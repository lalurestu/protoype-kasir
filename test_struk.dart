import 'package:flutter/material.dart'; // Just dummy to make sure it compiles if needed, but we can copy the pure dart logic

void main() {
  final tx = {
    'kasir_name': 'Budi',
    'customer_name': 'Andi',
    'items': [
      {'name': 'Nasi Goreng Spesial', 'quantity': 2, 'price': 25000},
      {'name': 'Es Teh Manis', 'quantity': 2, 'price': 5000},
      {'name': 'Kerupuk', 'quantity': 1, 'price': 3000},
    ],
    'subtotal_amount': 63000,
    'discount_amount': 3000,
    'tax_amount': 6000,
    'total_amount': 66000,
    'payment_method': 'qris'
  };

  final lines = _buildReceiptLines(tx);
  for (var line in lines) {
    print(line);
  }
}

List<String> _buildReceiptLines(Map<String, dynamic> tx) {
  final lines = <String>[];
  final divider = '--------------------------------';
  // Use a fixed date for consistent output
  final now = DateTime(2026, 6, 21, 14, 30);

  lines.add('');
  lines.add(_center('TOKO KASIR'));
  lines.add(_center('Struk Pembayaran'));
  lines.add(divider);
  lines.add('Tgl : ${now.day}/${now.month}/${now.year} ${now.hour}:${_pad(now.minute)}');
  lines.add('Kasir: ${tx['kasir_name'] ?? '-'}');
  if (tx['customer_name'] != null) {
    lines.add('Pelanggan: ${tx['customer_name']}');
  }
  lines.add(divider);

  final items = tx['items'] as List? ?? [];
  for (var item in items) {
    final name = item['name'] ?? item['menu_name'] ?? 'Item';
    final qty = item['quantity'] ?? 1;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final total = qty * price;
    lines.add(name);
    lines.add(_rightAlign('${qty}x Rp ${_formatRp(price)}', 'Rp ${_formatRp(total)}'));
  }

  lines.add(divider);
  if ((tx['discount_amount'] ?? 0) > 0) {
    lines.add(_rightAlign('Subtotal', 'Rp ${_formatRp((tx['subtotal_amount'] ?? tx['total_amount']))}'));
    lines.add(_rightAlign('Diskon', '- Rp ${_formatRp(tx['discount_amount'])}'));
  }
  if ((tx['tax_amount'] ?? 0) > 0) {
    lines.add(_rightAlign('Pajak', '+ Rp ${_formatRp(tx['tax_amount'])}'));
  }
  lines.add(divider);
  lines.add(_rightAlign('TOTAL', 'Rp ${_formatRp(tx['total_amount'])}'));
  lines.add(_rightAlign('Pembayaran', (tx['payment_method'] as String? ?? 'cash').toUpperCase()));
  lines.add(divider);
  lines.add(_center('Terima Kasih!'));
  lines.add(_center('Kunjungi kami lagi :)'));
  lines.add(divider);
  lines.add(_center('Powered by SELLORA'));
  lines.add('');
  lines.add('');

  return lines;
}

String _center(String text, {int width = 32}) {
  if (text.length >= width) return text;
  final padding = (width - text.length) ~/ 2;
  return ' ' * padding + text;
}

String _rightAlign(String left, String right, {int width = 32}) {
  final spaces = width - left.length - right.length;
  if (spaces < 1) return '$left $right';
  return left + ' ' * spaces + right;
}

String _pad(int n) => n.toString().padLeft(2, '0');

String _formatRp(dynamic amount) {
  if (amount == null) return '0';
  final num val = amount is num ? amount : double.tryParse(amount.toString()) ?? 0;
  return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}
