// GENERATED CODE - DO NOT MODIFY BY HAND
// Regenerated manually to reflect changes in menu_model.dart
// Run: flutter pub run build_runner build

part of 'menu_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MenuModel _$MenuModelFromJson(Map<String, dynamic> json) => MenuModel(
      id: (json['id'] as num).toInt(),
      storeId: (json['store_id'] as num).toInt(),
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      stock: (json['stock'] as num?)?.toInt(),
      minStock: (json['min_stock'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MenuModelToJson(MenuModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'store_id': instance.storeId,
      'name': instance.name,
      'price': instance.price,
      'category': instance.category,
      'image_url': instance.imageUrl,
      'description': instance.description,
      'is_available': instance.isAvailable,
      'stock': instance.stock,
      'min_stock': instance.minStock,
    };
