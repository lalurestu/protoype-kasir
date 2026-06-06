import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../kasir/presentation/providers/menu_provider.dart';
import '../../../../core/network/api_client.dart';

class ManageMenuScreen extends ConsumerStatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  ConsumerState<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends ConsumerState<ManageMenuScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final menusAsync = ref.watch(menusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Menus'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: menusAsync.when(
        data: (menus) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(AppTheme.primaryColor.withOpacity(0.1)),
                  columns: const [
                    DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: menus.map((menu) {
                    return DataRow(cells: [
                      DataCell(Text(menu.name)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.secondaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text(menu.category, style: const TextStyle(color: AppTheme.secondaryColor)),
                      )),
                      DataCell(Text('Rp ${menu.price}')),
                      DataCell(Row(
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () {}),
                          IconButton(icon: const Icon(Icons.delete, color: AppTheme.error), onPressed: () {}),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenuDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Add New Menu'),
      ),
    );
  }

  void _showAddMenuDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Add New Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Menu Name')),
            const SizedBox(height: 16),
            TextField(controller: _priceCtrl, decoration: const InputDecoration(labelText: 'Price (Rp)'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            TextField(controller: _categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(onPressed: _submitMenu, child: const Text('Save Menu')),
        ],
      ),
    );
  }

  Future<void> _submitMenu() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/menus', data: {
        'name': _nameCtrl.text,
        'price': double.parse(_priceCtrl.text),
        'category': _categoryCtrl.text,
      });
      // Refresh menus
      ref.invalidate(menusProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}
