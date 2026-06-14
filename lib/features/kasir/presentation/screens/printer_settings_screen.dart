import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/printer_service.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  bool _isScanning = false;
  List<Map<String, String>> _devices = [];

  @override
  void initState() {
    super.initState();
    _scanForDevices();
  }

  Future<void> _scanForDevices() async {
    setState(() => _isScanning = true);
    final printerService = ref.read(printerServiceProvider);
    
    final devices = await printerService.scanDevices();
    
    if (mounted) {
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(Map<String, String> device) async {
    final printerService = ref.read(printerServiceProvider);
    
    // Disconnect if already connected to something else
    if (printerService.isConnected) {
      await printerService.disconnect();
      setState(() {});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menghubungkan ke ${device['name']}...')),
    );

    final success = await printerService.connect(device['mac']!, device['name']!);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Printer Terhubung!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Gagal terhubung ke Printer'), backgroundColor: AppTheme.error),
        );
      }
      setState(() {});
    }
  }

  Future<void> _disconnectDevice() async {
    final printerService = ref.read(printerServiceProvider);
    await printerService.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer diputus.')),
      );
      setState(() {});
    }
  }

  Future<void> _testPrint() async {
    final printerService = ref.read(printerServiceProvider);
    try {
      await printerService.printReceipt({
        'kasir_name': 'Test Kasir',
        'items': [
          {'name': 'Test Menu 1', 'quantity': 1, 'price': 10000},
          {'name': 'Test Menu 2', 'quantity': 2, 'price': 5000},
        ],
        'subtotal_amount': 20000,
        'total_amount': 20000,
        'payment_method': 'cash'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Berhasil mencetak test struk'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal print: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerService = ref.watch(printerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanForDevices,
            tooltip: 'Scan ulang',
          ),
        ],
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          // Status Container
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceDark,
            child: Row(
              children: [
                Icon(
                  printerService.isConnected ? Icons.print : Icons.print_disabled,
                  color: printerService.isConnected ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status Printer', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      Text(
                        printerService.isConnected
                            ? 'Terhubung ke: ${printerService.connectedDeviceName}'
                            : 'Belum terhubung',
                        style: TextStyle(
                          color: printerService.isConnected ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (printerService.isConnected) ...[
                  IconButton(
                    icon: const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                    onPressed: _testPrint,
                    tooltip: 'Test Print',
                  ),
                  IconButton(
                    icon: const Icon(Icons.link_off, color: AppTheme.error),
                    onPressed: _disconnectDevice,
                    tooltip: 'Putus Koneksi',
                  ),
                ],
              ],
            ),
          ),
          
          const Divider(height: 1, color: Colors.white12),

          // Devices List
          Expanded(
            child: _isScanning
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryColor),
                        SizedBox(height: 16),
                        Text('Mencari printer bluetooth...', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : _devices.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada perangkat bluetooth ditemukan.\nPastikan bluetooth aktif dan printer menyala.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final isThisConnected = printerService.isConnected && 
                                                  printerService.connectedDeviceName == device['name'];
                          
                          return ListTile(
                            leading: const Icon(Icons.bluetooth, color: AppTheme.textSecondary),
                            title: Text(device['name'] ?? 'Unknown Device', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(device['mac'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            trailing: isThisConnected
                                ? const Chip(
                                    label: Text('Connected', style: TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: Colors.green,
                                  )
                                : ElevatedButton(
                                    onPressed: () => _connectToDevice(device),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      minimumSize: const Size(80, 36),
                                    ),
                                    child: const Text('Connect'),
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
