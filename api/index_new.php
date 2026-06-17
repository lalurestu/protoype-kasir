<?php
// api/index.php - UPDATED with Stock, Shift, CRM, Discount, Tax support

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

// Helper: Format currency
function formatRupiah($amount) {
    return (double)$amount;
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

    // =========================================================================
    // AUTH ROUTES
    // =========================================================================

    if ($method === 'POST' && $route === '/api/auth/register-owner') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['name']) || empty($input['email']) || empty($input['password']) || empty($input['verification_code'])) {
            http_response_code(400);
            echo json_encode(["error" => "Name, email, password, and verification_code are required"]);
            exit;
        }

        $stmtCode = $pdo->prepare("SELECT id FROM verification_codes WHERE code = ? AND is_used = FALSE LIMIT 1");
        $stmtCode->execute([$input['verification_code']]);
        $verif = $stmtCode->fetch();
        if (!$verif) {
            http_response_code(400);
            echo json_encode(["error" => "Invalid or already used verification code"]);
            exit;
        }

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

        $stmt = $pdo->prepare("SELECT id, name, email, role, store_id FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        $user = $stmt->fetch();
        $user['id'] = (int)$user['id'];

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

        $token = bin2hex(random_bytes(32));
        $stmtToken = $pdo->prepare("INSERT INTO user_tokens (user_id, token, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 8 HOUR))");
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

    // =========================================================================
    // MENU ROUTES
    // =========================================================================

    } elseif ($method === 'GET' && $route === '/api/store/menus') {
        $user = getAuthUser($pdo);

        if ($user['role'] === 'super_admin') {
            $stmt = $pdo->query("SELECT m.*, s.quantity as stock, s.min_stock FROM menus m LEFT JOIN stock s ON s.menu_id = m.id");
            $menus = $stmt->fetchAll();
        } elseif ($user['role'] === 'owner') {
            $stmt = $pdo->prepare("
                SELECT m.*, s.quantity as stock, s.min_stock FROM menus m
                LEFT JOIN stock s ON s.menu_id = m.id
                JOIN stores st ON m.store_id = st.id
                WHERE st.owner_id = ?
            ");
            $stmt->execute([$user['id']]);
            $menus = $stmt->fetchAll();
        } else {
            $storeId = $user['store_id'] ?? 1;
            $stmt = $pdo->prepare("SELECT m.*, s.quantity as stock, s.min_stock FROM menus m LEFT JOIN stock s ON s.menu_id = m.id WHERE m.store_id = ?");
            $stmt->execute([$storeId]);
            $menus = $stmt->fetchAll();
        }

        foreach ($menus as &$menu) {
            $menu['id'] = (int)$menu['id'];
            $menu['store_id'] = (int)$menu['store_id'];
            $menu['price'] = (double)$menu['price'];
            $menu['is_available'] = (bool)($menu['is_available'] ?? true);
            $menu['stock'] = $menu['stock'] !== null ? (int)$menu['stock'] : null;
            $menu['min_stock'] = $menu['min_stock'] !== null ? (int)$menu['min_stock'] : 5;

            // Fetch variants
            $stmtVar = $pdo->prepare("SELECT id, name, price FROM menu_variants WHERE menu_id = ?");
            $stmtVar->execute([$menu['id']]);
            $variants = $stmtVar->fetchAll();
            foreach ($variants as &$v) {
                $v['id'] = (int)$v['id'];
                $v['price'] = (double)$v['price'];
            }
            $menu['variants'] = $variants;

            // Fetch addons
            $stmtAdd = $pdo->prepare("SELECT id, name, price FROM menu_addons WHERE menu_id = ?");
            $stmtAdd->execute([$menu['id']]);
            $addons = $stmtAdd->fetchAll();
            foreach ($addons as &$a) {
                $a['id'] = (int)$a['id'];
                $a['price'] = (double)$a['price'];
            }
            $menu['addons'] = $addons;
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
        if (empty($input['name']) || !isset($input['price']) || empty($input['category'])) {
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

        $isAvailable = isset($input['is_available']) ? (bool)$input['is_available'] : true;
        $description = $input['description'] ?? null;
        $initialStock = isset($input['initial_stock']) ? (int)$input['initial_stock'] : 50;
        $minStock = isset($input['min_stock']) ? (int)$input['min_stock'] : 5;

        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare("INSERT INTO menus (store_id, name, price, category, is_available, description) VALUES (?, ?, ?, ?, ?, ?)");
            $stmt->execute([$storeId, $input['name'], $input['price'], $input['category'], $isAvailable, $description]);
            $menuId = $pdo->lastInsertId();

            // Auto-create stock record
            $pdo->prepare("INSERT INTO stock (menu_id, quantity, min_stock) VALUES (?, ?, ?)")
                ->execute([$menuId, $initialStock, $minStock]);

            if (!empty($input['variants']) && is_array($input['variants'])) {
                $stmtVar = $pdo->prepare("INSERT INTO menu_variants (menu_id, name, price) VALUES (?, ?, ?)");
                foreach ($input['variants'] as $v) {
                    $stmtVar->execute([$menuId, $v['name'], $v['price']]);
                }
            }
            if (!empty($input['addons']) && is_array($input['addons'])) {
                $stmtAdd = $pdo->prepare("INSERT INTO menu_addons (menu_id, name, price) VALUES (?, ?, ?)");
                foreach ($input['addons'] as $a) {
                    $stmtAdd->execute([$menuId, $a['name'], $a['price']]);
                }
            }

            $pdo->commit();
        } catch (Exception $e) {
            $pdo->rollBack();
            http_response_code(500);
            echo json_encode(["error" => "Failed to create menu: " . $e->getMessage()]);
            exit;
        }

        $stmt = $pdo->prepare("SELECT m.*, s.quantity as stock, s.min_stock FROM menus m LEFT JOIN stock s ON s.menu_id = m.id WHERE m.id = ?");
        $stmt->execute([$menuId]);
        $newMenu = $stmt->fetch();
        $newMenu['id'] = (int)$newMenu['id'];
        $newMenu['store_id'] = (int)$newMenu['store_id'];
        $newMenu['price'] = (double)$newMenu['price'];
        $newMenu['is_available'] = (bool)$newMenu['is_available'];

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
        if (empty($input['name']) || !isset($input['price']) || empty($input['category'])) {
            http_response_code(400);
            echo json_encode(["error" => "Name, price, and category are required"]);
            exit;
        }

        $isAvailable = isset($input['is_available']) ? (bool)$input['is_available'] : true;
        $description = $input['description'] ?? null;

        $stmt = $pdo->prepare("UPDATE menus SET name = ?, price = ?, category = ?, is_available = ?, description = ? WHERE id = ?");
        $stmt->execute([$input['name'], $input['price'], $input['category'], $isAvailable, $description, $menuId]);

        // Update min_stock if provided
        if (isset($input['min_stock'])) {
            $pdo->prepare("UPDATE stock SET min_stock = ? WHERE menu_id = ?")->execute([$input['min_stock'], $menuId]);
        }

        // Update variants
        if (isset($input['variants']) && is_array($input['variants'])) {
            $pdo->prepare("DELETE FROM menu_variants WHERE menu_id = ?")->execute([$menuId]);
            $stmtVar = $pdo->prepare("INSERT INTO menu_variants (menu_id, name, price) VALUES (?, ?, ?)");
            foreach ($input['variants'] as $v) {
                $stmtVar->execute([$menuId, $v['name'], $v['price']]);
            }
        }

        // Update addons
        if (isset($input['addons']) && is_array($input['addons'])) {
            $pdo->prepare("DELETE FROM menu_addons WHERE menu_id = ?")->execute([$menuId]);
            $stmtAdd = $pdo->prepare("INSERT INTO menu_addons (menu_id, name, price) VALUES (?, ?, ?)");
            foreach ($input['addons'] as $a) {
                $stmtAdd->execute([$menuId, $a['name'], $a['price']]);
            }
        }

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

    // =========================================================================
    // STOCK ROUTES
    // =========================================================================

    } elseif ($method === 'GET' && $route === '/api/owner/stock') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner' && $user['role'] !== 'super_admin') {
            http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit;
        }

        if ($user['role'] === 'super_admin') {
            $stmt = $pdo->query("
                SELECT s.*, m.name as menu_name, m.category as menu_category, m.price as menu_price
                FROM stock s JOIN menus m ON s.menu_id = m.id
                ORDER BY s.quantity ASC
            ");
        } else {
            $stmt = $pdo->prepare("
                SELECT s.*, m.name as menu_name, m.category as menu_category, m.price as menu_price
                FROM stock s
                JOIN menus m ON s.menu_id = m.id
                JOIN stores st ON m.store_id = st.id
                WHERE st.owner_id = ?
                ORDER BY s.quantity ASC
            ");
            $stmt->execute([$user['id']]);
        }

        $stocks = $stmt->fetchAll();
        foreach ($stocks as &$stock) {
            $stock['id'] = (int)$stock['id'];
            $stock['menu_id'] = (int)$stock['menu_id'];
            $stock['quantity'] = (int)$stock['quantity'];
            $stock['min_stock'] = (int)$stock['min_stock'];
            $stock['menu_price'] = (double)$stock['menu_price'];
        }

        echo json_encode($stocks);
        exit;

    } elseif ($method === 'PUT' && preg_match('/^\/api\/owner\/stock\/(\d+)$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner' && $user['role'] !== 'super_admin') {
            http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit;
        }

        $menuId = $matches[1];
        $input = json_decode(file_get_contents('php://input'), true);

        if (!isset($input['quantity'])) {
            http_response_code(400); echo json_encode(['error' => 'quantity is required']); exit;
        }

        $pdo->prepare("UPDATE stock SET quantity = ?, min_stock = COALESCE(?, min_stock) WHERE menu_id = ?")
            ->execute([$input['quantity'], $input['min_stock'] ?? null, $menuId]);

        echo json_encode(['message' => 'Stok berhasil diperbarui']);
        exit;

    } elseif ($method === 'POST' && preg_match('/^\/api\/owner\/stock\/(\d+)\/(add|subtract)$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner' && $user['role'] !== 'super_admin') {
            http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit;
        }

        $menuId = $matches[1];
        $action = $matches[2]; // 'add' atau 'subtract'
        $input = json_decode(file_get_contents('php://input'), true);
        $amount = (int)($input['amount'] ?? 0);

        if ($amount <= 0) {
            http_response_code(400); echo json_encode(['error' => 'amount must be positive']); exit;
        }

        if ($action === 'add') {
            $pdo->prepare("UPDATE stock SET quantity = quantity + ? WHERE menu_id = ?")->execute([$amount, $menuId]);
        } else {
            $pdo->prepare("UPDATE stock SET quantity = GREATEST(0, quantity - ?) WHERE menu_id = ?")->execute([$amount, $menuId]);
        }

        $stmt = $pdo->prepare("SELECT quantity FROM stock WHERE menu_id = ?");
        $stmt->execute([$menuId]);
        $newStock = $stmt->fetch();

        echo json_encode(['message' => 'Stok diperbarui', 'quantity' => (int)$newStock['quantity']]);
        exit;

    } elseif ($method === 'GET' && $route === '/api/owner/stock/alerts') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner' && $user['role'] !== 'super_admin') {
            http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit;
        }

        $stmt = $pdo->prepare("
            SELECT s.*, m.name as menu_name, m.category as menu_category
            FROM stock s
            JOIN menus m ON s.menu_id = m.id
            JOIN stores st ON m.store_id = st.id
            WHERE st.owner_id = ? AND s.quantity <= s.min_stock
            ORDER BY s.quantity ASC
        ");
        $stmt->execute([$user['id']]);
        $alerts = $stmt->fetchAll();

        foreach ($alerts as &$a) {
            $a['id'] = (int)$a['id'];
            $a['menu_id'] = (int)$a['menu_id'];
            $a['quantity'] = (int)$a['quantity'];
            $a['min_stock'] = (int)$a['min_stock'];
        }

        echo json_encode($alerts);
        exit;

    // =========================================================================
    // SHIFT ROUTES
    // =========================================================================

    } elseif ($method === 'GET' && $route === '/api/shifts/current') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit;
        }

        $stmt = $pdo->prepare("
            SELECT sh.*, u.name as kasir_name
            FROM shifts sh
            JOIN users u ON sh.kasir_id = u.id
            WHERE sh.kasir_id = ? AND sh.status = 'open'
            ORDER BY sh.opened_at DESC LIMIT 1
        ");
        $stmt->execute([$user['id']]);
        $shift = $stmt->fetch();

        if (!$shift) {
            http_response_code(404); echo json_encode(['error' => 'No active shift']); exit;
        }

        $shift['id'] = (int)$shift['id'];
        $shift['kasir_id'] = (int)$shift['kasir_id'];
        $shift['store_id'] = (int)$shift['store_id'];
        $shift['opening_cash'] = (double)$shift['opening_cash'];
        $shift['total_sales'] = (double)$shift['total_sales'];
        $shift['total_transactions'] = (int)$shift['total_transactions'];

        echo json_encode($shift);
        exit;

    } elseif ($method === 'POST' && $route === '/api/shifts/open') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit;
        }

        // Check if already has open shift
        $stmtCheck = $pdo->prepare("SELECT id FROM shifts WHERE kasir_id = ? AND status = 'open' LIMIT 1");
        $stmtCheck->execute([$user['id']]);
        if ($stmtCheck->fetch()) {
            http_response_code(400); echo json_encode(['error' => 'Anda sudah memiliki shift yang sedang aktif']); exit;
        }

        $input = json_decode(file_get_contents('php://input'), true);
        $openingCash = (double)($input['opening_cash'] ?? 0);
        $storeId = $user['store_id'] ?? 1;

        $pdo->prepare("INSERT INTO shifts (kasir_id, store_id, opening_cash) VALUES (?, ?, ?)")
            ->execute([$user['id'], $storeId, $openingCash]);
        $shiftId = $pdo->lastInsertId();

        $stmt = $pdo->prepare("SELECT sh.*, u.name as kasir_name FROM shifts sh JOIN users u ON sh.kasir_id = u.id WHERE sh.id = ?");
        $stmt->execute([$shiftId]);
        $shift = $stmt->fetch();

        $shift['id'] = (int)$shift['id'];
        $shift['kasir_id'] = (int)$shift['kasir_id'];
        $shift['store_id'] = (int)$shift['store_id'];
        $shift['opening_cash'] = (double)$shift['opening_cash'];
        $shift['total_sales'] = (double)$shift['total_sales'];
        $shift['total_transactions'] = (int)$shift['total_transactions'];

        http_response_code(201);
        echo json_encode(['message' => 'Shift berhasil dibuka', 'shift' => $shift]);
        exit;

    } elseif ($method === 'POST' && $route === '/api/shifts/close') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit;
        }

        $input = json_decode(file_get_contents('php://input'), true);
        $shiftId = (int)($input['shift_id'] ?? 0);
        $closingCash = (double)($input['closing_cash'] ?? 0);
        $note = $input['note'] ?? null;

        if (!$shiftId) {
            http_response_code(400); echo json_encode(['error' => 'shift_id is required']); exit;
        }

        // Calculate total sales in this shift
        $stmtSales = $pdo->prepare("SELECT SUM(total_amount) as total, COUNT(*) as count FROM transactions WHERE shift_id = ? AND status = 'completed'");
        $stmtSales->execute([$shiftId]);
        $salesData = $stmtSales->fetch();
        $totalSales = (double)($salesData['total'] ?? 0);
        $totalTx = (int)($salesData['count'] ?? 0);

        $pdo->prepare("
            UPDATE shifts SET status = 'closed', closed_at = NOW(), closing_cash = ?, note = ?, total_sales = ?, total_transactions = ?
            WHERE id = ? AND kasir_id = ? AND status = 'open'
        ")->execute([$closingCash, $note, $totalSales, $totalTx, $shiftId, $user['id']]);

        $stmt = $pdo->prepare("SELECT sh.*, u.name as kasir_name FROM shifts sh JOIN users u ON sh.kasir_id = u.id WHERE sh.id = ?");
        $stmt->execute([$shiftId]);
        $shift = $stmt->fetch();

        if (!$shift) {
            http_response_code(404); echo json_encode(['error' => 'Shift tidak ditemukan atau sudah ditutup']); exit;
        }

        $shift['id'] = (int)$shift['id'];
        $shift['opening_cash'] = (double)$shift['opening_cash'];
        $shift['closing_cash'] = (double)$shift['closing_cash'];
        $shift['total_sales'] = (double)$shift['total_sales'];
        $shift['total_transactions'] = (int)$shift['total_transactions'];

        echo json_encode(['message' => 'Shift berhasil ditutup', 'shift' => $shift]);
        exit;

    } elseif ($method === 'GET' && $route === '/api/owner/shifts') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner' && $user['role'] !== 'super_admin') {
            http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit;
        }

        $stmt = $pdo->prepare("
            SELECT sh.*, u.name as kasir_name
            FROM shifts sh
            JOIN users u ON sh.kasir_id = u.id
            JOIN stores st ON sh.store_id = st.id
            WHERE st.owner_id = ?
            ORDER BY sh.opened_at DESC
            LIMIT 100
        ");
        $stmt->execute([$user['id']]);
        $shifts = $stmt->fetchAll();

        foreach ($shifts as &$shift) {
            $shift['id'] = (int)$shift['id'];
            $shift['kasir_id'] = (int)$shift['kasir_id'];
            $shift['opening_cash'] = (double)$shift['opening_cash'];
            $shift['closing_cash'] = $shift['closing_cash'] !== null ? (double)$shift['closing_cash'] : null;
            $shift['total_sales'] = (double)$shift['total_sales'];
            $shift['total_transactions'] = (int)$shift['total_transactions'];
        }

        echo json_encode($shifts);
        exit;

    // =========================================================================
    // CUSTOMER / CRM ROUTES
    // =========================================================================

    } elseif ($method === 'GET' && $route === '/api/customers') {
        $user = getAuthUser($pdo);
        $storeId = null;
        if ($user['role'] === 'owner') {
            $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
            $stmtStore->execute([$user['id']]);
            $store = $stmtStore->fetch();
            $storeId = $store ? (int)$store['id'] : null;
        } elseif ($user['role'] === 'kasir') {
            $storeId = $user['store_id'];
        }

        if (!$storeId) { echo json_encode([]); exit; }

        $stmt = $pdo->prepare("SELECT * FROM customers WHERE store_id = ? ORDER BY total_spend DESC");
        $stmt->execute([$storeId]);
        $customers = $stmt->fetchAll();

        foreach ($customers as &$c) {
            $c['id'] = (int)$c['id'];
            $c['store_id'] = (int)$c['store_id'];
            $c['points'] = (int)$c['points'];
            $c['total_spend'] = (double)$c['total_spend'];
            $c['visit_count'] = (int)$c['visit_count'];
        }

        echo json_encode($customers);
        exit;

    } elseif ($method === 'POST' && $route === '/api/customers') {
        $user = getAuthUser($pdo);
        $input = json_decode(file_get_contents('php://input'), true);

        if (empty($input['name']) || empty($input['phone'])) {
            http_response_code(400); echo json_encode(['error' => 'name and phone are required']); exit;
        }

        $storeId = null;
        if ($user['role'] === 'owner') {
            $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
            $stmtStore->execute([$user['id']]);
            $store = $stmtStore->fetch();
            $storeId = $store ? (int)$store['id'] : null;
        } elseif ($user['role'] === 'kasir') {
            $storeId = $user['store_id'];
        }

        if (!$storeId) { http_response_code(400); echo json_encode(['error' => 'Store not found']); exit; }

        // Check duplicate phone in same store
        $stmtDup = $pdo->prepare("SELECT id FROM customers WHERE phone = ? AND store_id = ? LIMIT 1");
        $stmtDup->execute([$input['phone'], $storeId]);
        if ($stmtDup->fetch()) {
            http_response_code(400); echo json_encode(['error' => 'Nomor HP sudah terdaftar']); exit;
        }

        $pdo->prepare("INSERT INTO customers (store_id, name, phone, email) VALUES (?, ?, ?, ?)")
            ->execute([$storeId, $input['name'], $input['phone'], $input['email'] ?? null]);
        $custId = $pdo->lastInsertId();

        $stmt = $pdo->prepare("SELECT * FROM customers WHERE id = ?");
        $stmt->execute([$custId]);
        $customer = $stmt->fetch();
        $customer['id'] = (int)$customer['id'];

        http_response_code(201);
        echo json_encode($customer);
        exit;

    } elseif ($method === 'GET' && $route === '/api/customers/search') {
        $user = getAuthUser($pdo);
        $phone = $_GET['phone'] ?? '';

        if (strlen($phone) < 4) {
            http_response_code(400); echo json_encode(['error' => 'phone must be at least 4 characters']); exit;
        }

        $storeId = null;
        if ($user['role'] === 'kasir') {
            $storeId = $user['store_id'];
        } elseif ($user['role'] === 'owner') {
            $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
            $stmtStore->execute([$user['id']]);
            $store = $stmtStore->fetch();
            $storeId = $store ? (int)$store['id'] : null;
        }

        if (!$storeId) { http_response_code(404); echo json_encode(['error' => 'Not found']); exit; }

        $stmt = $pdo->prepare("SELECT * FROM customers WHERE store_id = ? AND phone LIKE ? LIMIT 5");
        $stmt->execute([$storeId, '%' . $phone . '%']);
        $results = $stmt->fetchAll();

        foreach ($results as &$c) {
            $c['id'] = (int)$c['id'];
            $c['points'] = (int)$c['points'];
            $c['total_spend'] = (double)$c['total_spend'];
            $c['visit_count'] = (int)$c['visit_count'];
        }

        if (empty($results)) {
            http_response_code(404); echo json_encode(['error' => 'Pelanggan tidak ditemukan']); exit;
        }

        echo json_encode(count($results) === 1 ? $results[0] : $results);
        exit;

    } elseif ($method === 'PUT' && preg_match('/^\/api\/customers\/(\d+)$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        $custId = $matches[1];
        $input = json_decode(file_get_contents('php://input'), true);

        $pdo->prepare("UPDATE customers SET name = COALESCE(?, name), phone = COALESCE(?, phone), email = COALESCE(?, email) WHERE id = ?")
            ->execute([$input['name'] ?? null, $input['phone'] ?? null, $input['email'] ?? null, $custId]);

        echo json_encode(['message' => 'Pelanggan diperbarui']);
        exit;

    // =========================================================================
    // QRIS ROUTES
    // =========================================================================

    } elseif ($method === 'POST' && $route === '/api/qris/generate') {
        $user = getAuthUser($pdo);
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['total_amount'])) {
            http_response_code(400);
            echo json_encode(["error" => "total_amount is required"]);
            exit;
        }

        $serverKey = 'Mid-server-pScqIkUSLacGu739R4FnTDFO';
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

    // =========================================================================
    // CHECKOUT ROUTE (UPDATED with discount, tax, customer, shift)
    // =========================================================================

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
        if (!in_array($paymentMethod, ['cash', 'qris'])) $paymentMethod = 'cash';

        $storeId = $user['store_id'] ?? 1;
        $discountAmount = (double)($input['discount_amount'] ?? 0);
        $discountType = in_array($input['discount_type'] ?? '', ['percent', 'nominal']) ? $input['discount_type'] : 'nominal';
        $taxAmount = (double)($input['tax_amount'] ?? 0);
        $taxPercent = (double)($input['tax_percent'] ?? 0);
        $subtotalAmount = (double)($input['subtotal_amount'] ?? $input['total_amount']);
        $customerId = isset($input['customer_id']) ? (int)$input['customer_id'] : null;
        $customerNote = $input['customer_note'] ?? null;
        $status = $input['status'] ?? 'completed';
        $tableNumber = $input['table_number'] ?? null;

        // Get active shift
        $stmtShift = $pdo->prepare("SELECT id FROM shifts WHERE kasir_id = ? AND status = 'open' ORDER BY opened_at DESC LIMIT 1");
        $stmtShift->execute([$user['id']]);
        $activeShift = $stmtShift->fetch();
        $shiftId = $activeShift ? (int)$activeShift['id'] : null;

        try {
            $pdo->beginTransaction();

            $stmt = $pdo->prepare("
                INSERT INTO transactions
                (store_id, kasir_id, subtotal_amount, discount_amount, discount_type, tax_amount, tax_percent, total_amount, payment_method, customer_id, shift_id, customer_note, status, table_number)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            $stmt->execute([
                $storeId, $user['id'],
                $subtotalAmount, $discountAmount, $discountType,
                $taxAmount, $taxPercent, $input['total_amount'],
                $paymentMethod, $customerId, $shiftId, $customerNote, $status, $tableNumber
            ]);
            $transactionId = $pdo->lastInsertId();

            // Insert items & deduct stock
            if (!empty($input['items']) && is_array($input['items'])) {
                $stmtItem = $pdo->prepare("INSERT INTO transaction_items (transaction_id, menu_id, quantity, price, variant_id, variant_name, addons_info) VALUES (?, ?, ?, ?, ?, ?, ?)");
                foreach ($input['items'] as $item) {
                    $addonsInfo = !empty($item['addons']) ? json_encode($item['addons']) : null;
                    $stmtItem->execute([
                        $transactionId,
                        $item['menu_id'],
                        $item['quantity'],
                        $item['price'],
                        $item['variant_id'] ?? null,
                        $item['variant_name'] ?? null,
                        $addonsInfo
                    ]);
                    // Deduct stock
                    $pdo->prepare("UPDATE stock SET quantity = GREATEST(0, quantity - ?) WHERE menu_id = ?")
                        ->execute([$item['quantity'], $item['menu_id']]);
                }
            }

            // Update customer: add points + spend + visit count
            if ($customerId && $status === 'completed') {
                $pointsEarned = (int)floor($input['total_amount'] / 1000);
                $pdo->prepare("
                    UPDATE customers
                    SET points = points + ?, total_spend = total_spend + ?, visit_count = visit_count + 1
                    WHERE id = ?
                ")->execute([$pointsEarned, $input['total_amount'], $customerId]);
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
        $transaction['discount_amount'] = (double)$transaction['discount_amount'];
        $transaction['tax_amount'] = (double)$transaction['tax_amount'];

        http_response_code(201);
        echo json_encode([
            "message" => "Checkout successful",
            "transaction" => $transaction
        ]);
        exit;

    // =========================================================================
    // SAVED BILLS ROUTES
    // =========================================================================

    } elseif ($method === 'GET' && $route === '/api/checkout/saved') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403);
            echo json_encode(["error" => "Forbidden: Only kasir can view saved bills"]);
            exit;
        }

        $stmt = $pdo->prepare("
            SELECT t.id, t.created_at, t.total_amount, t.subtotal_amount, t.discount_amount, t.tax_amount, t.customer_id, t.table_number, t.customer_note
            FROM transactions t
            WHERE t.kasir_id = ? AND t.status = 'saved'
            ORDER BY t.created_at ASC
        ");
        $stmt->execute([$user['id']]);
        $transactions = $stmt->fetchAll();

        foreach ($transactions as &$tx) {
            $tx['id'] = (int)$tx['id'];
            $tx['total_amount'] = (double)$tx['total_amount'];
            $tx['subtotal_amount'] = (double)($tx['subtotal_amount'] ?? $tx['total_amount']);
            $tx['discount_amount'] = (double)($tx['discount_amount'] ?? 0);
            $tx['tax_amount'] = (double)($tx['tax_amount'] ?? 0);

            $stmtItems = $pdo->prepare("
                SELECT ti.quantity, ti.price, m.name, m.id as menu_id
                FROM transaction_items ti
                JOIN menus m ON ti.menu_id = m.id
                WHERE ti.transaction_id = ?
            ");
            $stmtItems->execute([$tx['id']]);
            $items = $stmtItems->fetchAll();
            foreach ($items as &$it) {
                $it['menu_id'] = (int)$it['menu_id'];
                $it['quantity'] = (int)$it['quantity'];
                $it['price'] = (double)$it['price'];
            }
            $tx['items'] = $items;

            if ($tx['customer_id']) {
                $stmtCust = $pdo->prepare("SELECT id, name, phone FROM customers WHERE id = ?");
                $stmtCust->execute([$tx['customer_id']]);
                $tx['customer'] = $stmtCust->fetch() ?: null;
            } else {
                $tx['customer'] = null;
            }
        }

        echo json_encode($transactions);
        exit;

    } elseif ($method === 'PUT' && preg_match('/^\/api\/checkout\/(\d+)\/pay$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403);
            echo json_encode(["error" => "Forbidden"]);
            exit;
        }

        $transactionId = $matches[1];
        $input = json_decode(file_get_contents('php://input'), true);
        $paymentMethod = $input['payment_method'] ?? 'cash';
        
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare("SELECT * FROM transactions WHERE id = ? AND status = 'saved' AND kasir_id = ? FOR UPDATE");
            $stmt->execute([$transactionId, $user['id']]);
            $tx = $stmt->fetch();

            if (!$tx) {
                http_response_code(404);
                echo json_encode(["error" => "Saved bill not found or already paid"]);
                $pdo->rollBack();
                exit;
            }

            $pdo->prepare("UPDATE transactions SET status = 'completed', payment_method = ? WHERE id = ?")
                ->execute([$paymentMethod, $transactionId]);

            // Update customer points
            if ($tx['customer_id']) {
                $pointsEarned = (int)floor($tx['total_amount'] / 1000);
                $pdo->prepare("
                    UPDATE customers
                    SET points = points + ?, total_spend = total_spend + ?, visit_count = visit_count + 1
                    WHERE id = ?
                ")->execute([$pointsEarned, $tx['total_amount'], $tx['customer_id']]);
            }

            $pdo->commit();
            echo json_encode(["message" => "Bill paid successfully"]);
        } catch (Exception $e) {
            $pdo->rollBack();
            http_response_code(500);
            echo json_encode(["error" => "Failed to pay bill: " . $e->getMessage()]);
        }
        exit;

    } elseif ($method === 'DELETE' && preg_match('/^\/api\/checkout\/(\d+)$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403);
            echo json_encode(["error" => "Forbidden"]);
            exit;
        }

        $transactionId = $matches[1];
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare("SELECT * FROM transactions WHERE id = ? AND status = 'saved' AND kasir_id = ?");
            $stmt->execute([$transactionId, $user['id']]);
            $tx = $stmt->fetch();

            if (!$tx) {
                http_response_code(404);
                echo json_encode(["error" => "Saved bill not found"]);
                $pdo->rollBack();
                exit;
            }

            // Restore stock
            $stmtItems = $pdo->prepare("SELECT menu_id, quantity FROM transaction_items WHERE transaction_id = ?");
            $stmtItems->execute([$transactionId]);
            $items = $stmtItems->fetchAll();

            foreach ($items as $item) {
                $pdo->prepare("UPDATE stock SET quantity = quantity + ? WHERE menu_id = ?")
                    ->execute([$item['quantity'], $item['menu_id']]);
            }

            $pdo->prepare("UPDATE transactions SET status = 'cancelled' WHERE id = ?")
                ->execute([$transactionId]);

            $pdo->commit();
            echo json_encode(["message" => "Saved bill cancelled successfully"]);
        } catch (Exception $e) {
            $pdo->rollBack();
            http_response_code(500);
            echo json_encode(["error" => "Failed to cancel bill: " . $e->getMessage()]);
        }
        exit;

    // =========================================================================
    // SYNC TRANSACTIONS (UPDATED)
    // =========================================================================

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
            $stmtTx = $pdo->prepare("
                INSERT INTO transactions
                (store_id, kasir_id, subtotal_amount, discount_amount, discount_type, tax_amount, tax_percent, total_amount, payment_method, customer_id, shift_id, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            $stmtItem = $pdo->prepare("INSERT INTO transaction_items (transaction_id, menu_id, quantity, price) VALUES (?, ?, ?, ?)");

            foreach ($input['transactions'] as $tx) {
                $createdAt = !empty($tx['created_at']) ? $tx['created_at'] : date('Y-m-d H:i:s');
                $paymentMethod = !empty($tx['payment_method']) ? $tx['payment_method'] : 'cash';
                if (!in_array($paymentMethod, ['cash', 'qris'])) $paymentMethod = 'cash';

                $stmtTx->execute([
                    $user['store_id'],
                    $user['id'],
                    $tx['subtotal_amount'] ?? $tx['total_amount'],
                    $tx['discount_amount'] ?? 0,
                    $tx['discount_type'] ?? 'nominal',
                    $tx['tax_amount'] ?? 0,
                    $tx['tax_percent'] ?? 0,
                    $tx['total_amount'],
                    $paymentMethod,
                    $tx['customer_id'] ?? null,
                    $tx['shift_id'] ?? null,
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
                        $pdo->prepare("UPDATE stock SET quantity = GREATEST(0, quantity - ?) WHERE menu_id = ?")
                            ->execute([$item['quantity'], $item['menu_id']]);
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

    // =========================================================================
    // OWNER REPORT ROUTES
    // =========================================================================

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
            $tx['discount_amount'] = (double)($tx['discount_amount'] ?? 0);
            $tx['tax_amount'] = (double)($tx['tax_amount'] ?? 0);

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

        // Low stock alerts count
        $stmtLowStock = $pdo->prepare("
            SELECT COUNT(*) as low_stock_count
            FROM stock s
            JOIN menus m ON s.menu_id = m.id
            JOIN stores st ON m.store_id = st.id
            WHERE st.owner_id = ? AND s.quantity <= s.min_stock
        ");
        $stmtLowStock->execute([$user['id']]);
        $lowStock = $stmtLowStock->fetch();

        // Active customers count
        $stmtCust = $pdo->prepare("
            SELECT COUNT(*) as total_customers
            FROM customers c
            JOIN stores st ON c.store_id = st.id
            WHERE st.owner_id = ?
        ");
        $stmtCust->execute([$user['id']]);
        $custData = $stmtCust->fetch();

        echo json_encode([
            'total_sales_today' => (double)($today['total_sales'] ?? 0),
            'total_orders_today' => (int)($today['total_orders'] ?? 0),
            'total_menus' => (int)($menu['total_menus'] ?? 0),
            'low_stock_count' => (int)($lowStock['low_stock_count'] ?? 0),
            'total_customers' => (int)($custData['total_customers'] ?? 0),
        ]);
        exit;

    } elseif ($method === 'GET' && $route === '/api/reports/kasir') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'kasir') {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden: Kasir only']);
            exit;
        }

        $stmt = $pdo->prepare("
            SELECT
                COUNT(*) as total_transactions,
                SUM(total_amount) as total_revenue,
                SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END) as total_cash,
                SUM(CASE WHEN payment_method = 'qris' THEN total_amount ELSE 0 END) as total_qris,
                SUM(discount_amount) as total_discount,
                SUM(tax_amount) as total_tax
            FROM transactions
            WHERE kasir_id = ? AND DATE(created_at) = CURDATE() AND status = 'completed'
        ");
        $stmt->execute([$user['id']]);
        $report = $stmt->fetch();

        $stmtTx = $pdo->prepare("
            SELECT id, created_at, payment_method, total_amount, subtotal_amount, discount_amount, tax_amount, customer_id
            FROM transactions
            WHERE kasir_id = ? AND DATE(created_at) = CURDATE() AND status = 'completed'
            ORDER BY created_at DESC
        ");
        $stmtTx->execute([$user['id']]);
        $transactions = $stmtTx->fetchAll();

        foreach ($transactions as &$tx) {
            $tx['id'] = (int)$tx['id'];
            $tx['total_amount'] = (double)$tx['total_amount'];
            $tx['subtotal_amount'] = (double)($tx['subtotal_amount'] ?? $tx['total_amount']);
            $tx['discount_amount'] = (double)($tx['discount_amount'] ?? 0);
            $tx['tax_amount'] = (double)($tx['tax_amount'] ?? 0);

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

            // Customer info
            if ($tx['customer_id']) {
                $stmtCust = $pdo->prepare("SELECT id, name, phone, points FROM customers WHERE id = ?");
                $stmtCust->execute([$tx['customer_id']]);
                $cust = $stmtCust->fetch();
                $tx['customer'] = $cust ?: null;
            } else {
                $tx['customer'] = null;
            }
        }

        echo json_encode([
            'total_transactions' => (int)$report['total_transactions'],
            'total_revenue' => (double)$report['total_revenue'],
            'total_cash' => (double)$report['total_cash'],
            'total_qris' => (double)$report['total_qris'],
            'total_discount' => (double)($report['total_discount'] ?? 0),
            'total_tax' => (double)($report['total_tax'] ?? 0),
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
                SUM(CASE WHEN t.payment_method = 'qris' THEN t.total_amount ELSE 0 END) as total_qris,
                SUM(t.discount_amount) as total_discount,
                SUM(t.tax_amount) as total_tax
            FROM transactions t
            JOIN stores s ON t.store_id = s.id
            WHERE s.owner_id = ? AND t.status = 'completed'
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
            $r['total_discount'] = (double)($r['total_discount'] ?? 0);
            $r['total_tax'] = (double)($r['total_tax'] ?? 0);

            if ($period === 'daily') {
                $stmtDet = $pdo->prepare("
                    SELECT t.id, t.created_at, t.total_amount, t.payment_method, t.discount_amount, t.tax_amount
                    FROM transactions t
                    JOIN stores s ON t.store_id = s.id
                    WHERE s.owner_id = ? AND DATE_FORMAT(t.created_at, ?) = ? AND t.status = 'completed'
                    ORDER BY t.created_at DESC
                ");
                $stmtDet->execute([$user['id'], $dateFormat, $r['period_date']]);
                $details = $stmtDet->fetchAll();

                foreach ($details as &$d) {
                    $d['total_amount'] = (double)$d['total_amount'];
                    $d['discount_amount'] = (double)($d['discount_amount'] ?? 0);
                    $d['tax_amount'] = (double)($d['tax_amount'] ?? 0);
                    $stmtItems = $pdo->prepare("
                        SELECT ti.quantity, ti.price, m.name
                        FROM transaction_items ti
                        JOIN menus m ON ti.menu_id = m.id
                        WHERE ti.transaction_id = ?
                    ");
                    $stmtItems->execute([$d['id']]);
                    $items = $stmtItems->fetchAll();
                    foreach ($items as &$it) {
                        $it['quantity'] = (int)$it['quantity'];
                        $it['price'] = (double)$it['price'];
                    }
                    $d['items'] = $items;
                }
                $r['details'] = $details;
            } elseif ($period === 'monthly') {
                $stmtDet = $pdo->prepare("
                    SELECT
                        DATE_FORMAT(t.created_at, '%Y-%m-%d') as sub_period_date,
                        SUM(t.total_amount) as sub_total_revenue
                    FROM transactions t
                    JOIN stores s ON t.store_id = s.id
                    WHERE s.owner_id = ? AND DATE_FORMAT(t.created_at, ?) = ? AND t.status = 'completed'
                    GROUP BY sub_period_date
                    ORDER BY sub_period_date DESC
                ");
                $stmtDet->execute([$user['id'], $dateFormat, $r['period_date']]);
                $details = $stmtDet->fetchAll();
                foreach ($details as &$d) {
                    $d['sub_total_revenue'] = (double)$d['sub_total_revenue'];
                }
                $r['details'] = $details;
            } elseif ($period === 'yearly') {
                $stmtDet = $pdo->prepare("
                    SELECT
                        DATE_FORMAT(t.created_at, '%Y-%m') as sub_period_date,
                        SUM(t.total_amount) as sub_total_revenue
                    FROM transactions t
                    JOIN stores s ON t.store_id = s.id
                    WHERE s.owner_id = ? AND DATE_FORMAT(t.created_at, ?) = ? AND t.status = 'completed'
                    GROUP BY sub_period_date
                    ORDER BY sub_period_date DESC
                ");
                $stmtDet->execute([$user['id'], $dateFormat, $r['period_date']]);
                $details = $stmtDet->fetchAll();
                foreach ($details as &$d) {
                    $d['sub_total_revenue'] = (double)$d['sub_total_revenue'];
                }
                $r['details'] = $details;
            }
        }

        echo json_encode($reports);
        exit;

    // =========================================================================
    // OWNER KASIR MANAGEMENT ROUTES
    // =========================================================================

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

    } elseif ($method === 'GET' && $route === '/api/owner/analytics') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner') { http_response_code(403); echo json_encode(['error'=>'Forbidden']); exit; }

        $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
        $stmtStore->execute([$user['id']]);
        $store = $stmtStore->fetch();
        if (!$store) { http_response_code(400); echo json_encode(['error'=>'Store not found']); exit; }

        // Daily sales for the last 7 days
        $stmtSales = $pdo->prepare("
            SELECT DATE(created_at) as date, SUM(total_amount) as total
            FROM transactions
            WHERE store_id = ? AND created_at >= DATE(NOW()) - INTERVAL 6 DAY
            GROUP BY DATE(created_at)
            ORDER BY date ASC
        ");
        $stmtSales->execute([$store['id']]);
        $dailySales = $stmtSales->fetchAll();

        // Top 5 menus
        $stmtTopMenus = $pdo->prepare("
            SELECT m.name, SUM(ti.quantity) as sold
            FROM transaction_items ti
            JOIN transactions t ON ti.transaction_id = t.id
            JOIN menus m ON ti.menu_id = m.id
            WHERE t.store_id = ?
            GROUP BY m.id
            ORDER BY sold DESC
            LIMIT 5
        ");
        $stmtTopMenus->execute([$store['id']]);
        $topMenus = $stmtTopMenus->fetchAll();

        echo json_encode([
            'daily_sales' => $dailySales,
            'top_menus' => $topMenus
        ]);
        exit;

    } elseif ($method === 'GET' && $route === '/api/owner/export-data') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'owner') { http_response_code(403); echo json_encode(['error'=>'Forbidden']); exit; }

        $stmtStore = $pdo->prepare("SELECT id FROM stores WHERE owner_id = ? LIMIT 1");
        $stmtStore->execute([$user['id']]);
        $store = $stmtStore->fetch();
        if (!$store) { http_response_code(400); echo json_encode(['error'=>'Store not found']); exit; }

        $period = $_GET['period'] ?? 'mingguan';
        
        $dateFilter = "";
        $groupBy = "DATE(created_at)";
        $selectDate = "DATE(created_at) as date";

        if ($period === 'harian') {
            $dateFilter = "AND DATE(t.created_at) = DATE(NOW())";
            $groupBy = "HOUR(t.created_at)";
            $selectDate = "CONCAT(HOUR(t.created_at), ':00') as date";
        } elseif ($period === 'mingguan') {
            $dateFilter = "AND t.created_at >= DATE(NOW()) - INTERVAL 6 DAY";
        } elseif ($period === 'bulanan') {
            $dateFilter = "AND t.created_at >= DATE(NOW()) - INTERVAL 29 DAY";
        } elseif ($period === 'tahunan') {
            $dateFilter = "AND t.created_at >= DATE(NOW()) - INTERVAL 1 YEAR";
            $groupBy = "DATE_FORMAT(t.created_at, '%Y-%m')";
            $selectDate = "DATE_FORMAT(t.created_at, '%Y-%m') as date";
        }

        // Stats
        $stmtStats = $pdo->prepare("
            SELECT SUM(total_amount) as total_revenue, COUNT(id) as total_transactions
            FROM transactions t
            WHERE t.store_id = ? $dateFilter
        ");
        $stmtStats->execute([$store['id']]);
        $stats = $stmtStats->fetch();

        // Total Customers
        $stmtCust = $pdo->prepare("
            SELECT COUNT(DISTINCT customer_id) as total_customers
            FROM transactions t
            WHERE t.store_id = ? AND customer_id IS NOT NULL AND customer_id != 0 $dateFilter
        ");
        $stmtCust->execute([$store['id']]);
        $cust = $stmtCust->fetch();

        // Sales trend
        $stmtSales = $pdo->prepare("
            SELECT $selectDate, SUM(total_amount) as total
            FROM transactions t
            WHERE t.store_id = ? $dateFilter
            GROUP BY $groupBy
            ORDER BY MIN(t.created_at) ASC
        ");
        $stmtSales->execute([$store['id']]);
        $dailySales = $stmtSales->fetchAll();

        // Top 5 menus
        $stmtTopMenus = $pdo->prepare("
            SELECT m.name, SUM(ti.quantity) as sold
            FROM transaction_items ti
            JOIN transactions t ON ti.transaction_id = t.id
            JOIN menus m ON ti.menu_id = m.id
            WHERE t.store_id = ? $dateFilter
            GROUP BY m.id
            ORDER BY sold DESC
            LIMIT 5
        ");
        $stmtTopMenus->execute([$store['id']]);
        $topMenus = $stmtTopMenus->fetchAll();

        echo json_encode([
            'total_revenue' => (double)($stats['total_revenue'] ?? 0),
            'total_transactions' => (int)($stats['total_transactions'] ?? 0),
            'total_customers' => (int)($cust['total_customers'] ?? 0),
            'daily_sales' => $dailySales,
            'top_menus' => $topMenus
        ]);
        exit;

    // =========================================================================
    // SUPER ADMIN ROUTES
    // =========================================================================

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

        // Get current status first
        $stmtGet = $pdo->prepare("SELECT id, name, email, is_active FROM users WHERE id = ? AND role = 'owner' LIMIT 1");
        $stmtGet->execute([$ownerId]);
        $owner = $stmtGet->fetch();
        if (!$owner) {
            http_response_code(404); echo json_encode(['error' => 'Owner not found']); exit;
        }

        $newStatus = !$owner['is_active'];
        $pdo->prepare("UPDATE users SET is_active = ?, suspended_at = ? WHERE id = ? AND role = 'owner'")
            ->execute([$newStatus, $newStatus ? null : date('Y-m-d H:i:s'), $ownerId]);

        echo json_encode([
            'message' => $newStatus ? 'Owner berhasil diaktifkan' : 'Owner berhasil ditangguhkan',
            'owner_id' => (int)$ownerId,
            'is_active' => $newStatus,
        ]);
        exit;

    // =========================================================================
    // SUPER ADMIN — GET ALL OWNERS
    // =========================================================================
    } elseif ($method === 'GET' && $route === '/api/admin/owners') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'super_admin') { http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit; }

        $stmt = $pdo->query("
            SELECT u.id, u.name, u.email, u.is_active, u.created_at, u.suspended_at,
                   COUNT(DISTINCT s.id) as total_stores,
                   COUNT(DISTINCT k.id) as total_kasir
            FROM users u
            LEFT JOIN stores s ON s.owner_id = u.id
            LEFT JOIN users k ON k.store_id = s.id AND k.role = 'kasir'
            WHERE u.role = 'owner'
            GROUP BY u.id
            ORDER BY u.created_at DESC
        ");
        $owners = $stmt->fetchAll();

        foreach ($owners as &$owner) {
            $owner['id'] = (int)$owner['id'];
            $owner['is_active'] = (bool)$owner['is_active'];
            $owner['total_stores'] = (int)$owner['total_stores'];
            $owner['total_kasir'] = (int)$owner['total_kasir'];
        }

        http_response_code(200);
        echo json_encode($owners);
        exit;

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
GET['status'] ?? 'all';
        $whereClause = ($statusFilter !== 'all') ? "WHERE prr.status = '" . $statusFilter . "'" : '';
        $stmt = $pdo->query("SELECT prr.id, prr.user_id, prr.email, prr.reason, prr.status, prr.admin_note, prr.created_at, prr.resolved_at, u.name as owner_name FROM password_reset_requests prr JOIN users u ON prr.user_id = u.id $whereClause ORDER BY CASE prr.status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END, prr.created_at DESC LIMIT 100");
        $requests = $stmt->fetchAll();
        foreach ($requests as &$req) { $req['id'] = (int)$req['id']; $req['user_id'] = (int)$req['user_id']; }
        echo json_encode($requests);
        exit;

    } elseif ($method === 'POST' && preg_match('/^\/api\/admin\/password-reset-requests\/(\d+)\/(approve|reject)$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'super_admin') { http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit; }
        $requestId = (int)$matches[1];
        $action = $matches[2];
        $input = json_decode(file_get_contents('php://input'), true);
        $stmtReq = $pdo->prepare("SELECT * FROM password_reset_requests WHERE id = ? AND status = 'pending' LIMIT 1");
        $stmtReq->execute([$requestId]);
        $resetReq = $stmtReq->fetch();
        if (!$resetReq) { http_response_code(404); echo json_encode(['error' => 'Request tidak ditemukan atau sudah diproses']); exit; }
        if ($action === 'approve') {
            if (!empty($resetReq['temp_password'])) {
                $newPasswordHash = $resetReq['temp_password'];
                $tempPasswordPlain = $resetReq['temp_password_plain'] ?? 'Diatur oleh Owner';
                $adminNote = $input['admin_note'] ?? 'Permintaan ubah password disetujui.';
                $responseMessage = 'Permintaan ubah password disetujui.';
            } else {
                $tempPasswordPlain = 'TMP' . strtoupper(bin2hex(random_bytes(3)));
                $newPasswordHash = password_hash($tempPasswordPlain, PASSWORD_BCRYPT);
                $adminNote = $input['admin_note'] ?? 'Password sementara telah diberikan. Segera ubah setelah login.';
                $responseMessage = 'Password sementara berhasil dibuat.';
            }
            $pdo->beginTransaction();
            try {
                $pdo->prepare("UPDATE users SET password = ? WHERE id = ?")->execute([$newPasswordHash, $resetReq['user_id']]);
                $pdo->prepare("UPDATE password_reset_requests SET status = 'approved', temp_password_plain = ?, admin_note = ?, resolved_at = NOW() WHERE id = ?")->execute([$tempPasswordPlain, $adminNote, $requestId]);
                $pdo->prepare("DELETE FROM user_tokens WHERE user_id = ?")->execute([$resetReq['user_id']]);
                $pdo->commit();
            } catch (Exception $e) {
                $pdo->rollBack();
                http_response_code(500); echo json_encode(['error' => 'Gagal: ' . $e->getMessage()]); exit;
            }
            echo json_encode(['message' => $responseMessage, 'temp_password' => $tempPasswordPlain, 'owner_email' => $resetReq['email']]);
            exit;
        } else {
            $adminNote = $input['admin_note'] ?? 'Permintaan ditolak oleh Super Admin.';
            $pdo->prepare("UPDATE password_reset_requests SET status = 'rejected', admin_note = ?, resolved_at = NOW() WHERE id = ?")->execute([$adminNote, $requestId]);
            echo json_encode(['message' => 'Permintaan berhasil ditolak.']);
            exit;
        }

    // =========================================================================
    // GLOBAL STATISTICS
    // =========================================================================
    } elseif ($method === 'GET' && $route === '/api/admin/stats') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'super_admin') { http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit; }
        $thisMonth = date('Y-m-01');
        $lastMonth = date('Y-m-01', strtotime('-1 month'));
        $lastMonthEnd = date('Y-m-t', strtotime('-1 month')) . ' 23:59:59';
        $s1 = $pdo->prepare("SELECT COALESCE(SUM(total_amount),0) FROM transactions WHERE status='completed' AND created_at >= ?"); $s1->execute([$thisMonth]); $revenueThis = (double)$s1->fetchColumn();
        $s2 = $pdo->prepare("SELECT COALESCE(SUM(total_amount),0) FROM transactions WHERE status='completed' AND created_at BETWEEN ? AND ?"); $s2->execute([$lastMonth,$lastMonthEnd]); $revenueLast = (double)$s2->fetchColumn();
        $totalTx = (int)$pdo->query("SELECT COUNT(*) FROM transactions WHERE status='completed'")->fetchColumn();
        $s3 = $pdo->prepare("SELECT COUNT(*) FROM transactions WHERE status='completed' AND created_at >= ?"); $s3->execute([$thisMonth]); $txThis = (int)$s3->fetchColumn();
        $ownerStats = $pdo->query("SELECT COUNT(*) as total, SUM(is_active) as active FROM users WHERE role='owner'")->fetch();
        $totalKasir = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role='kasir'")->fetchColumn();
        $totalMenus = (int)$pdo->query("SELECT COUNT(*) FROM menus")->fetchColumn();
        $totalCustomers = (int)$pdo->query("SELECT COUNT(*) FROM customers")->fetchColumn();
        $pendingResets = (int)$pdo->query("SELECT COUNT(*) FROM password_reset_requests WHERE status='pending'")->fetchColumn();
        $monthlyRevenue = [];
        for ($i = 5; $i >= 0; $i--) {
            $mStart = date('Y-m-01', strtotime("-$i months"));
            $mEnd = date('Y-m-t', strtotime("-$i months")) . ' 23:59:59';
            $mLabel = date('M Y', strtotime("-$i months"));
            $sm = $pdo->prepare("SELECT COALESCE(SUM(total_amount),0) FROM transactions WHERE status='completed' AND created_at BETWEEN ? AND ?"); $sm->execute([$mStart,$mEnd]);
            $monthlyRevenue[] = ['month' => $mLabel, 'revenue' => (double)$sm->fetchColumn()];
        }
        $topMenus = $pdo->query("SELECT m.name, SUM(ti.quantity) as total_sold, SUM(ti.quantity * ti.price) as total_revenue FROM transaction_items ti JOIN menus m ON ti.menu_id = m.id JOIN transactions t ON ti.transaction_id = t.id WHERE t.status='completed' GROUP BY m.id, m.name ORDER BY total_sold DESC LIMIT 5")->fetchAll();
        foreach ($topMenus as &$tm) { $tm['total_sold'] = (int)$tm['total_sold']; $tm['total_revenue'] = (double)$tm['total_revenue']; }
        $topOwners = $pdo->query("SELECT u.name, u.email, COALESCE(SUM(t.total_amount),0) as total_revenue, COUNT(t.id) as total_transactions FROM users u LEFT JOIN stores s ON s.owner_id = u.id LEFT JOIN transactions t ON t.store_id = s.id AND t.status='completed' WHERE u.role='owner' GROUP BY u.id, u.name, u.email ORDER BY total_revenue DESC LIMIT 5")->fetchAll();
        foreach ($topOwners as &$to) { $to['total_revenue'] = (double)$to['total_revenue']; $to['total_transactions'] = (int)$to['total_transactions']; }
        echo json_encode(['revenue' => ['this_month' => $revenueThis, 'last_month' => $revenueLast, 'growth_percent' => $revenueLast > 0 ? round((($revenueThis-$revenueLast)/$revenueLast)*100,1) : 0], 'transactions' => ['total' => $totalTx, 'this_month' => $txThis], 'users' => ['total_owners' => (int)$ownerStats['total'], 'active_owners' => (int)$ownerStats['active'], 'suspended_owners' => (int)$ownerStats['total']-(int)$ownerStats['active'], 'total_kasir' => $totalKasir, 'total_customers' => $totalCustomers], 'content' => ['total_menus' => $totalMenus], 'alerts' => ['pending_reset_requests' => $pendingResets], 'charts' => ['monthly_revenue' => $monthlyRevenue, 'top_menus' => $topMenus, 'top_owners' => $topOwners]]);
        exit;

    // =========================================================================
    // SYSTEM SETTINGS
    // =========================================================================
    } elseif ($method === 'GET' && $route === '/api/admin/settings') {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'super_admin') { http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit; }
        $stmt = $pdo->query("SELECT id, code, is_used, created_at FROM verification_codes ORDER BY created_at DESC LIMIT 50");
        $codes = $stmt->fetchAll();
        foreach ($codes as &$c) { $c['id'] = (int)$c['id']; $c['is_used'] = (bool)$c['is_used']; }
        $totalCodes = (int)$pdo->query("SELECT COUNT(*) FROM verification_codes")->fetchColumn();
        $usedCodes = (int)$pdo->query("SELECT COUNT(*) FROM verification_codes WHERE is_used = 1")->fetchColumn();
        echo json_encode(['verification_codes' => $codes, 'summary' => ['total_codes' => $totalCodes, 'used_codes' => $usedCodes, 'available_codes' => $totalCodes - $usedCodes]]);
        exit;

    } elseif ($method === 'DELETE' && preg_match('/^\/api\/admin\/verification-codes\/(\d+)$/', $route, $matches)) {
        $user = getAuthUser($pdo);
        if ($user['role'] !== 'super_admin') { http_response_code(403); echo json_encode(['error' => 'Forbidden']); exit; }
        $codeId = (int)$matches[1];
        $pdo->prepare("DELETE FROM verification_codes WHERE id = ? AND is_used = 0")->execute([$codeId]);
        echo json_encode(['message' => 'Kode verifikasi dihapus']);
        exit;

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
