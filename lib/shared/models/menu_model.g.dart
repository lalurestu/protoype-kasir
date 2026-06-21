// GENERATED CODE - DO NOT MODIFY BY HAND

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
      cogs: (json['cogs'] as num?)?.toDouble(),
      variants: (json['variants'] as List<dynamic>?)
          ?.map((e) => MenuVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
      addons: (json['addons'] as List<dynamic>?)
          ?.map((e) => MenuAddon.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MenuModelToJson(MenuModel instance) => <String, dynamic>{
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
      'cogs': instance.cogs,
      'variants': instance.variants,
      'addons': instance.addons,
    };

MenuVariant _$MenuVariantFromJson(Map<String, dynamic> json) => MenuVariant(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
    );

Map<String, dynamic> _$MenuVariantToJson(MenuVariant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'price': instance.price,
    };

MenuAddon _$MenuAddonFromJson(Map<String, dynamic> json) => MenuAddon(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
    );

Map<String, dynamic> _$MenuAddonToJson(MenuAddon instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'price': instance.price,
    };
