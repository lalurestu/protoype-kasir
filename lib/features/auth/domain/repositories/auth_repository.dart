import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/models/user_model.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserModel>> login(String email, String password);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserModel>> registerOwner(Map<String, dynamic> ownerData);
}
