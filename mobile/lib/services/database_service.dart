import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:path/path.dart';

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
      version: 8,
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
            collected INTEGER NOT NULL DEFAULT 0,
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

        await db.execute('''
          CREATE TABLE IF NOT EXISTS member_fines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            reason TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            paid INTEGER NOT NULL DEFAULT 0,
            paid_at TEXT,
            FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS treasury (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL CHECK(type IN ('income','expense')),
            concept TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT,
            member_id INTEGER,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            member_id INTEGER,
            role TEXT NOT NULL DEFAULT 'miembro' CHECK(role IN ('admin','tesorero','director','miembro')),
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_treasury_date ON treasury(created_at)');

        // Crear admin por defecto
        final adminHash = sha256.convert(utf8.encode('admin123')).toString();
        await db.insert('users', {'email': 'admin', 'password_hash': adminHash, 'role': 'admin', 'member_id': 1});

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
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              email TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL,
              member_id INTEGER,
              role TEXT NOT NULL DEFAULT 'miembro' CHECK(role IN ('admin','tesorero','director','miembro')),
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
            )
          ''');
          final adminHash = sha256.convert(utf8.encode('admin123')).toString();
          await db.insert('users', {'email': 'admin', 'password_hash': adminHash, 'role': 'admin', 'member_id': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        if (oldVersion < 7) {
          await db.execute("ALTER TABLE attendance ADD COLUMN collected INTEGER NOT NULL DEFAULT 0");
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS member_fines (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              member_id INTEGER NOT NULL,
              amount REAL NOT NULL,
              reason TEXT NOT NULL,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              paid INTEGER NOT NULL DEFAULT 0,
              paid_at TEXT,
              FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS treasury (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL CHECK(type IN ('income','expense')),
              concept TEXT NOT NULL,
              amount REAL NOT NULL,
              description TEXT,
              member_id INTEGER,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
            )
          ''');
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

  // ─── Attendance Matrix ─────────────────────────────────
  static Future<Map<String, dynamic>> getAttendanceMatrix(int year, int month) async {
    final db = await database;
    final m = month.toString().padLeft(2, '0');
    final rehearsals = await db.rawQuery('''
      SELECT id, date, start_time, end_time
      FROM rehearsals
      WHERE strftime('%m', date) = ? AND strftime('%Y', date) = ? AND is_canceled = 0
      ORDER BY date ASC
    ''', [m, '$year']);
    final members = await db.query('members', where: 'is_active = 1', orderBy: 'name ASC');
    final rehearsalIds = rehearsals.map((r) => r['id'] as int).toList();
    List<Map<String, dynamic>> attendance = [];
    if (rehearsalIds.isNotEmpty) {
      final placeholders = rehearsalIds.map((_) => '?').join(',');
      attendance = await db.rawQuery('''
        SELECT a.member_id, a.rehearsal_id, a.status, a.arrival_time, a.late_minutes, a.fine_amount
        FROM attendance a
        WHERE a.rehearsal_id IN ($placeholders)
      ''', rehearsalIds);
    }
    final attMap = <String, Map<String, dynamic>>{};
    for (final a in attendance) {
      attMap['${a['member_id']}_${a['rehearsal_id']}'] = a;
    }
    return {'rehearsals': rehearsals, 'members': members, 'attendance': attMap};
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

  // ─── Treasury & Fines ──────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTreasury({int? month, int? year}) async {
    final db = await database;
    if (month != null && year != null) {
      final m = month.toString().padLeft(2, '0');
      return db.rawQuery('''
        SELECT * FROM treasury
        WHERE strftime('%m', created_at) = ? AND strftime('%Y', created_at) = ?
        ORDER BY created_at DESC
      ''', [m, '$year']);
    }
    return db.query('treasury', orderBy: 'created_at DESC');
  }

  static Future<Map<String, double>> getTreasurySummary({int? month, int? year}) async {
    final db = await database;
    String where = ''; List? args;
    if (month != null && year != null) {
      final m = month.toString().padLeft(2, '0');
      where = "WHERE strftime('%m', created_at) = ? AND strftime('%Y', created_at) = ?";
      args = [m, '$year'];
    }
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as total_income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as total_expense
      FROM treasury $where
    ''', args ?? []);
    if (result.isEmpty) return {'total_income': 0, 'total_expense': 0, 'balance': 0};
    final income = (result.first['total_income'] as num).toDouble();
    final expense = (result.first['total_expense'] as num).toDouble();
    return {'total_income': income, 'total_expense': expense, 'balance': income - expense};
  }

  static Future<int> addTreasuryEntry(String type, String concept, double amount, {String? description, int? memberId}) async {
    final db = await database;
    return db.insert('treasury', {
      'type': type, 'concept': concept, 'amount': amount,
      'description': description, 'member_id': memberId,
    });
  }

  static Future<List<Map<String, dynamic>>> getMemberDebts() async {
    final db = await database;
    final lateFees = await db.rawQuery('''
      SELECT m.id, m.name, COALESCE(SUM(a.fine_amount), 0) as late_fee_debt
      FROM members m
      LEFT JOIN attendance a ON a.member_id = m.id AND a.status = 'late' AND a.collected = 0
      WHERE m.is_active = 1
      GROUP BY m.id
    ''');
    final manualFines = await db.rawQuery('''
      SELECT member_id, COALESCE(SUM(amount), 0) as manual_fine_debt
      FROM member_fines WHERE paid = 0
      GROUP BY member_id
    ''');
    final manualMap = {for (final f in manualFines) f['member_id'] as int: (f['manual_fine_debt'] as num).toDouble()};
    return lateFees.map((m) {
      final id = m['id'] as int;
      final late = (m['late_fee_debt'] as num).toDouble();
      final manual = manualMap[id] ?? 0.0;
      return {
        'id': id,
        'name': m['name'],
        'late_fee_debt': late,
        'manual_fine_debt': manual,
        'total_debt': late + manual,
      };
    }).toList();
  }

  static Future<void> addMemberFine(int memberId, double amount, String reason) async {
    final db = await database;
    await db.insert('member_fines', {'member_id': memberId, 'amount': amount, 'reason': reason});
  }

  static Future<void> collectMemberDebt(int memberId, double amount, String concept) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('treasury', {
        'type': 'income', 'concept': concept, 'amount': amount,
        'description': 'Cobro a miembro', 'member_id': memberId,
      });
      await txn.execute('''
        UPDATE attendance SET collected = 1
        WHERE member_id = ? AND status = 'late' AND collected = 0
      ''', [memberId]);
      await txn.execute('''
        UPDATE member_fines SET paid = 1, paid_at = datetime('now')
        WHERE member_id = ? AND paid = 0
      ''', [memberId]);
    });
  }

  static Future<List<Map<String, dynamic>>> getMemberFines(int memberId) async {
    final db = await database;
    return db.query('member_fines', where: 'member_id = ?', whereArgs: [memberId], orderBy: 'created_at DESC');
  }

  // ─── Auth ──────────────────────────────────────────────
  static Map<String, dynamic>? _currentUser;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null;
  static bool get isStaff => _currentUser != null && ['admin', 'tesorero', 'director'].contains(_currentUser!['role']);
  static bool get isAdmin => _currentUser != null && _currentUser!['role'] == 'admin';

  static Future<Map<String, dynamic>?> register(String email, String password, {int? memberId, String role = 'miembro'}) async {
    final db = await database;
    final hash = sha256.convert(utf8.encode(password)).toString();
    try {
      final id = await db.insert('users', {'email': email, 'password_hash': hash, 'member_id': memberId, 'role': role, 'session_token': 'active'});
      _currentUser = (await db.query('users', where: 'id = ?', whereArgs: [id])).first;
      return _currentUser;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final db = await database;
    final hash = sha256.convert(utf8.encode(password)).toString();
    final users = await db.query('users', where: 'email = ? AND password_hash = ?', whereArgs: [email, hash]);
    if (users.isEmpty) return null;
    _currentUser = users.first;
    await db.update('users', {'session_token': 'active'}, where: 'id = ?', whereArgs: [_currentUser!['id']]);
    return _currentUser;
  }

  static Future<void> logout() async {
    if (_currentUser != null) {
      final db = await database;
      await db.update('users', {'session_token': null}, where: 'id = ?', whereArgs: [_currentUser!['id']]);
    }
    _currentUser = null;
  }

  static Future<void> restoreSession() async {
    final db = await database;
    final users = await db.query('users', where: 'session_token = ?', whereArgs: ['active'], limit: 1);
    if (users.isNotEmpty) _currentUser = users.first;
  }

  static Future<List<Map<String, dynamic>>> getUnlinkedMembers() async {
    final db = await database;
    return db.rawQuery('''
      SELECT m.* FROM members m
      LEFT JOIN users u ON u.member_id = m.id
      WHERE u.id IS NULL AND m.is_active = 1
      ORDER BY m.name
    ''');
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return db.rawQuery('''
      SELECT u.*, m.name as member_name FROM users u
      LEFT JOIN members m ON m.id = u.member_id
      ORDER BY u.email
    ''');
  }

  static Future<void> updateUserRole(int userId, String role) async {
    final db = await database;
    await db.update('users', {'role': role}, where: 'id = ?', whereArgs: [userId]);
    if (_currentUser?['id'] == userId) _currentUser?['role'] = role;
  }

  static Future<void> updateUserMember(int userId, int? memberId) async {
    final db = await database;
    await db.update('users', {'member_id': memberId}, where: 'id = ?', whereArgs: [userId]);
    if (_currentUser?['id'] == userId) _currentUser?['member_id'] = memberId;
  }

  static Future<List<Map<String, dynamic>>> getMyAttendance(int memberId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT r.date, r.start_time, r.end_time, a.arrival_time, a.status, a.late_minutes, a.fine_amount, a.collected
      FROM attendance a JOIN rehearsals r ON a.rehearsal_id = r.id
      WHERE a.member_id = ?
      ORDER BY r.date DESC
    ''', [memberId]);
  }

  static Future<List<Map<String, dynamic>>> getMyFines(int memberId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT mf.*, m.name as member_name FROM member_fines mf
      JOIN members m ON m.id = mf.member_id
      WHERE mf.member_id = ?
      ORDER BY mf.created_at DESC
    ''', [memberId]);
  }

  static Future<Map<String, dynamic>> getMyStats(int memberId) async {
    final db = await database;
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString();
    final result = await db.rawQuery('''
      SELECT
        COUNT(r.id) as total,
        COALESCE(SUM(CASE WHEN a.status IN ('present','late') THEN 1 ELSE 0 END), 0) as attended,
        COALESCE(SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END), 0) as late_count,
        COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END), 0) as absent_count,
        COALESCE(SUM(a.fine_amount), 0) as total_fines,
        COALESCE(SUM(CASE WHEN a.collected = 1 THEN a.fine_amount ELSE 0 END), 0) as paid_fines
      FROM members m
      CROSS JOIN (SELECT id FROM rehearsals WHERE strftime('%m', date) = ? AND strftime('%Y', date) = ? AND is_canceled = 0) r
      LEFT JOIN attendance a ON a.member_id = m.id AND a.rehearsal_id = r.id
      WHERE m.id = ?
    ''', [m, y, memberId]);
    return result.isNotEmpty ? result.first : {'total': 0, 'attended': 0, 'late_count': 0, 'absent_count': 0, 'total_fines': 0, 'paid_fines': 0};
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
