<?php
namespace App\Auth;
use App\Auth\JwtHelper;


use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface as Handler;
use Slim\Psr7\Response as SlimResponse;

class AuthMiddleware implements MiddlewareInterface {
  public function process(Request $request, Handler $handler): Response {
    $authHeader = $request->getHeaderLine('Authorization');

    if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
      return $this->unauthorized("Missing Bearer token");
    }

    $token = trim(substr($authHeader, 7));

    try {
      $claims = JwtHelper::verify($token);
    } catch (\Throwable $e) {
      return $this->unauthorized("Invalid token: " . $e->getMessage());
    }

    // Attach claims to request so controllers can read it
    $request = $request->withAttribute('auth', $claims);
    return $handler->handle($request);
  }

  private function unauthorized(string $message): Response {
    $res = new SlimResponse();
    $res->getBody()->write(json_encode([
      "ok" => false,
      "error" => $message
    ]));
    return $res->withHeader('Content-Type', 'application/json')->withStatus(401);
  }
}
