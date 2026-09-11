<?php

declare(strict_types=1);

use App\Application\Actions\User\ListUsersAction;
use App\Application\Actions\User\ViewUserAction;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

use Slim\App;
use Slim\Routing\RouteCollectorProxy;
use Slim\Interfaces\RouteCollectorProxyInterface as Group;


use App\Controllers\AuthController;
use App\Controllers\MapController;
use App\Controllers\DeliveryController;
use App\Controllers\DonationController;
use App\Controllers\DashboardController;
use App\Controllers\ItemController;
use App\Controllers\NgoDonationController;
use App\Controllers\DeviceTokenController;
use App\Controllers\ShelterRequestController;
use App\Controllers\DependentsController;
use App\Controllers\ToyyibPayController;
use App\Controllers\ProfileController;
use App\Controllers\DeliveryGroupController;
use App\Controllers\BeneficiaryNeedController;


use App\Auth\AuthMiddleware;
use App\Auth\RoleMiddleware;




return function (App $app) {
    $app->options('/{routes:.*}', function (Request $request, Response $response) {
        // CORS Pre-Flight OPTIONS Request Handler
        return $response;
    });

    $app->get('/', function (Request $request, Response $response) {
        $response->getBody()->write('Hello world!');
        return $response;
    });


    // Shelter Requests (public access)
    $app->post('/shelter-requests/guest', [ShelterRequestController::class, 'guest']);
    $app->post('/shelter-requests/claim', [ShelterRequestController::class, 'claim']);

    $app->group('/users', function (Group $group) {
        $group->get('', ListUsersAction::class);
        $group->get('/{id}', ViewUserAction::class);
    });

    // Health check
    $app->get('/health', function ($req, $res) {
        $res->getBody()->write(json_encode(["ok"=>true]));
        return $res->withHeader('Content-Type','application/json');
    });

    // TOYYIBPAY PUBLIC CALLBACK / RETURN
    $app->post('/payment-callback/toyyibpay', [ToyyibPayController::class, 'callback']);
    $app->get('/payment-return/toyyibpay', [ToyyibPayController::class, 'returnPage']);
    $app->get('/receipts/toyyibpay/{token}', [ToyyibPayController::class, 'publicReceiptHtml']);

    // AUTH
    $app->post('/auth/register', [AuthController::class, 'register']);
    $app->post('/auth/login', [AuthController::class, 'login']);
    $app->get('/auth/me', [AuthController::class, 'me'])->add(new AuthMiddleware());

    // PROFILE
    $app->get('/profile/me', [ProfileController::class, 'me'])
        ->add(new AuthMiddleware());

    $app->patch('/profile/me', [ProfileController::class, 'update'])
        ->add(new AuthMiddleware());

    $app->get('/profile/lookups', [ProfileController::class, 'lookups'])
        ->add(new AuthMiddleware());

    // MAP (public access, before login and after login)
    $app->get('/map/shelters', [MapController::class, 'shelters']);
    $app->get('/map/ngos', [MapController::class, 'ngos']);
    $app->get('/map/inventory-needs', [MapController::class, 'inventoryNeeds']);

    // NGO routes
    $app->group('/deliveries', function (RouteCollectorProxy $group) {
        // Group delivery routes MUST be before /{id}
        $group->get('/groups', [DeliveryGroupController::class, 'list']);
        $group->get('/groups/{id}', [DeliveryGroupController::class, 'detail']);
        $group->post('/groups/{id}/optimize', [DeliveryGroupController::class, 'optimize']);

        // Existing individual delivery routes
        $group->get('', [DeliveryController::class, 'list']);
        $group->get('/{id}', [DeliveryController::class, 'detail']);
        $group->patch('/{id}/status', [DeliveryController::class, 'updateStatus']);
        $group->post('/{id}/tracking', [DeliveryController::class, 'addTracking']);
    })
    ->add(new RoleMiddleware(['NGO_STAFF', 'SHELTER_MANAGER', 'ADMIN']))
    ->add(new AuthMiddleware());

    // PUBLIC routes
    $app->group('/donations', function (RouteCollectorProxy $group) {
        $group->post('', [DonationController::class, 'create']);
        $group->get('/my', [DonationController::class, 'my']);
        $group->get('/{id}', [DonationController::class, 'detail']);
        $group->post('/{id}/items', [DonationController::class, 'addItem']);
        $group->post('/{id}/confirm-dropoff', [DonationController::class, 'confirmDropoff']);

        // ToyyibPay protected routes
        $group->post('/{id}/toyyibpay/create-bill', [ToyyibPayController::class, 'createBill']);
        $group->get('/{id}/payment-status', [ToyyibPayController::class, 'paymentStatus']);
        $group->get('/{id}/receipt', [ToyyibPayController::class, 'receipt']);
    })
    ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
    ->add(new AuthMiddleware());

    $app->group('/dependents', function (RouteCollectorProxy $group) {
        $group->get('', [DependentsController::class, 'list']);
        $group->get('/', [DependentsController::class, 'list']);

        $group->post('', [DependentsController::class, 'create']);
        $group->post('/', [DependentsController::class, 'create']);

        $group->get('/{id:[0-9]+}', [DependentsController::class, 'get']);
        $group->put('/{id:[0-9]+}', [DependentsController::class, 'update']);
        $group->delete('/{id:[0-9]+}', [DependentsController::class, 'deactivate']);
        $group->patch('/{id:[0-9]+}/deactivate', [DependentsController::class, 'deactivate']);
    })
    ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
    ->add(new AuthMiddleware());

    $app->group('/beneficiary-needs', function (RouteCollectorProxy $group) {
        $group->get('/my-status', [BeneficiaryNeedController::class, 'myStatus']);
        $group->get('/my', [BeneficiaryNeedController::class, 'my']);
        $group->get('/unmet-for-ngo', [BeneficiaryNeedController::class, 'unmetForNgo']);
        $group->post('', [BeneficiaryNeedController::class, 'create']);
    })
    ->add(new RoleMiddleware(['PUBLIC', 'NGO_STAFF', 'ADMIN']))
    ->add(new AuthMiddleware());

    // DASHBOARD
    $app->get('/dashboard/public', [DashboardController::class, 'publicDashboard'])
        ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
        ->add(new AuthMiddleware());

    $app->get('/dashboard/ngo', [DashboardController::class, 'ngoDashboard'])
        ->add(new RoleMiddleware(['NGO_STAFF', 'ADMIN']))
        ->add(new AuthMiddleware());

    // ITEMS & CATEGORIES (public access)
    $app->get('/items', [ItemController::class, 'list']);
    $app->get('/categories', [ItemController::class, 'categories']);

    // NGO donations (NGO_STAFF / ADMIN)
    $app->group('/ngo', function (RouteCollectorProxy $group) {
        $group->get('/donations', [NgoDonationController::class, 'list']);

        // Edit actual received item quantity before completing donation
        $group->patch('/donations/{id}/items', [NgoDonationController::class, 'updateItems']);

        $group->post('/donations/{id}/mark-received', [NgoDonationController::class, 'markReceived']);
    })
    ->add(new RoleMiddleware(['NGO_STAFF', 'ADMIN']))
    ->add(new AuthMiddleware());

    // Device tokens for push notifications
    $app->group('/device-tokens', function (RouteCollectorProxy $group) {
    $group->post('/register', [DeviceTokenController::class, 'register']);
    $group->post('/unregister', [DeviceTokenController::class, 'unregister']);
    })
    ->add(new AuthMiddleware());

    $app->get('/shelter-requests/lookup', [ShelterRequestController::class, 'lookup']);

    // Only logged-in PUBLIC users should access "my"
    $app->get('/shelter-requests/my', [ShelterRequestController::class, 'my'])
        ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
        ->add(new AuthMiddleware());

    $app->post('/shelter-requests', [ShelterRequestController::class, 'create'])
        ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
        ->add(new AuthMiddleware());

    $app->post('/shelter-requests/{id:[0-9]+}/cancel', [ShelterRequestController::class, 'cancel'])
        ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
        ->add(new AuthMiddleware());

    $app->post('/shelter-requests/{id:[0-9]+}/dependents/assign', [ShelterRequestController::class, 'assignDependents'])
        ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
        ->add(new AuthMiddleware());

    $app->post('/shelter-requests/{id:[0-9]+}/discharge', [ShelterRequestController::class, 'discharge'])
        ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
        ->add(new AuthMiddleware());

    $app->post('/shelter-requests/{id:[0-9]+}/dependents', [ShelterRequestController::class, 'addDependents'])
        ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
        ->add(new AuthMiddleware());

    // $app->post('/shelter-requests/{id:[0-9]+}/dependents/assign', [ShelterRequestController::class, 'assignDependents'])
    //     ->add(new RoleMiddleware(['PUBLIC', 'ADMIN']))
    //     ->add(new AuthMiddleware());
};
