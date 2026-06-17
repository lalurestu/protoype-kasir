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
        "ALTER TABLE `transactions` ADD COLUMN `status` ENUM('completed', 'saved', 'cancelled') DEFAULT 'completed' NOT NULL;",
        "ALTER TABLE `transactions` ADD COLUMN `table_number` VARCHAR(20) NULL;",
    ];

    $txAlterCols = [
        'discount_amount', 'discount_type', 'tax_amount', 'tax_percent',
        'customer_id', 'shift_id', 'subtotal_amount', 'customer_note',
        'status', 'table_number'
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

    // ─────────────────────────────────────────────────────────────────────
    // 6. CREATE TABLE menu_variants
    // ─────────────────────────────────────────────────────────────────────
    $pdo->exec("CREATE TABLE IF NOT EXISTS `menu_variants` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `menu_id` INT NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `price` DECIMAL(10, 2) NOT NULL,
        FOREIGN KEY (`menu_id`) REFERENCES `menus` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "[OK] Tabel 'menu_variants' siap.\n";

    // ─────────────────────────────────────────────────────────────────────
    // 7. CREATE TABLE menu_addons
    // ─────────────────────────────────────────────────────────────────────
    $pdo->exec("CREATE TABLE IF NOT EXISTS `menu_addons` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `menu_id` INT NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `price` DECIMAL(10, 2) NOT NULL,
        FOREIGN KEY (`menu_id`) REFERENCES `menus` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "[OK] Tabel 'menu_addons' siap.\n";

    // ─────────────────────────────────────────────────────────────────────
    // 8. ALTER TABLE transaction_items
    // ─────────────────────────────────────────────────────────────────────
    try {
        $pdo->exec("ALTER TABLE `transaction_items` ADD COLUMN `variant_id` INT NULL;");
        $pdo->exec("ALTER TABLE `transaction_items` ADD COLUMN `variant_name` VARCHAR(100) NULL;");
        $pdo->exec("ALTER TABLE `transaction_items` ADD COLUMN `addons_info` TEXT NULL;"); // JSON of addons {"name": "Keju", "price": 5000}
        echo "[OK] transaction_items: kolom variant & addons ditambahkan.\n";
    } catch (PDOException $e) {
        echo "[SKIP] transaction_items.variant_id sudah ada.\n";
    }

    echo "\n=== Migrasi Selesai! ===\n";
    echo "Semua tabel dan kolom baru telah ditambahkan.\n";
    echo "Data yang sudah ada tetap aman.\n";

    // ─────────────────────────────────────────────────────────────────────
    // 9. ALTER TABLE users — Kolom untuk suspension system
    // ─────────────────────────────────────────────────────────────────────
    try {
        $pdo->exec("ALTER TABLE `users` ADD COLUMN `is_active` TINYINT(1) NOT NULL DEFAULT 1;");
        echo "[OK] users: kolom 'is_active' ditambahkan.\n";
    } catch (PDOException $e) {
        echo "[SKIP] users.is_active sudah ada.\n";
    }

    try {
        $pdo->exec("ALTER TABLE `users` ADD COLUMN `suspended_at` TIMESTAMP NULL;");
        echo "[OK] users: kolom 'suspended_at' ditambahkan.\n";
    } catch (PDOException $e) {
        echo "[SKIP] users.suspended_at sudah ada.\n";
    }

    try {
        $pdo->exec("ALTER TABLE `users` ADD COLUMN `suspended_reason` TEXT NULL;");
        echo "[OK] users: kolom 'suspended_reason' ditambahkan.\n";
    } catch (PDOException $e) {
        echo "[SKIP] users.suspended_reason sudah ada.\n";
    }

    // Pastikan semua user existing memiliki is_active = 1 (sudah aktif)
    $pdo->exec("UPDATE users SET is_active = 1 WHERE is_active IS NULL");
    echo "[OK] Semua user existing set is_active = 1 (pastikan default aktif).\n";

    // ─────────────────────────────────────────────────────────────────────
    // 10. CREATE TABLE password_reset_requests
    //     Owner mengirimkan permintaan reset password ke Super Admin.
    //     Admin bisa approve (set password baru) atau reject (with reason).
    // ─────────────────────────────────────────────────────────────────────
    $pdo->exec("CREATE TABLE IF NOT EXISTS `password_reset_requests` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `user_id` INT NOT NULL,
        `email` VARCHAR(255) NOT NULL,
        `reason` TEXT NULL,
        `status` ENUM('pending', 'approved', 'rejected') DEFAULT 'pending' NOT NULL,
        `temp_password` VARCHAR(255) NULL COMMENT 'Temporary password set by admin (hashed)',
        `temp_password_plain` VARCHAR(100) NULL COMMENT 'Plaintext temp password to show admin once',
        `admin_note` TEXT NULL COMMENT 'Reason for rejection or note from admin',
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `resolved_at` TIMESTAMP NULL,
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "[OK] Tabel 'password_reset_requests' siap.\n";

    echo "\n=== ✅ Semua Migrasi Berhasil! ===\n";

} catch (Exception $e) {
    echo "\n[ERROR] Migrasi gagal:\n";
    echo $e->getMessage() . "\n";
    exit(1);
}
