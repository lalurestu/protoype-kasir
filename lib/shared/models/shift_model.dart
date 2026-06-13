// lib/shared/models/shift_model.dart

class ShiftModel {
  final int id;
  final int kasirId;
  final int storeId;
  final String kasirName;
  final double openingCash;
  final double? closingCash;
  final double totalSales;
  final int totalTransactions;
  final String? note;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status; // 'open' | 'closed'

  ShiftModel({
    required this.id,
    required this.kasirId,
    required this.storeId,
    required this.kasirName,
    required this.openingCash,
    this.closingCash,
    required this.totalSales,
    required this.totalTransactions,
    this.note,
    required this.openedAt,
    this.closedAt,
    required this.status,
  });

  bool get isOpen => status == 'open';

  double get cashDifference {
    if (closingCash == null) return 0;
    return closingCash! - openingCash - totalSales;
  }

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] as int,
      kasirId: json['kasir_id'] as int,
      storeId: json['store_id'] as int,
      kasirName: json['kasir_name'] as String? ?? 'Kasir',
      openingCash: (json['opening_cash'] as num?)?.toDouble() ?? 0.0,
      closingCash: (json['closing_cash'] as num?)?.toDouble(),
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: json['total_transactions'] as int? ?? 0,
      note: json['note'] as String?,
      openedAt: DateTime.parse(json['opened_at'] as String),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      status: json['status'] as String? ?? 'open',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kasir_id': kasirId,
        'store_id': storeId,
        'opening_cash': openingCash,
        'closing_cash': closingCash,
        'total_sales': totalSales,
        'total_transactions': totalTransactions,
        'note': note,
        'opened_at': openedAt.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
        'status': status,
      };
}
