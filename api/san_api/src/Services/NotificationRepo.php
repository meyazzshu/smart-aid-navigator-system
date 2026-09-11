<?php
namespace App\Services;

use App\Db;

class NotificationRepo {
  public static function activeTokensForUserIds(array $userIds): array {
    if (count($userIds) === 0) return [];
    $pdo = Db::conn();
    $in = implode(',', array_fill(0, count($userIds), '?'));
    $stmt = $pdo->prepare("
      SELECT token
      FROM device_tokens
      WHERE is_active=1 AND user_id IN ($in)
    ");
    $stmt->execute($userIds);
    return array_map(fn($r) => $r['token'], $stmt->fetchAll());
  }

  public static function ngoStaffUserIds(int $ngoId): array {
    $pdo = Db::conn();
    $stmt = $pdo->prepare("SELECT user_id FROM ngo_staff WHERE ngo_id=?");
    $stmt->execute([$ngoId]);
    return array_map(fn($r) => (int)$r['user_id'], $stmt->fetchAll());
  }

  public static function userIdByEmail(string $email): ?int {
    $pdo = Db::conn();
    $stmt = $pdo->prepare("
      SELECT u.user_id
      FROM users u
      JOIN persons p ON p.person_id = u.person_id
      WHERE LOWER(p.email) = LOWER(?)
      LIMIT 1
    ");
    $stmt->execute([$email]);
    $row = $stmt->fetch();
    return $row ? (int)$row['user_id'] : null;
  }
}
