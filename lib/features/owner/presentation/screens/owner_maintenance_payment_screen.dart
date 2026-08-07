// lib/features/owner/presentation/screens/owner_maintenance_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

class OwnerMaintenancePaymentScreen extends ConsumerStatefulWidget {
  const OwnerMaintenancePaymentScreen({super.key});

  @override
  ConsumerState<OwnerMaintenancePaymentScreen> createState() => _OwnerMaintenancePaymentScreenState();
}

class _OwnerMaintenancePaymentScreenState extends ConsumerState<OwnerMaintenancePaymentScreen> {
  bool _isLoadingPrice = true;
  bool _isRequesting = false;
  double _maintenancePrice = 0;
  String _qrUrl = '';
  List<dynamic> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchMaintenancePrice();
    _fetchHistory();
  }

  Future<void> _fetchMaintenancePrice() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/owner/maintenance/price');
      setState(() {
        _maintenancePrice = double.tryParse(response.data['maintenance_price'].toString()) ?? 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil harga maintenance.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPrice = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/owner/maintenance/history');
      setState(() {
        _history = response.data;
      });
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _requestMaintenance() async {
    if (_maintenancePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga maintenance belum diatur. Hubungi admin.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isRequesting = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/owner/maintenance/request', data: {
        'duration_days': 30
      });
      
      setState(() {
        _qrUrl = response.data['qr_url'] ?? '';
      });

      if (_qrUrl.isNotEmpty) {
        final uri = Uri.parse(_qrUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      
      _fetchHistory(); // Refresh history list
    } on DioException catch (e) {
      final errorMsg = e.response?.data is Map ? e.response?.data['error']?.toString() : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${errorMsg ?? "Gagal merequest maintenance"}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Pembayaran Maintenance'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perpanjang Lisensi via QRIS',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Perpanjang masa aktif sistem kasir Anda selama 30 Hari langsung melalui sistem QRIS Midtrans.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: _isLoadingPrice
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tagihan Maintenance', style: TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          'Rp ${_maintenancePrice.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isRequesting || _maintenancePrice <= 0 ? null : _requestMaintenance,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppTheme.primaryColor,
                            ),
                            child: _isRequesting 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Bayar dengan QRIS', style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                        ),
                        if (_qrUrl.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                final uri = Uri.parse(_qrUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: AppTheme.primaryColor),
                              ),
                              child: const Text('Buka Halaman Pembayaran', style: TextStyle(fontSize: 16, color: AppTheme.primaryColor)),
                            ),
                          ),
                        ]
                      ],
                    ),
            ),
            
            const SizedBox(height: 40),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Pembayaran',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: _fetchHistory,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('Belum ada riwayat pembayaran', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          final isSuccess = item['status'] == 'success';
                          final isPending = item['status'] == 'pending';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSuccess ? Colors.green.withOpacity(0.2) : (isPending ? Colors.orange.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isSuccess ? Icons.check_circle : (isPending ? Icons.access_time : Icons.cancel),
                                    color: isSuccess ? Colors.green : (isPending ? Colors.orange : Colors.red),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order: ${item['order_id']}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rp ${double.tryParse(item['amount'].toString())?.toStringAsFixed(0) ?? 0} • ${item['duration_days']} Hari',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
