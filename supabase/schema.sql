-- Supabase PostgreSQL Schema Migration untuk Aplikasi Kasir
-- Terjemahan dari MySQL db_init.php dan db_migrate.php

-- Enable UUID extension just in case (standard for Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Tabel users
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) CHECK (role IN ('super_admin', 'owner', 'kasir')) NOT NULL,
    store_id INT NULL,
    tenant_id INT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    suspended_at TIMESTAMP NULL,
    suspended_reason TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabel stores
CREATE TABLE stores (
    id SERIAL PRIMARY KEY,
    owner_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    logo VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Tabel menus
CREATE TABLE menus (
    id SERIAL PRIMARY KEY,
    store_id INT NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    category VARCHAR(255) NOT NULL,
    image_url VARCHAR(255) NULL,
    is_available BOOLEAN DEFAULT TRUE NOT NULL,
    description TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Tabel customers
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    store_id INT NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) NULL,
    points INT DEFAULT 0 NOT NULL,
    total_spend DECIMAL(15, 2) DEFAULT 0 NOT NULL,
    visit_count INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Tabel shifts
CREATE TABLE shifts (
    id SERIAL PRIMARY KEY,
    kasir_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    store_id INT NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    opening_cash DECIMAL(15, 2) NOT NULL DEFAULT 0,
    closing_cash DECIMAL(15, 2) NULL,
    total_sales DECIMAL(15, 2) DEFAULT 0 NOT NULL,
    total_transactions INT DEFAULT 0 NOT NULL,
    note TEXT NULL,
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP NULL,
    status VARCHAR(50) CHECK (status IN ('open', 'closed')) DEFAULT 'open' NOT NULL
);

-- 6. Tabel transactions
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    store_id INT NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    kasir_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    customer_id INT NULL REFERENCES customers(id) ON DELETE SET NULL,
    shift_id INT NULL REFERENCES shifts(id) ON DELETE SET NULL,
    total_amount DECIMAL(15, 2) NOT NULL,
    subtotal_amount DECIMAL(15, 2) DEFAULT 0 NOT NULL,
    payment_method VARCHAR(50) CHECK (payment_method IN ('cash', 'qris')) DEFAULT 'cash' NOT NULL,
    discount_amount DECIMAL(15, 2) DEFAULT 0 NOT NULL,
    discount_type VARCHAR(50) CHECK (discount_type IN ('percent', 'nominal')) DEFAULT 'nominal',
    tax_amount DECIMAL(15, 2) DEFAULT 0 NOT NULL,
    tax_percent DECIMAL(5, 2) DEFAULT 0 NOT NULL,
    customer_note TEXT NULL,
    table_number VARCHAR(20) NULL,
    status VARCHAR(50) CHECK (status IN ('completed', 'saved', 'cancelled')) DEFAULT 'completed' NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. Tabel transaction_items
CREATE TABLE transaction_items (
    id SERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    menu_id INT NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
    quantity INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    variant_id INT NULL,
    variant_name VARCHAR(100) NULL,
    addons_info TEXT NULL
);

-- 8. Tabel user_tokens
CREATE TABLE user_tokens (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL
);

-- 9. Tabel verification_codes
CREATE TABLE verification_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    is_used BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. Tabel stock
CREATE TABLE stock (
    id SERIAL PRIMARY KEY,
    menu_id INT NOT NULL UNIQUE REFERENCES menus(id) ON DELETE CASCADE,
    quantity INT DEFAULT 0 NOT NULL,
    min_stock INT DEFAULT 5 NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 11. Tabel menu_variants
CREATE TABLE menu_variants (
    id SERIAL PRIMARY KEY,
    menu_id INT NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

-- 12. Tabel menu_addons
CREATE TABLE menu_addons (
    id SERIAL PRIMARY KEY,
    menu_id INT NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

-- 13. Tabel password_reset_requests
CREATE TABLE password_reset_requests (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    reason TEXT NULL,
    status VARCHAR(50) CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending' NOT NULL,
    temp_password VARCHAR(255) NULL,
    temp_password_plain VARCHAR(100) NULL,
    admin_note TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL
);

-- Trigger Function for updated_at
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
CREATE TRIGGER set_timestamp_users BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();
CREATE TRIGGER set_timestamp_stores BEFORE UPDATE ON stores FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();
CREATE TRIGGER set_timestamp_menus BEFORE UPDATE ON menus FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();
CREATE TRIGGER set_timestamp_customers BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();
CREATE TRIGGER set_timestamp_transactions BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();
CREATE TRIGGER set_timestamp_stock BEFORE UPDATE ON stock FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

-- RLS (Row Level Security) Configuration (Opsional - Jika ingin digunakan via Supabase SDK Langsung)
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- (Tambahkan policies di sini jika diperlukan)
