import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'project_service.dart';

class ExpensePdfService {
  static Future<Uint8List> generateExpenseSheet({
    required String projectId,
    required String companyName,
    required String quoteDate,
    required double budget,
    required List<Map<String, dynamic>> expenses,
    String completedDate = '',
  }) async {
    final pdf = pw.Document();

    final timesRegular = await rootBundle.load('assets/fonts/times.ttf');
    final ttfRegular = pw.Font.ttf(timesRegular);
    final timesBold = await rootBundle.load('assets/fonts/timesbd.ttf');
    final ttfBold = pw.Font.ttf(timesBold);

    final logoImage = await rootBundle.load('assets/logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    final spent = ProjectService.totalSpent(expenses);
    final balance = budget - spent;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        build: (context) => [
          // HEADER
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColor.fromHex('#c40000'), width: 4),
              ),
            ),
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(logo, width: 105),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'SVJM MOULD & SOLUTIONS',
                        style: pw.TextStyle(fontSize: 20, font: ttfBold, color: PdfColor.fromHex('#c40000')),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('No. 27/19 Muthuramalingam Street',
                          style: pw.TextStyle(fontSize: 11, font: ttfBold, color: PdfColor.fromHex('#2A42B8')),
                          textAlign: pw.TextAlign.center),
                      pw.Text('Ekkattuthangal, Chennai - 600032',
                          style: pw.TextStyle(fontSize: 11, font: ttfBold, color: PdfColor.fromHex('#2A42B8')),
                          textAlign: pw.TextAlign.center),
                      pw.Text('E-Mail: sekhar_raman@yahoo.com | Mobile: 9600675380',
                          style: pw.TextStyle(fontSize: 11, font: ttfBold, color: PdfColor.fromHex('#2A42B8')),
                          textAlign: pw.TextAlign.center),
                      pw.SizedBox(height: 3),
                      pw.Text('GST Number: 33EFMPS7708C1Z9',
                          style: pw.TextStyle(fontSize: 11, font: ttfRegular),
                          textAlign: pw.TextAlign.center),
                    ],
                  ),
                ),
                pw.SizedBox(width: 105),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // TOP INFO ROW
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Company Name: ', style: pw.TextStyle(font: ttfBold, fontSize: 13)),
                      pw.TextSpan(text: companyName, style: pw.TextStyle(font: ttfRegular, fontSize: 13)),
                    ]),
                  ),
                  pw.SizedBox(height: 4),
                  pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Project ID: ', style: pw.TextStyle(font: ttfBold, fontSize: 13)),
                      pw.TextSpan(text: projectId, style: pw.TextStyle(font: ttfRegular, fontSize: 13)),
                    ]),
                  ),
                  pw.SizedBox(height: 4),
                  pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Quote Date: ', style: pw.TextStyle(font: ttfBold, fontSize: 13)),
                      pw.TextSpan(text: quoteDate, style: pw.TextStyle(font: ttfRegular, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black),
                  color: PdfColor.fromHex('#f9f9f9'),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Budget  : ', style: pw.TextStyle(font: ttfBold, fontSize: 13)),
                      pw.TextSpan(text: ProjectService.formatAmount(budget), style: pw.TextStyle(font: ttfRegular, fontSize: 13)),
                    ])),
                    pw.SizedBox(height: 4),
                    pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Spent    : ', style: pw.TextStyle(font: ttfBold, fontSize: 13)),
                      pw.TextSpan(text: ProjectService.formatAmount(spent), style: pw.TextStyle(font: ttfRegular, fontSize: 13)),
                    ])),
                    pw.SizedBox(height: 4),
                    pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Balance : ', style: pw.TextStyle(font: ttfBold, fontSize: 13)),
                      pw.TextSpan(text: ProjectService.formatAmount(balance), style: pw.TextStyle(font: ttfRegular, fontSize: 13)),
                    ])),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // EXPENSE TABLE
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black),
            columnWidths: {
              0: const pw.FixedColumnWidth(40),
              1: const pw.FixedColumnWidth(90),
              2: const pw.FlexColumnWidth(),
              3: const pw.FixedColumnWidth(90),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#7f97bd')),
                children: [
                  _cell('S.No', ttfBold, center: true),
                  _cell('Date', ttfBold, center: true),
                  _cell('Description', ttfBold, center: true),
                  _cell('Amount', ttfBold, center: true, bgColor: PdfColor.fromHex('#f4cc63')),
                ],
              ),
              // Expense rows
              ...expenses.asMap().entries.map((e) {
                final idx = e.key;
                final exp = e.value;
                final bg = idx % 2 == 0 ? PdfColor.fromHex('#f0f0f0') : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _cell('${idx + 1}', ttfRegular, center: true),
                    _cell(exp['date'] ?? '', ttfRegular, center: true),
                    _cell(exp['note'] ?? '', ttfRegular),
                    _cell('₹${exp['amount']}', ttfRegular, center: true),
                  ],
                );
              }),
              // Total row
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(''),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(''),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Total:', style: pw.TextStyle(font: ttfBold), textAlign: pw.TextAlign.right),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(ProjectService.formatAmount(spent),
                        style: pw.TextStyle(font: ttfBold), textAlign: pw.TextAlign.center),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 60),

          // FOOTER
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              children: [
                pw.Text('Payments', style: pw.TextStyle(font: ttfRegular, fontSize: 13)),
                pw.SizedBox(height: 4),
                pw.Text('By SVJM MOULD & SOLUTIONS', style: pw.TextStyle(font: ttfBold, fontSize: 13)),
                pw.SizedBox(height: 4),
                pw.Text(
                  completedDate.isNotEmpty ? completedDate : _today(),
                  style: pw.TextStyle(font: ttfRegular, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(String text, pw.Font font, {bool center = false, PdfColor? bgColor}) {
    return pw.Container(
      color: bgColor,
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 12),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static String _today() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
