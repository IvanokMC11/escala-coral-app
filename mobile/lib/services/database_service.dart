import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:path/path.dart';
import 'dart:io';

class DatabaseService {
  static Database? _db;
  static bool _initialized = false;

  static Future<Database> get database async {
    if (!_initialized) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        ffi.sqfliteFfiInit();
        databaseFactory = ffi.databaseFactoryFfi;
      }
      _initialized = true;
    }
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'escala_coral.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT,
            phone TEXT,
            codigo TEXT,
            escuela TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            beca_eligible INTEGER NOT NULL DEFAULT 1,
            cuerda TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');

        await db.execute('''
          CREATE TABLE rehearsals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            description TEXT,
            is_canceled INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');

        await db.execute('''
          CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER NOT NULL,
            rehearsal_id INTEGER NOT NULL,
            arrival_time TEXT NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('present','late','absent')),
            late_minutes INTEGER NOT NULL DEFAULT 0,
            fine_amount REAL NOT NULL DEFAULT 0,
            notes TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
            FOREIGN KEY (rehearsal_id) REFERENCES rehearsals(id) ON DELETE CASCADE,
            UNIQUE(member_id, rehearsal_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE presentations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            time TEXT NOT NULL,
            location TEXT,
            repertoire TEXT,
            is_closed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');

        await db.execute('''
          CREATE TABLE presentation_attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER NOT NULL,
            presentation_id INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'present' CHECK(status IN ('present','absent')),
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
            FOREIGN KEY (presentation_id) REFERENCES presentations(id) ON DELETE CASCADE,
            UNIQUE(member_id, presentation_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_attendance_member ON attendance(member_id)');
        await db.execute('CREATE INDEX idx_attendance_rehearsal ON attendance(rehearsal_id)');
        await db.execute('CREATE INDEX idx_pres_att_member ON presentation_attendance(member_id)');
        await db.execute('CREATE INDEX idx_pres_att_pres ON presentation_attendance(presentation_id)');

        await db.insert('settings', {'key': 'grace_period_minutes', 'value': '15'});
        await db.insert('settings', {'key': 'fine_per_minute', 'value': '0.20'});
        await db.insert('settings', {'key': 'fine_currency', 'value': 'S/'});
        await db.insert('settings', {'key': 'schedule_monday_start', 'value': '18:00'});
        await db.insert('settings', {'key': 'schedule_monday_end', 'value': '20:00'});
        await db.insert('settings', {'key': 'schedule_wednesday_start', 'value': '18:00'});
        await db.insert('settings', {'key': 'schedule_wednesday_end', 'value': '20:00'});
        await db.insert('settings', {'key': 'schedule_friday_start', 'value': '18:00'});
        await db.insert('settings', {'key': 'schedule_friday_end', 'value': '20:00'});
        await db.insert('settings', {'key': 'presentation_weight', 'value': '5'});

        final members = [
          {'name': 'Jaide Liseth Ramirez Hurtado', 'codigo': '241528', 'escuela': 'Matematica', 'cuerda': 'SOPRANO'},
          {'name': 'Astrid Araceli Ramos Puma', 'codigo': '231475', 'escuela': 'Matematica', 'cuerda': 'ALTO'},
          {'name': 'Marianela Haquehua Felix', 'codigo': '241513', 'escuela': 'Matematica', 'cuerda': ''},
          {'name': 'Kevin Paul Quispe Luque', 'codigo': '235235', 'escuela': 'Derecho', 'cuerda': 'ALTO'},
          {'name': 'George Ivanok Munoz Castillo', 'codigo': '204800', 'escuela': 'Ing. Informatica y de sistemas', 'cuerda': 'TENOR'},
          {'name': 'Leonardo Dario Mormontoy Quispe', 'codigo': '250913', 'escuela': 'Matematica', 'cuerda': 'TENOR'},
          {'name': 'Ronaldo Huaman Tecse', 'codigo': '215945', 'escuela': 'Arquitectura', 'cuerda': 'BAJO'},
          {'name': 'Tany Damnet Marron Pampa', 'codigo': '221633', 'escuela': 'Biologia', 'cuerda': 'TENOR'},
          {'name': 'Claudia Verenize Flores Mollinedo', 'codigo': '220846', 'escuela': 'Educacion secundaria c. lengua y literatura', 'cuerda': 'ALTO'},
          {'name': 'Carlos Eduardo Banda Cjuno', 'codigo': '250869', 'escuela': 'Ing. Geologica', 'cuerda': 'TENOR'},
          {'name': 'Luciano Javier Alanoca Senca', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'TENOR'},
          {'name': 'Josue Alejandro Flores Huicho', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'BAJO'},
          {'name': 'Helen Silvana Ormachea Achaui', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'SOPRANO'},
          {'name': 'Isabel Gabriela Percca Tupayachi', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'SOPRANO'},
          {'name': 'Ivonne Alexandra Nathali Robles Panduro', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'SOPRANO'},
          {'name': 'Josue Samuel Roque Quispe', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'TENOR'},
          {'name': 'Varinia Villavicencio Yllapuma', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'ALTO'},
          {'name': 'Miralbe Josdely Warthon Campana', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'SOPRANO'},
          {'name': 'Paul Sandro Zuniga Huaman', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'BAJO'},
          {'name': 'Leo Dan Chayna Castro', 'codigo': '', 'escuela': '', 'beca_eligible': 0, 'cuerda': 'TENOR'},
        ];
        final batch = db.batch();
        for (final m in members) {
          batch.insert('members', m);
        }
        await batch.commit(noResult: true);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE rehearsals ADD COLUMN is_canceled INTEGER NOT NULL DEFAULT 0");
          await db.execute('''
            CREATE TABLE IF NOT EXISTS presentations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL, time TEXT NOT NULL,
              location TEXT, repertoire TEXT,
              is_closed INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS presentation_attendance (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              member_id INTEGER NOT NULL, presentation_id INTEGER NOT NULL,
              status TEXT NOT NULL DEFAULT 'present' CHECK(status IN ('present','absent')),
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
              FOREIGN KEY (presentation_id) REFERENCES presentations(id) ON DELETE CASCADE,
              UNIQUE(member_id, presentation_id)
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_pres_att_member ON presentation_attendance(member_id)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_pres_att_pres ON presentation_attendance(presentation_id)');
          await db.insert('settings', {'key': 'presentation_weight', 'value': '5'});
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE members ADD COLUMN codigo TEXT");
          await db.execute("ALTER TABLE members ADD COLUMN escuela TEXT");
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE members ADD COLUMN beca_eligible INTEGER NOT NULL DEFAULT 1");
        }
        if (oldVersion < 5) {
          await db.execute("ALTER TABLE members ADD COLUMN cuerda TEXT");
        }
      },
    );
  }

  // ─── Members ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMembers() async {
    final db = await database;
    return db.query('members', where: 'is_active = 1', orderBy: 'name');
  }

  static Future<int> addMember(String name, {String? email, String? phone, String? codigo, String? escuela, int becaEligible = 1, String? cuerda}) async {
    final db = await database;
    return db.insert('members', {'name': name, 'email': email, 'phone': phone, 'codigo': codigo, 'escuela': escuela, 'beca_eligible': becaEligible, 'cuerda': cuerda});
  }

  static Future<void> updateMember(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('members', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteMember(int id) async {
    final db = await database;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Rehearsals ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRehearsals({int? month, int? year}) async {
    final db = await database;
    String? where;
    List? whereArgs;
    if (month != null && year != null) {
      where = "strftime('%m', date) = ? AND strftime('%Y', date) = ?";
      whereArgs = [month.toString().padLeft(2, '0'), year.toString()];
    }
    return db.query('rehearsals', where: where, whereArgs: whereArgs, orderBy: 'date ASC');
  }

  static Future<int> createRehearsal(String date, String startTime, String endTime, {String? description}) async {
    final db = await database;
    return db.insert('rehearsals', {
      'date': date, 'start_time': startTime, 'end_time': endTime, 'description': description,
    });
  }

  static Future<void> cancelRehearsal(int id, bool canceled) async {
    final db = await database;
    await db.update('rehearsals', {'is_canceled': canceled ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> autoGenerateRehearsals() async {
    final db = await database;
    final now = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final date = now.add(Duration(days: i));
      if (date.weekday == DateTime.monday || date.weekday == DateTime.wednesday || date.weekday == DateTime.friday) {
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final existing = await db.query('rehearsals', where: 'date = ?', whereArgs: [dateStr]);
        if (existing.isEmpty) {
          final dayName = date.weekday == DateTime.monday ? 'Lunes' : date.weekday == DateTime.wednesday ? 'Miercoles' : 'Viernes';
          await db.insert('rehearsals', {
            'date': dateStr, 'start_time': '18:00', 'end_time': '20:00', 'description': 'Ensayo $dayName',
          });
        }
      }
    }
  }

  static Future<Map<String, dynamic>?> getRehearsal(int id) async {
    final db = await database;
    final results = await db.query('rehearsals', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<void> deleteRehearsal(int id) async {
    final db = await database;
    await db.delete('attendance', where: 'rehearsal_id = ?', whereArgs: [id]);
    await db.delete('rehearsals', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Attendance ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRehearsalAttendance(int rehearsalId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT a.*, m.name as member_name
      FROM attendance a JOIN members m ON a.member_id = m.id
      WHERE a.rehearsal_id = ? ORDER BY m.name
    ''', [rehearsalId]);
  }

  static Future<Map<String, dynamic>> markAttendance(int memberId, int rehearsalId, String arrivalTime) async {
    final db = await database;
    final settings = await getSettings();
    final grace = int.parse(settings['grace_period_minutes'] ?? '15');
    final fine = double.parse(settings['fine_per_minute'] ?? '0.20');
    final rehearsal = await db.query('rehearsals', where: 'id = ?', whereArgs: [rehearsalId]);
    if (rehearsal.isEmpty) throw Exception('Ensayo no encontrado');
    final start = rehearsal.first['start_time'] as String;
    final r = _calc(arrivalTime, start, grace, fine);
    final id = await db.insert('attendance', {
      'member_id': memberId, 'rehearsal_id': rehearsalId, 'arrival_time': arrivalTime,
      'status': r['status'], 'late_minutes': r['lateMinutes'], 'fine_amount': r['fineAmount'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return (await db.query('attendance', where: 'id = ?', whereArgs: [id])).first;
  }

  static Future<void> markFJ(int memberId, int rehearsalId) async {
    final db = await database;
    await db.insert('attendance', {
      'member_id': memberId, 'rehearsal_id': rehearsalId, 'arrival_time': 'FJ',
      'status': 'present', 'late_minutes': 0, 'fine_amount': 0, 'notes': 'Falta justificada',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> markBatch(int rehearsalId, List<Map<String, dynamic>> records) async {
    final db = await database;
    final settings = await getSettings();
    final grace = int.parse(settings['grace_period_minutes'] ?? '15');
    final fine = double.parse(settings['fine_per_minute'] ?? '0.20');
    final rehearsal = await db.query('rehearsals', where: 'id = ?', whereArgs: [rehearsalId]);
    if (rehearsal.isEmpty) throw Exception('Ensayo no encontrado');
    final start = rehearsal.first['start_time'] as String;
    final batch = db.batch();
    for (final r in records) {
      final res = _calc(r['arrival_time'], start, grace, fine);
      batch.insert('attendance', {
        'member_id': r['member_id'], 'rehearsal_id': rehearsalId, 'arrival_time': r['arrival_time'],
        'status': res['status'], 'late_minutes': res['lateMinutes'], 'fine_amount': res['fineAmount'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
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
    final db = await database;
    final m = month.toString().padLeft(2, '0');
    return db.rawQuery('''
      SELECT
        m.id, m.name, m.codigo, m.escuela,
        COUNT(r.id) as total_rehearsals,
        COALESCE(SUM(CASE WHEN a.status = 'present' OR a.status = 'late' THEN 1 ELSE 0 END), 0) as attended,
        COALESCE(SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END), 0) as late_count,
        COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END), 0) as absent_count,
        COALESCE(SUM(a.late_minutes), 0) as total_late_minutes,
        COALESCE(SUM(a.fine_amount), 0) as total_fine
      FROM members m
      CROSS JOIN (SELECT id FROM rehearsals WHERE strftime('%m', date) = ? AND strftime('%Y', date) = ? AND is_canceled = 0) r
      LEFT JOIN attendance a ON a.member_id = m.id AND a.rehearsal_id = r.id
      WHERE m.is_active = 1
      GROUP BY m.id, m.name, m.codigo, m.escuela
      ORDER BY m.name
    ''', [m, '$year']);
  }

  // ─── Presentations ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPresentations({int? month, int? year}) async {
    final db = await database;
    String? where;
    List? whereArgs;
    if (month != null && year != null) {
      where = "strftime('%m', date) = ? AND strftime('%Y', date) = ?";
      whereArgs = [month.toString().padLeft(2, '0'), year.toString()];
    }
    return db.query('presentations', where: where, whereArgs: whereArgs, orderBy: 'date DESC');
  }

  static Future<int> createPresentation(String date, String time, {String? location, String? repertoire}) async {
    final db = await database;
    return db.insert('presentations', {
      'date': date, 'time': time, 'location': location, 'repertoire': repertoire,
    });
  }

  static Future<List<Map<String, dynamic>>> getPresentationAttendance(int presentationId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT pa.*, m.name as member_name
      FROM presentation_attendance pa JOIN members m ON pa.member_id = m.id
      WHERE pa.presentation_id = ? ORDER BY m.name
    ''', [presentationId]);
  }

  static Future<void> markPresentationAttendance(int memberId, int presentationId, String status) async {
    final db = await database;
    await db.insert('presentation_attendance', {
      'member_id': memberId, 'presentation_id': presentationId, 'status': status,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> markAllPresentationAttendance(int presentationId, String status) async {
    final db = await database;
    final members = await db.query('members', where: 'is_active = 1');
    final batch = db.batch();
    for (final m in members) {
      batch.insert('presentation_attendance', {
        'member_id': m['id'], 'presentation_id': presentationId, 'status': status,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> autoClosePresentations() async {
    final db = await database;
    final today = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    await db.update('presentations', {'is_closed': 1},
      where: "date < ? AND is_closed = 0", whereArgs: [today]);
  }

  static Future<void> closePresentation(int id) async {
    final db = await database;
    await db.update('presentations', {'is_closed': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<Map<String, dynamic>?> getPresentation(int id) async {
    final db = await database;
    final results = await db.query('presentations', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  // ─── Reports ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTop10(int year, int month) async {
    final db = await database;
    final m = month.toString().padLeft(2, '0');
    final weight = int.parse((await getSettings())['presentation_weight'] ?? '5');
    return db.rawQuery('''
      SELECT
        member_id, member_name, codigo, escuela,
        SUM(total) as total_events,
        SUM(present) as present_count,
        SUM(late) as late_count,
        SUM(absent) as absent_count,
        SUM(late_min) as total_late_minutes,
        SUM(fine) as total_fine,
        ROUND(CAST(SUM(present + late) AS REAL) / SUM(total) * 100, 1) as attendance_percentage
      FROM (
        SELECT
          m.id as member_id, m.name as member_name, m.codigo, m.escuela,
          COUNT(r.id) as total,
          SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present,
          SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) as late,
          SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent,
          COALESCE(SUM(a.late_minutes), 0) as late_min,
          COALESCE(SUM(a.fine_amount), 0) as fine
        FROM members m
        CROSS JOIN (SELECT id FROM rehearsals WHERE strftime('%m', date) = ? AND strftime('%Y', date) = ? AND is_canceled = 0) r
        LEFT JOIN attendance a ON a.member_id = m.id AND a.rehearsal_id = r.id
        WHERE m.is_active = 1
        GROUP BY m.id, m.name, m.codigo, m.escuela
        UNION ALL
        SELECT
          m.id as member_id, m.name as member_name, m.codigo, m.escuela,
          COUNT(p.id) * $weight as total,
          SUM(CASE WHEN pa.status = 'present' THEN $weight ELSE 0 END) as present,
          0 as late, 0 as absent, 0 as late_min, 0 as fine
        FROM members m
        CROSS JOIN (SELECT id FROM presentations WHERE strftime('%m', date) = ? AND strftime('%Y', date) = ?) p
        LEFT JOIN presentation_attendance pa ON pa.member_id = m.id AND pa.presentation_id = p.id
        WHERE m.is_active = 1
        GROUP BY m.id, m.name, m.codigo, m.escuela
      )
      GROUP BY member_id, member_name
      HAVING total_events > 0
      ORDER BY attendance_percentage DESC, total_late_minutes ASC
      LIMIT 10
    ''', [m, '$year', m, '$year']);
  }

  // ─── Settings ──────────────────────────────────────────
  static Future<Map<String, String>> getSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    final map = <String, String>{};
    for (final r in rows) map[r['key'] as String] = r['value'] as String;
    return map;
  }

  static Future<void> updateSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
