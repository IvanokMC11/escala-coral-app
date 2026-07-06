import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, String> _settings = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _settings = await DatabaseService.getSettings();
    setState(() => _loading = false);
  }

  void _edit(String key, String label) {
    final ctrl = TextEditingController(text: _settings[key] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar $label'),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            await DatabaseService.updateSetting(key, ctrl.text.trim());
            Navigator.pop(ctx);
            _load();
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Widget _tile(String label, String key) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        title: Text(label),
        trailing: Text(_settings[key] ?? '', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        onTap: () => _edit(key, label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Reglas de tardanza', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _tile('Minutos de tolerancia', 'grace_period_minutes'),
              _tile('Multa por minuto (S/)', 'fine_per_minute'),
              const SizedBox(height: 24),
              Text('Presentaciones', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _tile('Valor en asistencias', 'presentation_weight'),
              const SizedBox(height: 24),
              Text('Horarios de ensayo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _tile('Lunes inicio', 'schedule_monday_start'),
              _tile('Lunes fin', 'schedule_monday_end'),
              _tile('Miercoles inicio', 'schedule_wednesday_start'),
              _tile('Miercoles fin', 'schedule_wednesday_end'),
              _tile('Viernes inicio', 'schedule_friday_start'),
              _tile('Viernes fin', 'schedule_friday_end'),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.music_note, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('Scala Coral', style: theme.textTheme.titleMedium),
                    Text('UNSAAC', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('v2.0.0', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
