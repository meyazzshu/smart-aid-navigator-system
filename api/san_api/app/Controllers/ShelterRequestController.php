<?php

namespace App\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ShelterRequestController
{
    // Handle guest shelter request submission
    public function guest(Request $request, Response $response, $args)
    {
        $data = (array)$request->getParsedBody();
        $pdo = \App\Db::conn();
        $fullName = trim($data['full_name'] ?? '');
        $email = strtolower(trim($data['email'] ?? ''));
        $phone = trim($data['phone'] ?? '');

        if ($fullName === '' || ($email === '' && $phone === '')) {
            $response->getBody()->write(json_encode(['ok' => false, 'error' => 'full_name and email/phone required']));
            return $response->withHeader('Content-Type', 'application/json')->withStatus(400);
        }

        $pdo->beginTransaction();
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
        } else {
            $stmt = $pdo->prepare("INSERT INTO persons(full_name, email, phone) VALUES(?,?,?)");
            $stmt->execute([$fullName, $email !== '' ? $email : null, $phone !== '' ? $phone : null]);
            $personId = (int)$pdo->lastInsertId();
        }
        $stmt = $pdo->prepare("SELECT user_id FROM users WHERE person_id = ? LIMIT 1");
        $stmt->execute([$personId]);
        $userId = $stmt->fetchColumn();
        if (!$userId) {
            $stmt = $pdo->prepare("INSERT INTO users(person_id, password_hash, is_active, is_guest) VALUES(?, NULL, 1, 1)");
            $stmt->execute([$personId]);
            $userId = (int)$pdo->lastInsertId();
        }

        // Insert the new request
        $stmt = $pdo->prepare("INSERT INTO shelter_requests (
            shelter_id,
            babies_male, babies_female, kids_male, kids_female,
            adult_male, adult_female, total_people, user_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
        $stmt->execute([
            $data['shelter_id'],
            $data['babies_male'],
            $data['babies_female'],
            $data['kids_male'],
            $data['kids_female'],
            $data['adult_male'],
            $data['adult_female'],
            $data['total_people'],
            $userId,
        ]);
        $requestId = (int)$pdo->lastInsertId();

        // Update current_occupancy in shelters table
        $shelterId = $data['shelter_id'];
        $stmt = $pdo->prepare("SELECT SUM(total_people) AS total FROM shelter_requests WHERE shelter_id = ?");
        $stmt->execute([$shelterId]);
        $row = $stmt->fetch();
        $currentOccupancy = (int)($row['total'] ?? 0);

        $stmt = $pdo->prepare("UPDATE shelters SET current_occupancy = ? WHERE shelter_id = ?");
        $stmt->execute([$currentOccupancy, $shelterId]);
        $pdo->commit();

        $result = [
            'success' => true,
            'message' => 'Guest shelter request received',
            'current_occupancy' => $currentOccupancy,
            'request_id' => $requestId,
        ];
        $response->getBody()->write(json_encode($result));
        return $response->withHeader('Content-Type', 'application/json');
    }

    // Handle claiming a guest request
    public function claim(Request $request, Response $response, $args)
    {
        $data = $request->getParsedBody();
        // TODO: Process claim logic here
        $result = [
            'success' => true,
            'message' => 'Guest request claimed',
            'data' => $data
        ];
        $response->getBody()->write(json_encode($result));
        return $response->withHeader('Content-Type', 'application/json');
    }
}
