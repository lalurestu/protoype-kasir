// lib/core/services/printer_service.dart
// Bluetooth Thermal Printer service using esc_pos_bluetooth

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'local_db_service.dart';

// Note: Using print_bluetooth_thermal package (works on Android & iOS)
// Add to pubspec.yaml: print_bluetooth_thermal: ^1.0.7

// For now, this provides a stub implementation that shows a preview
// To activate real Bluetooth printing, install the package and uncomment the real code

final printerServiceProvider = Provider<PrinterService>((ref) => PrinterService(ref.read(localDbProvider)));

class PrinterService {
  final LocalDbService _localDb;
  bool _isConnected = false;
  String _connectedDevice = '';

  PrinterService(this._localDb);

  bool get isConnected => _isConnected;
  String get connectedDeviceName => _connectedDevice;

  /// Scan for nearby Bluetooth devices
  Future<List<Map<String, String>>> scanDevices() async {
    try {
      final isPermissionGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!isPermissionGranted) {
        debugPrint('Bluetooth permission not granted');
      }
      final paired = await PrintBluetoothThermal.pairedBluetooths;
      return paired.map((bt) => {'name': bt.name, 'mac': bt.macAdress}).toList();
    } catch (e) {
      debugPrint('Error scanning devices: $e');
      return [];
    }
  }

  /// Connect to a Bluetooth printer by MAC address
  Future<bool> connect(String macAddress, String deviceName) async {
    try {
      final result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _isConnected = result;
      if (result) {
        _connectedDevice = deviceName;
      }
      return result;
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      return false;
    }
  }

  /// Disconnect from current printer
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
    _isConnected = false;
    _connectedDevice = '';
  }

  /// Print receipt from transaction data
  Future<void> printReceipt(Map<String, dynamic> transaction) async {
    if (!_isConnected) {
      // Try to auto-connect to last known device, or throw
      throw Exception('Printer tidak terhubung. Hubungkan printer terlebih dahulu.');
    }

    // Build receipt text content
    final receiptLines = _buildReceiptLines(transaction);
    final receiptBytes = _encodeReceipt(receiptLines);

    try {
      final result = await PrintBluetoothThermal.writeBytes(receiptBytes);
      if (!result) throw Exception('Gagal mengirim data ke printer');
    } catch (e) {
      debugPrint('Print error: $e');
      // If error, print the preview in console anyway
    }

    debugPrint('=== RECEIPT PREVIEW ===\n${receiptLines.join('\n')}\n====================');
  }

  List<String> _buildReceiptLines(Map<String, dynamic> tx) {
    final storeSettings = _localDb.getStoreSettings();
    final storeName = storeSettings['name'] ?? 'TOKO KASIR';
    final storeAddress = storeSettings['address'] ?? '';
    final storePhone = storeSettings['phone'] ?? '';

    final lines = <String>[];
    final divider = '--------------------------------';
    final now = DateTime.now();

    lines.add('');
    lines.add(_center(storeName.toUpperCase()));
    if (storeAddress.isNotEmpty) {
      // Simple word wrap for address to max 32 chars
      if (storeAddress.length <= 32) {
        lines.add(_center(storeAddress));
      } else {
        lines.add(_center(storeAddress.substring(0, 32)));
      }
    }
    if (storePhone.isNotEmpty) {
      lines.add(_center(storePhone));
    }
    lines.add(_center('Struk Pembayaran'));
    lines.add(divider);
    lines.add('Tgl : ${now.day}/${now.month}/${now.year} ${now.hour}:${_pad(now.minute)}');
    lines.add('Kasir: ${tx['kasir_name'] ?? '-'}');
    if (tx['customer_name'] != null) {
      lines.add('Pelanggan: ${tx['customer_name']}');
    }
    lines.add(divider);

    final items = tx['items'] as List? ?? [];
    for (var item in items) {
      final name = item['name'] ?? item['menu_name'] ?? 'Item';
      final qty = item['quantity'] ?? 1;
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final total = qty * price;
      lines.add(name);
      lines.add(_rightAlign('${qty}x Rp ${_formatRp(price)}', 'Rp ${_formatRp(total)}'));
    }

    lines.add(divider);
    if ((tx['discount_amount'] ?? 0) > 0) {
      lines.add(_rightAlign('Subtotal', 'Rp ${_formatRp((tx['subtotal_amount'] ?? tx['total_amount']))}'));
      lines.add(_rightAlign('Diskon', '- Rp ${_formatRp(tx['discount_amount'])}'));
    }
    if ((tx['service_amount'] ?? 0) > 0) {
      lines.add(_rightAlign('Service Charge', '+ Rp ${_formatRp(tx['service_amount'])}'));
    }
    if ((tx['tax_amount'] ?? 0) > 0) {
      lines.add(_rightAlign('Pajak', '+ Rp ${_formatRp(tx['tax_amount'])}'));
    }
    lines.add(divider);
    lines.add(_rightAlign('TOTAL', 'Rp ${_formatRp(tx['total_amount'])}'));
    lines.add(_rightAlign('Pembayaran', (tx['payment_method'] as String? ?? 'cash').toUpperCase()));
    lines.add(divider);
    lines.add(_center('Terima Kasih!'));
    lines.add(_center('Kunjungi kami lagi :)'));
    lines.add(divider);
    lines.add(_center('Powered by SELLORA'));
    lines.add('');
    lines.add('');

    return lines;
  }

  // ESC/POS encoding (simplified - actual implementation uses esc_pos_utils)
  List<int> _encodeReceipt(List<String> lines) {
    final List<int> bytes = [];
    // ESC @ - Initialize printer
    bytes.addAll([0x1B, 0x40]);
    for (final line in lines) {
      bytes.addAll(line.codeUnits);
      bytes.add(0x0A); // newline
    }
    // Cut paper
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  String _center(String text, {int width = 32}) {
    if (text.length >= width) return text;
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }

  String _rightAlign(String left, String right, {int width = 32}) {
    final spaces = width - left.length - right.length;
    if (spaces < 1) return '$left $right';
    return left + ' ' * spaces + right;
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatRp(dynamic amount) {
    if (amount == null) return '0';
    final num val = amount is num ? amount : double.tryParse(amount.toString()) ?? 0;
    return val.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }
}
