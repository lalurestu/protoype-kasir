import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'dio_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.2/protoype-kasir/api',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  final secureStorage = ref.watch(secureStorageProvider);
  dio.interceptors.add(AuthInterceptor(secureStorage));
  
  // Add logging in dev mode
  dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

  return dio;
});
