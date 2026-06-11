import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFF334155), width: 1),
                ),
                color: AppTheme.surfaceDark.withOpacity(0.8),
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.storefront,
                            size: 64, color: AppTheme.primaryColor),
                        const SizedBox(height: 24),
                        const Text(
                          'Selamat Datang',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Masuk untuk melanjutkan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 32),
                        if (_errorMsg != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                            child: Text(
                              _errorMsg!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        TextField(
                          controller: _emailCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Alamat Email',
                            labelStyle:
                                const TextStyle(color: AppTheme.textSecondary),
                            prefixIcon: const Icon(Icons.email_outlined,
                                color: AppTheme.textSecondary),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color:
                                      AppTheme.primaryColor.withOpacity(0.3)),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Kata Sandi',
                            labelStyle:
                                const TextStyle(color: AppTheme.textSecondary),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppTheme.textSecondary),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color:
                                      AppTheme.primaryColor.withOpacity(0.3)),
                            ),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Masuk',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                          ),
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
    );
  }

  Future<void> _handleLogin() async {
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
          if (e.response?.statusCode == 401) {
            _errorMsg = 'Email atau kata sandi salah.';
          } else if (e.response?.data != null &&
              e.response?.data is Map &&
              e.response!.data['error'] != null) {
            _errorMsg = e.response!.data['error'].toString();
          } else {
            _errorMsg = 'Terjadi kesalahan jaringan atau server.';
          }
        } else {
          _errorMsg = e.toString();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
