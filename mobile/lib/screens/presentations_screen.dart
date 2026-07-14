import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';

class PresentationsScreen extends StatefulWidget {
  const PresentationsScreen({super.key});

  @override
  State<PresentationsScreen> createState() => _PresentationsScreenState();
}

class _PresentationsScreenState extends State<PresentationsScreen> {
  List<Map<String, dynamic>> _presentations = [];
  bool _loading = true;
  bool _initialLoad = true;
  String? _error;
  int _filter = 0; // 0 = Próximas, 1 = Pasadas, 2 = Todas

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DatabaseService.autoClosePresentations();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _presentations = await DatabaseService.getPresentations();
    } catch (_) {
      _error = 'Error al cargar presentaciones';
    }
    setState(() { _loading = false; _initialLoad = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = _presentations.where((p) {
      final d = DateTime.tryParse(p['date'] ?? '');
      if (_filter == 0) return d != null && !d.isBefore(today); // próximas
      if (_filter == 1) return d != null && d.isBefore(today);  // pasadas
      return true; // todas
    }).toList();
    // Próximas: la más cercana primero. Pasadas/Todas: la más reciente primero.
    list.sort((a, b) => _filter == 0
        ? (a['date'] as String).compareTo(b['date'] as String)
        : (b['date'] as String).compareTo(a['date'] as String));
    return list;
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
            child: ModalWidthConstraint(child: Form(
              key: formKey,
              child: StatefulBuilder(
                builder: (ctx, setDialogState) {
                  return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    const Text('Nueva presentación', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                        NotificationService.rescheduleAll();
                        Navigator.pop(ctx);
                        _load();
                      }, child: const Text('Crear presentación')),
                    ),
                  ]);
                },
              ),
            )),
          ),
        );
      },
    );
  }

  Future<void> _showAttendance(Map<String, dynamic> p) async {
    final closed = p['is_closed'] == 1;
    final presId = p['id'] as int;

    if (closed || !DatabaseService.isStaff) {
      final attendance = await DatabaseService.getPresentationAttendance(presId);
      if (!mounted) return;
      _showAttendanceList(p, attendance, closed);
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
            child: ModalWidthConstraint(child: SizedBox(
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
                        title: Text(m['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
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
                      await DatabaseService.markPresentationAttendanceBatch(presId, selectedStatus);
                      Navigator.pop(ctx);
                      _load();
                    }, child: const Text('Guardar asistencia')),
                  ),
                ),
              ]),
            )),
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
        child: ModalWidthConstraint(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Asistencia - ${p['date']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            if (closed) Chip(avatar: const Icon(Icons.lock, size: 14), label: const Text('Cerrada', style: TextStyle(fontSize: 12))),
          ]),
          const SizedBox(height: 12),
          if (attendance.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Aún no se registra asistencia', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6)))),
          ...attendance.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, color: a['status'] == 'present' ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15)), child: Icon(a['status'] == 'present' ? Icons.check_circle : Icons.cancel, color: a['status'] == 'present' ? Colors.green : Colors.red, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(a['member_name'] ?? '', style: const TextStyle(fontSize: 15))),
            ]),
          )),
        ])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentaciones'),
        actions: DatabaseService.isStaff
            ? [Container(margin: const EdgeInsets.only(right: 4), child: IconButton.filled(icon: const Icon(Icons.add), onPressed: _showCreate))]
            : null,
      ),
      body: Column(
        children: [
          // ── Filtros tipo pestañas ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                _filterChip('Próximas', 0),
                const SizedBox(width: 8),
                _filterChip('Pasadas', 1),
                const SizedBox(width: 8),
                _filterChip('Todas', 2),
              ],
            ),
          ),
          Expanded(
            child: _loading && _initialLoad
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorRetry(message: _error!, onRetry: _load)
                    : items.isEmpty
                    ? const EmptyState(icon: Icons.event_note_outlined, title: 'Sin presentaciones', iconSize: 52)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _PresentationCard(p: items[i], onTap: () => _showAttendance(items[i])),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int value) {
    final theme = Theme.of(context);
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : theme.colorScheme.primary)),
      ),
    );
  }
}

class _PresentationCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final VoidCallback onTap;
  const _PresentationCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closed = p['is_closed'] == 1;
    final date = DateTime.tryParse(p['date'] ?? '');
    final dateStr = date != null
        ? DateFormat("EEE d 'de' MMM", 'es').format(date).replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase())
        : (p['date']?.toString() ?? '');
    final title = (p['location']?.toString().isNotEmpty == true) ? p['location'].toString() : 'Presentación';
    final rep = p['repertoire']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: (closed ? AppColors.success : theme.colorScheme.primary).withValues(alpha: 0.15),
                ),
                child: Icon(closed ? Icons.verified_rounded : Icons.star_rounded, color: closed ? AppColors.success : theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: (closed ? AppColors.success : Colors.orange).withValues(alpha: 0.12)),
                        child: Text(closed ? 'Cerrada' : 'Abierta', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: closed ? AppColors.success : Colors.orange)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.event, size: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Expanded(child: Text('$dateStr · ${p['time']}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    if (rep.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(rep, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
