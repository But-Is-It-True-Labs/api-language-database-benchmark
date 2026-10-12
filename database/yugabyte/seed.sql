-- Generated from database/postgres/01-init.sql
-- INSERT batches contain at most 5000 records.

CREATE TABLE benchmark_parent (
    id BIGINT PRIMARY KEY,
    account_number BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    payload TEXT NOT NULL
);

CREATE INDEX idx_benchmark_parent_account
    ON benchmark_parent(account_number);

CREATE INDEX idx_benchmark_parent_status
    ON benchmark_parent(status);

CREATE TABLE benchmark_child (
    id BIGINT PRIMARY KEY,
    parent_id BIGINT NOT NULL REFERENCES benchmark_parent(id),
    sequence_number INTEGER NOT NULL,
    value_number INTEGER NOT NULL,
    payload TEXT NOT NULL
);

CREATE INDEX idx_benchmark_child_parent
    ON benchmark_child(parent_id);

CREATE TABLE benchmark_event (
    id BIGINT PRIMARY KEY,
    parent_id BIGINT NOT NULL REFERENCES benchmark_parent(id),
    event_type VARCHAR(20) NOT NULL,
    event_time TIMESTAMP NOT NULL,
    payload TEXT NOT NULL
);

CREATE INDEX idx_benchmark_event_parent
    ON benchmark_event(parent_id);

INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(1, 5000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(5001, 10000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(10001, 15000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(15001, 20000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(20001, 25000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(25001, 30000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(30001, 35000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(35001, 40000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(40001, 45000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(45001, 50000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(50001, 55000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(55001, 60000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(60001, 65000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(65001, 70000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(70001, 75000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(75001, 80000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(80001, 85000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(85001, 90000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(90001, 95000) AS n;
INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(95001, 100000) AS n;


INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(1, 5000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(5001, 10000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(10001, 15000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(15001, 20000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(20001, 25000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(25001, 30000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(30001, 35000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(35001, 40000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(40001, 45000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(45001, 50000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(50001, 55000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(55001, 60000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(60001, 65000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(65001, 70000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(70001, 75000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(75001, 80000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(80001, 85000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(85001, 90000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(90001, 95000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(95001, 100000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(100001, 105000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(105001, 110000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(110001, 115000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(115001, 120000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(120001, 125000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(125001, 130000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(130001, 135000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(135001, 140000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(140001, 145000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(145001, 150000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(150001, 155000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(155001, 160000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(160001, 165000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(165001, 170000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(170001, 175000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(175001, 180000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(180001, 185000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(185001, 190000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(190001, 195000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(195001, 200000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(200001, 205000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(205001, 210000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(210001, 215000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(215001, 220000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(220001, 225000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(225001, 230000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(230001, 235000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(235001, 240000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(240001, 245000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(245001, 250000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(250001, 255000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(255001, 260000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(260001, 265000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(265001, 270000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(270001, 275000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(275001, 280000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(280001, 285000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(285001, 290000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(290001, 295000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(295001, 300000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(300001, 305000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(305001, 310000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(310001, 315000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(315001, 320000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(320001, 325000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(325001, 330000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(330001, 335000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(335001, 340000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(340001, 345000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(345001, 350000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(350001, 355000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(355001, 360000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(360001, 365000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(365001, 370000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(370001, 375000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(375001, 380000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(380001, 385000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(385001, 390000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(390001, 395000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(395001, 400000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(400001, 405000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(405001, 410000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(410001, 415000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(415001, 420000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(420001, 425000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(425001, 430000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(430001, 435000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(435001, 440000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(440001, 445000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(445001, 450000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(450001, 455000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(455001, 460000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(460001, 465000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(465001, 470000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(470001, 475000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(475001, 480000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(480001, 485000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(485001, 490000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(490001, 495000) AS n;
INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(495001, 500000) AS n;


INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(1, 5000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(5001, 10000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(10001, 15000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(15001, 20000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(20001, 25000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(25001, 30000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(30001, 35000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(35001, 40000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(40001, 45000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(45001, 50000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(50001, 55000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(55001, 60000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(60001, 65000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(65001, 70000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(70001, 75000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(75001, 80000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(80001, 85000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(85001, 90000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(90001, 95000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(95001, 100000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(100001, 105000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(105001, 110000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(110001, 115000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(115001, 120000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(120001, 125000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(125001, 130000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(130001, 135000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(135001, 140000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(140001, 145000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(145001, 150000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(150001, 155000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(155001, 160000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(160001, 165000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(165001, 170000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(170001, 175000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(175001, 180000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(180001, 185000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(185001, 190000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(190001, 195000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(195001, 200000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(200001, 205000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(205001, 210000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(210001, 215000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(215001, 220000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(220001, 225000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(225001, 230000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(230001, 235000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(235001, 240000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(240001, 245000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(245001, 250000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(250001, 255000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(255001, 260000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(260001, 265000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(265001, 270000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(270001, 275000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(275001, 280000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(280001, 285000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(285001, 290000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(290001, 295000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(295001, 300000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(300001, 305000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(305001, 310000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(310001, 315000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(315001, 320000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(320001, 325000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(325001, 330000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(330001, 335000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(335001, 340000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(340001, 345000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(345001, 350000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(350001, 355000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(355001, 360000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(360001, 365000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(365001, 370000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(370001, 375000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(375001, 380000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(380001, 385000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(385001, 390000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(390001, 395000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(395001, 400000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(400001, 405000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(405001, 410000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(410001, 415000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(415001, 420000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(420001, 425000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(425001, 430000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(430001, 435000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(435001, 440000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(440001, 445000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(445001, 450000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(450001, 455000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(455001, 460000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(460001, 465000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(465001, 470000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(470001, 475000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(475001, 480000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(480001, 485000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(485001, 490000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(490001, 495000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(495001, 500000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(500001, 505000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(505001, 510000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(510001, 515000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(515001, 520000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(520001, 525000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(525001, 530000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(530001, 535000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(535001, 540000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(540001, 545000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(545001, 550000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(550001, 555000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(555001, 560000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(560001, 565000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(565001, 570000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(570001, 575000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(575001, 580000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(580001, 585000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(585001, 590000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(590001, 595000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(595001, 600000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(600001, 605000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(605001, 610000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(610001, 615000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(615001, 620000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(620001, 625000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(625001, 630000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(630001, 635000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(635001, 640000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(640001, 645000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(645001, 650000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(650001, 655000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(655001, 660000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(660001, 665000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(665001, 670000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(670001, 675000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(675001, 680000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(680001, 685000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(685001, 690000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(690001, 695000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(695001, 700000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(700001, 705000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(705001, 710000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(710001, 715000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(715001, 720000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(720001, 725000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(725001, 730000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(730001, 735000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(735001, 740000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(740001, 745000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(745001, 750000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(750001, 755000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(755001, 760000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(760001, 765000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(765001, 770000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(770001, 775000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(775001, 780000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(780001, 785000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(785001, 790000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(790001, 795000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(795001, 800000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(800001, 805000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(805001, 810000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(810001, 815000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(815001, 820000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(820001, 825000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(825001, 830000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(830001, 835000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(835001, 840000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(840001, 845000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(845001, 850000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(850001, 855000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(855001, 860000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(860001, 865000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(865001, 870000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(870001, 875000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(875001, 880000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(880001, 885000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(885001, 890000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(890001, 895000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(895001, 900000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(900001, 905000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(905001, 910000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(910001, 915000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(915001, 920000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(920001, 925000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(925001, 930000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(930001, 935000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(935001, 940000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(940001, 945000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(945001, 950000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(950001, 955000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(955001, 960000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(960001, 965000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(965001, 970000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(970001, 975000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(975001, 980000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(980001, 985000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(985001, 990000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(990001, 995000) AS n;
INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(995001, 1000000) AS n;


ANALYZE;
