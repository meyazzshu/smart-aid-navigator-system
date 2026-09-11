<?php
namespace App\Auth;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

class JwtHelper {
  public static function sign(array $payload): string {
    $secret = $_ENV['JWT_SECRET'];
    $now = time();

    $tokenPayload = array_merge($payload, [
      "iat" => $now,
      "exp" => $now + 60 * 60 * 24 * 7 // 7 days
    ]);

    return JWT::encode($tokenPayload, $secret, 'HS256');
  }

  public static function verify(string $token): array {
    $secret = $_ENV['JWT_SECRET'];
    $decoded = JWT::decode($token, new Key($secret, 'HS256'));
    return (array)$decoded;
  }
}
