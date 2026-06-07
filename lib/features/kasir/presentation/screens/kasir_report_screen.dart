import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/local_db_service.dart';

final kasirReportProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final localDb = ref.read(localDbProvider);
  
  Map<String, dynamic> serverData = {
    'total_transactions': 0,
    'total_revenue': 0.0,
    'total_cash': 0.0,
    'total_qris': 0.0,
    'recent_transactions': [],
  };

  try {
    final response = await dio.get('/reports/kasir');
    if (response.data != null && response.data is Map) {
      serverData = response.data;
    }
  } catch (e) {
    // Kalo error atau offline, tetep lanjut pake data server kosong + digabung data lokal
  }

  // Gabung sama transaksi offline yang belom sinkron
  final pendingList = localDb.getPendingTransactions();
  
  int localCount = 0;
  double localRev = 0.0;
  double localCash = 0.0;
  double localQris = 0.0;
  List<dynamic> localRecent = [];

  for (var tx in pendingList.reversed) {
    localCount++;
    final amount = (tx['total_amount'] as num).toDouble();
    localRev += amount;
    
    if (tx['payment_method'] == 'cash') {
      localCash += amount;
    } else {
      localQris += amount;
    }
    
    localRecent.add({
      'id': 'offline_$localCount',
      'total_amount': amount,
      'payment_method': tx['payment_method'],
      'created_at': tx['created_at'] ?? DateTime.now().toString(),
      'items': tx['items'] ?? [],
    });
  }

  return {
    'total_transactions': (serverData['total_transactions'] ?? 0) + localCount,
    'total_revenue': ((serverData['total_revenue'] ?? 0.0) as num).toDouble() + localRev,
    'total_cash': ((serverData['total_cash'] ?? 0.0) as num).toDouble() + localCash,
    'total_qris': ((serverData['total_qris'] ?? 0.0) as num).toDouble() + localQris,
    'recent_transactions': [
      ...localRecent,
      ...(serverData['recent_transactions'] as List<dynamic>? ?? [])
    ],
  };
});

class KasirReportScreen extends ConsumerWidget {
  const KasirReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(kasirReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Harian'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(kasirReportProvider),
          ),
        ],
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: reportAsync.when(
        data: (report) {
          final totalTransactions = report['total_transactions'] ?? 0;
          final totalRevenue = report['total_revenue'] ?? 0.0;
          final totalCash = report['total_cash'] ?? 0.0;
          final totalQris = report['total_qris'] ?? 0.0;

          final recentTransactions = report['recent_transactions'] as List<dynamic>? ?? [];

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Ringkasan Hari Ini', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              _buildStatCard('Total Pendapatan', 'Rp $totalRevenue', Icons.account_balance_wallet, AppTheme.secondaryColor),
              const SizedBox(height: 16),
              _buildStatCard('Total Transaksi', '$totalTransactions', Icons.receipt_long, Colors.blue),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildSmallStatCard('TUNAI', 'Rp $totalCash', Icons.money, Colors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSmallStatCard('QRIS', 'Rp $totalQris', Icons.qr_code, Colors.purple)),
                ],
              ),
              const SizedBox(height: 40),
              const Text('Transaksi Terakhir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              if (recentTransactions.isEmpty)
                const Center(child: Text('Belum ada transaksi hari ini.', style: TextStyle(color: AppTheme.textSecondary)))
              else
                ...recentTransactions.map((tx) {
                  final createdAt = tx['created_at'] as String;
                  final timeStr = createdAt.split(' ').last.substring(0, 5);
                  final items = tx['items'] as List<dynamic>? ?? [];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppTheme.surfaceDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(timeStr, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tx['payment_method'] == 'cash' ? Colors.green.withOpacity(0.2) : Colors.purple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (tx['payment_method'] as String).toUpperCase(),
                                  style: TextStyle(
                                    color: tx['payment_method'] == 'cash' ? Colors.green : Colors.purple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 24),
                          ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['quantity']}x', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(item['name'] ?? 'Menu Offline', style: const TextStyle(color: Colors.white))),
                                Text('Rp ${item['price']}', style: const TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          )),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text('Rp ${tx['total_amount']}', style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          String errorMsg = e.toString();
          if (e is DioException && e.response != null) {
            errorMsg = e.response?.data.toString() ?? e.message ?? errorMsg;
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Error: $errorMsg', 
                style: const TextStyle(color: AppTheme.error, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
          );
        },      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
