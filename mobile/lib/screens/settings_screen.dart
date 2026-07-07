import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, String> _settings = {};
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _settings = await DatabaseService.getSettings();
    if (DatabaseService.isStaff) _users = await DatabaseService.getUsers();
    setState(() => _loading = false);
  }

  void _edit(String key, String label) {
    final ctrl = TextEditingController(text: _settings[key] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar $label'),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: label)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(DatabaseService.currentUser?['email'] ?? 'Sin sesion', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Rol: ${DatabaseService.currentUser?['role'] ?? '-'}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      ]),
                    ),
                    FilledButton.tonalIcon(icon: const Icon(Icons.logout, size: 16), label: const Text('Salir'), onPressed: () async {
                      await DatabaseService.logout();
                      if (!context.mounted) return;
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    }),
                  ]),
                ),
              ),
              if (DatabaseService.isAdmin && _users.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionHeader(icon: Icons.admin_panel_settings, label: 'Usuarios'),
                const SizedBox(height: 8),
                ..._users.map((u) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: CircleAvatar(radius: 16, child: Text((u['email'] as String).isNotEmpty ? u['email'][0].toUpperCase() : '?')),
                    title: Text(u['email'], style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${u['role']}${u['member_name'] != null ? ' - ${u['member_name']}' : ''}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    trailing: PopupMenuButton(
                      icon: Icon(Icons.more_vert, size: 18),
                      itemBuilder: (_) => ['admin', 'tesorero', 'director', 'miembro'].map((r) => PopupMenuItem(child: Text(r, style: TextStyle(fontWeight: u['role'] == r ? FontWeight.bold : FontWeight.normal)), onTap: () async {
                        await DatabaseService.updateUserRole(u['id'], r);
                        _load();
                      })).toList(),
                    ),
                  ),
                )),
              ],
              const SizedBox(height: 16),
              _SectionHeader(icon: Icons.timer_outlined, label: 'Reglas de tardanza'),
              const SizedBox(height: 12),
              _SettingTile(theme: theme, icon: Icons.hourglass_bottom, label: 'Minutos de tolerancia', value: '${_settings['grace_period_minutes']} min', onTap: () => _edit('grace_period_minutes', 'Minutos de tolerancia')),
              _SettingTile(theme: theme, icon: Icons.attach_money, label: 'Multa por minuto', value: 'S/ ${_settings['fine_per_minute']}', onTap: () => _edit('fine_per_minute', 'Multa por minuto (S/)')),
              const SizedBox(height: 28),
              _SectionHeader(icon: Icons.star_outline, label: 'Presentaciones'),
              const SizedBox(height: 12),
              _SettingTile(theme: theme, icon: Icons.exposure_plus_1, label: 'Valor en asistencias', value: '${_settings['presentation_weight']} asistencias', onTap: () => _edit('presentation_weight', 'Valor en asistencias')),
              const SizedBox(height: 28),
              _SectionHeader(icon: Icons.schedule, label: 'Horarios de ensayo'),
              const SizedBox(height: 12),
              _SettingTile(theme: theme, icon: Icons.sunny, label: 'Lunes', value: '${_settings['schedule_monday_start']} - ${_settings['schedule_monday_end']}', onTap: () => _edit('schedule_monday_start', 'Lunes inicio')),
              _SettingTile(theme: theme, icon: Icons.cloud, label: 'Miercoles', value: '${_settings['schedule_wednesday_start']} - ${_settings['schedule_wednesday_end']}', onTap: () => _edit('schedule_wednesday_start', 'Miercoles inicio')),
              _SettingTile(theme: theme, icon: Icons.nights_stay, label: 'Viernes', value: '${_settings['schedule_friday_start']} - ${_settings['schedule_friday_end']}', onTap: () => _edit('schedule_friday_start', 'Viernes inicio')),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.music_note, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    Text('Scala Coral', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Text('UNSAAC', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)), child: Text('v2.0.0', style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer))),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                      child: Text('Creado por Konavi, el mejor tenor xd', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 18, color: theme.colorScheme.primary),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.primary)),
    ]);
  }
}

class _SettingTile extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingTile({required this.theme, required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
          child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
        ),
        onTap: onTap,
      ),
    );
  }
}
