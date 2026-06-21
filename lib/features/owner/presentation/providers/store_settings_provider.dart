import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_db_service.dart';

final storeSettingsProvider = StateNotifierProvider<StoreSettingsNotifier, Map<String, dynamic>>((ref) {
  final localDb = ref.watch(localDbProvider);
  return StoreSettingsNotifier(localDb);
});

class StoreSettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  final LocalDbService _localDb;

  StoreSettingsNotifier(this._localDb) : super(_localDb.getStoreSettings());

  Future<void> saveSettings({required String name, required String address, required String phone}) async {
    final newData = {
      'name': name,
      'address': address,
      'phone': phone,
    };
    await _localDb.saveStoreSettings(newData);
    state = newData;
  }
}
