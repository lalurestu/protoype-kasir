import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';

class ExcelService {
  static Future<String?> generateOwnerReport(Map<String, dynamic> data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan Penjualan'];
    excel.setDefaultSheet('Laporan Penjualan');

    final totalRevenue = data['total_revenue'] ?? 0;
    final totalTransactions = data['total_transactions'] ?? 0;
    final totalCustomers = data['total_customers'] ?? 0;
    final dailySales = (data['daily_sales'] as List?) ?? [];
    final topMenus = (data['top_menus'] as List?) ?? [];

    final numberFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final thinBorder = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.black,
    );

    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.blueGrey,
      fontColorHex: ExcelColor.white,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );

    final titleStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Left,
      fontSize: 14,
    );

    final rowStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );

    void addStyledRow(List<CellValue> cells, {CellStyle? style}) {
      sheet.appendRow(cells);
      if (style != null) {
        int rowIndex = sheet.maxRows - 1;
        for (int i = 0; i < cells.length; i++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex)).cellStyle = style;
        }
      }
    }

    // Title
    addStyledRow([TextCellValue('LAPORAN PENJUALAN KASIR')], style: titleStyle);
    sheet.appendRow([TextCellValue('Tanggal Dicetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}')]);
    sheet.appendRow([TextCellValue('')]);

    // Summary Table
    addStyledRow([TextCellValue('RINGKASAN BISNIS')], style: titleStyle);
    addStyledRow([TextCellValue('Kategori'), TextCellValue('Nilai')], style: headerStyle);
    addStyledRow([TextCellValue('Total Omset'), TextCellValue(numberFormat.format(totalRevenue))], style: rowStyle);
    addStyledRow([TextCellValue('Total Transaksi'), IntCellValue(int.parse(totalTransactions.toString()))], style: rowStyle);
    addStyledRow([TextCellValue('Total Pelanggan'), IntCellValue(int.parse(totalCustomers.toString()))], style: rowStyle);
    sheet.appendRow([TextCellValue('')]);

    // Tren Penjualan Table
    addStyledRow([TextCellValue('TREN PENJUALAN (7 HARI TERAKHIR)')], style: titleStyle);
    addStyledRow([TextCellValue('Tanggal'), TextCellValue('Omset')], style: headerStyle);
    for (var d in dailySales) {
      addStyledRow([
        TextCellValue(d['date']?.toString() ?? ''),
        IntCellValue((double.tryParse(d['total']?.toString() ?? '0') ?? 0.0).toInt()),
      ], style: rowStyle);
    }
    sheet.appendRow([TextCellValue('')]);

    // Menu Terlaris Table
    addStyledRow([TextCellValue('MENU TERLARIS')], style: titleStyle);
    addStyledRow([TextCellValue('Nama Menu'), TextCellValue('Terjual')], style: headerStyle);
    for (var m in topMenus) {
      addStyledRow([
        TextCellValue(m['name']?.toString() ?? ''),
        IntCellValue((double.tryParse(m['sold']?.toString() ?? '0') ?? 0.0).toInt()),
      ], style: rowStyle);
    }

    // Adjust column widths roughly
    sheet.setColumnWidth(0, 30.0);
    sheet.setColumnWidth(1, 20.0);

    // Save File
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final fileName = 'Laporan_Penjualan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(fileBytes),
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        return null;
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      }
    }
    return null;
  }
}
