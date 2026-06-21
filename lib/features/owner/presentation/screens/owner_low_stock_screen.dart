// lib/features/owner/presentation/screens/owner_low_stock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/menu_model.dart';
import '../../../../core/services/local_db_service.dart';

class OwnerLowStockScreen extends ConsumerStatefulWidget {
  const OwnerLowStockScreen({super.key});

  @override
  ConsumerState<OwnerLowStockScreen> createState() => _OwnerLowStockScreenState();
}

class _OwnerLowStockScreenState extends ConsumerState<OwnerLowStockScreen> {
  List<MenuModel> _lowStockItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLowStockItems();
  }

  Future<void> _fetchLowStockItems() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/menus');
      final data = res.data;
      if (data != null && data['data'] != null) {
        final List menus = data['data'];
        final List<MenuModel> parsed = menus.map((m) => MenuModel.fromJson(m)).toList();
        
        // Filter those with low stock
        _lowStockItems = parsed.where((m) => m.isLowStock).toList();
      } else {
        // Fallback local DB
        final local = ref.read(localDbProvider).getMenus();
        final parsed = local.map((m) => MenuModel.fromJson(m)).toList();
        _lowStockItems = parsed.where((m) => m.isLowStock).toList();
      }
    } catch (e) {
      // Fallback local DB
      final local = ref.read(localDbProvider).getMenus();
      final parsed = local.map((m) => MenuModel.fromJson(m)).toList();
      _lowStockItems = parsed.where((m) => m.isLowStock).toList();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Peringatan Stok Menipis'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lowStockItems.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.inventory_2_outlined, size: 80, color: AppTheme.textSecondary),
          SizedBox(height: 16),
          Text(
            'Stok Aman',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Tidak ada item menu yang stoknya menipis.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lowStockItems.length,
      itemBuilder: (context, index) {
        final item = _lowStockItems[index];
        return Card(
          color: AppTheme.surfaceDark,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            ),
            title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Sisa Stok: ${item.stock}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            trailing: Text('Min: ${item.minStock}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
        );
      },
    );
  }
}
