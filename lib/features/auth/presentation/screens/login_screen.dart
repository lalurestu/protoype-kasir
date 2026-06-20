// lib/features/auth/presentation/screens/login_screen.dart
// UPDATED: Added "Lupa Password" feature — Owner can request password reset from Super Admin

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: const BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                    color: AppTheme.surfaceDark.withOpacity(0.9),
                    elevation: 24,
                    shadowColor: AppTheme.primaryColor.withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40.0, vertical: 48.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo & Branding
                            Container(
                              width: 80,
                              height: 80,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.storefront,
                                  size: 42, color: Colors.white),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Selamat Datang',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Masuk untuk melanjutkan ke sistem kasir',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 36),

                            // Error Banner
                            if (_errorMsg != null)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.error.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: AppTheme.error, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMsg!,
                                        style: const TextStyle(
                                            color: AppTheme.error, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Email Field
                            _buildInputField(
                              controller: _emailCtrl,
                              label: 'Alamat Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            _buildInputField(
                              controller: _passCtrl,
                              label: 'Kata Sandi',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              onSubmitted: (_) => _isLoading ? null : _handleLogin(),
                            ),
                            const SizedBox(height: 12),

                            // Lupa Password button (Owner only)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showForgotPasswordDialog(),
                                icon: const Icon(Icons.help_outline,
                                    size: 15, color: AppTheme.textSecondary),
                                label: const Text(
                                  'Lupa Password? (Owner)',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppTheme.textSecondary,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Login Button
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      AppTheme.primaryColor.withOpacity(0.5),
                                  elevation: 8,
                                  shadowColor:
                                      AppTheme.primaryColor.withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text('Masuk',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        )),
                              ),
                            ),

                            const SizedBox(height: 24),
                            // Info note
                            const Text(
                              'Hanya untuk Kasir & Pemilik Toko',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      keyboardType: keyboardType,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // FORGOT PASSWORD DIALOG
  // Alur: Owner isi email → kirim request ke server → Admin approve/reject
  // ──────────────────────────────────────────────────────────
  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureNewPass = true;
    bool obscureConfirmPass = true;
    bool isSubmitting = false;
    String? resultMessage;
    bool isSuccess = false;
    bool showStatusCheck = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.lock_reset, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Lupa Password',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppTheme.primaryColor, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fitur ini khusus untuk Pemilik Toko (Owner). '
                            'Anda dapat mengatur password baru, namun tetap membutuhkan persetujuan Super Admin sebelum password tersebut aktif.',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Result message
                  if (resultMessage != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? AppTheme.secondaryColor.withOpacity(0.12)
                            : AppTheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSuccess
                              ? AppTheme.secondaryColor.withOpacity(0.4)
                              : AppTheme.error.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                            color: isSuccess
                                ? AppTheme.secondaryColor
                                : AppTheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              resultMessage!,
                              style: TextStyle(
                                color: isSuccess
                                    ? AppTheme.secondaryColor
                                    : AppTheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (resultMessage == null) ...[
                    // Tab: Kirim Request / Cek Status
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setStateDialog(() => showStatusCheck = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !showStatusCheck
                                    ? AppTheme.primaryColor.withOpacity(0.15)
                                    : Colors.transparent,
                                border: Border(
                                    bottom: BorderSide(
                                  color: !showStatusCheck
                                      ? AppTheme.primaryColor
                                      : Colors.transparent,
                                  width: 2,
                                )),
                              ),
                              child: Text(
                                'Kirim Permintaan',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !showStatusCheck
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setStateDialog(() => showStatusCheck = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: showStatusCheck
                                    ? AppTheme.primaryColor.withOpacity(0.15)
                                    : Colors.transparent,
                                border: Border(
                                    bottom: BorderSide(
                                  color: showStatusCheck
                                      ? AppTheme.primaryColor
                                      : Colors.transparent,
                                  width: 2,
                                )),
                              ),
                              child: Text(
                                'Cek Status',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: showStatusCheck
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (!showStatusCheck) ...[
                      // FORM KIRIM REQUEST
                      TextField(
                        controller: emailCtrl,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Owner',
                          labelStyle:
                              const TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: const Icon(Icons.email_outlined,
                              color: AppTheme.primaryColor, size: 18),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color:
                                    AppTheme.primaryColor.withOpacity(0.25)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPassCtrl,
                        style: const TextStyle(color: Colors.white),
                        obscureText: obscureNewPass,
                        decoration: InputDecoration(
                          labelText: 'Password Baru',
                          labelStyle:
                              const TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppTheme.primaryColor, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                                obscureNewPass
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppTheme.textSecondary,
                                size: 18),
                            onPressed: () => setStateDialog(
                                () => obscureNewPass = !obscureNewPass),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color:
                                    AppTheme.primaryColor.withOpacity(0.25)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmPassCtrl,
                        style: const TextStyle(color: Colors.white),
                        obscureText: obscureConfirmPass,
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi Password Baru',
                          labelStyle:
                              const TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppTheme.primaryColor, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                                obscureConfirmPass
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppTheme.textSecondary,
                                size: 18),
                            onPressed: () => setStateDialog(
                                () => obscureConfirmPass = !obscureConfirmPass),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color:
                                    AppTheme.primaryColor.withOpacity(0.25)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryColor),
                          ),
                        ),
                      ),
                    ] else ...[
                      // CEK STATUS REQUEST
                      TextField(
                        controller: emailCtrl,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Owner',
                          labelStyle:
                              const TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: const Icon(Icons.email_outlined,
                              color: AppTheme.primaryColor, size: 18),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color:
                                    AppTheme.primaryColor.withOpacity(0.25)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            if (resultMessage == null)
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        final newPass = newPassCtrl.text;
                        final confirmPass = confirmPassCtrl.text;

                        if (!showStatusCheck) {
                          if (email.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                            setStateDialog(() {
                              resultMessage = 'Harap isi semua kolom.';
                              isSuccess = false;
                            });
                            return;
                          }
                          if (newPass != confirmPass) {
                            setStateDialog(() {
                              resultMessage = 'Password baru dan konfirmasi tidak cocok.';
                              isSuccess = false;
                            });
                            return;
                          }
                        } else {
                          if (email.isEmpty) return;
                        }

                        setStateDialog(() => isSubmitting = true);
                        try {
                          final dio = ref.read(dioProvider);

                          if (!showStatusCheck) {
                            // Kirim request reset
                            final response = await dio.post(
                              '/auth/request-password-reset',
                              data: {
                                'email': email,
                                'new_password': newPass,
                                'reason': 'Mengubah password',
                              },
                            );
                            setStateDialog(() {
                              resultMessage = response.data['message'] ??
                                  'Permintaan berhasil dikirim.';
                              isSuccess = true;
                              // Bersihkan input password setelah berhasil dikirim
                              newPassCtrl.clear();
                              confirmPassCtrl.clear();
                            });
                          } else {
                            // Cek status request
                            final response = await dio.get(
                              '/auth/reset-request-status',
                              queryParameters: {'email': email},
                            );
                            final data =
                                response.data as Map<String, dynamic>;
                            final status = data['status'] ?? 'unknown';
                            String msg = '';

                            if (status == 'pending') {
                              msg =
                                  '⏳ Permintaan Anda sedang MENUNGGU ditinjau oleh Super Admin. '
                                  'Mohon bersabar, Anda dapat login setelah disetujui.';
                              isSuccess = true;
                            } else if (status == 'approved') {
                              msg =
                                  '✅ DISETUJUI! Permintaan ubah password Anda telah disetujui.\n\n'
                                  'Segera login menggunakan password baru yang telah Anda buat.';
                              isSuccess = true;
                            } else if (status == 'rejected') {
                              final note =
                                  data['admin_note'] ?? 'Tidak ada keterangan';
                              msg = '❌ Permintaan DITOLAK oleh Super Admin.\n'
                                  'Catatan: $note\n\n'
                                  'Anda dapat mengirimkan permintaan baru jika diperlukan.';
                              isSuccess = false;
                            } else {
                              msg = 'Status tidak diketahui: $status';
                              isSuccess = false;
                            }

                            setStateDialog(() {
                              resultMessage = msg;
                            });
                          }
                        } on DioException catch (e) {
                          final msg = e.response?.data is Map
                              ? e.response?.data['error']?.toString()
                              : null;
                          setStateDialog(() {
                            resultMessage = msg ??
                                (showStatusCheck
                                    ? 'Tidak ada permintaan reset untuk email ini.'
                                    : 'Gagal mengirim permintaan. Coba lagi.');
                            isSuccess = false;
                          });
                        } finally {
                          setStateDialog(() => isSubmitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(showStatusCheck ? 'Cek Status' : 'Kirim Permintaan'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Email dan kata sandi tidak boleh kosong.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .login(_emailCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      setState(() {
        if (e is DioException) {
          final statusCode = e.response?.statusCode;
          final data = e.response?.data;
          if (statusCode == 401) {
            _errorMsg = 'Email atau kata sandi salah.';
          } else if (statusCode == 403) {
            final msg = data is Map ? data['error']?.toString() : null;
            if (msg != null &&
                (msg.contains('disabled') || msg.contains('suspended') ||
                    msg.contains('owner'))) {
              _errorMsg =
                  '🔒 Akun Anda atau toko Anda telah ditangguhkan oleh Super Admin. '
                  'Hubungi administrator untuk informasi lebih lanjut.';
            } else {
              _errorMsg = 'Akses ditolak. Hubungi administrator.';
            }
          } else if (data != null && data is Map && data['error'] != null) {
            _errorMsg = data['error'].toString();
          } else {
            _errorMsg = 'Terjadi kesalahan jaringan atau server.';
          }
        } else {
          _errorMsg = 'Terjadi kesalahan. Silakan coba lagi.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
