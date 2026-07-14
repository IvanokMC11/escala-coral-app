import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de un intento de inicio de sesion con Google.
enum GoogleAuthStatus {
  /// El usuario cerro el dialogo de Google sin elegir cuenta.
  cancelled,
  /// El correo no es @unsaac.edu.pe ni esta en la lista de autorizados.
  unauthorized,
  /// Ya existia un usuario con ese correo: sesion iniciada.
  loggedIn,
  /// Correo autorizado pero sin cuenta aun: falta vincular a un miembro.
  needsLink,
  /// Ocurrio un error inesperado.
  error,
}

class GoogleAuthResult {
  final GoogleAuthStatus status;
  final String? email;
  const GoogleAuthResult(this.status, {this.email});
}

class DatabaseService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  // ─── Google Sign-In ───────────────────────────────────
  /// Dominio institucional permitido para registrarse sin autorizacion previa.
  static const String allowedDomain = 'unsaac.edu.pe';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Client ID de tipo "Web" del proyecto en Google Cloud Console.
    serverClientId:
        '338526097367-b1shhrg6nd1gkire3e6q4gou4306nrvq.apps.googleusercontent.com',
    scopes: const ['email'],
  );

  // ─── Members ──────────────────────────────────────────
  // Cache en memoria de sesion: getMembers() se llama desde casi todas las
  // pantallas y los datos casi nunca cambian entre navegaciones, asi que
  // evitamos un round-trip de red repetido. Se invalida en cualquier
  // escritura (add/update/delete) y en logout().
  static List<Map<String, dynamic>>? _membersCache;

  static Future<List<Map<String, dynamic>>> getMembers({bool forceRefresh = false}) async {
    if (!forceRefresh && _membersCache != null) return _membersCache!;
    final r = await _supabase.from('members').select().eq('is_active', 1).order('name');
    _membersCache = List<Map<String, dynamic>>.from(r);
    return _membersCache!;
  }

  static Future<int> addMember(String name, {String? email, String? phone, String? codigo, String? escuela, int becaEligible = 1, String? cuerda}) async {
    final r = await _supabase.from('members').insert({
      'name': name, 'email': email, 'phone': phone, 'codigo': codigo,
      'escuela': escuela, 'beca_eligible': becaEligible, 'cuerda': cuerda,
    }).select();
    _membersCache = null;
    return (r.first as Map<String, dynamic>)['id'] as int;
  }

  static Future<void> updateMember(int id, Map<String, dynamic> data) async {
    await _supabase.from('members').update(data).eq('id', id);
    _membersCache = null;
  }

  static Future<void> deleteMember(int id) async {
    await _supabase.from('members').delete().eq('id', id);
    _membersCache = null;
  }

  static Future<Map<String, dynamic>?> getMember(int id) async {
    final r = await _supabase.from('members').select().eq('id', id);
    return r.isNotEmpty ? r.first as Map<String, dynamic> : null;
  }

  /// Nombre del miembro vinculado al usuario con sesion iniciada (o null).
  static Future<String?> currentMemberName() async {
    final id = _currentUser?['member_id'] as int?;
    if (id == null) return null;
    final m = await getMember(id);
    return m?['name'] as String?;
  }

  // ─── Rehearsals ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRehearsals({int? month, int? year}) async {
    var q = _supabase.from('rehearsals').select();
    if (month != null && year != null) {
      final start = '$year-${month.toString().padLeft(2, '0')}-01';
      final nextM = month == 12 ? 1 : month + 1;
      final nextY = month == 12 ? year + 1 : year;
      q = q.gte('date', start).lt('date', '$nextY-${nextM.toString().padLeft(2, '0')}-01');
    }
    return q.order('date');
  }

  static Future<int> createRehearsal(String date, String startTime, String endTime,
      {String? description, double? latitude, double? longitude, int? geofenceRadius}) async {
    final r = await _supabase.from('rehearsals').insert({
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'geofence_radius': geofenceRadius ?? 30,
    }).select();
    return (r.first as Map<String, dynamic>)['id'] as int;
  }

  static Future<void> cancelRehearsal(int id, bool canceled) async {
    await _supabase.from('rehearsals').update({'is_canceled': canceled ? 1 : 0}).eq('id', id);
  }

  static Future<void> autoGenerateRehearsals() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = today.add(const Duration(days: 59));

    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // Candidatas: todos los Lun/Mie/Vie del rango de 60 dias.
    final candidates = <DateTime>[];
    for (int i = 0; i <= 59; i++) {
      final date = today.add(Duration(days: i));
      if (date.weekday == DateTime.monday || date.weekday == DateTime.wednesday || date.weekday == DateTime.friday) {
        candidates.add(date);
      }
    }
    if (candidates.isEmpty) return;

    // Una sola consulta para saber que fechas ya existen en el rango.
    final existingRows = await _supabase
        .from('rehearsals')
        .select('date')
        .gte('date', fmt(today))
        .lte('date', fmt(lastDay));
    final existingDates = existingRows.map((r) => r['date'] as String).toSet();

    // Si el coro configuro una ubicacion por defecto en Ajustes, todo
    // ensayo autogenerado nace con geofence activo (antes nacian sin
    // ubicacion y la validacion de GPS nunca se aplicaba en la practica).
    final settings = await getSettings();
    final defaultLat = double.tryParse(settings['default_rehearsal_lat'] ?? '');
    final defaultLng = double.tryParse(settings['default_rehearsal_lng'] ?? '');
    final defaultRadius = int.tryParse(settings['default_rehearsal_radius'] ?? '') ?? 30;

    final toInsert = <Map<String, dynamic>>[];
    for (final date in candidates) {
      final dateStr = fmt(date);
      if (existingDates.contains(dateStr)) continue;
      final dayName = date.weekday == DateTime.monday ? 'Lunes' : date.weekday == DateTime.wednesday ? 'Miercoles' : 'Viernes';
      toInsert.add({
        'date': dateStr, 'start_time': '18:00', 'end_time': '20:00', 'description': 'Ensayo $dayName',
        if (defaultLat != null && defaultLng != null) 'latitude': defaultLat,
        if (defaultLat != null && defaultLng != null) 'longitude': defaultLng,
        if (defaultLat != null && defaultLng != null) 'geofence_radius': defaultRadius,
      });
    }
    if (toInsert.isEmpty) return;

    try {
      await _supabase.from('rehearsals').insert(toInsert);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getRehearsal(int id) async {
    final r = await _supabase.from('rehearsals').select().eq('id', id);
    return r.isNotEmpty ? r.first as Map<String, dynamic> : null;
  }

  static Future<void> deleteRehearsal(int id) async {
    await _supabase.from('attendance').delete().eq('rehearsal_id', id);
    await _supabase.from('rehearsals').delete().eq('id', id);
  }

  /// Fija, cambia o quita (con lat/lng/radius = null) la ubicacion GPS de
  /// un ensayo puntual (por ejemplo uno autogenerado que nacio sin
  /// ubicacion antes de que existiera la ubicacion por defecto).
  static Future<void> updateRehearsalLocation(int id, double? lat, double? lng, int? radius) async {
    await _supabase.from('rehearsals').update({
      'latitude': lat, 'longitude': lng, 'geofence_radius': lat != null ? radius : null,
    }).eq('id', id);
  }

  /// Aplica la ubicacion por defecto del coro a los ensayos ya creados
  /// (incluyendo los autogenerados antes de configurar la ubicacion) que
  /// todavia no tienen geofence, para que el arreglo tenga efecto de
  /// inmediato y no solo en ensayos generados a futuro.
  static Future<void> applyDefaultLocationToUpcomingRehearsals(double lat, double lng, int radius) async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _supabase.from('rehearsals')
        .update({'latitude': lat, 'longitude': lng, 'geofence_radius': radius})
        .gte('date', todayStr)
        .filter('latitude', 'is', null);
  }

  // ─── Attendance ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRehearsalAttendance(int rehearsalId) async {
    final data = await _supabase.from('attendance').select('*, members!inner(name)').eq('rehearsal_id', rehearsalId).order('name', referencedTable: 'members');
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      m['member_name'] = (m.remove('members') as Map<String, dynamic>)['name'];
      return m;
    }).toList();
  }

  static Future<Map<String, dynamic>> markAttendance(int memberId, int rehearsalId, String arrivalTime,
      {double? userLat, double? userLng, String? justifiedEntryTime}) async {
    final settings = await getSettings();
    final grace = int.parse(settings['grace_period_minutes'] ?? '15');
    final fine = double.parse(settings['fine_per_minute'] ?? '0.20');
    final rehearsal = await _supabase.from('rehearsals').select('start_time, latitude, longitude, geofence_radius').eq('id', rehearsalId).single();
    final start = rehearsal['start_time'] as String;

    // Validar geofence si el ensayo tiene coordenadas
    if (rehearsal['latitude'] != null && rehearsal['longitude'] != null) {
      if (userLat == null || userLng == null) {
        return {'error': 'REQUIERE_UBICACION', 'message': 'Debes activar GPS para marcar asistencia'};
      }
      final rehearsalLat = (rehearsal['latitude'] as num).toDouble();
      final rehearsalLng = (rehearsal['longitude'] as num).toDouble();
      final radius = (rehearsal['geofence_radius'] as num?)?.toDouble() ?? 30.0;

      final distance = Geolocator.distanceBetween(userLat, userLng, rehearsalLat, rehearsalLng);
      if (distance > radius) {
        return {
          'error': 'FUERA_RANGO',
          'message': 'Estás a ${distance.toStringAsFixed(0)}m del ensayo (máx. ${radius.toInt()}m)',
          'distance': distance,
        };
      }
    }

    // Calcular tardanza usando hora justificada si existe
    final effectiveStart = justifiedEntryTime ?? start;
    final r = _calc(arrivalTime, effectiveStart, grace, fine);
    final result = await _supabase.from('attendance').upsert({
      'member_id': memberId,
      'rehearsal_id': rehearsalId,
      'arrival_time': arrivalTime,
      'status': r['status'],
      'late_minutes': r['lateMinutes'],
      'fine_amount': r['fineAmount'],
      'justified_entry_time': justifiedEntryTime,
    }).select();
    return result.first as Map<String, dynamic>;
  }

  static Future<void> markFJ(int memberId, int rehearsalId) async {
    await _supabase.from('attendance').upsert({
      'member_id': memberId, 'rehearsal_id': rehearsalId, 'arrival_time': 'FJ',
      'status': 'present', 'late_minutes': 0, 'fine_amount': 0, 'notes': 'Falta justificada',
    });
  }

  /// Marca falta (no justificada) y cobra la multa configurada en Ajustes
  /// (S/4 por defecto) como una multa manual, para que aparezca en Deudas
  /// de miembros y se pueda cobrar igual que cualquier otra multa. Solo
  /// cobra una vez: si el miembro ya estaba marcado como ausente en este
  /// ensayo, no vuelve a insertar la multa.
  static Future<void> markAbsent(int memberId, int rehearsalId) async {
    final existing = await _supabase.from('attendance').select('status').eq('member_id', memberId).eq('rehearsal_id', rehearsalId);
    final alreadyAbsent = existing.isNotEmpty && existing.first['status'] == 'absent';

    await _supabase.from('attendance').upsert({
      'member_id': memberId, 'rehearsal_id': rehearsalId, 'arrival_time': 'AUSENTE',
      'status': 'absent', 'late_minutes': 0, 'fine_amount': 0, 'notes': 'Falta',
    });

    if (!alreadyAbsent) {
      final fine = await _absenceFine();
      if (fine > 0) {
        await _supabase.from('member_fines').insert({'member_id': memberId, 'amount': fine, 'reason': 'Falta de asistencia'});
      }
    }
  }

  /// Version en lote de [markAbsent], para "marcar todos ausentes".
  static Future<void> markAbsentBatch(List<int> memberIds, int rehearsalId) async {
    if (memberIds.isEmpty) return;
    final existing = await _supabase.from('attendance').select('member_id, status').eq('rehearsal_id', rehearsalId).inFilter('member_id', memberIds);
    final alreadyAbsentIds = existing.where((e) => e['status'] == 'absent').map((e) => e['member_id'] as int).toSet();

    final rows = memberIds.map((id) => {
      'member_id': id, 'rehearsal_id': rehearsalId, 'arrival_time': 'AUSENTE',
      'status': 'absent', 'late_minutes': 0, 'fine_amount': 0, 'notes': 'Falta',
    }).toList();
    await _supabase.from('attendance').upsert(rows);

    final toFine = memberIds.where((id) => !alreadyAbsentIds.contains(id)).toList();
    if (toFine.isNotEmpty) {
      final fine = await _absenceFine();
      if (fine > 0) {
        final fineRows = toFine.map((id) => {'member_id': id, 'amount': fine, 'reason': 'Falta de asistencia'}).toList();
        await _supabase.from('member_fines').insert(fineRows);
      }
    }
  }

  static Future<double> _absenceFine() async {
    final settings = await getSettings();
    return double.tryParse(settings['absence_fine'] ?? '4.00') ?? 4.00;
  }

  /// Actualiza asistencia existente (solo staff/admin)
  static Future<Map<String, dynamic>> updateAttendance(int attendanceId, {
    String? arrivalTime,
    String? status,
    int? lateMinutes,
    double? fineAmount,
    String? notes,
    String? justifiedEntryTime,
  }) async {
    final updateData = <String, dynamic>{};
    if (arrivalTime != null) updateData['arrival_time'] = arrivalTime;
    if (status != null) updateData['status'] = status;
    if (lateMinutes != null) updateData['late_minutes'] = lateMinutes;
    if (fineAmount != null) updateData['fine_amount'] = fineAmount;
    if (notes != null) updateData['notes'] = notes;
    if (justifiedEntryTime != null) updateData['justified_entry_time'] = justifiedEntryTime;
    if (updateData.isEmpty) throw ArgumentError('Nada que actualizar');

    final result = await _supabase.from('attendance').update(updateData).eq('id', attendanceId).select();
    return result.first as Map<String, dynamic>;
  }

  /// Elimina asistencia (solo staff/admin)
  static Future<void> deleteAttendance(int attendanceId) async {
    await _supabase.from('attendance').delete().eq('id', attendanceId);
  }

  static Future<void> markBatch(int rehearsalId, List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    final settings = await getSettings();
    final grace = int.parse(settings['grace_period_minutes'] ?? '15');
    final fine = double.parse(settings['fine_per_minute'] ?? '0.20');
    final rehearsal = await _supabase.from('rehearsals').select('start_time').eq('id', rehearsalId).single();
    final start = rehearsal['start_time'] as String;
    final rows = records.map((record) {
      final justifiedEntry = record['justified_entry_time'] as String?;
      final effectiveStart = justifiedEntry ?? start;
      final res = _calc(record['arrival_time'], effectiveStart, grace, fine);
      return {
        'member_id': record['member_id'], 'rehearsal_id': rehearsalId,
        'arrival_time': record['arrival_time'],
        'status': res['status'], 'late_minutes': res['lateMinutes'], 'fine_amount': res['fineAmount'],
        'justified_entry_time': justifiedEntry,
      };
    }).toList();
    await _supabase.from('attendance').upsert(rows);
  }

  /// Marca varios miembros como presentes/tarde a la vez con una sola
  /// llamada de red (usado por "marcar todos presentes"). Valida geofence
  /// una sola vez con la posicion GPS ya obtenida, no una vez por miembro.
  static Future<Map<String, dynamic>> markAttendanceBatch(
    List<int> memberIds, int rehearsalId, String arrivalTime,
    {double? userLat, double? userLng}) async {
    if (memberIds.isEmpty) return {'ok': true};
    final settings = await getSettings();
    final grace = int.parse(settings['grace_period_minutes'] ?? '15');
    final fine = double.parse(settings['fine_per_minute'] ?? '0.20');
    final rehearsal = await _supabase.from('rehearsals').select('start_time, latitude, longitude, geofence_radius').eq('id', rehearsalId).single();
    final start = rehearsal['start_time'] as String;

    if (rehearsal['latitude'] != null && rehearsal['longitude'] != null) {
      if (userLat == null || userLng == null) {
        return {'error': 'REQUIERE_UBICACION', 'message': 'Debes activar GPS para marcar asistencia'};
      }
      final rehearsalLat = (rehearsal['latitude'] as num).toDouble();
      final rehearsalLng = (rehearsal['longitude'] as num).toDouble();
      final radius = (rehearsal['geofence_radius'] as num?)?.toDouble() ?? 30.0;
      final distance = Geolocator.distanceBetween(userLat, userLng, rehearsalLat, rehearsalLng);
      if (distance > radius) {
        return {
          'error': 'FUERA_RANGO',
          'message': 'Estás a ${distance.toStringAsFixed(0)}m del ensayo (máx. ${radius.toInt()}m)',
          'distance': distance,
        };
      }
    }

    final r = _calc(arrivalTime, start, grace, fine);
    final rows = memberIds.map((id) => {
      'member_id': id, 'rehearsal_id': rehearsalId, 'arrival_time': arrivalTime,
      'status': r['status'], 'late_minutes': r['lateMinutes'], 'fine_amount': r['fineAmount'],
    }).toList();
    await _supabase.from('attendance').upsert(rows);
    return {'ok': true};
  }

  /// Marca varios miembros como falta justificada (FJ) con una sola llamada.
  static Future<void> markFJBatch(List<int> memberIds, int rehearsalId) async {
    if (memberIds.isEmpty) return;
    final rows = memberIds.map((id) => {
      'member_id': id, 'rehearsal_id': rehearsalId, 'arrival_time': 'FJ',
      'status': 'present', 'late_minutes': 0, 'fine_amount': 0, 'notes': 'Falta justificada',
    }).toList();
    await _supabase.from('attendance').upsert(rows);
  }

  static Map<String, dynamic> _calc(String arrival, String start, int grace, double finePerMin) {
    final a = arrival.split(':').map(int.parse).toList();
    final s = start.split(':').map(int.parse).toList();
    final diff = (a[0] * 60 + a[1]) - (s[0] * 60 + s[1]);
    if (diff <= 0) return {'status': 'present', 'lateMinutes': 0, 'fineAmount': 0.0};
    if (diff <= grace) return {'status': 'present', 'lateMinutes': diff, 'fineAmount': 0.0};
    final late = diff - grace;
    return {'status': 'late', 'lateMinutes': diff, 'fineAmount': (late * finePerMin * 100).round() / 100.0};
  }

  // ─── Member Monthly Stats ─────────────────────────────
  static Future<List<Map<String, dynamic>>> getMemberMonthlyStats(int year, int month) async {
    final r = await _supabase.rpc('get_member_monthly_stats', params: {'p_year': year, 'p_month': month});
    return (r as List).cast<Map<String, dynamic>>();
  }

  // ─── Attendance Matrix ─────────────────────────────────
  static Future<Map<String, dynamic>> getAttendanceMatrix(int year, int month) async {
    final r = await _supabase.rpc('get_attendance_matrix', params: {'p_year': year, 'p_month': month});
    final data = r as Map<String, dynamic>;
    final attMap = <String, Map<String, dynamic>>{};
    for (final a in (data['attendance'] as List)) {
      final entry = a as Map<String, dynamic>;
      attMap['${entry['member_id']}_${entry['rehearsal_id']}'] = entry;
    }
    return {
      'rehearsals': (data['rehearsals'] as List).cast<Map<String, dynamic>>(),
      'members': (data['members'] as List).cast<Map<String, dynamic>>(),
      'attendance': attMap,
    };
  }

  // ─── Presentations ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPresentations({int? month, int? year}) async {
    var q = _supabase.from('presentations').select();
    if (month != null && year != null) {
      final start = '$year-${month.toString().padLeft(2, '0')}-01';
      final nextM = month == 12 ? 1 : month + 1;
      final nextY = month == 12 ? year + 1 : year;
      q = q.gte('date', start).lt('date', '$nextY-${nextM.toString().padLeft(2, '0')}-01');
    }
    return q.order('date', ascending: false);
  }

  static Future<int> createPresentation(String date, String time, {String? location, String? repertoire}) async {
    final r = await _supabase.from('presentations').insert({
      'date': date, 'time': time, 'location': location, 'repertoire': repertoire,
    }).select();
    return (r.first as Map<String, dynamic>)['id'] as int;
  }

  static Future<List<Map<String, dynamic>>> getPresentationAttendance(int presentationId) async {
    final data = await _supabase.from('presentation_attendance').select('*, members!inner(name)').eq('presentation_id', presentationId).order('name', referencedTable: 'members');
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      m['member_name'] = (m.remove('members') as Map<String, dynamic>)['name'];
      return m;
    }).toList();
  }

  static Future<void> markPresentationAttendance(int memberId, int presentationId, String status) async {
    await _supabase.from('presentation_attendance').upsert({
      'member_id': memberId, 'presentation_id': presentationId, 'status': status,
    });
  }

  /// Guarda el estado de asistencia de varios miembros con una sola llamada.
  static Future<void> markPresentationAttendanceBatch(int presentationId, Map<int, String> statusByMemberId) async {
    if (statusByMemberId.isEmpty) return;
    final rows = statusByMemberId.entries.map((e) => {
      'member_id': e.key, 'presentation_id': presentationId, 'status': e.value,
    }).toList();
    await _supabase.from('presentation_attendance').upsert(rows);
  }

  static Future<void> markAllPresentationAttendance(int presentationId, String status) async {
    final members = await _supabase.from('members').select('id').eq('is_active', 1);
    if (members.isEmpty) return;
    final rows = members.map((m) => {
      'member_id': m['id'], 'presentation_id': presentationId, 'status': status,
    }).toList();
    await _supabase.from('presentation_attendance').upsert(rows);
  }

  static Future<void> autoClosePresentations() async {
    final today = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    await _supabase.from('presentations').update({'is_closed': 1}).lt('date', today).eq('is_closed', 0);
  }

  static Future<void> closePresentation(int id) async {
    await _supabase.from('presentations').update({'is_closed': 1}).eq('id', id);
  }

  static Future<Map<String, dynamic>?> getPresentation(int id) async {
    final r = await _supabase.from('presentations').select().eq('id', id);
    return r.isNotEmpty ? r.first as Map<String, dynamic> : null;
  }

  static Future<List<Map<String, dynamic>>> getFutureEvents() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final presentations = await _supabase
        .from('presentations')
        .select()
        .gte('date', today)
        .order('date');
    final rehearsals = await _supabase
        .from('rehearsals')
        .select()
        .gte('date', today)
        .order('date');
    return [...presentations, ...rehearsals];
  }

  static Future<void> updateFcmToken(int userId, String token) async {
    await _supabase.from('users').update({'fcm_token': token}).eq('id', userId);
  }

  static int? getCurrentUserId() {
    return _currentUser?['id'] as int?;
  }

  // ─── Reports ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTop10(int year, int month) async {
    final r = await _supabase.rpc('get_top10', params: {'p_year': year, 'p_month': month});
    return (r as List).cast<Map<String, dynamic>>();
  }

  // ─── Treasury & Fines ──────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTreasury({int? month, int? year}) async {
    var q = _supabase.from('treasury').select();
    if (month != null && year != null) {
      final start = '$year-${month.toString().padLeft(2, '0')}-01';
      final nextM = month == 12 ? 1 : month + 1;
      final nextY = month == 12 ? year + 1 : year;
      q = q.gte('created_at', start).lt('created_at', '$nextY-${nextM.toString().padLeft(2, '0')}-01');
    }
    return q.order('created_at', ascending: false);
  }

  static Future<Map<String, double>> getTreasurySummary({int? month, int? year}) async {
    final r = await _supabase.rpc('get_treasury_summary', params: {'p_year': year, 'p_month': month});
    final m = r as Map<String, dynamic>;
    return {
      'total_income': (m['total_income'] as num).toDouble(),
      'total_expense': (m['total_expense'] as num).toDouble(),
      'balance': (m['balance'] as num).toDouble(),
    };
  }

  static Future<int> addTreasuryEntry(String type, String concept, double amount, {String? description, int? memberId}) async {
    final r = await _supabase.from('treasury').insert({
      'type': type, 'concept': concept, 'amount': amount,
      'description': description, 'member_id': memberId,
    }).select();
    return (r.first as Map<String, dynamic>)['id'] as int;
  }

  static Future<List<Map<String, dynamic>>> getMemberDebts() async {
    final r = await _supabase.rpc('get_member_debts');
    return (r as List).cast<Map<String, dynamic>>();
  }

  static Future<void> addMemberFine(int memberId, double amount, String reason) async {
    await _supabase.from('member_fines').insert({
      'member_id': memberId, 'amount': amount, 'reason': reason,
    });
  }

  static Future<void> collectMemberDebt(int memberId, double amount, String concept) async {
    await _supabase.rpc('collect_member_debt', params: {
      'p_member_id': memberId, 'p_amount': amount, 'p_concept': concept,
    });
  }

  static Future<List<Map<String, dynamic>>> getMemberFines(int memberId) async {
    return _supabase.from('member_fines').select().eq('member_id', memberId).order('created_at', ascending: false);
  }

  // ─── Auth ──────────────────────────────────────────────
  static Map<String, dynamic>? _currentUser;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null;
  static bool get isStaff => _currentUser != null && ['admin', 'tesorero', 'director'].contains(_currentUser!['role']);
  static bool get isAdmin => _currentUser != null && _currentUser!['role'] == 'admin';

  static String _hash(String s) {
    return sha256.convert(utf8.encode(s)).toString();
  }

  /// Inicia sesion con Google. Solo permite correos @unsaac.edu.pe o los
  /// que el admin haya autorizado. Si el correo es valido pero aun no tiene
  /// cuenta, devuelve [GoogleAuthStatus.needsLink] para vincularlo a un miembro.
  static Future<GoogleAuthResult> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return const GoogleAuthResult(GoogleAuthStatus.cancelled);
      }
      final email = account.email.trim().toLowerCase();

      final authorized =
          email.endsWith('@$allowedDomain') || await _isAuthorizedEmail(email);
      if (!authorized) {
        await _googleSignIn.signOut();
        return GoogleAuthResult(GoogleAuthStatus.unauthorized, email: email);
      }

      final users = await _supabase.from('users').select().eq('email', email);
      if (users.isNotEmpty) {
        _currentUser = users.first as Map<String, dynamic>;
        await _persistSession();
        await _saveFcmToken();
        return GoogleAuthResult(GoogleAuthStatus.loggedIn, email: email);
      }
      return GoogleAuthResult(GoogleAuthStatus.needsLink, email: email);
    } catch (e) {
      _lastError = e.toString();
      return const GoogleAuthResult(GoogleAuthStatus.error);
    }
  }

  /// Crea la cuenta de un usuario que entro por Google y la vincula a un
  /// miembro. No usa contraseña (se guarda un marcador que nunca coincide
  /// con un hash real de login por contraseña).
  static Future<Map<String, dynamic>?> registerGoogleUser(
      String email, int memberId,
      {String role = 'miembro'}) async {
    try {
      final r = await _supabase.from('users').insert({
        'email': email.trim().toLowerCase(),
        'password_hash': 'GOOGLE_OAUTH',
        'member_id': memberId,
        'role': role,
        'session_token': 'active',
      }).select().single();
      _currentUser = r as Map<String, dynamic>;
      await _persistSession();
      await _saveFcmToken();
      return _currentUser;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  /// Lista de correos autorizados por el admin (fuera del dominio institucional),
  /// guardada en settings como texto separado por comas.
  static Future<List<String>> getAuthorizedEmails() async {
    final settings = await getSettings();
    return (settings['authorized_emails'] ?? '')
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Future<bool> _isAuthorizedEmail(String email) async {
    final list = await getAuthorizedEmails();
    return list.contains(email);
  }

  /// URL de la foto de perfil de la cuenta de Google (o null si el usuario
  /// no entro con Google o no tiene foto). Usa la sesion de Google ya
  /// existente en el dispositivo, sin volver a pedir login.
  static Future<String?> googlePhotoUrl() async {
    try {
      final acct = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      return acct?.photoUrl;
    } catch (_) {
      return null;
    }
  }

  static Future<void> addAuthorizedEmail(String email) async {
    final list = await getAuthorizedEmails();
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || list.contains(normalized)) return;
    list.add(normalized);
    await updateSetting('authorized_emails', list.join(','));
  }

  static Future<void> removeAuthorizedEmail(String email) async {
    final list = await getAuthorizedEmails();
    list.remove(email.trim().toLowerCase());
    await updateSetting('authorized_emails', list.join(','));
  }

  static String? _lastError;
  static String? get lastError => _lastError;

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final users = await _supabase.from('users').select()
          .eq('email', email).eq('password_hash', _hash(password))
          .timeout(const Duration(seconds: 30));
      if (users.isEmpty) return null;
      _currentUser = users.first as Map<String, dynamic>;
      await _persistSession();
      // Save FCM token after login
      await _saveFcmToken();
      return _currentUser;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  static Future<void> _saveFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && _currentUser != null) {
        await updateFcmToken(_currentUser!['id'] as int, token);
      }
    } catch (_) {}
  }

  static Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _clearSession();
    _currentUser = null;
    _membersCache = null;
    _settingsCache = null;
  }

  // ─── Sesion local por dispositivo ──────────────────────
  // La sesion se guarda en el propio celular (SharedPreferences), no en un
  // flag global de la base de datos, para que cada dispositivo tenga su
  // propia sesion independiente.
  static const String _sessionKey = 'logged_user_id';

  static Future<void> _persistSession() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionKey, _currentUser!['id'] as int);
  }

  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_sessionKey);
    if (id == null) return;
    try {
      final users = await _supabase.from('users').select().eq('id', id);
      if (users.isNotEmpty) {
        _currentUser = users.first as Map<String, dynamic>;
      } else {
        await _clearSession();
      }
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getUnlinkedMembers() async {
    final r = await _supabase.rpc('get_unlinked_members');
    return (r as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final data = await _supabase.from('users').select('*, members!left(name)').order('email');
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      m['member_name'] = (m.remove('members') as Map<String, dynamic>?)?['name'];
      return m;
    }).toList();
  }

  static Future<void> updateUserRole(int userId, String role) async {
    await _supabase.from('users').update({'role': role}).eq('id', userId);
    if (_currentUser?['id'] == userId) _currentUser?['role'] = role;
  }

  static Future<void> updateUserMember(int userId, int? memberId) async {
    await _supabase.from('users').update({'member_id': memberId}).eq('id', userId);
    if (_currentUser?['id'] == userId) _currentUser?['member_id'] = memberId;
  }

  static Future<List<Map<String, dynamic>>> getMyAttendance(int memberId) async {
    final data = await _supabase.from('attendance').select('rehearsals!inner(date, start_time, end_time)')
        .eq('member_id', memberId).order('date', referencedTable: 'rehearsals', ascending: false);
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      final rehearsal = m.remove('rehearsals') as Map<String, dynamic>;
      m['date'] = rehearsal['date'];
      m['start_time'] = rehearsal['start_time'];
      m['end_time'] = rehearsal['end_time'];
      return m;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getMyFines(int memberId) async {
    final data = await _supabase.from('member_fines').select('*, members!inner(name)').eq('member_id', memberId).order('created_at', ascending: false);
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      m['member_name'] = (m.remove('members') as Map<String, dynamic>)['name'];
      return m;
    }).toList();
  }

  static Future<Map<String, dynamic>> getMyStats(int memberId) async {
    final r = await _supabase.rpc('get_my_stats', params: {'p_member_id': memberId});
    return r as Map<String, dynamic>;
  }

  // ─── Settings ──────────────────────────────────────────
  // Igual que _membersCache: se consulta desde casi toda la app (calculo de
  // tardanza, ajustes, correos autorizados) y rara vez cambia.
  static Map<String, String>? _settingsCache;

  static Future<Map<String, String>> getSettings({bool forceRefresh = false}) async {
    if (!forceRefresh && _settingsCache != null) return _settingsCache!;
    final rows = await _supabase.from('settings').select();
    final map = <String, String>{};
    for (final r in rows) map[r['key'] as String] = r['value'] as String;
    _settingsCache = map;
    return map;
  }

  static Future<void> updateSetting(String key, String value) async {
    await _supabase.from('settings').upsert({'key': key, 'value': value});
    _settingsCache = null;
  }
}
