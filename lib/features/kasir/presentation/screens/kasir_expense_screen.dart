import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/expense_provider.dart';

class KasirExpenseScreen extends ConsumerStatefulWidget {
  const KasirExpenseScreen({super.key});

  @override
  ConsumerState<KasirExpenseScreen> createState() => _KasirExpenseScreenState();
}

class _KasirExpenseScreenState extends ConsumerState<KasirExpenseScreen> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _saveExpense() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nominal harus lebih dari 0')));
        return;
      }

      final expense = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'description': _descController.text,
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
      };

      ref.read(expenseProvider.notifier).addExpense(expense);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengeluaran berhasil dicatat')));
      _descController.clear();
      _amountController.clear();
      // Optional: context.pop() if it's meant to close after adding
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseProvider);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final todayExpenses = expenses.where((e) => e['date'].toString().startsWith(todayStr)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catat Pengeluaran (Kas Keluar)'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: AppTheme.surfaceDark,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Tambah Pengeluaran Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descController,
                          decoration: const InputDecoration(labelText: 'Keterangan (misal: Beli Es Batu)'),
                          validator: (val) => val == null || val.isEmpty ? 'Keterangan wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Nominal (Rp)', prefixIcon: Icon(Icons.money)),
                          validator: (val) => val == null || val.isEmpty ? 'Nominal wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _saveExpense,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                          child: const Text('Catat Kas Keluar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: todayExpenses.isEmpty
                  ? const Center(child: Text('Belum ada pengeluaran hari ini', style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: todayExpenses.length,
                      itemBuilder: (context, index) {
                        final e = todayExpenses[index];
                        final timeStr = e['date'].toString().substring(11, 16);
                        return Card(
                          color: AppTheme.surfaceDark,
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.arrow_downward, color: Colors.white)),
                            title: Text(e['description'], style: const TextStyle(color: Colors.white)),
                            subtitle: Text(timeStr, style: const TextStyle(color: AppTheme.textSecondary)),
                            trailing: Text('- ${CurrencyFormatter.format(e['amount'])}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
