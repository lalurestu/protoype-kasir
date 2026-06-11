import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

final reportPeriodProvider = StateProvider<String>((ref) => 'daily');

final ownerReportProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final period = ref.watch(reportPeriodProvider);
  final response = await dio.get('/reports/owner', queryParameters: {'period': period});
  return response.data;
});

class OwnerReportScreen extends ConsumerWidget {
  const OwnerReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(ownerReportProvider);
    final selectedPeriod = ref.watch(reportPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter Laporan:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: selectedPeriod,
                  dropdownColor: AppTheme.surfaceDark,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Harian')),
                    DropdownMenuItem(value: 'monthly', child: Text('Bulanan')),
                    DropdownMenuItem(value: 'yearly', child: Text('Tahunan')),
                  ],
                  onChanged: (val) {
                    if (val != null) ref.read(reportPeriodProvider.notifier).state = val;
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: reportAsync.when(
              data: (reports) {
                if (reports.isEmpty) {
                  return const Center(child: Text('Tidak ada transaksi pada periode ini.', style: TextStyle(color: AppTheme.textSecondary)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final row = reports[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: AppTheme.surfaceDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Periode: ${row['period_date']}', style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                            const Divider(color: Colors.white24, height: 16),
                            
                            if (row['details'] != null && (row['details'] as List).isNotEmpty) ...[
                              Text(
                                selectedPeriod == 'daily' ? 'Rincian Pesanan:' : (selectedPeriod == 'monthly' ? 'Rincian Pendapatan Harian:' : 'Rincian Pendapatan Bulanan:'),
                                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)
                              ),
                              const SizedBox(height: 8),
                              ...((row['details'] as List).map((det) {
                                if (selectedPeriod == 'daily') {
                                  final itemsStr = (det['items'] as List?)?.map((i) => '${i['quantity']}x ${i['name']}').join(', ') ?? '';
                                  final time = det['created_at'] != null ? det['created_at'].toString().split(' ').last.substring(0, 5) : '';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(time, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(itemsStr.isEmpty ? 'Pesanan Custom' : itemsStr, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Rp ${det['total_amount']}', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                } else {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${det['sub_period_date']}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        Text('Rp ${det['sub_total_revenue']}', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                }
                              })),
                              const Divider(color: Colors.white24, height: 24),
                            ],

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Transaksi:', style: TextStyle(color: AppTheme.textSecondary)),
                                Text('${row['total_transactions']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Tunai:', style: TextStyle(color: AppTheme.textSecondary)),
                                Text('Rp ${row['total_cash']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total QRIS:', style: TextStyle(color: AppTheme.textSecondary)),
                                Text('Rp ${row['total_qris']}', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(selectedPeriod == 'daily' ? 'Total Pendapatan Hari Ini:' : (selectedPeriod == 'monthly' ? 'Total Pendapatan Bulan Ini:' : 'Total Pendapatan Tahun Ini:'), style: const TextStyle(color: Colors.white, fontSize: 16)),
                                Text('Rp ${row['total_revenue']}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
            ),
          ),
        ],
      ),
    );
  }
}
