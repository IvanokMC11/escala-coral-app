import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/common.dart';
import 'my_attendance_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

/// Perfil del usuario: foto (de Google), datos del miembro, estadisticas
/// y menu de opciones.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _member;
  Map<String, dynamic> _stats = {};
  String? _photoUrl;
  bool _loading = true;
  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final memberId = DatabaseService.currentUser?['member_id'] as int?;
    final results = await Future.wait([
      DatabaseService.googlePhotoUrl(),
      if (memberId != null) DatabaseService.getMember(memberId) else Future.value(null),
      if (memberId != null)
        DatabaseService.getMyStats(memberId).catchError((_) => <String, dynamic>{})
      else
        Future.value(<String, dynamic>{}),
    ]);
    _photoUrl = results[0] as String?;
    _member = results[1] as Map<String, dynamic>?;
    _stats = results[2] as Map<String, dynamic>;
    if (mounted) setState(() { _loading = false; _initialLoad = false; });
  }

  Future<void> _logout() async {
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
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _showInfo() {
    final theme = Theme.of(context);
    final m = _member;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: ModalWidthConstraint(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            const Text('Mi información', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _infoRow(theme, Icons.person_outline, 'Nombre', m?['name']),
            _infoRow(theme, Icons.email_outlined, 'Correo', DatabaseService.currentUser?['email']),
            _infoRow(theme, Icons.phone_outlined, 'Teléfono', m?['phone']),
            _infoRow(theme, Icons.badge_outlined, 'Código', m?['codigo']),
            _infoRow(theme, Icons.school_outlined, 'Escuela', m?['escuela']),
            _infoRow(theme, Icons.multitrack_audio, 'Cuerda', m?['cuerda']),
            _infoRow(theme, Icons.card_giftcard_outlined, 'Beca Comedor', (m?['beca_eligible'] ?? 1) == 1 ? 'Postula' : 'No postula'),
          ],
        )),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, dynamic value) {
    final v = (value?.toString().isNotEmpty == true) ? value.toString() : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 14),
        Text('$label:', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(width: 8),
        Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _member?['name']?.toString() ?? DatabaseService.currentUser?['email']?.toString() ?? 'Usuario';
    final email = DatabaseService.currentUser?['email']?.toString() ?? '';
    final phone = _member?['phone']?.toString() ?? '';
    final cuerda = _member?['cuerda']?.toString() ?? '';

    final total = (_stats['total'] as int?) ?? 0;
    final attended = (_stats['attended'] as int?) ?? 0;
    final absent = (_stats['absent_count'] as int?) ?? 0;
    final pct = total > 0 ? (attended / total * 100).toStringAsFixed(0) : '0';

    final initials = name.split(RegExp(r'[ @]')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: _loading && _initialLoad
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // ── Foto + nombre ──
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.4)]),
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                            backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty) ? NetworkImage(_photoUrl!) : null,
                            child: (_photoUrl == null || _photoUrl!.isEmpty)
                                ? Text(initials, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: theme.colorScheme.primary))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(name, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(email, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (phone.isNotEmpty) Text(phone, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                        if (cuerda.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                            child: Text(cuerda, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Estadisticas ──
                  if (DatabaseService.currentUser?['member_id'] != null)
                    Row(children: [
                      StatCard(label: 'Asistencia', value: '$pct%'),
                      const SizedBox(width: 10),
                      StatCard(label: 'Ensayos', value: '$attended'),
                      const SizedBox(width: 10),
                      StatCard(label: 'Faltas', value: '$absent'),
                    ]),
                  const SizedBox(height: 24),

                  // ── Menu ──
                  _menuItem(theme, Icons.info_outline, 'Mi información', _showInfo),
                  if (DatabaseService.currentUser?['member_id'] != null)
                    _menuItem(theme, Icons.checklist_rounded, 'Mi asistencia', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAttendanceScreen()))),
                  if (DatabaseService.isAdmin)
                    _menuItem(theme, Icons.settings_outlined, 'Configuración del coro', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                  const SizedBox(height: 8),
                  _menuItem(theme, Icons.logout, 'Cerrar sesión', _logout, danger: true),
                ],
              ),
            ),
    );
  }

  Widget _menuItem(ThemeData theme, IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    final color = danger ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: danger ? theme.colorScheme.error : theme.colorScheme.primary),
        title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        trailing: danger ? null : Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        onTap: onTap,
      ),
    );
  }
}
