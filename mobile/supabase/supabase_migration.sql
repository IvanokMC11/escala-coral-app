-- ============================================================
-- MIGRACION: SQLite -> Supabase PostgreSQL
-- Ejecutar esto en Supabase SQL Editor
-- ============================================================

-- 1. TABLAS
-- ----------------------------------------
CREATE TABLE members (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  codigo TEXT,
  escuela TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  beca_eligible INTEGER NOT NULL DEFAULT 1,
  cuerda TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE rehearsals (
  id SERIAL PRIMARY KEY,
  date DATE NOT NULL UNIQUE,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  description TEXT,
  is_canceled INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE attendance (
  id SERIAL PRIMARY KEY,
  member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  rehearsal_id INTEGER NOT NULL REFERENCES rehearsals(id) ON DELETE CASCADE,
  arrival_time TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('present','late','absent')),
  late_minutes INTEGER NOT NULL DEFAULT 0,
  fine_amount NUMERIC NOT NULL DEFAULT 0,
  collected INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  justified_entry_time TEXT, -- Hora de entrada justificada (para llegadas tardías permitidas sin multa)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(member_id, rehearsal_id)
);

CREATE TABLE presentations (
  id SERIAL PRIMARY KEY,
  date DATE NOT NULL,
  time TIME NOT NULL,
  location TEXT,
  repertoire TEXT,
  is_closed INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE presentation_attendance (
  id SERIAL PRIMARY KEY,
  member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  presentation_id INTEGER NOT NULL REFERENCES presentations(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'present' CHECK(status IN ('present','absent')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(member_id, presentation_id)
);

CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE member_fines (
  id SERIAL PRIMARY KEY,
  member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid INTEGER NOT NULL DEFAULT 0,
  paid_at TIMESTAMPTZ
);

CREATE TABLE treasury (
  id SERIAL PRIMARY KEY,
  type TEXT NOT NULL CHECK(type IN ('income','expense')),
  concept TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  description TEXT,
  member_id INTEGER REFERENCES members(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  member_id INTEGER REFERENCES members(id) ON DELETE SET NULL,
  role TEXT NOT NULL DEFAULT 'miembro' CHECK(role IN ('admin','tesorero','director','miembro')),
  session_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. INDICES
-- ----------------------------------------
CREATE INDEX idx_attendance_member ON attendance(member_id);
CREATE INDEX idx_attendance_rehearsal ON attendance(rehearsal_id);
CREATE INDEX idx_pres_att_member ON presentation_attendance(member_id);
CREATE INDEX idx_pres_att_pres ON presentation_attendance(presentation_id);
CREATE INDEX idx_treasury_date ON treasury(created_at);

-- 3. FUNCIONES para consultas complejas
-- ----------------------------------------

-- Obtener miembros activos con estadisticas mensuales
CREATE OR REPLACE FUNCTION get_member_monthly_stats(p_year INT, p_month INT)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT JSON_AGG(row_to_json(t)) INTO result FROM (
    SELECT
      m.id, m.name, m.codigo, m.escuela,
      COUNT(r.id) as total_rehearsals,
      COALESCE(SUM(CASE WHEN a.status IN ('present','late') THEN 1 ELSE 0 END), 0) as attended,
      COALESCE(SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END), 0) as late_count,
      COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END), 0) as absent_count,
      COALESCE(SUM(a.late_minutes), 0) as total_late_minutes,
      COALESCE(SUM(a.fine_amount), 0) as total_fine
    FROM members m
    CROSS JOIN (
      SELECT id FROM rehearsals
      WHERE EXTRACT(MONTH FROM date) = p_month AND EXTRACT(YEAR FROM date) = p_year AND is_canceled = 0
    ) r
    LEFT JOIN attendance a ON a.member_id = m.id AND a.rehearsal_id = r.id
    WHERE m.is_active = 1
    GROUP BY m.id, m.name, m.codigo, m.escuela
    ORDER BY m.name
  ) t;
  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql;

-- Matriz de asistencia
CREATE OR REPLACE FUNCTION get_attendance_matrix(p_year INT, p_month INT)
RETURNS JSON AS $$
DECLARE
  rehearsals_json JSON;
  members_json JSON;
  attendance_json JSON;
BEGIN
  SELECT JSON_AGG(row_to_json(t)) INTO rehearsals_json FROM (
    SELECT id, date::TEXT, start_time::TEXT, end_time::TEXT
    FROM rehearsals
    WHERE EXTRACT(MONTH FROM date) = p_month AND EXTRACT(YEAR FROM date) = p_year AND is_canceled = 0
    ORDER BY date ASC
  ) t;

  SELECT JSON_AGG(row_to_json(t)) INTO members_json FROM (
    SELECT * FROM members WHERE is_active = 1 ORDER BY name ASC
  ) t;

  SELECT JSON_AGG(row_to_json(t)) INTO attendance_json FROM (
    SELECT a.member_id, a.rehearsal_id, a.status, a.arrival_time, a.late_minutes, a.fine_amount
    FROM attendance a
    WHERE a.rehearsal_id IN (
      SELECT id FROM rehearsals
      WHERE EXTRACT(MONTH FROM date) = p_month AND EXTRACT(YEAR FROM date) = p_year AND is_canceled = 0
    )
  ) t;

  RETURN JSON_BUILD_OBJECT(
    'rehearsals', COALESCE(rehearsals_json, '[]'::JSON),
    'members', COALESCE(members_json, '[]'::JSON),
    'attendance', COALESCE(attendance_json, '[]'::JSON)
  );
END;
$$ LANGUAGE plpgsql;

-- Top 10 ranking
CREATE OR REPLACE FUNCTION get_top10(p_year INT, p_month INT)
RETURNS JSON AS $$
DECLARE
  weight INT;
  result JSON;
BEGIN
  SELECT COALESCE(value::INT, 5) INTO weight FROM settings WHERE key = 'presentation_weight';

  SELECT JSON_AGG(row_to_json(t)) INTO result FROM (
    SELECT
      member_id, member_name, codigo, escuela,
      SUM(total) as total_events,
      SUM(present) as present_count,
      SUM(late) as late_count,
      SUM(absent) as absent_count,
      SUM(late_min) as total_late_minutes,
      SUM(fine) as total_fine,
      ROUND(CAST(SUM(present + late) AS NUMERIC) / NULLIF(SUM(total), 0) * 100, 1) as attendance_percentage
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
      CROSS JOIN (SELECT id FROM rehearsals WHERE EXTRACT(MONTH FROM date) = p_month AND EXTRACT(YEAR FROM date) = p_year AND is_canceled = 0) r
      LEFT JOIN attendance a ON a.member_id = m.id AND a.rehearsal_id = r.id
      WHERE m.is_active = 1
      GROUP BY m.id, m.name, m.codigo, m.escuela
      UNION ALL
      SELECT
        m.id as member_id, m.name as member_name, m.codigo, m.escuela,
        COUNT(p.id) * weight as total,
        SUM(CASE WHEN pa.status = 'present' THEN weight ELSE 0 END) as present,
        0 as late, 0 as absent, 0 as late_min, 0 as fine
      FROM members m
      CROSS JOIN (SELECT id FROM presentations WHERE EXTRACT(MONTH FROM date) = p_month AND EXTRACT(YEAR FROM date) = p_year) p
      LEFT JOIN presentation_attendance pa ON pa.member_id = m.id AND pa.presentation_id = p.id
      WHERE m.is_active = 1
      GROUP BY m.id, m.name, m.codigo, m.escuela
    ) sub
    GROUP BY member_id, member_name, codigo, escuela
    HAVING SUM(total) > 0
    ORDER BY attendance_percentage DESC, total_late_minutes ASC
    LIMIT 10
  ) t;
  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql;

-- Deudas de miembros
CREATE OR REPLACE FUNCTION get_member_debts()
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT JSON_AGG(row_to_json(t)) INTO result FROM (
    SELECT m.id, m.name,
      COALESCE(lf.late_fee_debt, 0) as late_fee_debt,
      COALESCE(mf.manual_fine_debt, 0) as manual_fine_debt,
      COALESCE(lf.late_fee_debt, 0) + COALESCE(mf.manual_fine_debt, 0) as total_debt
    FROM members m
    LEFT JOIN (
      SELECT member_id, SUM(fine_amount) as late_fee_debt
      FROM attendance WHERE status = 'late' AND collected = 0
      GROUP BY member_id
    ) lf ON lf.member_id = m.id
    LEFT JOIN (
      SELECT member_id, SUM(amount) as manual_fine_debt
      FROM member_fines WHERE paid = 0
      GROUP BY member_id
    ) mf ON mf.member_id = m.id
    WHERE m.is_active = 1
      AND (COALESCE(lf.late_fee_debt, 0) + COALESCE(mf.manual_fine_debt, 0)) > 0
    ORDER BY m.name
  ) t;
  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql;

-- Estadisticas de un miembro
CREATE OR REPLACE FUNCTION get_my_stats(p_member_id INT)
RETURNS JSON AS $$
DECLARE
  now_date DATE := CURRENT_DATE;
  p_month INT := EXTRACT(MONTH FROM now_date);
  p_year INT := EXTRACT(YEAR FROM now_date);
  result JSON;
BEGIN
  SELECT row_to_json(t) INTO result FROM (
    SELECT
      COUNT(r.id) as total,
      COALESCE(SUM(CASE WHEN a.status IN ('present','late') THEN 1 ELSE 0 END), 0) as attended,
      COALESCE(SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END), 0) as late_count,
      COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END), 0) as absent_count,
      COALESCE(SUM(a.fine_amount), 0) as total_fines,
      COALESCE(SUM(CASE WHEN a.collected = 1 THEN a.fine_amount ELSE 0 END), 0) as paid_fines
    FROM members m
    CROSS JOIN (SELECT id FROM rehearsals WHERE EXTRACT(MONTH FROM date) = p_month AND EXTRACT(YEAR FROM date) = p_year AND is_canceled = 0) r
    LEFT JOIN attendance a ON a.member_id = m.id AND a.rehearsal_id = r.id
    WHERE m.id = p_member_id
  ) t;
  RETURN COALESCE(result, '{"total": 0, "attended": 0, "late_count": 0, "absent_count": 0, "total_fines": 0, "paid_fines": 0}'::JSON);
