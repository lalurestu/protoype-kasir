import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../shared/models/menu_model.dart';

final menusProvider = FutureProvider<List<MenuModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final localDb = ref.watch(localDbProvider);

  try {
    final response = await dio.get('/store/menus');
    final List data = response.data;
    await localDb.saveMenus(data);
    return data.map((json) => MenuModel.fromJson(json)).toList();
  } catch (e) {
    final localData = localDb.getMenus();
    if (localData.isNotEmpty) {
      return localData.map((json) => MenuModel.fromJson(json)).toList();
    }
    throw Exception('Gagal memuat menu dan tidak ada data offline.');
  }
});
