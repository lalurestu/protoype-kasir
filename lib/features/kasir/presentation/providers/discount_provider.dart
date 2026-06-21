// lib/features/kasir/presentation/providers/discount_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_db_service.dart';

enum DiscountType { percent, nominal }

class DiscountState {
  final DiscountType discountType;
  final double discountValue;  // Persen (0-100) atau nominal (Rp)
  final double taxPercent;     // Default 0, bisa PPN 11%
  final double servicePercent; // Default 0

  const DiscountState({
    this.discountType = DiscountType.percent,
    this.discountValue = 0,
    this.taxPercent = 0,
    this.servicePercent = 0,
  });

  // Hitung diskon dari subtotal
  double calculateDiscount(double subtotal) {
    if (discountValue <= 0) return 0;
    if (discountType == DiscountType.percent) {
      return subtotal * (discountValue / 100);
    }
    return discountValue > subtotal ? subtotal : discountValue;
  }

  // Hitung service charge dari (subtotal - diskon)
  double calculateServiceCharge(double subtotal) {
    if (servicePercent <= 0) return 0;
    final afterDiscount = subtotal - calculateDiscount(subtotal);
    return afterDiscount * (servicePercent / 100);
  }

  // Hitung pajak dari (subtotal - diskon + service)
  double calculateTax(double subtotal) {
    if (taxPercent <= 0) return 0;
    final afterDiscountAndService = subtotal - calculateDiscount(subtotal) + calculateServiceCharge(subtotal);
    return afterDiscountAndService * (taxPercent / 100);
  }

  // Total akhir
  double calculateTotal(double subtotal) {
    return subtotal - calculateDiscount(subtotal) + calculateServiceCharge(subtotal) + calculateTax(subtotal);
  }

  DiscountState copyWith({
    DiscountType? discountType,
    double? discountValue,
    double? taxPercent,
    double? servicePercent,
  }) {
    return DiscountState(
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      taxPercent: taxPercent ?? this.taxPercent,
      servicePercent: servicePercent ?? this.servicePercent,
    );
  }
}

class DiscountNotifier extends StateNotifier<DiscountState> {
  final double defaultTax;
  final double defaultService;

  DiscountNotifier({this.defaultTax = 0, this.defaultService = 0}) 
      : super(DiscountState(taxPercent: defaultTax, servicePercent: defaultService));

  void setDiscountType(DiscountType type) {
    state = state.copyWith(discountType: type, discountValue: 0);
  }

  void setDiscountValue(double value) {
    state = state.copyWith(discountValue: value);
  }

  void reset() {
    state = DiscountState(taxPercent: defaultTax, servicePercent: defaultService);
  }
}


final discountProvider = StateNotifierProvider.autoDispose<DiscountNotifier, DiscountState>((ref) {
  final localDb = ref.watch(localDbProvider);
  final settings = localDb.getStoreSettings();
  final tax = (settings['tax_percent'] as num?)?.toDouble() ?? 0.0;
  final service = (settings['service_percent'] as num?)?.toDouble() ?? 0.0;
  
  return DiscountNotifier(defaultTax: tax, defaultService: service);
});
