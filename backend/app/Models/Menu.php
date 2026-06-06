<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Models\Scopes\TenantScope;

class Menu extends Model
{
    protected $fillable = ['store_id', 'name', 'price', 'category', 'image_url'];

    protected static function booted(): void
    {
        static::addGlobalScope(new TenantScope);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}
