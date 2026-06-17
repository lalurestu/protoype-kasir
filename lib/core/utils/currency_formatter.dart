// lib/core/utils/currency_formatter.dart
// Utility untuk memformat angka menjadi format mata uang Rupiah (Rp).
// Gunakan ini secara konsisten di seluruh aplikasi untuk menampilkan harga.
//
// PENGGUNAAN:
//   CurrencyFormatter.format(15000)         → "Rp 15.000"
//   CurrencyFormatter.format(1500000)       → "Rp 1.500.000"
//   CurrencyFormatter.formatCompact(15000)  → "Rp 15k"
//   CurrencyFormatter.formatInput(15000)    → "15.000" (tanpa prefix Rp, untuk input)

import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._(); // Private constructor — hanya static methods

  static final NumberFormat _fullFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _inputFormat = NumberFormat('#,###', 'id_ID');

  /// Format angka ke format Rupiah penuh.
  /// Contoh: 15000 → "Rp 15.000"
  static String format(num amount) {
    return _fullFormat.format(amount);
  }

  /// Format angka ke format compact untuk layar kecil.
  /// Contoh: 15000 → "Rp 15k" | 1500000 → "Rp 1,5j"
  static String formatCompact(num amount) {
    if (amount >= 1000000) {
      final val = amount / 1000000;
      final formatted = val == val.truncateToDouble()
          ? val.toInt().toString()
          : val.toStringAsFixed(1);
      return 'Rp ${formatted}j';
    } else if (amount >= 1000) {
      final val = amount / 1000;
      final formatted = val == val.truncateToDouble()
          ? val.toInt().toString()
          : val.toStringAsFixed(1);
      return 'Rp ${formatted}k';
    }
    return 'Rp ${amount.toInt()}';
  }

  /// Format untuk input field (tanpa prefix Rp, tanpa desimal).
  /// Contoh: 15000 → "15.000"
  static String formatInput(num amount) {
    return _inputFormat.format(amount);
  }

  /// Parse string input kembali ke double.
  /// Contoh: "15.000" → 15000.0
  static double parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Format perubahan (delta), tampilkan tanda + untuk positif.
  /// Contoh: 5000 → "+Rp 5.000" | -2000 → "-Rp 2.000"
  static String formatDelta(num amount) {
    if (amount >= 0) {
      return '+${format(amount)}';
    }
    return format(amount);
  }
}
