import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/menu_model.dart';

class CartItem {
  final MenuModel menu;
  int quantity;

  CartItem({required this.menu, this.quantity = 1});
  
  double get total => menu.price * quantity;
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(MenuModel menu) {
    final index = state.indexWhere((item) => item.menu.id == menu.id);
    if (index >= 0) {
      final updatedList = List<CartItem>.from(state);
      updatedList[index].quantity++;
      state = updatedList;
    } else {
      state = [...state, CartItem(menu: menu)];
    }
  }

  void removeItem(int menuId) {
    state = state.where((item) => item.menu.id != menuId).toList();
  }

  void clearCart() {
    state = [];
  }

  double get totalPrice {
    return state.fold(0, (sum, item) => sum + item.total);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
