import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_db_service.dart';

final expenseProvider = StateNotifierProvider<ExpenseNotifier, List<dynamic>>((ref) {
  final localDb = ref.watch(localDbProvider);
  return ExpenseNotifier(localDb);
});

class ExpenseNotifier extends StateNotifier<List<dynamic>> {
  final LocalDbService _localDb;

  ExpenseNotifier(this._localDb) : super(_localDb.getExpenses());

  Future<void> addExpense(Map<String, dynamic> expense) async {
    await _localDb.saveExpense(expense);
    state = _localDb.getExpenses();
  }
}
