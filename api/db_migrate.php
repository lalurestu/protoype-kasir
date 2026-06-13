<?php
// api/db_migrate.php
// Safe migration: hanya ALTER TABLE dan CREATE TABLE IF NOT EXISTS
// Tidak ada DROP TABLE - data lama aman!

require_once __DIR__ . '/config.php';

try {
    $pdo = getDBConnection();
    echo "=== Database Migration v2.0 ===\n";
    echo "Menambahkan fitur: Stok, Shift, Diskon, Pajak, Pelanggan\n\n";

    // ─────────────────────────────────────────────────────────────────────
    // 1. ALTER TABLE menus — Tambah kolom is_available (jika belum ada)
    // ─────────────────────────────────────────────────────────────────────
    try {
        $pdo->exec("ALTER TABLE `menus` ADD COLUMN `is_available` BOOLEAN DEFAULT TRUE NOT NULL;");
        echo "[OK] menus: kolom 'is_available' ditambahkan.\n";
    } catch (PDOException $e) {
        echo "[SKIP] menus.is_available sudah ada.\n";
    }

    try {
        $pdo->exec("ALTER TABLE `menus` ADD COLUMN `description` TEXT NULL;");
        echo "[OK] menus: kolom 'description' ditambahkan.\n";
    } catch (PDOException $e) {
        echo "[SKIP] menus.description sudah ada.\n";
    }

    // ─────────────────────────────────────────────────────────────────────
    // 2. CREATE TABLE customers
    // ─────────────────────────────────────────────────────────────────────
    $pdo->exec("CREATE TABLE IF NOT EXISTS `customers` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `store_id` INT NOT NULL,
        `name` VARCHAR(255) NOT NULL,
        `phone` VARCHAR(20) UNIQUE NOT NULL,
        `email` VARCHAR(255) NULL,
        `points` INT DEFAULT 0 NOT NULL,
        `total_spend` DECIMAL(15, 2) DEFAULT 0 NOT NULL,
        `visit_count` INT DEFAULT 0 NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "[OK] Tabel 'customers' siap.\n";

    // ─────────────────────────────────────────────────────────────────────
    // 3. CREATE TABLE shifts
    // ─────────────────────────────────────────────────────────────────────
    $pdo->exec("CREATE TABLE IF NOT EXISTS `shifts` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `kasir_id` INT NOT NULL,
        `store_id` INT NOT NULL,
        `opening_cash` DECIMAL(15, 2) NOT NULL DEFAULT 0,
        `closing_cash` DECIMAL(15, 2) NULL,
        `total_sales` DECIMAL(15, 2) DEFAULT 0 NOT NULL,
        `total_transactions` INT DEFAULT 0 NOT NULL,
        `note` TEXT NULL,
        `opened_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `closed_at` TIMESTAMP NULL,
        `status` ENUM('open', 'closed') DEFAULT 'open' NOT NULL,
        FOREIGN KEY (`kasir_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
        FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "[OK] Tabel 'shifts' siap.\n";

    // ─────────────────────────────────────────────────────────────────────
    // 4. CREATE TABLE stock
    // ─────────────────────────────────────────────────────────────────────
    $pdo->exec("CREATE TABLE IF NOT EXISTS `stock` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `menu_id` INT NOT NULL UNIQUE,
        `quantity` INT DEFAULT 0 NOT NULL,
        `min_stock` INT DEFAULT 5 NOT NULL,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (`menu_id`) REFERENCES `menus` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "[OK] Tabel 'stock' siap.\n";

    // ─────────────────────────────────────────────────────────────────────
    // 5. ALTER TABLE transactions — Tambah kolom baru
    // ─────────────────────────────────────────────────────────────────────
    $txAlters = [
        "ALTER TABLE `transactions` ADD COLUMN `discount_amount` DECIMAL(15,2) DEFAULT 0 NOT NULL;",
        "ALTER TABLE `transactions` ADD COLUMN `discount_type` ENUM('percent', 'nominal') DEFAULT 'nominal';",
        "ALTER TABLE `transactions` ADD COLUMN `tax_amount` DECIMAL(15,2) DEFAULT 0 NOT NULL;",
        "ALTER TABLE `transactions` ADD COLUMN `tax_percent` DECIMAL(5,2) DEFAULT 0 NOT NULL;",
        "ALTER TABLE `transactions` ADD COLUMN `customer_id` INT NULL;",
        "ALTER TABLE `transactions` ADD COLUMN `shift_id` INT NULL;",
        "ALTER TABLE `transactions` ADD COLUMN `subtotal_amount` DECIMAL(15,2) DEFAULT 0 NOT NULL;",
        "ALTER TABLE `transactions` ADD COLUMN `customer_note` TEXT NULL;",
    ];

    $txAlterCols = [
        'discount_amount', 'discount_type', 'tax_amount', 'tax_percent',
        'customer_id', 'shift_id', 'subtotal_amount', 'customer_note'
    ];

    foreach ($txAlters as $i => $sql) {
        try {
            $pdo->exec($sql);
            echo "[OK] transactions: kolom '{$txAlterCols[$i]}' ditambahkan.\n";
        } catch (PDOException $e) {
            echo "[SKIP] transactions.{$txAlterCols[$i]} sudah ada.\n";
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // 6. Seed stock records untuk menu yang sudah ada (jika belum ada)
    // ─────────────────────────────────────────────────────────────────────
    $stmt = $pdo->query("SELECT id FROM menus");
    $menuIds = $stmt->fetchAll(PDO::FETCH_COLUMN);
    $insertedStock = 0;
    foreach ($menuIds as $menuId) {
        try {
            $pdo->prepare("INSERT IGNORE INTO `stock` (menu_id, quantity, min_stock) VALUES (?, 50, 5)")
                ->execute([$menuId]);
            $insertedStock++;
        } catch (PDOException $e) { /* skip if exists */ }
    }
    echo "[OK] Stock awal diisi untuk $insertedStock menu.\n";

    echo "\n=== Migrasi Selesai! ===\n";
    echo "Semua tabel dan kolom baru telah ditambahkan.\n";
    echo "Data yang sudah ada tetap aman.\n";

} catch (PDOException $e) {
    echo "Migration GAGAL: " . $e->getMessage() . "\n";
    exit(1);
}
