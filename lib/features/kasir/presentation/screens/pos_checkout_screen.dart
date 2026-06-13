// lib/features/kasir/presentation/screens/pos_checkout_screen.dart
// UPDATED: Discount, Tax, Customer CRM, Print Receipt support

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/discount_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/shift_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../core/services/printer_service.dart';
import '../../../../shared/models/customer_model.dart';

class PosCheckoutScreen extends ConsumerStatefulWidget {
  const PosCheckoutScreen({super.key});

  @override
  ConsumerState<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends ConsumerState<PosCheckoutScreen> {
  bool _isProcessing = false;
  Map<String, dynamic>? _lastTransaction;

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
                label: const Text('Kosongkan', style: TextStyle(color: AppTheme.error)),
                onPressed: () {
                  ref.read(cartProvider.notifier).clearCart();
                  ref.read(discountProvider.notifier).reset();
                  ref.read(selectedCustomerProvider.notifier).clear();
                },
              ),
              const SizedBox(width: 8),
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
          endDrawer: !isDesktop
              ? Drawer(child: SafeArea(child: _buildCartPane()))
              : null,
          body: isDesktop
              ? Row(children: [
                  Expanded(flex: 2, child: _buildMenusPane()),
                  _buildCartPane(),
                ])
              : _buildMenusPane(),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────
  // MENUS PANE
  // ──────────────────────────────────────────────────────────
  Widget _buildMenusPane() {
    final menusAsync = ref.watch(menusProvider);
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return Container(
      color: AppTheme.backgroundDark,
      padding: const EdgeInsets.all(16),
      child: menusAsync.when(
        data: (menus) {
          // Only show available menus
          final availableMenus = menus.where((m) => m.isAvailable).toList();
          if (availableMenus.isEmpty) {
            return const Center(child: Text('Menu tidak tersedia'));
          }
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: availableMenus.length,
            itemBuilder: (context, index) {
              final menu = availableMenus[index];
              final cartItemIndex = cartItems.indexWhere((item) => item.menu.id == menu.id);
              final quantity = cartItemIndex >= 0 ? cartItems[cartItemIndex].quantity : 0;
              final isOutOfStock = menu.stock != null && menu.stock! <= 0;

              return InkWell(
                onTap: isOutOfStock ? null : () => cartNotifier.addItem(menu),
                borderRadius: BorderRadius.circular(16),
                child: Badge(
                  isLabelVisible: quantity > 0,
                  label: Text('$quantity', style: const TextStyle(fontSize: 14)),
                  backgroundColor: AppTheme.secondaryColor,
                  offset: const Offset(-12, 12),
                  child: Card(
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: (isOutOfStock
                                          ? Colors.grey
                                          : AppTheme.primaryColor)
                                      .withOpacity(0.1),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                ),
                                child: Icon(
                                  Icons.fastfood,
                                  size: 48,
                                  color: isOutOfStock ? Colors.grey : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(menu.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isOutOfStock ? Colors.grey : Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rp ${menu.price.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        color: isOutOfStock
                                            ? Colors.grey
                                            : AppTheme.secondaryColor,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (menu.stock != null)
                                    Text(
                                      'Stok: ${menu.stock}',
                                      style: TextStyle(
                                          color: menu.isLowStock ? Colors.orange : AppTheme.textSecondary,
                                          fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isOutOfStock)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text('HABIS',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
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

  // ──────────────────────────────────────────────────────────
  // CART PANE
  // ──────────────────────────────────────────────────────────
  Widget _buildCartPane() {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final discount = ref.watch(discountProvider);
    final selectedCustomer = ref.watch(selectedCustomerProvider);

    final subtotal = cartItems.fold(0.0, (sum, item) => sum + (item.menu.price * item.quantity));
    final discountAmount = discount.calculateDiscount(subtotal);
    final taxAmount = discount.calculateTax(subtotal);
    final total = discount.calculateTotal(subtotal);

    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(left: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: AppTheme.primaryColor.withOpacity(0.1),
            child: const Text('Pesanan Saat Ini',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          // Customer section
          _buildCustomerSection(selectedCustomer),

          // Cart items
          Expanded(
            child: cartItems.isEmpty
                ? const Center(
                    child: Text('Keranjang kosong',
                        style: TextStyle(color: AppTheme.textSecondary)))
                : ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.menu.name,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                            'Rp ${item.menu.price.toStringAsFixed(0)} x ${item.quantity}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: AppTheme.textSecondary, size: 20),
                              onPressed: () => cartNotifier.removeItem(item.menu.id),
                            ),
                            Text('${item.quantity}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: AppTheme.primaryColor, size: 20),
                              onPressed: () => cartNotifier.addItem(item.menu),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Discount & Tax section
          _buildDiscountTaxSection(subtotal, discountAmount, taxAmount, total, discount),

          // Total + Checkout button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Column(
              children: [
                // Price breakdown
                if (discountAmount > 0 || taxAmount > 0) ...[
                  _priceRow('Subtotal:', 'Rp ${subtotal.toStringAsFixed(0)}', Colors.white),
                  if (discountAmount > 0)
                    _priceRow(
                        'Diskon${discount.discountType == DiscountType.percent ? ' (${discount.discountValue.toStringAsFixed(0)}%)' : ''}:',
                        '- Rp ${discountAmount.toStringAsFixed(0)}',
                        AppTheme.secondaryColor),
                  if (taxAmount > 0)
                    _priceRow(
                        'Pajak (${discount.taxPercent.toStringAsFixed(0)}%):',
                        '+ Rp ${taxAmount.toStringAsFixed(0)}',
                        Colors.orange),
                  const Divider(color: Colors.white24, height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Rp ${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (cartItems.isEmpty || _isProcessing)
                        ? null
                        : () => _showPaymentDialog(context, subtotal, discountAmount, taxAmount, total, discount),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Proses Pembayaran', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(CustomerModel? customer) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: customer != null
              ? AppTheme.secondaryColor.withOpacity(0.4)
              : const Color(0xFF334155),
        ),
      ),
      child: customer != null
          ? Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.secondaryColor.withOpacity(0.2),
                  radius: 18,
                  child: Text(customer.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text('${customer.points} poin · ${customer.tier}',
                          style: const TextStyle(
                              color: AppTheme.secondaryColor, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                  onPressed: () => ref.read(selectedCustomerProvider.notifier).clear(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            )
          : InkWell(
              onTap: () => _showCustomerSearchDialog(),
              child: const Row(
                children: [
                  Icon(Icons.person_search, color: AppTheme.textSecondary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Cari / Tambah Pelanggan (opsional)',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
                ],
              ),
            ),
    );
  }

  Widget _buildDiscountTaxSection(
      double subtotal, double discountAmount, double taxAmount, double total, DiscountState discount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showDiscountTaxDialog(subtotal),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.local_offer, color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      discountAmount > 0 || taxAmount > 0
                          ? 'Diskon & Pajak (aktif)'
                          : 'Tambah Diskon / Pajak',
                      style: TextStyle(
                        color: discountAmount > 0 || taxAmount > 0
                            ? AppTheme.secondaryColor
                            : AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: discountAmount > 0 || taxAmount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (discountAmount > 0 || taxAmount > 0)
                    GestureDetector(
                      onTap: () => ref.read(discountProvider.notifier).reset(),
                      child: const Icon(Icons.close, color: AppTheme.error, size: 16),
                    )
                  else
                    const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // DIALOGS
  // ──────────────────────────────────────────────────────────

  void _showCustomerSearchDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    CustomerModel? found;
    bool isSearching = false;
    bool showAddForm = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Cari Pelanggan', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nomor HP',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor, minimumSize: const Size(50, 50)),
                      onPressed: isSearching
                          ? null
                          : () async {
                              setStateDialog(() { isSearching = true; found = null; });
                              try {
                                final dio = ref.read(dioProvider);
                                final res = await dio.get('/customers/search',
                                    queryParameters: {'phone': phoneCtrl.text});
                                final data = res.data;
                                if (data is Map) {
                                  setStateDialog(() => found = CustomerModel.fromJson(data as Map<String, dynamic>));
                                }
                              } catch (e) {
                                setStateDialog(() => showAddForm = true);
                              } finally {
                                setStateDialog(() => isSearching = false);
                              }
                            },
                      child: isSearching
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
                if (found != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(found!.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(found!.phone,
                            style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('${found!.tier}',
                                  style: const TextStyle(
                                      color: AppTheme.secondaryColor, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Text('${found!.points} poin',
                                style: const TextStyle(
                                    color: AppTheme.secondaryColor,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (showAddForm && found == null) ...[
                  const SizedBox(height: 16),
                  const Text('Pelanggan tidak ditemukan. Daftarkan pelanggan baru:',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nama Pelanggan',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            if (found != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                onPressed: () {
                  ref.read(selectedCustomerProvider.notifier).select(found!);
                  Navigator.pop(ctx);
                },
                child: const Text('Pilih Pelanggan'),
              ),
            if (showAddForm && found == null && nameCtrl.text.isNotEmpty)
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                  try {
                    final dio = ref.read(dioProvider);
                    final res = await dio.post('/customers', data: {
                      'name': nameCtrl.text,
                      'phone': phoneCtrl.text,
                    });
                    final newCust = CustomerModel.fromJson(res.data as Map<String, dynamic>);
                    ref.read(selectedCustomerProvider.notifier).select(newCust);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal daftar pelanggan: $e')));
                    }
                  }
                },
                child: const Text('Daftarkan'),
              ),
          ],
        ),
      ),
    );
  }

  void _showDiscountTaxDialog(double subtotal) {
    final discountCtrl = TextEditingController(text: '0');
    final discountState = ref.read(discountProvider);
    DiscountType selectedType = discountState.discountType;
    double taxPercent = discountState.taxPercent;
    discountCtrl.text = discountState.discountValue.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Row(
            children: [
              Icon(Icons.local_offer, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('Diskon & Pajak', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subtotal: Rp ${subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 20),

              // Discount type toggle
              const Text('Tipe Diskon', style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setStateDialog(() => selectedType = DiscountType.percent),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedType == DiscountType.percent
                              ? AppTheme.primaryColor.withOpacity(0.2)
                              : AppTheme.backgroundDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedType == DiscountType.percent
                                ? AppTheme.primaryColor
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: const Text('Persen (%)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setStateDialog(() => selectedType = DiscountType.nominal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedType == DiscountType.nominal
                              ? AppTheme.primaryColor.withOpacity(0.2)
                              : AppTheme.backgroundDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedType == DiscountType.nominal
                                ? AppTheme.primaryColor
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: const Text('Nominal (Rp)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: discountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: selectedType == DiscountType.percent ? 'Diskon (%)' : 'Diskon (Rp)',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.discount, color: AppTheme.secondaryColor),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Pajak', style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [0.0, 10.0, 11.0].map((pct) {
                  return ChoiceChip(
                    label: Text(pct == 0 ? 'Tanpa Pajak' : 'PPN ${pct.toStringAsFixed(0)}%'),
                    selected: taxPercent == pct,
                    onSelected: (_) => setStateDialog(() => taxPercent = pct),
                    selectedColor: Colors.orange.withOpacity(0.3),
                    backgroundColor: AppTheme.backgroundDark,
                    labelStyle: TextStyle(
                        color: taxPercent == pct ? Colors.orange : AppTheme.textSecondary,
                        fontSize: 12),
                    side: BorderSide(
                        color: taxPercent == pct ? Colors.orange : const Color(0xFF334155)),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(discountCtrl.text) ?? 0;
                ref.read(discountProvider.notifier)
                  ..setDiscountType(selectedType)
                  ..setDiscountValue(val)
                  ..setTaxPercent(taxPercent);
                Navigator.pop(ctx);
              },
              child: const Text('Terapkan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, double subtotal, double discountAmount,
      double taxAmount, double total, DiscountState discount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Metode Pembayaran', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (discountAmount > 0 || taxAmount > 0) ...[
              _priceRow('Subtotal:', 'Rp ${subtotal.toStringAsFixed(0)}', Colors.white),
              if (discountAmount > 0)
                _priceRow('Diskon:', '- Rp ${discountAmount.toStringAsFixed(0)}',
                    AppTheme.secondaryColor),
              if (taxAmount > 0)
                _priceRow('Pajak:', '+ Rp ${taxAmount.toStringAsFixed(0)}', Colors.orange),
              const Divider(color: Colors.white24, height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Rp ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Metode pembayaran:', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processCheckout(total, subtotal, discountAmount, taxAmount, discount, 'cash');
            },
            child: const Text('💵 TUNAI',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              Navigator.pop(context);
              _processMidtransQris(total, subtotal, discountAmount, taxAmount, discount);
            },
            child: const Text('📱 QRIS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _processMidtransQris(double totalAmount, double subtotal,
      double discountAmount, double taxAmount, DiscountState discount) async {
    setState(() => _isProcessing = true);
    final dio = ref.read(dioProvider);
    try {
      final res = await dio.post('/qris/generate', data: {'total_amount': totalAmount});
      if (res.data != null && res.data['qr_url'] != null) {
        final orderId = res.data['order_id'];
        final qrUrl = res.data['qr_url'];
        final qrString = res.data['qr_string'] ?? '';
        if (mounted) {
          _showQrisDialog(context, orderId, qrUrl, qrString, totalAmount, subtotal,
              discountAmount, taxAmount, discount);
        }
      } else {
        throw Exception('Gagal mendapatkan QR dari Midtrans');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showQrisDialog(BuildContext context, String orderId, String qrUrl, String qrString,
      double totalAmount, double subtotal, double discountAmount, double taxAmount, DiscountState discount) {
    bool isChecking = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Scan QRIS', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rp ${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppTheme.secondaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Image.network(qrUrl, width: 230, height: 230, fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 100)),
              ),
              const SizedBox(height: 16),
              const Text('Minta pelanggan scan QR di atas.',
                  style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
              if (qrString.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(qrString,
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              if (isChecking)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      minimumSize: const Size(double.infinity, 48)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Cek Status Pembayaran'),
                  onPressed: () async {
                    setDialogState(() => isChecking = true);
                    try {
                      final res = await ref.read(dioProvider).get('/qris/status/$orderId');
                      final status = res.data['status'];
                      if (status == 'settlement' || status == 'capture') {
                        if (ctx.mounted) Navigator.pop(ctx);
                        _processCheckout(totalAmount, subtotal, discountAmount, taxAmount, discount, 'qris');
                      } else {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Status: $status. Pelanggan belum membayar.')));
                        }
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Gagal cek status: $e')));
                      }
                    } finally {
                      if (ctx.mounted) setDialogState(() => isChecking = false);
                    }
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isChecking ? null : () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processCheckout(double total, double subtotal, double discountAmount,
      double taxAmount, DiscountState discount, String paymentMethod) async {
    setState(() => _isProcessing = true);
    try {
      final dio = ref.read(dioProvider);
      final localDb = ref.read(localDbProvider);
      final cartItems = ref.read(cartProvider);
      final selectedCustomer = ref.read(selectedCustomerProvider);
      final shiftState = ref.read(shiftNotifierProvider);
      final currentShiftId = shiftState.valueOrNull?.id;

      final itemsData = cartItems.map((item) => {
        'menu_id': item.menu.id,
        'quantity': item.quantity,
        'price': item.menu.price,
      }).toList();

      final txData = {
        'subtotal_amount': subtotal,
        'discount_amount': discountAmount,
        'discount_type': discount.discountType == DiscountType.percent ? 'percent' : 'nominal',
        'tax_amount': taxAmount,
        'tax_percent': discount.taxPercent,
        'total_amount': total,
        'payment_method': paymentMethod,
        'items': itemsData,
        'created_at': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        if (selectedCustomer != null) 'customer_id': selectedCustomer.id,
        if (currentShiftId != null) 'shift_id': currentShiftId,
      };

      try {
        await dio.post('/checkout', data: txData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Pembayaran Berhasil! (Online)'),
                backgroundColor: Colors.green),
          );
        }
        // Reload shift to update stats
        ref.read(shiftNotifierProvider.notifier).loadCurrentShift();
      } catch (e) {
        await localDb.savePendingTransaction(txData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('⚠️ Offline! Pembayaran Disimpan ke Antrian.'),
                backgroundColor: Colors.orange),
          );
        }
      }

      setState(() => _lastTransaction = {
        ...txData,
        'items': cartItems.map((i) => {
          'name': i.menu.name,
          'quantity': i.quantity,
          'price': i.menu.price,
          'total': i.menu.price * i.quantity,
        }).toList(),
        'payment_method': paymentMethod,
        if (selectedCustomer != null) 'customer_name': selectedCustomer.name,
      });

      ref.read(cartProvider.notifier).clearCart();
      ref.read(discountProvider.notifier).reset();
      ref.read(selectedCustomerProvider.notifier).clear();

      // Show print dialog
      if (mounted) _showPrintDialog();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showPrintDialog() {
    if (_lastTransaction == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('🧾 Cetak Struk?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Pembayaran berhasil! Apakah Anda ingin mencetak struk untuk pelanggan?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Lewati', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Cetak Struk'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _printReceipt();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt() async {
    if (_lastTransaction == null) return;
    final printerService = ref.read(printerServiceProvider);
    try {
      await printerService.printReceipt(_lastTransaction!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🖨️ Struk berhasil dicetak!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal cetak: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
}
