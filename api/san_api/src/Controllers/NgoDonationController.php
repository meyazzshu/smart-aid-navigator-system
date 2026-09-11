<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class NgoDonationController {

  // GET /ngo/donations  (NGO_STAFF / ADMIN)
  public function list(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];

    $q = $req->getQueryParams();
    $status = strtoupper(trim($q['status'] ?? ''));

    $allowed = ['PENDING','CONFIRMED','COMPLETED','CANCELLED'];
    if ($status !== '' && !in_array($status, $allowed, true)) {
      return Http::json($res, [
        "ok" => false,
        "error" => "Invalid status filter"
      ], 400);
    }

    $pdo = Db::conn();

    // Get NGO IDs for this staff
    $stmt = $pdo->prepare("SELECT ngo_id FROM ngo_staff WHERE user_id = ?");
    $stmt->execute([$userId]);
    $ngoIds = array_map(fn($r) => (int)$r['ngo_id'], $stmt->fetchAll());

    if (count($ngoIds) === 0) {
      return Http::json($res, [
        "ok" => true,
        "donations" => []
      ]);
    }

    $in = implode(',', array_fill(0, count($ngoIds), '?'));

    /*
      This query now supports both:
      1. NGO-targeted donations:
         donations.ngo_id IN staff NGO IDs

      2. Shelter-targeted donations:
         donations.shelter_id belongs to a shelter under the staff's NGO

      This is important because you added donations.shelter_id.
    */
    $sql = "
      SELECT 
        d.donation_id,
        d.donor_id,
        d.ngo_id,
        d.shelter_id,
        d.donation_type,
        d.status,
        d.dropoff_required,
        d.dropoff_confirmed,
        d.proof_photo_url,
        d.created_at,
        d.remarks,

        COALESCE(n_direct.ngo_name, n_shelter.ngo_name) AS ngo_name,
        s.shelter_name,

        CASE 
          WHEN d.shelter_id IS NOT NULL THEN 'SHELTER'
          ELSE 'NGO'
        END AS receiver_type,

        CASE 
          WHEN d.shelter_id IS NOT NULL THEN s.shelter_name
          ELSE COALESCE(n_direct.ngo_name, n_shelter.ngo_name)
        END AS receiver_name,

        p.full_name AS donor_name,
        p.email AS donor_email,
        p.phone AS donor_phone,

        pay.amount AS payment_amount,
        pay.currency AS payment_currency,
        pay.method AS payment_method,
        pay.provider AS payment_provider,
        pay.provider_ref AS payment_provider_ref,
        pay.provider_bill_code,
        pay.provider_invoice_no,
        pay.payment_status,
        pay.paid_at

      FROM donations d

      LEFT JOIN shelters s 
        ON s.shelter_id = d.shelter_id

      LEFT JOIN ngos n_direct 
        ON n_direct.ngo_id = d.ngo_id

      LEFT JOIN ngos n_shelter 
        ON n_shelter.ngo_id = s.ngo_id

      LEFT JOIN donors dn 
        ON dn.donor_id = d.donor_id

      LEFT JOIN persons p 
        ON p.person_id = dn.person_id

      LEFT JOIN payments pay 
        ON pay.donation_id = d.donation_id

      WHERE (
        d.ngo_id IN ($in)
        OR s.ngo_id IN ($in)
      )
    ";

    /*
      Because the SQL has:
        d.ngo_id IN ($in)
        OR s.ngo_id IN ($in)

      We must pass the NGO IDs twice.
    */
    $params = array_merge($ngoIds, $ngoIds);

    if ($status !== '') {
      $sql .= " AND d.status = ?";
      $params[] = $status;
    }

    $sql .= " ORDER BY d.created_at DESC LIMIT 200";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $donations = $stmt->fetchAll();

    /*
      Attach item details for ITEM donations.
      Flutter NGO detail page reads:
        d['items'] ?? d['donation_items']
    */
    $donationIds = array_map(
      fn($d) => (int)$d['donation_id'],
      $donations
    );

    $itemsByDonation = [];

    if (count($donationIds) > 0) {
      $itemIn = implode(',', array_fill(0, count($donationIds), '?'));

      $itemStmt = $pdo->prepare("
        SELECT 
          di.donation_id,
          di.donation_item_id,
          di.item_id,
          di.quantity,
          ai.item_name,
          ai.unit,
          ac.category_name
        FROM donation_items di
        JOIN aid_items ai ON ai.item_id = di.item_id
        LEFT JOIN aid_categories ac ON ac.category_id = ai.category_id
        WHERE di.donation_id IN ($itemIn)
        ORDER BY ac.category_name ASC, ai.item_name ASC
      ");

      $itemStmt->execute($donationIds);

      foreach ($itemStmt->fetchAll() as $item) {
        $donationId = (int)$item['donation_id'];

        if (!isset($itemsByDonation[$donationId])) {
          $itemsByDonation[$donationId] = [];
        }

        $itemsByDonation[$donationId][] = [
          "donation_item_id" => (int)$item['donation_item_id'],
          "item_id" => (int)$item['item_id'],
          "item_name" => $item['item_name'],
          "category_name" => $item['category_name'],
          "quantity" => (int)$item['quantity'],
          "unit" => $item['unit'],
        ];
      }
    }

    foreach ($donations as &$donation) {
      $donationId = (int)$donation['donation_id'];
      $donation['items'] = $itemsByDonation[$donationId] ?? [];
    }
    unset($donation);

    return Http::json($res, [
      "ok" => true,
      "donations" => $donations
    ]);
  }

  // PATCH /ngo/donations/{id}/items  (NGO_STAFF / ADMIN)
  // Allows NGO staff to correct actual received item quantities before completion.
  public function updateItems(Request $req, Response $res, array $args): Response {
    $donationId = (int)$args['id'];

    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];

    $body = (array)$req->getParsedBody();
    $items = $body['items'] ?? null;

    if (!is_array($items)) {
      return Http::json($res, [
        "ok" => false,
        "error" => "items array is required"
      ], 400);
    }

    if (count($items) === 0) {
      return Http::json($res, [
        "ok" => false,
        "error" => "At least one item is required"
      ], 400);
    }

    $pdo = Db::conn();

    try {
      $pdo->beginTransaction();

      /*
        Lock donation row and verify this NGO staff is allowed to manage it.

        Supports:
        - donation.ngo_id belongs to staff NGO
        - donation.shelter_id belongs to shelter under staff NGO
      */
      $stmt = $pdo->prepare("
        SELECT 
          d.donation_id,
          d.ngo_id,
          d.shelter_id,
          d.status,
          d.donation_type,
          s.ngo_id AS shelter_ngo_id
        FROM donations d
        LEFT JOIN shelters s 
          ON s.shelter_id = d.shelter_id
        LEFT JOIN ngo_staff ns_direct 
          ON ns_direct.ngo_id = d.ngo_id
        AND ns_direct.user_id = ?
        LEFT JOIN ngo_staff ns_shelter 
          ON ns_shelter.ngo_id = s.ngo_id
        AND ns_shelter.user_id = ?
        WHERE d.donation_id = ?
          AND (
            ns_direct.user_id IS NOT NULL
            OR ns_shelter.user_id IS NOT NULL
          )
        LIMIT 1
        FOR UPDATE
      ");
      $stmt->execute([$userId, $userId, $donationId]);
      $donation = $stmt->fetch();

      if (!$donation) {
        $pdo->rollBack();
        return Http::json($res, [
          "ok" => false,
          "error" => "Donation not found or forbidden"
        ], 404);
      }

      if ($donation['donation_type'] !== 'ITEM') {
        $pdo->rollBack();
        return Http::json($res, [
          "ok" => false,
          "error" => "Only ITEM donation quantities can be edited"
        ], 400);
      }

      if ($donation['status'] === 'CANCELLED') {
        $pdo->rollBack();
        return Http::json($res, [
          "ok" => false,
          "error" => "Cannot edit CANCELLED donation"
        ], 400);
      }

      /*
        Do not allow edit after COMPLETED.
        Inventory has already been updated at that point.
      */
      if ($donation['status'] === 'COMPLETED') {
        $pdo->rollBack();
        return Http::json($res, [
          "ok" => false,
          "error" => "Cannot edit item quantities after donation is COMPLETED"
        ], 400);
      }

      /*
        Load existing donation items to make sure NGO cannot update random item_id
        that was never part of this donation.
      */
      $existingStmt = $pdo->prepare("
        SELECT donation_item_id, item_id, quantity
        FROM donation_items
        WHERE donation_id = ?
      ");
      $existingStmt->execute([$donationId]);
      $existingRows = $existingStmt->fetchAll();

      if (count($existingRows) === 0) {
        $pdo->rollBack();
        return Http::json($res, [
          "ok" => false,
          "error" => "No donation items found"
        ], 400);
      }

      $existingItemIds = [];
      foreach ($existingRows as $row) {
        $existingItemIds[(int)$row['item_id']] = true;
      }

      $updatedCount = 0;

      foreach ($items as $item) {
        if (!is_array($item)) {
          $pdo->rollBack();
          return Http::json($res, [
            "ok" => false,
            "error" => "Each item must be an object"
          ], 400);
        }

        $itemId = (int)($item['item_id'] ?? 0);
        $quantity = (int)($item['quantity'] ?? -1);

        if ($itemId <= 0) {
          $pdo->rollBack();
          return Http::json($res, [
            "ok" => false,
            "error" => "Invalid item_id"
          ], 400);
        }

        /*
          Allow quantity 0 because in real life NGO may receive 0 of an item
          even though donor selected it. But negative is not allowed.
        */
        if ($quantity < 0) {
          $pdo->rollBack();
          return Http::json($res, [
            "ok" => false,
            "error" => "Quantity cannot be negative"
          ], 400);
        }

        if (!isset($existingItemIds[$itemId])) {
          $pdo->rollBack();
          return Http::json($res, [
            "ok" => false,
            "error" => "Item ID {$itemId} does not belong to this donation"
          ], 400);
        }

        $updateStmt = $pdo->prepare("
          UPDATE donation_items
          SET quantity = ?
          WHERE donation_id = ?
            AND item_id = ?
        ");
        $updateStmt->execute([$quantity, $donationId, $itemId]);

        $updatedCount++;
      }

      /*
        Audit log for item quantity correction.
      */
      $auditStmt = $pdo->prepare("
        INSERT INTO audit_logs (
          user_id,
          action,
          entity,
          entity_id,
          detail
        )
        VALUES (
          ?,
          'DONATION_ITEMS_QUANTITY_UPDATED',
          'donation_items',
          ?,
          ?
        )
      ");

      $auditStmt->execute([
        $userId,
        $donationId,
        json_encode([
          "updated_items" => $items,
          "note" => "NGO corrected actual received donation item quantities before completion"
        ])
      ]);

      $pdo->commit();

      return Http::json($res, [
        "ok" => true,
        "message" => "Donation item quantities updated",
        "updated_count" => $updatedCount
      ]);

    } catch (\Throwable $e) {
      if ($pdo->inTransaction()) {
        $pdo->rollBack();
      }

      return Http::json($res, [
        "ok" => false,
        "error" => "Failed to update donation items: " . $e->getMessage()
      ], 500);
    }
  }

  // POST /ngo/donations/{id}/mark-received  (NGO_STAFF / ADMIN)
  public function markReceived(Request $req, Response $res, array $args): Response {
    $donationId = (int)$args['id'];

    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];

    $body = (array)$req->getParsedBody();
    $note = trim($body['note'] ?? '');

    $pdo = Db::conn();

    try {
      $pdo->beginTransaction();

      /*
        Lock the donation row.

        This prevents double-click from adding inventory twice.
        Also supports:
          - NGO-targeted donations
          - Shelter-targeted donations where shelter belongs to the NGO staff's NGO
      */
      $stmt = $pdo->prepare("
        SELECT 
          d.donation_id,
          d.ngo_id,
          d.shelter_id,
          d.status,
          d.donation_type,
          d.dropoff_required,
          d.dropoff_confirmed,
          s.ngo_id AS shelter_ngo_id
        FROM donations d
        LEFT JOIN shelters s 
          ON s.shelter_id = d.shelter_id
        LEFT JOIN ngo_staff ns_direct 
          ON ns_direct.ngo_id = d.ngo_id
         AND ns_direct.user_id = ?
        LEFT JOIN ngo_staff ns_shelter 
          ON ns_shelter.ngo_id = s.ngo_id
         AND ns_shelter.user_id = ?
        WHERE d.donation_id = ?
          AND (
            ns_direct.user_id IS NOT NULL
            OR ns_shelter.user_id IS NOT NULL
          )
        LIMIT 1
        FOR UPDATE
      ");
      $stmt->execute([$userId, $userId, $donationId]);
      $d = $stmt->fetch();

      if (!$d) {
        $pdo->rollBack();
        return Http::json($res, [
          "ok" => false,
          "error" => "Donation not found or forbidden"
        ], 404);
      }

      if ($d['status'] === 'CANCELLED') {
        $pdo->rollBack();
        return Http::json($res, [
          "ok" => false,
          "error" => "Cannot receive CANCELLED donation"
        ], 400);
      }

      /*
        If already completed, do not add inventory again.
      */
      if ($d['status'] === 'COMPLETED') {
        $pdo->commit();
        return Http::json($res, [
          "ok" => true,
          "message" => "Donation already completed. Inventory was not updated again."
        ]);
      }

      /*
        If item donation requires drop-off, donor must confirm first.
      */
      if (
        $d['donation_type'] === 'ITEM' &&
        (int)$d['dropoff_required'] === 1 &&
        (int)$d['dropoff_confirmed'] !== 1
      ) {
        $pdo->rollBack();
        return Http::json($res, [
          "ok" => false,
          "error" => "Drop-off not confirmed by donor yet"
        ], 400);
      }

      /*
        For ITEM donation, add stock to the correct inventory.

        If shelter_id exists:
          update shelter_inventory

        Else:
          update ngo_inventory
      */
      if ($d['donation_type'] === 'ITEM') {
        $itemStmt = $pdo->prepare("
          SELECT 
            di.item_id,
            di.quantity,
            ai.item_name
          FROM donation_items di
          JOIN aid_items ai ON ai.item_id = di.item_id
          WHERE di.donation_id = ?
        ");
        $itemStmt->execute([$donationId]);
        $items = $itemStmt->fetchAll();

        if (count($items) === 0) {
          $pdo->rollBack();
          return Http::json($res, [
            "ok" => false,
            "error" => "Cannot complete item donation because no donation items were found"
          ], 400);
        }

        /*
          Decide receiver.
        */
        $ownerType = null;
        $ownerId = null;
        $inventoryTable = null;
        $ownerColumn = null;

        if (!empty($d['shelter_id'])) {
          $ownerType = 'SHELTER';
          $ownerId = (int)$d['shelter_id'];
          $inventoryTable = 'shelter_inventory';
          $ownerColumn = 'shelter_id';
        } elseif (!empty($d['ngo_id'])) {
          $ownerType = 'NGO';
          $ownerId = (int)$d['ngo_id'];
          $inventoryTable = 'ngo_inventory';
          $ownerColumn = 'ngo_id';
        } else {
          $pdo->rollBack();
          return Http::json($res, [
            "ok" => false,
            "error" => "Donation has no receiving NGO or shelter"
          ], 400);
        }

        foreach ($items as $item) {
          $itemId = (int)$item['item_id'];
          $qty = (int)$item['quantity'];

          if ($itemId <= 0 || $qty <= 0) {
            continue;
          }

          /*
            Dynamic table name is safe here because it only comes from fixed values:
              shelter_inventory / ngo_inventory

            Dynamic owner column is also fixed:
              shelter_id / ngo_id
          */
          $inventoryStmt = $pdo->prepare("
            INSERT INTO {$inventoryTable} (
              {$ownerColumn},
              item_id,
              quantity,
              minimum_level,
              updated_at
            )
            VALUES (
              :owner_id,
              :item_id,
              :quantity,
              0,
              NOW()
            )
            ON DUPLICATE KEY UPDATE
              quantity = quantity + VALUES(quantity),
              updated_at = NOW()
          ");

          $inventoryStmt->execute([
            ':owner_id' => $ownerId,
            ':item_id' => $itemId,
            ':quantity' => $qty,
          ]);

          /*
            Log transaction.
          */
          $txStmt = $pdo->prepare("
            INSERT INTO inventory_transactions (
              owner_type,
              owner_id,
              item_id,
              transaction_type,
              quantity,
              source_type,
              source_id,
              note,
              created_by,
              created_at
            )
            VALUES (
              :owner_type,
              :owner_id,
              :item_id,
              'IN',
              :quantity,
              'DONATION',
              :source_id,
              :note,
              :created_by,
              NOW()
            )
          ");

          $txStmt->execute([
            ':owner_type' => $ownerType,
            ':owner_id' => $ownerId,
            ':item_id' => $itemId,
            ':quantity' => $qty,
            ':source_id' => $donationId,
            ':note' => $note !== ''
              ? $note
              : 'Donation item received and added to inventory',
            ':created_by' => $userId,
          ]);
        }
      }

      /*
        MONEY donation:
        No inventory update needed.
        Just complete the donation.
      */
      $stmt = $pdo->prepare("
        UPDATE donations
        SET status = 'COMPLETED'
        WHERE donation_id = ?
      ");
      $stmt->execute([$donationId]);

      /*
        Audit log.
      */
      $stmt = $pdo->prepare("
        INSERT INTO audit_logs (
          user_id,
          action,
          entity,
          entity_id,
          detail
        )
        VALUES (
          ?,
          'DONATION_MARK_RECEIVED',
          'donations',
          ?,
          ?
        )
      ");
      $stmt->execute([
        $userId,
        $donationId,
        $note
      ]);

      $pdo->commit();

    } catch (\Throwable $e) {
      if ($pdo->inTransaction()) {
        $pdo->rollBack();
      }

      return Http::json($res, [
        "ok" => false,
        "error" => "Failed to mark donation as received: " . $e->getMessage()
      ], 500);
    }

    /*
      Notify donor user.

      Notification failure should not undo donation completion or inventory update.
    */
    try {
      $donorEmailStmt = $pdo->prepare("
        SELECT p.email
        FROM donations d
        JOIN donors dn ON dn.donor_id = d.donor_id
        JOIN persons p ON p.person_id = dn.person_id
        WHERE d.donation_id = ?
        LIMIT 1
      ");
      $donorEmailStmt->execute([$donationId]);
      $donorEmail = $donorEmailStmt->fetchColumn();

      if ($donorEmail) {
        $donorUserId = \App\Services\NotificationRepo::userIdByEmail($donorEmail);

        if ($donorUserId) {
          $tokens = \App\Services\NotificationRepo::activeTokensForUserIds([$donorUserId]);

          $fcm = new \App\Services\FcmService(
            $_ENV['FCM_PROJECT_ID'],
            $_ENV['FCM_SERVICE_ACCOUNT']
          );

          foreach ($tokens as $t) {
            $fcm->sendToToken(
              $t,
              "Donation Received",
              "Your donation #{$donationId} has been received. Thank you!",
              [
                "type" => "donation",
                "donation_id" => $donationId,
                "event" => "received"
              ]
            );
          }
        }
      }
    } catch (\Throwable $e) {
      /*
        Ignore notification error.
      */
    }

    return Http::json($res, [
      "ok" => true,
      "message" => "Donation marked as COMPLETED and inventory updated"
    ]);
  }
}