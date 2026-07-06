import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class PresentationsScreen extends StatefulWidget {
  const PresentationsScreen({super.key});

  @override
  State<PresentationsScreen> createState() => _PresentationsScreenState();
}

class _PresentationsScreenState extends State<PresentationsScreen> {
  List<Map<String, dynamic>> _presentations = [];
  bool _loading = true;

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
    setState(() => _loading = true);
    final now = DateTime.now();
    _presentations = await DatabaseService.getPresentations(month: now.month, year: now.year);
    setState(() => _loading = false);
  }

  void _showCreate() {
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '19:00');
    final locCtrl = TextEditingController();
    final repCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva presentacion'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Fecha (YYYY-MM-DD)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)), validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 12),
            TextFormField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Hora', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time))),
            const SizedBox(height: 12),
            TextFormField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Lugar', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on))),
            const SizedBox(height: 12),
            TextFormField(controller: repCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Repertorio (separado por comas)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.music_note))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            await DatabaseService.createPresentation(
              dateCtrl.text.trim(), timeCtrl.text.trim(),
              location: locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(),
              repertoire: repCtrl.text.trim().isEmpty ? null : repCtrl.text.trim(),
            );
            Navigator.pop(ctx);
            _load();
          }, child: const Text('Crear')),
        ],
      ),
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

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Asistencia - ${p['date']}'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (isPast)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.lock),
                        label: const Text('Cerrar asistencia (medianoche)'),
                        onPressed: () async {
                          await DatabaseService.closePresentation(presId);
                          Navigator.pop(ctx);
                          _load();
                        },
                      ),
                    ),
                  FilledButton.icon(
                    icon: const Icon(Icons.checklist),
                    label: const Text('Marcar todos presente'),
                    onPressed: () {
                      for (final m in members) selectedStatus[m['id']] = 'present';
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  ...members.map((m) => CheckboxListTile(
                    title: Text(m['name']),
                    value: selectedStatus[m['id']] == 'present',
                    secondary: Icon(selectedStatus[m['id']] == 'present' ? Icons.check_circle : Icons.cancel, color: selectedStatus[m['id']] == 'present' ? Colors.green : Colors.red),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedStatus[m['id']] = v == true ? 'present' : 'absent';
                      });
                    },
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(onPressed: () async {
                for (final entry in selectedStatus.entries) {
                  await DatabaseService.markPresentationAttendance(entry.key, presId, entry.value);
                }
                Navigator.pop(ctx);
                _load();
              }, child: const Text('Guardar')),
            ],
          );
        },
      ),
    );
  }

  void _showAttendanceList(Map<String, dynamic> p, List<Map<String, dynamic>> attendance, bool closed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Asistencia - ${p['date']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (closed) Chip(avatar: const Icon(Icons.lock, size: 16), label: const Text('Cerrada')),
              const SizedBox(height: 8),
              ...attendance.map((a) => ListTile(
                dense: true,
                leading: Icon(a['status'] == 'present' ? Icons.check_circle : Icons.cancel, color: a['status'] == 'present' ? Colors.green : Colors.red),
                title: Text(a['member_name'] ?? ''),
              )),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentaciones'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showCreate)],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _presentations.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_outline, size: 64, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Sin presentaciones este mes', style: theme.textTheme.bodyLarge),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _presentations.length,
                itemBuilder: (_, i) {
                  final p = _presentations[i];
                  final closed = p['is_closed'] == 1;
                  final date = DateTime.tryParse(p['date']);
                  final formatted = date != null ? DateFormat("d MMMM yyyy", 'es').format(date) : p['date'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: closed ? Colors.green : theme.colorScheme.primaryContainer,
                        child: Icon(closed ? Icons.lock : Icons.star, color: closed ? Colors.white : theme.colorScheme.onPrimaryContainer),
                      ),
                      title: Text(formatted, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([
                        p['time'],
                        if (p['location'] != null) p['location'],
                        if (closed) 'Cerrada' else 'Abierta',
                      ].join(' \u2022 ')),
                      trailing: PopupMenuButton(
                        itemBuilder: (_) => [
                          PopupMenuItem(child: Text('Ver asistencia'), onTap: () => _showAttendance(p)),
                        ],
                      ),
                      onTap: () => _showAttendance(p),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
