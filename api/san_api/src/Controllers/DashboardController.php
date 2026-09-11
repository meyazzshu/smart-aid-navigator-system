<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class DashboardController {

  // GET /dashboard/public   (PUBLIC or ADMIN)
  public function publicDashboard(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)($auth['user_id'] ?? 0);

    $pdo = Db::conn();

    // Active shelters
    $stmt = $pdo->query("SELECT COUNT(*) AS total FROM shelters WHERE is_active = 1");
    $totalShelters = (int)$stmt->fetch()['total'];

    // Active NGOs
    $stmt = $pdo->query("SELECT COUNT(*) AS total FROM ngos WHERE is_active = 1");
    $totalNgos = (int)$stmt->fetch()['total'];

    // Public map/support numbers
    $stmt = $pdo->query("
      SELECT COALESCE(SUM(capacity), 0) AS total_capacity,
             COALESCE(SUM(current_occupancy), 0) AS total_occupancy
      FROM shelters
      WHERE is_active = 1
    ");
    $shelterCapacityRow = $stmt->fetch();
    $totalCapacity = (int)$shelterCapacityRow['total_capacity'];
    $totalOccupancy = (int)$shelterCapacityRow['total_occupancy'];
    $availableCapacity = max(0, $totalCapacity - $totalOccupancy);

    // Find donor id for logged-in public user
    $stmt = $pdo->prepare("
      SELECT d.donor_id
      FROM donors d
      JOIN users u ON u.person_id = d.person_id
      WHERE u.user_id = ?
      LIMIT 1
    ");
    $stmt->execute([$userId]);
    $donorId = $stmt->fetchColumn();
    $donorId = $donorId !== false ? (int)$donorId : null;

    $myDonationStats = [
      "PENDING" => 0,
      "CONFIRMED" => 0,
      "CANCELLED" => 0,
      "COMPLETED" => 0,
    ];

    $myDonationTypeStats = [
      "MONEY" => 0,
      "ITEM" => 0,
    ];

    $myTotalDonationAmount = 0.00;
    $recentDonations = [];

    if ($donorId) {
      $stmt = $pdo->prepare("
        SELECT status, COUNT(*) AS c
        FROM donations
        WHERE donor_id = ?
        GROUP BY status
      ");
      $stmt->execute([$donorId]);
      foreach ($stmt->fetchAll() as $row) {
        $myDonationStats[$row['status']] = (int)$row['c'];
      }

      $stmt = $pdo->prepare("
        SELECT donation_type, COUNT(*) AS c
        FROM donations
        WHERE donor_id = ?
        GROUP BY donation_type
      ");
      $stmt->execute([$donorId]);
      foreach ($stmt->fetchAll() as $row) {
        $myDonationTypeStats[$row['donation_type']] = (int)$row['c'];
      }

      $stmt = $pdo->prepare("
        SELECT COALESCE(SUM(p.amount), 0) AS total_amount
        FROM donations d
        JOIN payments p ON p.donation_id = d.donation_id
        WHERE d.donor_id = ?
          AND d.donation_type = 'MONEY'
          AND d.status = 'COMPLETED'
          AND p.payment_status = 'PAID'
      ");
      $stmt->execute([$donorId]);
      $myTotalDonationAmount = (float)$stmt->fetchColumn();

      $stmt = $pdo->prepare("
        SELECT 
          d.donation_id,
          d.donation_type,
          d.status,
          d.created_at,
          d.remarks,
          d.dropoff_required,
          d.dropoff_confirmed,
          d.proof_photo_url,
          n.ngo_name,
          p.amount AS payment_amount,
          p.currency AS payment_currency,
          p.payment_status
        FROM donations d
        LEFT JOIN ngos n ON n.ngo_id = d.ngo_id
        LEFT JOIN payments p ON p.donation_id = d.donation_id
        WHERE d.donor_id = ?
        ORDER BY d.created_at DESC
        LIMIT 5
      ");
      $stmt->execute([$donorId]);
      $recentDonations = $stmt->fetchAll();
    }

    // Shelter requests created by this user
    $shelterRequestStats = [
      "PENDING" => 0,
      "CONFIRMED" => 0,
      "CANCELLED" => 0,
    ];

    $stmt = $pdo->prepare("
      SELECT status, COUNT(*) AS c
      FROM shelter_requests
      WHERE user_id = ?
      GROUP BY status
    ");
    $stmt->execute([$userId]);
    foreach ($stmt->fetchAll() as $row) {
      $shelterRequestStats[$row['status']] = (int)$row['c'];
    }

    $stmt = $pdo->prepare("
      SELECT 
        sr.request_id,
        sr.status,
        sr.total_people,
        sr.created_at,
        sr.confirmed_at,
        s.shelter_name,
        s.city,
        s.state
      FROM shelter_requests sr
      JOIN shelters s ON s.shelter_id = sr.shelter_id
      WHERE sr.user_id = ?
      ORDER BY sr.created_at DESC
      LIMIT 3
    ");
    $stmt->execute([$userId]);
    $recentShelterRequests = $stmt->fetchAll();

    // Dependents under user's main person
    $stmt = $pdo->prepare("
      SELECT COUNT(*) AS total
      FROM person_relationships pr
      JOIN users u ON u.person_id = pr.main_person_id
      WHERE u.user_id = ?
        AND pr.is_active = 1
        AND pr.relationship_type <> 'SELF'
    ");
    $stmt->execute([$userId]);
    $activeDependents = (int)$stmt->fetch()['total'];

    return Http::json($res, [
      "ok" => true,
      "summary" => [
        "total_shelters" => $totalShelters,
        "total_ngos" => $totalNgos,
        "total_shelter_capacity" => $totalCapacity,
        "total_shelter_occupancy" => $totalOccupancy,
        "available_shelter_capacity" => $availableCapacity,
        "my_donation_stats" => $myDonationStats,
        "my_donation_type_stats" => $myDonationTypeStats,
        "my_total_donation_amount" => $myTotalDonationAmount,
        "shelter_request_stats" => $shelterRequestStats,
        "active_dependents" => $activeDependents,
      ],
      "recent_donations" => $recentDonations,
      "recent_shelter_requests" => $recentShelterRequests
    ]);
  }

  // GET /dashboard/ngo  (NGO_STAFF or ADMIN)
  public function ngoDashboard(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];

    $pdo = Db::conn();

    $stmt = $pdo->prepare("SELECT ngo_id FROM ngo_staff WHERE user_id = ?");
    $stmt->execute([$userId]);
    $ngoIds = array_map(fn($r) => (int)$r['ngo_id'], $stmt->fetchAll());

    if (count($ngoIds) === 0) {
      return Http::json($res, [
        "ok" => true,
        "summary" => [
          "ngo_ids" => [],
          "deliveries_by_status" => [
            "PLANNED" => 0,
            "ROUTED" => 0,
            "IN_TRANSIT" => 0,
            "DELIVERED" => 0,
            "CANCELLED" => 0,
          ],
          "donations_by_status" => [
            "PENDING" => 0,
            "CONFIRMED" => 0,
            "COMPLETED" => 0,
            "CANCELLED" => 0,
          ],
          "donations_by_type" => [
            "MONEY" => 0,
            "ITEM" => 0,
          ],
          "total_money_received" => 0,
          "dropoff_waiting" => 0,
          "proof_uploaded" => 0,
          "upcoming_deliveries" => [],
          "recent_donations" => []
        ]
      ]);
    }

    $in = implode(',', array_fill(0, count($ngoIds), '?'));

    // Deliveries count by status
    $stmt = $pdo->prepare("
      SELECT status, COUNT(*) AS c
      FROM deliveries
      WHERE ngo_id IN ($in)
      GROUP BY status
    ");
    $stmt->execute($ngoIds);

    $deliveriesByStatus = [
      "PLANNED" => 0,
      "ROUTED" => 0,
      "IN_TRANSIT" => 0,
      "DELIVERED" => 0,
      "CANCELLED" => 0,
    ];

    foreach ($stmt->fetchAll() as $row) {
      $deliveriesByStatus[$row['status']] = (int)$row['c'];
    }

    // Donation count by status
    $stmt = $pdo->prepare("
      SELECT status, COUNT(*) AS c
      FROM donations
      WHERE ngo_id IN ($in)
      GROUP BY status
    ");
    $stmt->execute($ngoIds);

    $donationsByStatus = [
      "PENDING" => 0,
      "CONFIRMED" => 0,
      "COMPLETED" => 0,
      "CANCELLED" => 0,
    ];

    foreach ($stmt->fetchAll() as $row) {
      $donationsByStatus[$row['status']] = (int)$row['c'];
    }

    // Donation count by type
    $stmt = $pdo->prepare("
      SELECT donation_type, COUNT(*) AS c
      FROM donations
      WHERE ngo_id IN ($in)
      GROUP BY donation_type
    ");
    $stmt->execute($ngoIds);

    $donationsByType = [
      "MONEY" => 0,
      "ITEM" => 0,
    ];

    foreach ($stmt->fetchAll() as $row) {
      $donationsByType[$row['donation_type']] = (int)$row['c'];
    }

    // Total money received
    $stmt = $pdo->prepare("
      SELECT COALESCE(SUM(p.amount), 0) AS total_amount
      FROM donations d
      JOIN payments p ON p.donation_id = d.donation_id
      WHERE d.ngo_id IN ($in)
        AND d.donation_type = 'MONEY'
        AND d.status = 'COMPLETED'
        AND p.payment_status = 'PAID'
    ");
    $stmt->execute($ngoIds);
    $totalMoneyReceived = (float)$stmt->fetchColumn();

    // Drop-off waiting confirmation
    $stmt = $pdo->prepare("
      SELECT COUNT(*) AS total
      FROM donations
      WHERE ngo_id IN ($in)
        AND donation_type = 'ITEM'
        AND dropoff_required = 1
        AND dropoff_confirmed = 0
        AND status <> 'CANCELLED'
    ");
    $stmt->execute($ngoIds);
    $dropoffWaiting = (int)$stmt->fetch()['total'];

    // Proof uploaded count
    $stmt = $pdo->prepare("
      SELECT COUNT(*) AS total
      FROM donations
      WHERE ngo_id IN ($in)
        AND proof_photo_url IS NOT NULL
        AND proof_photo_url <> ''
    ");
    $stmt->execute($ngoIds);
    $proofUploaded = (int)$stmt->fetch()['total'];

    // Upcoming deliveries
    $stmt = $pdo->prepare("
      SELECT d.delivery_id, d.status, d.scheduled_date, d.created_at,
             d.distance_km, d.eta_minutes,
             s.shelter_name, s.city, s.state, s.latitude, s.longitude
      FROM deliveries d
      JOIN shelters s ON s.shelter_id = d.shelter_id
      WHERE d.ngo_id IN ($in)
      ORDER BY (d.scheduled_date IS NULL), d.scheduled_date ASC, d.created_at DESC
      LIMIT 8
    ");
    $stmt->execute($ngoIds);
    $upcoming = $stmt->fetchAll();

    // Recent donations
    $stmt = $pdo->prepare("
      SELECT 
        d.donation_id,
        d.donation_type,
        d.status,
        d.dropoff_required,
        d.dropoff_confirmed,
        d.proof_photo_url,
        d.created_at,
        d.remarks,
        n.ngo_name,
        p.full_name AS donor_name,
        p.email AS donor_email,
        p.phone AS donor_phone,
        pay.amount AS payment_amount,
        pay.currency AS payment_currency,
        pay.payment_status,
        pay.paid_at
      FROM donations d
      JOIN ngos n ON n.ngo_id = d.ngo_id
      LEFT JOIN donors dn ON dn.donor_id = d.donor_id
      LEFT JOIN persons p ON p.person_id = dn.person_id
      LEFT JOIN payments pay ON pay.donation_id = d.donation_id
      WHERE d.ngo_id IN ($in)
      ORDER BY d.created_at DESC
      LIMIT 6
    ");
    $stmt->execute($ngoIds);
    $recentDonations = $stmt->fetchAll();

    return Http::json($res, [
      "ok" => true,
      "summary" => [
        "ngo_ids" => $ngoIds,
        "deliveries_by_status" => $deliveriesByStatus,
        "donations_by_status" => $donationsByStatus,
        "donations_by_type" => $donationsByType,
        "total_money_received" => $totalMoneyReceived,
        "dropoff_waiting" => $dropoffWaiting,
        "proof_uploaded" => $proofUploaded,
        "upcoming_deliveries" => $upcoming,
        "recent_donations" => $recentDonations
      ]
    ]);
  }
}