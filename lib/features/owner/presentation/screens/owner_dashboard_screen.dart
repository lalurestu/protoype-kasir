// lib/features/owner/presentation/screens/owner_dashboard_screen.dart
// UPDATED: Added stock alert, customers stat, manage stock & customers action cards

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final ownerDashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/owner/dashboard-stats');
  return response.data;
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(ownerDashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Pemilik', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ownerDashboardStatsProvider),
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
            Text('Ringkasan Bisnis', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 8),
            const Text('Hari ini', style: TextStyle(color: AppTheme.textSecondary)),
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
                                  'Rp ${totalSales.toStringAsFixed(0)}',
                                  Icons.trending_up, AppTheme.secondaryColor)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard(context, 'Pesanan',
                                  '$totalOrders', Icons.receipt_long, AppTheme.accentColor)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard(context, 'Total Menu',
                                  '$totalMenus', Icons.restaurant_menu, AppTheme.primaryColor)),
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
                            childAspectRatio: 1.4,
                            children: [
                              _buildStatCard(context, 'Penjualan',
                                  'Rp ${totalSales.toStringAsFixed(0)}',
                                  Icons.trending_up, AppTheme.secondaryColor),
                              _buildStatCard(context, 'Pesanan',
                                  '$totalOrders', Icons.receipt_long, AppTheme.accentColor),
                              _buildStatCard(context, 'Total Menu',
                                  '$totalMenus', Icons.restaurant_menu, AppTheme.primaryColor),
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
}
