<?php
// api/db_init.php

require_once __DIR__ . '/config.php';

try {
    // 1. Connect to MySQL Server (without DB name first)
    $dsn = "mysql:host=" . DB_HOST . ";charset=utf8mb4";
    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ];
    $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
    echo "Connected to MySQL server successfully.\n";

    // 2. Create Database
    $dbName = DB_NAME;
    $pdo->exec("CREATE DATABASE IF NOT EXISTS `$dbName` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    echo "Database `$dbName` verified/created successfully.\n";

    // 3. Select Database
    $pdo->exec("USE `$dbName`");
    echo "Using Database `$dbName`.\n";

    // 4. Drop tables in correct order if they exist
    $pdo->exec("SET FOREIGN_KEY_CHECKS = 0;");
    $pdo->exec("DROP TABLE IF EXISTS `user_tokens`;");
    $pdo->exec("DROP TABLE IF EXISTS `transaction_items`;");
    $pdo->exec("DROP TABLE IF EXISTS `transactions`;");
    $pdo->exec("DROP TABLE IF EXISTS `verification_codes`;");
    $pdo->exec("DROP TABLE IF EXISTS `menus`;");
    $pdo->exec("DROP TABLE IF EXISTS `stores`;");
    $pdo->exec("DROP TABLE IF EXISTS `users`;");
    $pdo->exec("SET FOREIGN_KEY_CHECKS = 1;");
    echo "Dropped existing tables (fresh start).\n";

    // 5. Create Tables
    // Users
    $pdo->exec("CREATE TABLE `users` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(255) NOT NULL,
        `email` VARCHAR(255) UNIQUE NOT NULL,
        `password` VARCHAR(255) NOT NULL,
        `role` ENUM('super_admin', 'owner', 'kasir') NOT NULL,
        `store_id` INT NULL,
        `tenant_id` INT NULL,
        `is_active` BOOLEAN DEFAULT TRUE NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;");
    echo "Created table `users`.\n";

    // Stores
    $pdo->exec("CREATE TABLE `stores` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `owner_id` INT NOT NULL,
        `name` VARCHAR(255) NOT NULL,
        `address` TEXT NOT NULL,
        `logo` VARCHAR(255) NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "Created table `stores`.\n";

    // Menus
    $pdo->exec("CREATE TABLE `menus` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `store_id` INT NOT NULL,
        `name` VARCHAR(255) NOT NULL,
        `price` DECIMAL(10, 2) NOT NULL,
        `category` VARCHAR(255) NOT NULL,
        `image_url` VARCHAR(255) NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "Created table `menus`.\n";

    // Transactions
    $pdo->exec("CREATE TABLE `transactions` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `store_id` INT NOT NULL,
        `kasir_id` INT NOT NULL,
        `total_amount` DECIMAL(15, 2) NOT NULL,
        `payment_method` ENUM('cash', 'qris') DEFAULT 'cash' NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`) ON DELETE CASCADE,
        FOREIGN KEY (`kasir_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "Created table `transactions`.\n";

    // Transaction Items
    $pdo->exec("CREATE TABLE `transaction_items` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `transaction_id` INT NOT NULL,
        `menu_id` INT NOT NULL,
        `quantity` INT NOT NULL,
        `price` DECIMAL(10, 2) NOT NULL,
        FOREIGN KEY (`transaction_id`) REFERENCES `transactions` (`id`) ON DELETE CASCADE,
        FOREIGN KEY (`menu_id`) REFERENCES `menus` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "Created table `transaction_items`.\n";

    // User Tokens
    $pdo->exec("CREATE TABLE `user_tokens` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `user_id` INT NOT NULL,
        `token` VARCHAR(255) NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `expires_at` TIMESTAMP NOT NULL,
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB;");
    echo "Created table `user_tokens`.\n";

    // Verification Codes
    $pdo->exec("CREATE TABLE `verification_codes` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `code` VARCHAR(20) UNIQUE NOT NULL,
        `is_used` BOOLEAN DEFAULT FALSE NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;");
    echo "Created table `verification_codes`.\n";

    // 6. Seed Data
    $passwordHash = password_hash('password123', PASSWORD_BCRYPT);

    // Seed Super Admin
    $stmt = $pdo->prepare("INSERT INTO `users` (`name`, `email`, `password`, `role`) VALUES (?, ?, ?, ?)");
    $stmt->execute(['Super Admin', 'admin@pos.com', $passwordHash, 'super_admin']);
    echo "Seeded Super Admin (admin@pos.com)\n";

    // Seed Owner
    $stmt->execute(['Budi Owner', 'owner@pos.com', $passwordHash, 'owner']);
    $ownerId = $pdo->lastInsertId();
    echo "Seeded Owner Budi (owner@pos.com) ID: $ownerId\n";

    // Seed Store for Owner Budi
    $stmtStore = $pdo->prepare("INSERT INTO `stores` (`owner_id`, `name`, `address`) VALUES (?, ?, ?)");
    $stmtStore->execute([$ownerId, 'Toko Budi Sejahtera', 'Jl. Merdeka No. 123']);
    $storeId = $pdo->lastInsertId();
    echo "Seeded Store Toko Budi Sejahtera ID: $storeId\n";

    // Seed Kasir assigned to that store
    $stmtKasir = $pdo->prepare("INSERT INTO `users` (`name`, `email`, `password`, `role`, `store_id`, `tenant_id`) VALUES (?, ?, ?, ?, ?, ?)");
    $stmtKasir->execute(['Siti Kasir', 'kasir@pos.com', $passwordHash, 'kasir', $storeId, $ownerId]);
    echo "Seeded Kasir Siti (kasir@pos.com) assigned to Store ID: $storeId\n";

    // Seed initial Menus
    $stmtMenu = $pdo->prepare("INSERT INTO `menus` (`store_id`, `name`, `price`, `category`) VALUES (?, ?, ?, ?)");
    $stmtMenu->execute([$storeId, 'Nasi Goreng Spesial', 25000.00, 'Makanan']);
    $stmtMenu->execute([$storeId, 'Es Teh Manis', 5000.00, 'Minuman']);
    $stmtMenu->execute([$storeId, 'Ayam Bakar Taliwang', 35000.00, 'Makanan']);
    $stmtMenu->execute([$storeId, 'Kopi Susu Aren', 18000.00, 'Minuman']);
    echo "Seeded 4 default menus.\n";

    echo "\nDatabase initialized and seeded successfully!\n";

} catch (PDOException $e) {
    echo "Initialization Failed: " . $e->getMessage() . "\n";
    exit(1);
}
