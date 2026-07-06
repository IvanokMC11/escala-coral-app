import { Hono } from 'hono';
import { sign } from 'hono/jwt';
import { Env } from '../types';

export const authRoutes = new Hono<{ Bindings: Env }>();

authRoutes.post('/register', async (c) => {
  try {
    const { name, email, password, phone } = await c.req.json();
    if (!name || !email || !password) {
      return c.json({ error: 'name, email, and password required' }, 400);
    }

    const existing = await c.env.DB.prepare(
      'SELECT id FROM members WHERE email = ?'
    ).bind(email).first();

    if (existing) {
      return c.json({ error: 'Email already registered' }, 409);
    }

    const isFirstUser = await c.env.DB.prepare(
      'SELECT COUNT(*) as count FROM members'
    ).first<{ count: number }>();

    const passwordHash = await hashPassword(password);

    const member = await c.env.DB.prepare(
      `INSERT INTO members (name, email, phone, role) VALUES (?, ?, ?, ?) RETURNING id, name, email, role`
    ).bind(name, email, phone, isFirstUser!.count === 0 ? 'admin' : 'member').first<{ id: number; name: string; email: string; role: string }>();

    await c.env.DB.prepare(
      'INSERT INTO auth (member_id, password_hash) VALUES (?, ?)'
    ).bind(member!.id, passwordHash).run();

    const token = await sign({ sub: member!.id, email: member!.email, role: member!.role }, c.env.JWT_SECRET);

    return c.json({ token, user: member }, 201);
  } catch (e) {
    return c.json({ error: 'Registration failed' }, 500);
  }
});

authRoutes.post('/login', async (c) => {
  try {
    const { email, password } = await c.req.json();
    if (!email || !password) {
      return c.json({ error: 'email and password required' }, 400);
    }

    const authRecord = await c.env.DB.prepare(
      `SELECT a.member_id, a.password_hash, m.name, m.email, m.role
       FROM auth a JOIN members m ON a.member_id = m.id
       WHERE m.email = ? AND m.is_active = 1`
    ).bind(email).first<{ member_id: number; password_hash: string; name: string; email: string; role: string }>();

    if (!authRecord || !(await verifyPassword(password, authRecord.password_hash))) {
      return c.json({ error: 'Invalid credentials' }, 401);
    }

    const token = await sign(
      { sub: authRecord.member_id, email: authRecord.email, role: authRecord.role },
      c.env.JWT_SECRET
    );

    return c.json({
      token,
      user: {
        id: authRecord.member_id,
        name: authRecord.name,
        email: authRecord.email,
        role: authRecord.role
      }
    });
  } catch (e) {
    return c.json({ error: 'Login failed' }, 500);
  }
});

async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const saltHex = Array.from(salt).map(b => b.toString(16).padStart(2, '0')).join('');

  const keyMaterial = await crypto.subtle.importKey(
    'raw', encoder.encode(password), { name: 'PBKDF2' }, false, ['deriveBits']
  );

  const derivedBits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
    keyMaterial, 256
  );

  const hashHex = Array.from(new Uint8Array(derivedBits)).map(b => b.toString(16).padStart(2, '0')).join('');
  return `${saltHex}:${hashHex}`;
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [saltHex, hashHex] = stored.split(':');
  if (!saltHex || !hashHex) return false;

  const salt = new Uint8Array(saltHex.match(/.{2}/g)!.map(b => parseInt(b, 16)));

  const encoder = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    'raw', encoder.encode(password), { name: 'PBKDF2' }, false, ['deriveBits']
  );

  const derivedBits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
    keyMaterial, 256
  );

  const computedHex = Array.from(new Uint8Array(derivedBits)).map(b => b.toString(16).padStart(2, '0')).join('');
  return computedHex === hashHex;
}
