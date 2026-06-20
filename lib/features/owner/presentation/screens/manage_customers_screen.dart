// lib/features/owner/presentation/screens/manage_customers_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/customer_model.dart';
import '../../../kasir/presentation/providers/customer_provider.dart';
import '../../../../core/utils/currency_formatter.dart';

class ManageCustomersScreen extends ConsumerStatefulWidget {
  const ManageCustomersScreen({super.key});

  @override
  ConsumerState<ManageCustomersScreen> createState() =>
      _ManageCustomersScreenState();
}

class _ManageCustomersScreenState extends ConsumerState<ManageCustomersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(allCustomersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Pelanggan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allCustomersProvider),
          ),
        ],
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: customersAsync.when(
        data: (customers) {
          final filtered = customers.where((c) {
            final q = _searchQuery.toLowerCase();
            return q.isEmpty ||
                c.name.toLowerCase().contains(q) ||
                c.phone.contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atau nomor HP...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              // Summary row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    _buildMiniStat('Total Pelanggan', '${customers.length}', Icons.people, AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    _buildMiniStat(
                        'Gold+',
                        '${customers.where((c) => c.totalSpend >= 1000000).length}',
                        Icons.star,
                        Colors.amber),
                    const SizedBox(width: 12),
                    _buildMiniStat(
                        'Total Poin',
                        '${customers.fold(0, (sum, c) => sum + c.points)}',
                        Icons.monetization_on,
                        AppTheme.secondaryColor),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('Belum ada pelanggan terdaftar',
                            style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _buildCustomerCard(filtered[index]),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('Error: $e', style: const TextStyle(color: AppTheme.error)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Pelanggan'),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
    final tierColor = _getTierColor(customer.tier);

    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tierColor.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: tierColor.withOpacity(0.2),
          radius: 26,
          child: Text(
            customer.name[0].toUpperCase(),
            style: TextStyle(
                color: tierColor, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(customer.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(customer.tier,
                  style: TextStyle(
                      color: tierColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(customer.phone,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.monetization_on,
                    size: 12, color: AppTheme.secondaryColor),
                const SizedBox(width: 4),
                Text('${customer.points} poin',
                    style: const TextStyle(
                        color: AppTheme.secondaryColor, fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.shopping_bag, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('${customer.visitCount}x kunjungan',
                    style:
                        const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Total belanja: ${CurrencyFormatter.format(customer.totalSpend)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'Platinum': return Colors.cyan;
      case 'Gold': return Colors.amber;
      case 'Silver': return Colors.grey;
      default: return const Color(0xFFCD7F32); // bronze
    }
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Tambah Pelanggan', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Nama Pelanggan',
                  labelStyle: TextStyle(color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  labelStyle: TextStyle(color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email (opsional)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Nama dan nomor HP wajib diisi')));
                return;
              }
              try {
                final dio = ref.read(dioProvider);
                await dio.post('/customers', data: {
                  'name': nameCtrl.text,
                  'phone': phoneCtrl.text,
                  'email': emailCtrl.text.isNotEmpty ? emailCtrl.text : null,
                });
                ref.invalidate(allCustomersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Pelanggan berhasil ditambahkan'),
                    backgroundColor: AppTheme.secondaryColor,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.error));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
