<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\MenuController;
use App\Http\Controllers\TransactionController;

Route::group(['prefix' => 'auth'], function () {
    Route::post('register-owner', [AuthController::class, 'registerOwner']);
    Route::post('login', [AuthController::class, 'login']);
    Route::post('logout', [AuthController::class, 'logout'])->middleware('auth:api');
    Route::get('me', [AuthController::class, 'me'])->middleware('auth:api');
});

Route::group(['middleware' => ['auth:api', 'role:owner']], function () {
    Route::apiResource('menus', MenuController::class);
    Route::get('owner/reports', [TransactionController::class, 'reports']);
});

Route::group(['middleware' => ['auth:api', 'role:kasir']], function () {
    Route::post('checkout', [TransactionController::class, 'checkout']);
});

Route::group(['middleware' => ['auth:api']], function () {
    // Both Kasir and Owner can view menus
    Route::get('store/menus', [MenuController::class, 'index']);
});
