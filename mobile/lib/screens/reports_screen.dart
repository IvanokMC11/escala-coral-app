import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import 'package:printing/printing.dart';
import '../services/pdf_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late int _year, _month;
  List<Map<String, dynamic>> _top10 = [];
  List<Map<String, dynamic>> _memberStats = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _top10 = await DatabaseService.getTop10(_year, _month);
      _memberStats = await DatabaseService.getMemberMonthlyStats(_year, _month);
    } catch (e) {
      _error = 'Error al cargar datos';
    }
    setState(() => _loading = false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) { _month = 1; _year++; }
      else if (_month < 1) { _month = 12; _year--; }
    });
    _load();
  }

  Future<void> _generatePdf() async {
    final eligible = _top10.where((m) => (m['beca_eligible'] ?? 1) == 1).toList();
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay miembros aptos para beca')));
      return;
    }
    try {
      final pdfBytes = await PdfService.generateBecaComedor(
        year: _year, month: _month, top10: eligible,
        presidente: 'Jaide Liseth Ramirez Hurtado',
      );
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'beca_comedor_${_month}_$_year.pdf',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = DateFormat('MMMM yyyy', 'es').format(DateTime(_year, _month));

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16), Text(_error!, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8), FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                        Text('${monthName[0].toUpperCase()}${monthName.substring(1)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_top10.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TOP 10 - Asistencias', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          FilledButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('Beca Comedor'),
                            onPressed: _generatePdf,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 100,
                            barGroups: _top10.take(5).toList().asMap().entries.map((e) {
                              final i = e.key;
                              final r = e.value;
                              return BarChartGroupData(x: i, barRods: [
                                BarChartRodData(
                                  toY: (r['attendance_percentage'] as num).toDouble(),
                                  color: [Colors.purple, Colors.blue, Colors.teal, Colors.green, Colors.orange][i],
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: theme.colorScheme.surfaceContainerHighest),
                                ),
                              ]);
                            }).toList(),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)))),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx >= 0 && idx < _top10.take(5).length) {
                                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text((_top10[idx]['member_name'] as String).split(' ').first, style: const TextStyle(fontSize: 10)));
                                }
                                return const Text('');
                              })),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: (v) => FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 0.5)),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Table(
                            columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth(), 2: IntrinsicColumnWidth(), 3: IntrinsicColumnWidth(), 4: IntrinsicColumnWidth()},
                            children: [
                              TableRow(
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant))),
                                children: const [
                                  Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('%', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('Tard.', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('Multa', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                              ..._top10.asMap().entries.map((e) {
                                final i = e.key;
                                final r = e.value;
                                final pct = (r['attendance_percentage'] as num).toDouble();
                                return TableRow(
                                  decoration: i < 3 ? BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3)) : null,
                                  children: [
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: i < 3
                                      ? Icon([Icons.emoji_events, Icons.emoji_events, Icons.emoji_events][i], color: [Colors.amber, Colors.grey, Colors.brown][i], size: 18)
                                      : Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text(r['member_name'], style: const TextStyle(fontSize: 13))),
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: pct >= 90 ? Colors.green : pct >= 70 ? Colors.orange : Colors.red))),
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('${r['total_late_minutes']}min', style: const TextStyle(fontSize: 12))),
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('S/ ${(r['total_fine'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_top10.isEmpty)
                      Padding(padding: const EdgeInsets.all(32), child: Column(children: [Icon(Icons.bar_chart, size: 64, color: theme.colorScheme.onSurfaceVariant), const SizedBox(height: 16), Text('Sin datos para este mes', style: theme.textTheme.bodyLarge)])),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: Text('Detalle de miembros', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        if (_top10.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text('PDF Beca Comedor'),
                            onPressed: _generatePdf,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Table(
                          columnWidths: const {0: FlexColumnWidth(), 1: IntrinsicColumnWidth(), 2: IntrinsicColumnWidth(), 3: IntrinsicColumnWidth()},
                          children: [
                            TableRow(
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant))),
                              children: const [
                                Padding(padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Padding(padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Padding(padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('Tard.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Padding(padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('Multa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                            ),
                            ...(_memberStats.isEmpty ? _membersFallback() : _memberStats).map((s) {
                              final total = s['total_rehearsals'] as int;
                              final attended = s['attended'] as int;
                              final late = s['late_count'] as int;
                              final fine = (s['total_fine'] as num).toDouble();
                              final pct = total > 0 ? attended / total * 100 : 0.0;
                              return TableRow(children: [
                                Padding(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4), child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4), child: Text(total > 0 ? '${pct.toStringAsFixed(0)}%' : '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pct >= 90 ? Colors.green : pct >= 70 ? Colors.orange : Colors.red))),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4), child: Text('$late', style: const TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4), child: Text('S/ ${fine.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: fine > 0 ? theme.colorScheme.error : null))),
                              ]);
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Map<String, dynamic>> _membersFallback() {
    return _top10.map((t) => {
      'name': t['member_name'],
      'total_rehearsals': t['total_events'],
      'attended': (t['present_count'] as num) + (t['late_count'] as num),
      'late_count': t['late_count'],
      'total_fine': t['total_fine'],
    }).toList();
  }
}
