<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class DependentsController {
  private const ALLOWED_RELATIONSHIPS = [
    'SELF',
    'CHILD',
    'SPOUSE',
    'PARENT',
    'SIBLING',
    'GRANDCHILD',
    'EXTENDED_FAMILY',
    'OTHER'
  ];

  private function mainPersonId(Request $request, \PDO $pdo): ?int {
    $auth = $request->getAttribute('auth') ?? [];
    $userId = (int)($auth['user_id'] ?? 0);
    if ($userId <= 0) {
      return null;
    }
    $stmt = $pdo->prepare("SELECT person_id FROM users WHERE user_id = ? LIMIT 1");
    $stmt->execute([$userId]);
    $personId = $stmt->fetchColumn();
    return $personId !== false ? (int)$personId : null;
  }

  private function ensureSelfRelationship(\PDO $pdo, int $mainPersonId): void {
    $stmt = $pdo->prepare("
      SELECT relationship_id
      FROM person_relationships
      WHERE main_person_id = ?
        AND related_person_id = ?
        AND relationship_type = 'SELF'
      LIMIT 1
    ");
    $stmt->execute([$mainPersonId, $mainPersonId]);

    if ($stmt->fetchColumn()) {
      return;
    }

    $stmt = $pdo->prepare("
      INSERT INTO person_relationships(main_person_id, related_person_id, relationship_type, is_active)
      VALUES(?, ?, 'SELF', 1)
    ");
    $stmt->execute([$mainPersonId, $mainPersonId]);
  }

  private function readDependent(\PDO $pdo, int $mainPersonId, int $relationshipId): ?array {
    $stmt = $pdo->prepare("
      SELECT pr.relationship_id, pr.main_person_id, pr.related_person_id, pr.relationship_type, pr.is_active, pr.created_at,
             p.full_name, p.ic_or_passport, p.phone, p.email, p.gender, p.date_of_birth,
             p.address_line, p.city, p.state, p.postal_code
      FROM person_relationships pr
      JOIN persons p ON p.person_id = pr.related_person_id
      WHERE pr.relationship_id = ? AND pr.main_person_id = ?
      LIMIT 1
    ");
    $stmt->execute([$relationshipId, $mainPersonId]);
    $row = $stmt->fetch();
    return $row ?: null;
  }

  public function list(Request $request, Response $response): Response {
    $pdo = Db::conn();
    $mainPersonId = $this->mainPersonId($request, $pdo);
    if (!$mainPersonId) {
      return Http::json($response, ['ok' => false, 'error' => 'Unauthorized'], 401);
    }

    $this->ensureSelfRelationship($pdo, $mainPersonId);

    $q = $request->getQueryParams();
    $includeInactive = (int)($q['include_inactive'] ?? 0) === 1;

    $sql = "
      SELECT pr.relationship_id, pr.relationship_type, pr.is_active, pr.created_at,
             p.person_id, p.full_name, p.ic_or_passport, p.phone, p.email, p.gender, p.date_of_birth,
             p.address_line, p.city, p.state, p.postal_code
      FROM person_relationships pr
      JOIN persons p ON p.person_id = pr.related_person_id
      WHERE pr.main_person_id = ?
    ";
    if (!$includeInactive) {
      $sql .= " AND pr.is_active = 1";
    }
    $sql .= "
      ORDER BY 
        CASE WHEN pr.relationship_type = 'SELF' THEN 0 ELSE 1 END,
        pr.created_at DESC
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([$mainPersonId]);
    return Http::json($response, ['ok' => true, 'dependents' => $stmt->fetchAll()]);
  }

  public function get(Request $request, Response $response, array $args): Response {
    $relationshipId = (int)($args['id'] ?? 0);
    if ($relationshipId <= 0) {
      return Http::json($response, ['ok' => false, 'error' => 'Invalid dependent id'], 400);
    }

    $pdo = Db::conn();
    $mainPersonId = $this->mainPersonId($request, $pdo);
    if (!$mainPersonId) {
      return Http::json($response, ['ok' => false, 'error' => 'Unauthorized'], 401);
    }

    $dependent = $this->readDependent($pdo, $mainPersonId, $relationshipId);
    if (!$dependent) {
      return Http::json($response, ['ok' => false, 'error' => 'Dependent not found'], 404);
    }

    return Http::json($response, ['ok' => true, 'dependent' => $dependent]);
  }

  public function create(Request $request, Response $response): Response {
    $body = (array)$request->getParsedBody();
    $fullName = trim($body['full_name'] ?? '');
    $relationshipType = strtoupper(trim($body['relationship_type'] ?? 'DEPENDENT'));
    if ($fullName === '') {
      return Http::json($response, ['ok' => false, 'error' => 'full_name is required'], 400);
    }
    if (!in_array($relationshipType, self::ALLOWED_RELATIONSHIPS, true)) {
      return Http::json($response, ['ok' => false, 'error' => 'Invalid relationship_type'], 400);
    }
    if ($relationshipType === 'SELF') {
      return Http::json($response, [
        'ok' => false,
        'error' => 'SELF dependent is created automatically from your account profile'
      ], 400);
    }

    $pdo = Db::conn();
    $mainPersonId = $this->mainPersonId($request, $pdo);
    if (!$mainPersonId) {
      return Http::json($response, ['ok' => false, 'error' => 'Unauthorized'], 401);
    }

    $pdo->beginTransaction();
    try {
      $stmt = $pdo->prepare("
        INSERT INTO persons(full_name, ic_or_passport, phone, email, gender, date_of_birth, address_line, city, state, postal_code)
        VALUES(?,?,?,?,?,?,?,?,?,?)
      ");
      $stmt->execute([
        $fullName,
        trim($body['ic_or_passport'] ?? '') ?: null,
        trim($body['phone'] ?? '') ?: null,
        strtolower(trim($body['email'] ?? '')) ?: null,
        trim($body['gender'] ?? '') ?: null,
        trim($body['date_of_birth'] ?? '') ?: null,
        trim($body['address_line'] ?? '') ?: null,
        trim($body['city'] ?? '') ?: null,
        trim($body['state'] ?? '') ?: null,
        trim($body['postal_code'] ?? '') ?: null
      ]);
      $relatedPersonId = (int)$pdo->lastInsertId();

      $stmt = $pdo->prepare("
        INSERT INTO person_relationships(main_person_id, related_person_id, relationship_type, is_active)
        VALUES(?,?,?,1)
      ");
      $stmt->execute([$mainPersonId, $relatedPersonId, $relationshipType]);
      $relationshipId = (int)$pdo->lastInsertId();
      $pdo->commit();
    } catch (\Throwable $e) {
      $pdo->rollBack();
      return Http::json($response, ['ok' => false, 'error' => 'Failed to create dependent'], 500);
    }

    return Http::json($response, ['ok' => true, 'relationship_id' => $relationshipId, 'person_id' => $relatedPersonId], 201);
  }

  public function update(Request $request, Response $response, array $args): Response {
    $relationshipId = (int)($args['id'] ?? 0);
    if ($relationshipId <= 0) {
      return Http::json($response, ['ok' => false, 'error' => 'Invalid dependent id'], 400);
    }

    $body = (array)$request->getParsedBody();
    $pdo = Db::conn();
    $mainPersonId = $this->mainPersonId($request, $pdo);
    if (!$mainPersonId) {
      return Http::json($response, ['ok' => false, 'error' => 'Unauthorized'], 401);
    }

    $dependent = $this->readDependent($pdo, $mainPersonId, $relationshipId);
    if (!$dependent) {
      return Http::json($response, ['ok' => false, 'error' => 'Dependent not found'], 404);
    }

    $currentRelationshipType = strtoupper(trim($dependent['relationship_type'] ?? ''));
    $relationshipType = strtoupper(trim($body['relationship_type'] ?? $currentRelationshipType));

    if ($currentRelationshipType === 'SELF') {
      $relationshipType = 'SELF';
    } elseif ($relationshipType === 'SELF') {
      return Http::json($response, [
        'ok' => false,
        'error' => 'SELF relationship is reserved for the account owner'
      ], 400);
    }

    if (!in_array($relationshipType, self::ALLOWED_RELATIONSHIPS, true)) {
      return Http::json($response, ['ok' => false, 'error' => 'Invalid relationship_type'], 400);
    }

    $pdo->beginTransaction();
    try {
      $stmt = $pdo->prepare("
        UPDATE persons
        SET full_name = ?, ic_or_passport = ?, phone = ?, email = ?, gender = ?, date_of_birth = ?,
            address_line = ?, city = ?, state = ?, postal_code = ?, updated_at = CURRENT_TIMESTAMP
        WHERE person_id = ?
      ");
      $stmt->execute([
        trim($body['full_name'] ?? $dependent['full_name']),
        trim($body['ic_or_passport'] ?? $dependent['ic_or_passport']) ?: null,
        trim($body['phone'] ?? $dependent['phone']) ?: null,
        strtolower(trim($body['email'] ?? $dependent['email'])) ?: null,
        trim($body['gender'] ?? $dependent['gender']) ?: null,
        trim($body['date_of_birth'] ?? $dependent['date_of_birth']) ?: null,
        trim($body['address_line'] ?? $dependent['address_line']) ?: null,
        trim($body['city'] ?? $dependent['city']) ?: null,
        trim($body['state'] ?? $dependent['state']) ?: null,
        trim($body['postal_code'] ?? $dependent['postal_code']) ?: null,
        (int)$dependent['related_person_id']
      ]);

      $stmt = $pdo->prepare("
        UPDATE person_relationships
        SET relationship_type = ?, is_active = ?
        WHERE relationship_id = ? AND main_person_id = ?
      ");
      $stmt->execute([
        $relationshipType,
        isset($body['is_active']) ? ((int)$body['is_active'] === 1 ? 1 : 0) : (int)$dependent['is_active'],
        $relationshipId,
        $mainPersonId
      ]);
      $pdo->commit();
    } catch (\Throwable $e) {
      $pdo->rollBack();
      return Http::json($response, ['ok' => false, 'error' => 'Failed to update dependent'], 500);
    }

    $updated = $this->readDependent($pdo, $mainPersonId, $relationshipId);
    return Http::json($response, ['ok' => true, 'dependent' => $updated]);
  }

  public function deactivate(Request $request, Response $response, array $args): Response {
    $relationshipId = (int)($args['id'] ?? 0);
    if ($relationshipId <= 0) {
      return Http::json($response, ['ok' => false, 'error' => 'Invalid dependent id'], 400);
    }

    $pdo = Db::conn();
    $mainPersonId = $this->mainPersonId($request, $pdo);
    if (!$mainPersonId) {
      return Http::json($response, ['ok' => false, 'error' => 'Unauthorized'], 401);
    }

    $dependent = $this->readDependent($pdo, $mainPersonId, $relationshipId);

    if (!$dependent) {
      return Http::json($response, ['ok' => false, 'error' => 'Dependent not found'], 404);
    }

    if (($dependent['relationship_type'] ?? '') === 'SELF') {
      return Http::json($response, [
        'ok' => false,
        'error' => 'You cannot delete your own account profile from dependents'
      ], 400);
    }

    $stmt = $pdo->prepare("
      UPDATE person_relationships
      SET is_active = 0
      WHERE relationship_id = ? AND main_person_id = ?
    ");
    $stmt->execute([$relationshipId, $mainPersonId]);

    return Http::json($response, ['ok' => true]);
  }
}
