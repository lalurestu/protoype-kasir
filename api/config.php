<?php
// api/config.php

define('DB_CONNECTION', 'pgsql'); // Change to 'mysql' to revert to local MySQL
define('DB_HOST', '127.0.0.1');
define('DB_PORT', '5432'); // Default Postgres port
define('DB_NAME', 'postgres'); // Default Supabase DB name
define('DB_USER', 'postgres');
define('DB_PASS', 'your-super-secret-and-long-postgres-password');

function getDBConnection() {
    try {
        if (DB_CONNECTION === 'pgsql') {
            $dsn = "pgsql:host=" . DB_HOST . ";port=" . DB_PORT . ";dbname=" . DB_NAME;
        } else {
            $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4";
        }
        
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
