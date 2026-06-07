<?php
// api/index.php

// 1. Handle CORS (Cross-Origin Resource Sharing)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, Accept");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

header("Content-Type: application/json");

require_once __DIR__ . '/config.php';

// Helper: Get Bearer Token
function getAuthorizationHeader() {
    $headers = null;
    if (function_exists('getallheaders')) {
        $headers = getallheaders();
        $headers = array_change_key_case($headers, CASE_LOWER);
        if (isset($headers['authorization'])) {
            return $headers['authorization'];
        }
    }
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        return $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        return $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    }
    return null;
}

// Helper: Authenticate user by token
function getAuthUser($pdo) {
    $authHeader = getAuthorizationHeader();
    if (!$authHeader || !preg_match('/Bearer\s(\S+)/i', $authHeader, $matches)) {
        http_response_code(401);
        echo json_encode(["error" => "Unauthorized: Token missing"]);
        exit;
    }

    $token = $matches[1];

    $stmt = $pdo->prepare("
        SELECT u.* FROM users u
        JOIN user_tokens ut ON u.id = ut.user_id
        WHERE ut.token = ? AND ut.expires_at > NOW()
        LIMIT 1
    ");
    $stmt->execute([$token]);
    $user = $stmt->fetch();

    if (!$user) {
        http_response_code(401);
        echo json_encode(["error" => "Unauthorized: Invalid or expired token"]);
        exit;
    }

    $user['id'] = (int)$user['id'];
    if ($user['store_id'] !== null) $user['store_id'] = (int)$user['store_id'];
    if ($user['tenant_id'] !== null) $user['tenant_id'] = (int)$user['tenant_id'];

    return $user;
}

try {
    $pdo = getDBConnection();

    // 2. Parse Route
    $requestUri = $_SERVER['REQUEST_URI'];
    $path = parse_url($requestUri, PHP_URL_PATH);
    $route = $path;

    // Support running under subdirectories (like XAMPP's htdocs/protoype-kasir/api)
    if (preg_match('/(\/api\/.*)$/', $path, $matches)) {
        $route = $matches[1];
    }

    $route = rtrim($route, '/');
    $method = $_SERVER['REQUEST_METHOD'];

    // 3. Router
    if ($method === 'POST' && $route === '/api/auth/register-owner') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['name']) || empty($input['email']) || empty($input['password']) || empty($input['verification_code'])) {
            http_response_code(400);
            echo json_encode(["error" => "Name, email, password, and verification_code are required"]);
            exit;
        }

        // Verify code
        $stmtCode = $pdo->prepare("SELECT id FROM verification_codes WHERE code = ? AND is_used = FALSE LIMIT 1");
        $stmtCode->execute([$input['verification_code']]);
        $verif = $stmtCode->fetch();
        if (!$verif) {
            http_response_code(400);
            echo json_encode(["error" => "Invalid or already used verification code"]);
            exit;
        }

        // Check uniqueness
        $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ? LIMIT 1");
        $stmt->execute([$input['email']]);
        if ($stmt->fetch()) {
            http_response_code(400);
            echo json_encode(["error" => "The email has already been taken."]);
            exit;
        }

        $pdo->beginTransaction();
        try {
            $passwordHash = password_hash($input['password'], PASSWORD_BCRYPT);
            $stmt = $pdo->prepare("INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, 'owner')");
            $stmt->execute([$input['name'], $input['email'], $passwordHash]);
            $userId = $pdo->lastInsertId();

            $pdo->exec("UPDATE verification_codes SET is_used = TRUE WHERE id = " . $verif['id']);
            $pdo->commit();
        } catch (Exception $e) {
            $pdo->rollBack();
            http_response_code(500);
            echo json_encode(["error" => "Database error"]);
            exit;
        }

        // Fetch user
        $stmt = $pdo->prepare("SELECT id, name, email, role, store_id FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        $user = $stmt->fetch();
        $user['id'] = (int)$user['id'];

        // Token
        $token = bin2hex(random_bytes(32));
        $stmtToken = $pdo->prepare("INSERT INTO user_tokens (user_id, token, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 2 HOUR))");
        $stmtToken->execute([$userId, $token]);

        http_response_code(201);
        echo json_encode([
            "message" => "Owner registered successfully",
            "user" => $user,
            "access_token" => $token,
            "token_type" => "bearer",
            "expires_in" => 7200
        ]);
        exit;

    } elseif ($method === 'POST' && $route === '/api/auth/login') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['email']) || empty($input['password'])) {
            http_response_code(400);
            echo json_encode(["error" => "Email and password are required"]);
            exit;
        }

        $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ? LIMIT 1");
        $stmt->execute([$input['email']]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($input['password'], $user['password'])) {
            http_response_code(401);
            echo json_encode(["error" => "Unauthorized"]);
            exit;
        }

        if (!$user['is_active']) {
            http_response_code(403);
            echo json_encode(["error" => "Your account has been disabled"]);
            exit;
        }

        if ($user['role'] === 'kasir' && $user['store_id']) {
            // Check if owner is disabled
            $stmtOwner = $pdo->prepare("SELECT u.is_active FROM users u JOIN stores s ON u.id = s.owner_id WHERE s.id = ? LIMIT 1");
            $stmtOwner->execute([$user['store_id']]);
            $owner = $stmtOwner->fetch();
            if ($owner && !$owner['is_active']) {
                http_response_code(403);
                echo json_encode(["error" => "Your store's owner account has been disabled"]);
                exit;
            }
        }

        $userResponse = [
            "id" => (int)$user['id'],
            "name" => $user['name'],
            "email" => $user['email'],
            "role" => $user['role'],
            "store_id" => $user['store_id'] !== null ? (int)$user['store_id'] : null,
            "tenant_id" => $user['tenant_id'] !== null ? (int)$user['tenant_id'] : null,
        ];

        // Generate Token
        $token = bin2hex(random_bytes(32));
        $stmtToken = $pdo->prepare("INSERT INTO user_tokens (user_id, token, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 2 HOUR))");
        $stmtToken->execute([$user['id'], $token]);

        http_response_code(200);
        echo json_encode([
            "access_token" => $token,
            "token_type" => "bearer",
            "expires_in" => 7200,
            "user" => $userResponse
        ]);
        exit;

    } elseif ($method === 'POST' && $route === '/api/auth/logout') {
        $authHeader = getAuthorizationHeader();
        if ($authHeader && preg_match('/Bearer\s(\S+)/i', $authHeader, $matches)) {
            $token = $matches[1];
            $stmt = $pdo->prepare("DELETE FROM user_tokens WHERE token = ?");
            $stmt->execute([$token]);
        }
        http_response_code(200);
        echo json_encode(["message" => "Successfully logged out"]);
        exit;

    } elseif ($method === 'GET' && $route === '/api/auth/me') {
        $user = getAuthUser($pdo);
        $userResponse = [
            "id" => $user['id'],
            "name" => $user['name'],
            "email" => $user['email'],
            "role" => $user['role'],
            "store_id" => $user['store_id'],
            "tenant_id" => $user['tenant_id']
        ];
        http_response_code(200);
        echo json_encode($userResponse);
        exit;

    } elseif ($method === 'GET' && $route === '/api/store/menus') {
        $user = getAuthUser($pdo);

        if ($user['role'] === 'super_admin') {
            $stmt = $pdo->query("SELECT * FROM menus");
            $menus = $stmt->fetchAll();
        } elseif ($user['role'] === 'owner') {
            $stmt = $pdo->prepare("
                SELECT m.* FROM menus m
                JOIN stores s ON m.store_id = s.id
                WHERE s.owner_id = ?
            ");
            $stmt->execute([$user['id']]);
            $menus = $stmt->fetchAll();
        } else {
            $storeId = $user['store_id'] ?? 1;
            $stmt = $pdo->prepare("SELECT * FROM menus WHERE store_id = ?");
            $stmt->execute([$storeId]);
            $menus = $stmt->fetchAll();
        }

        foreach ($menus as &$menu) {
            $menu['id'] = (int)$menu['id'];
            $menu['store_id'] = (int)$menu['store_id'];
            $menu['price'] = (double)$menu['price'];
        }

        http_response_code(200);
        echo json_encode($menus);
        exit;

    } elseif ($method === 'POST' && $route === '/api/menus') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner' && $user['role'] !== 'super_admin') {
            http_response_code(403);
            echo json_encode(["error" => "Forbidden: Owner only"]);
            exit;
        }

        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['name']) || empty($input['price']) || empty($input['category'])) {
            http_response_code(400);
            echo json_encode(["error" => "Name, price, and category are required"]);
            exit;
        }

        $storeId = 1;
        if ($user['role'] === 'owner') {
            $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
            $stmtStore->execute([$user['id']]);
            $store = $stmtStore->fetch();
            $storeId = $store ? (int)$store['id'] : 1;
        }

        $stmt = $pdo->prepare("INSERT INTO menus (store_id, name, price, category) VALUES (?, ?, ?, ?)");
        $stmt->execute([$storeId, $input['name'], $input['price'], $input['category']]);
        $menuId = $pdo->lastInsertId();

        $stmt = $pdo->prepare("SELECT * FROM menus WHERE id = ?");
        $stmt->execute([$menuId]);
        $newMenu = $stmt->fetch();

        $newMenu['id'] = (int)$newMenu['id'];
        $newMenu['store_id'] = (int)$newMenu['store_id'];
        $newMenu['price'] = (double)$newMenu['price'];

        http_response_code(201);
        echo json_encode($newMenu);
        exit;

    } elseif ($method === 'PUT' && preg_match('/^\/api\/menus\/(\d+)$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner' && $user['role'] !== 'super_admin') {
            http_response_code(403);
            echo json_encode(["error" => "Forbidden: Owner only"]);
            exit;
        }

        $menuId = $matches[1];
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['name']) || empty($input['price']) || empty($input['category'])) {
            http_response_code(400);
            echo json_encode(["error" => "Name, price, and category are required"]);
            exit;
        }

        $stmt = $pdo->prepare("UPDATE menus SET name = ?, price = ?, category = ? WHERE id = ?");
        $stmt->execute([$input['name'], $input['price'], $input['category'], $menuId]);

        echo json_encode(["message" => "Menu updated successfully"]);
        exit;

    } elseif ($method === 'DELETE' && preg_match('/^\/api\/menus\/(\d+)$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner' && $user['role'] !== 'super_admin') {
            http_response_code(403);
            echo json_encode(["error" => "Forbidden: Owner only"]);
            exit;
        }

        $menuId = $matches[1];
        $stmt = $pdo->prepare("DELETE FROM menus WHERE id = ?");
        $stmt->execute([$menuId]);

        echo json_encode(["message" => "Menu deleted successfully"]);
        exit;

    } elseif ($method === 'POST' && $route === '/api/qris/generate') {
        $user = getAuthUser($pdo);
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['total_amount'])) {
            http_response_code(400);
            echo json_encode(["error" => "total_amount is required"]);
            exit;
        }

        $serverKey = 'Mid-server-pScqIkUSLacGu739R4FnTDFO'; // User's server key
        $orderId = 'QRIS-' . time() . '-' . rand(100, 999);
        $grossAmount = (int)$input['total_amount'];

        $payload = [
            "payment_type" => "qris",
            "transaction_details" => [
                "order_id" => $orderId,
                "gross_amount" => $grossAmount
            ]
        ];

        $ch = curl_init('https://api.sandbox.midtrans.com/v2/charge');
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Accept: application/json',
            'Authorization: Basic ' . base64_encode($serverKey . ':')
        ]);

        $response = curl_exec($ch);
        curl_close($ch);

        $resData = json_decode($response, true);

        if (isset($resData['status_code']) && $resData['status_code'] == '201') {
            $qrUrl = '';
            if (isset($resData['actions']) && is_array($resData['actions'])) {
                foreach ($resData['actions'] as $action) {
                    if ($action['name'] === 'generate-qr-code') {
                        $qrUrl = $action['url'];
                        break;
                    }
                }
            }
            
            echo json_encode([
                "order_id" => $orderId,
                "qr_url" => $qrUrl,
                "qr_string" => $resData['qr_string'] ?? ''
            ]);
        } else {
            http_response_code(500);
            echo json_encode(["error" => "Failed to generate QRIS", "midtrans_response" => $resData]);
        }
        exit;

    } elseif ($method === 'GET' && preg_match('/^\/api\/qris\/status\/(.+)$/', $route, $matches)) {
        $orderId = $matches[1];
        $serverKey = 'Mid-server-pScqIkUSLacGu739R4FnTDFO';
        
        $ch = curl_init("https://api.sandbox.midtrans.com/v2/$orderId/status");
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Accept: application/json',
            'Authorization: Basic ' . base64_encode($serverKey . ':')
        ]);

        $response = curl_exec($ch);
        curl_close($ch);

        $resData = json_decode($response, true);
        
        if (isset($resData['transaction_status'])) {
            echo json_encode(["status" => $resData['transaction_status']]);
        } else {
            http_response_code(404);
            echo json_encode(["error" => "Transaction not found"]);
        }
        exit;

    } elseif ($method === 'POST' && $route === '/api/checkout') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403);
            echo json_encode(["error" => "Forbidden: Only kasir can checkout"]);
            exit;
        }

        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['total_amount'])) {
            http_response_code(400);
            echo json_encode(["error" => "total_amount is required"]);
            exit;
        }
        
        $paymentMethod = $input['payment_method'] ?? 'cash';
        if (!in_array($paymentMethod, ['cash', 'qris'])) {
            $paymentMethod = 'cash';
        }

        $storeId = $user['store_id'] ?? 1;

        try {
            $pdo->beginTransaction();
            $stmt = $pdo->prepare("INSERT INTO transactions (store_id, kasir_id, total_amount, payment_method) VALUES (?, ?, ?, ?)");
            $stmt->execute([$storeId, $user['id'], $input['total_amount'], $paymentMethod]);
            $transactionId = $pdo->lastInsertId();

            if (!empty($input['items']) && is_array($input['items'])) {
                $stmtItem = $pdo->prepare("INSERT INTO transaction_items (transaction_id, menu_id, quantity, price) VALUES (?, ?, ?, ?)");
                foreach ($input['items'] as $item) {
                    $stmtItem->execute([                        $transactionId, 
                        $item['menu_id'], 
                        $item['quantity'], 
                        $item['price']
                    ]);
                }
            }
            $pdo->commit();
        } catch (Exception $e) {
            $pdo->rollBack();
            http_response_code(500);
            echo json_encode(["error" => "Failed to checkout: " . $e->getMessage()]);
            exit;
        }

        $stmt = $pdo->prepare("SELECT * FROM transactions WHERE id = ?");
        $stmt->execute([$transactionId]);
        $transaction = $stmt->fetch();

        $transaction['id'] = (int)$transaction['id'];
        $transaction['store_id'] = (int)$transaction['store_id'];
        $transaction['kasir_id'] = (int)$transaction['kasir_id'];
        $transaction['total_amount'] = (double)$transaction['total_amount'];

        http_response_code(201);
        echo json_encode([
            "message" => "Checkout successful",
            "transaction" => $transaction
        ]);
        exit;

    } elseif ($method === 'POST' && $route === '/api/sync-transactions') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403);
            echo json_encode(["error" => "Forbidden: Only kasir can sync transactions"]);
            exit;
        }

        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['transactions']) || !is_array($input['transactions'])) {
            http_response_code(400);
            echo json_encode(["error" => "Transactions array is required"]);
            exit;
        }

        $pdo->beginTransaction();
        try {
            $inserted = 0;
            $stmtTx = $pdo->prepare("INSERT INTO transactions (store_id, kasir_id, total_amount, payment_method, created_at) VALUES (?, ?, ?, ?, ?)");
            $stmtItem = $pdo->prepare("INSERT INTO transaction_items (transaction_id, menu_id, quantity, price) VALUES (?, ?, ?, ?)");

            foreach ($input['transactions'] as $tx) {
                $createdAt = !empty($tx['created_at']) ? $tx['created_at'] : date('Y-m-d H:i:s');
                $paymentMethod = !empty($tx['payment_method']) ? $tx['payment_method'] : 'cash';
                if (!in_array($paymentMethod, ['cash', 'qris'])) $paymentMethod = 'cash';

                $stmtTx->execute([
                    $user['store_id'],
                    $user['id'],
                    $tx['total_amount'],
                    $paymentMethod,
                    $createdAt
                ]);
                $txId = $pdo->lastInsertId();

                if (!empty($tx['items']) && is_array($tx['items'])) {
                    foreach ($tx['items'] as $item) {
                        $stmtItem->execute([
                            $txId,
                            $item['menu_id'],
                            $item['quantity'],
                            $item['price']
                        ]);
                    }
                }
                $inserted++;
            }

            $pdo->commit();
            echo json_encode(["message" => "Sync successful", "inserted" => $inserted]);
        } catch (Exception $e) {
            $pdo->rollBack();
            http_response_code(500);
            echo json_encode(["error" => "Database error during sync: " . $e->getMessage()]);
        }
        exit;

    } elseif ($method === 'GET' && $route === '/api/owner/reports') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner' && $user['role'] !== 'super_admin') {
            http_response_code(403);
            echo json_encode(["error" => "Forbidden: Owner only"]);
            exit;
        }

        if ($user['role'] === 'super_admin') {
            $stmt = $pdo->query("SELECT * FROM transactions");
            $transactions = $stmt->fetchAll();
        } else {
            $stmt = $pdo->prepare("
                SELECT t.* FROM transactions t
                JOIN stores s ON t.store_id = s.id
                WHERE s.owner_id = ?
            ");
            $stmt->execute([$user['id']]);
            $transactions = $stmt->fetchAll();
        }

        foreach ($transactions as &$tx) {
            $tx['id'] = (int)$tx['id'];
            $tx['store_id'] = (int)$tx['store_id'];
            $tx['kasir_id'] = (int)$tx['kasir_id'];
            $tx['total_amount'] = (double)$tx['total_amount'];

            $stmtKasir = $pdo->prepare("SELECT id, name, email FROM users WHERE id = ?");
            $stmtKasir->execute([$tx['kasir_id']]);
            $kasir = $stmtKasir->fetch();
            if ($kasir) {
                $kasir['id'] = (int)$kasir['id'];
                $tx['kasir'] = $kasir;
            } else {
                $tx['kasir'] = null;
            }
        }

        http_response_code(200);
        echo json_encode($transactions);
        exit;

    } elseif ($method === 'GET' && $route === '/api/owner/dashboard-stats') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner') {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden: Owner only']);
            exit;
        }

        $stmt = $pdo->prepare("
            SELECT SUM(t.total_amount) as total_sales, COUNT(t.id) as total_orders
            FROM transactions t
            JOIN stores s ON t.store_id = s.id
            WHERE s.owner_id = ? AND DATE(t.created_at) = CURDATE()
        ");
        $stmt->execute([$user['id']]);
        $today = $stmt->fetch();

        $stmtMenu = $pdo->prepare("
            SELECT COUNT(m.id) as total_menus
            FROM menus m
            JOIN stores s ON m.store_id = s.id
            WHERE s.owner_id = ?
        ");
        $stmtMenu->execute([$user['id']]);
        $menu = $stmtMenu->fetch();

        echo json_encode([
            'total_sales_today' => (double)($today['total_sales'] ?? 0),
            'total_orders_today' => (int)($today['total_orders'] ?? 0),
            'total_menus' => (int)($menu['total_menus'] ?? 0)
        ]);
        exit;

    } elseif ($method === 'GET' && $route === '/api/reports/kasir') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden: Kasir only']);
            exit;
        }

        // Kasir can only see TODAY'S report for their transactions
        $stmt = $pdo->prepare("
            SELECT 
                COUNT(*) as total_transactions,
                SUM(total_amount) as total_revenue,
                SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END) as total_cash,
                SUM(CASE WHEN payment_method = 'qris' THEN total_amount ELSE 0 END) as total_qris
            FROM transactions 
            WHERE kasir_id = ? AND DATE(created_at) = CURDATE()
        ");
        $stmt->execute([$user['id']]);
        $report = $stmt->fetch();

        // Fetch recent transactions
        $stmtTx = $pdo->prepare("
            SELECT id, created_at, payment_method, total_amount
            FROM transactions
            WHERE kasir_id = ? AND DATE(created_at) = CURDATE()
            ORDER BY created_at DESC
        ");
        $stmtTx->execute([$user['id']]);
        $transactions = $stmtTx->fetchAll();

        foreach ($transactions as &$tx) {
            $tx['id'] = (int)$tx['id'];
            $tx['total_amount'] = (double)$tx['total_amount'];
            
            $stmtItems = $pdo->prepare("
                SELECT ti.quantity, ti.price, m.name 
                FROM transaction_items ti
                JOIN menus m ON ti.menu_id = m.id
                WHERE ti.transaction_id = ?
            ");
            $stmtItems->execute([$tx['id']]);
            $items = $stmtItems->fetchAll();
            foreach ($items as &$it) {
                $it['quantity'] = (int)$it['quantity'];
                $it['price'] = (double)$it['price'];
            }
            $tx['items'] = $items;
        }

        echo json_encode([
            'total_transactions' => (int)$report['total_transactions'],
            'total_revenue' => (double)$report['total_revenue'],
            'total_cash' => (double)$report['total_cash'],
            'total_qris' => (double)$report['total_qris'],
            'recent_transactions' => $transactions
        ]);
        exit;

    } elseif ($method === 'GET' && $route === '/api/reports/owner') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner') {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden: Owner only']);
            exit;
        }

        $period = $_GET['period'] ?? 'daily';
        
        if ($period === 'monthly') {
            $dateFormat = '%Y-%m';
        } elseif ($period === 'yearly') {
            $dateFormat = '%Y';
        } else {
            $dateFormat = '%Y-%m-%d';
        }

        $stmt = $pdo->prepare("
            SELECT 
                DATE_FORMAT(t.created_at, ?) as period_date,
                COUNT(t.id) as total_transactions,
                SUM(t.total_amount) as total_revenue,
                SUM(CASE WHEN t.payment_method = 'cash' THEN t.total_amount ELSE 0 END) as total_cash,
                SUM(CASE WHEN t.payment_method = 'qris' THEN t.total_amount ELSE 0 END) as total_qris
            FROM transactions t
            JOIN stores s ON t.store_id = s.id
            WHERE s.owner_id = ?
            GROUP BY period_date
            ORDER BY period_date DESC
        ");
        $stmt->execute([$dateFormat, $user['id']]);
        $reports = $stmt->fetchAll();

        foreach ($reports as &$r) {
            $r['total_transactions'] = (int)$r['total_transactions'];
            $r['total_revenue'] = (double)$r['total_revenue'];
            $r['total_cash'] = (double)$r['total_cash'];
            $r['total_qris'] = (double)$r['total_qris'];
        }

        echo json_encode($reports);
        exit;

    } elseif ($method === 'GET' && $route === '/api/owner/kasir') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner') { http_response_code(403); echo json_encode(['error'=>'Forbidden']); exit; }
        
        $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
        $stmtStore->execute([$user['id']]);
        $store = $stmtStore->fetch();
        if (!$store) { echo json_encode([]); exit; }

        $stmt = $pdo->prepare("SELECT id, name, email, is_active, created_at FROM users WHERE role = 'kasir' AND store_id = ? ORDER BY created_at DESC");
        $stmt->execute([$store['id']]);
        echo json_encode($stmt->fetchAll()); exit;

    } elseif ($method === 'POST' && $route === '/api/owner/kasir') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner') { http_response_code(403); echo json_encode(['error'=>'Forbidden']); exit; }

        $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
        $stmtStore->execute([$user['id']]);
        $store = $stmtStore->fetch();
        if (!$store) { http_response_code(400); echo json_encode(['error'=>'Please setup your store first']); exit; }

        $stmtCount = $pdo->prepare("SELECT COUNT(id) as count FROM users WHERE role = 'kasir' AND store_id = ?");
        $stmtCount->execute([$store['id']]);
        $count = $stmtCount->fetch()['count'];

        if ($count >= 5) {
            http_response_code(400); echo json_encode(['error'=>'Batas maksimal 5 akun Kasir telah tercapai']); exit;
        }

        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['name']) || empty($input['email']) || empty($input['password'])) {
            http_response_code(400); echo json_encode(["error" => "Name, email, and password required"]); exit;
        }

        $stmtUniq = $pdo->prepare("SELECT id FROM users WHERE email = ? LIMIT 1");
        $stmtUniq->execute([$input['email']]);
        if ($stmtUniq->fetch()) {
            http_response_code(400); echo json_encode(["error" => "Email already taken"]); exit;
        }

        $hash = password_hash($input['password'], PASSWORD_BCRYPT);
        $pdo->prepare("INSERT INTO users (name, email, password, role, store_id) VALUES (?, ?, ?, 'kasir', ?)")
            ->execute([$input['name'], $input['email'], $hash, $store['id']]);
        
        echo json_encode(['message' => 'Kasir created successfully']); exit;

    } elseif ($method === 'POST' && preg_match('/^\/api\/owner\/kasir\/(\d+)\/toggle$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner') { http_response_code(403); echo json_encode(['error'=>'Forbidden']); exit; }
        $kasirId = $matches[1];

        $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
        $stmtStore->execute([$user['id']]);
        $store = $stmtStore->fetch();

        if ($store) {
            $pdo->prepare("UPDATE users SET is_active = NOT is_active WHERE id = ? AND role = 'kasir' AND store_id = ?")
                ->execute([$kasirId, $store['id']]);
        }
        echo json_encode(['message' => 'Status kasir diubah']); exit;

    } elseif ($method === 'DELETE' && preg_match('/^\/api\/owner\/kasir\/(\d+)$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner') { http_response_code(403); echo json_encode(['error'=>'Forbidden']); exit; }
        $kasirId = $matches[1];

        $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
        $stmtStore->execute([$user['id']]);
        $store = $stmtStore->fetch();

        if ($store) {
            $pdo->prepare("DELETE FROM users WHERE id = ? AND role = 'kasir' AND store_id = ?")
                ->execute([$kasirId, $store['id']]);
        }
        echo json_encode(['message' => 'Kasir dihapus']); exit;

    } elseif ($method === 'POST' && $route === '/api/admin/generate-code') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'super_admin') { http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit; }
        
        $code = substr(str_shuffle("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"), 0, 8);
        $pdo->prepare("INSERT INTO verification_codes (code) VALUES (?)")->execute([$code]);
        echo json_encode(['code' => $code]); exit;

    } elseif ($method === 'GET' && $route === '/api/admin/owners') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'super_admin') { http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit; }
        
        $stmt = $pdo->query("SELECT id, name, email, is_active, created_at FROM users WHERE role = 'owner' ORDER BY created_at DESC");
        echo json_encode($stmt->fetchAll()); exit;

    } elseif ($method === 'POST' && preg_match('/^\/api\/admin\/owners\/(\d+)\/toggle$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'super_admin') { http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit; }
        
        $ownerId = $matches[1];
        $pdo->prepare("UPDATE users SET is_active = NOT is_active WHERE id = ? AND role = 'owner'")->execute([$ownerId]);
        echo json_encode(['message' => 'Owner status toggled']); exit;

    } else {
        http_response_code(404);
        echo json_encode(["error" => "Endpoint not found: $method $route"]);
        exit;
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "error" => "Internal Server Error: " . $e->getMessage()
    ]);
    exit;
}
