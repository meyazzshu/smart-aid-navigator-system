<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class DonationController {

  private function personIdForUser(\PDO $pdo, int $userId): ?int {
    $stmt = $pdo->prepare("SELECT person_id FROM users WHERE user_id = ? LIMIT 1");
    $stmt->execute([$userId]);
    $personId = $stmt->fetchColumn();
    return $personId !== false ? (int)$personId : null;
  }

  private function donorIdForPerson(\PDO $pdo, int $personId, bool $createIfMissing = false): ?int {
    $stmt = $pdo->prepare("SELECT donor_id FROM donors WHERE person_id = ? LIMIT 1");
    $stmt->execute([$personId]);
    $donorId = $stmt->fetchColumn();
    if ($donorId !== false) {
      return (int)$donorId;
    }
    if (!$createIfMissing) {
      return null;
    }

    $stmt = $pdo->prepare("
      INSERT INTO donors(person_id, donor_type)
      VALUES(?, 'REGISTERED_USER')
    ");
    $stmt->execute([$personId]);
    return (int)$pdo->lastInsertId();
  }

  // POST /donations  (PUBLIC only)
  public function create(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)($auth['user_id'] ?? 0);

    $body = (array)$req->getParsedBody();
    $ngo_id = $body['ngo_id'] ?? null;
    $shelter_id = $body['shelter_id'] ?? null;
    $donation_type = strtoupper(trim($body['donation_type'] ?? ''));
    $remarks = trim($body['remarks'] ?? '');
    

    if (!in_array($donation_type, ['MONEY','ITEM'], true)) {
      return Http::json($res, ["ok"=>false,"error"=>"donation_type must be MONEY or ITEM"], 400);
    }

    $pdo = Db::conn();
    $personId = $this->personIdForUser($pdo, $userId);
    if (!$personId) {
      return Http::json($res, ["ok"=>false,"error"=>"User profile missing"], 404);
    }
    $donor_id = $this->donorIdForPerson($pdo, $personId, true);
    $dropoff_required = isset($body['dropoff_required']) ? (int)$body['dropoff_required'] : 0;
    $dropoff_required = ($dropoff_required === 1) ? 1 : 0;

    $stmt = $pdo->prepare("
      INSERT INTO donations(donor_id, ngo_id, shelter_id, donation_type, dropoff_required, remarks)
      VALUES(?,?,?,?,?,?)
    ");
    $stmt->execute([
      $donor_id,
      $ngo_id ? (int)$ngo_id : null,
      $shelter_id ? (int)$shelter_id : null,
      $donation_type,
      $dropoff_required,
      $remarks
    ]);

    $donationId = (int)$pdo->lastInsertId();

    return Http::json($res, ["ok"=>true,"donation_id"=>$donationId], 201);
  }

  // GET /donations/my  (PUBLIC only)
  public function my(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)($auth['user_id'] ?? 0);

    $pdo = Db::conn();
    $personId = $this->personIdForUser($pdo, $userId);
    if (!$personId) return Http::json($res, ["ok"=>true,"donations"=>[]]);
    $donorId = $this->donorIdForPerson($pdo, $personId);
    if (!$donorId) return Http::json($res, ["ok"=>true,"donations"=>[]]);

    $stmt = $pdo->prepare("
      SELECT d.donation_id, d.donation_type, d.status, d.created_at, d.remarks,
             n.ngo_name
      FROM donations d
      LEFT JOIN ngos n ON n.ngo_id = d.ngo_id
      WHERE d.donor_id = ?
      ORDER BY d.created_at DESC
    ");
    $stmt->execute([$donorId]);

    return Http::json($res, ["ok"=>true,"donations"=>$stmt->fetchAll()]);
  }

  // POST /donations/{id}/items  (PUBLIC only) for ITEM donation
  public function addItem(Request $req, Response $res, array $args): Response {
    $donationId = (int)$args['id'];
    $body = (array)$req->getParsedBody();

    $item_id = (int)($body['item_id'] ?? 0);
    $qty = (int)($body['quantity'] ?? 0);

    if ($item_id <= 0 || $qty <= 0) {
      return Http::json($res, ["ok"=>false,"error"=>"item_id and quantity required"], 400);
    }

    $pdo = Db::conn();

    // Ensure donation exists and is ITEM
    $stmt = $pdo->prepare("SELECT donation_type FROM donations WHERE donation_id = ? LIMIT 1");
    $stmt->execute([$donationId]);
    $row = $stmt->fetch();
    if (!$row) return Http::json($res, ["ok"=>false,"error"=>"Donation not found"], 404);
    if ($row['donation_type'] !== 'ITEM') return Http::json($res, ["ok"=>false,"error"=>"Donation is not ITEM type"], 400);

    $stmt = $pdo->prepare("INSERT INTO donation_items(donation_id, item_id, quantity) VALUES(?,?,?)");
    $stmt->execute([$donationId, $item_id, $qty]);

    return Http::json($res, ["ok"=>true], 201);
  }

  public function detail(Request $req, Response $res, array $args): Response {
    $donationId = (int)$args['id'];

    $auth = $req->getAttribute('auth');
    $userId = (int)($auth['user_id'] ?? 0);

    $pdo = Db::conn();
    $personId = $this->personIdForUser($pdo, $userId);
    if (!$personId) return Http::json($res, ["ok"=>false,"error"=>"User profile missing"], 404);
    $donorId = $this->donorIdForPerson($pdo, $personId);
    if (!$donorId) return Http::json($res, ["ok"=>false,"error"=>"Donor not found"], 404);

    // donation row must belong to this donor
    $stmt = $pdo->prepare("
      SELECT d.*, n.ngo_name, n.latitude AS ngo_lat, n.longitude AS ngo_lng,
            n.address_line AS ngo_address, n.city AS ngo_city, n.state AS ngo_state, n.postal_code AS ngo_postal
      FROM donations d
      LEFT JOIN ngos n ON n.ngo_id = d.ngo_id
      WHERE d.donation_id = ? AND d.donor_id = ?
      LIMIT 1
    ");
    $stmt->execute([$donationId, $donorId]);
    $donation = $stmt->fetch();
    if (!$donation) return Http::json($res, ["ok"=>false,"error"=>"Donation not found"], 404);

    // donation items
    $stmt = $pdo->prepare("
      SELECT di.quantity, ai.item_name, ai.unit
      FROM donation_items di
      JOIN aid_items ai ON ai.item_id = di.item_id
      WHERE di.donation_id = ?
      ORDER BY ai.item_name ASC
    ");
    $stmt->execute([$donationId]);
    $items = $stmt->fetchAll();

    $stmt = $pdo->prepare("
      SELECT 
        payment_id,
        amount,
        currency,
        method,
        provider,
        provider_ref,
        provider_bill_code,
        provider_invoice_no,
        external_reference_no,
        payment_status,
        paid_at,
        receipt_token,
        receipt_issued_at,
        created_at
      FROM payments
      WHERE donation_id = ?
      ORDER BY created_at DESC
      LIMIT 1
    ");
    $stmt->execute([$donationId]);
    $payment = $stmt->fetch();

    return Http::json($res, [
      "ok" => true,
      "donation" => $donation,
      "items" => $items,
      "payment" => $payment ?: null
    ]);
  }

  public function confirmDropoff(Request $req, Response $res, array $args): Response {
    $donationId = (int)$args['id'];

    $auth = $req->getAttribute('auth');
    $userId = (int)($auth['user_id'] ?? 0);
    $pdo = Db::conn();

    $personId = $this->personIdForUser($pdo, $userId);
    if (!$personId) return Http::json($res, ["ok"=>false,"error"=>"User profile missing"], 404);
    $donorId = $this->donorIdForPerson($pdo, $personId);
    if (!$donorId) return Http::json($res, ["ok"=>false,"error"=>"Donor not found"], 404);

    // validate donation belongs to donor
    $stmt = $pdo->prepare("
      SELECT donation_type, dropoff_required, status
      FROM donations
      WHERE donation_id = ? AND donor_id = ?
      LIMIT 1
    ");
    $stmt->execute([$donationId, $donorId]);
    $row = $stmt->fetch();
    if (!$row) return Http::json($res, ["ok"=>false,"error"=>"Donation not found"], 404);

    if ($row['donation_type'] !== 'ITEM') {
      return Http::json($res, ["ok"=>false,"error"=>"Dropoff confirmation only for ITEM donations"], 400);
    }
    if ((int)$row['dropoff_required'] !== 1) {
      return Http::json($res, ["ok"=>false,"error"=>"dropoff_required is not enabled for this donation"], 400);
    }
    if ($row['status'] === 'CANCELLED') {
      return Http::json($res, ["ok"=>false,"error"=>"Donation is CANCELLED"], 400);
    }

    $body = (array)$req->getParsedBody();
    $photoUrl = trim($body['photo_url'] ?? '');

    // confirm dropoff and set status -> CONFIRMED
    $stmt = $pdo->prepare("
      UPDATE donations
      SET dropoff_confirmed = 1, proof_photo_url = :photo_url, status = 'CONFIRMED'
      WHERE donation_id = :donation_id
    ");
    $stmt->execute([':photo_url' => $photoUrl ?: null, ':donation_id' => $donationId]);

    // notify NGO staff (if donation has ngo_id)
    $ngoStmt = $pdo->prepare("SELECT ngo_id FROM donations WHERE donation_id=? LIMIT 1");
    $ngoStmt->execute([$donationId]);
    $ngoId = (int)$ngoStmt->fetchColumn();

    if ($ngoId > 0) {
      $fcm = new \App\Services\FcmService($_ENV['FCM_PROJECT_ID'], $_ENV['FCM_SERVICE_ACCOUNT']);
      $userIds = \App\Services\NotificationRepo::ngoStaffUserIds($ngoId);
      $tokens = \App\Services\NotificationRepo::activeTokensForUserIds($userIds);
      foreach ($tokens as $t) {
        $fcm->sendToToken(
          $t,
          "Drop-off Confirmed",
          "Donation #{$donationId} drop-off confirmed by donor",
          ["type"=>"donation", "donation_id"=>$donationId, "event"=>"dropoff_confirmed"]
        );
      }
    }

    return Http::json($res, ["ok"=>true]);
  }

}
