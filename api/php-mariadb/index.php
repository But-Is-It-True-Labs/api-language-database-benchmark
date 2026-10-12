<?php

declare(strict_types=1);

header('Content-Type: application/json');

$databaseUrl = getenv('DATABASE_URL');

if (!$databaseUrl) {
    http_response_code(500);
    echo json_encode(['error' => 'DATABASE_URL is required']);
    exit;
}

$parts = parse_url($databaseUrl);

if ($parts === false) {
    http_response_code(500);
    echo json_encode(['error' => 'invalid DATABASE_URL']);
    exit;
}

$host = $parts['host'] ?? '';
$port = $parts['port'] ?? 3306;
$user = $parts['user'] ?? '';
$pass = $parts['pass'] ?? '';
$db   = ltrim($parts['path'] ?? '', '/');

$dsn = "mysql:host={$host};port={$port};dbname={$db};charset=utf8mb4";

try {
    $pdo = new PDO(
        $dsn,
        $user,
        $pass,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_PERSISTENT => true,
        ]
    );
} catch (Throwable $e) {
    http_response_code(503);
    echo json_encode(['error' => 'database unavailable']);
    exit;
}


function respond(mixed $data, int $status = 200): never
{
    http_response_code($status);

    echo json_encode(
        $data,
        JSON_UNESCAPED_SLASHES
    );

    exit;
}


function parentRow(array $row): array
{
    return [
        'id' => (int)$row['id'],
        'account_number' => (int)$row['account_number'],
        'status' => $row['status'],
        'created_at' => $row['created_at'],
        'payload' => $row['payload'],
    ];
}


function childRow(array $row): array
{
    return [
        'id' => (int)$row['id'],
        'parent_id' => (int)$row['parent_id'],
        'sequence_number' => (int)$row['sequence_number'],
        'value_number' => (int)$row['value_number'],
        'payload' => $row['payload'],
    ];
}


function eventRow(array $row): array
{
    return [
        'id' => (int)$row['id'],
        'parent_id' => (int)$row['parent_id'],
        'event_type' => $row['event_type'],
        'event_time' => $row['event_time'],
        'payload' => $row['payload'],
    ];
}


$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);


if ($method === 'GET' && $path === '/health') {
    try {
        $pdo->query('SELECT 1');

        respond([
            'status' => 'ok',
        ]);
    } catch (Throwable $e) {
        respond([
            'status' => 'database unavailable',
        ], 503);
    }
}


if (
    $method === 'GET' &&
    preg_match('#^/parent/(\d+)$#', $path, $matches)
) {
    $id = (int)$matches[1];

    $stmt = $pdo->prepare(
        '
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE id = :id
        '
    );

    $stmt->execute([
        ':id' => $id,
    ]);

    $row = $stmt->fetch();

    if (!$row) {
        respond([
            'error' => 'parent not found',
        ], 404);
    }

    respond(parentRow($row));
}


if (
    $method === 'GET' &&
    preg_match('#^/parent/(\d+)/children$#', $path, $matches)
) {
    $id = (int)$matches[1];

    $stmt = $pdo->prepare(
        '
        SELECT id, parent_id, sequence_number, value_number, payload
        FROM benchmark_child
        WHERE parent_id = :id
        ORDER BY id
        '
    );

    $stmt->execute([
        ':id' => $id,
    ]);

    $rows = [];

    while ($row = $stmt->fetch()) {
        $rows[] = childRow($row);
    }

    respond($rows);
}


if (
    $method === 'GET' &&
    preg_match('#^/parent/(\d+)/events$#', $path, $matches)
) {
    $id = (int)$matches[1];

    $stmt = $pdo->prepare(
        '
        SELECT id, parent_id, event_type, event_time, payload
        FROM benchmark_event
        WHERE parent_id = :id
        ORDER BY event_time DESC, id DESC
        LIMIT 20
        '
    );

    $stmt->execute([
        ':id' => $id,
    ]);

    $rows = [];

    while ($row = $stmt->fetch()) {
        $rows[] = eventRow($row);
    }

    respond($rows);
}


if (
    $method === 'GET' &&
    preg_match('#^/parent/(\d+)/bundle$#', $path, $matches)
) {
    $id = (int)$matches[1];

    $stmt = $pdo->prepare(
        '
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE id = :id
        '
    );

    $stmt->execute([
        ':id' => $id,
    ]);

    $parent = $stmt->fetch();

    if (!$parent) {
        respond([
            'error' => 'parent not found',
        ], 404);
    }

    $stmt = $pdo->prepare(
        '
        SELECT id, parent_id, sequence_number, value_number, payload
        FROM benchmark_child
        WHERE parent_id = :id
        ORDER BY id
        '
    );

    $stmt->execute([
        ':id' => $id,
    ]);

    $children = [];

    while ($row = $stmt->fetch()) {
        $children[] = childRow($row);
    }

    $stmt = $pdo->prepare(
        '
        SELECT id, parent_id, event_type, event_time, payload
        FROM benchmark_event
        WHERE parent_id = :id
        ORDER BY event_time DESC, id DESC
        LIMIT 20
        '
    );

    $stmt->execute([
        ':id' => $id,
    ]);

    $events = [];

    while ($row = $stmt->fetch()) {
        $events[] = eventRow($row);
    }

    respond([
        'parent' => parentRow($parent),
        'children' => $children,
        'events' => $events,
    ]);
}


if (
    $method === 'GET' &&
    preg_match('#^/account/(\d+)/parents$#', $path, $matches)
) {
    $id = (int)$matches[1];

    $stmt = $pdo->prepare(
        '
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE account_number = :id
        ORDER BY id
        LIMIT 50
        '
    );

    $stmt->execute([
        ':id' => $id,
    ]);

    $rows = [];

    while ($row = $stmt->fetch()) {
        $rows[] = parentRow($row);
    }

    respond($rows);
}


if ($method === 'POST' && $path === '/event') {
    $body = json_decode(
        file_get_contents('php://input'),
        true
    );

    if (
        !is_array($body) ||
        !isset(
            $body['id'],
            $body['parent_id'],
            $body['event_type'],
            $body['payload']
        )
    ) {
        respond([
            'error' => 'invalid json',
        ], 400);
    }

    $stmt = $pdo->prepare(
        '
        INSERT INTO benchmark_event
        (id, parent_id, event_type, event_time, payload)
        VALUES
        (:id, :parent_id, :event_type, CURRENT_TIMESTAMP, :payload)
        '
    );

    $stmt->execute([
        ':id' => (int)$body['id'],
        ':parent_id' => (int)$body['parent_id'],
        ':event_type' => (string)$body['event_type'],
        ':payload' => (string)$body['payload'],
    ]);

    respond([
        'created' => true,
        'id' => (int)$body['id'],
    ], 201);
}


respond([
    'error' => 'not found',
], 404);
