import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../core/network/api_client.dart';

class KasirDashboardScreen extends ConsumerStatefulWidget {
  const KasirDashboardScreen({super.key});

  @override
  ConsumerState<KasirDashboardScreen> createState() => _KasirDashboardScreenState();
}

class _KasirDashboardScreenState extends ConsumerState<KasirDashboardScreen> {
  bool _isSyncing = false;

  Future<void> _syncOfflineData() async {
    setState(() => _isSyncing = true);
    final localDb = ref.read(localDbProvider);
    final dio = ref.read(dioProvider);
    final pendingList = localDb.getPendingTransactions();

    if (pendingList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data offline yang perlu disinkronisasi')));
      }
      setState(() => _isSyncing = false);
      return;
    }

    try {
      final res = await dio.post('/sync-transactions', data: {'transactions': pendingList});
      if (res.statusCode == 200 || res.statusCode == 201) {
        await localDb.clearPendingTransactions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil menyinkronkan data offline ke server!'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data.toString() ?? e.message ?? errorMsg;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal sinkronisasi: $errorMsg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Kasir', style: TextStyle(fontWeight: FontWeight.bold)),
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
        padding: const EdgeInsets.all(32.0),
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const Text('Selamat Datang!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Pilih aksi di bawah untuk memulai.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 48),
            InkWell(
              onTap: () => context.goNamed(RouteNames.posCheckout),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.point_of_sale, size: 48, color: Colors.white),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Buka Mesin Kasir (POS)', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Mulai layani pelanggan dan proses pesanan', style: TextStyle(color: Colors.white70, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => context.goNamed(RouteNames.kasirReport),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.analytics, size: 48, color: AppTheme.primaryColor),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Laporan Harian', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Lihat ringkasan penjualan hari ini', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, color: AppTheme.primaryColor, size: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: _isSyncing ? null : _syncOfflineData,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    _isSyncing 
                      ? const CircularProgressIndicator(color: Colors.orange)
                      : const Icon(Icons.sync, size: 48, color: Colors.orange),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sinkronisasi Offline', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Kirim data jualan offline ke server', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
