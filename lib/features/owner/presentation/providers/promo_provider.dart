import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_db_service.dart';

final promoProvider = StateNotifierProvider<PromoNotifier, List<dynamic>>((ref) {
  final localDb = ref.watch(localDbProvider);
  return PromoNotifier(localDb);
});

class PromoNotifier extends StateNotifier<List<dynamic>> {
  final LocalDbService _localDb;

  PromoNotifier(this._localDb) : super(_localDb.getPromos());

  Future<void> addPromo(Map<String, dynamic> promo) async {
    final newState = [...state, promo];
    await _localDb.savePromos(newState);
    state = newState;
  }

  Future<void> updatePromo(String id, Map<String, dynamic> updatedPromo) async {
    final newState = state.map((p) => p['id'] == id ? updatedPromo : p).toList();
    await _localDb.savePromos(newState);
    state = newState;
  }

  Future<void> deletePromo(String id) async {
    final newState = state.where((p) => p['id'] != id).toList();
    await _localDb.savePromos(newState);
    state = newState;
  }
}
