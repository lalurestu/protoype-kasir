import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/menu_model.dart';

final menusProvider = FutureProvider<List<MenuModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/store/menus');
  final List data = response.data;
  return data.map((json) => MenuModel.fromJson(json)).toList();
});
