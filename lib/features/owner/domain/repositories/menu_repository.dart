import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/models/menu_model.dart';

abstract class MenuRepository {
  Future<Either<Failure, List<MenuModel>>> getMenus(int storeId);
  Future<Either<Failure, MenuModel>> addMenu(MenuModel menu);
  Future<Either<Failure, MenuModel>> updateMenu(MenuModel menu);
  Future<Either<Failure, void>> deleteMenu(int id);
}
