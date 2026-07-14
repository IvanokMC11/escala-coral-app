  -- ============================================================
  -- FIX: Reportes fallaba con "function round(double precision, integer)
  -- does not exist". El problema es que ROUND() en PostgreSQL no acepta
  -- REAL/double, solo NUMERIC. Se cambia el CAST a NUMERIC.
  --
  -- Ejecutar TODO este bloque en: Supabase -> SQL Editor -> Run
  -- ============================================================

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
