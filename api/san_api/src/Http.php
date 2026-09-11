<?php
namespace App;

use Psr\Http\Message\ResponseInterface as Response;

class Http {
  public static function json(Response $res, array $data, int $status = 200): Response {
    $res->getBody()->write(json_encode($data));
    return $res->withHeader('Content-Type', 'application/json')->withStatus($status);
  }
}
