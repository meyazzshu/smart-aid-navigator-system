<?php
namespace App\Services;

use Google\Auth\Credentials\ServiceAccountCredentials;

class FcmService {
  private string $projectId;
  private string $serviceAccountPath;

  public function __construct(string $projectId, string $serviceAccountPath) {
    $this->projectId = $projectId;
    $this->serviceAccountPath = $serviceAccountPath;
  }

  private function getAccessToken(): string {
    $scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    $creds = new ServiceAccountCredentials($scopes, $this->serviceAccountPath);
    $token = $creds->fetchAuthToken();
    return $token['access_token'];
  }

  public function sendToToken(string $deviceToken, string $title, string $body, array $data = []): array {
    $accessToken = $this->getAccessToken();

    $url = "https://fcm.googleapis.com/v1/projects/{$this->projectId}/messages:send";
    $payload = [
      "message" => [
        "token" => $deviceToken,
        "notification" => [
          "title" => $title,
          "body"  => $body
        ],
        "data" => array_map(fn($v) => (string)$v, $data),
      ]
    ];

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
      "Authorization: Bearer {$accessToken}",
      "Content-Type: application/json"
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));

    $resp = curl_exec($ch);
    $http = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    return ["http" => $http, "resp" => $resp];
  }
}
