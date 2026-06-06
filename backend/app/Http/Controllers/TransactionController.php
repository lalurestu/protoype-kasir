<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class TransactionController extends Controller
{
    public function checkout(Request $request)
    {
        $request->validate([
            'total_amount' => 'required|numeric'
        ]);

        $transaction = Transaction::create([
            'store_id' => Auth::user()->store_id ?? 1,
            'kasir_id' => Auth::id(),
            'total_amount' => $request->total_amount,
        ]);

        return response()->json([
            'message' => 'Checkout successful',
            'transaction' => $transaction
        ], 201);
    }

    public function reports()
    {
        // Global scope ensures only transactions for this owner's stores are returned
        return response()->json(Transaction::with('kasir')->get());
    }
}
