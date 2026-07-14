import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/location_picker.dart';
import 'attendance_screen.dart';

class RehearsalsScreen extends StatefulWidget {
  const RehearsalsScreen({super.key});

  @override
  State<RehearsalsScreen> createState() => _RehearsalsScreenState();
}

class _RehearsalsScreenState extends State<RehearsalsScreen> {
  List<Map<String, dynamic>> _rehearsals = [];
  bool _loading = true;
  bool _initialLoad = true;

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
    final today = DateTime(now.year, now.month, now.day);
    final list = await DatabaseService.getRehearsals(month: now.month, year: now.year);

    final upcoming = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];
    for (final r in list) {
      final d = DateTime.tryParse(r['date'] ?? '');
      if (d != null && d.isBefore(today)) {
        past.add(r);
      } else {
        upcoming.add(r);
      }
    }
    upcoming.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    past.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    _rehearsals = [...upcoming, ...past];

    setState(() { _loading = false; _initialLoad = false; });
  }

  Future<void> _toggleCancel(Map<String, dynamic> r) async {
    final newVal = (r['is_canceled'] == 1) ? 0 : 1;
    await DatabaseService.cancelRehearsal(r['id'], newVal == 1);
    NotificationService.rescheduleAll();
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
      NotificationService.rescheduleAll();
      _load();
    }
  }

  void _showCreate() {
    var selectedDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 18, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 20, minute: 0);
    final descCtrl = TextEditingController();
    Position? selectedPosition;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: const Text('Nuevo ensayo'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: ModalWidthConstraint(maxWidth: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: startTime);
                      if (picked != null) setDialogState(() => startTime = picked);
                    },
                    child: InputDecorator(decoration: const InputDecoration(labelText: 'Inicio', prefixIcon: Icon(Icons.access_time)), child: Text(_fmt(startTime))),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: endTime);
                      if (picked != null) setDialogState(() => endTime = picked);
                    },
                    child: InputDecorator(decoration: const InputDecoration(labelText: 'Fin', prefixIcon: Icon(Icons.access_time)), child: Text(_fmt(endTime))),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripcion', prefixIcon: Icon(Icons.description))),
                  const SizedBox(height: 16),
                  LocationPicker(
                    selectedPosition: selectedPosition,
                    onLocationSelected: (pos) => setDialogState(() => selectedPosition = pos),
                    onClear: () => setDialogState(() => selectedPosition = null),
                  ),
                ])),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                await DatabaseService.createRehearsal(dateStr, _fmt(startTime), _fmt(endTime), description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(), latitude: selectedPosition?.latitude, longitude: selectedPosition?.longitude, geofenceRadius: selectedPosition != null ? 30 : null);
                NotificationService.rescheduleAll();
                Navigator.pop(ctx);
                _load();
              }, child: const Text('Crear')),
            ],
          );
        },
      ),
    );
  }

  /// Permite fijar, cambiar o quitar la ubicacion GPS de un ensayo ya
  /// creado (por ejemplo, uno autogenerado que nacio sin ubicacion).
  void _editLocation(Map<String, dynamic> r) {
    Position? selectedPosition;
    final lat = r['latitude'] as num?;
    final lng = r['longitude'] as num?;
    final radius = (r['geofence_radius'] as num?)?.toInt() ?? 30;
    if (lat != null && lng != null) {
      selectedPosition = Position(
        latitude: lat.toDouble(), longitude: lng.toDouble(), timestamp: DateTime.now(),
        accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ubicación del ensayo'),
          content: SingleChildScrollView(
            child: ModalWidthConstraint(maxWidth: 420, child: LocationPicker(
              selectedPosition: selectedPosition,
              radiusMeters: radius,
              onLocationSelected: (pos) => setDialogState(() => selectedPosition = pos),
              onClear: () => setDialogState(() => selectedPosition = null),
            )),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            if (lat != null && lng != null)
              TextButton(
                onPressed: () async {
                  await DatabaseService.updateRehearsalLocation(r['id'], null, null, null);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Quitar restricción GPS'),
              ),
            FilledButton(
              onPressed: selectedPosition == null ? null : () async {
                await DatabaseService.updateRehearsalLocation(r['id'], selectedPosition!.latitude, selectedPosition!.longitude, radius);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
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
        actions: DatabaseService.isStaff ? [Container(margin: const EdgeInsets.only(right: 4), child: IconButton.filled(icon: const Icon(Icons.add), onPressed: _showCreate))] : null,
      ),
      body: _loading && _initialLoad ? const Center(child: CircularProgressIndicator()) : _rehearsals.isEmpty ? const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Sin ensayos',
        subtitle: 'Los ensayos se generan automaticamente',
      ) : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: _rehearsals.length,
          itemBuilder: (_, i) {
            final r = _rehearsals[i];
            final canceled = r['is_canceled'] == 1;
            final date = DateTime.tryParse(r['date'] ?? '');
            final dayName = date != null ? DateFormat('EEEE', 'es').format(date) : '';
            final formatted = date != null ? DateFormat("d 'de' MMMM", 'es').format(date) : r['date'];
            final isPast = date != null && date.isBefore(DateTime(now.year, now.month, now.day));

            return !canceled
                ? InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(rehearsalId: r['id'], rehearsalDate: r['date'], startTime: r['start_time'], endTime: r['end_time']))),
                    borderRadius: BorderRadius.circular(16),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: LinearGradient(colors: [theme.colorScheme.primaryContainer, theme.colorScheme.primary.withValues(alpha: 0.3)])), child: Center(child: Text('${date?.day ?? '?'}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)))),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Expanded(child: Text(dayName.isNotEmpty ? '${dayName[0].toUpperCase()}${dayName.substring(1)}' : '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))), if (isPast) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text('PASADO', style: TextStyle(fontSize: 9, color: Colors.green.shade400, fontWeight: FontWeight.bold)))]),
                            const SizedBox(height: 4),
                            Text('$formatted', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                            Text('${r['start_time']} - ${r['end_time']}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          ])),
                          if (DatabaseService.isStaff)
                            PopupMenuButton(icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant), itemBuilder: (_) => [
                              PopupMenuItem(child: const Text('No hubo ensayo'), onTap: () => _toggleCancel(r)),
                              PopupMenuItem(child: const Text('Tomar asistencia'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(rehearsalId: r['id'], rehearsalDate: r['date'], startTime: r['start_time'], endTime: r['end_time'])))),
                              PopupMenuItem(child: Text(r['latitude'] != null ? 'Actualizar ubicación' : 'Agregar ubicación'), onTap: () => _editLocation(r)),
                              PopupMenuItem(child: const Text('Eliminar', style: TextStyle(color: Colors.red)), onTap: () => _deleteRehearsal(r)),
                            ])
                          else
                            IconButton(icon: Icon(Icons.arrow_forward, color: theme.colorScheme.onSurfaceVariant), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(rehearsalId: r['id'], rehearsalDate: r['date'], startTime: r['start_time'], endTime: r['end_time'])))),
                        ]),
                      ),
                    ),
                  )
                : Card(
              margin: const EdgeInsets.only(bottom: 10), color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.grey.withValues(alpha: 0.2)), child: Center(child: Text('${date?.day ?? '?'}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(dayName.isNotEmpty ? '${dayName[0].toUpperCase()}${dayName.substring(1)}' : '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, decoration: TextDecoration.lineThrough, color: theme.colorScheme.onSurfaceVariant))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Text('NO HUBO', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)))]),
                  const SizedBox(height: 4),
                  Text('$formatted', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  Text('${r['start_time']} - ${r['end_time']}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ])),
                if (DatabaseService.isStaff) PopupMenuButton(icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant), itemBuilder: (_) => [
                  PopupMenuItem(child: const Text('Marcar como realizado'), onTap: () => _toggleCancel(r)),
                  PopupMenuItem(child: Text(r['latitude'] != null ? 'Actualizar ubicación' : 'Agregar ubicación'), onTap: () => _editLocation(r)),
                  PopupMenuItem(child: const Text('Eliminar', style: TextStyle(color: Colors.red)), onTap: () => _deleteRehearsal(r)),
                ]),
              ])),
            );
          },
        ),
      ),
    );
  }
}
