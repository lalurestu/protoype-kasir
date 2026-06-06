import 'package:json_annotation/json_annotation.dart';

part 'transaction_model.g.dart';

@JsonSerializable()
class TransactionModel {
  final int id;
  @JsonKey(name: 'store_id')
  final int storeId;
  @JsonKey(name: 'kasir_id')
  final int kasirId;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.storeId,
    required this.kasirId,
    required this.totalAmount,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) => _$TransactionModelFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionModelToJson(this);
}
