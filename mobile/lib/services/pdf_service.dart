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

  /// Informe diario de asistencia de un ensayo: lista a TODOS los miembros
  /// (no solo a quienes asistieron) cruzando con el registro de asistencia,
  /// para que tambien se vea claramente quien faltó.
  static Future<Uint8List> generateDailyAttendanceReport({
    required String date,
    required String startTime,
    required String endTime,
    String? description,
    required List<Map<String, dynamic>> members,
    required List<Map<String, dynamic>> attendance,
  }) async {
    final pdf = pw.Document();
    final attendanceByMember = {for (final a in attendance) a['member_id'] as int: a};

    final logoBytes = (await rootBundle.load('assets/icon.png')).buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    final rows = <List<String>>[];
    int presentCount = 0, lateCount = 0, absentCount = 0, justifiedCount = 0;

    for (final m in members) {
      final a = attendanceByMember[m['id'] as int];
      String estado;
      String multa = '-';
      if (a == null) {
        estado = 'Ausente';
        absentCount++;
      } else if (a['arrival_time'] == 'FJ') {
        estado = 'Falta justificada';
        justifiedCount++;
      } else if (a['status'] == 'late') {
        estado = 'Tarde (${a['late_minutes']}min)';
        final fine = (a['fine_amount'] as num?)?.toDouble() ?? 0;
        multa = fine > 0 ? 'S/ ${fine.toStringAsFixed(2)}' : '-';
        lateCount++;
      } else {
        estado = 'Presente';
        presentCount++;
      }
      rows.add([m['name'] as String, estado, multa]);
    }

    final dateObj = DateTime.tryParse(date);
    final dateLabel = dateObj != null
        ? '${dateObj.day.toString().padLeft(2, '0')}/${dateObj.month.toString().padLeft(2, '0')}/${dateObj.year}'
        : date;
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          // ── Membrete institucional ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(width: 56, height: 56, child: pw.Image(logoImage)),
              pw.Expanded(
                child: pw.Column(children: [
                  pw.Text('UNIVERSIDAD NACIONAL SAN ANTONIO ABAD DEL CUSCO', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('SCALA CORAL UNIVERSITARIA', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
              ),
              pw.SizedBox(width: 56),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1, color: PdfColors.black),
          pw.SizedBox(height: 16),
          pw.Center(child: pw.Text('INFORME DE ASISTENCIA', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),

          // ── Datos del ensayo ──
          pw.Text('1. Fecha:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text(dateLabel, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 10),
          pw.Text('2. Horario:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text('$startTime - $endTime', style: const pw.TextStyle(fontSize: 11)),
          if (description != null && description.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('3. Descripción:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(description, style: const pw.TextStyle(fontSize: 11)),
          ],
          pw.SizedBox(height: 18),

          pw.Row(children: [
            _summaryChip('Presentes', presentCount, PdfColors.green),
            pw.SizedBox(width: 8),
            _summaryChip('Tardanzas', lateCount, PdfColors.orange),
            pw.SizedBox(width: 8),
            _summaryChip('Justificados', justifiedCount, PdfColors.blue),
            pw.SizedBox(width: 8),
            _summaryChip('Ausentes', absentCount, PdfColors.red),
          ]),
          pw.SizedBox(height: 20),
          pw.Center(child: pw.Text('Relación de asistencia:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(110),
              3: const pw.FixedColumnWidth(64),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [_cell('N°', true), _cell('Nombre', true), _cell('Estado', true), _cell('Multa', true)],
              ),
              for (int i = 0; i < rows.length; i++)
                pw.TableRow(children: [_cell('${i + 1}'), _cell(rows[i][0]), _cell(rows[i][1]), _cell(rows[i][2])]),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('Generado el ${now.day}/${now.month}/${now.year}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _summaryChip(String label, int count, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(children: [
          pw.Text('$count', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ]),
      ),
    );
  }

  static pw.Widget _cell(String text, [bool header = false]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}
