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
  static const String keyStoreSettings = 'store_settings';
  static const String keyPromos = 'promos';
  static const String keyExpenses = 'expenses';
  static const String keyOpenBills = 'open_bills';
  static const String keyBranches = 'branches';
  static const String keyActiveBranch = 'active_branch';
  static const String keyLicense = 'license_info';
  static const String keyOwnerPin = 'owner_pin';
  static const String keyKasirPin = 'kasir_pin';
  static const String keyOwnerRecoveryContact = 'owner_recovery_contact';

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

  Future<void> saveStoreSettings(Map<String, dynamic> data) async {
    await prefs.setString(keyStoreSettings, jsonEncode(data));
  }

  Map<String, dynamic> getStoreSettings() {
    final str = prefs.getString(keyStoreSettings);
    if (str != null) {
      return jsonDecode(str) as Map<String, dynamic>;
    }
    // Default fallback
    return {
      'name': 'TOKO KASIR',
      'address': 'Alamat Toko Belum Diatur',
      'phone': '0812xxxxxx',
      'tax_percent': 0.0,
      'service_percent': 0.0,
    };
  }

  Future<void> savePromos(List<dynamic> promos) async {
    await prefs.setString(keyPromos, jsonEncode(promos));
  }

  List<dynamic> getPromos() {
    final str = prefs.getString(keyPromos);
    if (str != null) {
      return jsonDecode(str) as List<dynamic>;
    }
    return [];
  }

  Future<void> saveExpense(Map<String, dynamic> expense) async {
    final list = getExpenses();
    list.add(expense);
    await prefs.setString(keyExpenses, jsonEncode(list));
  }

  List<dynamic> getExpenses() {
    final str = prefs.getString(keyExpenses);
    if (str != null) {
      return jsonDecode(str) as List<dynamic>;
    }
    return [];
  }

  Future<void> saveOpenBill(Map<String, dynamic> bill) async {
    final list = getOpenBills();
    // remove if exists
    list.removeWhere((b) => b['id'] == bill['id']);
    list.add(bill);
    await prefs.setString(keyOpenBills, jsonEncode(list));
  }

  List<dynamic> getOpenBills() {
    final str = prefs.getString(keyOpenBills);
    if (str != null) {
      return jsonDecode(str) as List<dynamic>;
    }
    return [];
  }

  Future<void> deleteOpenBill(String id) async {
    final list = getOpenBills();
    list.removeWhere((b) => b['id'] == id);
    await prefs.setString(keyOpenBills, jsonEncode(list));
  }

  // --- Branch Management ---
  Future<void> saveBranches(List<Map<String, dynamic>> branches) async {
    await prefs.setString(keyBranches, jsonEncode(branches));
  }

  List<Map<String, dynamic>> getBranches() {
    final str = prefs.getString(keyBranches);
    if (str != null) {
      final list = jsonDecode(str) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    return [
      {'id': 1, 'name': 'Cabang Pusat'}
    ];
  }

  Future<void> setActiveBranch(int id) async {
    await prefs.setInt(keyActiveBranch, id);
  }

  int getActiveBranch() {
    return prefs.getInt(keyActiveBranch) ?? 1;
  }

  // --- License Management ---
  Future<void> saveLicenseInfo(Map<String, dynamic> info) async {
    await prefs.setString(keyLicense, jsonEncode(info));
  }

  Map<String, dynamic>? getLicenseInfo() {
    final str = prefs.getString(keyLicense);
    if (str != null) {
      return jsonDecode(str) as Map<String, dynamic>;
    }
    return null;
  }

  // --- PIN Management ---
  Future<void> saveOwnerPin(String pin) async {
    await prefs.setString(keyOwnerPin, pin);
  }

  String getOwnerPin() {
    return prefs.getString(keyOwnerPin) ?? '123456';
  }

  Future<void> saveKasirPin(String pin) async {
    await prefs.setString(keyKasirPin, pin);
  }

  String getKasirPin() {
    return prefs.getString(keyKasirPin) ?? '000000';
  }

  Future<void> saveOwnerRecoveryContact(String contact) async {
    await prefs.setString(keyOwnerRecoveryContact, contact);
  }

  String? getOwnerRecoveryContact() {
    return prefs.getString(keyOwnerRecoveryContact);
  }
}
