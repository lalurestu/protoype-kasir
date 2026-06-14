import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'dio_interceptor.dart';

String _getBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost/protoype-kasir/api';
  }
  if (Platform.isAndroid) {
    // 10.0.2.2 is the special alias for your host machine's localhost in the Android Emulator.
    // If you are testing on a PHYSICAL Android device, you must change this to your computer's actual Wi-Fi IP (e.g., 192.168.1.X)
    return 'http://192.168.1.2/protoype-kasir/api';
  } else if (Platform.isIOS) {
    // iOS simulator uses localhost directly
    return 'http://localhost/protoype-kasir/api';
  }
  // Fallback for physical devices or other platforms. Make sure this is your PC's current IP address.
  return 'http://192.168.1.2/protoype-kasir/api';
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _getBaseUrl(),
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
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
