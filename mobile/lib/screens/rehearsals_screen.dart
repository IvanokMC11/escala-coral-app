import 'package:flutter/material.dart';
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
    final dateCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '18:00');
    final endCtrl = TextEditingController(text: '20:00');
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo ensayo'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Fecha (YYYY-MM-DD)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)), validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 12),
            TextFormField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Inicio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time))),
            const SizedBox(height: 12),
            TextFormField(controller: endCtrl, decoration: const InputDecoration(labelText: 'Fin', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time))),
            const SizedBox(height: 12),
            TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripcion', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            await DatabaseService.createRehearsal(dateCtrl.text.trim(), startCtrl.text.trim(), endCtrl.text.trim(), description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
            Navigator.pop(ctx);
            _load();
          }, child: const Text('Crear')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ensayos'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showCreate)],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _rehearsals.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_month_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Sin ensayos', style: theme.textTheme.bodyLarge),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _rehearsals.length,
                itemBuilder: (_, i) {
                  final r = _rehearsals[i];
                  final canceled = r['is_canceled'] == 1;
                  final date = DateTime.tryParse(r['date']);
                  final dayName = date != null ? DateFormat('EEEE', 'es').format(date) : '';
                  final formatted = date != null ? DateFormat('d MMMM yyyy', 'es').format(date) : r['date'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: canceled ? theme.colorScheme.surfaceContainerHighest : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: canceled ? Colors.grey : theme.colorScheme.primaryContainer,
                        child: Text('${date?.day ?? '?'}', style: TextStyle(color: canceled ? Colors.grey : theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text('${dayName.isNotEmpty ? dayName[0].toUpperCase() + dayName.substring(1) : ''}', style: TextStyle(fontWeight: FontWeight.w600, decoration: canceled ? TextDecoration.lineThrough : null))),
                          if (canceled) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)), child: const Text('NO HUBO', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      subtitle: Text('$formatted\n${r['start_time']} - ${r['end_time']}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton(
                        itemBuilder: (_) => [
                          PopupMenuItem(child: Text(canceled ? 'Marcar como realizado' : 'No hubo ensayo'), onTap: () => _toggleCancel(r)),
                          PopupMenuItem(child: const Text('Tomar asistencia', style: TextStyle(color: Colors.blue)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(rehearsalId: r['id'], rehearsalDate: r['date'], startTime: r['start_time'], endTime: r['end_time'], isCanceled: canceled)))),
                          PopupMenuItem(child: const Text('Eliminar', style: TextStyle(color: Colors.red)), onTap: () => _deleteRehearsal(r)),
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
