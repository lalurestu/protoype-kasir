<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Store;
use App\Models\Menu;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // 1. Create Super Admin
        User::create([
            'name' => 'Super Admin',
            'email' => 'admin@pos.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
        ]);

        // 2. Create Owner
        $owner = User::create([
            'name' => 'Budi Owner',
            'email' => 'owner@pos.com',
            'password' => Hash::make('password123'),
            'role' => 'owner',
        ]);

        // 3. Create a Store for the Owner
        $store = Store::create([
            'owner_id' => $owner->id,
            'name' => 'Toko Budi Sejahtera',
            'address' => 'Jl. Merdeka No. 123',
        ]);

        // 4. Create Kasir assigned to that Store
        User::create([
            'name' => 'Siti Kasir',
            'email' => 'kasir@pos.com',
            'password' => Hash::make('password123'),
            'role' => 'kasir',
            'store_id' => $store->id,
            'tenant_id' => $owner->id,
        ]);

        // 5. Seed some initial Menus for the Store
        Menu::create(['store_id' => $store->id, 'name' => 'Nasi Goreng Spesial', 'price' => 25000, 'category' => 'Makanan']);
        Menu::create(['store_id' => $store->id, 'name' => 'Es Teh Manis', 'price' => 5000, 'category' => 'Minuman']);
        Menu::create(['store_id' => $store->id, 'name' => 'Ayam Bakar Taliwang', 'price' => 35000, 'category' => 'Makanan']);
        Menu::create(['store_id' => $store->id, 'name' => 'Kopi Susu Aren', 'price' => 18000, 'category' => 'Minuman']);
    }
}
