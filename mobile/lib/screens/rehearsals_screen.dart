import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import 'attendance_screen.dart';

class RehearsalsScreen extends StatefulWidget {
  const RehearsalsScreen({super.key});

  @override
  State<RehearsalsScreen> createState() => _RehearsalsScreenState();
}

class _RehearsalsScreenState extends State<RehearsalsScreen> {
  List<Map<String, dynamic>> _rehearsals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DatabaseService.autoGenerateRehearsals();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    _rehearsals = await DatabaseService.getRehearsals(month: now.month, year: now.year);
    setState(() => _loading = false);
  }

  Future<void> _toggleCancel(Map<String, dynamic> r) async {
    final newVal = (r['is_canceled'] == 1) ? 0 : 1;
    await DatabaseService.cancelRehearsal(r['id'], newVal == 1);
    _load();
  }

  Future<void> _deleteRehearsal(Map<String, dynamic> r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ensayo'),
        content: Text('Eliminar ensayo del ${r['date']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.deleteRehearsal(r['id']);
      _load();
    }
  }

  void _showCreate() {
    var selectedDate = DateTime.now();
    final startCtrl = TextEditingController(text: '18:00');
    final endCtrl = TextEditingController(text: '20:00');
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Nuevo ensayo'),
            content: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2030), locale: const Locale('es'));
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha', prefixIcon: Icon(Icons.calendar_today)),
                    child: Text(DateFormat('EEEE d MMMM yyyy', 'es').format(selectedDate).split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ')),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Inicio', prefixIcon: Icon(Icons.access_time))),
                const SizedBox(height: 12),
                TextFormField(controller: endCtrl, decoration: const InputDecoration(labelText: 'Fin', prefixIcon: Icon(Icons.access_time))),
                const SizedBox(height: 12),
                TextFormField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripcion')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                await DatabaseService.createRehearsal(dateStr, startCtrl.text.trim(), endCtrl.text.trim(), description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
                Navigator.pop(ctx);
                _load();
              }, child: const Text('Crear')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy', 'es').format(now);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ensayos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          Text(monthName[0].toUpperCase() + monthName.substring(1), style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        ]),
        actions: DatabaseService.isStaff
          ? [Container(margin: const EdgeInsets.only(right: 4), child: IconButton.filled(icon: const Icon(Icons.add), onPressed: _showCreate))]
          : null,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _rehearsals.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5)), child: Icon(Icons.calendar_month_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              Text('Sin ensayos', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('Los ensayos se generan automaticamente', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: _rehearsals.length,
                itemBuilder: (_, i) {
                  final r = _rehearsals[i];
                  final canceled = r['is_canceled'] == 1;
                  final date = DateTime.tryParse(r['date']);
                  final dayName = date != null ? DateFormat('EEEE', 'es').format(date) : '';
                  final formatted = date != null ? DateFormat("d 'de' MMMM", 'es').format(date) : r['date'];
                  final isPast = date != null && date.isBefore(DateTime(now.year, now.month, now.day));

                  return !canceled
                    ? OpenContainer(
                        closedElevation: 0,
                        openElevation: 0,
                        closedColor: Colors.transparent,
                        openColor: Colors.transparent,
                        middleColor: Colors.transparent,
                        closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        transitionDuration: const Duration(milliseconds: 500),
                        closedBuilder: (_, openContainer) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: theme.colorScheme.surface,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: openContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: LinearGradient(colors: [theme.colorScheme.primaryContainer, theme.colorScheme.primary.withValues(alpha: 0.3)])), child: Center(child: Text('${date?.day ?? '?'}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)))),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Expanded(child: Text(dayName.isNotEmpty ? '${dayName[0].toUpperCase()}${dayName.substring(1)}' : '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                                        if (isPast) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text('PASADO', style: TextStyle(fontSize: 9, color: Colors.green.shade400, fontWeight: FontWeight.bold))),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text('$formatted', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                      Text('${r['start_time']} - ${r['end_time']}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                    ]),
                                  ),
                                   if (DatabaseService.isStaff)
                                     PopupMenuButton(
                                      icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                                      itemBuilder: (_) => [
                                        PopupMenuItem(child: const Text('No hubo ensayo'), onTap: () => _toggleCancel(r)),
                                        PopupMenuItem(child: const Text('Tomar asistencia'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(rehearsalId: r['id'], rehearsalDate: r['date'], startTime: r['start_time'], endTime: r['end_time'])))),
                                        PopupMenuItem(child: const Text('Eliminar', style: TextStyle(color: Colors.red)), onTap: () => _deleteRehearsal(r)),
                                      ],
                                    )
                                   else
                                     IconButton(
                                      icon: Icon(Icons.arrow_forward, color: theme.colorScheme.onSurfaceVariant),
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(rehearsalId: r['id'], rehearsalDate: r['date'], startTime: r['start_time'], endTime: r['end_time']))),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        openBuilder: (_, closeContainer) => AttendanceScreen(rehearsalId: r['id'], rehearsalDate: r['date'], startTime: r['start_time'], endTime: r['end_time']),
                      )
                    : Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.grey.withValues(alpha: 0.2)), child: Center(child: Text('${date?.day ?? '?'}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)))),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(dayName.isNotEmpty ? '${dayName[0].toUpperCase()}${dayName.substring(1)}' : '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, decoration: TextDecoration.lineThrough, color: theme.colorScheme.onSurfaceVariant))),
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Text('NO HUBO', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold))),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text('$formatted', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                  Text('${r['start_time']} - ${r['end_time']}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                ]),
                              ),
                              if (DatabaseService.isStaff)
                                PopupMenuButton(
                                  icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(child: const Text('Marcar como realizado'), onTap: () => _toggleCancel(r)),
                                    PopupMenuItem(child: const Text('Eliminar', style: TextStyle(color: Colors.red)), onTap: () => _deleteRehearsal(r)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                },
              ),
            ),
    );
  }
}
