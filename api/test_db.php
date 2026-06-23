<?php
// Tampilkan semua error untuk mempermudah debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config.php';

echo "Mencoba koneksi ke database...\n";

try {
    // Memanggil fungsi dari config.php
    $db = getDBConnection();
    echo "✅ Berhasil terhubung ke database!\n\n";

    // Coba ambil daftar tabel untuk membuktikan schema.sql sudah tereksekusi
    echo "Daftar Tabel di Database:\n";
    echo "--------------------------\n";
    $stmt = $db->query("SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public'");
    $tables = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (count($tables) > 0) {
        foreach ($tables as $table) {
            echo "- " . $table['tablename'] . "\n";
        }
    } else {
        echo "Belum ada tabel di dalam schema public.\n";
    }

} catch (Exception $e) {
    echo "❌ Gagal terhubung ke database!\n";
    echo "Error: " . $e->getMessage() . "\n";
}
?>
