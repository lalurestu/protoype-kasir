import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  @JsonKey(name: 'tenant_id')
  final int? tenantId;
  @JsonKey(name: 'store_id')
  final int? storeId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.tenantId,
    this.storeId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
