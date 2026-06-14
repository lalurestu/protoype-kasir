
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateOwnerReport(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final totalRevenue = data['total_revenue'] ?? 0;
    final totalTransactions = data['total_transactions'] ?? 0;
    final totalCustomers = data['total_customers'] ?? 0;
    final dailySales = (data['daily_sales'] as List?) ?? [];
    final topMenus = (data['top_menus'] as List?) ?? [];

    final numberFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader(),
          pw.SizedBox(height: 20),
          _buildSummary(totalRevenue, totalTransactions, totalCustomers, numberFormat),
          pw.SizedBox(height: 20),
          _buildDailySales(dailySales, numberFormat),
          pw.SizedBox(height: 20),
          _buildTopMenus(topMenus),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Penjualan_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('LAPORAN PENJUALAN', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Tanggal Dicetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12)),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildSummary(num revenue, num transactions, num customers, NumberFormat format) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Omset', format.format(revenue)),
          _buildSummaryItem('Total Transaksi', transactions.toString()),
          _buildSummaryItem('Total Pelanggan', customers.toString()),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: const pw.TextStyle(fontSize: 14)),
      ],
    );
  }

  static pw.Widget _buildDailySales(List<dynamic> dailySales, NumberFormat format) {
    if (dailySales.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Tren Penjualan (7 Hari Terakhir)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Tanggal', 'Omset (Rp)'],
          data: dailySales.map((d) => [d['date'], format.format(d['total_amount'] ?? 0)]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  static pw.Widget _buildTopMenus(List<dynamic> topMenus) {
    if (topMenus.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Menu Terlaris', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Nama Menu', 'Terjual'],
          data: topMenus.map((m) => [m['name'], m['sold'].toString()]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }
}
