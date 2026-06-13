// lib/features/kasir/presentation/providers/discount_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DiscountType { percent, nominal }

class DiscountState {
  final DiscountType discountType;
  final double discountValue;  // Persen (0-100) atau nominal (Rp)
  final double taxPercent;     // Default 0, bisa PPN 11%

  const DiscountState({
    this.discountType = DiscountType.percent,
    this.discountValue = 0,
    this.taxPercent = 0,
  });

  // Hitung diskon dari subtotal
  double calculateDiscount(double subtotal) {
    if (discountValue <= 0) return 0;
    if (discountType == DiscountType.percent) {
      return subtotal * (discountValue / 100);
    }
    return discountValue > subtotal ? subtotal : discountValue;
  }

  // Hitung pajak dari (subtotal - diskon)
  double calculateTax(double subtotal) {
    if (taxPercent <= 0) return 0;
    final afterDiscount = subtotal - calculateDiscount(subtotal);
    return afterDiscount * (taxPercent / 100);
  }

  // Total akhir
  double calculateTotal(double subtotal) {
    return subtotal - calculateDiscount(subtotal) + calculateTax(subtotal);
  }

  DiscountState copyWith({
    DiscountType? discountType,
    double? discountValue,
    double? taxPercent,
  }) {
    return DiscountState(
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      taxPercent: taxPercent ?? this.taxPercent,
    );
  }
}

class DiscountNotifier extends StateNotifier<DiscountState> {
  DiscountNotifier() : super(const DiscountState());

  void setDiscountType(DiscountType type) {
    state = state.copyWith(discountType: type, discountValue: 0);
  }

  void setDiscountValue(double value) {
    state = state.copyWith(discountValue: value);
  }

  void setTaxPercent(double percent) {
    state = state.copyWith(taxPercent: percent);
  }

  void reset() {
    state = const DiscountState();
  }
}

final discountProvider = StateNotifierProvider.autoDispose<DiscountNotifier, DiscountState>((ref) {
  return DiscountNotifier();
});
