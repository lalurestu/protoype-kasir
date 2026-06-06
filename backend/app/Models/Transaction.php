<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Models\Scopes\TenantScope;

class Transaction extends Model
{
    protected $fillable = ['store_id', 'kasir_id', 'total_amount'];

    protected static function booted(): void
    {
        static::addGlobalScope(new TenantScope);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function kasir(): BelongsTo
    {
        return $this->belongsTo(User::class, 'kasir_id');
    }
}
