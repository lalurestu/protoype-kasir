// lib/features/owner/presentation/screens/owner_tax_service_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/local_db_service.dart';

class OwnerTaxServiceScreen extends ConsumerStatefulWidget {
  const OwnerTaxServiceScreen({super.key});

  @override
  ConsumerState<OwnerTaxServiceScreen> createState() => _OwnerTaxServiceScreenState();
}

class _OwnerTaxServiceScreenState extends ConsumerState<OwnerTaxServiceScreen> {
  final _taxCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = ref.read(localDbProvider).getStoreSettings();
    _taxCtrl.text = (settings['tax_percent'] ?? 0).toString();
    _serviceCtrl.text = (settings['service_percent'] ?? 0).toString();
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final localDb = ref.read(localDbProvider);
      final currentSettings = localDb.getStoreSettings();
      
      final tax = double.tryParse(_taxCtrl.text) ?? 0.0;
      final service = double.tryParse(_serviceCtrl.text) ?? 0.0;

      final updated = {
        ...currentSettings,
        'tax_percent': tax,
        'service_percent': service,
      };

      await localDb.saveStoreSettings(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Pengaturan Pajak & Layanan berhasil disimpan!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal menyimpan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Manajemen Pajak & Layanan'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pengaturan Beban Tambahan',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Persentase ini akan otomatis ditambahkan pada setiap transaksi di menu kasir.',
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
                  const Text('Pajak Pembangunan 1 (PB1) / PPN', style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _taxCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Contoh: 10 atau 11',
                      suffixText: '%',
                      suffixStyle: TextStyle(color: AppTheme.secondaryColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Service Charge (Biaya Layanan)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _serviceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Contoh: 5',
                      suffixText: '%',
                      suffixStyle: TextStyle(color: AppTheme.secondaryColor),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan Pengaturan', style: TextStyle(fontSize: 16)),
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
