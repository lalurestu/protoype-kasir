<?php
require_once __DIR__ . '/config.php';

try {
    $pdo = getDBConnection();
    
    try {
        $pdo->exec("ALTER TABLE users ADD COLUMN maintenance_price DECIMAL(15, 2) DEFAULT 0 NOT NULL;");
        echo "[OK] users: maintenance_price added.\n";
    } catch (PDOException $e) {
        echo "[SKIP] users.maintenance_price already exists or error: " . $e->getMessage() . "\n";
    }

    $pdo->exec("CREATE TABLE IF NOT EXISTS maintenance_transactions (
        id SERIAL PRIMARY KEY,
        user_id INT NOT NULL,
        order_id VARCHAR(100) UNIQUE NOT NULL,
        amount DECIMAL(15, 2) NOT NULL,
        duration_days INT NOT NULL,
        status VARCHAR(20) DEFAULT 'pending' NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        paid_at TIMESTAMP NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    );");
    echo "[OK] maintenance_transactions table ready.\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
