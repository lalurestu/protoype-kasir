-- Seed Data Awal untuk Supabase PostgreSQL
-- Gunakan SQL Editor di Supabase untuk menjalankan perintah ini setelah menjalankan schema.sql
-- Password untuk semua akun default di bawah ini adalah: password123

-- 1. Bersihkan data lama jika ada (opsional)
TRUNCATE TABLE user_tokens, transaction_items, transactions, stock, menu_addons, menu_variants, menus, stores, users RESTART IDENTITY CASCADE;

-- 2. Tambah Super Admin
INSERT INTO users (name, email, password, role) 
VALUES ('Super Admin', 'admin@pos.com', '$2y$10$v/j/YHriV4HWRRcP/4I0HesX00Mcp8fsKKRZ4j94mN8gTV0db.W4W', 'super_admin');

-- 3. Tambah Owner Toko (Budi Owner)
INSERT INTO users (name, email, password, role) 
VALUES ('Budi Owner', 'owner@pos.com', '$2y$10$v/j/YHriV4HWRRcP/4I0HesX00Mcp8fsKKRZ4j94mN8gTV0db.W4W', 'owner');

-- 4. Tambah Toko (Budi Sejahtera)
INSERT INTO stores (owner_id, name, address) 
VALUES (2, 'Toko Budi Sejahtera', 'Jl. Merdeka No. 123');

-- 5. Tambah Kasir (Siti Kasir) - Terhubung ke Toko ID 1 dan Owner ID 2
INSERT INTO users (name, email, password, role, store_id, tenant_id) 
VALUES ('Siti Kasir', 'kasir@pos.com', '$2y$10$v/j/YHriV4HWRRcP/4I0HesX00Mcp8fsKKRZ4j94mN8gTV0db.W4W', 'kasir', 1, 2);

-- 6. Tambah Menu Makanan & Minuman Awal
INSERT INTO menus (id, store_id, name, price, category, is_available) VALUES 
(1, 1, 'Nasi Goreng Spesial', 25000.00, 'Makanan', true),
(2, 1, 'Es Teh Manis', 5000.00, 'Minuman', true),
(3, 1, 'Ayam Bakar Taliwang', 35000.00, 'Makanan', true),
(4, 1, 'Kopi Susu Aren', 18000.00, 'Minuman', true);

-- Sesuaikan urutan sequence ID untuk tabel menus agar auto increment tidak bentrok
SELECT setval('menus_id_seq', (SELECT MAX(id) FROM menus));

-- 7. Tambah Stok Awal Menu
INSERT INTO stock (menu_id, quantity, min_stock) VALUES
(1, 50, 5),
(2, 100, 5),
(3, 30, 5),
(4, 80, 5);

-- 8. Tambah Kode Verifikasi Aktif (Untuk registrasi owner baru)
INSERT INTO verification_codes (code, is_used) 
VALUES ('KASIR-OK-2026', false);
