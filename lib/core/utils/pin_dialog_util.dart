// lib/core/utils/pin_dialog_util.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';

class PinDialogUtil {
  /// Meminta PIN Owner. Mengembalikan [true] jika benar, [false] jika dibatalkan atau salah limit.
  static Future<bool> requireOwnerPin(BuildContext context, WidgetRef ref) async {
    final localDb = ref.read(localDbProvider);
    final correctPin = localDb.getOwnerPin();

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PinDialog(correctPin: correctPin, title: 'Otorisasi Owner', isOwner: true),
    );

    return result ?? false;
  }

  /// Meminta PIN Kasir. Mengembalikan [true] jika benar, [false] jika dibatalkan atau salah limit.
  static Future<bool> requireKasirPin(BuildContext context, WidgetRef ref) async {
    final localDb = ref.read(localDbProvider);
    final correctPin = localDb.getKasirPin();

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PinDialog(correctPin: correctPin, title: 'Otorisasi Kasir', isOwner: false),
    );

    return result ?? false;
  }
}

class _PinDialog extends ConsumerStatefulWidget {
  final String correctPin;
  final String title;
  final bool isOwner;

  const _PinDialog({required this.correctPin, required this.title, required this.isOwner});

  @override
  ConsumerState<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends ConsumerState<_PinDialog> {
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
    if (enteredPin == widget.correctPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        attempts++;
        isError = true;
        enteredPin = '';
      });

      if (attempts >= 3) {
        Navigator.of(context).pop(false);
      }
    }
  }

  void _handleForgotPin() {
    if (!widget.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hanya Owner yang dapat mereset PIN via Email.')));
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
                    Navigator.pop(ctx); // Tutup dialog set PIN
                    Navigator.of(context).pop(true); // Tutup PinDialog dengan sukses
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN berhasil direset!')));
                  }
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('PIN harus 6 digit!')));
                }
              },
              child: const Text('Simpan & Lanjutkan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: AppTheme.primaryColor, size: 48),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masukkan PIN 6 Digit',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                bool isFilled = index < enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppTheme.primaryColor : Colors.transparent,
                    border: Border.all(color: AppTheme.primaryColor),
                  ),
                );
              }),
            ),
            if (isError) ...[
              const SizedBox(height: 16),
              Text(
                'PIN Salah! Sisa percobaan: ${3 - attempts}',
                style: const TextStyle(color: AppTheme.error),
              ),
            ] else ...[
              const SizedBox(height: 32),
            ],
            // Numpad
            SizedBox(
              width: 250,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  if (index == 9) return const SizedBox(); // Empty bottom-left
                  if (index == 11) {
                    // Delete button
                    return InkWell(
                      onTap: _onDeletePress,
                      child: const Center(child: Icon(Icons.backspace, color: Colors.white)),
                    );
                  }
                  final digit = index == 10 ? '0' : '${index + 1}';
                  return InkWell(
                    onTap: () => _onDigitPress(digit),
                    child: Center(
                      child: Text(
                        digit,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _handleForgotPin,
                  child: const Text('Lupa PIN?', style: TextStyle(color: Colors.orange)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
