import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/local_db_service.dart';
import '../providers/store_settings_provider.dart';

class OwnerStoreSettingsScreen extends ConsumerStatefulWidget {
  const OwnerStoreSettingsScreen({super.key});

  @override
  ConsumerState<OwnerStoreSettingsScreen> createState() => _OwnerStoreSettingsScreenState();
}

class _OwnerStoreSettingsScreenState extends ConsumerState<OwnerStoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _ownerPinController;
  late TextEditingController _kasirPinController;
  late TextEditingController _recoveryContactController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(storeSettingsProvider);
    final localDb = ref.read(localDbProvider);
    _nameController = TextEditingController(text: settings['name']);
    _addressController = TextEditingController(text: settings['address']);
    _phoneController = TextEditingController(text: settings['phone']);
    _ownerPinController = TextEditingController(text: localDb.getOwnerPin());
    _kasirPinController = TextEditingController(text: localDb.getKasirPin());
    _recoveryContactController = TextEditingController(text: localDb.getOwnerRecoveryContact() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _ownerPinController.dispose();
    _kasirPinController.dispose();
    _recoveryContactController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      ref.read(storeSettingsProvider.notifier).saveSettings(
            name: _nameController.text,
            address: _addressController.text,
            phone: _phoneController.text,
          );
      ref.read(localDbProvider).saveOwnerPin(_ownerPinController.text);
      ref.read(localDbProvider).saveKasirPin(_kasirPinController.text);
      if (_recoveryContactController.text.isNotEmpty) {
        ref.read(localDbProvider).saveOwnerRecoveryContact(_recoveryContactController.text);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan toko & PIN berhasil disimpan')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Toko'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              _buildSectionTitle('Informasi Dasar'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Toko',
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Nama toko wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Alamat Toko',
                  prefixIcon: Icon(Icons.location_on),
                  alignLabelWithHint: true,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Alamat wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Nomor telepon wajib diisi' : null,
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Keamanan (Otorisasi Kasir)'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN Owner (6 Digit)',
                  prefixIcon: Icon(Icons.password),
                  helperText: 'Otorisasi Void / Pengaturan.',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'PIN tidak boleh kosong';
                  if (val.length != 6) return 'PIN harus 6 digit angka';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _kasirPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN Kasir (6 Digit)',
                  prefixIcon: Icon(Icons.pin),
                  helperText: 'Otorisasi Diskon Transaksi.',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'PIN tidak boleh kosong';
                  if (val.length != 6) return 'PIN harus 6 digit angka';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recoveryContactController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email / No. HP Pemulihan PIN',
                  prefixIcon: Icon(Icons.contact_mail),
                  helperText: 'Digunakan jika Manajer lupa PIN.',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Kontak pemulihan wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Simpan Pengaturan', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
    );
  }
}
