import 'package:json_annotation/json_annotation.dart';

part 'menu_model.g.dart';

@JsonSerializable()
class MenuModel {
  final int id;
  @JsonKey(name: 'store_id')
  final int storeId;
  final String name;
  final double price;
  final String category;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  final String? description;
  @JsonKey(name: 'is_available')
  final bool isAvailable;
  // Stock info (joined dari tabel stock, optional)
  final int? stock;
  @JsonKey(name: 'min_stock')
  final int? minStock;

  final List<MenuVariant>? variants;
  final List<MenuAddon>? addons;

  MenuModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl,
    this.description,
    this.isAvailable = true,
    this.stock,
    this.minStock,
    this.variants,
    this.addons,
  });

  bool get isLowStock => stock != null && minStock != null && stock! <= minStock!;

  factory MenuModel.fromJson(Map<String, dynamic> json) => _$MenuModelFromJson(json);
  Map<String, dynamic> toJson() => _$MenuModelToJson(this);
}

@JsonSerializable()
class MenuVariant {
  final int? id;
  final String name;
  final double price;

  MenuVariant({this.id, required this.name, required this.price});

  factory MenuVariant.fromJson(Map<String, dynamic> json) => _$MenuVariantFromJson(json);
  Map<String, dynamic> toJson() => _$MenuVariantToJson(this);
}

@JsonSerializable()
class MenuAddon {
  final int? id;
  final String name;
  final double price;

  MenuAddon({this.id, required this.name, required this.price});

  factory MenuAddon.fromJson(Map<String, dynamic> json) => _$MenuAddonFromJson(json);
  Map<String, dynamic> toJson() => _$MenuAddonToJson(this);
}
