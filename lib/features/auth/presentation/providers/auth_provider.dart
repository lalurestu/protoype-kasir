import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/user_role.dart';

// Provides SecureStorage instance
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(const FlutterSecureStorage());
});

class AuthState {
  final bool isAuthenticated;
  final bool isPinVerified;
  final UserRole role;

  AuthState({
    required this.isAuthenticated,
    required this.isPinVerified,
    required this.role,
  });

  factory AuthState.initial() {
    return AuthState(isAuthenticated: false, isPinVerified: false, role: UserRole.guest);
  }

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isPinVerified,
    UserRole? role,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isPinVerified: isPinVerified ?? this.isPinVerified,
      role: role ?? this.role,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SecureStorage _storage;
  final Dio _dio;

  AuthNotifier(this._storage, this._dio) : super(AuthState.initial()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _storage.getToken();
    if (token != null) {
      try {
        final response = await _dio.get('/auth/me');
        final roleStr = response.data['role'] as String;
        final role = _parseRole(roleStr);
        state = AuthState(isAuthenticated: true, isPinVerified: false, role: role);
      } catch (e) {
        await logout();
      }
    }
  }

  UserRole _parseRole(String role) {
    switch (role) {
      case 'owner': return UserRole.owner;
      case 'kasir': return UserRole.kasir;
      case 'super_admin': return UserRole.superAdmin;
      default: return UserRole.guest;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      final token = response.data['access_token'];
      final roleStr = response.data['user']['role'];
      
      await _storage.saveToken(token);
      state = AuthState(isAuthenticated: true, isPinVerified: false, role: _parseRole(roleStr));
    } on DioException catch (e) {
      throw Exception('DioError: ${e.message} | Response: ${e.response?.data}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    await _storage.deleteToken();
    state = AuthState.initial();
  }

  void verifyPin() {
    state = state.copyWith(isPinVerified: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = ref.watch(dioProvider);
  return AuthNotifier(storage, dio);
});
