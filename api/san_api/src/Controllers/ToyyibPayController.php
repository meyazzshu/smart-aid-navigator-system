<?php
namespace App\Controllers;

use App\Db;
use App\Http;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ToyyibPayController
{
    private function baseUrl(): string
    {
        return rtrim($_ENV['TOYYIBPAY_BASE_URL'] ?? 'https://dev.toyyibpay.com', '/');
    }

    private function secretKey(): string
    {
        return $_ENV['TOYYIBPAY_SECRET_KEY'] ?? '';
    }

    private function categoryCode(): string
    {
        return $_ENV['TOYYIBPAY_CATEGORY_CODE'] ?? '';
    }

    private function appPublicUrl(): string
    {
        return rtrim($_ENV['APP_PUBLIC_URL'] ?? '', '/');
    }

    private function personIdForUser(\PDO $pdo, int $userId): ?int
    {
        $stmt = $pdo->prepare("SELECT person_id FROM users WHERE user_id = ? LIMIT 1");
        $stmt->execute([$userId]);
        $personId = $stmt->fetchColumn();
        return $personId !== false ? (int)$personId : null;
    }

    private function donorIdForPerson(\PDO $pdo, int $personId): ?int
    {
        $stmt = $pdo->prepare("SELECT donor_id FROM donors WHERE person_id = ? LIMIT 1");
        $stmt->execute([$personId]);
        $donorId = $stmt->fetchColumn();
        return $donorId !== false ? (int)$donorId : null;
    }

    private function getDonorProfile(\PDO $pdo, int $userId): array
    {
        $stmt = $pdo->prepare("
            SELECT 
                u.user_id,
                p.full_name,
                p.email,
                p.phone
            FROM users u
            JOIN persons p ON p.person_id = u.person_id
            WHERE u.user_id = ?
            LIMIT 1
        ");
        $stmt->execute([$userId]);
        $row = $stmt->fetch();

        return $row ?: [
            'full_name' => 'SmartAidNavigator Donor',
            'email' => '',
            'phone' => '',
        ];
    }

    public function createBill(Request $req, Response $res, array $args): Response
    {
        $donationId = (int)$args['id'];

        $auth = $req->getAttribute('auth');
        $userId = (int)($auth['user_id'] ?? 0);

        $body = (array)$req->getParsedBody();
        $amount = (float)($body['amount'] ?? 0);

        if ($amount <= 0) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Valid amount is required'
            ], 400);
        }

        if ($this->secretKey() === '' || $this->categoryCode() === '' || $this->appPublicUrl() === '') {
            return Http::json($res, [
                'ok' => false,
                'error' => 'ToyyibPay configuration is missing. Check .env values.'
            ], 500);
        }

        $pdo = Db::conn();

        $personId = $this->personIdForUser($pdo, $userId);
        if (!$personId) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'User profile missing'
            ], 404);
        }

        $donorId = $this->donorIdForPerson($pdo, $personId);
        if (!$donorId) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Donor profile missing'
            ], 404);
        }

        $stmt = $pdo->prepare("
            SELECT 
                d.donation_id,
                d.donor_id,
                d.donation_type,
                d.status,
                d.ngo_id,
                d.remarks,
                n.ngo_name
            FROM donations d
            LEFT JOIN ngos n ON n.ngo_id = d.ngo_id
            WHERE d.donation_id = ? AND d.donor_id = ?
            LIMIT 1
        ");
        $stmt->execute([$donationId, $donorId]);
        $donation = $stmt->fetch();

        if (!$donation) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Donation not found'
            ], 404);
        }

        if ($donation['donation_type'] !== 'MONEY') {
            return Http::json($res, [
                'ok' => false,
                'error' => 'ToyyibPay payment is only for MONEY donations'
            ], 400);
        }

        if ($donation['status'] === 'COMPLETED') {
            return Http::json($res, [
                'ok' => false,
                'error' => 'This donation is already completed'
            ], 400);
        }

        $profile = $this->getDonorProfile($pdo, $userId);

        $externalRef = 'SAN-DONATION-' . $donationId;
        $amountInSen = (int)round($amount * 100);

        $returnUrl = $this->appPublicUrl() . '/payment-return/toyyibpay';
        $callbackUrl = $this->appPublicUrl() . '/payment-callback/toyyibpay';

        $description = 'Money donation';
        if (!empty($donation['ngo_name'])) {
            $description .= ' to ' . $donation['ngo_name'];
        } else {
            $description .= ' to SmartAidNavigator relief fund';
        }

        $postData = [
            'userSecretKey' => $this->secretKey(),
            'categoryCode' => $this->categoryCode(),

            'billName' => 'SmartAidNavigator Donation #' . $donationId,
            'billDescription' => $description,

            'billPriceSetting' => 1,
            'billPayorInfo' => 1,
            'billAmount' => $amountInSen,

            'billReturnUrl' => $returnUrl,
            'billCallbackUrl' => $callbackUrl,
            'billExternalReferenceNo' => $externalRef,

            'billTo' => $profile['full_name'] ?? 'SmartAidNavigator Donor',
            'billEmail' => $profile['email'] ?? '',
            'billPhone' => $profile['phone'] ?? '',

            // Use FPX / online banking first.
            'billPaymentChannel' => 0,
        ];

        $curl = curl_init();
        curl_setopt($curl, CURLOPT_URL, $this->baseUrl() . '/index.php/api/createBill');
        curl_setopt($curl, CURLOPT_POST, true);
        curl_setopt($curl, CURLOPT_POSTFIELDS, $postData);
        curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($curl, CURLOPT_TIMEOUT, 30);

        $result = curl_exec($curl);
        $error = curl_error($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);

        if ($result === false || $error) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'ToyyibPay request failed: ' . $error
            ], 500);
        }

        $decoded = json_decode($result, true);

        if (!is_array($decoded) || empty($decoded[0]['BillCode'])) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'ToyyibPay did not return BillCode',
                'http_code' => $httpCode,
                'raw' => $result
            ], 500);
        }

        $billCode = $decoded[0]['BillCode'];
        $paymentUrl = $this->baseUrl() . '/' . $billCode;

        $pdo->beginTransaction();

        try {
            $stmt = $pdo->prepare("
                INSERT INTO payments (
                    donation_id,
                    amount,
                    currency,
                    method,
                    provider,
                    provider_ref,
                    provider_bill_code,
                    external_reference_no,
                    payment_status
                )
                VALUES (
                    :donation_id,
                    :amount,
                    'MYR',
                    'FPX',
                    'TOYYIBPAY',
                    :provider_ref,
                    :provider_bill_code,
                    :external_reference_no,
                    'PENDING'
                )
                ON DUPLICATE KEY UPDATE
                    amount = VALUES(amount),
                    method = VALUES(method),
                    provider_ref = VALUES(provider_ref),
                    provider_bill_code = VALUES(provider_bill_code),
                    external_reference_no = VALUES(external_reference_no),
                    payment_status = 'PENDING',
                    paid_at = NULL
            ");

            $stmt->execute([
                ':donation_id' => $donationId,
                ':amount' => $amount,
                ':provider_ref' => $billCode,
                ':provider_bill_code' => $billCode,
                ':external_reference_no' => $externalRef,
            ]);

            $stmt = $pdo->prepare("
                UPDATE donations
                SET status = 'PENDING'
                WHERE donation_id = ?
            ");
            $stmt->execute([$donationId]);

            $pdo->commit();
        } catch (\Throwable $e) {
            $pdo->rollBack();

            return Http::json($res, [
                'ok' => false,
                'error' => 'Failed to save payment: ' . $e->getMessage()
            ], 500);
        }

        return Http::json($res, [
            'ok' => true,
            'donation_id' => $donationId,
            'bill_code' => $billCode,
            'payment_url' => $paymentUrl,
            'amount' => $amount,
            'currency' => 'MYR',
            'callback_url_used' => $callbackUrl,
            'return_url_used' => $returnUrl
        ]);
    }

    public function paymentStatus(Request $req, Response $res, array $args): Response
    {
        $donationId = (int)$args['id'];

        $auth = $req->getAttribute('auth');
        $userId = (int)($auth['user_id'] ?? 0);

        $pdo = Db::conn();

        $personId = $this->personIdForUser($pdo, $userId);
        if (!$personId) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'User profile missing'
            ], 404);
        }

        $donorId = $this->donorIdForPerson($pdo, $personId);
        if (!$donorId) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Donor profile missing'
            ], 404);
        }

        $stmt = $pdo->prepare("
            SELECT 
                d.donation_id,
                d.status AS donation_status,
                p.payment_status,
                p.amount,
                p.currency,
                p.method,
                p.provider,
                p.provider_bill_code,
                p.provider_invoice_no,
                p.paid_at
            FROM donations d
            LEFT JOIN payments p 
                ON p.donation_id = d.donation_id 
               AND p.provider = 'TOYYIBPAY'
            WHERE d.donation_id = ? AND d.donor_id = ?
            LIMIT 1
        ");
        $stmt->execute([$donationId, $donorId]);
        $row = $stmt->fetch();

        if (!$row) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Donation not found'
            ], 404);
        }

        return Http::json($res, [
            'ok' => true,
            'payment' => $row
        ]);
    }

    public function callback(Request $req, Response $res): Response
    {
        $body = (array)$req->getParsedBody();

        $status = (string)($body['status'] ?? '');
        $orderId = (string)($body['order_id'] ?? '');
        $refNo = (string)($body['refno'] ?? '');
        $billCode = (string)($body['billcode'] ?? '');
        $amount = (string)($body['amount'] ?? '');
        $reason = (string)($body['reason'] ?? '');
        $receivedHash = (string)($body['hash'] ?? '');

        $expectedHash = md5($this->secretKey() . $status . $orderId . $refNo . 'ok');

        if ($receivedHash !== '' && !hash_equals($expectedHash, $receivedHash)) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Invalid ToyyibPay callback hash'
            ], 400);
        }

        if (!preg_match('/SAN-DONATION-(\d+)/', $orderId, $matches)) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Invalid order_id'
            ], 400);
        }

        $donationId = (int)$matches[1];
        $rawJson = json_encode($body);

        $pdo = Db::conn();
        $pdo->beginTransaction();

        try {
            if ($status === '1') {
                $receiptToken = bin2hex(random_bytes(32));

                $stmt = $pdo->prepare("
                    UPDATE payments
                    SET 
                        payment_status = 'PAID',
                        provider_ref = :refno,
                        provider_bill_code = :billcode,
                        provider_invoice_no = :invoice_no,
                        callback_raw = :callback_raw,
                        paid_at = NOW(),
                        receipt_token = COALESCE(receipt_token, :receipt_token),
                        receipt_issued_at = COALESCE(receipt_issued_at, NOW())
                    WHERE donation_id = :donation_id
                    AND provider = 'TOYYIBPAY'
                ");

                $stmt->execute([
                    ':refno' => $refNo,
                    ':billcode' => $billCode,
                    ':invoice_no' => $body['transaction_id'] ?? $refNo,
                    ':callback_raw' => $rawJson,
                    ':receipt_token' => $receiptToken,
                    ':donation_id' => $donationId,
                ]);

                $stmt = $pdo->prepare("
                    UPDATE donations
                    SET status = 'COMPLETED'
                    WHERE donation_id = ?
                    AND donation_type = 'MONEY'
                ");
                $stmt->execute([$donationId]);
            } elseif ($status === '3') {
                $stmt = $pdo->prepare("
                    UPDATE payments
                    SET 
                        payment_status = 'FAILED',
                        provider_ref = :refno,
                        provider_bill_code = :billcode,
                        callback_raw = :callback_raw
                    WHERE donation_id = :donation_id
                      AND provider = 'TOYYIBPAY'
                ");

                $stmt->execute([
                    ':refno' => $refNo,
                    ':billcode' => $billCode,
                    ':callback_raw' => $rawJson,
                    ':donation_id' => $donationId,
                ]);

                $stmt = $pdo->prepare("
                    UPDATE donations
                    SET status = 'PENDING'
                    WHERE donation_id = ?
                      AND donation_type = 'MONEY'
                ");
                $stmt->execute([$donationId]);
            } else {
                $stmt = $pdo->prepare("
                    UPDATE payments
                    SET 
                        payment_status = 'PENDING',
                        provider_ref = :refno,
                        provider_bill_code = :billcode,
                        callback_raw = :callback_raw
                    WHERE donation_id = :donation_id
                      AND provider = 'TOYYIBPAY'
                ");

                $stmt->execute([
                    ':refno' => $refNo,
                    ':billcode' => $billCode,
                    ':callback_raw' => $rawJson,
                    ':donation_id' => $donationId,
                ]);
            }

            $pdo->commit();

            return Http::json($res, [
                'ok' => true,
                'message' => 'Callback processed',
                'donation_id' => $donationId,
                'status' => $status,
                'reason' => $reason,
                'amount' => $amount
            ]);
        } catch (\Throwable $e) {
            $pdo->rollBack();

            return Http::json($res, [
                'ok' => false,
                'error' => 'Callback processing failed: ' . $e->getMessage()
            ], 500);
        }
    }

    public function returnPage(Request $req, Response $res): Response
    {
        $html = <<<HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Payment Completed</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body {
            font-family: Arial, sans-serif;
            background: #f3f9fc;
            color: #03466e;
            padding: 32px;
            text-align: center;
          }
          .card {
            max-width: 420px;
            margin: 40px auto;
            background: #ffffff;
            padding: 28px;
            border-radius: 18px;
            box-shadow: 0 8px 24px rgba(3,70,110,0.12);
          }
          h1 {
            font-size: 24px;
            margin-bottom: 8px;
          }
          p {
            color: #333;
            line-height: 1.5;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>Payment Process Completed</h1>
          <p>You may return to the SmartAidNavigator mobile app.</p>
          <p>Your donation status will update after ToyyibPay confirms the payment.</p>
        </div>
      </body>
      </html>
      HTML;

        $res->getBody()->write($html);
        return $res->withHeader('Content-Type', 'text/html');
    }

    public function receipt(Request $req, Response $res, array $args): Response
    {
        $donationId = (int)$args['id'];

        $auth = $req->getAttribute('auth');
        $userId = (int)($auth['user_id'] ?? 0);

        $pdo = Db::conn();

        $personId = $this->personIdForUser($pdo, $userId);
        if (!$personId) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'User profile missing'
            ], 404);
        }

        $donorId = $this->donorIdForPerson($pdo, $personId);
        if (!$donorId) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Donor profile missing'
            ], 404);
        }

        $stmt = $pdo->prepare("
            SELECT
                d.donation_id,
                d.status AS donation_status,
                d.created_at AS donation_created_at,
                d.remarks,
                p.payment_id,
                p.amount,
                p.currency,
                p.method,
                p.provider,
                p.provider_ref,
                p.provider_bill_code,
                p.provider_invoice_no,
                p.payment_status,
                p.paid_at,
                p.receipt_token,
                p.receipt_issued_at,
                donor_person.full_name AS donor_name,
                donor_person.email AS donor_email,
                donor_person.phone AS donor_phone,
                donor_person.ic_or_passport AS donor_ic,
                n.ngo_name,
                n.email AS ngo_email,
                n.phone AS ngo_phone,
                n.address_line AS ngo_address,
                n.city AS ngo_city,
                n.state AS ngo_state,
                n.postal_code AS ngo_postal,
                COALESCE(n.is_tax_exempt, 0) AS is_tax_exempt,
                n.tax_exemption_no
            FROM donations d
            JOIN donors dr ON dr.donor_id = d.donor_id
            JOIN persons donor_person ON donor_person.person_id = dr.person_id
            LEFT JOIN ngos n ON n.ngo_id = d.ngo_id
            LEFT JOIN payments p 
                ON p.donation_id = d.donation_id
              AND p.provider = 'TOYYIBPAY'
            WHERE d.donation_id = ?
              AND d.donor_id = ?
              AND d.donation_type = 'MONEY'
            LIMIT 1
        ");
        $stmt->execute([$donationId, $donorId]);
        $row = $stmt->fetch();

        if (!$row) {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Receipt not found'
            ], 404);
        }

        if ($row['payment_status'] !== 'PAID' || $row['donation_status'] !== 'COMPLETED') {
            return Http::json($res, [
                'ok' => false,
                'error' => 'Receipt is only available after successful payment'
            ], 400);
        }

        if (empty($row['receipt_token'])) {
            $receiptToken = bin2hex(random_bytes(32));

            $stmt = $pdo->prepare("
                UPDATE payments
                SET receipt_token = ?, receipt_issued_at = COALESCE(receipt_issued_at, NOW())
                WHERE payment_id = ?
            ");
            $stmt->execute([$receiptToken, $row['payment_id']]);

            $row['receipt_token'] = $receiptToken;
            $row['receipt_issued_at'] = date('Y-m-d H:i:s');
        }

        $receiptUrl = $this->appPublicUrl() . '/receipts/toyyibpay/' . $row['receipt_token'];

        return Http::json($res, [
            'ok' => true,
            'receipt' => [
                'receipt_no' => 'SAN-RCPT-' . str_pad((string)$row['payment_id'], 6, '0', STR_PAD_LEFT),
                'donation_id' => (int)$row['donation_id'],
                'donor_name' => $row['donor_name'],
                'donor_email' => $row['donor_email'],
                'donor_phone' => $row['donor_phone'],
                'donor_ic' => $row['donor_ic'],
                'ngo_name' => $row['ngo_name'] ?: 'SmartAidNavigator General Relief Fund',
                'ngo_email' => $row['ngo_email'],
                'ngo_phone' => $row['ngo_phone'],
                'ngo_address' => trim(implode(', ', array_filter([
                    $row['ngo_address'],
                    $row['ngo_city'],
                    $row['ngo_state'],
                    $row['ngo_postal'],
                ]))),
                'amount' => $row['amount'],
                'currency' => $row['currency'],
                'method' => $row['method'],
                'provider' => $row['provider'],
                'payment_status' => $row['payment_status'],
                'donation_status' => $row['donation_status'],
                'provider_bill_code' => $row['provider_bill_code'],
                'provider_invoice_no' => $row['provider_invoice_no'],
                'paid_at' => $row['paid_at'],
                'receipt_issued_at' => $row['receipt_issued_at'],
                'is_tax_exempt' => (int)$row['is_tax_exempt'] === 1,
                'tax_exemption_no' => $row['tax_exemption_no'],
                'receipt_url' => $receiptUrl,
                'download_url' => $receiptUrl . '?download=1',
            ]
        ]);
    }

    public function publicReceiptHtml(Request $req, Response $res, array $args): Response
    {
        $token = trim((string)$args['token']);
        $download = (string)($req->getQueryParams()['download'] ?? '') === '1';

        if ($token === '') {
            $res->getBody()->write('Invalid receipt token.');
            return $res->withStatus(400);
        }

        $pdo = Db::conn();

        $stmt = $pdo->prepare("
            SELECT
                d.donation_id,
                d.status AS donation_status,
                d.created_at AS donation_created_at,
                d.remarks,
                p.payment_id,
                p.amount,
                p.currency,
                p.method,
                p.provider,
                p.provider_ref,
                p.provider_bill_code,
                p.provider_invoice_no,
                p.payment_status,
                p.paid_at,
                p.receipt_token,
                p.receipt_issued_at,
                donor_person.full_name AS donor_name,
                donor_person.email AS donor_email,
                donor_person.phone AS donor_phone,
                donor_person.ic_or_passport AS donor_ic,
                n.ngo_name,
                n.email AS ngo_email,
                n.phone AS ngo_phone,
                n.address_line AS ngo_address,
                n.city AS ngo_city,
                n.state AS ngo_state,
                n.postal_code AS ngo_postal,
                COALESCE(n.is_tax_exempt, 0) AS is_tax_exempt,
                n.tax_exemption_no
            FROM payments p
            JOIN donations d ON d.donation_id = p.donation_id
            JOIN donors dr ON dr.donor_id = d.donor_id
            JOIN persons donor_person ON donor_person.person_id = dr.person_id
            LEFT JOIN ngos n ON n.ngo_id = d.ngo_id
            WHERE p.receipt_token = ?
              AND p.provider = 'TOYYIBPAY'
              AND p.payment_status = 'PAID'
              AND d.status = 'COMPLETED'
            LIMIT 1
        ");
        $stmt->execute([$token]);
        $row = $stmt->fetch();

        if (!$row) {
            $res->getBody()->write('Receipt not found or payment not completed.');
            return $res->withStatus(404);
        }

        $receiptNo = 'SAN-RCPT-' . str_pad((string)$row['payment_id'], 6, '0', STR_PAD_LEFT);

        $ngoName = htmlspecialchars($row['ngo_name'] ?: 'SmartAidNavigator General Relief Fund');
        $donorName = htmlspecialchars($row['donor_name'] ?: '-');
        $donorEmail = htmlspecialchars($row['donor_email'] ?: '-');
        $donorPhone = htmlspecialchars($row['donor_phone'] ?: '-');
        $donorIc = htmlspecialchars($row['donor_ic'] ?: '-');
        $amount = htmlspecialchars($row['currency'] . ' ' . number_format((float)$row['amount'], 2));
        $billCode = htmlspecialchars($row['provider_bill_code'] ?: '-');
        $invoiceNo = htmlspecialchars($row['provider_invoice_no'] ?: '-');
        $paidAt = htmlspecialchars($row['paid_at'] ?: '-');
        $issuedAt = htmlspecialchars($row['receipt_issued_at'] ?: '-');
        $taxNo = htmlspecialchars($row['tax_exemption_no'] ?: '-');

        $isTaxExempt = (int)$row['is_tax_exempt'] === 1;

        $taxBox = $isTaxExempt
            ? "<div class='tax-ok'>Tax Exemption Supporting Receipt<br><small>LHDN Approval / Reference No: {$taxNo}</small></div>"
            : "<div class='tax-note'>This is a payment receipt. Tax exemption is subject to the recipient organisation's LHDN approval status.</div>";

        $html = <<<HTML
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>{$receiptNo}</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        body {
          font-family: Arial, sans-serif;
          background: #f3f9fc;
          color: #242424;
          padding: 24px;
        }
        .receipt {
          max-width: 760px;
          margin: 0 auto;
          background: #ffffff;
          border-radius: 18px;
          overflow: hidden;
          box-shadow: 0 8px 24px rgba(3,70,110,0.12);
        }
        .header {
          background: linear-gradient(135deg, #03466e, #54afe6);
          color: white;
          padding: 28px;
        }
        .header h1 {
          margin: 0;
          font-size: 26px;
        }
        .header p {
          margin: 8px 0 0;
          opacity: 0.85;
        }
        .content {
          padding: 28px;
        }
        .badge {
          display: inline-block;
          background: rgba(25,135,84,0.12);
          color: #198754;
          padding: 6px 12px;
          border-radius: 999px;
          font-weight: bold;
          font-size: 13px;
          margin-bottom: 16px;
        }
        .row {
          display: flex;
          border-bottom: 1px solid #e7eef3;
          padding: 10px 0;
          gap: 16px;
        }
        .label {
          width: 220px;
          color: #666;
          font-size: 14px;
        }
        .value {
          flex: 1;
          font-weight: bold;
          color: #03466e;
          font-size: 14px;
        }
        .section-title {
          margin-top: 24px;
          margin-bottom: 8px;
          color: #03466e;
          font-size: 16px;
          font-weight: bold;
        }
        .tax-ok {
          margin-top: 22px;
          background: rgba(25,135,84,0.12);
          color: #198754;
          padding: 14px;
          border-radius: 12px;
          font-weight: bold;
        }
        .tax-note {
          margin-top: 22px;
          background: rgba(253,126,20,0.12);
          color: #9a4b00;
          padding: 14px;
          border-radius: 12px;
          font-weight: bold;
          line-height: 1.5;
        }
        .footer {
          padding: 20px 28px 28px;
          color: #666;
          font-size: 12px;
          line-height: 1.5;
        }
        .actions {
          max-width: 760px;
          margin: 16px auto;
          text-align: center;
        }
        button {
          background: #03466e;
          color: white;
          border: none;
          padding: 12px 18px;
          border-radius: 10px;
          font-weight: bold;
          cursor: pointer;
        }
        @media print {
          body { background: white; padding: 0; }
          .receipt { box-shadow: none; border-radius: 0; }
          .actions { display: none; }
        }
      </style>
    </head>
    <body>
      <div class="actions">
        <button onclick="window.print()">Print / Save as PDF</button>
      </div>

      <div class="receipt">
        <div class="header">
          <h1>SmartAidNavigator Receipt</h1>
          <p>Payment Receipt for Money Donation</p>
        </div>

        <div class="content">
          <div class="badge">PAID</div>

          <div class="section-title">Receipt Information</div>
          <div class="row"><div class="label">Receipt No</div><div class="value">{$receiptNo}</div></div>
          <div class="row"><div class="label">Donation ID</div><div class="value">#{$row['donation_id']}</div></div>
          <div class="row"><div class="label">Issued At</div><div class="value">{$issuedAt}</div></div>

          <div class="section-title">Donor Information</div>
          <div class="row"><div class="label">Donor Name</div><div class="value">{$donorName}</div></div>
          <div class="row"><div class="label">IC / Passport</div><div class="value">{$donorIc}</div></div>
          <div class="row"><div class="label">Email</div><div class="value">{$donorEmail}</div></div>
          <div class="row"><div class="label">Phone</div><div class="value">{$donorPhone}</div></div>

          <div class="section-title">Recipient</div>
          <div class="row"><div class="label">Recipient Name</div><div class="value">{$ngoName}</div></div>

          <div class="section-title">Payment Details</div>
          <div class="row"><div class="label">Amount</div><div class="value">{$amount}</div></div>
          <div class="row"><div class="label">Payment Provider</div><div class="value">ToyyibPay</div></div>
          <div class="row"><div class="label">Payment Method</div><div class="value">{$row['method']}</div></div>
          <div class="row"><div class="label">ToyyibPay Bill Code</div><div class="value">{$billCode}</div></div>
          <div class="row"><div class="label">Transaction / Invoice No</div><div class="value">{$invoiceNo}</div></div>
          <div class="row"><div class="label">Paid At</div><div class="value">{$paidAt}</div></div>

          {$taxBox}
        </div>

        <div class="footer">
          This receipt is generated by SmartAidNavigator for payment tracking purposes.
          Tax deduction eligibility depends on the recipient organisation's LHDN approval status and applicable Malaysian tax rules.
        </div>
      </div>
    </body>
    </html>
    HTML;

        $res->getBody()->write($html);

        $response = $res->withHeader('Content-Type', 'text/html');

        if ($download) {
            $safeName = $receiptNo . '.html';
            $response = $response->withHeader(
                'Content-Disposition',
                'attachment; filename="' . $safeName . '"'
            );
        }

        return $response;
    }
}