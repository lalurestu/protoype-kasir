import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../kasir/presentation/providers/menu_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/currency_formatter.dart';

class ManageMenuScreen extends ConsumerStatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  ConsumerState<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends ConsumerState<ManageMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _cogsController = TextEditingController();
  final _variantsController = TextEditingController();
  final _addonsController = TextEditingController();
  String _selectedCategory = 'makanan';
  bool _isAvailable = true;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _cogsController.dispose();
    _variantsController.dispose();
    _addonsController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseOptions(String text) {
    if (text.trim().isEmpty) return [];
    return text.split(',').map((e) {
      final parts = e.split(':');
      if (parts.length == 2) {
        return {'name': parts[0].trim(), 'price': double.tryParse(parts[1].trim()) ?? 0};
      }
      return {'name': e.trim(), 'price': 0};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final menusAsync = ref.watch(menusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Menu'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: menusAsync.when(
        data: (menus) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (menus.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Belum ada menu.', style: TextStyle(color: AppTheme.textSecondary)),
                ))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: menus.length,
                  itemBuilder: (context, index) {
                    final menu = menus[index];
                    return Card(
                      color: AppTheme.surfaceDark,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(menu.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(CurrencyFormatter.format(menu.price), style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: Text(menu.category.toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10)),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showMenuDialog(context, ref, menu: menu),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppTheme.error),
                              onPressed: () => _deleteMenu(context, ref, menu.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMenuDialog(context, ref),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Menu Baru'),
      ),
    );
  }

  Future<void> _deleteMenu(BuildContext context, WidgetRef ref, int menuId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Hapus Menu', style: TextStyle(color: Colors.white)),
        content: const Text('Yakin mau menghapus menu ini?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dio = ref.read(dioProvider);
      try {
        await dio.delete('/menus/$menuId');
        ref.invalidate(menusProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menu dihapus', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
        }
      }
    }
  }

  void _showMenuDialog(BuildContext context, WidgetRef ref, {dynamic menu}) {
    if (menu != null) {
      _nameController.text = menu.name;
      _priceController.text = menu.price.toString();
      _cogsController.text = menu.cogs?.toString() ?? '';
      _selectedCategory = menu.category;
      _isAvailable = menu.isAvailable;
      _variantsController.text = (menu.variants as List?)?.map((v) => '${v.name}:${v.price.toInt()}').join(', ') ?? '';
      _addonsController.text = (menu.addons as List?)?.map((a) => '${a.name}:${a.price.toInt()}').join(', ') ?? '';
    } else {
      _nameController.clear();
      _priceController.clear();
      _cogsController.clear();
      _variantsController.clear();
      _addonsController.clear();
      _selectedCategory = 'makanan';
      _isAvailable = true;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              title: Text(menu == null ? 'Tambah Menu' : 'Ubah Menu', style: const TextStyle(color: Colors.white)),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Nama Menu', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                      validator: (val) => val == null || val.isEmpty ? 'Isi kolom ini' : null,
                    ),
                    TextFormField(
                      controller: _priceController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Harga Jual (Rp)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Isi kolom ini' : null,
                    ),
                    TextFormField(
                      controller: _cogsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Harga Modal / HPP (Rp)', labelStyle: TextStyle(color: AppTheme.textSecondary), helperText: 'Opsional: Digunakan untuk laporan Laba/Rugi.'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: AppTheme.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Kategori', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                      items: const [
                        DropdownMenuItem(value: 'makanan', child: Text('Makanan')),
                        DropdownMenuItem(value: 'minuman', child: Text('Minuman')),
                        DropdownMenuItem(value: 'snack', child: Text('Snack')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => _selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _variantsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Varian (cth: Medium:0, Large:5000)', labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addonsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Topping (cth: Keju:3000, Boba:4000)', labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                    SwitchListTile(
                      title: const Text('Tersedia', style: TextStyle(color: Colors.white)),
                      value: _isAvailable,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) => setStateDialog(() => _isAvailable = val),
                    ),
                  ],
                ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final dio = ref.read(dioProvider);
                      try {
                        if (menu == null) {
                          await dio.post('/menus', data: {
                            'name': _nameController.text,
                            'price': double.parse(_priceController.text),
                            'cogs': _cogsController.text.isNotEmpty ? double.parse(_cogsController.text) : null,
                            'category': _selectedCategory,
                            'is_available': _isAvailable,
                            'variants': _parseOptions(_variantsController.text),
                            'addons': _parseOptions(_addonsController.text),
                          });
                        } else {
                          await dio.put('/menus/${menu.id}', data: {
                            'name': _nameController.text,
                            'price': double.parse(_priceController.text),
                            'cogs': _cogsController.text.isNotEmpty ? double.parse(_cogsController.text) : null,
                            'category': _selectedCategory,
                            'is_available': _isAvailable,
                            'variants': _parseOptions(_variantsController.text),
                            'addons': _parseOptions(_addonsController.text),
                          });
                        }
                        ref.invalidate(menusProvider);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
                        }
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}
