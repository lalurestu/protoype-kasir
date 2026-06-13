// lib/shared/models/customer_model.dart

class CustomerModel {
  final int id;
  final int storeId;
  final String name;
  final String phone;
  final String? email;
  final int points;
  final double totalSpend;
  final int visitCount;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.phone,
    this.email,
    required this.points,
    required this.totalSpend,
    required this.visitCount,
    required this.createdAt,
  });

  String get tier {
    if (totalSpend >= 5000000) return 'Platinum';
    if (totalSpend >= 1000000) return 'Gold';
    if (totalSpend >= 500000) return 'Silver';
    return 'Bronze';
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as int,
      storeId: json['store_id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      points: json['points'] as int? ?? 0,
      totalSpend: (json['total_spend'] as num?)?.toDouble() ?? 0.0,
      visitCount: json['visit_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'name': name,
        'phone': phone,
        'email': email,
        'points': points,
        'total_spend': totalSpend,
        'visit_count': visitCount,
        'created_at': createdAt.toIso8601String(),
      };
}
