import { Hono } from 'hono';
import { Env, MonthlyReport } from '../types';

export const reportRoutes = new Hono<{ Bindings: Env }>();

reportRoutes.get('/monthly/:year/:month', async (c) => {
  const year = c.req.param('year');
  const month = c.req.param('month').padStart(2, '0');
  const payload = c.get('jwtPayload');

  const memberFilter = c.req.query('member_id');

  let query = `
    SELECT
      m.id as member_id,
      m.name as member_name,
      COUNT(r.id) as total_rehearsals,
      SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present_count,
      SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) as late_count,
      SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent_count,
      COALESCE(SUM(a.late_minutes), 0) as total_late_minutes,
      COALESCE(SUM(a.fine_amount), 0) as total_fine,
      ROUND(CAST(SUM(CASE WHEN a.status IN ('present', 'late') THEN 1 ELSE 0 END) AS REAL) / COUNT(r.id) * 100, 1) as attendance_percentage
    FROM members m
    CROSS JOIN (
      SELECT id FROM rehearsals
      WHERE strftime('%m', date) = ? AND strftime('%Y', date) = ?
    ) r
    LEFT JOIN attendance a ON a.member_id = m.id AND a.rehearsal_id = r.id
    WHERE m.is_active = 1
  `;

  let params: string[] = [month, year];

  if (memberFilter) {
    query += ` AND m.id = ?`;
    params.push(memberFilter);
  }

  query += `
    GROUP BY m.id, m.name
    ORDER BY attendance_percentage DESC, total_late_minutes ASC
  `;

  const report = await c.env.DB.prepare(query).bind(...params).all<MonthlyReport>();
  return c.json(report.results);
});

reportRoutes.get('/top10/:year/:month', async (c) => {
  const year = c.req.param('year');
  const month = c.req.param('month').padStart(2, '0');

  const report = await c.env.DB.prepare(`
    SELECT
      m.id as member_id,
      m.name as member_name,
      COUNT(r.id) as total_rehearsals,
      SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present_count,
      SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) as late_count,
      SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent_count,
      COALESCE(SUM(a.late_minutes), 0) as total_late_minutes,
      COALESCE(SUM(a.fine_amount), 0) as total_fine,
      ROUND(CAST(SUM(CASE WHEN a.status IN ('present', 'late') THEN 1 ELSE 0 END) AS REAL) / COUNT(r.id) * 100, 1) as attendance_percentage
    FROM members m
    CROSS JOIN (
      SELECT id FROM rehearsals
      WHERE strftime('%m', date) = ? AND strftime('%Y', date) = ?
    ) r
    LEFT JOIN attendance a ON a.member_id = m.id AND a.rehearsal_id = r.id
    WHERE m.is_active = 1
    GROUP BY m.id, m.name
    HAVING total_rehearsals > 0
    ORDER BY attendance_percentage DESC, total_late_minutes ASC, present_count DESC
    LIMIT 10
  `).bind(month, year).all<MonthlyReport>();

  return c.json({
    month: parseInt(month),
    year: parseInt(year),
    total_rehearsals: report.results.length > 0 ? report.results[0].total_rehearsals : 0,
    ranking: report.results
  });
});

reportRoutes.get('/member/:memberId/stats', async (c) => {
  const memberId = c.req.param('memberId');
  const payload = c.get('jwtPayload');

  if (payload.role !== 'admin' && payload.sub !== Number(memberId)) {
    return c.json({ error: 'Not authorized' }, 403);
  }

  const { year } = c.req.query();
  let dateFilter = '';
  let params: string[] = [memberId];

  if (year) {
    dateFilter = 'AND strftime(\'%Y\', r.date) = ?';
    params.push(year);
  }

  const stats = await c.env.DB.prepare(`
    SELECT
      COUNT(r.id) as total_rehearsals,
      SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present_count,
      SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) as late_count,
      SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent_count,
      COALESCE(SUM(a.late_minutes), 0) as total_late_minutes,
      COALESCE(SUM(a.fine_amount), 0) as total_fine,
      ROUND(CAST(SUM(CASE WHEN a.status IN ('present', 'late') THEN 1 ELSE 0 END) AS REAL) / COUNT(r.id) * 100, 1) as attendance_percentage
    FROM members m
    JOIN rehearsals r ON 1=1
    LEFT JOIN attendance a ON a.member_id = m.id AND a.rehearsal_id = r.id
    WHERE m.id = ? ${dateFilter}
  `).bind(...params).first();

  const recent = await c.env.DB.prepare(`
    SELECT a.*, r.date, r.start_time, r.end_time
    FROM attendance a
    JOIN rehearsals r ON a.rehearsal_id = r.id
    WHERE a.member_id = ?
    ORDER BY r.date DESC
    LIMIT 10
  `).bind(memberId).all();

  return c.json({ stats, recent_attendance: recent.results });
});

reportRoutes.get('/settings', async (c) => {
  const settings = await c.env.DB.prepare('SELECT key, value FROM settings').all<{ key: string; value: string }>();
  const result: Record<string, string> = {};
  for (const row of settings.results) {
    result[row.key] = row.value;
  }
  return c.json(result);
});

reportRoutes.put('/settings', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const updates = await c.req.json();
  for (const [key, value] of Object.entries(updates)) {
    await c.env.DB.prepare(
      `INSERT INTO settings (key, value) VALUES (?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value`
    ).bind(key, String(value)).run();
  }

  const settings = await c.env.DB.prepare('SELECT key, value FROM settings').all<{ key: string; value: string }>();
  const result: Record<string, string> = {};
  for (const row of settings.results) {
    result[row.key] = row.value;
  }
  return c.json(result);
});
