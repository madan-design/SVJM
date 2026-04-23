import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {

  static Future<Uint8List> generateQuote(Map data) async {

    final pdf = pw.Document();

    // Load assets
    final logoImage = await rootBundle.load('assets/new_logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());
    
    final bgImage = await rootBundle.load('assets/bg.png');
    final watermark = pw.MemoryImage(bgImage.buffer.asUint8List());
    
    final signImage = await rootBundle.load('assets/sign.png');
    final signature = pw.MemoryImage(signImage.buffer.asUint8List());

    // Load Times New Roman fonts
    final timesRegular = await rootBundle.load('assets/fonts/times.ttf');
    final ttfRegular = pw.Font.ttf(timesRegular);
    
    final timesBold = await rootBundle.load('assets/fonts/timesbd.ttf');
    final ttfBold = pw.Font.ttf(timesBold);

    final components = data["components"] as List;
    final includeMachine = data["includeMachine"] ?? true;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(
          base: ttfRegular,
          bold: ttfBold,
        ),
        build: (context) {
          return pw.Stack(
            children: [
              // Watermark background - full image
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Image(watermark, fit: pw.BoxFit.contain),
                ),
              ),
              
              // Main content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  
                  // HEADER
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColor.fromHex('#c40000'),
                          width: 4,
                        ),
                      ),
                    ),
                    padding: pw.EdgeInsets.only(bottom: 8),
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
                                style: pw.TextStyle(
                                  fontSize: 20,
                                  font: ttfBold,
                                  color: PdfColor.fromHex('#c40000'),
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'No. 27/19 Muthuramalingam Street',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  font: ttfBold,
                                  color: PdfColor.fromHex('#2A42B8'),
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.Text(
                                'Ekkattuthangal, Chennai - 600032',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  font: ttfBold,
                                  color: PdfColor.fromHex('#2A42B8'),
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.Text(
                                'E-Mail: sekhar_raman@yahoo.com | Mobile: 9600675380',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  font: ttfBold,
                                  color: PdfColor.fromHex('#2A42B8'),
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'GST Number: 33EFMPS7708C1Z9',
                                style: pw.TextStyle(fontSize: 11, font: ttfRegular),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 105),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 18),

                  // TO and DATE section
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('To', style: pw.TextStyle(font: ttfBold)),
                            pw.Text(data["company"], style: pw.TextStyle(font: ttfRegular)),
                            pw.Text(data["address"], style: pw.TextStyle(font: ttfRegular)),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'DATE: ${data["date"]}',
                            style: pw.TextStyle(font: ttfBold),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 14),

                  // SUBJECT
                  pw.Text(
                    'Reg: ${data["subject"]}',
                    style: pw.TextStyle(font: ttfBold),
                  ),

                  pw.SizedBox(height: 10),

                  // INTRO
                  pw.Text('Dear Sir,', style: pw.TextStyle(font: ttfRegular)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'We thank you very much for your kindly enquiry and we are pleased to submit our lowest offer for mould the following items as per the model.',
                    style: pw.TextStyle(font: ttfRegular),
                  ),

                  pw.SizedBox(height: 15),

                  // TABLE
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black),
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#a0a0a0')),
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(6),
                            child: pw.Text(
                              'S.no',
                              style: pw.TextStyle(font: ttfBold),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(6),
                            child: pw.Text(
                              'Description',
                              style: pw.TextStyle(font: ttfBold),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(6),
                            child: pw.Text(
                              'Amount',
                              style: pw.TextStyle(font: ttfBold),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          if (includeMachine)
                            pw.Padding(
                              padding: pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Machine',
                                style: pw.TextStyle(font: ttfBold),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                      // Data rows
                      ...components.asMap().entries.map((entry) {
                        int index = entry.key;
                        var c = entry.value;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: index % 2 == 0 ? PdfColor.fromHex('#e8e8e8') : PdfColors.white,
                          ),
                          children: [
                            pw.Padding(
                              padding: pw.EdgeInsets.all(6),
                              child: pw.Text(
                                '${index + 1}',
                                style: pw.TextStyle(font: ttfRegular),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(6),
                              child: pw.Text(c["description"], style: pw.TextStyle(font: ttfRegular)),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Rs. ${c["amount"]}',
                                style: pw.TextStyle(font: ttfRegular),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            if (includeMachine)
                              pw.Padding(
                                padding: pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  c["machine"] ?? '',
                                  style: pw.TextStyle(font: ttfRegular),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.SizedBox(height: 12),

                  pw.Text(
                    'We hope our above offer is in line with your requirements and we are awaiting for your valuable order at the earliest.',
                    style: pw.TextStyle(font: ttfRegular),
                  ),

                  pw.SizedBox(height: 15),

                  // TERMS AND CONDITIONS
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Terms and Conditions:',
                        style: pw.TextStyle(
                          font: ttfBold,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('1. 50% Advance along with Purchase Order.', style: pw.TextStyle(font: ttfRegular)),
                      pw.Text('2. 25% Payment after trial.', style: pw.TextStyle(font: ttfRegular)),
                      pw.Text('3. 25% Final payment after delivery of the Mould.', style: pw.TextStyle(font: ttfRegular)),
                      pw.Text('4. Delivery 40-45 working days and GST added to billing.', style: pw.TextStyle(font: ttfRegular)),
                    ],
                  ),

                  pw.SizedBox(height: 15),

                  // BANK DETAILS
                  pw.Container(
                    width: 260,
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Bank Details',
                          style: pw.TextStyle(font: ttfBold),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text('Bank Name : IDBI Bank', style: pw.TextStyle(font: ttfRegular)),
                        pw.Text('Branch : Ashok Nagar', style: pw.TextStyle(font: ttfRegular)),
                        pw.Text('Account Number : 0630102000017037', style: pw.TextStyle(font: ttfRegular)),
                        pw.Text('IFSC Code : IBKL0000630', style: pw.TextStyle(font: ttfRegular)),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  // SIGNATURE
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      children: [
                        pw.Text('With Regards,', style: pw.TextStyle(font: ttfRegular)),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'For SVJM MOULD & SOLUTIONS',
                          style: pw.TextStyle(font: ttfBold),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Image(signature, width: 110),
                        pw.Text('Proprietor', style: pw.TextStyle(font: ttfRegular)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}