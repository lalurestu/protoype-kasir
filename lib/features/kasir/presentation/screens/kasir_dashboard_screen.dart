// lib/features/kasir/presentation/screens/kasir_dashboard_screen.dart
// UPDATED: Full shift management (open/close), sync offline, tutup kasir

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../core/network/api_client.dart';
import '../providers/shift_provider.dart';
import '../../../../shared/models/shift_model.dart';

class KasirDashboardScreen extends ConsumerStatefulWidget {
  const KasirDashboardScreen({super.key});

  @override
  ConsumerState<KasirDashboardScreen> createState() => _KasirDashboardScreenState();
}

class _KasirDashboardScreenState extends ConsumerState<KasirDashboardScreen> {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // Load current shift on dashboard open
    Future.microtask(() => ref.read(shiftNotifierProvider.notifier).loadCurrentShift());
  }

  Future<void> _syncOfflineData() async {
    setState(() => _isSyncing = true);
    final localDb = ref.read(localDbProvider);
    final dio = ref.read(dioProvider);
    final pendingList = localDb.getPendingTransactions();

    if (pendingList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada data offline yang perlu disinkronisasi')));
      }
      setState(() => _isSyncing = false);
      return;
    }

    try {
      final res = await dio.post('/sync-transactions', data: {'transactions': pendingList});
      if (res.statusCode == 200 || res.statusCode == 201) {
        await localDb.clearPendingTransactions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Berhasil menyinkronkan data offline ke server!'),
                  backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data.toString() ?? e.message ?? errorMsg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal sinkronisasi: $errorMsg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // BUKA SHIFT
  Future<void> _showBukaShiftDialog() async {
    final cashController = TextEditingController(text: '0');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock_open, color: AppTheme.secondaryColor),
                  SizedBox(width: 10),
                  Text('Buka Shift', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan jumlah uang tunai awal di laci kasir untuk memulai shift.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: cashController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'Kas Awal (Rp)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: Icon(Icons.payments, color: AppTheme.secondaryColor),
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                  icon: isLoading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.play_arrow),
                  label: const Text('Mulai Shift'),
                  onPressed: isLoading
                      ? null
                      : () async {
                          setStateDialog(() => isLoading = true);
                          try {
                            final openingCash = double.tryParse(cashController.text) ?? 0;
                            await ref
                                .read(shiftNotifierProvider.notifier)
                                .openShift(openingCash);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Shift berhasil dibuka! Selamat bekerja.'),
                                  backgroundColor: AppTheme.secondaryColor,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Gagal buka shift: $e'),
                                    backgroundColor: AppTheme.error),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setStateDialog(() => isLoading = false);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // TUTUP SHIFT
  Future<void> _showTutupShiftDialog(ShiftModel shift) async {
    final closingCashCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final expectedCash = shift.openingCash + shift.totalSales;
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock_clock, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('Tutup Shift', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ringkasan shift
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _shiftSummaryRow('Kas Awal', 'Rp ${shift.openingCash.toStringAsFixed(0)}', Colors.white),
                          const SizedBox(height: 6),
                          _shiftSummaryRow('Total Penjualan', 'Rp ${shift.totalSales.toStringAsFixed(0)}', AppTheme.secondaryColor),
                          const SizedBox(height: 6),
                          _shiftSummaryRow('Total Transaksi', '${shift.totalTransactions} txn', Colors.blue),
                          const Divider(color: Colors.white24, height: 20),
                          _shiftSummaryRow('Ekspektasi Kas', 'Rp ${expectedCash.toStringAsFixed(0)}', Colors.amber),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: closingCashCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Uang Tunai di Laci (Rp)',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        prefixIcon: Icon(Icons.payments, color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        prefixIcon: Icon(Icons.note, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  icon: isLoading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.stop),
                  label: const Text('Tutup Shift'),
                  onPressed: isLoading
                      ? null
                      : () async {
                          setStateDialog(() => isLoading = true);
                          try {
                            final closingCash = double.tryParse(closingCashCtrl.text) ?? 0;
                            final closedShift = await ref
                                .read(shiftNotifierProvider.notifier)
                                .closeShift(shift.id, closingCash, noteCtrl.text);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              _showShiftSummaryAlert(closedShift);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Gagal tutup shift: $e'),
                                    backgroundColor: AppTheme.error),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setStateDialog(() => isLoading = false);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showShiftSummaryAlert(ShiftModel shift) {
    final diff = (shift.closingCash ?? 0) - shift.openingCash - shift.totalSales;
    final isPositive = diff >= 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('✅ Shift Selesai', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _shiftSummaryRow('Kas Awal', 'Rp ${shift.openingCash.toStringAsFixed(0)}', Colors.white),
            const SizedBox(height: 8),
            _shiftSummaryRow('Penjualan', 'Rp ${shift.totalSales.toStringAsFixed(0)}', AppTheme.secondaryColor),
            const SizedBox(height: 8),
            _shiftSummaryRow('Kas Akhir', 'Rp ${(shift.closingCash ?? 0).toStringAsFixed(0)}', Colors.white),
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Selisih Kas:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${isPositive ? '+' : ''}Rp ${diff.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isPositive ? AppTheme.secondaryColor : AppTheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            if (!isPositive)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ Terdapat selisih negatif. Harap dilaporkan ke pemilik toko.',
                    style: TextStyle(color: AppTheme.error, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Widget _shiftSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _showTutupKasirDialog() async {
    // Must close shift first if open
    final shiftState = ref.read(shiftNotifierProvider);
    shiftState.whenData((shift) {
      if (shift != null && shift.isOpen) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Tutup shift terlebih dahulu sebelum keluar!'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    });

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
                    decoration: const InputDecoration(
                        labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                        labelText: 'Kata Sandi', border: OutlineInputBorder()),
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
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (emailController.text.isEmpty ||
                              passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Email dan kata sandi harus diisi')));
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Verifikasi gagal. Periksa kembali email dan sandi.'),
                                      backgroundColor: Colors.red));
                            }
                          } finally {
                            if (mounted) setStateDialog(() => isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  child: isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Verifikasi & Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftNotifierProvider);
    final pendingCount = ref.read(localDbProvider).getPendingTransactions().length;

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
            // Shift Status Banner
            shiftState.when(
              data: (shift) => _buildShiftBanner(shift),
              loading: () => const LinearProgressIndicator(color: AppTheme.primaryColor),
              error: (e, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            const Text('Selamat Datang!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Pilih aksi di bawah untuk memulai.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 32),

            // POS Kasir
            _buildActionCard(
              title: 'Buka Mesin Kasir (POS)',
              subtitle: 'Mulai layani pelanggan dan proses pesanan',
              icon: Icons.point_of_sale,
              gradient: AppTheme.primaryGradient,
              shadowColor: AppTheme.primaryColor,
              onTap: () {
                final shift = shiftState.valueOrNull;
                if (shift == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('⚠️ Buka shift terlebih dahulu sebelum melayani pelanggan!'),
                    backgroundColor: Colors.orange,
                  ));
                  _showBukaShiftDialog();
                  return;
                }
                context.goNamed(RouteNames.posCheckout);
              },
            ),
            const SizedBox(height: 16),

            // Laporan Harian
            _buildActionCard(
              title: 'Laporan Harian',
              subtitle: 'Lihat ringkasan penjualan hari ini',
              icon: Icons.analytics,
              color: AppTheme.surfaceDark,
              borderColor: AppTheme.primaryColor.withOpacity(0.3),
              iconColor: AppTheme.primaryColor,
              onTap: () => context.goNamed(RouteNames.kasirReport),
            ),
            const SizedBox(height: 16),

            // Pengaturan Printer
            _buildActionCard(
              title: 'Pengaturan Printer',
              subtitle: 'Hubungkan printer struk bluetooth',
              icon: Icons.print,
              color: AppTheme.surfaceDark,
              borderColor: Colors.blueAccent.withOpacity(0.3),
              iconColor: Colors.blueAccent,
              onTap: () => context.goNamed(RouteNames.printerSettings),
            ),
            const SizedBox(height: 16),

            // Sinkronisasi Offline
            _buildActionCard(
              title: 'Sinkronisasi Offline',
              subtitle: pendingCount > 0
                  ? '$pendingCount transaksi menunggu dikirim'
                  : 'Kirim data jualan offline ke server',
              icon: _isSyncing ? Icons.sync : Icons.sync,
              color: AppTheme.surfaceDark,
              borderColor: Colors.orange.withOpacity(0.5),
              iconColor: Colors.orange,
              badge: pendingCount > 0 ? '$pendingCount' : null,
              isLoading: _isSyncing,
              onTap: _isSyncing ? null : _syncOfflineData,
            ),
            const SizedBox(height: 16),

            // Shift Controls
            shiftState.when(
              data: (shift) {
                if (shift == null || !shift.isOpen) {
                  return _buildActionCard(
                    title: 'Buka Shift',
                    subtitle: 'Mulai sesi kerja dan catat kas awal',
                    icon: Icons.lock_open,
                    color: AppTheme.surfaceDark,
                    borderColor: AppTheme.secondaryColor.withOpacity(0.5),
                    iconColor: AppTheme.secondaryColor,
                    onTap: _showBukaShiftDialog,
                  );
                } else {
                  return _buildActionCard(
                    title: 'Tutup Shift',
                    subtitle: 'Akhiri sesi kerja dan rekap kas akhir',
                    icon: Icons.lock_clock,
                    color: AppTheme.surfaceDark,
                    borderColor: Colors.redAccent.withOpacity(0.5),
                    iconColor: Colors.redAccent,
                    onTap: () => _showTutupShiftDialog(shift),
                  );
                }
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Keluar / Ganti User
            _buildActionCard(
              title: 'Tutup Kasir / Keluar',
              subtitle: 'Akhiri sesi kasir dan keluar dari aplikasi',
              icon: Icons.exit_to_app,
              color: AppTheme.surfaceDark,
              borderColor: Colors.redAccent.withOpacity(0.5),
              iconColor: Colors.redAccent,
              onTap: _showTutupKasirDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftBanner(ShiftModel? shift) {
    if (shift == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Shift belum dibuka. Buka shift untuk mulai bekerja.',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.secondaryColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shift Aktif',
                    style: TextStyle(
                        color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                Text(
                    'Kas awal: Rp ${shift.openingCash.toStringAsFixed(0)} | '
                    '${shift.totalTransactions} transaksi | '
                    'Rp ${shift.totalSales.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    LinearGradient? gradient,
    Color? color,
    Color? borderColor,
    Color? iconColor,
    Color? shadowColor,
    String? badge,
    bool isLoading = false,
  }) {
    final isGradient = gradient != null;
    final effectiveIconColor = iconColor ?? (isGradient ? Colors.white : AppTheme.primaryColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          boxShadow: shadowColor != null
              ? [BoxShadow(color: shadowColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]
              : null,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isLoading ? Icons.sync : icon,
                  size: 44,
                  color: effectiveIconColor,
                ),
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.orange, shape: BoxShape.circle),
                      child: Text(badge,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isGradient ? Colors.white : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: isGradient ? Colors.white70 : AppTheme.textSecondary,
                          fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios,
                color: isGradient ? Colors.white : effectiveIconColor, size: 20),
          ],
        ),
      ),
    );
  }
}
