// lib/features/kasir/presentation/providers/customer_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/customer_model.dart';

// Selected customer at checkout
final selectedCustomerProvider =
    StateNotifierProvider<SelectedCustomerNotifier, CustomerModel?>((ref) {
  return SelectedCustomerNotifier();
});

class SelectedCustomerNotifier extends StateNotifier<CustomerModel?> {
  SelectedCustomerNotifier() : super(null);

  void select(CustomerModel customer) => state = customer;
  void clear() => state = null;
}

// Search customer by phone
final customerSearchProvider =
    FutureProvider.family.autoDispose<CustomerModel?, String>((ref, phone) async {
  if (phone.length < 6) return null;
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/customers/search', queryParameters: {'phone': phone});
    if (response.data != null) {
      return CustomerModel.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  } catch (e) {
    return null;
  }
});

// Owner: all customers
final allCustomersProvider = FutureProvider.autoDispose<List<CustomerModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/customers');
  final List data = response.data as List;
  return data.map((json) => CustomerModel.fromJson(json as Map<String, dynamic>)).toList();
});
