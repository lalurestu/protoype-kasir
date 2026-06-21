import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/menu_model.dart';

class CartItem {
  final String id; // unique id for cart item since same menu can have different variants
  final MenuModel menu;
  final MenuVariant? variant;
  final List<MenuAddon> addons;
  int quantity;

  CartItem({
    required this.menu,
    this.variant,
    this.addons = const [],
    this.quantity = 1,
  }) : id = '${menu.id}_${variant?.id ?? 0}_${addons.map((a) => a.id).join("-")}';
  
  double get total {
    double basePrice = variant?.price ?? menu.price;
    double addonsPrice = addons.fold(0.0, (sum, addon) => sum + addon.price);
    return (basePrice + addonsPrice) * quantity;
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(MenuModel menu, {MenuVariant? variant, List<MenuAddon> addons = const [], int quantity = 1}) {
    final newItem = CartItem(menu: menu, variant: variant, addons: addons, quantity: quantity);
    final index = state.indexWhere((item) => item.id == newItem.id);
    if (index >= 0) {
      final updatedList = List<CartItem>.from(state);
      updatedList[index].quantity += quantity;
      state = updatedList;
    } else {
      state = [...state, newItem];
    }
  }

  void incrementItem(String cartItemId) {
    final index = state.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      final updatedList = List<CartItem>.from(state);
      updatedList[index].quantity++;
      state = updatedList;
    }
  }

  void decrementItem(String cartItemId) {
    final index = state.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      final updatedList = List<CartItem>.from(state);
      if (updatedList[index].quantity > 1) {
        updatedList[index].quantity--;
        state = updatedList;
      } else {
        state = state.where((item) => item.id != cartItemId).toList();
      }
    }
  }

  void removeItem(String cartItemId) {
    state = state.where((item) => item.id != cartItemId).toList();
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
