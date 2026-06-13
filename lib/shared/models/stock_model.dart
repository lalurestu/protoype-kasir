// lib/shared/models/stock_model.dart

class StockModel {
  final int id;
  final int menuId;
  final String menuName;
  final String menuCategory;
  final double menuPrice;
  final int quantity;
  final int minStock;

  StockModel({
    required this.id,
    required this.menuId,
    required this.menuName,
    required this.menuCategory,
    required this.menuPrice,
    required this.quantity,
    required this.minStock,
  });

  bool get isLowStock => quantity <= minStock;
  bool get isOutOfStock => quantity <= 0;

  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      id: json['id'] as int,
      menuId: json['menu_id'] as int,
      menuName: json['menu_name'] as String? ?? '',
      menuCategory: json['menu_category'] as String? ?? '',
      menuPrice: (json['menu_price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 0,
      minStock: json['min_stock'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'menu_id': menuId,
        'menu_name': menuName,
        'quantity': quantity,
        'min_stock': minStock,
      };

  StockModel copyWith({int? quantity, int? minStock}) {
    return StockModel(
      id: id,
      menuId: menuId,
      menuName: menuName,
      menuCategory: menuCategory,
      menuPrice: menuPrice,
      quantity: quantity ?? this.quantity,
      minStock: minStock ?? this.minStock,
    );
  }
}
