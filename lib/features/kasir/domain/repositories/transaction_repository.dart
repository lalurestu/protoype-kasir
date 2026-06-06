import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/models/transaction_model.dart';

abstract class TransactionRepository {
  Future<Either<Failure, TransactionModel>> checkout(Map<String, dynamic> cartData);
  Future<Either<Failure, List<TransactionModel>>> getDailyReports(int storeId, DateTime date);
}
