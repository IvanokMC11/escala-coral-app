import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/rehearsal.dart';
import '../providers/app_state.dart';
import 'attendance_screen.dart';

class RehearsalsScreen extends StatefulWidget {
  const RehearsalsScreen({super.key});

  @override
  State<RehearsalsScreen> createState() => _RehearsalsScreenState();
}

class _RehearsalsScreenState extends State<RehearsalsScreen> {
  List<Rehearsal> _rehearsals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRehearsals();
  }

  Future<void> _loadRehearsals() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppState>().api;
      final now = DateTime.now();
      final rehearsals = await api.getRehearsals(
        month: now.month.toString(),
        year: now.year.toString(),
      );
      setState(() => _rehearsals = rehearsals);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar ensayos')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showCreateDialog() {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fecha (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hora inicio (HH:MM)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hora fin (HH:MM)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripcion (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await context.read<AppState>().api.createRehearsal(
                      dateCtrl.text.trim(),
                      startCtrl.text.trim(),
                      endCtrl.text.trim(),
                      descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    );
                Navigator.pop(ctx);
                _loadRehearsals();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showGenerateDialog() {
    final monthCtrl =
        TextEditingController(text: DateTime.now().month.toString());
    final yearCtrl =
        TextEditingController(text: DateTime.now().year.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generar ensayos del mes'),
        content: Form(
          key: formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: monthCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mes (1-12)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 12) return '1-12';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Anio',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 2024) return 'Invalido';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final result = await context
                    .read<AppState>()
                    .api
                    .generateRehearsals(
                        int.parse(yearCtrl.text), int.parse(monthCtrl.text));
                Navigator.pop(ctx);
                _loadRehearsals();
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${result['count']} ensayos generados')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = context.watch<AppState>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ensayos'),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Generar mes',
              onPressed: _showGenerateDialog,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateDialog,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rehearsals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 64, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('No hay ensayos este mes',
                          style: theme.textTheme.bodyLarge),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRehearsals,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rehearsals.length,
                    itemBuilder: (_, i) => _RehearsalCard(
                      rehearsal: _rehearsals[i],
                      isAdmin: isAdmin,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AttendanceScreen(rehearsal: _rehearsals[i]),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _RehearsalCard extends StatelessWidget {
  final Rehearsal rehearsal;
  final bool isAdmin;
  final VoidCallback onTap;

  const _RehearsalCard({
    required this.rehearsal,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(rehearsal.date);
    final dayName = date != null
        ? DateFormat('EEEE', 'es').format(date)
        : '';
    final formattedDate = date != null
        ? DateFormat('d MMMM yyyy', 'es').format(date)
        : rehearsal.date;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(date?.day.toString() ?? '?',
              style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(
            '${dayName.isNotEmpty ? dayName[0].toUpperCase() + dayName.substring(1) : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$formattedDate\n${rehearsal.startTime} - ${rehearsal.endTime}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
