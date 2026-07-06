import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class AttendanceScreen extends StatefulWidget {
  final int rehearsalId;
  final String rehearsalDate;
  final String startTime;
  final String endTime;
  final bool isCanceled;

  const AttendanceScreen({
    super.key,
    required this.rehearsalId,
    required this.rehearsalDate,
    required this.startTime,
    required this.endTime,
    this.isCanceled = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _monthStats = [];
  bool _loading = true;
  bool _insideHours = false;

  @override
  void initState() {
    super.initState();
    _checkHours();
    _load();
  }

  void _checkHours() {
    final now = DateTime.now();
    final parts = widget.startTime.split(':').map(int.parse).toList();
    final start = DateTime(now.year, now.month, now.day, parts[0], parts[1]);
    final endParts = widget.endTime.split(':').map(int.parse).toList();
    final end = DateTime(now.year, now.month, now.day, endParts[0], endParts[1]);
    _insideHours = now.isAfter(start) && now.isBefore(end);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _attendance = await DatabaseService.getRehearsalAttendance(widget.rehearsalId);
    _members = await DatabaseService.getMembers();
    final now = DateTime.now();
    _monthStats = await DatabaseService.getMemberMonthlyStats(now.year, now.month);
    _checkHours();
    setState(() => _loading = false);
  }

  String _now() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _mark(int memberId) async {
    await DatabaseService.markAttendance(memberId, widget.rehearsalId, _now());
    _load();
  }

  Future<void> _markFJ(int memberId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Falta Justificada'),
        content: Text('¿Seguro que $name justificó su falta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('RECHAZAR')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ACEPTAR')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.markFJ(memberId, widget.rehearsalId);
      _load();
    }
  }

  List<Map<String, dynamic>> get _unmarked {
    final marked = _attendance.map((a) => a['member_id'] as int).toSet();
    return _members.where((m) => !marked.contains(m['id'])).toList();
  }

  Map<String, dynamic>? _getStats(int memberId) {
    try { return _monthStats.firstWhere((s) => s['id'] == memberId); } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(widget.rehearsalDate);
    final formatted = date != null ? DateFormat("EEEE d 'de' MMMM", 'es').format(date) : widget.rehearsalDate;

    return Scaffold(
      appBar: AppBar(title: const Text('Asistencia')),
      body: widget.isCanceled
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.block, size: 64, color: Colors.orange), const SizedBox(height: 16), Text('Este ensayo fue cancelado', style: theme.textTheme.titleMedium), const Text('No hubo ensayo este dia')]))
        : _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${formatted[0].toUpperCase()}${formatted.substring(1)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${widget.startTime} - ${widget.endTime}'),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: _insideHours ? Colors.green : Colors.grey, borderRadius: BorderRadius.circular(4)),
                            child: Text(_insideHours ? 'HORARIO DE ENSAYO' : 'FUERA DE HORARIO', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_unmarked.isNotEmpty) ...[
                      ..._unmarked.map((m) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(m['name']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.healing, size: 18),
                                label: const Text('FJ', style: TextStyle(fontSize: 11)),
                                onPressed: _insideHours ? () => _markFJ(m['id'], m['name']) : null,
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Marcar'),
                                onPressed: _insideHours ? () => _mark(m['id']) : null,
                              ),
                            ],
                          ),
                        ),
                      )),
                      const Divider(height: 32),
                    ],
                    Text('Asistencia registrada', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_attendance.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Sin asistencias aun', style: theme.textTheme.bodyLarge)))
                    else
                      ..._attendance.map((a) {
                        IconData icon; Color color; String label;
                        if (a['arrival_time'] == 'FJ') {
                          icon = Icons.healing; color = Colors.orange; label = 'Falta justificada';
                        } else switch (a['status'] as String) {
                          case 'present': icon = Icons.check_circle; color = Colors.green; label = 'A tiempo'; break;
                          case 'late': icon = Icons.warning_amber; color = Colors.orange; label = 'Tarde ${a['late_minutes']}min - S/ ${(a['fine_amount'] as num).toStringAsFixed(2)}'; break;
                          default: icon = Icons.cancel; color = Colors.red; label = 'Ausente';
                        }
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: Icon(icon, color: color, size: 28),
                            title: Text(a['member_name'] ?? ''),
                            subtitle: Text(label),
                            dense: true,
                          ),
                        );
                      }),
                    const Divider(height: 32),
                    Text('Resumen mensual', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._members.map((m) {
                      final s = _getStats(m['id']);
                      final total = s != null ? s['total_rehearsals'] as int : 0;
                      final attended = s != null ? s['attended'] as int : 0;
                      final late = s != null ? s['late_count'] as int : 0;
                      final fine = s != null ? (s['total_fine'] as num).toDouble() : 0.0;
                      final pct = total > 0 ? (attended / total * 100).toStringAsFixed(0) : '-';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(m['name'], style: const TextStyle(fontSize: 13))),
                              Expanded(child: Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, color: total > 0 && attended / total >= 0.9 ? Colors.green : total > 0 && attended / total >= 0.7 ? Colors.orange : Colors.red, fontSize: 13))),
                              Expanded(child: Text('T:$late', style: const TextStyle(fontSize: 12))),
                              Expanded(child: Text('S/ ${fine.toStringAsFixed(2)}', style: TextStyle(color: fine > 0 ? theme.colorScheme.error : null, fontSize: 12))),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}
