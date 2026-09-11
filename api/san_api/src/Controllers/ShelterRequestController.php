<?php

namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ShelterRequestController
{
    public function guest(Request $request, Response $response, $args)
    {
        $data = (array)$request->getParsedBody();
        $pdo = Db::conn();

        $fullName = trim($data['full_name'] ?? '');
        $email = strtolower(trim($data['email'] ?? ''));
        $phone = trim($data['phone'] ?? '');

        if ($fullName === '' || ($email === '' && $phone === '')) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Full name and either email or phone are required'
            ]);
        }

        $pdo->beginTransaction();

        try {
            $person = null;
            if ($email !== '') {
                $stmt = $pdo->prepare("SELECT person_id FROM persons WHERE LOWER(email) = ? LIMIT 1");
                $stmt->execute([$email]);
            } else {
                $stmt = $pdo->prepare("SELECT person_id FROM persons WHERE phone = ? LIMIT 1");
                $stmt->execute([$phone]);
            }
            $person = $stmt->fetch();

            if ($person) {
                $personId = (int)$person['person_id'];
                $stmt = $pdo->prepare("
                    UPDATE persons
                    SET full_name = ?, phone = COALESCE(?, phone), email = COALESCE(?, email), updated_at = CURRENT_TIMESTAMP
                    WHERE person_id = ?
                ");
                $stmt->execute([
                    $fullName,
                    $phone !== '' ? $phone : null,
                    $email !== '' ? $email : null,
                    $personId
                ]);
            } else {
                $stmt = $pdo->prepare("
                    INSERT INTO persons (
                        full_name,
                        email,
                        phone
                    ) VALUES (?, ?, ?)
                ");
                $stmt->execute([
                    $fullName,
                    $email !== '' ? $email : null,
                    $phone !== '' ? $phone : null
                ]);
                $personId = (int)$pdo->lastInsertId();
            }

            $stmt = $pdo->prepare("SELECT user_id FROM users WHERE person_id = ? LIMIT 1");
            $stmt->execute([$personId]);
            $existingUser = $stmt->fetch();
            if ($existingUser) {
                $userId = (int)$existingUser['user_id'];
            } else {
                $stmt = $pdo->prepare("
                    INSERT INTO users (person_id, password_hash, is_active, is_guest)
                    VALUES (?, NULL, 1, 1)
                ");
                $stmt->execute([$personId]);
                $userId = (int)$pdo->lastInsertId();
            }

            $stmt = $pdo->prepare("
                INSERT INTO shelter_requests (
                    shelter_id,
                    babies_male,
                    babies_female,
                    kids_male,
                    kids_female,
                    adult_male,
                    adult_female,
                    total_people,
                    user_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");

            $stmt->execute([
                $data['shelter_id'],
                $data['babies_male'] ?? 0,
                $data['babies_female'] ?? 0,
                $data['kids_male'] ?? 0,
                $data['kids_female'] ?? 0,
                $data['adult_male'] ?? 0,
                $data['adult_female'] ?? 0,
                $data['total_people'] ?? 0,
                $userId
            ]);

            $requestId = $pdo->lastInsertId();

            $pdo->commit();

            return Http::json($response, [
                'ok' => true,
                'request_id' => $requestId,
                'message' => 'Guest shelter request received'
            ]);
        } catch (\Throwable $e) {
            $pdo->rollBack();

            return Http::json($response->withStatus(500), [
                'ok' => false,
                'error' => $e->getMessage()
            ]);
        }
    }

    private function authUserId(Request $request): int
    {
        $auth = $request->getAttribute('auth') ?? [];
        return (int)($auth['user_id'] ?? $auth['id'] ?? 0);
    }

    private function authPersonId(Request $request, \PDO $pdo): int
    {
        $auth = $request->getAttribute('auth') ?? [];

        if (!empty($auth['person_id'])) {
            return (int)$auth['person_id'];
        }

        $userId = $this->authUserId($request);

        if ($userId <= 0) {
            return 0;
        }

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

    private function attachDependentsToRequests(\PDO $pdo, array $requests): array
    {
        if (empty($requests)) {
            return $requests;
        }

        $requestIds = [];

        foreach ($requests as $requestRow) {
            if (!empty($requestRow['request_id'])) {
                $requestIds[] = (int)$requestRow['request_id'];
            }
        }

        if (empty($requestIds)) {
            return $requests;
        }

        $placeholders = implode(',', array_fill(0, count($requestIds), '?'));

        $stmt = $pdo->prepare("
            SELECT 
                srd.request_id,
                pr.relationship_id AS dependent_id,
                pr.relationship_id,
                pr.relationship_type,
                pr.is_active,
                p.person_id,
                p.full_name,
                p.ic_or_passport,
                p.email,
                p.phone,
                p.gender,
                p.date_of_birth,
                p.address_line,
                p.city,
                p.state,
                p.postal_code
            FROM shelter_request_dependents srd
            JOIN person_relationships pr 
                ON pr.relationship_id = srd.relationship_id
            JOIN persons p 
                ON p.person_id = pr.related_person_id
            WHERE srd.request_id IN ($placeholders)
            ORDER BY 
                CASE WHEN pr.relationship_type = 'SELF' THEN 0 ELSE 1 END,
                p.full_name ASC
        ");

        $stmt->execute($requestIds);
        $dependentRows = $stmt->fetchAll();

        $grouped = [];

        foreach ($dependentRows as $row) {
            $requestId = (int)$row['request_id'];
            unset($row['request_id']);
            $grouped[$requestId][] = $row;
        }

        foreach ($requests as &$requestRow) {
            $requestId = (int)($requestRow['request_id'] ?? 0);
            $requestRow['dependents'] = $grouped[$requestId] ?? [];
        }

        return $requests;
    }

    // Handle claiming a guest request
    public function claim(Request $request, Response $response, $args)
    {
        $data = $request->getParsedBody();
        $result = [
            'success' => true,
            'message' => 'Guest request claimed',
            'data' => $data
        ];
        $response->getBody()->write(json_encode($result));
        return $response->withHeader('Content-Type', 'application/json');
    }

    public function lookup(Request $request, Response $response, $args)
    {
        $q = $request->getQueryParams();

        $email = trim($q['email'] ?? '');
        $phone = trim($q['phone'] ?? '');
        $requestId = trim($q['request_id'] ?? '');

        if ($email === '' && $phone === '' && $requestId === '') {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Please provide email, phone, or request_id'
            ]);
        }

        $pdo = Db::conn();

        $sql = "
            SELECT 
                rs.*,

                CASE
                    WHEN EXISTS (
                        SELECT 1
                        FROM beneficiaries b
                        WHERE b.shelter_id = rs.shelter_id
                        AND b.status = 'DISCHARGED'
                        AND b.person_id IN (
                            SELECT u2.person_id
                            FROM users u2
                            WHERE u2.user_id = rs.user_id

                            UNION

                            SELECT pr.related_person_id
                            FROM shelter_request_dependents srd
                            JOIN person_relationships pr
                                ON pr.relationship_id = srd.relationship_id
                            WHERE srd.request_id = rs.request_id
                        )
                    )
                    THEN 1
                    ELSE 0
                END AS is_discharged,

                (
                    SELECT COUNT(*)
                    FROM beneficiaries b
                    WHERE b.shelter_id = rs.shelter_id
                    AND b.status = 'DISCHARGED'
                    AND b.person_id IN (
                        SELECT u2.person_id
                        FROM users u2
                        WHERE u2.user_id = rs.user_id

                        UNION

                        SELECT pr.related_person_id
                        FROM shelter_request_dependents srd
                        JOIN person_relationships pr
                            ON pr.relationship_id = srd.relationship_id
                        WHERE srd.request_id = rs.request_id
                    )
                ) AS discharged_count,

                p.full_name,
                p.email,
                p.phone,
                s.shelter_name,
                s.address_line,
                s.city,
                s.state
            FROM shelter_requests rs
            JOIN users u ON u.user_id = rs.user_id
            JOIN persons p ON p.person_id = u.person_id
            JOIN shelters s ON s.shelter_id = rs.shelter_id
            WHERE 1
        ";

        $params = [];

        if ($requestId !== '') {
            $sql .= " AND rs.request_id = ?";
            $params[] = $requestId;
        }

        if ($email !== '') {
            $sql .= " AND LOWER(p.email) = ?";
            $params[] = strtolower($email);
        }

        if ($phone !== '') {
            $sql .= " AND p.phone = ?";
            $params[] = $phone;
        }

        $sql .= " ORDER BY rs.request_id DESC";

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);

        $requests = $stmt->fetchAll();
        $requests = $this->attachDependentsToRequests($pdo, $requests);

        $requests = $stmt->fetchAll();
        $requests = $this->attachDependentsToRequests($pdo, $requests);

        /*
        * Mobile display rule:
        * Keep shelter_requests.status in database as ARRIVED.
        * But if the related beneficiaries have already been discharged,
        * return status as DISCHARGED for mobile display only.
        */
        foreach ($requests as &$requestRow) {
            $realStatus = strtoupper(trim((string)($requestRow['status'] ?? '')));
            $isDischarged = (int)($requestRow['is_discharged'] ?? 0);

            if ($realStatus === 'ARRIVED' && $isDischarged === 1) {
                $requestRow['real_status'] = $requestRow['status'];
                $requestRow['status'] = 'DISCHARGED';
            }
        }
        unset($requestRow);

        return Http::json($response, [
            'ok' => true,
            'requests' => $requests,
        ]);

        return Http::json($response, [
            'ok' => true,
            'requests' => $requests,
        ]);
    }
    
    public function my(Request $request, Response $response, $args)
    {
        $auth = $request->getAttribute('auth') ?? [];

        $userId = $auth['user_id'] ?? $auth['id'] ?? null;

        if (!$userId) {
            return Http::json($response->withStatus(401), [
                'ok' => false,
                'error' => 'Unauthorized: missing user_id in auth context',
                'auth_debug' => $auth
            ]);
        }

        $pdo = Db::conn();

        $stmt = $pdo->prepare("
            SELECT 
                rs.*,

                CASE
                    WHEN EXISTS (
                        SELECT 1
                        FROM beneficiaries b
                        WHERE b.shelter_id = rs.shelter_id
                        AND b.status = 'DISCHARGED'
                        AND b.person_id IN (
                            SELECT u2.person_id
                            FROM users u2
                            WHERE u2.user_id = rs.user_id

                            UNION

                            SELECT pr.related_person_id
                            FROM shelter_request_dependents srd
                            JOIN person_relationships pr
                                ON pr.relationship_id = srd.relationship_id
                            WHERE srd.request_id = rs.request_id
                        )
                    )
                    THEN 1
                    ELSE 0
                END AS is_discharged,

                (
                    SELECT COUNT(*)
                    FROM beneficiaries b
                    WHERE b.shelter_id = rs.shelter_id
                    AND b.status = 'DISCHARGED'
                    AND b.person_id IN (
                        SELECT u2.person_id
                        FROM users u2
                        WHERE u2.user_id = rs.user_id

                        UNION

                        SELECT pr.related_person_id
                        FROM shelter_request_dependents srd
                        JOIN person_relationships pr
                            ON pr.relationship_id = srd.relationship_id
                        WHERE srd.request_id = rs.request_id
                    )
                ) AS discharged_count,

                p.full_name,
                p.email,
                p.phone,
                s.shelter_name,
                s.address_line,
                s.city,
                s.state
            FROM shelter_requests rs
            JOIN users u ON u.user_id = rs.user_id
            JOIN persons p ON p.person_id = u.person_id
            JOIN shelters s ON s.shelter_id = rs.shelter_id
            WHERE rs.user_id = ?
            ORDER BY rs.request_id DESC
        ");

        $stmt->execute([$userId]);

        $requests = $stmt->fetchAll();
        $requests = $this->attachDependentsToRequests($pdo, $requests);

        /*
        * Mobile display rule:
        * Keep shelter_requests.status in database as ARRIVED.
        * But if the related beneficiaries have already been discharged,
        * return status as DISCHARGED for mobile display only.
        */
        foreach ($requests as &$requestRow) {
            $realStatus = strtoupper(trim((string)($requestRow['status'] ?? '')));
            $isDischarged = (int)($requestRow['is_discharged'] ?? 0);

            if ($realStatus === 'ARRIVED' && $isDischarged === 1) {
                $requestRow['real_status'] = $requestRow['status'];
                $requestRow['status'] = 'DISCHARGED';
            }
        }
        unset($requestRow);

        return Http::json($response, [
            'ok' => true,
            'requests' => $requests,
        ]);
    }

    public function create(Request $request, Response $response, $args)
    {
        $auth = $request->getAttribute('auth') ?? [];
        $userId = $auth['user_id'] ?? $auth['id'] ?? null;

        if (!$userId) {
            return Http::json($response->withStatus(401), [
                'ok' => false,
                'error' => 'Unauthorized: missing user_id'
            ]);
        }

        $data = (array)$request->getParsedBody();
        $pdo = Db::conn();

        $stmt = $pdo->prepare("
            INSERT INTO shelter_requests (
                shelter_id,
                babies_male,
                babies_female,
                kids_male,
                kids_female,
                adult_male,
                adult_female,
                total_people,
                user_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");

        $stmt->execute([
            $data['shelter_id'],
            $data['babies_male'] ?? 0,
            $data['babies_female'] ?? 0,
            $data['kids_male'] ?? 0,
            $data['kids_female'] ?? 0,
            $data['adult_male'] ?? 0,
            $data['adult_female'] ?? 0,
            $data['total_people'] ?? 0,
            $userId
        ]);

        return Http::json($response, [
            'ok' => true,
            'request_id' => $pdo->lastInsertId(),
            'message' => 'Shelter request submitted successfully'
        ]);
    }

    public function cancel(Request $request, Response $response, array $args): Response
    {
        $requestId = (int)($args['id'] ?? 0);

        if ($requestId <= 0) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Invalid booking id'
            ]);
        }

        $pdo = Db::conn();

        $userId = $this->authUserId($request);

        if ($userId <= 0) {
            return Http::json($response->withStatus(401), [
                'ok' => false,
                'error' => 'Unauthorized'
            ]);
        }

        $stmt = $pdo->prepare("
            SELECT request_id, status
            FROM shelter_requests
            WHERE request_id = ?
            AND user_id = ?
            LIMIT 1
        ");
        $stmt->execute([$requestId, $userId]);
        $booking = $stmt->fetch();

        if (!$booking) {
            return Http::json($response->withStatus(404), [
                'ok' => false,
                'error' => 'Booking not found for this account'
            ]);
        }

        $currentStatus = strtoupper(trim((string)$booking['status']));

        if ($currentStatus === 'CANCELLED') {
            return Http::json($response, [
                'ok' => true,
                'message' => 'Booking is already cancelled'
            ]);
        }

        if (in_array($currentStatus, ['REJECTED', 'CHECKED_IN'], true)) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'This booking can no longer be cancelled'
            ]);
        }

        $stmt = $pdo->prepare("
            UPDATE shelter_requests
            SET status = 'CANCELLED'
            WHERE request_id = ?
            AND user_id = ?
        ");
        $stmt->execute([$requestId, $userId]);

        return Http::json($response, [
            'ok' => true,
            'message' => 'Booking cancelled successfully',
            'request_id' => $requestId,
            'status' => 'CANCELLED'
        ]);
    }

    public function assignDependents(Request $request, Response $response, array $args): Response
    {
        $requestId = (int)($args['id'] ?? 0);

        if ($requestId <= 0) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Invalid request id'
            ]);
        }

        $pdo = Db::conn();

        $userId = $this->authUserId($request);
        $mainPersonId = $this->authPersonId($request, $pdo);

        if ($userId <= 0 || $mainPersonId <= 0) {
            return Http::json($response->withStatus(401), [
                'ok' => false,
                'error' => 'Unauthorized'
            ]);
        }

        $body = (array)$request->getParsedBody();
        $dependentIds = $body['dependent_ids'] ?? [];

        if (!is_array($dependentIds)) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'dependent_ids must be an array'
            ]);
        }

        $dependentIds = array_values(array_unique(array_filter(array_map('intval', $dependentIds))));

        if (empty($dependentIds)) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Please select at least one dependent'
            ]);
        }

        $stmt = $pdo->prepare("
            SELECT request_id
            FROM shelter_requests
            WHERE request_id = ?
            AND user_id = ?
            LIMIT 1
        ");
        $stmt->execute([$requestId, $userId]);

        if (!$stmt->fetch()) {
            return Http::json($response->withStatus(404), [
                'ok' => false,
                'error' => 'Booking not found for this account'
            ]);
        }

        $placeholders = implode(',', array_fill(0, count($dependentIds), '?'));
        $params = array_merge([$mainPersonId], $dependentIds);

        $stmt = $pdo->prepare("
            SELECT 
                pr.relationship_id,
                pr.relationship_type,
                p.gender
            FROM person_relationships pr
            JOIN persons p 
                ON p.person_id = pr.related_person_id
            WHERE pr.main_person_id = ?
            AND pr.relationship_id IN ($placeholders)
            AND pr.is_active = 1
        ");
        $stmt->execute($params);

        $validDependents = $stmt->fetchAll();
        $validIds = array_map(fn($row) => (int)$row['relationship_id'], $validDependents);

        sort($dependentIds);
        sort($validIds);

        if ($dependentIds !== $validIds) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'One or more selected dependents do not belong to your account'
            ]);
        }

        $pdo->beginTransaction();

        try {
            $stmt = $pdo->prepare("
                DELETE FROM shelter_request_dependents
                WHERE request_id = ?
            ");
            $stmt->execute([$requestId]);

            $stmt = $pdo->prepare("
                INSERT INTO shelter_request_dependents (
                    request_id,
                    relationship_id
                ) VALUES (?, ?)
            ");

            foreach ($dependentIds as $relationshipId) {
                $stmt->execute([$requestId, $relationshipId]);
            }

            $pdo->commit();

            return Http::json($response, [
                'ok' => true,
                'message' => 'Dependents assigned to booking successfully',
                'request_id' => $requestId,
                'assigned_count' => count($dependentIds)
            ]);
        } catch (\Throwable $e) {
            $pdo->rollBack();

            return Http::json($response->withStatus(500), [
                'ok' => false,
                'error' => 'Failed to assign dependents',
                'debug' => $e->getMessage()
            ]);
        }
    }

    public function discharge(Request $request, Response $response, array $args): Response
    {
        $requestId = (int)($args['id'] ?? 0);

        if ($requestId <= 0) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'Invalid booking id'
            ]);
        }

        $pdo = Db::conn();

        $userId = $this->authUserId($request);

        if ($userId <= 0) {
            return Http::json($response->withStatus(401), [
                'ok' => false,
                'error' => 'Unauthorized'
            ]);
        }

        /*
            Get the booking and make sure this booking belongs to the logged-in public user.
            We do NOT discharge from shelter_requests.
            We only use shelter_requests to find:
            - shelter_id
            - main requestor user/person
        */
        $stmt = $pdo->prepare("
            SELECT 
                sr.request_id,
                sr.shelter_id,
                sr.status,
                sr.user_id,
                u.person_id
            FROM shelter_requests sr
            INNER JOIN users u
                ON u.user_id = sr.user_id
            WHERE sr.request_id = ?
            AND sr.user_id = ?
            LIMIT 1
        ");
        $stmt->execute([$requestId, $userId]);
        $booking = $stmt->fetch();

        if (!$booking) {
            return Http::json($response->withStatus(404), [
                'ok' => false,
                'error' => 'Booking not found for this account'
            ]);
        }

        $bookingStatus = strtoupper(trim((string)$booking['status']));

        /*
            Allow discharge only after the person has been received/arrived.
            Your system may use CONFIRMED or ARRIVED depending on the flow,
            so we allow both.
        */
        if ($bookingStatus !== 'ARRIVED') {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'You can only discharge after you have arrived and been received as a beneficiary.'
            ]);
        }

        $shelterId = (int)$booking['shelter_id'];

        /*
            Person list to discharge:
            1. Main requestor person_id from shelter_requests.user_id
            2. Assigned dependents from shelter_request_dependents
        */
        $personIds = [];
        $personIds[] = (int)$booking['person_id'];

        $depStmt = $pdo->prepare("
            SELECT p.person_id
            FROM shelter_request_dependents srd
            INNER JOIN person_relationships pr
                ON pr.relationship_id = srd.relationship_id
            INNER JOIN persons p
                ON p.person_id = pr.related_person_id
            WHERE srd.request_id = ?
        ");
        $depStmt->execute([$requestId]);

        foreach ($depStmt->fetchAll() as $row) {
            $personIds[] = (int)$row['person_id'];
        }

        $personIds = array_values(array_unique(array_filter($personIds)));

        if (empty($personIds)) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'No person records found for this booking.'
            ]);
        }

        $placeholders = implode(',', array_fill(0, count($personIds), '?'));

        /*
            Check whether these people are actually active beneficiaries in this shelter.
            This prevents discharge before they are received as beneficiaries.
        */
        $checkParams = array_merge([$shelterId], $personIds);

        $checkStmt = $pdo->prepare("
            SELECT 
                beneficiary_id,
                person_id,
                status
            FROM beneficiaries
            WHERE shelter_id = ?
            AND person_id IN ($placeholders)
            AND status = 'ACTIVE'
        ");
        $checkStmt->execute($checkParams);
        $activeBeneficiaries = $checkStmt->fetchAll();

        if (count($activeBeneficiaries) === 0) {
            return Http::json($response->withStatus(400), [
                'ok' => false,
                'error' => 'No active beneficiaries found for this booking. They may not have been received yet, or they are already discharged.'
            ]);
        }

        $pdo->beginTransaction();

        try {
            $updateParams = array_merge([$shelterId], $personIds);

            $updateStmt = $pdo->prepare("
                UPDATE beneficiaries
                SET 
                    status = 'DISCHARGED',
                    discharged_at = NOW()
                WHERE shelter_id = ?
                AND person_id IN ($placeholders)
                AND status = 'ACTIVE'
            ");
            $updateStmt->execute($updateParams);

            $dischargedCount = $updateStmt->rowCount();

            $pdo->commit();

            return Http::json($response, [
                'ok' => true,
                'message' => 'Beneficiaries discharged successfully.',
                'request_id' => $requestId,
                'shelter_id' => $shelterId,
                'discharged_count' => $dischargedCount
            ]);
        } catch (\Throwable $e) {
            $pdo->rollBack();

            return Http::json($response->withStatus(500), [
                'ok' => false,
                'error' => 'Failed to discharge beneficiaries.',
                'debug' => $e->getMessage()
            ]);
        }
    }
}
