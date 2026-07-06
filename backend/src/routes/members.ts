import { Hono } from 'hono';
import { getCookie } from 'hono/cookie';
import { Env, Member } from '../types';

export const memberRoutes = new Hono<{ Bindings: Env }>();

memberRoutes.get('/', async (c) => {
  const payload = c.get('jwtPayload');
  const members = await c.env.DB.prepare(
    'SELECT id, name, email, phone, role, is_active, created_at FROM members ORDER BY name'
  ).all<Member>();

  return c.json(members.results);
});

memberRoutes.get('/:id', async (c) => {
  const id = c.req.param('id');
  const member = await c.env.DB.prepare(
    'SELECT id, name, email, phone, role, is_active, created_at FROM members WHERE id = ?'
  ).bind(id).first<Member>();

  if (!member) return c.json({ error: 'Member not found' }, 404);
  return c.json(member);
});

memberRoutes.post('/', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const { name, email, phone } = await c.req.json();
  if (!name) return c.json({ error: 'name required' }, 400);

  const member = await c.env.DB.prepare(
    `INSERT INTO members (name, email, phone) VALUES (?, ?, ?) RETURNING id, name, email, phone, role, is_active, created_at`
  ).bind(name, email || null, phone || null).first<Member>();

  return c.json(member, 201);
});

memberRoutes.put('/:id', async (c) => {
  const payload = c.get('jwtPayload');
  const id = c.req.param('id');

  if (payload.role !== 'admin' && payload.sub !== Number(id)) {
    return c.json({ error: 'Not authorized' }, 403);
  }

  const { name, email, phone, is_active } = await c.req.json();
  const existing = await c.env.DB.prepare('SELECT id FROM members WHERE id = ?').bind(id).first();
  if (!existing) return c.json({ error: 'Member not found' }, 404);

  await c.env.DB.prepare(
    `UPDATE members SET name = COALESCE(?, name), email = COALESCE(?, email),
     phone = COALESCE(?, phone), is_active = COALESCE(?, is_active),
     updated_at = datetime('now') WHERE id = ?`
  ).bind(name || null, email !== undefined ? email : null, phone !== undefined ? phone : null, is_active !== undefined ? (is_active ? 1 : 0) : null, id).run();

  const updated = await c.env.DB.prepare(
    'SELECT id, name, email, phone, role, is_active, created_at FROM members WHERE id = ?'
  ).bind(id).first<Member>();

  return c.json(updated);
});

memberRoutes.delete('/:id', async (c) => {
  const payload = c.get('jwtPayload');
  if (payload.role !== 'admin') return c.json({ error: 'Admin only' }, 403);

  const id = c.req.param('id');
  await c.env.DB.prepare('DELETE FROM members WHERE id = ?').bind(id).run();
  return c.json({ success: true });
});
