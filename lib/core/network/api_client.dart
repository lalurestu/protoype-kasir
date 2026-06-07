import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'dio_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  // Setup Base URL otomatis buat Emulator (10.0.2.2) atau Windows/Web (127.0.0.1)
  // Berhubung pake XAMPP, portnya biasanya 80 dan pathnya /protoype-kasir/api/
  String baseUrl = 'http://127.0.0.1/protoype-kasir/api';
  try {
    if (Platform.isAndroid) {
      baseUrl = 'http://10.0.2.2/protoype-kasir/api';
    }
  } catch (e) {
    // Kalo jalan di Web, biarin pake 127.0.0.1 atau domain aslinya
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      headers: {'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  final secureStorage = ref.watch(secureStorageProvider);
  dio.interceptors.add(AuthInterceptor(secureStorage));
  
  // Add logging in dev mode
  dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

  return dio;
});
