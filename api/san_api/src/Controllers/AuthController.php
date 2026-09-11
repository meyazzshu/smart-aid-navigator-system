<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use App\Auth\JwtHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class AuthController {

  // POST /auth/register  (PUBLIC)
  public function register(Request $req, Response $res): Response {
    $body = (array)$req->getParsedBody();
    $full_name = trim($body['full_name'] ?? '');
    $email = strtolower(trim($body['email'] ?? ''));
    $phone = trim($body['phone'] ?? '');
    $password = $body['password'] ?? '';

    if ($full_name === '' || $email === '' || $password === '') {
      return Http::json($res, ["ok"=>false,"error"=>"Missing full_name/email/password"], 400);
    }

    $pdo = Db::conn();
    $roleStmt = $pdo->prepare("SELECT role_id FROM roles WHERE role_name = 'PUBLIC' LIMIT 1");
    $roleStmt->execute();
    $publicRoleId = (int)$roleStmt->fetchColumn();
    if ($publicRoleId <= 0) {
      return Http::json($res, ["ok"=>false,"error"=>"PUBLIC role missing"], 500);
    }

    $stmt = $pdo->prepare("
      SELECT u.user_id, u.person_id, u.is_guest
      FROM users u
      JOIN persons p ON p.person_id = u.person_id
      WHERE LOWER(p.email) = ?
      LIMIT 1
    ");
    $stmt->execute([$email]);
    $existingUser = $stmt->fetch();

    if ($existingUser) {
      if ((int)$existingUser['is_guest'] === 1) {
        $hash = password_hash($password, PASSWORD_BCRYPT);
        $userId = (int)$existingUser['user_id'];
        $personId = (int)$existingUser['person_id'];

        $stmt = $pdo->prepare("
          UPDATE users
          SET password_hash = ?, is_guest = 0, is_active = 1
          WHERE user_id = ?
        ");
        $stmt->execute([$hash, $userId]);

        $stmt = $pdo->prepare("
          UPDATE persons
          SET full_name = ?, phone = ?, email = ?, updated_at = CURRENT_TIMESTAMP
          WHERE person_id = ?
        ");
        $stmt->execute([
          $full_name,
          $phone !== '' ? $phone : null,
          $email,
          $personId
        ]);

        $stmt = $pdo->prepare("
          INSERT IGNORE INTO user_roles(user_id, role_id)
          VALUES(?, ?)
        ");
        $stmt->execute([$userId, $publicRoleId]);

        return Http::json($res, [
          "ok" => true,
          "message" => "Guest account upgraded successfully",
          "user_id" => $userId
        ], 200);
      }

      return Http::json($res, ["ok"=>false,"error"=>"Email already exists"], 409);
    }

    $hash = password_hash($password, PASSWORD_BCRYPT);
    $pdo->beginTransaction();
    try {
      $stmt = $pdo->prepare("
        INSERT INTO persons(full_name, email, phone)
        VALUES(?,?,?)
      ");
      $stmt->execute([$full_name, $email, $phone !== '' ? $phone : null]);
      $personId = (int)$pdo->lastInsertId();

      $stmt = $pdo->prepare("
        INSERT INTO users(person_id, password_hash, is_guest)
        VALUES(?,?,0)
      ");
      $stmt->execute([$personId, $hash]);
      $userId = (int)$pdo->lastInsertId();

      $stmt = $pdo->prepare("INSERT INTO user_roles(user_id, role_id) VALUES(?,?)");
      $stmt->execute([$userId, $publicRoleId]);

      $pdo->commit();
    } catch (\Throwable $e) {
      $pdo->rollBack();
      return Http::json($res, ["ok"=>false,"error"=>"Registration failed"], 500);
    }

    return Http::json($res, ["ok"=>true, "user_id"=>$userId], 201);
  }

  // POST /auth/login (NGO or PUBLIC)
  public function login(Request $req, Response $res): Response {
    $body = (array)$req->getParsedBody();
    $email = strtolower(trim($body['email'] ?? ''));
    $password = $body['password'] ?? '';

    if ($email === '' || $password === '') {
      return Http::json($res, ["ok"=>false,"error"=>"Missing email/password"], 400);
    }

    $pdo = Db::conn();

    $stmt = $pdo->prepare("
      SELECT u.user_id, u.person_id, u.password_hash, u.is_active,
             p.full_name, p.email, p.phone
      FROM users u
      JOIN persons p ON p.person_id = u.person_id
      WHERE LOWER(p.email) = ?
      LIMIT 1
    ");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'])) {
      return Http::json($res, ["ok"=>false,"error"=>"Invalid credentials"], 401);
    }

    if ((int)$user['is_active'] !== 1) {
      return Http::json($res, ["ok"=>false,"error"=>"Account disabled"], 403);
    }

    // Fetch role_name
    $stmt = $pdo->prepare("
      SELECT r.role_name
      FROM user_roles ur
      JOIN roles r ON r.role_id = ur.role_id
      WHERE ur.user_id = ?
      ORDER BY FIELD(r.role_name, 'ADMIN', 'NGO_STAFF', 'SHELTER_MANAGER', 'PUBLIC')
      LIMIT 1
    ");
    $stmt->execute([(int)$user['user_id']]);
    $role = $stmt->fetchColumn();

    if (!$role) {
      return Http::json($res, ["ok"=>false,"error"=>"No role assigned"], 500);
    }

    error_log("LOGIN DEBUG JwtHelper file: " . (new \ReflectionClass(JwtHelper::class))->getFileName());
    error_log("LOGIN DEBUG JWT_SECRET first 6: " . substr($_ENV['JWT_SECRET'] ?? 'MISSING', 0, 6));

    $token = JwtHelper::sign([
      "user_id" => (int)$user['user_id'],
      "person_id" => (int)$user['person_id'],
      "role" => $role,
      "email" => $user['email']
    ]);

    return Http::json($res, [
      "ok" => true,
      "token" => $token,
      "user" => [
        "user_id" => (int)$user['user_id'],
        "full_name" => $user['full_name'],
        "email" => $user['email'],
        "phone" => $user['phone'],
        "role" => $role
      ]
    ]);
  }

  // GET /auth/me (requires token)
  public function me(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $pdo = Db::conn();
    $userId = (int)($auth['user_id'] ?? 0);
    if ($userId <= 0) {
      return Http::json($res, ["ok"=>false, "error"=>"Unauthorized"], 401);
    }

    $stmt = $pdo->prepare("
      SELECT u.user_id, u.person_id, u.is_active, u.is_guest, u.created_at,
            p.full_name, p.email, p.phone,
            p.ic_or_passport, p.gender, p.date_of_birth,
            p.address_line, p.city, p.state, p.postal_code
      FROM users u
      JOIN persons p ON p.person_id = u.person_id
      WHERE u.user_id = ?
      LIMIT 1
    ");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();
    if (!$user) {
      return Http::json($res, ["ok"=>false, "error"=>"User not found"], 404);
    }

    $stmt = $pdo->prepare("
      SELECT r.role_name
      FROM user_roles ur
      JOIN roles r ON r.role_id = ur.role_id
      WHERE ur.user_id = ?
      ORDER BY FIELD(r.role_name, 'ADMIN', 'NGO_STAFF', 'SHELTER_MANAGER', 'PUBLIC')
    ");
    $stmt->execute([$userId]);
    $roles = array_map(fn($row) => $row['role_name'], $stmt->fetchAll());

    return Http::json($res, [
      "ok" => true,
      "user" => [
        "user_id" => (int)$user['user_id'],
        "person_id" => (int)$user['person_id'],
        "full_name" => $user['full_name'],
        "email" => $user['email'],
        "phone" => $user['phone'],
        "is_active" => (int)$user['is_active'],
        "is_guest" => (int)$user['is_guest'],
        "roles" => $roles,

        // Also expose address directly under user for existing Flutter parser
        "address_line" => $user['address_line'],
        "city" => $user['city'],
        "state" => $user['state'],
        "postal_code" => $user['postal_code'],

        // Optional extra personal fields
        "ic_or_passport" => $user['ic_or_passport'],
        "gender" => $user['gender'],
        "date_of_birth" => $user['date_of_birth'],
      ],
      "person" => [
        "person_id" => (int)$user['person_id'],
        "full_name" => $user['full_name'],
        "email" => $user['email'],
        "phone" => $user['phone'],
        "ic_or_passport" => $user['ic_or_passport'],
        "gender" => $user['gender'],
        "date_of_birth" => $user['date_of_birth'],
        "address_line" => $user['address_line'],
        "city" => $user['city'],
        "state" => $user['state'],
        "postal_code" => $user['postal_code'],
      ]
    ]);
  }
}
