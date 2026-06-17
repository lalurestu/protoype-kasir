// lib/core/storage/local_database_service.dart
// SQLite-based local database untuk offline-first capability.
// Menyimpan transaksi, menu, dan shift secara lokal di perangkat.
// Data akan disinkronisasi ke server saat koneksi tersedia.
//
// ARSITEKTUR:
// - Semua transaksi HARUS disimpan ke sini terlebih dahulu sebelum ke server
// - SyncService.dart bertugas push data dari sini ke server
// - Gunakan provider: localDatabaseServiceProvider

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService._instance;
});

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  LocalDatabaseService._internal();

  static Database? _database;

  static const String _dbName = 'pos_local.db';
  static const int _dbVersion = 1;

  // Table names
  static const String tablePendingTransactions = 'pending_transactions';
  static const String tableLocalMenus = 'local_menus';
  static const String tableSyncLog = 'sync_log';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel untuk transaksi yang belum tersinkronisasi
    await db.execute('''
      CREATE TABLE $tablePendingTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        shift_id INTEGER,
        store_id INTEGER,
        total_amount REAL NOT NULL,
        subtotal_amount REAL DEFAULT 0,
        discount_amount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        tax_percent REAL DEFAULT 0,
        payment_method TEXT NOT NULL,
        customer_id INTEGER,
        customer_note TEXT,
        table_number TEXT,
        items TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_error TEXT
      )
    ''');

    // Tabel untuk cache menu lokal (untuk mode offline)
    await db.execute('''
      CREATE TABLE $tableLocalMenus (
        id INTEGER PRIMARY KEY,
        store_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT NOT NULL,
        is_available INTEGER DEFAULT 1,
        description TEXT,
        stock INTEGER,
        min_stock INTEGER DEFAULT 5,
        variants TEXT,
        addons TEXT,
        cached_at TEXT NOT NULL
      )
    ''');

    // Tabel log sinkronisasi
    await db.execute('''
      CREATE TABLE $tableSyncLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_type TEXT NOT NULL,
        status TEXT NOT NULL,
        records_synced INTEGER DEFAULT 0,
        error_message TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations here
  }

  // ═══════════════════════════════════════════════════════════════
  // PENDING TRANSACTIONS — Offline transaksi queue
  // ═══════════════════════════════════════════════════════════════

  /// Simpan transaksi offline. Selalu panggil ini saat checkout,
  /// baik ada internet maupun tidak.
  Future<int> savePendingTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    final data = Map<String, dynamic>.from(transaction);

    // Serialize items list to JSON string
    if (data['items'] is List) {
      data['items'] = jsonEncode(data['items']);
    }

    // Generate local_id jika belum ada
    data['local_id'] ??= 'local_${DateTime.now().millisecondsSinceEpoch}';
    data['created_at'] ??= DateTime.now().toIso8601String();
    data['is_synced'] = 0;

    return await db.insert(
      tablePendingTransactions,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil semua transaksi yang belum tersinkronisasi
  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    final db = await database;
    final rows = await db.query(
      tablePendingTransactions,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    return rows.map((row) {
      final mutable = Map<String, dynamic>.from(row);
      if (mutable['items'] is String) {
        try {
          mutable['items'] = jsonDecode(mutable['items'] as String);
        } catch (_) {
          mutable['items'] = [];
        }
      }
      return mutable;
    }).toList();
  }

  /// Ambil semua transaksi (untuk laporan harian offline)
  Future<List<Map<String, dynamic>>> getAllTransactions({String? date}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (date != null) {
      where = 'created_at LIKE ?';
      whereArgs = ['$date%'];
    }

    final rows = await db.query(
      tablePendingTransactions,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return rows.map((row) {
      final mutable = Map<String, dynamic>.from(row);
      if (mutable['items'] is String) {
        try {
          mutable['items'] = jsonDecode(mutable['items'] as String);
        } catch (_) {
          mutable['items'] = [];
        }
      }
      return mutable;
    }).toList();
  }

  /// Tandai transaksi sebagai sudah tersinkronisasi
  Future<void> markTransactionSynced(String localId) async {
    final db = await database;
    await db.update(
      tablePendingTransactions,
      {'is_synced': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Tandai error sinkronisasi pada transaksi
  Future<void> markTransactionSyncError(String localId, String error) async {
    final db = await database;
    await db.update(
      tablePendingTransactions,
      {'sync_error': error},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Hapus semua transaksi yang sudah tersinkronisasi
  Future<int> clearSyncedTransactions() async {
    final db = await database;
    return await db.delete(
      tablePendingTransactions,
      where: 'is_synced = ?',
      whereArgs: [1],
    );
  }

  /// Hitung jumlah transaksi pending (untuk badge di dashboard)
  Future<int> countPendingTransactions() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tablePendingTransactions WHERE is_synced = 0',
    );
    return result.first['count'] as int? ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════
  // LOCAL MENUS — Cache menu untuk mode offline
  // ═══════════════════════════════════════════════════════════════

  /// Simpan daftar menu ke cache lokal
  Future<void> cacheMenus(List<Map<String, dynamic>> menus) async {
    final db = await database;
    final batch = db.batch();

    // Clear old cache
    batch.delete(tableLocalMenus);

    // Insert new cache
    final now = DateTime.now().toIso8601String();
    for (final menu in menus) {
      final data = Map<String, dynamic>.from(menu);
      data['cached_at'] = now;
      if (data['variants'] is List) {
        data['variants'] = jsonEncode(data['variants']);
      }
      if (data['addons'] is List) {
        data['addons'] = jsonEncode(data['addons']);
      }
      if (data['is_available'] is bool) {
        data['is_available'] = (data['is_available'] as bool) ? 1 : 0;
      }
      batch.insert(tableLocalMenus, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Ambil menu dari cache lokal
  Future<List<Map<String, dynamic>>> getCachedMenus() async {
    final db = await database;
    final rows = await db.query(tableLocalMenus, orderBy: 'category, name');

    return rows.map((row) {
      final mutable = Map<String, dynamic>.from(row);
      try {
        if (mutable['variants'] is String && (mutable['variants'] as String).isNotEmpty) {
          mutable['variants'] = jsonDecode(mutable['variants'] as String);
        } else {
          mutable['variants'] = [];
        }
        if (mutable['addons'] is String && (mutable['addons'] as String).isNotEmpty) {
          mutable['addons'] = jsonDecode(mutable['addons'] as String);
        } else {
          mutable['addons'] = [];
        }
      } catch (_) {
        mutable['variants'] = [];
        mutable['addons'] = [];
      }
      mutable['is_available'] = (mutable['is_available'] as int? ?? 1) == 1;
      return mutable;
    }).toList();
  }

  /// Cek apakah ada cache menu (untuk memutuskan apakah bisa mode offline)
  Future<bool> hasMenuCache() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableLocalMenus');
    return (result.first['count'] as int? ?? 0) > 0;
  }

  // ═══════════════════════════════════════════════════════════════
  // SYNC LOG
  // ═══════════════════════════════════════════════════════════════

  Future<void> logSync({
    required String syncType,
    required String status,
    int recordsSynced = 0,
    String? errorMessage,
  }) async {
    final db = await database;
    await db.insert(tableSyncLog, {
      'sync_type': syncType,
      'status': status,
      'records_synced': recordsSynced,
      'error_message': errorMessage,
      'synced_at': DateTime.now().toIso8601String(),
    });
  }

  /// Tutup database saat tidak digunakan
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
