<?php

declare(strict_types=1);

header('Content-Type: application/json');

function respond(mixed $data, int $status = 200): never
{
    http_response_code($status);

    echo json_encode(
        $data,
        JSON_UNESCAPED_SLASHES
    );

    exit;
}

function cassandraInt(mixed $value): int
{
    if (is_int($value)) {
        return $value;
    }

    if (
        is_object($value) &&
        method_exists($value, 'value')
    ) {
        return (int)$value->value();
    }

    return (int)$value;
}

function cassandraTimestamp(mixed $value): string
{
    if ($value instanceof DateTimeInterface) {
        return $value
            ->setTimezone(new DateTimeZone('UTC'))
            ->format('Y-m-d\TH:i:s.v\Z');
    }

    if (
        is_object($value) &&
        method_exists($value, 'toDateTime')
    ) {
        $date = $value->toDateTime();

        return $date
            ->setTimezone(new DateTimeZone('UTC'))
            ->format('Y-m-d\TH:i:s.v\Z');
    }

    if (
        is_object($value) &&
        method_exists($value, 'time')
    ) {
        return gmdate(
            'Y-m-d\TH:i:s\Z',
            (int)$value->time()
        );
    }

    return (string)$value;
}

$host = getenv('CASSANDRA_HOST');

if (!$host) {
    $host = 'benchmark_cassandra';
}

try {
    $cluster = Cassandra::cluster()
        ->withContactPoints($host)
        ->withPort(9042)
        ->withPersistentSessions(true)
        ->build();

    $session = $cluster->connect('benchmark');
} catch (Throwable $e) {
    http_response_code(503);

    echo json_encode([
        'error' => 'database unavailable',
    ]);

    exit;
}

$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url(
    $_SERVER['REQUEST_URI'],
    PHP_URL_PATH
);

if (
    $method === 'GET' &&
    $path === '/health'
) {
    try {
        $statement =
            new Cassandra\SimpleStatement(
                "
                SELECT release_version
                FROM system.local
                WHERE key = 'local'
                "
            );

        $session->execute(
            $statement,
            [
                'consistency' =>
                    Cassandra::CONSISTENCY_ONE,
            ]
        );

        respond([
            'status' => 'ok',
        ]);
    } catch (Throwable $e) {
        respond([
            'status' =>
                'database unavailable',
        ], 503);
    }
}

if (
    $method === 'GET' &&
    preg_match(
        '#^/parent/(\d+)$#',
        $path,
        $matches
    )
) {
    $id = (int)$matches[1];

    try {
        $statement =
            new Cassandra\SimpleStatement(
                '
                SELECT
                    id,
                    account_number,
                    status,
                    created_at,
                    payload
                FROM parent_by_id
                WHERE id = ?
                '
            );

        $rows = $session->execute(
            $statement,
            [
                'arguments' => [
                    new Cassandra\Bigint(
                        (string)$id
                    ),
                ],
                'consistency' =>
                    Cassandra::CONSISTENCY_ONE,
            ]
        );

        $row = $rows->first();

        if (!$row) {
            respond([
                'error' =>
                    'parent not found',
            ], 404);
        }

        respond([
            'id' =>
                cassandraInt(
                    $row['id']
                ),

            'account_number' =>
                cassandraInt(
                    $row['account_number']
                ),

            'status' =>
                $row['status'],

            'created_at' =>
                cassandraTimestamp(
                    $row['created_at']
                ),

            'payload' =>
                $row['payload'],
        ]);

    } catch (Throwable $e) {
        error_log(
            'Cassandra query error: ' .
            $e->getMessage()
        );

        respond([
            'error' => 'query failed',
        ], 500);
    }
}

respond([
    'error' => 'not found',
], 404);
