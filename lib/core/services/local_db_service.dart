import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final localDbProvider = Provider<LocalDbService>((ref) {
  return LocalDbService(ref.watch(sharedPreferencesProvider));
});

class LocalDbService {
  static const String keyMenus = 'local_menus';
  static const String keyPendingTransactions = 'pending_transactions';

  final SharedPreferences prefs;

  LocalDbService(this.prefs);

  Future<void> saveMenus(List<dynamic> menus) async {
    await prefs.setString(keyMenus, jsonEncode(menus));
  }

  List<dynamic> getMenus() {
    final str = prefs.getString(keyMenus);
    if (str != null) {
      return jsonDecode(str) as List<dynamic>;
    }
    return [];
  }

  Future<void> savePendingTransaction(Map<String, dynamic> tx) async {
    final list = getPendingTransactions();
    list.add(tx);
    await prefs.setString(keyPendingTransactions, jsonEncode(list));
  }

  List<dynamic> getPendingTransactions() {
    final str = prefs.getString(keyPendingTransactions);
    if (str != null) {
      return jsonDecode(str) as List<dynamic>;
    }
    return [];
  }

  Future<void> clearPendingTransactions() async {
    await prefs.remove(keyPendingTransactions);
  }
}
