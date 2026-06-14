<?php
$db = new PDO('mysql:host=localhost;dbname=protoype_kasir', 'root', '');
$stmt = $db->query("SELECT * FROM users WHERE role = 'owner' LIMIT 1");
$user = $stmt->fetch();
$storeStmt = $db->query("SELECT id FROM stores WHERE owner_id = " . $user['id']);
$store = $storeStmt->fetch();

echo "User ID: " . $user['id'] . "\n";
echo "Store ID: " . $store['id'] . "\n";

$period = 'mingguan';
$dateFilter = "AND created_at >= DATE(NOW()) - INTERVAL 6 DAY";
$groupBy = "DATE(created_at)";
$selectDate = "DATE(created_at) as date";

$stmtStats = $db->prepare("SELECT SUM(total_amount) as total_revenue, COUNT(id) as total_transactions FROM transactions WHERE store_id = ? $dateFilter");
$stmtStats->execute([$store['id']]);
$stats = $stmtStats->fetch();

$stmtCust = $db->prepare("SELECT COUNT(DISTINCT customer_id) as total_customers FROM transactions WHERE store_id = ? AND customer_id IS NOT NULL AND customer_id != 0 $dateFilter");
$stmtCust->execute([$store['id']]);
$cust = $stmtCust->fetch();

echo json_encode(['stats' => $stats, 'cust' => $cust]);
?>
