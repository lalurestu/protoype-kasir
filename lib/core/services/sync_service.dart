// lib/core/services/sync_service.dart
// Mengelola sinkronisasi data antara SQLite lokal dengan server pusat.
// Memastikan tidak ada data transaksi yang hilang saat offline.
//
// ATURAN OFFLINE-FIRST:
// 1. Setiap transaksi HARUS disimpan ke LocalDatabaseService terlebih dahulu
// 2. Coba kirim ke server (jika berhasil, tandai is_synced = 1)
// 3. Jika gagal (offline), data tetap aman di SQLite — kirim saat online kembali
// 4. SyncService bisa dipanggil manual (dari tombol dashboard) atau otomatis

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_database_service.dart';
import '../network/api_client.dart';

// ═══════════════════════════════════════════════════════════════
// STATE MODEL
// ═══════════════════════════════════════════════════════════════

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final int syncedCount;
  final String? errorMessage;
  final DateTime? lastSyncAt;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.errorMessage,
    this.lastSyncAt,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    int? syncedCount,
    String? errorMessage,
    DateTime? lastSyncAt,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  bool get isSyncing => status == SyncStatus.syncing;
  bool get hasError => status == SyncStatus.error;
  bool get hasPending => pendingCount > 0;
}

// ═══════════════════════════════════════════════════════════════
// NOTIFIER
// ═══════════════════════════════════════════════════════════════

class SyncNotifier extends StateNotifier<SyncState> {
  final LocalDatabaseService _localDb;
  final Dio _dio;

  SyncNotifier(this._localDb, this._dio) : super(const SyncState()) {
    _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final count = await _localDb.countPendingTransactions();
    state = state.copyWith(pendingCount: count);
  }

  /// Sinkronisasi semua transaksi pending ke server.
  /// Panggil dari tombol "Sinkronisasi Offline" di dashboard.
  Future<SyncResult> syncPendingTransactions() async {
    if (state.isSyncing) {
      return SyncResult(success: false, message: 'Sinkronisasi sedang berjalan.');
    }

    state = state.copyWith(status: SyncStatus.syncing);

    final pendingList = await _localDb.getPendingTransactions();

    if (pendingList.isEmpty) {
      state = state.copyWith(
        status: SyncStatus.success,
        pendingCount: 0,
        syncedCount: 0,
        lastSyncAt: DateTime.now(),
      );
      return SyncResult(success: true, message: 'Tidak ada data offline yang perlu disinkronisasi.', syncedCount: 0);
    }

    int syncedCount = 0;
    int failedCount = 0;
    String? lastError;

    for (final tx in pendingList) {
      final localId = tx['local_id'] as String;
      try {
        // Kirim transaksi ke server
        final response = await _dio.post(
          '/transactions',
          data: {
            'shift_id': tx['shift_id'],
            'store_id': tx['store_id'],
            'total_amount': tx['total_amount'],
            'subtotal_amount': tx['subtotal_amount'] ?? 0,
            'discount_amount': tx['discount_amount'] ?? 0,
            'tax_amount': tx['tax_amount'] ?? 0,
            'tax_percent': tx['tax_percent'] ?? 0,
            'payment_method': tx['payment_method'],
            'customer_id': tx['customer_id'],
            'customer_note': tx['customer_note'],
            'table_number': tx['table_number'],
            'items': tx['items'],
            'offline_local_id': localId,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _localDb.markTransactionSynced(localId);
          syncedCount++;
        }
      } on DioException catch (e) {
        final errMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
        await _localDb.markTransactionSyncError(localId, errMsg);
        failedCount++;
        lastError = errMsg;
      } catch (e) {
        await _localDb.markTransactionSyncError(localId, e.toString());
        failedCount++;
        lastError = e.toString();
      }
    }

    // Bersihkan yang sudah tersinkron
    if (syncedCount > 0) {
      await _localDb.clearSyncedTransactions();
    }

    // Log hasil sinkronisasi
    await _localDb.logSync(
      syncType: 'transactions',
      status: failedCount == 0 ? 'success' : 'partial',
      recordsSynced: syncedCount,
      errorMessage: lastError,
    );

    final remainingCount = await _localDb.countPendingTransactions();
    final isSuccess = failedCount == 0;

    state = state.copyWith(
      status: isSuccess ? SyncStatus.success : SyncStatus.error,
      pendingCount: remainingCount,
      syncedCount: syncedCount,
      errorMessage: isSuccess ? null : 'Gagal sync $failedCount transaksi. $lastError',
      lastSyncAt: DateTime.now(),
    );

    if (isSuccess) {
      return SyncResult(
        success: true,
        message: '✅ Berhasil menyinkronkan $syncedCount transaksi ke server!',
        syncedCount: syncedCount,
      );
    } else {
      return SyncResult(
        success: false,
        message: syncedCount > 0
            ? '⚠️ $syncedCount berhasil, $failedCount gagal. Coba lagi nanti.'
            : '❌ Semua transaksi gagal disinkronkan. Periksa koneksi internet.',
        syncedCount: syncedCount,
        failedCount: failedCount,
      );
    }
  }

  /// Sinkronisasi menu dari server ke cache lokal.
  /// Panggil saat startup atau refresh manual.
  Future<void> syncMenusFromServer() async {
    try {
      final response = await _dio.get('/store/menus');
      if (response.statusCode == 200 && response.data is List) {
        final menus = (response.data as List)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
        await _localDb.cacheMenus(menus);
        await _localDb.logSync(
          syncType: 'menus',
          status: 'success',
          recordsSynced: menus.length,
        );
      }
    } catch (e) {
      // Gagal sync menu — mode offline pakai cache lama
      await _localDb.logSync(
        syncType: 'menus',
        status: 'error',
        errorMessage: e.toString(),
      );
    }
  }

  /// Refresh pending count (panggil setelah checkout)
  Future<void> refreshPendingCount() async {
    await _refreshPendingCount();
  }
}

// ═══════════════════════════════════════════════════════════════
// RESULT MODEL
// ═══════════════════════════════════════════════════════════════

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
  });
}

// ═══════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════

final syncServiceProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final dio = ref.watch(dioProvider);
  return SyncNotifier(localDb, dio);
});
