CREATE TABLE IF NOT EXISTS members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'member' CHECK(role IN ('admin', 'member')),
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS auth (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS rehearsals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL UNIQUE,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  description TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS attendance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER NOT NULL,
  rehearsal_id INTEGER NOT NULL,
  arrival_time TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('present', 'late', 'absent')),
  late_minutes INTEGER NOT NULL DEFAULT 0,
  fine_amount REAL NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
  FOREIGN KEY (rehearsal_id) REFERENCES rehearsals(id) ON DELETE CASCADE,
  UNIQUE(member_id, rehearsal_id)
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT OR IGNORE INTO settings (key, value) VALUES
  ('schedule_monday_start', '18:00'),
  ('schedule_monday_end', '20:00'),
  ('schedule_wednesday_start', '18:00'),
  ('schedule_wednesday_end', '20:00'),
  ('schedule_friday_start', '18:00'),
  ('schedule_friday_end', '20:00'),
  ('grace_period_minutes', '15'),
  ('fine_per_minute', '0.20'),
  ('fine_currency', 'S/');

CREATE INDEX IF NOT EXISTS idx_attendance_member ON attendance(member_id);
CREATE INDEX IF NOT EXISTS idx_attendance_rehearsal ON attendance(rehearsal_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(rehearsal_id, member_id);
CREATE INDEX IF NOT EXISTS idx_rehearsals_date ON rehearsals(date);
