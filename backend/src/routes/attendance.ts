import { Hono } from 'hono';
import { Env, Attendance } from '../types';

export const attendanceRoutes = new Hono<{ Bindings: Env }>();

attendanceRoutes.get('/rehearsal/:rehearsalId', async (c) => {
  const rehearsalId = c.req.param('rehearsalId');

  const records = await c.env.DB.prepare(
    `SELECT a.*, m.name as member_name, m.email as member_email
     FROM attendance a
     JOIN members m ON a.member_id = m.id
     WHERE a.rehearsal_id = ?
     ORDER BY m.name`
  ).bind(rehearsalId).all();

  return c.json(records.results);
});

attendanceRoutes.get('/member/:memberId', async (c) => {
  const memberId = c.req.param('memberId');
  const payload = c.get('jwtPayload');

  if (payload.role !== 'admin' && payload.sub !== Number(memberId)) {
    return c.json({ error: 'Not authorized' }, 403);
  }

  const { limit, offset } = c.req.query();
  let query = `SELECT a.*, r.date, r.start_time, r.end_time
               FROM attendance a
               JOIN rehearsals r ON a.rehearsal_id = r.id
               WHERE a.member_id = ?
               ORDER BY r.date DESC`;
  let params: string[] = [memberId];

  if (limit) { query += ` LIMIT ?`; params.push(limit); }
  if (offset) { query += ` OFFSET ?`; params.push(offset); }

  const records = await c.env.DB.prepare(query).bind(...params).all();
  return c.json(records.results);
});

attendanceRoutes.post('/', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const { member_id, rehearsal_id, arrival_time, notes } = await c.req.json();
  if (!member_id || !rehearsal_id || !arrival_time) {
    return c.json({ error: 'member_id, rehearsal_id, arrival_time required' }, 400);
  }

  const rehearsal = await c.env.DB.prepare(
    'SELECT * FROM rehearsals WHERE id = ?'
  ).bind(rehearsal_id).first<{ start_time: string; end_time: string }>();

  if (!rehearsal) return c.json({ error: 'Rehearsal not found' }, 404);

  const settings = await getSettings(c.env.DB);
  const graceMinutes = parseInt(settings.grace_period_minutes || '15');
  const finePerMinute = parseFloat(settings.fine_per_minute || '0.20');

  const result = calculateAttendance(arrival_time, rehearsal.start_time, graceMinutes, finePerMinute);

  const attendance = await c.env.DB.prepare(
    `INSERT INTO attendance (member_id, rehearsal_id, arrival_time, status, late_minutes, fine_amount, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(member_id, rehearsal_id) DO UPDATE SET
       arrival_time = excluded.arrival_time,
       status = excluded.status,
       late_minutes = excluded.late_minutes,
       fine_amount = excluded.fine_amount,
       notes = excluded.notes,
       updated_at = datetime('now')
     RETURNING *`
  ).bind(
    member_id, rehearsal_id, arrival_time,
    result.status, result.lateMinutes, result.fineAmount,
    notes || null
  ).first<Attendance>();

  return c.json(attendance, 201);
});

attendanceRoutes.post('/batch', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const { rehearsal_id, records } = await c.req.json();
  if (!rehearsal_id || !records || !Array.isArray(records)) {
    return c.json({ error: 'rehearsal_id and records array required' }, 400);
  }

  const rehearsal = await c.env.DB.prepare(
    'SELECT * FROM rehearsals WHERE id = ?'
  ).bind(rehearsal_id).first<{ start_time: string; end_time: string }>();

  if (!rehearsal) return c.json({ error: 'Rehearsal not found' }, 404);

  const settings = await getSettings(c.env.DB);
  const graceMinutes = parseInt(settings.grace_period_minutes || '15');
  const finePerMinute = parseFloat(settings.fine_per_minute || '0.20');

  const results = [];
  const errors = [];

  for (const record of records) {
    const { member_id, arrival_time, notes } = record;
    if (!member_id || !arrival_time) {
      errors.push({ member_id, error: 'member_id and arrival_time required' });
      continue;
    }

    const result = calculateAttendance(arrival_time, rehearsal.start_time, graceMinutes, finePerMinute);

    try {
      const attendance = await c.env.DB.prepare(
        `INSERT INTO attendance (member_id, rehearsal_id, arrival_time, status, late_minutes, fine_amount, notes)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(member_id, rehearsal_id) DO UPDATE SET
           arrival_time = excluded.arrival_time,
           status = excluded.status,
           late_minutes = excluded.late_minutes,
           fine_amount = excluded.fine_amount,
           notes = excluded.notes,
           updated_at = datetime('now')
         RETURNING *`
      ).bind(
        member_id, rehearsal_id, arrival_time,
        result.status, result.lateMinutes, result.fineAmount,
        notes || null
      ).first<Attendance>();

      results.push(attendance);
    } catch (e) {
      errors.push({ member_id, error: String(e) });
    }
  }

  return c.json({ results, errors, total: results.length, failed: errors.length }, 201);
});

attendanceRoutes.put('/:id', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const id = c.req.param('id');
  const { arrival_time, status, late_minutes, fine_amount, notes } = await c.req.json();

  await c.env.DB.prepare(
    `UPDATE attendance SET
       arrival_time = COALESCE(?, arrival_time),
       status = COALESCE(?, status),
       late_minutes = COALESCE(?, late_minutes),
       fine_amount = COALESCE(?, fine_amount),
       notes = COALESCE(?, notes),
       updated_at = datetime('now')
     WHERE id = ?`
  ).bind(
    arrival_time || null, status || null,
    late_minutes !== undefined ? late_minutes : null,
    fine_amount !== undefined ? fine_amount : null,
    notes !== undefined ? notes : null,
    id
  ).run();

  const updated = await c.env.DB.prepare('SELECT * FROM attendance WHERE id = ?').bind(id).first<Attendance>();
  return c.json(updated);
});

attendanceRoutes.delete('/:id', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const id = c.req.param('id');
  await c.env.DB.prepare('DELETE FROM attendance WHERE id = ?').bind(id).run();
  return c.json({ success: true });
});

function calculateAttendance(
  arrivalTime: string,
  sessionStart: string,
  graceMinutes: number,
  finePerMinute: number
): { status: 'present' | 'late' | 'absent'; lateMinutes: number; fineAmount: number } {
  const [arrH, arrM] = arrivalTime.split(':').map(Number);
  const [startH, startM] = sessionStart.split(':').map(Number);

  const arrTotal = arrH * 60 + arrM;
  const startTotal = startH * 60 + startM;
  const diff = arrTotal - startTotal;

  if (diff < 0) {
    return { status: 'present', lateMinutes: 0, fineAmount: 0 };
  }

  if (diff <= graceMinutes) {
    return { status: 'present', lateMinutes: diff, fineAmount: 0 };
  }

  const lateMin = diff - graceMinutes;
  const fine = Math.round(lateMin * finePerMinute * 100) / 100;

  return { status: 'late', lateMinutes: diff, fineAmount: fine };
}

async function getSettings(db: D1Database): Promise<Record<string, string>> {
  const result = await db.prepare('SELECT key, value FROM settings').all<{ key: string; value: string }>();
  const settings: Record<string, string> = {};
  for (const row of result.results) {
    settings[row.key] = row.value;
  }
  return settings;
}
