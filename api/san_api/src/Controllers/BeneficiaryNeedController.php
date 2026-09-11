<?php

namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class BeneficiaryNeedController
{
    private function authUserId(Request $request): int
    {
        $auth = $request->getAttribute('auth') ?? [];
        return (int)($auth['user_id'] ?? $auth['id'] ?? 0);
    }

    private function getUserPersonId(\PDO $pdo, int $userId): int
    {
        $stmt = $pdo->prepare("
            SELECT person_id
            FROM users
            WHERE user_id = ?
            LIMIT 1
        ");
        $stmt->execute([$userId]);

        $personId = $stmt->fetchColumn();

        return $personId !== false ? (int)$personId : 0;
    }

    private function getActiveBeneficiaryForUser(\PDO $pdo, int $userId): ?array
    {
        $personId = $this->getUserPersonId($pdo, $userId);

        if ($personId <= 0) {
            return null;
        }

        $stmt = $pdo->prepare("
            SELECT 
                b.beneficiary_id,
                b.person_id,
                b.shelter_id,
                b.status,
                s.shelter_name,
                p.full_name
            FROM beneficiaries b
            JOIN shelters s ON s.shelter_id = b.shelter_id
            JOIN persons p ON p.person_id = b.person_id
            WHERE b.person_id = ?
              AND b.status = 'ACTIVE'
            ORDER BY b.beneficiary_id DESC
            LIMIT 1
        ");
        $stmt->execute([$personId]);

        $row = $stmt->fetch();

        return $row ?: null;
    }

    public function myStatus(Request $request, Response $response): Response
    {
        $userId = $this->authUserId($request);

        if ($userId <= 0) {
            return Http::json($response->withStatus(401), [
                'ok' => false,
                'error' => 'Unauthorized'
            ]);
        }

        $pdo = Db::conn();
        $beneficiary = $this->getActiveBeneficiaryForUser($pdo, $userId);

        return Http::json($response, [
            'ok' => true,
            'is_beneficiary' => $beneficiary !== null,
            'beneficiary' => $beneficiary
        ]);
    }

    public function my(Request $request, Response $response): Response
    {
        $userId = $this->authUserId($request);

        if ($userId <= 0) {
            return Http::json($response->withStatus(401), [
                'ok' => false,
                'error' => 'Unauthorized'
            ]);
        }

        $pdo = Db::conn();
        $beneficiary = $this->getActiveBeneficiaryForUser($pdo, $userId);

        if (!$beneficiary) {
            return Http::json($response, [
                'ok' => true,
                'is_beneficiary' => false,
                'needs' => []
            ]);
        }

        $stmt = $pdo->prepare("
            SELECT
                bn.need_id,
                bn.beneficiary_id,
                bn.item_id,
                ai.item_name,
                ai.unit,
                ac.category_name,
                bn.required_quantity,
                bn.priority,
                bn.request_status,
                bn.notes,
                bn.rejection_reason,
                bn.created_at,
                bn.reviewed_at,
                bn.fulfilled_at,
                s.shelter_id,
                s.shelter_name
            FROM beneficiary_needs bn
            JOIN aid_items ai ON ai.item_id = bn.item_id
            JOIN aid_categories ac ON ac.category_id = ai.category_id
            JOIN beneficiaries b ON b.beneficiary_id = bn.beneficiary_id
            JOIN shelters s ON s.shelter_id = b.shelter_id
            WHERE bn.beneficiary_id = ?
              AND bn.requested_by_user_id = ?
            ORDER BY bn.need_id DESC
        ");
        $stmt->execute([
            $beneficiary['beneficiary_id'],
            $userId
        ]);

        return Http::json($response, [
            'ok' => true,
            'is_beneficiary' => true,
            'beneficiary' => $beneficiary,
            'needs' => $stmt->fetchAll()
        ]);
    }

    public function create(Request $request, Response $response): Response
    {
        $userId = $this->authUserId($request);

        if ($userId <= 0) {
            return Http::json($response->withStatus(401), [
                'ok' => false,
                'error' => 'Unauthorized'
            ]);
        }

        $data = (array)$request->getParsedBody();

        $itemId = (int)($data['item_id'] ?? 0);
        $quantity = (int)($data['required_quantity'] ?? 0);
        $priority = strtoupper(trim($data['priority'] ?? 'MEDIUM'));
        $notes = trim($data['notes'] ?? '');

        if ($itemId <= 0) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Please select an aid item'
            ]);
        }

        if ($quantity <= 0) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Required quantity must be at least 1'
            ]);
        }

        $allowedPriority = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

        if (!in_array($priority, $allowedPriority, true)) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Invalid priority'
            ]);
        }

        $pdo = Db::conn();

        $beneficiary = $this->getActiveBeneficiaryForUser($pdo, $userId);

        if (!$beneficiary) {
            return Http::json($response->withStatus(403), [
                'ok' => false,
                'error' => 'Only active beneficiaries can submit aid requests'
            ]);
        }

        $stmt = $pdo->prepare("
            SELECT item_id
            FROM aid_items
            WHERE item_id = ?
              AND is_active = 1
            LIMIT 1
        ");
        $stmt->execute([$itemId]);

        if (!$stmt->fetch()) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Selected aid item is invalid or inactive'
            ]);
        }

        $stmt = $pdo->prepare("
            INSERT INTO beneficiary_needs (
                beneficiary_id,
                item_id,
                required_quantity,
                priority,
                request_status,
                requested_by_user_id,
                notes,
                created_at
            ) VALUES (
                :beneficiary_id,
                :item_id,
                :required_quantity,
                :priority,
                'SUBMITTED',
                :requested_by_user_id,
                :notes,
                CURRENT_TIMESTAMP
            )
        ");

        $stmt->execute([
            ':beneficiary_id' => (int)$beneficiary['beneficiary_id'],
            ':item_id' => $itemId,
            ':required_quantity' => $quantity,
            ':priority' => $priority,
            ':requested_by_user_id' => $userId,
            ':notes' => $notes !== '' ? $notes : null,
        ]);

        return Http::json($response, [
            'ok' => true,
            'need_id' => (int)$pdo->lastInsertId(),
            'message' => 'Aid request submitted successfully'
        ]);
    }

    public function unmetForNgo(Request $request, Response $response): Response
    {
        $pdo = Db::conn();

        $stmt = $pdo->prepare("
            SELECT
                bn.need_id,
                bn.beneficiary_id,
                bn.item_id,
                ai.item_name,
                ai.unit,
                ac.category_name,
                bn.required_quantity,
                bn.priority,
                bn.request_status,
                bn.notes,
                bn.created_at,
                b.shelter_id,
                s.shelter_name,
                s.city,
                s.state
            FROM beneficiary_needs bn
            JOIN beneficiaries b ON b.beneficiary_id = bn.beneficiary_id
            JOIN shelters s ON s.shelter_id = b.shelter_id
            JOIN aid_items ai ON ai.item_id = bn.item_id
            JOIN aid_categories ac ON ac.category_id = ai.category_id
            WHERE bn.request_status = 'AWAITING_DONATION'
            ORDER BY
                CASE bn.priority
                    WHEN 'CRITICAL' THEN 1
                    WHEN 'HIGH' THEN 2
                    WHEN 'MEDIUM' THEN 3
                    WHEN 'LOW' THEN 4
                    ELSE 5
                END,
                bn.created_at ASC
        ");

        $stmt->execute();

        return Http::json($response, [
            'ok' => true,
            'needs' => $stmt->fetchAll()
        ]);
    }
}