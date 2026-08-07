// lib/features/owner/presentation/screens/owner_license_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../core/network/api_client.dart';

class OwnerLicenseScreen extends ConsumerStatefulWidget {
  const OwnerLicenseScreen({super.key});

  @override
  ConsumerState<OwnerLicenseScreen> createState() => _OwnerLicenseScreenState();
}

class _OwnerLicenseScreenState extends ConsumerState<OwnerLicenseScreen> {
  final _keyCtrl = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _currentLicense;

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  void _loadLicense() {
    setState(() {
      _currentLicense = ref.read(localDbProvider).getLicenseInfo();
    });
  }

  Future<void> _activateLicense() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/owner/activate-serial-key', data: {
        'serial_key': key,
      });

      final message = response.data['message'] ?? 'Lisensi berhasil diaktifkan!';
      final expiresAt = response.data['license_expires_at'];

      final licenseInfo = {
        'serial_key': key,
        'activation_date': DateTime.now().toIso8601String(),
        'expiry_date': expiresAt ?? DateTime.now().add(const Duration(days: 365)).toIso8601String(),
        'status': 'ACTIVE',
      };

      await ref.read(localDbProvider).saveLicenseInfo(licenseInfo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $message'), backgroundColor: Colors.green),
        );
        _keyCtrl.clear();
        _loadLicense();
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data is Map ? e.response?.data['error']?.toString() : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${errorMsg ?? "Gagal mengaktifkan serial key."}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Terjadi kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isExpired = false;
    int daysLeft = 0;

    if (_currentLicense != null) {
      final expiry = DateTime.parse(_currentLicense!['expiry_date']);
      final now = DateTime.now();
      daysLeft = expiry.difference(now).inDays;
      isExpired = daysLeft <= 0;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Lisensi & Maintenance'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentLicense != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isExpired 
                      ? const LinearGradient(colors: [Colors.redAccent, Colors.red])
                      : AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status Lisensi', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(isExpired ? 'KADALUARSA' : 'AKTIF', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('Sisa Masa Maintenance: ${isExpired ? 0 : daysLeft} hari', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Berlaku hingga: ${_currentLicense!['expiry_date'].toString().split('T')[0]}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            const Text(
              'Aktivasi / Perpanjang Lisensi Toko',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masukkan Kode Serial Key yang Anda dapatkan dari Super Admin untuk mengaktifkan sistem atau memperpanjang masa berlaku lisensi toko.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Serial Key', style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Contoh: KEY-XXXX-XXXX',
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _activateLicense,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.secondaryColor,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Validasi Key', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
