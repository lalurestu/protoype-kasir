<?php
require 'api/config.php';
$pdo = getDBConnection();
try {
    $pdo->exec("ALTER TABLE password_reset_requests ADD COLUMN email VARCHAR(255) NOT NULL AFTER user_id");
    echo "Column 'email' added successfully.";
} catch (PDOException $e) {
    if (strpos($e->getMessage(), 'Duplicate column name') !== false) {
        echo "Column 'email' already exists.";
    } else {
        echo "Error: " . $e->getMessage();
    }
}
