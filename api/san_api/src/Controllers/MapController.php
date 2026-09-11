<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class MapController {

  private function refreshShelterOccupancy(\PDO $pdo): void {
    $stmt = $pdo->prepare("
      UPDATE shelters s
      SET s.current_occupancy = (
        COALESCE((
          SELECT COUNT(*)
          FROM beneficiaries b
          WHERE b.shelter_id = s.shelter_id
            AND b.status = 'ACTIVE'
        ), 0)
        +
        COALESCE((
          SELECT SUM(sr.total_people)
          FROM shelter_requests sr
          WHERE sr.shelter_id = s.shelter_id
            AND sr.status = 'PENDING'
        ), 0)
      )
    ");

    $stmt->execute();
  }

  // GET /map/shelters?state=&city=
  public function shelters(Request $req, Response $res): Response {
    $q = $req->getQueryParams();
    $state = trim($q['state'] ?? '');
    $city  = trim($q['city'] ?? '');

    $pdo = Db::conn();

    $this->refreshShelterOccupancy($pdo);

    $sql = "SELECT
      s.shelter_id,
      s.shelter_name,
      s.address_line,
      s.city,
      s.state,
      s.postal_code,
      s.latitude,
      s.longitude,
      s.is_active,
      s.capacity,
      s.current_occupancy,
      GREATEST(COALESCE(s.capacity, 0) - COALESCE(s.current_occupancy, 0), 0) AS remaining_capacity
      FROM shelters s
      WHERE s.is_active = 1
        AND s.latitude IS NOT NULL
        AND s.longitude IS NOT NULL";
        
    $params = [];

    if ($state !== '') { $sql .= " AND s.state = ?"; $params[] = $state; }
    if ($city !== '')  { $sql .= " AND s.city = ?";  $params[] = $city; }

    $sql .= " ORDER BY s.shelter_name ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    return Http::json($res, ["ok"=>true, "shelters"=>$stmt->fetchAll()]);
  }

  // GET /map/ngos?state=&city=
  public function ngos(Request $req, Response $res): Response {
    $q = $req->getQueryParams();
    $state = trim($q['state'] ?? '');
    $city  = trim($q['city'] ?? '');

    $pdo = Db::conn();
    $sql = "SELECT ngo_id, ngo_name, address_line, city, state, postal_code, latitude, longitude, is_active
            FROM ngos
            WHERE is_active = 1
              AND latitude IS NOT NULL
              AND longitude IS NOT NULL";
    $params = [];

    if ($state !== '') { $sql .= " AND state = ?"; $params[] = $state; }
    if ($city !== '')  { $sql .= " AND city = ?";  $params[] = $city; }

    $sql .= " ORDER BY ngo_name ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    return Http::json($res, ["ok"=>true, "ngos"=>$stmt->fetchAll()]);
  }

  public function inventoryNeeds(Request $req, Response $res): Response {
    $q = $req->getQueryParams();

    $ownerType = strtoupper(trim($q['owner_type'] ?? ''));
    $ownerId = (int)($q['owner_id'] ?? 0);

    if (!in_array($ownerType, ['NGO', 'SHELTER'], true) || $ownerId <= 0) {
      return Http::json($res, [
        "ok" => false,
        "error" => "owner_type must be NGO or SHELTER and owner_id is required"
      ], 400);
    }

    $pdo = Db::conn();

    if ($ownerType === 'NGO') {
      $sql = "
        SELECT 
          'INVENTORY_NEED' AS need_type,
          NULL AS need_id,
          NULL AS beneficiary_id,
          NULL AS beneficiary_name,
          ai.item_id,
          ai.item_name,
          ai.unit,
          COALESCE(ni.quantity, 0) AS quantity,
          COALESCE(ni.minimum_level, 0) AS minimum_level,
          NULL AS required_quantity,
          NULL AS priority,
          NULL AS request_status,
          NULL AS notes,
          CASE
            WHEN COALESCE(ni.quantity, 0) = 0 THEN 'OUT_OF_STOCK'
            WHEN COALESCE(ni.quantity, 0) <= COALESCE(ni.minimum_level, 0) THEN 'CRITICAL'
            ELSE 'SUFFICIENT'
          END AS stock_status
        FROM aid_items ai
        LEFT JOIN ngo_inventory ni
          ON ni.item_id = ai.item_id AND ni.ngo_id = ?
        WHERE ai.is_active = 1
        HAVING stock_status IN ('OUT_OF_STOCK', 'CRITICAL')
        ORDER BY ai.item_name ASC
      ";

      $stmt = $pdo->prepare($sql);
      $stmt->execute([$ownerId]);
      $needs = $stmt->fetchAll();

      return Http::json($res, [
        "ok" => true,
        "owner_type" => $ownerType,
        "owner_id" => $ownerId,
        "needs" => $needs
      ]);
    }

    $sql = "
      SELECT 
        'INVENTORY_NEED' AS need_type,
        NULL AS need_id,
        NULL AS beneficiary_id,
        NULL AS beneficiary_name,
        ai.item_id,
        ai.item_name,
        ai.unit,
        COALESCE(si.quantity, 0) AS quantity,
        COALESCE(si.minimum_level, 0) AS minimum_level,
        NULL AS required_quantity,
        NULL AS priority,
        NULL AS request_status,
        NULL AS notes,
        CASE
          WHEN COALESCE(si.quantity, 0) = 0 THEN 'OUT_OF_STOCK'
          WHEN COALESCE(si.quantity, 0) <= COALESCE(si.minimum_level, 0) THEN 'CRITICAL'
          ELSE 'SUFFICIENT'
        END AS stock_status
      FROM aid_items ai
      LEFT JOIN shelter_inventory si
        ON si.item_id = ai.item_id AND si.shelter_id = ?
      WHERE ai.is_active = 1
      HAVING stock_status IN ('OUT_OF_STOCK', 'CRITICAL')
      ORDER BY ai.item_name ASC
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([$ownerId]);
    $needs = $stmt->fetchAll();

    $beneficiarySql = "
      SELECT
        'BENEFICIARY_NEED' AS need_type,
        bn.need_id,
        bn.beneficiary_id,
        p.full_name AS beneficiary_name,
        bn.item_id,
        ai.item_name,
        ai.unit,
        NULL AS quantity,
        NULL AS minimum_level,
        bn.required_quantity,
        bn.priority,
        bn.request_status,
        bn.notes,
        'BENEFICIARY_AWAITING_DONATION' AS stock_status
      FROM beneficiary_needs bn
      INNER JOIN beneficiaries b
        ON b.beneficiary_id = bn.beneficiary_id
      INNER JOIN persons p
        ON p.person_id = b.person_id
      INNER JOIN aid_items ai
        ON ai.item_id = bn.item_id
      WHERE b.shelter_id = ?
        AND b.status = 'ACTIVE'
        AND bn.request_status = 'AWAITING_DONATION'
      ORDER BY
        CASE bn.priority
          WHEN 'CRITICAL' THEN 1
          WHEN 'HIGH' THEN 2
          WHEN 'MEDIUM' THEN 3
          WHEN 'LOW' THEN 4
          ELSE 5
        END,
        bn.created_at DESC
    ";

    $stmt = $pdo->prepare($beneficiarySql);
    $stmt->execute([$ownerId]);
    $beneficiaryNeeds = $stmt->fetchAll();

    $needs = array_merge($needs, $beneficiaryNeeds);

    return Http::json($res, [
      "ok" => true,
      "owner_type" => $ownerType,
      "owner_id" => $ownerId,
      "needs" => $needs
    ]);
  }
}
