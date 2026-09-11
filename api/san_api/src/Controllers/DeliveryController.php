<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Services\FcmService;
use App\Services\NotificationRepo;


class DeliveryController {

  // GET /deliveries  (NGO role only)
  public function list(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];

    $query = $req->getQueryParams();

    /*
    * group_scope:
    * SINGLE  = only deliveries not inside any delivery group
    * GROUPED = only deliveries already inside a delivery group
    * ALL     = all deliveries
    */
    $groupScope = strtoupper(trim($query['group_scope'] ?? 'SINGLE'));

    if (!in_array($groupScope, ['SINGLE', 'GROUPED', 'ALL'], true)) {
      $groupScope = 'SINGLE';
    }

    $pdo = Db::conn();

    // Find NGO(s) this user belongs to via ngo_staff
    $stmt = $pdo->prepare("SELECT ngo_id FROM ngo_staff WHERE user_id = ?");
    $stmt->execute([$userId]);
    $ngoIds = array_map(fn($r) => (int)$r['ngo_id'], $stmt->fetchAll());

    if (count($ngoIds) === 0) {
      return Http::json($res, [
        "ok" => true,
        "group_scope" => $groupScope,
        "deliveries" => []
      ]);
    }

    // Build IN clause safely
    $in = implode(',', array_fill(0, count($ngoIds), '?'));

    $sql = "
      SELECT
        d.delivery_id,
        d.status,
        d.scheduled_date,
        d.notes,
        d.image_link,
        d.created_at,
        d.distance_km,
        d.eta_minutes,

        s.shelter_name,
        s.city,
        s.state,
        s.latitude,
        s.longitude,

        dgd.delivery_group_id,
        CASE
          WHEN dgd.delivery_group_id IS NULL THEN 0
          ELSE 1
        END AS is_grouped

      FROM deliveries d
      JOIN shelters s
        ON s.shelter_id = d.shelter_id
      LEFT JOIN delivery_group_deliveries dgd
        ON dgd.delivery_id = d.delivery_id
      WHERE d.ngo_id IN ($in)
    ";

    $params = $ngoIds;

    if ($groupScope === 'SINGLE') {
      $sql .= "
        AND dgd.delivery_group_id IS NULL
      ";
    }

    if ($groupScope === 'GROUPED') {
      $sql .= "
        AND dgd.delivery_group_id IS NOT NULL
      ";
    }

