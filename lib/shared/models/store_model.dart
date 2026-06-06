import 'package:json_annotation/json_annotation.dart';

part 'store_model.g.dart';

@JsonSerializable()
class StoreModel {
  final int id;
  @JsonKey(name: 'owner_id')
  final int ownerId;
  final String name;
  final String address;
  final String? logo;

  StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    this.logo,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) => _$StoreModelFromJson(json);
  Map<String, dynamic> toJson() => _$StoreModelToJson(this);
}
