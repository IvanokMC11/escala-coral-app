import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../services/database_service.dart';

class PresentationsScreen extends StatefulWidget {
  const PresentationsScreen({super.key});

  @override
  State<PresentationsScreen> createState() => _PresentationsScreenState();
}

class _PresentationsScreenState extends State<PresentationsScreen> {
  late int _year, _month;
  List<Map<String, dynamic>> _presentations = [];
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _init();
  }

  Future<void> _init() async {
    await DatabaseService.autoClosePresentations();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _presentations = await DatabaseService.getPresentations(month: _month, year: _year);
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    final sel = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return _presentations.where((p) => p['date'] == sel).toList();
  }

  void _showCreate() {
    var selectedDate = DateTime.now();
    final timeCtrl = TextEditingController(text: '19:00');
    final locCtrl = TextEditingController();
    final repCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Form(
              key: formKey,
              child: StatefulBuilder(
                builder: (ctx, setDialogState) {
                  return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    const Text('Nueva presentacion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2030), locale: const Locale('es'));
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Fecha', prefixIcon: Icon(Icons.calendar_today)),
                        child: Text(DateFormat("EEEE d 'de' MMMM yyyy", 'es').format(selectedDate).split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ')),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Hora', prefixIcon: Icon(Icons.access_time))),
                    const SizedBox(height: 14),
                    TextFormField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Lugar', prefixIcon: Icon(Icons.location_on))),
                    const SizedBox(height: 14),
                    TextFormField(controller: repCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Repertorio (separado por comas)', prefixIcon: Icon(Icons.music_note))),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                        await DatabaseService.createPresentation(dateStr, timeCtrl.text.trim(), location: locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(), repertoire: repCtrl.text.trim().isEmpty ? null : repCtrl.text.trim());
                        Navigator.pop(ctx);
                        _load();
                      }, child: const Text('Crear presentacion')),
                    ),
                  ]);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAttendance(Map<String, dynamic> p) async {
    final closed = p['is_closed'] == 1;
    final presId = p['id'] as int;

    if (closed) {
      final attendance = await DatabaseService.getPresentationAttendance(presId);
      if (!mounted) return;
      _showAttendanceList(p, attendance, true);
      return;
    }

    final now = DateTime.now();
    final presDate = DateTime.tryParse(p['date']);
    final isPast = presDate != null && presDate.isBefore(DateTime(now.year, now.month, now.day));

    final members = await DatabaseService.getMembers();
    final existing = await DatabaseService.getPresentationAttendance(presId);
    final existingMap = {for (final e in existing) e['member_id'] as int: e['status'] as String};

    final selectedStatus = <int, String>{};
    for (final m in members) {
      if (existingMap.containsKey(m['id'])) {
        selectedStatus[m['id']] = existingMap[m['id']]!;
      }
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  child: Column(children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: Text('Asistencia - ${p['date']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      if (isPast)
                        FilledButton.tonalIcon(icon: const Icon(Icons.lock, size: 16), label: const Text('Cerrar'), onPressed: () async {
                          await DatabaseService.closePresentation(presId);
                          Navigator.pop(ctx);
                          _load();
                        }),
                    ]),
                    const SizedBox(height: 8),
                    FilledButton.icon(icon: const Icon(Icons.checklist), label: const Text('Marcar todos presente'), onPressed: () {
                      for (final m in members) selectedStatus[m['id']] = 'present';
                      setDialogState(() {});
                    }),
                  ]),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: members.map((m) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: CheckboxListTile(
                        title: Text(m['name']),
                        value: selectedStatus[m['id']] == 'present',
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: selectedStatus[m['id']] == 'present' ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15)),
                          child: Icon(selectedStatus[m['id']] == 'present' ? Icons.check_circle : Icons.cancel, color: selectedStatus[m['id']] == 'present' ? Colors.green : Colors.red, size: 20),
                        ),
                        onChanged: (v) { setDialogState(() { selectedStatus[m['id']] = v == true ? 'present' : 'absent'; }); },
                      ),
                    )).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () async {
                      for (final entry in selectedStatus.entries) {
                        await DatabaseService.markPresentationAttendance(entry.key, presId, entry.value);
                      }
                      Navigator.pop(ctx);
                      _load();
                    }, child: const Text('Guardar asistencia')),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showAttendanceList(Map<String, dynamic> p, List<Map<String, dynamic>> attendance, bool closed) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Asistencia - ${p['date']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            if (closed) Chip(avatar: const Icon(Icons.lock, size: 14), label: const Text('Cerrada', style: TextStyle(fontSize: 12))),
          ]),
          const SizedBox(height: 12),
          ...attendance.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, color: a['status'] == 'present' ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15)), child: Icon(a['status'] == 'present' ? Icons.check_circle : Icons.cancel, color: a['status'] == 'present' ? Colors.green : Colors.red, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(a['member_name'] ?? '', style: const TextStyle(fontSize: 15))),
            ]),
          )),
        ]),
      ),
    );
  }

  void _onCalendarTap(CalendarTapDetails details) {
    if (details.date != null) {
      setState(() => _selectedDate = details.date!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: DatabaseService.isStaff
          ? [Container(margin: const EdgeInsets.only(right: 4), child: IconButton.filled(icon: const Icon(Icons.add), onPressed: _showCreate))]
          : null,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  SfCalendar(
                    view: CalendarView.month,
                    initialSelectedDate: _selectedDate,
                    onTap: _onCalendarTap,
                    todayTextStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    headerStyle: CalendarHeaderStyle(
                      textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                    monthViewSettings: MonthViewSettings(
                      showTrailingAndLeadingDates: false,
                      dayFormat: 'EEE',
                      monthCellStyle: MonthCellStyle(
                        textStyle: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                        leadingDatesTextStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        trailingDatesTextStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                    dataSource: _PresentationDataSource(_presentations),
                    backgroundColor: Colors.transparent,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(),
                  ),
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                      child: Column(children: [
                        Icon(Icons.event_busy, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('Sin presentaciones en esta fecha', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      ]),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(children: [
                        Row(children: [
                          Icon(Icons.star, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(DateFormat("d 'de' MMMM", 'es').format(_selectedDate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface)),
                          Text(' (${_filtered.length})', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ]),
                        const SizedBox(height: 12),
                        ..._filtered.map((p) {
                          final closed = p['is_closed'] == 1;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showAttendance(p),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(width: 46, height: 46, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: closed ? Colors.green.withValues(alpha: 0.15) : theme.colorScheme.primaryContainer), child: Icon(closed ? Icons.lock : Icons.star, color: closed ? Colors.green : theme.colorScheme.onPrimaryContainer, size: 20)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('${p['time']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        if (p['location'] != null) Text(p['location'], style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ]),
                                    ),
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: closed ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)), child: Text(closed ? 'Cerrada' : 'Abierta', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: closed ? Colors.green : Colors.orange))),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ]),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );
  }
}

class _PresentationDataSource extends CalendarDataSource {
  _PresentationDataSource(List<Map<String, dynamic>> presentations) {
    appointments = presentations.map((p) {
      final date = DateTime.tryParse(p['date']);
      final closed = p['is_closed'] == 1;
      return Appointment(
        startTime: date ?? DateTime.now(),
        endTime: (date ?? DateTime.now()).add(const Duration(hours: 2)),
        subject: p['location'] ?? 'Presentacion',
        color: closed ? Colors.green : Colors.purple,
        isAllDay: true,
      );
    }).toList();
  }
}
