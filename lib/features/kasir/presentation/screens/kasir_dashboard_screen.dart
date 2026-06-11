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

  Future<void> _showTutupKasirDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Verifikasi Tutup Kasir'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Masukkan email dan kata sandi Anda untuk menutup kasir.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Kata Sandi', border: OutlineInputBorder()),
                    obscureText: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email dan kata sandi harus diisi')));
                      return;
                    }
                    setStateDialog(() => isLoading = true);
                    try {
                      final dio = ref.read(dioProvider);
                      final response = await dio.post('/auth/login', data: {
                        'email': emailController.text,
                        'password': passwordController.text,
                      });
                      
                      if (response.statusCode == 200 || response.statusCode == 201) {
                        if (mounted) Navigator.pop(context);
                        ref.read(authProvider.notifier).logout();
                      }
                    } catch (e) {
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verifikasi gagal. Periksa kembali email dan sandi.'), backgroundColor: Colors.red));
                      }
                    } finally {
                      if (mounted) setStateDialog(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verifikasi & Tutup'),
                ),
              ],
            );
          }
        );
      }
    );
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
            const SizedBox(height: 24),
            InkWell(
              onTap: _showTutupKasirDialog,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_clock, size: 48, color: Colors.redAccent),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tutup Kasir', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Akhiri sesi kasir dan keluar dari aplikasi', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, color: Colors.redAccent, size: 24),
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
