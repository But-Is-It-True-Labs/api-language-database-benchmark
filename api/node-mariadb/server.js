import Fastify from 'fastify';
import mysql from 'mysql2/promise';

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) throw new Error('DATABASE_URL is required');

const u = new URL(DATABASE_URL);
const pool = mysql.createPool({
  host: u.hostname,
  port: Number(u.port || 3306),
  user: decodeURIComponent(u.username),
  password: decodeURIComponent(u.password),
  database: u.pathname.replace(/^\//, ''),
  waitForConnections: true,
  connectionLimit: 50,
  maxIdle: 50,
  idleTimeout: 300000,
  enableKeepAlive: true,
  dateStrings: true
});

const app = Fastify({ logger: false });

function parentRow(row) {
  return { id: Number(row.id), account_number: Number(row.account_number), status: row.status, created_at: row.created_at, payload: row.payload };
}
function childRow(row) {
  return { id: Number(row.id), parent_id: Number(row.parent_id), sequence_number: Number(row.sequence_number), value_number: Number(row.value_number), payload: row.payload };
}
function eventRow(row) {
  return { id: Number(row.id), parent_id: Number(row.parent_id), event_type: row.event_type, event_time: row.event_time, payload: row.payload };
}

app.get('/health', async (request, reply) => {
  try { await pool.query('SELECT 1'); return { status: 'ok' }; }
  catch { return reply.code(503).send({ status: 'database unavailable' }); }
});

app.get('/parent/:id', async (request, reply) => {
  const id = Number(request.params.id);
  if (!Number.isInteger(id)) return reply.code(400).send('invalid parent id');
  const [rows] = await pool.execute(
    'SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE id = ?',
    [id]
  );
  if (rows.length === 0) return reply.code(404).send('parent not found');
  return parentRow(rows[0]);
});

app.get('/parent/:id/children', async (request, reply) => {
  const id = Number(request.params.id);
  if (!Number.isInteger(id)) return reply.code(400).send('invalid parent id');
  const [rows] = await pool.execute(
    'SELECT id, parent_id, sequence_number, value_number, payload FROM benchmark_child WHERE parent_id = ? ORDER BY id',
    [id]
  );
  return rows.map(childRow);
});

app.get('/parent/:id/events', async (request, reply) => {
  const id = Number(request.params.id);
  if (!Number.isInteger(id)) return reply.code(400).send('invalid parent id');
  const [rows] = await pool.execute(
    'SELECT id, parent_id, event_type, event_time, payload FROM benchmark_event WHERE parent_id = ? ORDER BY event_time DESC, id DESC LIMIT 20',
    [id]
  );
  return rows.map(eventRow);
});

app.get('/parent/:id/bundle', async (request, reply) => {
  const id = Number(request.params.id);
  if (!Number.isInteger(id)) return reply.code(400).send('invalid parent id');
  const conn = await pool.getConnection();
  try {
    const [parents] = await conn.execute('SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE id = ?', [id]);
    if (parents.length === 0) return reply.code(404).send('parent not found');
    const [children] = await conn.execute('SELECT id, parent_id, sequence_number, value_number, payload FROM benchmark_child WHERE parent_id = ? ORDER BY id', [id]);
    const [events] = await conn.execute('SELECT id, parent_id, event_type, event_time, payload FROM benchmark_event WHERE parent_id = ? ORDER BY event_time DESC, id DESC LIMIT 20', [id]);
    return { parent: parentRow(parents[0]), children: children.map(childRow), events: events.map(eventRow) };
  } finally { conn.release(); }
});

app.get('/account/:id/parents', async (request, reply) => {
  const id = Number(request.params.id);
  if (!Number.isInteger(id)) return reply.code(400).send('invalid account id');
  const [rows] = await pool.execute(
    'SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE account_number = ? ORDER BY id LIMIT 50',
    [id]
  );
  return rows.map(parentRow);
});

app.post('/event', async (request, reply) => {
  const { id, parent_id, event_type, payload } = request.body ?? {};
  if (!Number.isInteger(id) || !Number.isInteger(parent_id) || typeof event_type !== 'string' || typeof payload !== 'string') {
    return reply.code(400).send('invalid json');
  }
  await pool.execute(
    'INSERT INTO benchmark_event (id, parent_id, event_type, event_time, payload) VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?)',
    [id, parent_id, event_type, payload]
  );
  return reply.code(201).send({ created: true, id });
});

app.setErrorHandler((error, request, reply) => { console.error(error); reply.code(500).send('internal server error'); });
const shutdown = async () => { try { await app.close(); await pool.end(); } finally { process.exit(0); } };
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

await app.listen({ host: '0.0.0.0', port: 8080 });
console.log('Node/Fastify MariaDB benchmark API listening on :8080');
