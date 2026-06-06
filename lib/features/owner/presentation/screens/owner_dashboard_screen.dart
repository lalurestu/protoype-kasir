import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
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
            Text('Business Overview', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 32),
            Row(
              children: [
                _buildStatCard(context, 'Total Sales Today', 'Rp 4.500.000', Icons.trending_up, AppTheme.secondaryColor),
                const SizedBox(width: 24),
                _buildStatCard(context, 'Active Orders', '12', Icons.receipt_long, AppTheme.accentColor),
                const SizedBox(width: 24),
                _buildStatCard(context, 'Total Menus', '34', Icons.restaurant_menu, AppTheme.primaryColor),
              ],
            ),
            const SizedBox(height: 48),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    'Manage Menus',
                    'Add, edit, or remove products',
                    Icons.fastfood,
                    () => context.goNamed(RouteNames.manageMenu),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildActionCard(
                    context,
                    'View Reports',
                    'Check detailed transaction history',
                    Icons.bar_chart,
                    () {
                      // TODO: Implement Reports
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