    /*
    * Real-world operational ordering:
    * 1. PLANNED
    * 2. IN_TRANSIT
    * 3. ROUTED
    * 4. DELIVERED
    * 5. CANCELLED
    *
    * Within each status, newest/bigger delivery_id first.
    */
    $sql .= "
      ORDER BY
        CASE d.status
          WHEN 'PLANNED' THEN 1
          WHEN 'IN_TRANSIT' THEN 2
          WHEN 'ROUTED' THEN 3
          WHEN 'DELIVERED' THEN 4
          WHEN 'CANCELLED' THEN 5
          ELSE 6
        END,
        d.delivery_id DESC
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    return Http::json($res, [
      "ok" => true,
      "group_scope" => $groupScope,
      "deliveries" => $stmt->fetchAll()
    ]);
  }

  // GET /deliveries/{id} (NGO role only)
  public function detail(Request $req, Response $res, array $args): Response {
    $deliveryId = (int)$args['id'];
    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];

    $pdo = Db::conn();

    // Check user has access (belongs to same NGO)
    $stmt = $pdo->prepare("
      SELECT d.*
      FROM deliveries d
      JOIN ngo_staff ns ON ns.ngo_id = d.ngo_id
      WHERE d.delivery_id = ? AND ns.user_id = ?
      LIMIT 1
    ");
    $stmt->execute([$deliveryId, $userId]);
    $delivery = $stmt->fetch();

    if (!$delivery) {
      return Http::json($res, ["ok"=>false,"error"=>"Delivery not found or forbidden"], 404);
    }

    // Shelter details
    $stmt = $pdo->prepare("SELECT * FROM shelters WHERE shelter_id = ? LIMIT 1");
    $stmt->execute([(int)$delivery['shelter_id']]);
    $shelter = $stmt->fetch();

    $navUrl = null;
    if ($shelter && $shelter['latitude'] !== null && $shelter['longitude'] !== null) {
      $lat = $shelter['latitude'];
      $lng = $shelter['longitude'];
      $navUrl = "https://www.google.com/maps/dir/?api=1&destination={$lat},{$lng}&travelmode=driving";
    }

    // Items
    $stmt = $pdo->prepare("
      SELECT di.quantity, ai.item_name, ai.unit
      FROM delivery_items di
      JOIN aid_items ai ON ai.item_id = di.item_id
      WHERE di.delivery_id = ?
      ORDER BY ai.item_name ASC
    ");
    $stmt->execute([$deliveryId]);
    $items = $stmt->fetchAll();

    // Latest tracking status
    $stmt = $pdo->prepare("
      SELECT status, latitude, longitude, note, created_at
      FROM delivery_tracking
      WHERE delivery_id = ?
      ORDER BY created_at DESC
      LIMIT 10
    ");
    $stmt->execute([$deliveryId]);
    $tracking = $stmt->fetchAll();

    return Http::json($res, [
      "ok"=>true,
      "delivery"=>$delivery,
      "shelter"=>$shelter,
      "items"=>$items,
      "tracking"=>$tracking,
      "navigation_url" => $navUrl
    ]);
  }

  // PATCH /deliveries/{id}/status  (NGO role only)
  public function updateStatus(Request $req, Response $res, array $args): Response {
    $deliveryId = (int)$args['id'];
    $body = (array)$req->getParsedBody();

    $status = strtoupper(trim($body['status'] ?? ''));
    $note = trim($body['note'] ?? '');

    // New: receive Supabase image URL from Flutter
    $imageLink = trim($body['image_link'] ?? '');

    $allowed = ['PLANNED','ROUTED','IN_TRANSIT','DELIVERED','CANCELLED'];
    if (!in_array($status, $allowed, true)) {
      return Http::json($res, ["ok"=>false,"error"=>"Invalid status"], 400);
    }

    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];
    $pdo = Db::conn();

    // Ensure belongs to NGO staff
    $stmt = $pdo->prepare("
      SELECT d.delivery_id
      FROM deliveries d
      JOIN ngo_staff ns ON ns.ngo_id = d.ngo_id
      WHERE d.delivery_id = ? AND ns.user_id = ?
      LIMIT 1
    ");
    $stmt->execute([$deliveryId, $userId]);

    if (!$stmt->fetch()) {
      return Http::json($res, ["ok"=>false,"error"=>"Forbidden"], 403);
    }

    // Update deliveries table
    // If image_link is sent, save it.
    // If not sent, keep old image_link value.
    if ($imageLink !== '') {
      $stmt = $pdo->prepare("
        UPDATE deliveries
        SET status = ?, image_link = ?
        WHERE delivery_id = ?
      ");
      $stmt->execute([$status, $imageLink, $deliveryId]);
    } else {
      $stmt = $pdo->prepare("
        UPDATE deliveries
        SET status = ?
        WHERE delivery_id = ?
      ");
      $stmt->execute([$status, $deliveryId]);
    }

    // Insert tracking record
    $trackingNote = $note;

    if ($imageLink !== '') {
      $trackingNote = trim($trackingNote . " Proof photo: " . $imageLink);
    }

    $stmt = $pdo->prepare("
      INSERT INTO delivery_tracking(delivery_id, status, note)
      VALUES(?,?,?)
    ");
    $stmt->execute([$deliveryId, $status, $trackingNote]);

    // --- Push notification to NGO staff
    $ngoIdStmt = $pdo->prepare("SELECT ngo_id FROM deliveries WHERE delivery_id=? LIMIT 1");
    $ngoIdStmt->execute([$deliveryId]);
    $ngoId = (int)$ngoIdStmt->fetchColumn();

    $fcm = new \App\Services\FcmService($_ENV['FCM_PROJECT_ID'], $_ENV['FCM_SERVICE_ACCOUNT']);
    $userIds = \App\Services\NotificationRepo::ngoStaffUserIds($ngoId);
    $tokens = \App\Services\NotificationRepo::activeTokensForUserIds($userIds);

    foreach ($tokens as $t) {
      $fcm->sendToToken(
        $t,
        "Delivery Updated",
        "Delivery #{$deliveryId} status: {$status}",
        ["type"=>"delivery", "delivery_id"=>$deliveryId, "status"=>$status]
      );
    }

    $groupStmt = $pdo->prepare("
      SELECT delivery_group_id
      FROM delivery_group_deliveries
      WHERE delivery_id = ?
      LIMIT 1
    ");
    $groupStmt->execute([$deliveryId]);
    $groupId = $groupStmt->fetchColumn();

    if ($groupId) {
      if ($status === 'IN_TRANSIT') {
        $updateGroupStmt = $pdo->prepare("
          UPDATE delivery_groups
          SET status = 'IN_TRANSIT'
          WHERE delivery_group_id = ?
            AND status NOT IN ('DELIVERED', 'CANCELLED')
        ");
        $updateGroupStmt->execute([(int)$groupId]);
      }

      if ($status === 'DELIVERED') {
        $countStmt = $pdo->prepare("
          SELECT
            COUNT(*) AS total_count,
            SUM(CASE WHEN d.status = 'DELIVERED' THEN 1 ELSE 0 END) AS delivered_count
          FROM delivery_group_deliveries dgd
          INNER JOIN deliveries d
            ON d.delivery_id = dgd.delivery_id
          WHERE dgd.delivery_group_id = ?
        ");
        $countStmt->execute([(int)$groupId]);
        $counts = $countStmt->fetch();

        if (
          $counts &&
          (int)$counts['total_count'] > 0 &&
          (int)$counts['total_count'] === (int)$counts['delivered_count']
        ) {
          $updateGroupStmt = $pdo->prepare("
            UPDATE delivery_groups
            SET status = 'DELIVERED'
            WHERE delivery_group_id = ?
          ");
          $updateGroupStmt->execute([(int)$groupId]);
        }
      }

      if ($status === 'CANCELLED') {
        $countStmt = $pdo->prepare("
          SELECT
            COUNT(*) AS total_count,
            SUM(CASE WHEN d.status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_count
          FROM delivery_group_deliveries dgd
          INNER JOIN deliveries d
            ON d.delivery_id = dgd.delivery_id
          WHERE dgd.delivery_group_id = ?
        ");
        $countStmt->execute([(int)$groupId]);
        $counts = $countStmt->fetch();

        if (
          $counts &&
          (int)$counts['total_count'] > 0 &&
          (int)$counts['total_count'] === (int)$counts['cancelled_count']
        ) {
          $updateGroupStmt = $pdo->prepare("
            UPDATE delivery_groups
            SET status = 'CANCELLED'
            WHERE delivery_group_id = ?
          ");
          $updateGroupStmt->execute([(int)$groupId]);
        }
      }
    }

    return Http::json($res, [
      "ok" => true,
      "delivery_id" => $deliveryId,
      "status" => $status,
      "image_link" => $imageLink !== '' ? $imageLink : null
    ]);
  }

  public function addTracking(Request $req, Response $res, array $args): Response {
    $deliveryId = (int)$args['id'];
    $body = (array)$req->getParsedBody();

    $lat = isset($body['latitude']) ? (float)$body['latitude'] : null;
    $lng = isset($body['longitude']) ? (float)$body['longitude'] : null;
    $status = strtoupper(trim($body['status'] ?? 'IN_TRANSIT'));
    $note = trim($body['note'] ?? '');

    $allowed = ['PLANNED','ROUTED','IN_TRANSIT','DELIVERED','CANCELLED'];
    if (!in_array($status, $allowed, true)) {
      return \App\Http::json($res, ["ok"=>false,"error"=>"Invalid status"], 400);
    }

    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];
    $pdo = \App\Db::conn();

    // Ensure staff has access to this delivery
    $stmt = $pdo->prepare("
      SELECT d.delivery_id
      FROM deliveries d
      JOIN ngo_staff ns ON ns.ngo_id = d.ngo_id
      WHERE d.delivery_id = ? AND ns.user_id = ?
      LIMIT 1
    ");
    $stmt->execute([$deliveryId, $userId]);
    if (!$stmt->fetch()) {
      return \App\Http::json($res, ["ok"=>false,"error"=>"Forbidden"], 403);
    }

    $stmt = $pdo->prepare("
      INSERT INTO delivery_tracking(delivery_id, status, latitude, longitude, note)
      VALUES(?,?,?,?,?)
    ");
    $stmt->execute([$deliveryId, $status, $lat, $lng, $note]);

    return \App\Http::json($res, ["ok"=>true], 201);
  }

}
