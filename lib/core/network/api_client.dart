import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'dio_interceptor.dart';

String _getBaseUrl() {
  // Using localtunnel public URL for cross-network testing
  return 'https://eleven-ghosts-clap.loca.lt/protoype-kasir/api';
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _getBaseUrl(),
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Bypass-Tunnel-Reminder': 'true', // Required to bypass localtunnel warning page
      },
    ),
  );

  final secureStorage = ref.watch(secureStorageProvider);
  dio.interceptors.add(AuthInterceptor(secureStorage));

  // Add logging in dev mode
  dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

  return dio;
});
