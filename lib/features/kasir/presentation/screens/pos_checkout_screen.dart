import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/menu_model.dart';
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart';
import '../../../../core/network/api_client.dart';

class PosCheckoutScreen extends ConsumerStatefulWidget {
  const PosCheckoutScreen({super.key});

  @override
  ConsumerState<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends ConsumerState<PosCheckoutScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final menusAsync = ref.watch(menusProvider);
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    final totalAmount = cartItems.fold(0.0, (sum, item) => sum + (item.menu.price * item.quantity));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: Row(
        children: [
          // Left Pane: Products Grid
          Expanded(
            flex: 2,
            child: Container(
              color: AppTheme.backgroundDark,
              padding: const EdgeInsets.all(24),
              child: menusAsync.when(
                data: (menus) {
                  if (menus.isEmpty) {
                    return const Center(child: Text('No menus available'));
                  }
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: menus.length,
                    itemBuilder: (context, index) {
                      final menu = menus[index];
                      return InkWell(
                        onTap: () => cartNotifier.addItem(menu),
                        borderRadius: BorderRadius.circular(16),
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
                                    Text(menu.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('Rp ${menu.price}', style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error loading menus: $e')),
              ),
            ),
          ),
          
          // Right Pane: Cart Summary
          Container(
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
                  child: const Text('Current Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: cartItems.isEmpty
                      ? const Center(child: Text('Cart is empty', style: TextStyle(color: AppTheme.textSecondary)))
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
                          onPressed: (cartItems.isEmpty || _isProcessing) ? null : () => _processCheckout(totalAmount),
                          child: _isProcessing 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Process Payment', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processCheckout(double total) async {
    setState(() => _isProcessing = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/checkout', data: {
        'total_amount': total,
      });
      ref.read(cartProvider.notifier).clearCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Successful!'), backgroundColor: AppTheme.secondaryColor),
        );
      }
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
