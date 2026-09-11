<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ItemController {

  // GET /items?category_id=
  public function list(Request $req, Response $res): Response {
    $q = $req->getQueryParams();
    $categoryId = (int)($q['category_id'] ?? 0);

    $pdo = Db::conn();

    $sql = "
      SELECT ai.item_id, ai.item_name, ai.unit, ai.category_id,
             ac.category_name
      FROM aid_items ai
      JOIN aid_categories ac ON ac.category_id = ai.category_id
      WHERE ai.is_active = 1
    ";
    $params = [];
    if ($categoryId > 0) {
      $sql .= " AND ai.category_id = ?";
      $params[] = $categoryId;
    }
    $sql .= " ORDER BY ac.category_name ASC, ai.item_name ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    return Http::json($res, ["ok"=>true, "items"=>$stmt->fetchAll()]);
  }

  // GET /categories
  public function categories(Request $req, Response $res): Response {
    $pdo = Db::conn();
    $stmt = $pdo->query("SELECT category_id, category_name FROM aid_categories ORDER BY category_name ASC");
    return Http::json($res, ["ok"=>true, "categories"=>$stmt->fetchAll()]);
  }
}
