import Fastify from 'fastify';
import pg from 'pg';

const { Pool, types } = pg;

/*
 * PostgreSQL BIGINT normally comes back as a string.
 * Our benchmark IDs are safely inside JavaScript's integer range,
 * so normalize BIGINT to Number to match the other APIs.
 */
types.setTypeParser(20, value => Number(value));

const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
    throw new Error('DATABASE_URL is required');
}

const pool = new Pool({
    connectionString: DATABASE_URL,
    max: 50,
    idleTimeoutMillis: 300000,
    connectionTimeoutMillis: 10000
});

const app = Fastify({
    logger: false
});


function normalizeTimestamp(value) {
    if (value instanceof Date) {
        return value.toISOString().replace('.000Z', 'Z');
    }

    return value;
}


function parentRow(row) {
    return {
        id: row.id,
        account_number: row.account_number,
        status: row.status,
        created_at: normalizeTimestamp(row.created_at),
        payload: row.payload
    };
}


function childRow(row) {
    return {
        id: row.id,
        parent_id: row.parent_id,
        sequence_number: row.sequence_number,
        value_number: row.value_number,
        payload: row.payload
    };
}


function eventRow(row) {
    return {
        id: row.id,
        parent_id: row.parent_id,
        event_type: row.event_type,
        event_time: normalizeTimestamp(row.event_time),
        payload: row.payload
    };
}


app.get('/health', async (request, reply) => {
    try {
        await pool.query('SELECT 1');

        return {
            status: 'ok'
        };
    } catch {
        return reply
            .code(503)
            .send({
                status: 'database unavailable'
            });
    }
});


app.get('/parent/:id', async (request, reply) => {
    const id = Number(request.params.id);

    if (!Number.isInteger(id)) {
        return reply
            .code(400)
            .send('invalid parent id');
    }

    const result = await pool.query(
        `
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE id = $1
        `,
        [id]
    );

    if (result.rowCount === 0) {
        return reply
            .code(404)
            .send('parent not found');
    }

    return parentRow(result.rows[0]);
});


app.get('/parent/:id/children', async (request, reply) => {
    const id = Number(request.params.id);

    if (!Number.isInteger(id)) {
        return reply
            .code(400)
            .send('invalid parent id');
    }

    const result = await pool.query(
        `
        SELECT id, parent_id, sequence_number, value_number, payload
        FROM benchmark_child
        WHERE parent_id = $1
        ORDER BY id
        `,
        [id]
    );

    return result.rows.map(childRow);
});


app.get('/parent/:id/events', async (request, reply) => {
    const id = Number(request.params.id);

    if (!Number.isInteger(id)) {
        return reply
            .code(400)
            .send('invalid parent id');
    }

    const result = await pool.query(
        `
        SELECT id, parent_id, event_type, event_time, payload
        FROM benchmark_event
        WHERE parent_id = $1
        ORDER BY event_time DESC, id DESC
        LIMIT 20
        `,
        [id]
    );

    return result.rows.map(eventRow);
});


app.get('/parent/:id/bundle', async (request, reply) => {
    const id = Number(request.params.id);

    if (!Number.isInteger(id)) {
        return reply
            .code(400)
            .send('invalid parent id');
    }

    const client = await pool.connect();

    try {
        const parentResult = await client.query(
            `
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE id = $1
            `,
            [id]
        );

        if (parentResult.rowCount === 0) {
            return reply
                .code(404)
                .send('parent not found');
        }

        const childResult = await client.query(
            `
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = $1
            ORDER BY id
            `,
            [id]
        );

        const eventResult = await client.query(
            `
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = $1
            ORDER BY event_time DESC, id DESC
            LIMIT 20
            `,
            [id]
        );

        return {
            parent: parentRow(parentResult.rows[0]),
            children: childResult.rows.map(childRow),
            events: eventResult.rows.map(eventRow)
        };

    } finally {
        client.release();
    }
});


app.get('/account/:id/parents', async (request, reply) => {
    const id = Number(request.params.id);

    if (!Number.isInteger(id)) {
        return reply
            .code(400)
            .send('invalid account id');
    }

    const result = await pool.query(
        `
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE account_number = $1
        ORDER BY id
        LIMIT 50
        `,
        [id]
    );

    return result.rows.map(parentRow);
});


app.post('/event', async (request, reply) => {
    const {
        id,
        parent_id,
        event_type,
        payload
    } = request.body ?? {};

    if (
        !Number.isInteger(id) ||
        !Number.isInteger(parent_id) ||
        typeof event_type !== 'string' ||
        typeof payload !== 'string'
    ) {
        return reply
            .code(400)
            .send('invalid json');
    }

    await pool.query(
        `
        INSERT INTO benchmark_event
        (id, parent_id, event_type, event_time, payload)
        VALUES ($1, $2, $3, CURRENT_TIMESTAMP, $4)
        `,
        [
            id,
            parent_id,
            event_type,
            payload
        ]
    );

    return reply
        .code(201)
        .send({
            created: true,
            id
        });
});


app.setErrorHandler((error, request, reply) => {
    console.error(error);

    reply
        .code(500)
        .send('internal server error');
});


const shutdown = async () => {
    try {
        await app.close();
        await pool.end();
    } finally {
        process.exit(0);
    }
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);


await app.listen({
    host: '0.0.0.0',
    port: 8080
});

console.log('Node/Fastify benchmark API listening on :8080');
