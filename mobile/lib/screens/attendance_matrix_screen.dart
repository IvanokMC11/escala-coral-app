import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class AttendanceMatrixScreen extends StatefulWidget {
  const AttendanceMatrixScreen({super.key});

  @override
  State<AttendanceMatrixScreen> createState() => _AttendanceMatrixScreenState();
}

class _AttendanceMatrixScreenState extends State<AttendanceMatrixScreen> {
  late int _year, _month;
  List<Map<String, dynamic>> _rehearsals = [];
  List<Map<String, dynamic>> _members = [];
  Map<String, Map<String, dynamic>> _attendance = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseService.getAttendanceMatrix(_year, _month);
    _rehearsals = data['rehearsals'] as List<Map<String, dynamic>>;
    _members = data['members'] as List<Map<String, dynamic>>;
    _attendance = data['attendance'] as Map<String, Map<String, dynamic>>;
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

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year, _month, 1),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      locale: const Locale('es'),
    );
    if (picked != null && mounted) {
      setState(() { _year = picked.year; _month = picked.month; });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = DateFormat('MMMM yyyy', 'es').format(DateTime(_year, _month));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Row(children: [
                        Text(monthName[0].toUpperCase() + monthName.substring(1), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                      ]),
                    ),
                    IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
                  ],
                ),
              ),
              Expanded(
                child: _rehearsals.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5)), child: Icon(Icons.calendar_month_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      Text('Sin ensayos este mes', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ]))
                  : Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(theme.colorScheme.primaryContainer.withValues(alpha: 0.4)),
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 48,
                            columnSpacing: 6,
                            horizontalMargin: 8,
                            columns: [
                              DataColumn(label: SizedBox(width: 140, child: Text('Miembro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                              ..._rehearsals.map((r) {
                                final date = DateTime.tryParse(r['date']);
                                final day = date?.day.toString() ?? '';
                                final dayName = date != null ? DateFormat('EEEEE', 'es').format(date)[0].toUpperCase() : '';
                                return DataColumn(label: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(dayName, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant)),
                                  Text(day, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ]));
                              }),
                              DataColumn(label: Text('%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('T', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Multa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                            rows: _members.map((m) {
                              int attended = 0, lateCount = 0;
                              double fineTotal = 0;
                              return DataRow(cells: [
                                DataCell(SizedBox(width: 140, child: Text(m['name'], style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                                ..._rehearsals.map((r) {
                                  final key = '${m['id']}_${r['id']}';
                                  final a = _attendance[key];
                                  IconData icon; Color color;
                                  if (a == null) {
                                    icon = Icons.remove; color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
                                  } else if (a['arrival_time'] == 'FJ') {
                                    icon = Icons.healing; color = Colors.orange; attended++;
                                  } else if (a['status'] == 'present') {
                                    icon = Icons.check_circle; color = Colors.green; attended++;
                                  } else if (a['status'] == 'late') {
                                    icon = Icons.warning_amber; color = Colors.orange; attended++; lateCount++;
                                    fineTotal += (a['fine_amount'] as num).toDouble();
                                  } else {
                                    icon = Icons.cancel; color = Colors.red;
                                  }
                                  return DataCell(Center(child: Icon(icon, size: 18, color: color)));
                                }),
                                DataCell(Center(child: Text(
                                  _rehearsals.length > 0 ? '${(attended / _rehearsals.length * 100).toStringAsFixed(0)}%' : '-',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _rehearsals.length > 0 && attended / _rehearsals.length >= 0.9 ? Colors.green : _rehearsals.length > 0 && attended / _rehearsals.length >= 0.7 ? Colors.orange : Colors.red),
                                ))),
                                DataCell(Center(child: Text('$lateCount', style: const TextStyle(fontSize: 11)))),
                                DataCell(Center(child: Text('S/ ${fineTotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: fineTotal > 0 ? theme.colorScheme.error : null)))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
              ),
            ],
          ),
    );
  }
}
