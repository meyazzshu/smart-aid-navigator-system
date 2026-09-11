<?php
namespace App\Auth;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface as Handler;
use Slim\Psr7\Response as SlimResponse;

class RoleMiddleware implements MiddlewareInterface {
  /** @var string[] */
  private array $allowed;

  /**
   * @param string[] $allowedRoles
   */
  public function __construct(array $allowedRoles) {
    $this->allowed = $allowedRoles;
  }

  public function process(Request $request, Handler $handler): Response {
    $auth = $request->getAttribute('auth');
    $role = $auth['role'] ?? null;

    if (!$role || !in_array($role, $this->allowed, true)) {
      $res = new SlimResponse();
      $res->getBody()->write(json_encode([
        "ok" => false,
        "error" => "Forbidden: requires one of roles: " . implode(", ", $this->allowed)
      ]));
      return $res->withHeader('Content-Type', 'application/json')->withStatus(403);
    }

    return $handler->handle($request);
  }
}
