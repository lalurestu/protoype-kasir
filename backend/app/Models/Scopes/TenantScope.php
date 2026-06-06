<?php

namespace App\Models\Scopes;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Scope;
use Illuminate\Support\Facades\Auth;

class TenantScope implements Scope
{
    /**
     * Apply the scope to a given Eloquent query builder.
     */
    public function apply(Builder $builder, Model $model): void
    {
        if (Auth::check()) {
            $user = Auth::user();
            
            // Super Admin sees everything
            if ($user->role === 'super_admin') {
                return;
            }

            // Owner sees their stores
            if ($user->role === 'owner') {
                if ($model->getTable() === 'stores') {
                    $builder->where('owner_id', $user->id);
                } else {
                    $storeIds = $user->stores()->pluck('id');
                    $builder->whereIn('store_id', $storeIds);
                }
                return;
            }

            // Kasir sees only their assigned store
            if ($user->role === 'kasir' && $user->store_id) {
                if ($model->getTable() === 'stores') {
                    $builder->where('id', $user->store_id);
                } else {
                    $builder->where('store_id', $user->store_id);
                }
                return;
            }
        }
    }
}
