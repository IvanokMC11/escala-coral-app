import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _fines = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  int? _memberId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _memberId = DatabaseService.currentUser?['member_id'] as int?;
    if (_memberId != null) {
      _attendance = await DatabaseService.getMyAttendance(_memberId!);
      _fines = await DatabaseService.getMyFines(_memberId!);
      _stats = await DatabaseService.getMyStats(_memberId!);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = (_stats['total'] as int?) ?? 0;
    final attended = (_stats['attended'] as int?) ?? 0;
    final late = (_stats['late_count'] as int?) ?? 0;
    final absent = (_stats['absent_count'] as int?) ?? 0;
    final fines = (_stats['total_fines'] as num?)?.toDouble() ?? 0;
    final paid = (_stats['paid_fines'] as num?)?.toDouble() ?? 0;
    final pct = total > 0 ? (attended / total * 100).toStringAsFixed(1) : '0';
    final debt = fines - paid;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi asistencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22))),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _memberId == null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_off, size: 64, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Sin perfil vinculado', style: theme.textTheme.titleMedium),
              Text('Contacta al administrador', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.colorScheme.primaryContainer, theme.colorScheme.primary.withValues(alpha: 0.2)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _StatCircle(theme: theme, label: 'Asistencia', value: '$pct%', color: total > 0 && attended / total >= 0.9 ? Colors.green : total > 0 && attended / total >= 0.7 ? Colors.orange : Colors.red),
                          _StatCircle(theme: theme, label: 'Tardanzas', value: '$late', color: Colors.orange),
                          _StatCircle(theme: theme, label: 'Faltas', value: '$absent', color: Colors.red),
                        ]),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          Text('Deuda: S/ ${debt.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: debt > 0 ? theme.colorScheme.error : Colors.green)),
                          Text('Pagado: S/ ${paid.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: Colors.green)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    if (_fines.isNotEmpty) ...[
                      Row(children: [Icon(Icons.warning, size: 18, color: Colors.orange), const SizedBox(width: 8), Text('Multas', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 8),
                      ..._fines.map((f) => Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, color: (f['paid'] == 1 ? Colors.green : Colors.red).withValues(alpha: 0.15)), child: Icon(f['paid'] == 1 ? Icons.check_circle : Icons.error, color: f['paid'] == 1 ? Colors.green : Colors.red, size: 20)),
                          title: Text(f['reason'] ?? '', style: const TextStyle(fontSize: 13)),
                          subtitle: Text(f['paid'] == 1 ? 'Pagado' : 'Pendiente', style: TextStyle(fontSize: 11, color: f['paid'] == 1 ? Colors.green : Colors.red)),
                          trailing: Text('S/ ${(f['amount'] as num).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: f['paid'] == 1 ? Colors.green : theme.colorScheme.error)),
                          dense: true,
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],
                    Row(children: [Icon(Icons.history, size: 18, color: theme.colorScheme.primary), const SizedBox(width: 8), Text('Historial de ensayos', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 8),
                    if (_attendance.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Sin registro de asistencias', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))))
                    else
                      ..._attendance.map((a) {
                        IconData icon; Color color; String label;
                        if (a['arrival_time'] == 'FJ') { icon = Icons.healing; color = Colors.orange; label = 'Justificado'; }
                        else if (a['status'] == 'present') { icon = Icons.check_circle; color = Colors.green; label = 'A tiempo'; }
                        else if (a['status'] == 'late') { icon = Icons.warning_amber; color = Colors.orange; label = 'Tarde ${a['late_minutes']}min'; }
                        else { icon = Icons.cancel; color = Colors.red; label = 'Ausente'; }
                        final date = DateTime.tryParse(a['date']);
                        final formatted = date != null ? DateFormat('d MMM yyyy', 'es').format(date) : a['date'];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)), child: Icon(icon, color: color, size: 20)),
                            title: Text(formatted, style: const TextStyle(fontSize: 13)),
                            subtitle: Text(label, style: TextStyle(fontSize: 11, color: color)),
                            trailing: (a['fine_amount'] as num?)?.toDouble() != null && (a['fine_amount'] as num) > 0
                              ? Text('S/ ${(a['fine_amount'] as num).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: a['collected'] == 1 ? Colors.green : theme.colorScheme.error))
                              : null,
                            dense: true,
                          ),
                        );
                      }),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCircle extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final String value;
  final Color color;
  const _StatCircle({required this.theme, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
        child: Center(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}
