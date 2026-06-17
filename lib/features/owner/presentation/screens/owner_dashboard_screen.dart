// lib/features/owner/presentation/screens/owner_dashboard_screen.dart
// UPDATED: Stock alert, customers stat, analytics charts, CurrencyFormatter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../core/services/excel_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final ownerDashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/owner/dashboard-stats');
  return response.data;
});

final ownerAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/owner/analytics');
  return response.data;
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  void _showExportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text('Pilih Periode Laporan Excel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.today, color: AppTheme.primaryColor),
                title: const Text('Harian (Hari Ini)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _processExport(context, ref, 'harian');
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_week, color: AppTheme.primaryColor),
                title: const Text('Mingguan (7 Hari)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _processExport(context, ref, 'mingguan');
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: AppTheme.primaryColor),
                title: const Text('Bulanan (30 Hari)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _processExport(context, ref, 'bulanan');
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                title: const Text('Tahunan (1 Tahun)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _processExport(context, ref, 'tahunan');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processExport(BuildContext context, WidgetRef ref, String period) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyiapkan data Excel...')));
      final dio = ref.read(dioProvider);
      final response = await dio.get('/owner/export-data', queryParameters: {'period': period});
      
      final reportData = response.data;
      
      final filePath = await ExcelService.generateOwnerReport(reportData);
      if (context.mounted) {
        if (filePath != null) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Excel Berhasil Dibuat!'),
              content: const Text('Laporan Excel siap dibuka.\nAnda dapat menyimpannya dari aplikasi Excel.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    OpenFilex.open(filePath);
                  },
                  child: const Text('Buka Excel'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan Excel berhasil diunduh!')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat Excel: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(ownerDashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Pemilik', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
            tooltip: 'Export Laporan',
            onPressed: () async {
              try {
                final stats = await ref.read(ownerDashboardStatsProvider.future);
                final analytics = await ref.read(ownerAnalyticsProvider.future);
                
                final reportData = {
                  'total_revenue': stats['total_sales_today'] ?? 0,
                  'total_transactions': stats['total_orders_today'] ?? 0,
                  'total_customers': stats['total_customers'] ?? 0,
                  'daily_sales': analytics['daily_sales'] ?? [],
                  'top_menus': analytics['top_menus'] ?? [],
                };
                
                await PdfService.generateOwnerReport(reportData);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan PDF siap untuk di-print/disimpan!')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_view, color: Colors.green),
            tooltip: 'Export Excel',
            onPressed: () => _showExportOptions(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(ownerDashboardStatsProvider);
              ref.invalidate(ownerAnalyticsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.error),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: ListView(
          padding: const EdgeInsets.all(28.0),
          children: [
            // Premium greeting header
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard Pemilik', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 22)),
                    const Text('Ringkasan bisnis hari ini', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            statsAsync.when(
              data: (stats) {
                final double totalSales = (stats['total_sales_today'] as num?)?.toDouble() ?? 0.0;
                final totalOrders = stats['total_orders_today'] ?? 0;
                final totalMenus = stats['total_menus'] ?? 0;
                final lowStockCount = stats['low_stock_count'] ?? 0;
                final totalCustomers = stats['total_customers'] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Low stock alert
                    if (lowStockCount > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$lowStockCount item stok menipis! Segera cek manajemen stok.',
                                style: const TextStyle(
                                    color: Colors.orange, fontWeight: FontWeight.w500),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.goNamed(RouteNames.manageStock),
                              child: const Text('Lihat',
                                  style: TextStyle(color: Colors.orange)),
                            ),
                          ],
                        ),
                      ),

                    // Stat cards - responsive layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 700) {
                          return Row(
                            children: [
                              Expanded(child: _buildStatCard(context, 'Penjualan Hari Ini',
                                  CurrencyFormatter.format(totalSales),
                                  Icons.trending_up, AppTheme.secondaryColor)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard(context, 'Pesanan',
                                  '$totalOrders txn', Icons.receipt_long, AppTheme.accentColor)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard(context, 'Total Menu',
                                  '$totalMenus item', Icons.restaurant_menu, AppTheme.primaryColor)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard(context, 'Pelanggan',
                                  '$totalCustomers', Icons.people, Colors.purple)),
                            ],
                          );
                        } else {
                          return GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.35,
                            children: [
                              _buildStatCard(context, 'Penjualan',
                                  CurrencyFormatter.formatCompact(totalSales),
                                  Icons.trending_up, AppTheme.secondaryColor),
                              _buildStatCard(context, 'Pesanan',
                                  '$totalOrders txn', Icons.receipt_long, AppTheme.accentColor),
                              _buildStatCard(context, 'Total Menu',
                                  '$totalMenus item', Icons.restaurant_menu, AppTheme.primaryColor),
                              _buildStatCard(context, 'Pelanggan',
                                  '$totalCustomers', Icons.people, Colors.purple),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) =>
                  Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
            ),
            const SizedBox(height: 32),
            
            // Analytics Charts
            _buildAnalyticsCharts(ref),
            
            const SizedBox(height: 40),
            Text('Aksi Cepat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: _buildActionCards(context),
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildActionCards(context)
                        .map((card) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: card,
                            ))
                        .toList(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionCards(BuildContext context) {
    return [
      _buildActionCard(context, 'Kelola Menu', 'Tambah, ubah, hapus produk',
          Icons.fastfood, () => context.goNamed(RouteNames.manageMenu)),
      _buildActionCard(context, 'Kelola Stok', 'Pantau & update inventaris',
          Icons.inventory_2, () => context.goNamed(RouteNames.manageStock),
          accentColor: Colors.teal),
      _buildActionCard(context, 'Kelola Kasir', 'Tambah dan pantau akun kasir',
          Icons.people, () => context.goNamed(RouteNames.manageKasir)),
      _buildActionCard(context, 'Data Pelanggan', 'Lihat member & program poin',
          Icons.card_membership, () => context.goNamed(RouteNames.manageCustomers),
          accentColor: Colors.purple),
      _buildActionCard(context, 'Lihat Laporan', 'Cek detail riwayat transaksi',
          Icons.bar_chart, () => context.goNamed(RouteNames.ownerReport)),
      _buildActionCard(context, 'Riwayat Shift', 'Lihat rekap shift kasir',
          Icons.schedule, () => context.goNamed(RouteNames.ownerShifts),
          accentColor: Colors.indigo),
    ];
  }

  Widget _buildStatCard(
      BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      color: AppTheme.surfaceDark.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration:
                  BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    Color accentColor = AppTheme.primaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border.all(color: const Color(0xFF334155)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(color: accentColor.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCharts(WidgetRef ref) {
    final analyticsAsync = ref.watch(ownerAnalyticsProvider);

    return analyticsAsync.when(
      data: (data) {
        final dailySales = (data['daily_sales'] as List?) ?? [];
        final topMenus = (data['top_menus'] as List?) ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tren Penjualan (7 Hari)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.only(right: 24, left: 16, top: 24, bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: _buildLineChart(dailySales),
            ),
            const SizedBox(height: 32),
            Text('Menu Terlaris', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: _buildPieChart(topMenus),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildLineChart(List<dynamic> data) {
    if (data.isEmpty) return const Center(child: Text('Belum ada data penjualan', style: TextStyle(color: AppTheme.textSecondary)));

    double maxY = 0;
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final total = double.tryParse(data[i]['total']?.toString() ?? '0') ?? 0.0;
      if (total > maxY) maxY = total;
      spots.add(FlSpot(i.toDouble(), total));
    }
    
    // Add 10% padding to maxY
    maxY = maxY > 0 ? maxY * 1.1 : 100000;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final int idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox();
                final dateStr = data[idx]['date'] as String;
                final dateParts = dateStr.split('-');
                final label = dateParts.length == 3 ? '${dateParts[2]}/${dateParts[1]}' : '';
                return SideTitleWidget(
                  meta: meta,
                  child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY / 4,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text('${(value/1000).toStringAsFixed(0)}k', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.secondaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.secondaryColor.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<dynamic> data) {
    if (data.isEmpty) return const Center(child: Text('Belum ada data menu terlaris', style: TextStyle(color: AppTheme.textSecondary)));

    final colors = [
      AppTheme.secondaryColor,
      AppTheme.primaryColor,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    int totalSold = data.fold(0, (sum, item) => sum + (int.tryParse(item['sold']?.toString() ?? '0') ?? 0));

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(enabled: false),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(data.length, (i) {
                final sold = int.tryParse(data[i]['sold']?.toString() ?? '0') ?? 0;
                final double percentage = totalSold > 0 ? (sold / totalSold) * 100 : 0;
                return PieChartSectionData(
                  color: colors[i % colors.length],
                  value: sold.toDouble(),
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(data.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('${data[i]['name']} (${data[i]['sold']})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

