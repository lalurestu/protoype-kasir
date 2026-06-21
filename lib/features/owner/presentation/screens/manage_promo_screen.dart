import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/promo_provider.dart';

class ManagePromoScreen extends ConsumerStatefulWidget {
  const ManagePromoScreen({super.key});

  @override
  ConsumerState<ManagePromoScreen> createState() => _ManagePromoScreenState();
}

class _ManagePromoScreenState extends ConsumerState<ManagePromoScreen> {
  void _showPromoDialog({Map<String, dynamic>? promo}) {
    final isEdit = promo != null;
    final nameController = TextEditingController(text: promo?['name']);
    final valueController = TextEditingController(text: promo?['value']?.toString());
    String type = promo?['type'] ?? 'nominal'; // 'nominal' or 'percent'

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Edit Promo' : 'Tambah Promo Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Promo (misal: Diskon Merdeka)'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Tipe Diskon'),
                  items: const [
                    DropdownMenuItem(value: 'nominal', child: Text('Nominal (Rp)')),
                    DropdownMenuItem(value: 'percent', child: Text('Persentase (%)')),
                  ],
                  onChanged: (val) => setState(() => type = val!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nilai Diskon'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(valueController.text);
                if (nameController.text.isEmpty || val == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isian tidak valid')));
                  return;
                }
                
                final newPromo = {
                  'id': isEdit ? promo['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': nameController.text,
                  'type': type,
                  'value': val,
                  'is_active': promo?['is_active'] ?? true,
                };

                if (isEdit) {
                  ref.read(promoProvider.notifier).updatePromo(promo['id'], newPromo);
                } else {
                  ref.read(promoProvider.notifier).addPromo(newPromo);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final promos = ref.watch(promoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Promo'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPromoDialog(),
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: promos.isEmpty
            ? const Center(child: Text('Belum ada promo. Silakan tambah promo baru.', style: TextStyle(color: Colors.white)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: promos.length,
                itemBuilder: (context, index) {
                  final p = promos[index];
                  final isPercent = p['type'] == 'percent';
                  final valStr = isPercent ? '${p['value']}%' : 'Rp ${p['value']}';
                  
                  return Card(
                    color: AppTheme.surfaceDark,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text('Potongan: $valStr', style: const TextStyle(color: AppTheme.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: p['is_active'] ?? true,
                            onChanged: (val) {
                              final updated = Map<String, dynamic>.from(p)..['is_active'] = val;
                              ref.read(promoProvider.notifier).updatePromo(p['id'], updated);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showPromoDialog(promo: p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppTheme.error),
                            onPressed: () => ref.read(promoProvider.notifier).deletePromo(p['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