END;
$$ LANGUAGE plpgsql;

-- Resumen de tesoreria
CREATE OR REPLACE FUNCTION get_treasury_summary(p_year INT DEFAULT NULL, p_month INT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
  income NUMERIC;
  expense NUMERIC;
BEGIN
  SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0)
  INTO income, expense
  FROM treasury
  WHERE (p_year IS NULL OR EXTRACT(YEAR FROM created_at) = p_year)
    AND (p_month IS NULL OR EXTRACT(MONTH FROM created_at) = p_month);

  RETURN JSON_BUILD_OBJECT('total_income', income, 'total_expense', expense, 'balance', income - expense);
END;
$$ LANGUAGE plpgsql;

-- Cobrar deuda de miembro (transaccion)
CREATE OR REPLACE FUNCTION collect_member_debt(p_member_id INT, p_amount NUMERIC, p_concept TEXT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO treasury (type, concept, amount, description, member_id)
  VALUES ('income', p_concept, p_amount, 'Cobro a miembro', p_member_id);

  UPDATE attendance SET collected = 1
  WHERE member_id = p_member_id AND status = 'late' AND collected = 0;

  UPDATE member_fines SET paid = 1, paid_at = NOW()
  WHERE member_id = p_member_id AND paid = 0;
END;
$$ LANGUAGE plpgsql;

-- 4. DATOS INICIALES
-- ----------------------------------------
-- Miembros sin usuario vinculado
CREATE OR REPLACE FUNCTION get_unlinked_members()
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT JSON_AGG(row_to_json(t)) INTO result FROM (
    SELECT m.* FROM members m
    LEFT JOIN users u ON u.member_id = m.id
    WHERE u.id IS NULL AND m.is_active = 1
    ORDER BY m.name
  ) t;
  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql;

INSERT INTO settings (key, value) VALUES
  ('grace_period_minutes', '15'),
  ('fine_per_minute', '0.20'),
  ('fine_currency', 'S/'),
  ('schedule_monday_start', '18:00'),
  ('schedule_monday_end', '20:00'),
  ('schedule_wednesday_start', '18:00'),
  ('schedule_wednesday_end', '20:00'),
  ('schedule_friday_start', '18:00'),
  ('schedule_friday_end', '20:00'),
  ('presentation_weight', '5')
ON CONFLICT (key) DO NOTHING;

-- Miembros iniciales
INSERT INTO members (name, codigo, escuela, cuerda) VALUES
  ('Jaide Liseth Ramirez Hurtado', '241528', 'Matematica', 'SOPRANO'),
  ('Astrid Araceli Ramos Puma', '231475', 'Matematica', 'ALTO'),
  ('Marianela Haquehua Felix', '241513', 'Matematica', NULL),
  ('Kevin Paul Quispe Luque', '235235', 'Derecho', 'ALTO'),
  ('George Ivanok Munoz Castillo', '204800', 'Ing. Informatica y de sistemas', 'TENOR'),
  ('Leonardo Dario Mormontoy Quispe', '250913', 'Matematica', 'TENOR'),
  ('Ronaldo Huaman Tecse', '215945', 'Arquitectura', 'BAJO'),
  ('Tany Damnet Marron Pampa', '221633', 'Biologia', 'TENOR'),
  ('Claudia Verenize Flores Mollinedo', '220846', 'Educacion secundaria c. lengua y literatura', 'ALTO'),
  ('Carlos Eduardo Banda Cjuno', '250869', 'Ing. Geologica', 'TENOR'),
  ('Luciano Javier Alanoca Senca', '', '', 'TENOR'),
  ('Josue Alejandro Flores Huicho', '', '', 'BAJO'),
  ('Helen Silvana Ormachea Achaui', '', '', 'SOPRANO'),
  ('Isabel Gabriela Percca Tupayachi', '', '', 'SOPRANO'),
  ('Ivonne Alexandra Nathali Robles Panduro', '', '', 'SOPRANO'),
  ('Josue Samuel Roque Quispe', '', '', 'TENOR'),
  ('Varinia Villavicencio Yllapuma', '', '', 'ALTO'),
  ('Miralbe Josdely Warthon Campana', '', '', 'SOPRANO'),
  ('Paul Sandro Zuniga Huaman', '', '', 'BAJO'),
  ('Leo Dan Chayna Castro', '', '', 'TENOR')
ON CONFLICT DO NOTHING;

-- Miembros sin beca (beca_eligible = 0 por defecto, se actualizan manualmente en la app)
UPDATE members SET beca_eligible = 0 WHERE name IN (
  'Luciano Javier Alanoca Senca', 'Josue Alejandro Flores Huicho',
  'Helen Silvana Ormachea Achaui', 'Isabel Gabriela Percca Tupayachi',
  'Ivonne Alexandra Nathali Robles Panduro', 'Josue Samuel Roque Quispe',
  'Varinia Villavicencio Yllapuma', 'Miralbe Josdely Warthon Campana',
  'Paul Sandro Zuniga Huaman', 'Leo Dan Chayna Castro'
);

-- Admin por defecto (contraseña: admin123)
INSERT INTO users (email, password_hash, role, member_id, session_token)
VALUES ('admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'admin', 1, NULL)
ON CONFLICT (email) DO NOTHING;
