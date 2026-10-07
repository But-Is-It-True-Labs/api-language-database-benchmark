import Fastify from 'fastify';
import cassandra from 'cassandra-driver';

const {
    Client,
    types
} = cassandra;

const CASSANDRA_HOST =
    process.env.CASSANDRA_HOST || 'benchmark_cassandra';

const consistency =
    types.consistencies.one;

const client = new Client({
    contactPoints: [CASSANDRA_HOST],
    localDataCenter: 'datacenter1',
    keyspace: 'benchmark',
    queryOptions: {
        consistency
    }
});

const app = Fastify({
    logger: false
});


function numberFromBigInt(value) {
    if (
        value !== null &&
        value !== undefined &&
        typeof value.toNumber === 'function'
    ) {
        return value.toNumber();
    }

    return Number(value);
}


function normalizeTimestamp(value) {
    if (value instanceof Date) {
        return value.toISOString().replace('.000Z', 'Z');
    }

    return value;
}


function parentRow(row) {
    return {
        id: numberFromBigInt(row.id),
        account_number: numberFromBigInt(row.account_number),
        status: row.status,
        created_at: normalizeTimestamp(row.created_at),
        payload: row.payload
    };
}


app.get('/health', async (request, reply) => {
    try {
        await client.execute(
            `
            SELECT release_version
            FROM system.local
            WHERE key = 'local'
            `,
            [],
            {
                consistency
            }
        );

        return {
            status: 'ok'
        };

    } catch (error) {
        console.error(error);

        return reply
            .code(503)
            .send({
                status: 'database unavailable'
            });
    }
});


app.get('/parent/:id', async (request, reply) => {
    const id = Number(request.params.id);

    if (!Number.isSafeInteger(id)) {
        return reply
            .code(400)
            .send('invalid parent id');
    }

    const result = await client.execute(
        `
        SELECT id, account_number, status, created_at, payload
        FROM parent_by_id
        WHERE id = ?
        `,
        [
            types.Long.fromNumber(id)
        ],
        {
            prepare: true,
            consistency
        }
    );

    if (result.rowLength === 0) {
        return reply
            .code(404)
            .send('parent not found');
    }

    return parentRow(result.first());
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
        await client.shutdown();
    } finally {
        process.exit(0);
    }
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);


await client.connect();

await app.listen({
    host: '0.0.0.0',
    port: 8080
});

console.log(
    'Node/Fastify Cassandra benchmark API listening on :8080'
);
