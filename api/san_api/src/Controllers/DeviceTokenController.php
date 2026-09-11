<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class DeviceTokenController {

  // POST /device-tokens/register (auth required)
  public function register(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];

    $body = (array)$req->getParsedBody();
    $token = trim($body['token'] ?? '');
    $platform = trim($body['platform'] ?? 'android');

    if ($token === '') {
      return Http::json($res, ["ok"=>false,"error"=>"Missing token"], 400);
    }

    $pdo = Db::conn();
    $stmt = $pdo->prepare("
      INSERT INTO device_tokens(user_id, token, platform, is_active)
      VALUES(?,?,?,1)
      ON DUPLICATE KEY UPDATE is_active=1, platform=VALUES(platform), updated_at=CURRENT_TIMESTAMP
    ");
    $stmt->execute([$userId, $token, $platform]);

    return Http::json($res, ["ok"=>true]);
  }

  // POST /device-tokens/unregister (auth required)
  public function unregister(Request $req, Response $res): Response {
    $auth = $req->getAttribute('auth');
    $userId = (int)$auth['user_id'];

    $body = (array)$req->getParsedBody();
    $token = trim($body['token'] ?? '');

    if ($token === '') {
      return Http::json($res, ["ok"=>false,"error"=>"Missing token"], 400);
    }

    $pdo = Db::conn();
    $stmt = $pdo->prepare("
      UPDATE device_tokens SET is_active=0
      WHERE user_id=? AND token=?
    ");
    $stmt->execute([$userId, $token]);

    return Http::json($res, ["ok"=>true]);
  }
}
