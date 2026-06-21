import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../domain/entities/user_role.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String enteredPin = '';
  int attempts = 0;
  bool isError = false;

  void _onDigitPress(String digit) {
    if (enteredPin.length < 6) {
      setState(() {
        enteredPin += digit;
        isError = false;
      });

      if (enteredPin.length == 6) {
        _validatePin();
      }
    }
  }

  void _onDeletePress() {
    if (enteredPin.isNotEmpty) {
      setState(() {
        enteredPin = enteredPin.substring(0, enteredPin.length - 1);
        isError = false;
      });
    }
  }

  void _validatePin() {
    final localDb = ref.read(localDbProvider);
    final authState = ref.read(authProvider);

    final correctPin = authState.role == UserRole.owner
        ? localDb.getOwnerPin()
        : localDb.getKasirPin();

    if (enteredPin == correctPin) {
      ref.read(authProvider.notifier).verifyPin();
      
      // Jika Kasir login, kirim notifikasi bahwa shift sudah dibuka
      if (authState.role == UserRole.kasir) {
        ref.read(notificationServiceProvider).showNotification(
          title: 'Shift Kasir Dibuka',
          body: 'Kasir baru saja masuk ke sistem pada ${DateTime.now().toString().split('.')[0]}',
        );
      }
    } else {
      setState(() {
        attempts++;
        isError = true;
        enteredPin = '';
      });

      if (attempts >= 5) {
        // Logout otomatis jika terlalu banyak salah
        ref.read(authProvider.notifier).logout();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terlalu banyak percobaan. Sesi ditutup.'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _handleForgotPin() {
    final authState = ref.read(authProvider);
    if (authState.role != UserRole.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya Owner yang dapat mereset PIN via Email.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    final localDb = ref.read(localDbProvider);
    final recoveryContact = localDb.getOwnerRecoveryContact();

    if (recoveryContact == null || recoveryContact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kontak pemulihan belum diatur di Pengaturan Toko.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final codeCtrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Lupa PIN?', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kode verifikasi telah dikirim ke:\n$recoveryContact\n\n(Untuk demo, masukkan: 1234)', style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Kode Verifikasi'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (codeCtrl.text == '1234') {
                  Navigator.pop(ctx);
                  _showSetNewPinDialog();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Kode salah!')));
                }
              },
              child: const Text('Verifikasi'),
            ),
          ],
        );
      },
    );
  }

  void _showSetNewPinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final pinCtrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Set PIN Baru', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: pinCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'PIN Baru (6 digit)'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (pinCtrl.text.length == 6) {
                  await ref.read(localDbProvider).saveOwnerPin(pinCtrl.text);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN berhasil direset!')));
                  }
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('PIN harus 6 digit!')));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isOwner = authState.role == UserRole.owner;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: AppTheme.primaryColor, size: 64),
              const SizedBox(height: 24),
              Text(
                isOwner ? 'Verifikasi Owner' : 'Verifikasi Kasir',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan PIN 6 Digit',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  bool isFilled = index < enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? AppTheme.primaryColor : Colors.transparent,
                      border: Border.all(color: AppTheme.primaryColor, width: 2),
                    ),
                  );
                }),
              ),
              if (isError) ...[
                const SizedBox(height: 16),
                Text(
                  'PIN Salah! Sisa percobaan: ${5 - attempts}',
                  style: const TextStyle(color: AppTheme.error),
                ),
              ] else ...[
                const SizedBox(height: 36),
              ],
              // Numpad
              SizedBox(
                width: 280,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    if (index == 9) return const SizedBox();
                    if (index == 11) {
                      return InkWell(
                        onTap: _onDeletePress,
                        borderRadius: BorderRadius.circular(32),
                        child: const Center(child: Icon(Icons.backspace, color: Colors.white, size: 28)),
                      );
                    }
                    final digit = index == 10 ? '0' : '${index + 1}';
                    return InkWell(
                      onTap: () => _onDigitPress(digit),
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceDark.withOpacity(0.5),
                        ),
                        child: Center(
                          child: Text(
                            digit,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 48),
              if (isOwner)
                TextButton(
                  onPressed: _handleForgotPin,
                  child: const Text('Lupa PIN?', style: TextStyle(color: Colors.orange)),
                ),
              TextButton.icon(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout, color: AppTheme.error),
                label: const Text('Logout / Ganti Akun', style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
