import { Hono } from 'hono';
import { Env, Rehearsal } from '../types';

export const rehearsalRoutes = new Hono<{ Bindings: Env }>();

function getScheduleDay(dateStr: string): string {
  const date = new Date(dateStr);
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  return days[date.getDay()];
}

rehearsalRoutes.get('/', async (c) => {
  const { month, year, limit, offset } = c.req.query();
  let query = 'SELECT * FROM rehearsals';
  let params: string[] = [];

  if (month && year) {
    query += ` WHERE strftime('%m', date) = ? AND strftime('%Y', date) = ?`;
    params = [month.padStart(2, '0'), year];
  }

  query += ' ORDER BY date DESC';

  if (limit) query += ` LIMIT ?`; params.push(limit);
  if (offset) query += ` OFFSET ?`; params.push(offset);

  const rehearsals = await c.env.DB.prepare(query).bind(...params).all<Rehearsal>();
  return c.json(rehearsals.results);
});

rehearsalRoutes.get('/upcoming', async (c) => {
  const rehearsals = await c.env.DB.prepare(
    `SELECT * FROM rehearsals WHERE date >= date('now') ORDER BY date ASC LIMIT 10`
  ).all<Rehearsal>();

  return c.json(rehearsals.results);
});

rehearsalRoutes.get('/:id', async (c) => {
  const id = c.req.param('id');
  const rehearsal = await c.env.DB.prepare('SELECT * FROM rehearsals WHERE id = ?').bind(id).first<Rehearsal>();
  if (!rehearsal) return c.json({ error: 'Rehearsal not found' }, 404);

  const attendance = await c.env.DB.prepare(
    `SELECT a.*, m.name as member_name FROM attendance a
     JOIN members m ON a.member_id = m.id
     WHERE a.rehearsal_id = ? ORDER BY m.name`
  ).bind(id).all();

  return c.json({ ...rehearsal, attendance: attendance.results });
});

rehearsalRoutes.post('/', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const { date, start_time, end_time, description } = await c.req.json();
  if (!date || !start_time || !end_time) {
    return c.json({ error: 'date, start_time, end_time required' }, 400);
  }

  const existing = await c.env.DB.prepare('SELECT id FROM rehearsals WHERE date = ?').bind(date).first();
  if (existing) return c.json({ error: 'Rehearsal already exists for this date' }, 409);

  const rehearsal = await c.env.DB.prepare(
    `INSERT INTO rehearsals (date, start_time, end_time, description)
     VALUES (?, ?, ?, ?) RETURNING *`
  ).bind(date, start_time, end_time, description || null).first<Rehearsal>();

  return c.json(rehearsal, 201);
});

rehearsalRoutes.post('/generate', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const { year, month } = await c.req.json();
  if (!year || !month) return c.json({ error: 'year and month required' }, 400);

  const settings = await getSettings(c.env.DB);
  const scheduleDays = ['monday', 'wednesday', 'friday'];
  const created: Rehearsal[] = [];

  const daysInMonth = new Date(year, month, 0).getDate();
  for (let day = 1; day <= daysInMonth; day++) {
    const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    const dayName = getScheduleDay(dateStr);

    if (scheduleDays.includes(dayName)) {
      const startKey = `schedule_${dayName}_start`;
      const endKey = `schedule_${dayName}_end`;
      const startTime = settings[startKey] || '18:00';
      const endTime = settings[endKey] || '20:00';

      const existing = await c.env.DB.prepare('SELECT id FROM rehearsals WHERE date = ?').bind(dateStr).first();
      if (!existing) {
        const r = await c.env.DB.prepare(
          `INSERT INTO rehearsals (date, start_time, end_time, description)
           VALUES (?, ?, ?, ?) RETURNING *`
        ).bind(dateStr, startTime, endTime, `Ensayo ${dayName}`).first<Rehearsal>();
        if (r) created.push(r);
      }
    }
  }

  return c.json({ created, count: created.length }, 201);
});

rehearsalRoutes.put('/:id', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const id = c.req.param('id');
  const { date, start_time, end_time, description } = await c.req.json();

  await c.env.DB.prepare(
    `UPDATE rehearsals SET date = COALESCE(?, date), start_time = COALESCE(?, start_time),
     end_time = COALESCE(?, end_time), description = COALESCE(?, description),
     updated_at = datetime('now') WHERE id = ?`
  ).bind(date || null, start_time || null, end_time || null, description !== undefined ? description : null, id).run();

  const updated = await c.env.DB.prepare('SELECT * FROM rehearsals WHERE id = ?').bind(id).first<Rehearsal>();
  return c.json(updated);
});

rehearsalRoutes.delete('/:id', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const id = c.req.param('id');
  await c.env.DB.prepare('DELETE FROM rehearsals WHERE id = ?').bind(id).run();
  return c.json({ success: true });
});

async function getSettings(db: D1Database): Promise<Record<string, string>> {
  const result = await db.prepare('SELECT key, value FROM settings').all<{ key: string; value: string }>();
  const settings: Record<string, string> = {};
  for (const row of result.results) {
    settings[row.key] = row.value;
  }
  return settings;
}
