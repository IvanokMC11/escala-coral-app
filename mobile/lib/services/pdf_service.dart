import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  static Future<Uint8List> generateBecaComedor({
    required int year,
    required int month,
    required List<Map<String, dynamic>> top10,
    required String presidente,
  }) async {
    final pdf = pw.Document();
    final months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Setiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final monthName = months[month];

    final sigBytes = (await rootBundle.load('assets/firma_jaide_ramirez.png')).buffer.asUint8List();
    final sigImage = pw.MemoryImage(sigBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => [
          pw.Center(child: pw.Text('FORMATO DE PRESENTACIÓN - BECA COMEDOR', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 24),
          pw.Text('Datos generales:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Fecha: ${DateTime(year, month).day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year'),
          pw.Text('Nombre del Grupo Cultural: Scala Coral Universitaria'),
          pw.Text('Mes correspondiente de la beca comedor: $monthName'),
          pw.SizedBox(height: 16),
          pw.Text('Yo, $presidente, presidente del Grupo Cultural Scala Coral Universitaria, hago constar que los estudiantes consignados en la relación adjunta son integrantes activos del grupo cultural, participando constantemente en ensayos, presentaciones, actividades culturales y demás acciones programadas por la universidad y el grupo correspondiente.'),
          pw.SizedBox(height: 24),
          pw.Center(child: pw.Text('Relación de estudiantes beneficiarios:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(64),
              3: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('N°', true),
                  _cell('Nombres y Apellidos', true),
                  _cell('Código', true),
                  _cell('Escuela Profesional', true),
                ],
              ),
              for (int i = 0; i < top10.length; i++) ...[
                pw.TableRow(children: [
                  _cell('${i + 1}'),
                  _cell(top10[i]['member_name'] ?? ''),
                  _cell(top10[i]['codigo']?.toString() ?? ''),
                  _cell(top10[i]['escuela']?.toString() ?? ''),
                ]),
              ],
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(sigImage, width: 100, height: 40),
                  pw.SizedBox(height: 4),
                  pw.Text('____________________________'),
                  pw.Text('Firma del Presidente'),
                  pw.SizedBox(height: 4),
                  pw.Text(presidente, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(String text, [bool header = false]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}
