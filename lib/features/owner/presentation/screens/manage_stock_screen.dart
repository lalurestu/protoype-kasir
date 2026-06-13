// lib/features/owner/presentation/screens/manage_stock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/stock_model.dart';

final stockProvider = FutureProvider.autoDispose<List<StockModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/owner/stock');
  final List data = response.data as List;
  return data.map((json) => StockModel.fromJson(json as Map<String, dynamic>)).toList();
});

class ManageStockScreen extends ConsumerStatefulWidget {
  const ManageStockScreen({super.key});

  @override
  ConsumerState<ManageStockScreen> createState() => _ManageStockScreenState();
}

class _ManageStockScreenState extends ConsumerState<ManageStockScreen> {
  String _searchQuery = '';
  String _filterCategory = 'semua';

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Stok', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(stockProvider),
          ),
        ],
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: stockAsync.when(
        data: (stocks) {
          final lowStockCount = stocks.where((s) => s.isLowStock).length;
          final outOfStockCount = stocks.where((s) => s.isOutOfStock).length;

          // Filter
          var filtered = stocks.where((s) {
            final matchSearch = _searchQuery.isEmpty ||
                s.menuName.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchCategory = _filterCategory == 'semua' ||
                s.menuCategory.toLowerCase() == _filterCategory;
            return matchSearch && matchCategory;
          }).toList();

          return Column(
            children: [
              // Alert banner
              if (lowStockCount > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$lowStockCount item stok menipis${outOfStockCount > 0 ? ', $outOfStockCount item habis!' : ''}',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            const Text('Segera lakukan restok untuk menghindari kehabisan produk',
                                style: TextStyle(color: Colors.orange, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Search + Filter
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari nama menu...',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                        hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['semua', 'makanan', 'minuman', 'snack'].map((cat) {
                          final isSelected = _filterCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat[0].toUpperCase() + cat.substring(1)),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _filterCategory = cat),
                              backgroundColor: AppTheme.surfaceDark,
                              selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                              labelStyle: TextStyle(
                                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primaryColor : const Color(0xFF334155),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Stock list
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('Tidak ada item ditemukan',
                            style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final stock = filtered[index];
                          return _buildStockCard(stock);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
              const SizedBox(height: 16),
              Text('Error: $e', style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(stockProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockCard(StockModel stock) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (stock.isOutOfStock) {
      statusColor = AppTheme.error;
      statusText = 'HABIS';
      statusIcon = Icons.cancel;
    } else if (stock.isLowStock) {
      statusColor = Colors.orange;
      statusText = 'MENIPIS';
      statusIcon = Icons.warning_amber;
    } else {
      statusColor = AppTheme.secondaryColor;
      statusText = 'AMAN';
      statusIcon = Icons.check_circle;
    }

    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fastfood, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stock.menuName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(stock.menuCategory.toUpperCase(),
                                style: const TextStyle(
                                    color: AppTheme.primaryColor, fontSize: 10)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rp ${stock.menuPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stock gauge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stok: ${stock.quantity}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          Text('Min: ${stock.minStock}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: stock.minStock > 0
                            ? (stock.quantity / (stock.minStock * 3)).clamp(0.0, 1.0)
                            : 0,
                        backgroundColor: AppTheme.backgroundDark,
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Quick action buttons
                Row(
                  children: [
                    _buildAdjustButton(
                      icon: Icons.remove,
                      color: AppTheme.error,
                      onTap: () => _adjustStock(stock, 'subtract'),
                    ),
                    const SizedBox(width: 8),
                    _buildAdjustButton(
                      icon: Icons.add,
                      color: AppTheme.secondaryColor,
                      onTap: () => _adjustStock(stock, 'add'),
                    ),
                    const SizedBox(width: 8),
                    _buildAdjustButton(
                      icon: Icons.edit,
                      color: AppTheme.primaryColor,
                      onTap: () => _showEditStockDialog(stock),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Future<void> _adjustStock(StockModel stock, String action) async {
    final controller = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(action == 'add' ? 'Tambah Stok' : 'Kurangi Stok',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${stock.menuName}\nStok saat ini: ${stock.quantity}',
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Jumlah',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(
                    action == 'add' ? Icons.add : Icons.remove,
                    color: action == 'add' ? AppTheme.secondaryColor : AppTheme.error),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  action == 'add' ? AppTheme.secondaryColor : AppTheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text) ?? 0),
            child: Text(action == 'add' ? 'Tambah' : 'Kurangi'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      try {
        final dio = ref.read(dioProvider);
        await dio.post('/owner/stock/${stock.menuId}/$action', data: {'amount': result});
        ref.invalidate(stockProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Stok ${stock.menuName} berhasil ${action == 'add' ? 'ditambah' : 'dikurangi'} $result'),
            backgroundColor: AppTheme.secondaryColor,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.error));
        }
      }
    }
  }

  Future<void> _showEditStockDialog(StockModel stock) async {
    final qtyController = TextEditingController(text: stock.quantity.toString());
    final minController = TextEditingController(text: stock.minStock.toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Edit Stok', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stock.menuName,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Stok Sekarang',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.inventory, color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Batas Minimum Stok',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.warning_amber, color: Colors.orange),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final dio = ref.read(dioProvider);
                await dio.put('/owner/stock/${stock.menuId}', data: {
                  'quantity': int.tryParse(qtyController.text) ?? stock.quantity,
                  'min_stock': int.tryParse(minController.text) ?? stock.minStock,
                });
                ref.invalidate(stockProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Stok berhasil diperbarui'),
                    backgroundColor: AppTheme.secondaryColor,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.error));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
