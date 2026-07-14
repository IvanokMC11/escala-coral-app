import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/pdf_service.dart';
import '../widgets/common.dart';

class AttendanceScreen extends StatefulWidget {
  final int rehearsalId;
  final String rehearsalDate;
  final String startTime;
  final String endTime;
  final bool isCanceled;

  const AttendanceScreen({
    super.key,
    required this.rehearsalId,
    required this.rehearsalDate,
    required this.startTime,
    required this.endTime,
    this.isCanceled = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _monthStats = [];
  bool _loading = true;
  bool _insideHours = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkHours();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkHours() {
    final now = DateTime.now();
    final parts = widget.startTime.split(':').map(int.parse).toList();
    final start = DateTime(now.year, now.month, now.day, parts[0], parts[1]);
    final endParts = widget.endTime.split(':').map(int.parse).toList();
    final end = DateTime(now.year, now.month, now.day, endParts[0], endParts[1]);
    _insideHours = now.isAfter(start) && now.isBefore(end);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final results = await Future.wait([
      DatabaseService.getRehearsalAttendance(widget.rehearsalId),
      DatabaseService.getMembers(),
      DatabaseService.getMemberMonthlyStats(now.year, now.month),
    ]);
    _attendance = results[0];
    _members = results[1];
    _monthStats = results[2];
    _checkHours();
    if (mounted) setState(() => _loading = false);
  }

  String _now() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  /// Obtiene la posicion GPS mostrando feedback mientras se espera — la
  /// lectura puede tardar hasta 15s (GPS en frio, sobre todo en interiores),
  /// y sin este aviso el boton se siente "colgado".
  Future<Position?> _getPosition() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Obteniendo tu ubicación GPS…'),
          ]),
          duration: Duration(seconds: 20),
        ),
      );
    }
    Position? userPosition;
    try {
      userPosition = await LocationService.getCurrentPosition();
    } catch (_) {}
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    return userPosition;
  }

  Future<void> _mark(int memberId, String status, {String? arrivalTime, String? justifiedEntryTime}) async {
    // Obtener ubicación GPS si el ensayo tiene geofence
    final userPosition = await _getPosition();

    final result = await DatabaseService.markAttendance(
      memberId,
      widget.rehearsalId,
      arrivalTime ?? _now(),
      userLat: userPosition?.latitude,
      userLng: userPosition?.longitude,
      justifiedEntryTime: justifiedEntryTime,
    );

    // Manejar errores de geofence
    if (result['error'] != null) {
      if (mounted) {
        final msg = result['error'] == 'REQUIERE_UBICACION'
            ? (LocationService.lastFailureReason ?? result['message'])
            : result['message'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg ?? 'Error al marcar asistencia'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    _load();
  }

  Future<void> _markFJ(int memberId) async {
    await DatabaseService.markFJ(memberId, widget.rehearsalId);
    _load();
  }

  /// Marca llegada tardía justificada: pide hora de entrada permitida
  Future<void> _markJustifiedLate(int memberId) async {
    final ctrl = TextEditingController(text: widget.startTime);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Llegada tardía justificada'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Hora de entrada permitida (sin multa):'),
          const SizedBox(height: 12),
          TextFormField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Hora (HH:MM)', prefixIcon: Icon(Icons.access_time)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            Navigator.pop(ctx);
            _mark(memberId, 'present', arrivalTime: ctrl.text.trim());
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _markAllPresent() async {
    final unmarked = _getUnmarked();
    // Obtener una sola ubicación GPS para todos
    final userPosition = await _getPosition();

    final result = await DatabaseService.markAttendanceBatch(
      unmarked.map((m) => m['id'] as int).toList(),
      widget.rehearsalId,
      _now(),
      userLat: userPosition?.latitude,
      userLng: userPosition?.longitude,
    );

    if (result['error'] != null) {
      if (mounted) {
        final msg = result['error'] == 'REQUIERE_UBICACION'
            ? (LocationService.lastFailureReason ?? result['message'])
            : result['message'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg ?? 'Error al marcar asistencia'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    _load();
  }

  Future<void> _markAllFJ() async {
    final unmarked = _getUnmarked();
    await DatabaseService.markFJBatch(unmarked.map((m) => m['id'] as int).toList(), widget.rehearsalId);
    _load();
  }

  Future<String> _absenceFineLabel() async {
    final settings = await DatabaseService.getSettings();
    return settings['absence_fine'] ?? '4.00';
  }

  /// Marca falta y cobra la multa configurada — pide confirmacion porque
  /// genera un cargo de dinero al miembro.
  Future<void> _markAbsent(int memberId, String memberName) async {
    final fine = await _absenceFineLabel();
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar falta'),
        content: Text('¿Marcar a $memberName como ausente y cobrarle S/ $fine de multa?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Marcar falta')),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseService.markAbsent(memberId, widget.rehearsalId);
    _load();
  }

  Future<void> _markAllAbsent() async {
    final unmarked = _getUnmarked();
    final fine = await _absenceFineLabel();
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar todos ausentes'),
        content: Text('¿Marcar a ${unmarked.length} miembros como ausentes y cobrarles S/ $fine de multa a cada uno?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Marcar todos')),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseService.markAbsentBatch(unmarked.map((m) => m['id'] as int).toList(), widget.rehearsalId);
    _load();
  }

  List<Map<String, dynamic>> _getUnmarked() {
    final marked = _attendance.map((a) => a['member_id'] as int).toSet();
    return _members.where((m) => !marked.contains(m['id'])).toList();
  }

  /// Genera y comparte el informe diario de asistencia (PDF) con todos los
  /// miembros del coro y su estado en este ensayo, incluyendo quienes
  /// faltaron.
  Future<void> _shareDailyReport() async {
    try {
      final bytes = await PdfService.generateDailyAttendanceReport(
        date: widget.rehearsalDate,
        startTime: widget.startTime,
        endTime: widget.endTime,
        members: _members,
        attendance: _attendance,
      );
      await Printing.sharePdf(bytes: bytes, filename: 'asistencia_${widget.rehearsalDate}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo generar el informe: $e')));
      }
    }
  }

  Map<String, dynamic>? _getStats(int memberId) {
    try { return _monthStats.firstWhere((s) => s['id'] == memberId); } catch (_) { return null; }
  }

  String _getStatusLabel(Map<String, dynamic> a) {
    if (a['arrival_time'] == 'FJ') return 'Falta justificada';
    switch (a['status'] as String) {
      case 'present': return 'Presente';
      case 'late': return 'Tarde ${a['late_minutes']}min - S/ ${(a['fine_amount'] as num).toStringAsFixed(2)}';
      default: return 'Ausente';
    }
  }

  Color _getStatusColor(Map<String, dynamic> a) {
    if (a['arrival_time'] == 'FJ') return Colors.orange;
    switch (a['status'] as String) {
      case 'present': return Colors.green;
      case 'late': return Colors.orange;
      default: return Colors.red;
    }
  }

  IconData _getStatusIcon(Map<String, dynamic> a) {
    if (a['arrival_time'] == 'FJ') return Icons.healing;
    switch (a['status'] as String) {
      case 'present': return Icons.check_circle;
      case 'late': return Icons.warning_amber;
      default: return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStaff = DatabaseService.isStaff;
    final date = DateTime.tryParse(widget.rehearsalDate);
    final formatted = date != null ? DateFormat("EEEE d 'de' MMMM", 'es').format(date) : widget.rehearsalDate;
    final unmarked = _getUnmarked();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Marcar', icon: Icon(Icons.how_to_reg)),
            Tab(text: 'Registrados', icon: Icon(Icons.list)),
          ],
        ),
        actions: [
          if (isStaff && unmarked.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.flash_on),
              onSelected: (value) {
                if (value == 'all_present') _markAllPresent();
                if (value == 'all_fj') _markAllFJ();
                if (value == 'all_absent') _markAllAbsent();
              },
              itemBuilder: (_) => [
                if (_insideHours) ...[
                  PopupMenuItem(value: 'all_present', child: Row(children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text('Marcar todos PRESENTES (${unmarked.length})', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ])),
                  PopupMenuItem(value: 'all_fj', child: Row(children: [
                    Icon(Icons.healing, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text('Marcar todos FJ (${unmarked.length})', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ])),
                ],
                PopupMenuItem(value: 'all_absent', child: Row(children: [
                  Icon(Icons.cancel, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Marcar todos AUSENTES (${unmarked.length})', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ])),
              ],
            ),
          if (isStaff)
            IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Informe diario', onPressed: _shareDailyReport),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: widget.isCanceled
          ? _buildCanceledView(theme)
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMarkTab(theme, formatted, unmarked, isStaff),
                      _buildRegisteredTab(theme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCanceledView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withValues(alpha: 0.15)),
              child: const Icon(Icons.block, size: 56, color: Colors.orange),
            ),
            const SizedBox(height: 20),
            Text('Este ensayo fue cancelado', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('No hubo ensayo este día', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkTab(ThemeData theme, String formatted, List<Map<String, dynamic>> unmarked, bool isStaff) {
    final currentUser = DatabaseService.currentUser;
    final myMemberId = currentUser?['member_id'] as int?;
    final myAttendance = _attendance.firstWhere(
      (a) => a['member_id'] == myMemberId,
      orElse: () => <String, dynamic>{},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(theme, formatted),
          const SizedBox(height: 16),

          // MODO MIEMBRO: Auto-marcarse
          if (myMemberId != null && myAttendance.isEmpty) _buildSelfCheckIn(theme, myMemberId),
          if (myMemberId != null && myAttendance.isNotEmpty) _buildMyStatus(theme, myAttendance),
          if (myMemberId != null) const SizedBox(height: 16),

          // MODO STAFF: Marcar a otros
          if (isStaff) ...[
            _buildSectionTitle(theme, 'Miembros sin marcar (${unmarked.length})', Icons.person_add),
            const SizedBox(height: 8),
            if (unmarked.isEmpty)
              _buildEmptyState(theme, 'Todos marcados', Icons.check_circle, Colors.green)
            else
              _buildMemberGrid(theme, unmarked),
            const SizedBox(height: 16),
          ],

          // RESUMEN MENSUAL
          _buildSectionTitle(theme, 'Resumen mensual', Icons.date_range),
          const SizedBox(height: 8),
          _buildMonthlySummary(theme),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, String formatted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primaryContainer, theme.colorScheme.primary.withValues(alpha: 0.2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatted[0].toUpperCase() + formatted.substring(1), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('${widget.startTime} - ${widget.endTime}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _insideHours ? Colors.green : Colors.grey.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_insideHours ? Icons.play_circle_fill : Icons.pause_circle, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(_insideHours ? 'HORARIO DE ENSAYO' : 'FUERA DE HORARIO', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfCheckIn(ThemeData theme, int myMemberId) {
    final isLate = _insideHours ? _checkIfLate() : false;
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.person, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Mi asistencia', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ]),
            const SizedBox(height: 12),
            // Solo un botón: marcarse presente/tarde. FJ solo lo pone staff.
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle, size: 20),
                label: Text(isLate ? 'LLEGAR TARDE' : 'ESTOY AQUÍ'),
                style: FilledButton.styleFrom(
                  backgroundColor: isLate ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _mark(myMemberId, isLate ? 'late' : 'present'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _checkIfLate() {
    final now = DateTime.now();
    final parts = widget.startTime.split(':').map(int.parse).toList();
    final start = DateTime(now.year, now.month, now.day, parts[0], parts[1]);
    return now.isAfter(start.add(const Duration(minutes: 15)));
  }

  Widget _buildMyStatus(ThemeData theme, Map<String, dynamic> attendance) {
    final color = _getStatusColor(attendance);
    final icon = _getStatusIcon(attendance);
    final label = _getStatusLabel(attendance);
    final arrival = attendance['arrival_time'] == 'FJ' ? 'FJ' : attendance['arrival_time'];

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.2)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mi estado: $label', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                  if (arrival != null && arrival != 'FJ') Text('Marcado a las $arrival', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: theme.colorScheme.primary),
      const SizedBox(width: 8),
      Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildEmptyState(ThemeData theme, String message, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(message, style: theme.textTheme.bodyLarge?.copyWith(color: color)),
        ])),
      ),
    );
  }

  Widget _buildMemberGrid(ThemeData theme, List<Map<String, dynamic>> members) {
    // Los 5 botones (Presente/Tarde/T.Just./FJ/Falta) necesitan mas ancho
    // del que cabe en una celda de GridView con un alto fijo por
    // aspect-ratio: ese alto fijo es justamente el problema — el ancho
    // disponible por columna varia segun el celular (densidad de pantalla,
    // "tamaño de pantalla" de MIUI, escala de fuente, etc.), asi que a
    // veces los botones necesitan 2 lineas para no desbordar, y una altura
    // fija calculada para 1 linea los recorta en esos celulares. Con
    // LayoutBuilder + Wrap cada tarjeta mide su alto segun su contenido
    // real (nunca se recorta, sin importar cuantas lineas ocupen los
    // botones en cada dispositivo).
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 10.0;
      const minCardWidth = 300.0;
      final cols = (constraints.maxWidth / minCardWidth).floor().clamp(1, 4);
      final cardWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: members.map((m) => SizedBox(width: cardWidth, child: _buildMemberCard(theme, m))).toList(),
      );
    });
  }

  Widget _buildMemberCard(ThemeData theme, Map<String, dynamic> m) {
    final initials = (m['name'] as String).split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
            ),
            const SizedBox(height: 8),
            Text(
              m['name'],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                _QuickActionBtn(
                  icon: Icons.check,
                  color: Colors.green,
                  label: 'Presente',
                  onTap: () => _mark(m['id'], 'present'),
                ),
                _QuickActionBtn(
                  icon: Icons.access_time,
                  color: Colors.orange,
                  label: 'Tarde',
                  onTap: () => _mark(m['id'], 'late'),
                ),
                _QuickActionBtn(
                  icon: Icons.schedule,
                  color: Colors.blue,
                  label: 'T. Just.',
                  onTap: () => _markJustifiedLate(m['id']),
                  outlined: true,
                ),
                _QuickActionBtn(
                  icon: Icons.healing,
                  color: Colors.orange,
                  label: 'FJ',
                  onTap: () => _markFJ(m['id']),
                  outlined: true,
                ),
                _QuickActionBtn(
                  icon: Icons.cancel,
                  color: Colors.red,
                  label: 'Falta',
                  onTap: () => _markAbsent(m['id'], m['name']),
                  outlined: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisteredTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(theme, 'Asistencia registrada (${_attendance.length})', Icons.list),
          const SizedBox(height: 12),
          if (_attendance.isEmpty)
            _buildEmptyState(theme, 'Sin asistencias aún', Icons.how_to_reg, theme.colorScheme.onSurfaceVariant)
          else
            ..._attendance.map((a) => _buildAttendanceItem(theme, a)),
          const Divider(height: 32),
          _buildSectionTitle(theme, 'Resumen mensual', Icons.date_range),
          const SizedBox(height: 8),
          _buildMonthlySummary(theme),
        ],
      ),
    );
  }

  Widget _buildAttendanceItem(ThemeData theme, Map<String, dynamic> a) {
    final color = _getStatusColor(a);
    final icon = _getStatusIcon(a);
    final label = _getStatusLabel(a);
    final arrival = a['arrival_time'];
    final isStaff = DatabaseService.isStaff;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(a['member_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(label, style: TextStyle(fontSize: 12, color: color)),
        trailing: arrival != 'FJ' && arrival != null
            ? Text('🕐 $arrival', style: const TextStyle(fontSize: 11))
            : null,
        dense: true,
        onLongPress: isStaff ? () => _showEditAttendanceDialog(theme, a) : null,
        onTap: isStaff ? () => _showEditAttendanceDialog(theme, a) : null,
      ),
    );
  }

  Future<void> _showEditAttendanceDialog(ThemeData theme, Map<String, dynamic> a) async {
    final attendanceId = a['id'] as int;
    final memberName = a['member_name'] ?? '';
    String? arrivalTime = a['arrival_time'] == 'FJ' ? null : a['arrival_time'] as String?;
    String? justifiedEntryTime = a['justified_entry_time'] as String?;
    String status = a['status'] as String;
    int lateMinutes = a['late_minutes'] as int? ?? 0;
    double fineAmount = (a['fine_amount'] as num?)?.toDouble() ?? 0.0;
    String? notes = a['notes'] as String?;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Editar: $memberName', maxLines: 1, overflow: TextOverflow.ellipsis),
          content: ModalWidthConstraint(maxWidth: 420, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Estado
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Estado', prefixIcon: Icon(Icons.flag)),
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Presente')),
                  DropdownMenuItem(value: 'late', child: Text('Tarde')),
                  DropdownMenuItem(value: 'absent', child: Text('Ausente')),
                ],
                onChanged: (v) => setDialogState(() => status = v!),
              ),
              const SizedBox(height: 12),
              // Hora llegada
              TextFormField(
                initialValue: arrivalTime,
                decoration: const InputDecoration(labelText: 'Hora llegada (HH:MM)', prefixIcon: Icon(Icons.access_time), hintText: 'Dejar vacío si FJ'),
                onChanged: (v) => arrivalTime = v.trim().isEmpty ? null : v,
              ),
              const SizedBox(height: 12),
              // Hora entrada justificada (para llegadas tardías permitidas)
              TextFormField(
                initialValue: a['justified_entry_time'] as String?,
                decoration: const InputDecoration(labelText: 'Hora entrada justificada (HH:MM)', prefixIcon: Icon(Icons.schedule), hintText: 'Si tiene permiso para llegar tarde'),
                onChanged: (v) => justifiedEntryTime = v.trim().isEmpty ? null : v,
              ),
              const SizedBox(height: 12),
              // Minutos tarde
              TextFormField(
                initialValue: lateMinutes.toString(),
                decoration: const InputDecoration(labelText: 'Minutos tarde', prefixIcon: Icon(Icons.timer)),
                keyboardType: TextInputType.number,
                onChanged: (v) => lateMinutes = int.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 12),
              // Multa
              TextFormField(
                initialValue: fineAmount.toStringAsFixed(2),
                decoration: const InputDecoration(labelText: 'Multa (S/)', prefixIcon: Icon(Icons.attach_money)),
                keyboardType: TextInputType.number,
                onChanged: (v) => fineAmount = double.tryParse(v) ?? 0.0,
              ),
              const SizedBox(height: 12),
              // Notas
              TextFormField(
                initialValue: notes,
                decoration: const InputDecoration(labelText: 'Notas', prefixIcon: Icon(Icons.note)),
                onChanged: (v) => notes = v.trim().isEmpty ? null : v,
              ),
            ],
          ))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            // Botón FJ rápido
            OutlinedButton.icon(
              icon: const Icon(Icons.healing, color: Colors.orange),
              label: const Text('Marcar FJ', style: TextStyle(color: Colors.orange)),
              onPressed: () async {
                await DatabaseService.updateAttendance(attendanceId, arrivalTime: 'FJ', status: 'present', lateMinutes: 0, fineAmount: 0, notes: 'Falta justificada');
                Navigator.pop(ctx);
                _load();
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
              onPressed: () async {
                await DatabaseService.updateAttendance(attendanceId, arrivalTime: arrivalTime, status: status, lateMinutes: lateMinutes, fineAmount: fineAmount, notes: notes, justifiedEntryTime: justifiedEntryTime);
                Navigator.pop(ctx);
                _load();
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text('Eliminar', style: TextStyle(color: Colors.white)),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
                  title: const Text('Eliminar asistencia'),
                  content: Text('¿Borrar registro de $memberName?'),
                  actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí'), style: FilledButton.styleFrom(backgroundColor: Colors.red))],
                ));
                if (confirm == true) {
                  await DatabaseService.deleteAttendance(attendanceId);
                  Navigator.pop(ctx);
                  _load();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummary(ThemeData theme) {
    if (_members.isEmpty) return _buildEmptyState(theme, 'Sin miembros', Icons.people, theme.colorScheme.onSurfaceVariant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(flex: 4, child: Text('Miembro', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))),
                Expanded(child: Text('%', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center)),
                SizedBox(width: 45, child: Text('Tard.', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
                SizedBox(width: 65, child: Text('Multa', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const Divider(height: 8),
            ..._members.map((m) {
              final s = _getStats(m['id']);
              final total = s != null ? s['total_rehearsals'] as int : 0;
              final attended = s != null ? s['attended'] as int : 0;
              final late = s != null ? s['late_count'] as int : 0;
              final fine = s != null ? (s['total_fine'] as num).toDouble() : 0.0;
              final pct = total > 0 ? (attended / total * 100).toStringAsFixed(0) : '-';
              final pctColor = total > 0 && attended / total >= 0.9 ? Colors.green : total > 0 && attended / total >= 0.7 ? Colors.orange : Colors.red;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        m['name'],
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: pctColor.withValues(alpha: 0.15),
                          ),
                          child: Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, color: pctColor, fontSize: 12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 45, child: Center(child: Text('T:$late', style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis))),
                    SizedBox(width: 65, child: Center(child: Text('S/ ${fine.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: fine > 0 ? theme.colorScheme.error : null), maxLines: 1, overflow: TextOverflow.ellipsis))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  const _QuickActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: outlined ? Colors.transparent : color.withValues(alpha: 0.15),
          border: outlined ? Border.all(color: color) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}