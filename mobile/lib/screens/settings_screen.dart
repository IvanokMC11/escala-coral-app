import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import '../widgets/common.dart';
import '../widgets/location_picker.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, String> _settings = {};
  List<Map<String, dynamic>> _users = [];
  List<String> _authorizedEmails = [];
  bool _loading = true;
  Position? _defaultLocation;
  int _defaultRadius = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      DatabaseService.getSettings(),
      DatabaseService.isStaff ? DatabaseService.getUsers() : Future.value(<Map<String, dynamic>>[]),
      DatabaseService.isAdmin ? DatabaseService.getAuthorizedEmails() : Future.value(<String>[]),
    ]);
    _settings = results[0] as Map<String, String>;
    _users = results[1] as List<Map<String, dynamic>>;
    _authorizedEmails = results[2] as List<String>;
    final lat = double.tryParse(_settings['default_rehearsal_lat'] ?? '');
    final lng = double.tryParse(_settings['default_rehearsal_lng'] ?? '');
    _defaultRadius = int.tryParse(_settings['default_rehearsal_radius'] ?? '') ?? 30;
    _defaultLocation = (lat != null && lng != null)
        ? Position(latitude: lat, longitude: lng, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0)
        : null;
    setState(() => _loading = false);
  }

  Future<void> _saveDefaultLocation() async {
    final pos = _defaultLocation;
    if (pos == null) return;
    await Future.wait([
      DatabaseService.updateSetting('default_rehearsal_lat', pos.latitude.toString()),
      DatabaseService.updateSetting('default_rehearsal_lng', pos.longitude.toString()),
      DatabaseService.updateSetting('default_rehearsal_radius', _defaultRadius.toString()),
    ]);
    if (!mounted) return;
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubicación guardada'),
        content: const Text('¿Aplicar esta ubicación a los ensayos futuros que todavía no tienen ubicación asignada? Esto activa la validación de GPS en ellos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, solo a los nuevos')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar ahora')),
        ],
      ),
    );
    if (apply == true) {
      await DatabaseService.applyDefaultLocationToUpcomingRehearsals(pos.latitude, pos.longitude, _defaultRadius);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación aplicada a los ensayos futuros sin ubicación')));
      }
    }
    _load();
  }

  void _addAuthorizedEmail() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Autorizar correo'),
        content: ModalWidthConstraint(maxWidth: 420, child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Correo externo (fuera de @unsaac.edu.pe) que podrá iniciar sesión con Google.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'correo@ejemplo.com')),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            final email = ctrl.text.trim();
            if (email.isEmpty || !email.contains('@')) return;
            await DatabaseService.addAuthorizedEmail(email);
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          }, child: const Text('Autorizar')),
        ],
      ),
    );
  }

  void _edit(String key, String label, {String defaultValue = ''}) {
    final ctrl = TextEditingController(text: _settings[key] ?? defaultValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar $label', maxLines: 1, overflow: TextOverflow.ellipsis),
        content: ModalWidthConstraint(maxWidth: 420, child: TextField(controller: ctrl, decoration: InputDecoration(labelText: label))),
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
                        Text(
                          DatabaseService.currentUser?['email'] ?? 'Sin sesion',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rol: ${DatabaseService.currentUser?['role'] ?? '-'}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
              if (DatabaseService.isAdmin && _users.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionHeader(icon: Icons.admin_panel_settings, label: 'Usuarios'),
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
              if (DatabaseService.isAdmin) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SectionHeader(icon: Icons.mark_email_read_outlined, label: 'Correos autorizados')),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: theme.colorScheme.primary),
                      tooltip: 'Autorizar correo',
                      onPressed: _addAuthorizedEmail,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Correos fuera de @${DatabaseService.allowedDomain} habilitados para entrar con Google.', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ),
                if (_authorizedEmails.isEmpty)
                  Card(child: ListTile(dense: true, leading: const Icon(Icons.info_outline, size: 18), title: Text('Sin correos externos autorizados', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)))),
                ..._authorizedEmails.map((email) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const CircleAvatar(radius: 16, child: Icon(Icons.alternate_email, size: 16)),
                    title: Text(email, style: const TextStyle(fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () async {
                        await DatabaseService.removeAuthorizedEmail(email);
                        _load();
                      },
                    ),
                  ),
                )),
              ],
              // Configuracion del coro: solo el admin puede verla/editarla.
              if (DatabaseService.isAdmin) ...[
                const SizedBox(height: 16),
                SectionHeader(icon: Icons.timer_outlined, label: 'Reglas de tardanza'),
                const SizedBox(height: 12),
                _SettingTile(theme: theme, icon: Icons.hourglass_bottom, label: 'Minutos de tolerancia', value: '${_settings['grace_period_minutes']} min', onTap: () => _edit('grace_period_minutes', 'Minutos de tolerancia')),
                _SettingTile(theme: theme, icon: Icons.attach_money, label: 'Multa por minuto', value: 'S/ ${_settings['fine_per_minute']}', onTap: () => _edit('fine_per_minute', 'Multa por minuto (S/)')),
                _SettingTile(theme: theme, icon: Icons.money_off, label: 'Multa por falta', value: 'S/ ${_settings['absence_fine'] ?? '4.00'}', onTap: () => _edit('absence_fine', 'Multa por falta (S/)', defaultValue: '4.00')),
                const SizedBox(height: 28),
                SectionHeader(icon: Icons.star_outline, label: 'Presentaciones'),
                const SizedBox(height: 12),
                _SettingTile(theme: theme, icon: Icons.exposure_plus_1, label: 'Valor en asistencias', value: '${_settings['presentation_weight']} asistencias', onTap: () => _edit('presentation_weight', 'Valor en asistencias')),
                const SizedBox(height: 28),
                SectionHeader(icon: Icons.schedule, label: 'Horarios de ensayo'),
                const SizedBox(height: 12),
                _SettingTile(theme: theme, icon: Icons.sunny, label: 'Lunes', value: '${_settings['schedule_monday_start']} - ${_settings['schedule_monday_end']}', onTap: () => _edit('schedule_monday_start', 'Lunes inicio')),
                _SettingTile(theme: theme, icon: Icons.cloud, label: 'Miercoles', value: '${_settings['schedule_wednesday_start']} - ${_settings['schedule_wednesday_end']}', onTap: () => _edit('schedule_wednesday_start', 'Miercoles inicio')),
                _SettingTile(theme: theme, icon: Icons.nights_stay, label: 'Viernes', value: '${_settings['schedule_friday_start']} - ${_settings['schedule_friday_end']}', onTap: () => _edit('schedule_friday_start', 'Viernes inicio')),
                const SizedBox(height: 28),
                const SectionHeader(icon: Icons.location_on_outlined, label: 'Ubicación de ensayos'),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Ubicación aplicada automáticamente a los ensayos que se generan solos, para que exijan estar presentes al marcar asistencia.',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                StatefulBuilder(
                  builder: (ctx, setLocationState) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocationPicker(
                        title: 'Ubicación por defecto',
                        selectedPosition: _defaultLocation,
                        radiusMeters: _defaultRadius,
                        onLocationSelected: (pos) => setLocationState(() => _defaultLocation = pos),
                        onClear: () => setLocationState(() => _defaultLocation = null),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _defaultRadius.toString(),
                            decoration: const InputDecoration(labelText: 'Radio (metros)', prefixIcon: Icon(Icons.radar)),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setLocationState(() => _defaultRadius = int.tryParse(v) ?? _defaultRadius),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _defaultLocation == null ? null : () async { await _saveDefaultLocation(); setLocationState(() {}); },
                          child: const Text('Guardar'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Cerrar sesion (disponible para todos)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cerrar sesión'),
                        content: const Text('¿Seguro que quieres cerrar sesión?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    await DatabaseService.logout();
                    if (!context.mounted) return;
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                ),
              ),
              const SizedBox(height: 32),
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
