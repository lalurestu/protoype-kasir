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
          padding: const EdgeInsets.all(32.0),
          children: [
            Text('Ringkasan Bisnis', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 32),
            statsAsync.when(
              data: (stats) {
                final totalSales = stats['total_sales_today'] ?? 0.0;
                final totalOrders = stats['total_orders_today'] ?? 0;
                final totalMenus = stats['total_menus'] ?? 0;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return Row(
                        children: [
                          Expanded(child: _buildStatCard(context, 'Penjualan Hari Ini', 'Rp $totalSales', Icons.trending_up, AppTheme.secondaryColor)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildStatCard(context, 'Pesanan Hari Ini', '$totalOrders', Icons.receipt_long, AppTheme.accentColor)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildStatCard(context, 'Total Menu', '$totalMenus', Icons.restaurant_menu, AppTheme.primaryColor)),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatCard(context, 'Penjualan Hari Ini', 'Rp $totalSales', Icons.trending_up, AppTheme.secondaryColor),
                          const SizedBox(height: 16),
                          _buildStatCard(context, 'Pesanan Hari Ini', '$totalOrders', Icons.receipt_long, AppTheme.accentColor),
                          const SizedBox(height: 16),
                          _buildStatCard(context, 'Total Menu', '$totalMenus', Icons.restaurant_menu, AppTheme.primaryColor),
                        ],
                      );
                    }
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
            ),
            const SizedBox(height: 48),
            Text('Aksi Cepat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          'Kelola Menu',
                          'Tambah, ubah, atau hapus produk',
                          Icons.fastfood,
                          () => context.goNamed(RouteNames.manageMenu),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          'Kelola Kasir',
                          'Tambah dan pantau akun kasir',
                          Icons.people,
                          () => context.goNamed(RouteNames.manageKasir),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          'Lihat Laporan',
                          'Cek detail riwayat transaksi',
                          Icons.bar_chart,
                          () => context.goNamed(RouteNames.ownerReport),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildActionCard(
                        context,
                        'Kelola Menu',
                        'Tambah, ubah, atau hapus produk',
                        Icons.fastfood,
                        () => context.goNamed(RouteNames.manageMenu),
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        context,
                        'Kelola Kasir',
                        'Tambah dan pantau akun kasir',
                        Icons.people,
                        () => context.goNamed(RouteNames.manageKasir),
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        context,
                        'Lihat Laporan',
                        'Cek detail riwayat transaksi',
                        Icons.bar_chart,
                        () => context.goNamed(RouteNames.ownerReport),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      color: AppTheme.surfaceDark.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 28),
                ),
                const Spacer(),
                const Icon(Icons.more_horiz, color: AppTheme.textSecondary),
              ],
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border.all(color: const Color(0xFF334155)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
