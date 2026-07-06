import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { jwt } from 'hono/jwt';
import { Env } from './types';
import { authRoutes } from './routes/auth';
import { memberRoutes } from './routes/members';
import { rehearsalRoutes } from './routes/rehearsals';
import { attendanceRoutes } from './routes/attendance';
import { reportRoutes } from './routes/reports';

const app = new Hono<{ Bindings: Env }>();

app.use('/*', cors({ origin: '*', credentials: true }));
app.use('/api/*', async (c, next) => {
  const publicPaths = ['/api/auth/login', '/api/auth/register', '/api/health'];
  if (publicPaths.some(p => c.req.path === p)) return next();
  return jwt({ secret: c.env.JWT_SECRET })(c, next);
});

app.get('/api/health', (c) => c.json({ status: 'ok', version: '1.0.0' }));

app.route('/api/auth', authRoutes);
app.route('/api/members', memberRoutes);
app.route('/api/rehearsals', rehearsalRoutes);
app.route('/api/attendance', attendanceRoutes);
app.route('/api/reports', reportRoutes);

export default app;
