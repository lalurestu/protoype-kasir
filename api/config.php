<?php
// api/config.php

define('DB_HOST', '127.0.0.1');
define('DB_NAME', 'prototype_kasir');
define('DB_USER', 'root');
define('DB_PASS', '');

function getDBConnection() {
    try {
        $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4";
        $options = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ];
        return new PDO($dsn, DB_USER, DB_PASS, $options);
    } catch (\PDOException $e) {
        http_response_code(500);
        header('Content-Type: application/json');
        echo json_encode([
            "error" => "Database Connection Failed: " . $e->getMessage()
        ]);
        exit;
    }
}
