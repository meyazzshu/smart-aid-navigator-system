<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ProfileController {

  // GET /profile/me
  public function me(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)($auth['user_id'] ?? 0);

    if ($userId <= 0) {
      return Http::json($res, [
        "ok" => false,
        "error" => "Unauthorized"
      ], 401);
    }

    $pdo = Db::conn();

    $stmt = $pdo->prepare("
      SELECT 
        u.user_id,
        u.person_id,
        u.is_active,
        u.is_guest,
        u.created_at,

        p.full_name,
        p.ic_or_passport,
        p.email,
        p.phone,
        p.gender,
        p.date_of_birth,
        p.address_line,
        p.city,
        p.state,
        p.postal_code,
        p.updated_at
      FROM users u
      JOIN persons p ON p.person_id = u.person_id
      WHERE u.user_id = ?
      LIMIT 1
    ");
    $stmt->execute([$userId]);
    $row = $stmt->fetch();

    if (!$row) {
      return Http::json($res, [
        "ok" => false,
        "error" => "Profile not found"
      ], 404);
    }

    $roleStmt = $pdo->prepare("
      SELECT r.role_name
      FROM user_roles ur
      JOIN roles r ON r.role_id = ur.role_id
      WHERE ur.user_id = ?
      ORDER BY FIELD(r.role_name, 'ADMIN', 'NGO_STAFF', 'SHELTER_MANAGER', 'PUBLIC')
      LIMIT 1
    ");
    $roleStmt->execute([$userId]);
    $role = $roleStmt->fetchColumn() ?: '';

    $org = null;

    if ($role === 'NGO_STAFF') {
      $orgStmt = $pdo->prepare("
        SELECT 
          n.ngo_id,
          n.ngo_name,
          ns.staff_title
        FROM ngo_staff ns
        JOIN ngos n ON n.ngo_id = ns.ngo_id
        WHERE ns.user_id = ?
        LIMIT 1
      ");
      $orgStmt->execute([$userId]);
      $org = $orgStmt->fetch() ?: null;
    }

    if ($role === 'SHELTER_MANAGER') {
      $orgStmt = $pdo->prepare("
        SELECT 
          s.shelter_id,
          s.shelter_name,
          s.ngo_id,
          n.ngo_name
        FROM shelter_managers sm
        JOIN shelters s ON s.shelter_id = sm.shelter_id
        LEFT JOIN ngos n ON n.ngo_id = s.ngo_id
        WHERE sm.user_id = ?
        LIMIT 1
      ");
      $orgStmt->execute([$userId]);
      $org = $orgStmt->fetch() ?: null;
    }

    return Http::json($res, [
      "ok" => true,
      "profile" => [
        "user_id" => (int)$row['user_id'],
        "person_id" => (int)$row['person_id'],
        "role" => $role,
        "is_active" => (int)$row['is_active'],
        "is_guest" => (int)$row['is_guest'],

        "full_name" => $row['full_name'],
        "ic_or_passport" => $row['ic_or_passport'],
        "email" => $row['email'],
        "phone" => $row['phone'],
        "gender" => $row['gender'],
        "date_of_birth" => $row['date_of_birth'],
        "address_line" => $row['address_line'],
        "city" => $row['city'],
        "state" => $row['state'],
        "postal_code" => $row['postal_code'],

        "created_at" => $row['created_at'],
        "updated_at" => $row['updated_at'],
        "organization" => $org,
      ]
    ]);
  }

  // PATCH /profile/me
  public function update(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)($auth['user_id'] ?? 0);

    if ($userId <= 0) {
      return Http::json($res, [
        "ok" => false,
        "error" => "Unauthorized"
      ], 401);
    }

    $body = (array)$req->getParsedBody();

    $fullName = trim($body['full_name'] ?? '');
    $icOrPassport = trim($body['ic_or_passport'] ?? '');
    $phone = trim($body['phone'] ?? '');
    $gender = strtoupper(trim($body['gender'] ?? ''));
    $dateOfBirth = trim($body['date_of_birth'] ?? '');
    $addressLine = trim($body['address_line'] ?? '');
    $city = trim($body['city'] ?? '');
    $state = trim($body['state'] ?? '');
    $postalCode = trim($body['postal_code'] ?? '');

    if ($fullName === '') {
      return Http::json($res, [
        "ok" => false,
        "error" => "Full name is required"
      ], 400);
    }

    $allowedGender = ['', 'MALE', 'FEMALE', 'OTHER'];
    if (!in_array($gender, $allowedGender, true)) {
      return Http::json($res, [
        "ok" => false,
        "error" => "Invalid gender"
      ], 400);
    }

    if ($dateOfBirth !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateOfBirth)) {
      return Http::json($res, [
        "ok" => false,
        "error" => "Date of birth must be YYYY-MM-DD"
      ], 400);
    }

    $pdo = Db::conn();

    $stmt = $pdo->prepare("
      SELECT person_id
      FROM users
      WHERE user_id = ?
      LIMIT 1
    ");
    $stmt->execute([$userId]);
    $personId = $stmt->fetchColumn();

    if (!$personId) {
      return Http::json($res, [
        "ok" => false,
        "error" => "User profile not found"
      ], 404);
    }

    /*
      Check IC/passport unique only if user fills it.
    */
    if ($icOrPassport !== '') {
      $stmt = $pdo->prepare("
        SELECT person_id
        FROM persons
        WHERE ic_or_passport = ?
          AND person_id <> ?
        LIMIT 1
      ");
      $stmt->execute([$icOrPassport, $personId]);

      if ($stmt->fetch()) {
        return Http::json($res, [
          "ok" => false,
          "error" => "IC/Passport already belongs to another profile"
        ], 409);
      }
    }

    $stmt = $pdo->prepare("
      UPDATE persons
      SET 
        full_name = :full_name,
        ic_or_passport = :ic_or_passport,
        phone = :phone,
        gender = :gender,
        date_of_birth = :date_of_birth,
        address_line = :address_line,
        city = :city,
        state = :state,
        postal_code = :postal_code,
        updated_at = CURRENT_TIMESTAMP
      WHERE person_id = :person_id
    ");

    $stmt->execute([
      ':full_name' => $fullName,
      ':ic_or_passport' => $icOrPassport !== '' ? $icOrPassport : null,
      ':phone' => $phone !== '' ? $phone : null,
      ':gender' => $gender !== '' ? $gender : null,
      ':date_of_birth' => $dateOfBirth !== '' ? $dateOfBirth : null,
      ':address_line' => $addressLine !== '' ? $addressLine : null,
      ':city' => $city !== '' ? $city : null,
      ':state' => $state !== '' ? $state : null,
      ':postal_code' => $postalCode !== '' ? $postalCode : null,
      ':person_id' => $personId,
    ]);

    return Http::json($res, [
      "ok" => true,
      "message" => "Profile updated successfully"
    ]);
  }

  // GET /profile/lookups
  public function lookups(Request $req, Response $res): Response {
    $pdo = Db::conn();

    /*
      Data-backed state/city dropdown:
      - Pulls values already used in persons, shelters, and NGOs.
      - Adds Malaysia state fallback values so dropdown is not empty.
    */
    $states = [
      'Johor',
      'Kedah',
      'Kelantan',
      'Kuala Lumpur',
      'Labuan',
      'Melaka',
      'Negeri Sembilan',
      'Pahang',
      'Penang',
      'Perak',
      'Perlis',
      'Putrajaya',
      'Sabah',
      'Sarawak',
      'Selangor',
      'Terengganu'
    ];

    $stateStmt = $pdo->query("
      SELECT DISTINCT state
      FROM (
        SELECT state FROM persons WHERE state IS NOT NULL AND state <> ''
        UNION
        SELECT state FROM shelters WHERE state IS NOT NULL AND state <> ''
        UNION
        SELECT state FROM ngos WHERE state IS NOT NULL AND state <> ''
      ) x
      ORDER BY state ASC
    ");

    foreach ($stateStmt->fetchAll() as $row) {
      $value = trim($row['state'] ?? '');
      if ($value !== '' && !in_array($value, $states, true)) {
        $states[] = $value;
      }
    }

    sort($states);

    $cityStmt = $pdo->query("
      SELECT DISTINCT city
      FROM (
        SELECT city FROM persons WHERE city IS NOT NULL AND city <> ''
        UNION
        SELECT city FROM shelters WHERE city IS NOT NULL AND city <> ''
        UNION
        SELECT city FROM ngos WHERE city IS NOT NULL AND city <> ''
      ) x
      ORDER BY city ASC
    ");

    $cities = [];
    foreach ($cityStmt->fetchAll() as $row) {
      $value = trim($row['city'] ?? '');
      if ($value !== '') {
        $cities[] = $value;
      }
    }

    return Http::json($res, [
      "ok" => true,
      "lookups" => [
        "genders" => [
          ["value" => "MALE", "label" => "Male"],
          ["value" => "FEMALE", "label" => "Female"],
          ["value" => "OTHER", "label" => "Other"],
        ],
        "states" => $states,
        "cities" => $cities,
      ]
    ]);
  }
}