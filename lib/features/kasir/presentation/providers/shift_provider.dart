// lib/features/kasir/presentation/providers/shift_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/models/shift_model.dart';

// Provider untuk shift aktif kasir saat ini
final currentShiftProvider = FutureProvider.autoDispose<ShiftModel?>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/shifts/current');
    if (response.data != null && response.data is Map) {
      return ShiftModel.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
});

// Provider untuk daftar shift owner
final ownerShiftsProvider = FutureProvider.autoDispose<List<ShiftModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/owner/shifts');
  final List data = response.data as List;
  return data.map((json) => ShiftModel.fromJson(json as Map<String, dynamic>)).toList();
});

// Notifier untuk aksi buka/tutup shift
class ShiftNotifier extends StateNotifier<AsyncValue<ShiftModel?>> {
  final Dio _dio;
  final NotificationService _notificationService;
  ShiftNotifier(this._dio, this._notificationService) : super(const AsyncValue.loading());

  Future<void> loadCurrentShift() async {
    state = const AsyncValue.loading();
    try {
      final response = await _dio.get('/shifts/current');
      if (response.data != null && response.data is Map) {
        state = AsyncValue.data(ShiftModel.fromJson(response.data as Map<String, dynamic>));
      } else {
        state = const AsyncValue.data(null);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(e, e.stackTrace ?? StackTrace.current);
      }
    }
  }

  Future<ShiftModel> openShift(double openingCash) async {
    final response = await _dio.post('/shifts/open', data: {
      'opening_cash': openingCash,
    });
    final shift = ShiftModel.fromJson(response.data['shift'] as Map<String, dynamic>);
    state = AsyncValue.data(shift);
    
    // Trigger local notification for shift open
    _notificationService.showShiftNotification(shift.kasirName ?? 'Kasir', 'open');
    
    return shift;
  }

  Future<ShiftModel> closeShift(int shiftId, double closingCash, String? note) async {
    final response = await _dio.post('/shifts/close', data: {
      'shift_id': shiftId,
      'closing_cash': closingCash,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final shift = ShiftModel.fromJson(response.data['shift'] as Map<String, dynamic>);
    state = const AsyncValue.data(null);
    
    // Trigger local notification for shift close
    _notificationService.showShiftNotification(shift.kasirName ?? 'Kasir', 'close');
    
    return shift;
  }
}

final shiftNotifierProvider =
    StateNotifierProvider<ShiftNotifier, AsyncValue<ShiftModel?>>((ref) {
  return ShiftNotifier(
    ref.read(dioProvider),
    ref.read(notificationServiceProvider),
  );
});
