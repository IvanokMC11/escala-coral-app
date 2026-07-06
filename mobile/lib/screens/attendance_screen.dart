import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/rehearsal.dart';
import '../models/attendance.dart';
import '../providers/app_state.dart';

class AttendanceScreen extends StatefulWidget {
  final Rehearsal rehearsal;
  const AttendanceScreen({super.key, required this.rehearsal});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Attendance> _attendance = [];
  bool _loading = true;
  final _timeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppState>().api;
      final att = await api.getRehearsalAttendance(widget.rehearsal.id);
      setState(() => _attendance = att);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar asistencias')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllPresent() async {
    try {
      final api = context.read<AppState>().api;
      final members = await api.getMembers();
      final records = members
          .where((m) => m.isActive)
          .map((m) => {
                'member_id': m.id,
                'arrival_time': widget.rehearsal.startTime,
              })
          .toList();
      await api.markBatchAttendance(widget.rehearsal.id, records);
      _loadAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _markAttendance(int memberId) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final arrivalTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    try {
      await context.read<AppState>().api.markAttendance(
            memberId,
            widget.rehearsal.id,
            arrivalTime,
          );
      _loadAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(widget.rehearsal.date);
    final formattedDate = date != null
        ? DateFormat("EEEE d 'de' MMMM", 'es').format(date)
        : widget.rehearsal.date;
    final isAdmin = context.watch<AppState>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text('Asistencia'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Marcar todos presente',
              onPressed: _markAllPresent,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formattedDate[0].toUpperCase()}${formattedDate.substring(1)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.rehearsal.startTime} - ${widget.rehearsal.endTime}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (widget.rehearsal.description != null) ...[
                  const SizedBox(height: 4),
                  Text(widget.rehearsal.description!,
                      style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          _loading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAttendance,
                    child: _attendance.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off_outlined,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(height: 16),
                                Text('Sin asistencias registradas',
                                    style: theme.textTheme.bodyLarge),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _attendance.length,
                            itemBuilder: (_, i) {
                              final a = _attendance[i];
                              return _AttendanceTile(
                                attendance: a,
                                canMark: isAdmin,
                                onTap: () =>
                                    _markAttendance(a.memberId),
                              );
                            },
                          ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  final Attendance attendance;
  final bool canMark;
  final VoidCallback onTap;

  const _AttendanceTile({
    required this.attendance,
    required this.canMark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    IconData icon;
    Color color;

    switch (attendance.status) {
      case 'present':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'late':
        icon = Icons.warning_amber;
        color = Colors.orange;
        break;
      case 'absent':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(attendance.memberName ?? 'Miembro #${attendance.memberId}'),
        subtitle: attendance.isLate
            ? Text(
                'Llego: ${attendance.arrivalTime} | '
                'Retraso: ${attendance.lateMinutes} min | '
                'Multa: S/ ${attendance.fineAmount.toStringAsFixed(2)}',
                style: TextStyle(color: theme.colorScheme.error),
              )
            : attendance.isPresent
                ? Text('Llego: ${attendance.arrivalTime}')
                : Text('Ausente'),
        trailing: canMark && attendance.isAbsent
            ? IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onTap,
              )
            : null,
      ),
    );
  }
}
