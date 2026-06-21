// lib/features/owner/presentation/screens/owner_license_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/local_db_service.dart';

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

    // Simulate network validation
    await Future.delayed(const Duration(seconds: 2));

    if (key.startsWith('SELLORA-')) {
      final now = DateTime.now();
      // Add 1 year of maintenance
      final expiry = now.add(const Duration(days: 365));
      
      final licenseInfo = {
        'serial_key': key,
        'activation_date': now.toIso8601String(),
        'expiry_date': expiry.toIso8601String(),
        'status': 'ACTIVE',
      };

      await ref.read(localDbProvider).saveLicenseInfo(licenseInfo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Lisensi berhasil diaktivasi! Maintenance diperpanjang 1 tahun.'), backgroundColor: Colors.green),
        );
        _keyCtrl.clear();
        _loadLicense();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Serial Key tidak valid!'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
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
              'Aktivasi / Perpanjang Lisensi',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masukkan Serial Key yang Tuan terima dari tim SELLORA untuk mengaktifkan sistem atau memperpanjang masa maintenance.',
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
                      hintText: 'Contoh: SELLORA-XXXX-XXXX',
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
