import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/menu_model.dart';
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/local_db_service.dart';

class PosCheckoutScreen extends ConsumerStatefulWidget {
  const PosCheckoutScreen({super.key});

  @override
  ConsumerState<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends ConsumerState<PosCheckoutScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalItems = cartItems.fold(0, (sum, item) => sum + item.quantity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pembayaran'),
            backgroundColor: AppTheme.surfaceDark,
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                label: const Text('Kosongkan Keranjang', style: TextStyle(color: AppTheme.error)),
                onPressed: () => ref.read(cartProvider.notifier).clearCart(),
              ),
              const SizedBox(width: 16),
              if (!isDesktop)
                Builder(
                  builder: (context) => IconButton(
                    icon: Badge(
                      isLabelVisible: totalItems > 0,
                      label: Text('$totalItems'),
                      child: const Icon(Icons.shopping_cart),
                    ),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ),
            ],
          ),
          endDrawer: !isDesktop ? Drawer(
            child: SafeArea(child: _buildCartPane()),
          ) : null,
          body: isDesktop
              ? Row(
                  children: [
                    Expanded(flex: 2, child: _buildMenusPane()),
                    _buildCartPane(),
                  ],
                )
              : _buildMenusPane(),
        );
      },
    );
  }

  Widget _buildMenusPane() {
    final menusAsync = ref.watch(menusProvider);
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    
    return Container(
      color: AppTheme.backgroundDark,
      padding: const EdgeInsets.all(16),
      child: menusAsync.when(
        data: (menus) {
          if (menus.isEmpty) return const Center(child: Text('Menu tidak tersedia'));
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: menus.length,
            itemBuilder: (context, index) {
              final menu = menus[index];
              final cartItemIndex = cartItems.indexWhere((item) => item.menu.id == menu.id);
              final quantity = cartItemIndex >= 0 ? cartItems[cartItemIndex].quantity : 0;

              return InkWell(
                onTap: () => cartNotifier.addItem(menu),
                borderRadius: BorderRadius.circular(16),
                child: Badge(
                  isLabelVisible: quantity > 0,
                  label: Text('$quantity', style: const TextStyle(fontSize: 14)),
                  backgroundColor: AppTheme.secondaryColor,
                  offset: const Offset(-12, 12),
                  child: Card(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: const Icon(Icons.fastfood, size: 48, color: AppTheme.primaryColor),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(menu.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('Rp ${menu.price}', style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error memuat menu: $e')),
      ),
    );
  }

  Widget _buildCartPane() {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final totalAmount = cartItems.fold(0.0, (sum, item) => sum + (item.menu.price * item.quantity));

    return Container(
      width: 350,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(left: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            color: AppTheme.primaryColor.withOpacity(0.1),
            child: const Text('Pesanan Saat Ini', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: cartItems.isEmpty
                ? const Center(child: Text('Keranjang kosong', style: TextStyle(color: AppTheme.textSecondary)))
                : ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return ListTile(
                        title: Text(item.menu.name),
                        subtitle: Text('Rp ${item.menu.price} x ${item.quantity}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.textSecondary),
                              onPressed: () => cartNotifier.removeItem(item.menu.id),
                            ),
                            Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                              onPressed: () => cartNotifier.addItem(item.menu),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Rp $totalAmount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (cartItems.isEmpty || _isProcessing) ? null : () => _showPaymentDialog(context, totalAmount),
                    child: _isProcessing 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Proses Pembayaran', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, double totalAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Metode Pembayaran', style: TextStyle(color: Colors.white)),
        content: const Text('Metode apa yang digunakan pelanggan untuk membayar pesanan ini?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processCheckout(totalAmount, 'cash');
            },
            child: const Text('TUNAI', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              Navigator.pop(context);
              _processCheckout(totalAmount, 'qris');
            },
            child: const Text('QRIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _processCheckout(double total, String paymentMethod) async {
    setState(() => _isProcessing = true);
    try {
      final dio = ref.read(dioProvider);
      final localDb = ref.read(localDbProvider);
      final cartItems = ref.read(cartProvider);
      
      final itemsData = cartItems.map((item) => {
        'menu_id': item.menu.id,
        'quantity': item.quantity,
        'price': item.menu.price,
      }).toList();

      final txData = {
        'total_amount': total,
        'payment_method': paymentMethod,
        'items': itemsData,
        'created_at': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
      };

      try {
        await dio.post('/checkout', data: txData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pembayaran Berhasil! (Online)'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        await localDb.savePendingTransaction(txData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sinyal Hilang! Pembayaran Disimpan ke Offline Queue.'), backgroundColor: Colors.orange),
          );
        }
      }

      ref.read(cartProvider.notifier).clearCart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
