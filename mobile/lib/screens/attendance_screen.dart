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
    if (!_insideHours) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fuera de horario'),
          content: const Text('Estas fuera del horario de ensayo. ¿Seguro que quieres marcar asistencia?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Si, marcar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await DatabaseService.markAttendance(memberId, widget.rehearsalId, _now());
    _load();
  }

  Future<void> _markFJ(int memberId, String name) async {
    if (!_insideHours) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fuera de horario'),
          content: const Text('Estas fuera del horario de ensayo. ¿Seguro que quieres justificar la falta?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Si, justificar')),
          ],
        ),
      );
      if (ok != true) return;
    }
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
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withValues(alpha: 0.15)), child: const Icon(Icons.block, size: 56, color: Colors.orange)),
            const SizedBox(height: 20),
            Text('Este ensayo fue cancelado', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('No hubo ensayo este dia', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ]))
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
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.colorScheme.primaryContainer, theme.colorScheme.primary.withValues(alpha: 0.2)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${formatted[0].toUpperCase()}${formatted.substring(1)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text('${widget.startTime} - ${widget.endTime}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                          ]),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _insideHours ? Colors.green : Colors.grey.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_insideHours ? Icons.play_circle_fill : Icons.pause_circle, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(_insideHours ? 'HORARIO DE ENSAYO' : 'FUERA DE HORARIO', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (DatabaseService.isStaff && _unmarked.isNotEmpty) ...[
                      Row(children: [
                        Icon(Icons.person_add, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Marcar asistencia (${_unmarked.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 12),
                      ..._unmarked.map((m) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text((m['name'] as String).split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(m['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.healing, size: 16),
                                label: const Text('FJ', style: TextStyle(fontSize: 11)),
                                onPressed: () => _markFJ(m['id'], m['name']),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Marcar'),
                                onPressed: () => _mark(m['id']),
                              ),
                            ],
                          ),
                        ),
                      )),
                      const Divider(height: 32),
                    ],
                    Row(children: [
                      Icon(Icons.list, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Asistencia registrada (${_attendance.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 12),
                    if (_attendance.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [
                        Icon(Icons.how_to_reg, size: 48, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('Sin asistencias aun', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ])))
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
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            title: Text(a['member_name'] ?? '', style: const TextStyle(fontSize: 14)),
                            subtitle: Text(label, style: TextStyle(fontSize: 12, color: color)),
                            dense: true,
                          ),
                        );
                      }),
                    const Divider(height: 32),
                    Row(children: [
                      Icon(Icons.date_range, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Resumen mensual', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 12),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(m['name'], style: const TextStyle(fontSize: 13))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: total > 0 && attended / total >= 0.9 ? Colors.green.withValues(alpha: 0.15) : total > 0 && attended / total >= 0.7 ? Colors.orange.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                ),
                                child: Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, color: total > 0 && attended / total >= 0.9 ? Colors.green : total > 0 && attended / total >= 0.7 ? Colors.orange : Colors.red, fontSize: 13)),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(width: 40, child: Text('T:$late', style: const TextStyle(fontSize: 12))),
                              SizedBox(width: 60, child: Text('S/ ${fine.toStringAsFixed(2)}', style: TextStyle(color: fine > 0 ? theme.colorScheme.error : null, fontSize: 12))),
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
