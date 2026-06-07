<?php
require_once __DIR__ . '/config.php';
try {
    $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4";
    $pdo = new PDO($dsn, DB_USER, DB_PASS);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $stmt = $pdo->prepare("
        SELECT 
            COUNT(*) as total_transactions,
            SUM(total_amount) as total_revenue,
            SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END) as total_cash,
            SUM(CASE WHEN payment_method = 'qris' THEN total_amount ELSE 0 END) as total_qris
        FROM transactions 
        WHERE kasir_id = ? AND DATE(created_at) = CURDATE()
    ");
    $stmt->execute([1]);
    $report = $stmt->fetch(PDO::FETCH_ASSOC);
    print_r($report);
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage();
}
?>
