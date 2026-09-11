<?php

namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class DeliveryGroupController
{
    private function authUserId(Request $request): ?int
    {
        $auth = $request->getAttribute('auth');

        if (is_array($auth) && isset($auth['user_id'])) {
            return (int)$auth['user_id'];
        }

        if (is_object($auth) && isset($auth->user_id)) {
            return (int)$auth->user_id;
        }

        return null;
    }

    public function list(Request $request, Response $response): Response
    {
        $pdo = Db::conn();
        $userId = $this->authUserId($request);

        if (!$userId) {
            return Http::json($response, [
                'ok' => false,
                'error' => 'Auth token passed, but user_id was not found in auth claims'
            ], 401);
        }

        $stmt = $pdo->prepare("
            SELECT ns.ngo_id
            FROM ngo_staff ns
            WHERE ns.user_id = ?
            LIMIT 1
        ");
        $stmt->execute([$userId]);
        $ngoStaff = $stmt->fetch();

        if (!$ngoStaff) {
            return Http::json($response, [
                'ok' => false,
                'error' => 'NGO staff profile not found'
            ], 403);
        }

        $stmt = $pdo->prepare("
            SELECT
                dg.delivery_group_id,
                dg.group_name,
                dg.status,
                dg.scheduled_date,
                dg.total_distance_km,
                dg.total_eta_minutes,
                dg.optimized_at,
                dg.created_at,
                COUNT(dgd.delivery_id) AS stop_count
            FROM delivery_groups dg
            LEFT JOIN delivery_group_deliveries dgd
                ON dgd.delivery_group_id = dg.delivery_group_id
            WHERE dg.ngo_id = ?
              AND (dg.assigned_to IS NULL OR dg.assigned_to = ?)
            GROUP BY
                dg.delivery_group_id,
                dg.group_name,
                dg.status,
                dg.scheduled_date,
                dg.total_distance_km,
                dg.total_eta_minutes,
                dg.optimized_at,
                dg.created_at
            ORDER BY dg.created_at DESC
        ");
        $stmt->execute([(int)$ngoStaff['ngo_id'], $userId]);

        return Http::json($response, [
            'ok' => true,
            'groups' => $stmt->fetchAll()
        ]);
    }

    public function detail(Request $request, Response $response, array $args): Response
    {
        $pdo = Db::conn();
        $userId = $this->authUserId($request);
        $groupId = (int)$args['id'];

        if (!$userId) {
            return Http::json($response, [
                'ok' => false,
                'error' => 'Auth token passed, but user_id was not found in auth claims'
            ], 401);
        }

        $groupStmt = $pdo->prepare("
            SELECT
                dg.*,
                n.ngo_name,
                n.latitude AS ngo_latitude,
                n.longitude AS ngo_longitude
            FROM delivery_groups dg
            INNER JOIN ngo_staff ns
                ON ns.ngo_id = dg.ngo_id
            INNER JOIN ngos n
                ON n.ngo_id = dg.ngo_id
            WHERE dg.delivery_group_id = ?
              AND ns.user_id = ?
              AND (dg.assigned_to IS NULL OR dg.assigned_to = ?)
            LIMIT 1
        ");
        $groupStmt->execute([$groupId, $userId, $userId]);
        $group = $groupStmt->fetch();

        if (!$group) {
            return Http::json($response, [
                'ok' => false,
                'error' => 'Delivery group not found'
            ], 404);
        }

        $stopsStmt = $pdo->prepare("
            SELECT
                dgd.delivery_group_delivery_id,
                dgd.delivery_group_id,
                dgd.delivery_id,
                dgd.requested_stop_order,
                dgd.optimized_stop_order,

                d.shelter_id,
                d.status,
                d.scheduled_date,
                d.notes,

                s.shelter_name,
                s.address_line,
                s.city,
                s.state,
                s.postal_code,
                s.latitude,
                s.longitude
            FROM delivery_group_deliveries dgd
            INNER JOIN deliveries d
                ON d.delivery_id = dgd.delivery_id
            INNER JOIN shelters s
                ON s.shelter_id = d.shelter_id
            WHERE dgd.delivery_group_id = ?
            ORDER BY
                COALESCE(dgd.optimized_stop_order, dgd.requested_stop_order, 9999),
                d.delivery_id
        ");
        $stopsStmt->execute([$groupId]);
        $stops = $stopsStmt->fetchAll();

        $itemsStmt = $pdo->prepare("
            SELECT
                di.delivery_id,
                di.delivery_item_id,
                di.item_id,
                ai.item_name,
                ai.unit,
                di.quantity
            FROM delivery_items di
            INNER JOIN aid_items ai
                ON ai.item_id = di.item_id
            INNER JOIN delivery_group_deliveries dgd
                ON dgd.delivery_id = di.delivery_id
            WHERE dgd.delivery_group_id = ?
            ORDER BY di.delivery_id, ai.item_name
        ");
        $itemsStmt->execute([$groupId]);
        $items = $itemsStmt->fetchAll();

        $itemsByDelivery = [];

        foreach ($items as $item) {
            $deliveryId = (int)$item['delivery_id'];

            if (!isset($itemsByDelivery[$deliveryId])) {
                $itemsByDelivery[$deliveryId] = [];
            }

            $itemsByDelivery[$deliveryId][] = $item;
        }

        foreach ($stops as &$stop) {
            $deliveryId = (int)$stop['delivery_id'];
            $stop['items'] = $itemsByDelivery[$deliveryId] ?? [];
        }

        return Http::json($response, [
            'ok' => true,
            'group' => $group,
            'stops' => $stops
        ]);
    }

    public function optimize(Request $request, Response $response, array $args): Response
    {
        $pdo = Db::conn();
        $userId = $this->authUserId($request);
        $groupId = (int)$args['id'];
        $body = (array)$request->getParsedBody();

        if (!$userId) {
            return Http::json($response, [
                'ok' => false,
                'error' => 'Auth token passed, but user_id was not found in auth claims'
            ], 401);
        }

        $currentLat = isset($body['current_lat']) ? (float)$body['current_lat'] : null;
        $currentLng = isset($body['current_lng']) ? (float)$body['current_lng'] : null;

        $groupStmt = $pdo->prepare("
            SELECT
                dg.*,
                n.latitude AS ngo_latitude,
                n.longitude AS ngo_longitude
            FROM delivery_groups dg
            INNER JOIN ngo_staff ns
                ON ns.ngo_id = dg.ngo_id
            INNER JOIN ngos n
                ON n.ngo_id = dg.ngo_id
            WHERE dg.delivery_group_id = ?
              AND ns.user_id = ?
              AND (dg.assigned_to IS NULL OR dg.assigned_to = ?)
            LIMIT 1
        ");
        $groupStmt->execute([$groupId, $userId, $userId]);
        $group = $groupStmt->fetch();

        if (!$group) {
            return Http::json($response, [
                'ok' => false,
                'error' => 'Delivery group not found'
            ], 404);
        }

        $defaultOriginLat = (float)($group['origin_lat'] ?? $group['ngo_latitude']);
        $defaultOriginLng = (float)($group['origin_lng'] ?? $group['ngo_longitude']);

        /*
        * Use phone GPS only if it is inside Malaysia-ish range.
        * Otherwise fallback to NGO origin.
        * This prevents Google from trying to drive from emulator/default overseas location to Malaysia.
        */
        $phoneLocationLooksValidForMalaysia =
            $currentLat !== null &&
            $currentLng !== null &&
            $currentLat >= 0.8 &&
            $currentLat <= 7.5 &&
            $currentLng >= 99.0 &&
            $currentLng <= 120.0;

        if ($phoneLocationLooksValidForMalaysia) {
            $originLat = $currentLat;
            $originLng = $currentLng;
        } else {
            $originLat = $defaultOriginLat;
            $originLng = $defaultOriginLng;
        }

        if (!$originLat || !$originLng) {
            return Http::json($response, [
                'ok' => false,
                'error' => 'Origin location is missing. Allow location permission or set NGO latitude/longitude.'
            ], 400);
        }

        $stopsStmt = $pdo->prepare("
            SELECT
                dgd.delivery_group_delivery_id,
                dgd.delivery_group_id,
                dgd.delivery_id,
                dgd.requested_stop_order,
                dgd.optimized_stop_order,

                d.shelter_id,
                d.status,

                s.shelter_name,
                s.latitude,
                s.longitude
            FROM delivery_group_deliveries dgd
            INNER JOIN deliveries d
                ON d.delivery_id = dgd.delivery_id
            INNER JOIN shelters s
                ON s.shelter_id = d.shelter_id
            WHERE dgd.delivery_group_id = ?
                AND d.status NOT IN ('CANCELLED')
                AND s.latitude IS NOT NULL
                AND s.longitude IS NOT NULL
            ORDER BY
                COALESCE(dgd.requested_stop_order, d.delivery_id)
        ");
        $stopsStmt->execute([$groupId]);
        $stops = $stopsStmt->fetchAll();

        if (count($stops) < 2) {
            return Http::json($response, [
                'ok' => false,
                'error' => 'At least 2 active stops with coordinates are required.'
            ], 400);
        }

        $apiKey = $_ENV['GOOGLE_MAPS_API_KEY'] ?? getenv('GOOGLE_MAPS_API_KEY');

        if (!$apiKey) {
            return Http::json($response, [
                'ok' => false,
                'error' => 'GOOGLE_MAPS_API_KEY is missing in .env'
            ], 500);
        }

        /*
        * IMPORTANT FIX:
        *
        * For exactly 2 delivery stops, do not call Google Routes API.
        * Google only optimizes intermediate waypoints, and with 2 stops there is only
        * 1 intermediate + 1 destination, so mobile Google Maps can behave weirdly.
        *
        * So for 2 stops:
        * origin -> nearest stop -> farthest stop
        *
        * For 3+ stops:
        * use Google Routes API optimization as before.
        */
        if (count($stops) === 2) {
            usort($stops, function ($a, $b) use ($originLat, $originLng) {
                $distanceA = $this->haversineKm(
                    $originLat,
                    $originLng,
                    (float)$a['latitude'],
                    (float)$a['longitude']
                );

                $distanceB = $this->haversineKm(
                    $originLat,
                    $originLng,
                    (float)$b['latitude'],
                    (float)$b['longitude']
                );

                return $distanceA <=> $distanceB;
            });

            $optimizedStops = array_values($stops);

            $firstStop = $optimizedStops[0];
            $secondStop = $optimizedStops[1];

            $leg1Distance = $this->haversineKm(
                $originLat,
                $originLng,
                (float)$firstStop['latitude'],
                (float)$firstStop['longitude']
            );

            $leg2Distance = $this->haversineKm(
                (float)$firstStop['latitude'],
                (float)$firstStop['longitude'],
                (float)$secondStop['latitude'],
                (float)$secondStop['longitude']
            );

            $totalDistanceKm = round($leg1Distance + $leg2Distance, 2);

            /*
            * Rough ETA for demo route summary.
            * 50 km/h average is safer than 60 km/h for mixed roads.
            */
            $totalEtaMinutes = (int)ceil(($totalDistanceKm / 50) * 60);

            $mapsUrl = $this->buildGoogleMapsUrl($originLat, $originLng, $optimizedStops);
        } else {
            /*
            * Google Routes API optimizes intermediate waypoints.
            * Origin and destination are fixed.
            * For FYP/demo, we choose the farthest stop as final destination,
            * then Google optimizes the stops before it.
            */
            $destinationIndex = $this->findFarthestStopIndex($originLat, $originLng, $stops);
            $destinationStop = $stops[$destinationIndex];

            $intermediateStops = [];

            foreach ($stops as $index => $stop) {
                if ($index !== $destinationIndex) {
                    $intermediateStops[] = $stop;
                }
            }

            $requestBody = [
                'origin' => [
                    'location' => [
                        'latLng' => [
                            'latitude' => $originLat,
                            'longitude' => $originLng
                        ]
                    ]
                ],
                'destination' => [
                    'location' => [
                        'latLng' => [
                            'latitude' => (float)$destinationStop['latitude'],
                            'longitude' => (float)$destinationStop['longitude']
                        ]
                    ]
                ],
                'intermediates' => array_map(function ($stop) {
                    return [
                        'location' => [
                            'latLng' => [
                                'latitude' => (float)$stop['latitude'],
                                'longitude' => (float)$stop['longitude']
                            ]
                        ]
                    ];
                }, $intermediateStops),
                'travelMode' => 'DRIVE',
                'routingPreference' => 'TRAFFIC_UNAWARE',
                'optimizeWaypointOrder' => true
            ];

            $googleResult = $this->callGoogleRoutesApi($apiKey, $requestBody);

            if (!$googleResult['ok']) {
                return Http::json($response, [
                    'ok' => false,
                    'error' => 'Google Routes API failed',
                    'details' => $googleResult['error'],
                    'hint' => 'Check GOOGLE_MAPS_API_KEY, Routes API enabled, billing enabled, and API key restrictions.'
                ], 502);
            }

            $route = $googleResult['data']['routes'][0] ?? null;

            if (!$route) {
                return Http::json($response, [
                    'ok' => false,
                    'error' => 'No route returned by Google.',
                    'origin_used' => [
                        'latitude' => $originLat,
                        'longitude' => $originLng
                    ],
                    'phone_location_received' => [
                        'latitude' => $currentLat,
                        'longitude' => $currentLng
                    ],
                    'default_ngo_origin' => [
                        'latitude' => $defaultOriginLat,
                        'longitude' => $defaultOriginLng
                    ],
                    'stops_sent_to_google' => array_map(function ($stop) {
                        return [
                            'delivery_id' => (int)$stop['delivery_id'],
                            'shelter_id' => (int)$stop['shelter_id'],
                            'shelter_name' => $stop['shelter_name'],
                            'latitude' => (float)$stop['latitude'],
                            'longitude' => (float)$stop['longitude']
                        ];
                    }, $stops),
                    'google_response' => $googleResult['data']
                ], 502);
            }

            $optimizedIndexes = $route['optimizedIntermediateWaypointIndex'] ?? [];
            $optimizedStops = [];

            if (count($optimizedIndexes) > 0) {
                foreach ($optimizedIndexes as $optimizedIndex) {
                    if (isset($intermediateStops[$optimizedIndex])) {
                        $optimizedStops[] = $intermediateStops[$optimizedIndex];
                    }
                }
            } else {
                $optimizedStops = $intermediateStops;
            }

            $optimizedStops[] = $destinationStop;

            $distanceMeters = (int)($route['distanceMeters'] ?? 0);
            $durationSeconds = $this->parseGoogleDurationSeconds($route['duration'] ?? '0s');

            $totalDistanceKm = round($distanceMeters / 1000, 2);
            $totalEtaMinutes = (int)ceil($durationSeconds / 60);

            $mapsUrl = $this->buildGoogleMapsUrl($originLat, $originLng, $optimizedStops);
        }

        $pdo->beginTransaction();

        try {
            $resetOldOrder = $pdo->prepare("
                UPDATE delivery_group_deliveries
                SET optimized_stop_order = NULL
                WHERE delivery_group_id = ?
            ");
            $resetOldOrder->execute([$groupId]);

            $order = 1;

            foreach ($optimizedStops as $stop) {
                $updateStopOrder = $pdo->prepare("
                    UPDATE delivery_group_deliveries
                    SET optimized_stop_order = ?
                    WHERE delivery_group_id = ?
                      AND delivery_id = ?
                ");
                $updateStopOrder->execute([
                    $order,
                    $groupId,
                    (int)$stop['delivery_id']
                ]);

                $order++;
            }

            $deliveryIdsToRoute = array_values(array_unique(
                array_map(function ($stop) {
                    return (int)$stop['delivery_id'];
                }, $stops)
            ));

            foreach ($deliveryIdsToRoute as $deliveryId) {
                $statusStmt = $pdo->prepare("
                    SELECT status
                    FROM deliveries
                    WHERE delivery_id = ?
                    LIMIT 1
                ");
                $statusStmt->execute([$deliveryId]);
                $oldStatus = strtoupper(trim((string)$statusStmt->fetchColumn()));

                if ($oldStatus === 'PLANNED') {
                    $updateDeliveryStatus = $pdo->prepare("
                        UPDATE deliveries
                        SET status = 'ROUTED'
                        WHERE delivery_id = ?
                        AND status = 'PLANNED'
                    ");
                    $updateDeliveryStatus->execute([$deliveryId]);

                    $insertTracking = $pdo->prepare("
                        INSERT INTO delivery_tracking (
                            delivery_id,
                            status,
                            latitude,
                            longitude,
                            note,
                            created_at
                        )
                        SELECT
                            ?,
                            'ROUTED',
                            NULL,
                            NULL,
                            ?,
                            NOW()
                        WHERE NOT EXISTS (
                            SELECT 1
                            FROM delivery_tracking
                            WHERE delivery_id = ?
                            AND status = 'ROUTED'
                        )
                    ");

                    $insertTracking->execute([
                        $deliveryId,
                        'Route optimized and assigned through group delivery navigation.',
                        $deliveryId
                    ]);
                }
            }

            $updateGroup = $pdo->prepare("
                UPDATE delivery_groups
                SET status = CASE
                        WHEN status = 'IN_TRANSIT' THEN 'IN_TRANSIT'
                        WHEN status = 'DELIVERED' THEN 'DELIVERED'
                        WHEN status = 'CANCELLED' THEN 'CANCELLED'
                        ELSE 'ROUTED'
                    END,
                    origin_lat = ?,
                    origin_lng = ?,
                    total_distance_km = ?,
                    total_eta_minutes = ?,
                    google_maps_url = ?,
                    optimized_at = NOW()
                WHERE delivery_group_id = ?
            ");
            $updateGroup->execute([
                $originLat,
                $originLng,
                $totalDistanceKm,
                $totalEtaMinutes,
                $mapsUrl,
                $groupId
            ]);

            $pdo->commit();
        } catch (\Throwable $e) {
            $pdo->rollBack();

            return Http::json($response, [
                'ok' => false,
                'error' => 'Failed to save optimized route',
                'details' => $e->getMessage()
            ], 500);
        }

        $finalStop = $optimizedStops[count($optimizedStops) - 1];

        return Http::json($response, [
            'ok' => true,
            'message' => 'Route optimized successfully',
            'total_distance_km' => $totalDistanceKm,
            'total_eta_minutes' => $totalEtaMinutes,
            'google_maps_url' => $mapsUrl,

            'debug_origin' => [
                'latitude' => $originLat,
                'longitude' => $originLng
            ],
            'debug_final_destination' => [
                'delivery_id' => (int)$finalStop['delivery_id'],
                'shelter_id' => (int)$finalStop['shelter_id'],
                'shelter_name' => $finalStop['shelter_name'],
                'latitude' => (float)$finalStop['latitude'],
                'longitude' => (float)$finalStop['longitude']
            ],

            'debug_original_stop_count' => count($stops),
            'debug_optimized_stop_count' => count($optimizedStops),
            'debug_google_maps_url' => $mapsUrl,
            'debug_maps_point_count' => count($optimizedStops) + 1,
            'debug_maps_url_mode' => count($optimizedStops) === 2 ? 'TWO_STOP_MANUAL_ORDER_WITH_WAYPOINT' : 'GOOGLE_ROUTES_OPTIMIZED',

            'optimized_stops' => array_map(function ($stop, $index) {
                return [
                    'order' => $index + 1,
                    'delivery_id' => (int)$stop['delivery_id'],
                    'shelter_id' => (int)$stop['shelter_id'],
                    'shelter_name' => $stop['shelter_name'],
                    'latitude' => (float)$stop['latitude'],
                    'longitude' => (float)$stop['longitude']
                ];
            }, $optimizedStops, array_keys($optimizedStops))
        ]);
    }

    private function callGoogleRoutesApi(string $apiKey, array $requestBody): array
    {
        $url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

        $headers = [
            'Content-Type: application/json',
            'X-Goog-Api-Key: ' . $apiKey,
            'X-Goog-FieldMask: routes.duration,routes.distanceMeters,routes.optimizedIntermediateWaypointIndex'
        ];

        $ch = curl_init($url);

        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_POSTFIELDS => json_encode($requestBody),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30
        ]);

        $raw = curl_exec($ch);
        $error = curl_error($ch);
        $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);

        curl_close($ch);

        if ($raw === false || $error) {
            return [
                'ok' => false,
                'error' => $error ?: 'Unknown cURL error'
            ];
        }

        $data = json_decode($raw, true);

        if ($status < 200 || $status >= 300) {
            return [
                'ok' => false,
                'error' => $data ?: $raw
            ];
        }

        return [
            'ok' => true,
            'data' => $data
        ];
    }

    private function parseGoogleDurationSeconds(string $duration): int
    {
        return (int)str_replace('s', '', $duration);
    }

    private function buildGoogleMapsUrl(float $originLat, float $originLng, array $orderedStops): string
    {
        if (count($orderedStops) === 0) {
            return '';
        }

        /*
        * Google Maps multi-stop route preview.
        *
        * origin      = NGO/current driver location
        * waypoints   = delivery stops before final stop
        * destination = last optimized delivery stop
        *
        * IMPORTANT:
        * Do not use dir_action=navigate.
        * Do not use /dir/point1/point2 path-style URL.
        */

        $origin = $originLat . ',' . $originLng;

        $lastStop = $orderedStops[count($orderedStops) - 1];

        $destination = $lastStop['latitude'] . ',' . $lastStop['longitude'];

        $waypoints = [];

        for ($i = 0; $i < count($orderedStops) - 1; $i++) {
            $waypoints[] = $orderedStops[$i]['latitude'] . ',' . $orderedStops[$i]['longitude'];
        }

        $params = [
            'api' => '1',
            'origin' => $origin,
            'destination' => $destination,
            'travelmode' => 'driving'
        ];

        if (count($waypoints) > 0) {
            $params['waypoints'] = implode('|', $waypoints);
        }

        return 'https://www.google.com/maps/dir/?' . http_build_query($params, '', '&', PHP_QUERY_RFC3986);
    }

    private function findFarthestStopIndex(float $originLat, float $originLng, array $stops): int
    {
        $farthestIndex = 0;
        $farthestDistance = -1;

        foreach ($stops as $index => $stop) {
            $distance = $this->haversineKm(
                $originLat,
                $originLng,
                (float)$stop['latitude'],
                (float)$stop['longitude']
            );

            if ($distance > $farthestDistance) {
                $farthestDistance = $distance;
                $farthestIndex = $index;
            }
        }

        return $farthestIndex;
    }

    private function haversineKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadius = 6371;

        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) * sin($dLat / 2)
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2))
            * sin($dLng / 2) * sin($dLng / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadius * $c;
    }
}