<?php

namespace App\Http\Controllers;

use App\Models\Menu;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class MenuController extends Controller
{
    public function index()
    {
        // Global scope ensures only menus for their tenant are returned
        return response()->json(Menu::all());
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string',
            'price' => 'required|numeric',
            'category' => 'required|string',
        ]);

        $menu = Menu::create([
            'store_id' => Auth::user()->stores()->first()->id ?? 1, // Naive implementation for demo
            'name' => $request->name,
            'price' => $request->price,
            'category' => $request->category,
        ]);

        return response()->json($menu, 201);
    }
}
