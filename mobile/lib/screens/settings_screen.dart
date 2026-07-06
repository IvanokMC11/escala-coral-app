import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppState>().api;
      final settings = await api.getSettings();
      setState(() => _settings = settings.map((k, v) => MapEntry(k, v.toString())));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar configuracion')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    try {
      await context.read<AppState>().api.updateSettings({key: value});
      setState(() => _settings[key] = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuracion actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showEditDialog(String key, String label, String currentValue) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar $label'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              _saveSetting(key, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!state.isAdmin)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.lock,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            'Solo el administrador puede configurar',
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (state.isAdmin) ...[
                  Text('Horario de ensayos',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _SettingTile(
                    label: 'Lunes inicio',
                    key_: 'schedule_monday_start',
                    value: _settings['schedule_monday_start'] ?? '18:00',
                    onTap: (k, v) =>
                        _showEditDialog(k, 'Lunes inicio', v),
                  ),
                  _SettingTile(
                    label: 'Lunes fin',
                    key_: 'schedule_monday_end',
                    value: _settings['schedule_monday_end'] ?? '20:00',
                    onTap: (k, v) =>
                        _showEditDialog(k, 'Lunes fin', v),
                  ),
                  _SettingTile(
                    label: 'Miercoles inicio',
                    key_: 'schedule_wednesday_start',
                    value: _settings['schedule_wednesday_start'] ?? '18:00',
                    onTap: (k, v) =>
                        _showEditDialog(k, 'Miercoles inicio', v),
                  ),
                  _SettingTile(
                    label: 'Miercoles fin',
                    key_: 'schedule_wednesday_end',
                    value: _settings['schedule_wednesday_end'] ?? '20:00',
                    onTap: (k, v) =>
                        _showEditDialog(k, 'Miercoles fin', v),
                  ),
                  _SettingTile(
                    label: 'Viernes inicio',
                    key_: 'schedule_friday_start',
                    value: _settings['schedule_friday_start'] ?? '18:00',
                    onTap: (k, v) =>
                        _showEditDialog(k, 'Viernes inicio', v),
                  ),
                  _SettingTile(
                    label: 'Viernes fin',
                    key_: 'schedule_friday_end',
                    value: _settings['schedule_friday_end'] ?? '20:00',
                    onTap: (k, v) =>
                        _showEditDialog(k, 'Viernes fin', v),
                  ),
                  const SizedBox(height: 24),
                  Text('Reglas de tardanza',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _SettingTile(
                    label: 'Minutos de tolerancia',
                    key_: 'grace_period_minutes',
                    value: _settings['grace_period_minutes'] ?? '15',
                    onTap: (k, v) =>
                        _showEditDialog(k, 'Tolerancia (minutos)', v),
                  ),
                  _SettingTile(
                    label: 'Multa por minuto',
                    key_: 'fine_per_minute',
                    value: 'S/ ${_settings['fine_per_minute'] ?? '0.20'}',
                    onTap: (k, v) =>
                        _showEditDialog(k, 'Multa por minuto', v),
                  ),
                ],
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Text('${state.user?['name'] ?? ''}',
                          style: theme.textTheme.bodyMedium),
                      Text('${state.user?['email'] ?? ''}',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () => state.logout(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesion'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String label;
  final String key_;
  final String value;
  final void Function(String key, String value) onTap;

  const _SettingTile({
    required this.label,
    required this.key_,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        title: Text(label),
        trailing: Text(value,
            style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        onTap: () => onTap(key_, value),
      ),
    );
  }
}
