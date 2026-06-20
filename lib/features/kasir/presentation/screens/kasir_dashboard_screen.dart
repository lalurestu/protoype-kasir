// lib/features/kasir/presentation/screens/kasir_dashboard_screen.dart
// UPDATED: Full shift management, offline sync, premium UI redesign + CurrencyFormatter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/shift_provider.dart';
import '../../../../shared/models/shift_model.dart';

class KasirDashboardScreen extends ConsumerStatefulWidget {
  const KasirDashboardScreen({super.key});

  @override
  ConsumerState<KasirDashboardScreen> createState() => _KasirDashboardScreenState();
}

class _KasirDashboardScreenState extends ConsumerState<KasirDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isSyncing = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    Future.microtask(
        () => ref.read(shiftNotifierProvider.notifier).loadCurrentShift());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _syncOfflineData() async {
    setState(() => _isSyncing = true);
    final localDb = ref.read(localDbProvider);
    final dio = ref.read(dioProvider);
    final pendingList = localDb.getPendingTransactions();

    if (pendingList.isEmpty) {
      if (mounted) {
        _showSnackBar('Tidak ada data offline yang perlu disinkronisasi', isSuccess: true);
      }
      setState(() => _isSyncing = false);
      return;
    }

    try {
      final res = await dio.post('/sync-transactions', data: {'transactions': pendingList});
      if (res.statusCode == 200 || res.statusCode == 201) {
        await localDb.clearPendingTransactions();
        if (mounted) {
          _showSnackBar('✅ Berhasil menyinkronkan ${pendingList.length} transaksi ke server!',
              isSuccess: true);
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data.toString() ?? e.message ?? errorMsg;
        }
        _showSnackBar('Gagal sinkronisasi: $errorMsg', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showSnackBar(String message,
      {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError
          ? AppTheme.error
          : isSuccess
              ? AppTheme.secondaryColor
              : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── BUKA SHIFT ───────────────────────────────────────────────
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(children: [
                Icon(Icons.lock_open, color: AppTheme.secondaryColor),
                SizedBox(width: 10),
                Text('Buka Shift', style: TextStyle(color: Colors.white)),
              ]),
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
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                            await ref.read(shiftNotifierProvider.notifier).openShift(openingCash);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) _showSnackBar('✅ Shift berhasil dibuka! Selamat bekerja.', isSuccess: true);
                          } catch (e) {
                            if (mounted) _showSnackBar('Gagal buka shift: $e', isError: true);
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

  // ─── TUTUP SHIFT ──────────────────────────────────────────────
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(children: [
                Icon(Icons.lock_clock, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Tutup Shift', style: TextStyle(color: Colors.white)),
              ]),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _shiftSummaryRow('Kas Awal',
                              CurrencyFormatter.format(shift.openingCash), Colors.white),
                          const SizedBox(height: 6),
                          _shiftSummaryRow('Total Penjualan',
                              CurrencyFormatter.format(shift.totalSales), AppTheme.secondaryColor),
                          const SizedBox(height: 6),
                          _shiftSummaryRow('Total Transaksi',
                              '${shift.totalTransactions} txn', Colors.blue),
                          const Divider(color: Colors.white24, height: 20),
                          _shiftSummaryRow('Ekspektasi Kas',
                              CurrencyFormatter.format(expectedCash), Colors.amber),
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
                            if (mounted) _showShiftSummaryAlert(closedShift);
                          } catch (e) {
                            if (mounted) _showSnackBar('Gagal tutup shift: $e', isError: true);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('✅ Shift Selesai', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _shiftSummaryRow('Kas Awal', CurrencyFormatter.format(shift.openingCash), Colors.white),
            const SizedBox(height: 8),
            _shiftSummaryRow('Penjualan', CurrencyFormatter.format(shift.totalSales), AppTheme.secondaryColor),
            const SizedBox(height: 8),
            _shiftSummaryRow('Kas Akhir', CurrencyFormatter.format(shift.closingCash ?? 0), Colors.white),
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Selisih Kas:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  CurrencyFormatter.formatDelta(diff),
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
    final shiftState = ref.read(shiftNotifierProvider);
    shiftState.whenData((shift) {
      if (shift != null && shift.isOpen) {
        _showSnackBar('⚠️ Tutup shift terlebih dahulu sebelum keluar!');
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
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(children: [
                Icon(Icons.exit_to_app, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Verifikasi Tutup Kasir', style: TextStyle(color: Colors.white)),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Masukkan email dan kata sandi Anda untuk menutup kasir.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Email', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Kata Sandi', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                    obscureText: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                            _showSnackBar('Email dan kata sandi harus diisi');
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
                              _showSnackBar('Verifikasi gagal. Periksa kembali email dan sandi.',
                                  isError: true);
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

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftNotifierProvider);
    final authState = ref.watch(authProvider);
    final pendingCount = ref.read(localDbProvider).getPendingTransactions().length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Premium Header ─────────────────────────────────
              _buildHeader(authState, shiftState),

              // ── Content ────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    // Shift status banner
                    shiftState.when(
                      data: (shift) => _buildShiftBanner(shift),
                      loading: () => const LinearProgressIndicator(color: AppTheme.primaryColor),
                      error: (e, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),

                    // Section label
                    const Text('Aksi Cepat',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 12),

                    // POS Card — highlighted
                    _buildActionCard(
                      title: 'Buka Mesin Kasir (POS)',
                      subtitle: 'Mulai layani pelanggan dan proses pesanan',
                      icon: Icons.point_of_sale,
                      gradient: AppTheme.primaryGradient,
                      shadowColor: AppTheme.primaryColor,
                      onTap: () {
                        final shift = shiftState.valueOrNull;
                        if (shift == null) {
                          _showSnackBar('⚠️ Buka shift terlebih dahulu!');
                          _showBukaShiftDialog();
                          return;
                        }
                        context.goNamed(RouteNames.posCheckout);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Laporan Harian
                    _buildActionCard(
                      title: 'Laporan Harian',
                      subtitle: 'Lihat ringkasan penjualan hari ini',
                      icon: Icons.analytics_outlined,
                      color: AppTheme.surfaceDark,
                      borderColor: AppTheme.primaryColor.withOpacity(0.3),
                      iconColor: AppTheme.primaryColor,
                      onTap: () => context.goNamed(RouteNames.kasirReport),
                    ),
                    const SizedBox(height: 12),

                    // Pengaturan Printer
                    _buildActionCard(
                      title: 'Pengaturan Printer',
                      subtitle: 'Hubungkan printer struk Bluetooth',
                      icon: Icons.print_outlined,
                      color: AppTheme.surfaceDark,
                      borderColor: Colors.blueAccent.withOpacity(0.3),
                      iconColor: Colors.blueAccent,
                      onTap: () => context.goNamed(RouteNames.printerSettings),
                    ),
                    const SizedBox(height: 12),

                    // Data Pelanggan
                    _buildActionCard(
                      title: 'Data Pelanggan',
                      subtitle: 'Pendaftaran member dan histori belanja',
                      icon: Icons.people_outline,
                      color: AppTheme.surfaceDark,
                      borderColor: Colors.purple.withOpacity(0.3),
                      iconColor: Colors.purple,
                      onTap: () => context.goNamed(RouteNames.kasirManageCustomers),
                    ),
                    const SizedBox(height: 12),

                    // Sinkronisasi Offline
                    _buildActionCard(
                      title: _isSyncing ? 'Menyinkronkan...' : 'Sinkronisasi Offline',
                      subtitle: pendingCount > 0
                          ? '$pendingCount transaksi menunggu dikirim ke server'
                          : 'Semua data sudah tersinkronisasi',
                      icon: Icons.cloud_sync_outlined,
                      color: AppTheme.surfaceDark,
                      borderColor: pendingCount > 0
                          ? Colors.orange.withOpacity(0.6)
                          : Colors.green.withOpacity(0.3),
                      iconColor: pendingCount > 0 ? Colors.orange : Colors.green,
                      badge: pendingCount > 0 ? '$pendingCount' : null,
                      isLoading: _isSyncing,
                      onTap: _isSyncing ? null : _syncOfflineData,
                    ),
                    const SizedBox(height: 20),

                    const Text('Manajemen Shift',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 12),

                    // Shift controls
                    shiftState.when(
                      data: (shift) {
                        if (shift == null || !shift.isOpen) {
                          return _buildActionCard(
                            title: 'Buka Shift',
                            subtitle: 'Mulai sesi kerja dan catat kas awal',
                            icon: Icons.lock_open_outlined,
                            color: AppTheme.surfaceDark,
                            borderColor: AppTheme.secondaryColor.withOpacity(0.4),
                            iconColor: AppTheme.secondaryColor,
                            onTap: _showBukaShiftDialog,
                          );
                        } else {
                          return _buildActionCard(
                            title: 'Tutup Shift',
                            subtitle: 'Akhiri sesi kerja dan rekap kas akhir',
                            icon: Icons.lock_clock,
                            color: AppTheme.surfaceDark,
                            borderColor: Colors.redAccent.withOpacity(0.4),
                            iconColor: Colors.redAccent,
                            onTap: () => _showTutupShiftDialog(shift),
                          );
                        }
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),

                    // Keluar / Ganti User
                    _buildActionCard(
                      title: 'Tutup Kasir / Keluar',
                      subtitle: 'Akhiri sesi kasir dan keluar dari aplikasi',
                      icon: Icons.exit_to_app,
                      color: AppTheme.surfaceDark,
                      borderColor: Colors.redAccent.withOpacity(0.3),
                      iconColor: Colors.redAccent,
                      onTap: _showTutupKasirDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AuthState authState, AsyncValue<ShiftModel?> shiftState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard Kasir',
                    style: TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                shiftState.when(
                  data: (shift) => Text(
                    shift != null && shift.isOpen ? '🟢 Shift Aktif' : '⚪ Belum Buka Shift',
                    style: TextStyle(
                      color: shift != null && shift.isOpen
                          ? AppTheme.secondaryColor
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.error, size: 22),
            tooltip: 'Keluar',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
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
        child: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Shift belum dibuka. Buka shift untuk mulai bekerja.',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  'Kas awal: ${CurrencyFormatter.format(shift.openingCash)} · '
                  '${shift.totalTransactions} txn · '
                  '${CurrencyFormatter.format(shift.totalSales)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
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
    final effectiveIconColor =
        iconColor ?? (isGradient ? Colors.white : AppTheme.primaryColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: gradient,
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: borderColor != null ? Border.all(color: borderColor) : null,
            boxShadow: shadowColor != null
                ? [
                    BoxShadow(
                        color: shadowColor.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ]
                : null,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isGradient
                          ? Colors.white.withOpacity(0.2)
                          : effectiveIconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 28, height: 28,
                            child: CircularProgressIndicator(
                                color: effectiveIconColor, strokeWidth: 2.5))
                        : Icon(icon, size: 28, color: effectiveIconColor),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -6, right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.orange, shape: BoxShape.circle),
                        child: Text(badge,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
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
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: isGradient ? Colors.white70 : AppTheme.textSecondary,
                            fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios,
                  color: isGradient ? Colors.white70 : effectiveIconColor.withOpacity(0.5),
                  size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
