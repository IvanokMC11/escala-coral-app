import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/database_service.dart';
import '../widgets/common.dart';
import 'rehearsals_screen.dart';
import 'members_screen.dart';
import 'reports_screen.dart';
import 'treasury_screen.dart';
import 'presentations_screen.dart';
import 'attendance_matrix_screen.dart';
import 'my_attendance_screen.dart';
import 'settings_screen.dart';
import 'repertoire_screen.dart';

/// Pantalla de inicio / dashboard: saludo, frase del coro, proximo ensayo
/// y accesos rapidos a las secciones segun el rol del usuario.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _name;
  Map<String, dynamic>? _nextRehearsal;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final results = await Future.wait([
        DatabaseService.currentMemberName(),
        DatabaseService.getRehearsals(),
      ]);
      _name = results[0] as String?;
      final all = results[1] as List<Map<String, dynamic>>;
      final upcoming = all.where((r) {
        if (r['is_canceled'] == 1) return false;
        final d = DateTime.tryParse(r['date'] ?? '');
        return d != null && !d.isBefore(today);
      }).toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
      _nextRehearsal = upcoming.isNotEmpty ? upcoming.first : null;
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  String get _firstName {
    final n = (_name ?? DatabaseService.currentUser?['email'] ?? '').toString();
    final parts = n.split(RegExp(r'[ @]')).where((p) => p.isNotEmpty);
    return parts.isEmpty ? 'coralista' : parts.first;
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStaff = DatabaseService.isStaff;

    final shortcuts = <_Shortcut>[
      _Shortcut(Icons.event_available, 'Ensayos', () => _open(const RehearsalsScreen())),
      _Shortcut(Icons.checklist_rounded, 'Asistencia', () => _open(const AttendanceMatrixScreen())),
      _Shortcut(Icons.star_rounded, 'Presentaciones', () => _open(const PresentationsScreen())),
      _Shortcut(Icons.library_music_rounded, 'Repertorio', () => _open(const RepertoireScreen())),
      _Shortcut(Icons.bar_chart_rounded, 'Reportes', () => _open(const ReportsScreen())),
      if (isStaff) _Shortcut(Icons.people_alt_rounded, 'Miembros', () => _open(const MembersScreen())),
      if (isStaff) _Shortcut(Icons.account_balance_rounded, 'Tesorería', () => _open(const TreasuryScreen())),
      _Shortcut(Icons.person_rounded, 'Mi asistencia', () => _open(const MyAttendanceScreen())),
      _Shortcut(Icons.settings_rounded, 'Ajustes', () => _open(const SettingsScreen())),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              // ── Saludo ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¡Hola, $_firstName! 👋',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('Bienvenido a Scala Coral',
                            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.person, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Banner con frase ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF8B0000)],
                  ),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.format_quote_rounded, color: Colors.white70, size: 28),
                          const SizedBox(height: 8),
                          const Text('Donde las voces se unen,\nnace la armonía.',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.25)),
                          const SizedBox(height: 6),
                          Text('Coro UNSAAC',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, letterSpacing: 2)),
                        ],
                      ),
                    ),
                    Container(
                      width: 54, height: 54,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: ClipOval(child: Image.asset('assets/icon.png', fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: AppColors.primary))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Proximo ensayo ──
              Text('Próximo ensayo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _loading
                  ? const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())))
                  : _error
                      ? Card(child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(children: [
                            Icon(Icons.error_outline, color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Expanded(child: Text('No se pudo cargar el próximo ensayo',
                                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)))),
                            TextButton(onPressed: _load, child: const Text('Reintentar')),
                          ]),
                        ))
                      : _nextRehearsal == null
                      ? Card(child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(children: [
                            Icon(Icons.event_busy, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 12),
                            Expanded(child: Text('No hay ensayos próximos',
                                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))),
                          ]),
                        ))
                      : _NextRehearsalCard(rehearsal: _nextRehearsal!, onTap: () => _open(const RehearsalsScreen())),
              const SizedBox(height: 24),

              // ── Accesos rapidos ──
              Text('Accesos rápidos', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: responsiveColumns(MediaQuery.of(context).size.width),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: shortcuts.map((s) => _ShortcutTile(shortcut: s)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _Shortcut(this.icon, this.label, this.onTap);
}

class _ShortcutTile extends StatelessWidget {
  final _Shortcut shortcut;
  const _ShortcutTile({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: shortcut.onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(shortcut.icon, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(height: 8),
              Text(shortcut.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextRehearsalCard extends StatelessWidget {
  final Map<String, dynamic> rehearsal;
  final VoidCallback onTap;
  const _NextRehearsalCard({required this.rehearsal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(rehearsal['date'] ?? '');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String when;
    if (date != null && date == today) {
      when = 'Hoy';
    } else if (date != null && date == today.add(const Duration(days: 1))) {
      when = 'Mañana';
    } else if (date != null) {
      when = DateFormat("EEEE d 'de' MMMM", 'es').format(date);
      when = when[0].toUpperCase() + when.substring(1);
    } else {
      when = rehearsal['date']?.toString() ?? '';
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.5)]),
                ),
                child: Center(child: Text('${date?.day ?? '?'}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(when, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${rehearsal['start_time']} - ${rehearsal['end_time']}',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    if ((rehearsal['description'] ?? '').toString().isNotEmpty)
                      Text(rehearsal['description'],
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
