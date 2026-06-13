// lib/features/owner/presentation/screens/owner_shifts_screen.dart
// Riwayat semua shift kasir untuk owner

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../kasir/presentation/providers/shift_provider.dart';
import '../../../../shared/models/shift_model.dart';

class OwnerShiftsScreen extends ConsumerWidget {
  const OwnerShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(ownerShiftsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Shift Kasir',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ownerShiftsProvider),
          ),
        ],
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: shiftsAsync.when(
        data: (shifts) {
          if (shifts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 64, color: AppTheme.textSecondary),
                  SizedBox(height: 16),
                  Text('Belum ada riwayat shift',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }

          // Summary stats
          final closedShifts = shifts.where((s) => !s.isOpen).toList();
          final totalSales = closedShifts.fold(0.0, (sum, s) => sum + s.totalSales);
          final openShifts = shifts.where((s) => s.isOpen).toList();

          return Column(
            children: [
              // Summary header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: _statBlock('Total Shift', '${shifts.length}',
                            Icons.schedule, AppTheme.primaryColor)),
                    Expanded(
                        child: _statBlock('Shift Aktif', '${openShifts.length}',
                            Icons.lock_open, AppTheme.secondaryColor)),
                    Expanded(
                        child: _statBlock('Total Penjualan',
                            'Rp ${totalSales.toStringAsFixed(0)}',
                            Icons.payments, Colors.amber)),
                  ],
                ),
              ),

              // Shift list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: shifts.length,
                  itemBuilder: (context, index) =>
                      _buildShiftCard(context, shifts[index]),
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
    );
  }

  Widget _statBlock(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildShiftCard(BuildContext context, ShiftModel shift) {
    final isOpen = shift.isOpen;
    final statusColor = isOpen ? Colors.orange : AppTheme.secondaryColor;
    final diff = shift.closingCash != null
        ? shift.closingCash! - shift.openingCash - shift.totalSales
        : null;

    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.15),
                  radius: 20,
                  child: Icon(
                      isOpen ? Icons.lock_open : Icons.lock,
                      color: statusColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shift.kasirName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(_formatDate(shift.openedAt),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isOpen ? 'AKTIF' : 'SELESAI',
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),

            // Shift details
            Row(
              children: [
                Expanded(child: _detailItem('Kas Awal', 'Rp ${shift.openingCash.toStringAsFixed(0)}', Colors.white)),
                Expanded(child: _detailItem('Penjualan', 'Rp ${shift.totalSales.toStringAsFixed(0)}', AppTheme.secondaryColor)),
                Expanded(child: _detailItem('Transaksi', '${shift.totalTransactions}', Colors.blue)),
              ],
            ),

            if (!isOpen && shift.closingCash != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _detailItem('Kas Akhir', 'Rp ${shift.closingCash!.toStringAsFixed(0)}', Colors.white)),
                  if (diff != null)
                    Expanded(
                      child: _detailItem(
                          'Selisih',
                          '${diff >= 0 ? '+' : ''}Rp ${diff.toStringAsFixed(0)}',
                          diff >= 0 ? AppTheme.secondaryColor : AppTheme.error),
                    ),
                ],
              ),
              if (shift.note != null && shift.note!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(shift.note!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ],
            ],

            if (!isOpen && shift.closedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                  'Ditutup: ${_formatDate(shift.closedAt!)} · Durasi: ${_duration(shift.openedAt, shift.closedAt!)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _duration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}j ${minutes}m';
  }
}
