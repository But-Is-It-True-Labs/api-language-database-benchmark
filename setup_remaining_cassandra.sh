#!/usr/bin/env bash
set -euo pipefail

cd "${1:-$HOME/development/api-benchmark}"

mkdir -p \
  api/nim-cassandra \
  api/v-cassandra \
  api/zig-cassandra/src \
  api/haskell-cassandra

cat > /tmp/cassandra_bridge.h <<'EOF'
#ifndef BENCHMARK_CASSANDRA_BRIDGE_H
#define BENCHMARK_CASSANDRA_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int bc_init(const char *host);
int bc_health(void);
int bc_get_parent(int64_t id);

int64_t bc_parent_id(void);
int64_t bc_parent_account_number(void);
const char *bc_parent_status(void);
const char *bc_parent_created_at(void);
const char *bc_parent_payload(void);

void bc_shutdown(void);

#ifdef __cplusplus
}
#endif

#endif
EOF

cat > /tmp/cassandra_bridge.c <<'EOF'
#include "cassandra_bridge.h"

#include <cassandra.h>

#include <stdio.h>
#include <string.h>
#include <time.h>

typedef struct {
    int64_t id;
    int64_t account_number;
    char status[128];
    char created_at[64];
    char payload[4096];
} BcParent;

static CassCluster *cluster = NULL;
static CassSession *session = NULL;
static const CassPrepared *parent_prepared = NULL;
static const CassPrepared *health_prepared = NULL;

static _Thread_local BcParent tls_parent;

static int future_ok(CassFuture *future) {
    cass_future_wait(future);

    if (cass_future_error_code(future) != CASS_OK) {
        const char *message = NULL;
        size_t message_len = 0;

        cass_future_error_message(
            future,
            &message,
            &message_len
        );

        if (message != NULL && message_len > 0) {
            fprintf(
                stderr,
                "Cassandra error: %.*s\n",
                (int)message_len,
                message
            );
        }

        return 0;
    }

    return 1;
}

static int copy_text(
    const CassRow *row,
    const char *column,
    char *dest,
    size_t dest_size
) {
    const CassValue *value =
        cass_row_get_column_by_name(
            row,
            column
        );

    const char *src = NULL;
    size_t src_len = 0;

    if (
        value == NULL ||
        cass_value_is_null(value) ||
        cass_value_get_string(
            value,
            &src,
            &src_len
        ) != CASS_OK
    ) {
        return 0;
    }

    if (dest_size == 0) {
        return 0;
    }

    if (src_len >= dest_size) {
        src_len = dest_size - 1;
    }

    memcpy(
        dest,
        src,
        src_len
    );

    dest[src_len] = '\0';

    return 1;
}

static void timestamp_to_iso(
    int64_t milliseconds,
    char *dest,
    size_t dest_size
) {
    time_t seconds =
        (time_t)(milliseconds / 1000);

    int millis =
        (int)(milliseconds % 1000);

    if (millis < 0) {
        millis += 1000;
        --seconds;
    }

    struct tm utc_tm;

    gmtime_r(
        &seconds,
        &utc_tm
    );

    if (millis == 0) {
        strftime(
            dest,
            dest_size,
            "%Y-%m-%dT%H:%M:%SZ",
            &utc_tm
        );

        return;
    }

    char base[48];

    strftime(
        base,
        sizeof(base),
        "%Y-%m-%dT%H:%M:%S",
        &utc_tm
    );

    snprintf(
        dest,
        dest_size,
        "%s.%03dZ",
        base,
        millis
    );
}

static const CassPrepared *prepare_query(
    const char *query
) {
    CassFuture *future =
        cass_session_prepare(
            session,
            query
        );

    if (!future_ok(future)) {
        cass_future_free(future);
        return NULL;
    }

    const CassPrepared *prepared =
        cass_future_get_prepared(
            future
        );

    cass_future_free(future);

    return prepared;
}

int bc_init(const char *host) {
    cluster =
        cass_cluster_new();

    session =
        cass_session_new();

    if (
        cluster == NULL ||
        session == NULL
    ) {
        return -1;
    }

    if (
        cass_cluster_set_contact_points(
            cluster,
            host
        ) != CASS_OK
    ) {
        return -1;
    }

    cass_cluster_set_port(
        cluster,
        9042
    );

    CassFuture *connect_future =
        cass_session_connect_keyspace(
            session,
            cluster,
            "benchmark"
        );

    if (!future_ok(connect_future)) {
        cass_future_free(
            connect_future
        );

        return -1;
    }

    cass_future_free(
        connect_future
    );

    parent_prepared =
        prepare_query(
            "SELECT id, account_number, status, created_at, payload "
            "FROM parent_by_id "
            "WHERE id = ?"
        );

    health_prepared =
        prepare_query(
            "SELECT release_version "
            "FROM system.local"
        );

    if (
        parent_prepared == NULL ||
        health_prepared == NULL
    ) {
        return -1;
    }

    return 0;
}

int bc_health(void) {
    CassStatement *statement =
        cass_prepared_bind(
            health_prepared
        );

    if (statement == NULL) {
        return -1;
    }

    cass_statement_set_consistency(
        statement,
        CASS_CONSISTENCY_ONE
    );

    CassFuture *future =
        cass_session_execute(
            session,
            statement
        );

    cass_statement_free(
        statement
    );

    int ok =
        future_ok(
            future
        );

    cass_future_free(
        future
    );

    return ok ? 0 : -1;
}

int bc_get_parent(int64_t id) {
    CassStatement *statement =
        cass_prepared_bind(
            parent_prepared
        );

    if (statement == NULL) {
        return -1;
    }

    cass_statement_set_consistency(
        statement,
        CASS_CONSISTENCY_ONE
    );

    if (
        cass_statement_bind_int64(
            statement,
            0,
            (cass_int64_t)id
        ) != CASS_OK
    ) {
        cass_statement_free(
            statement
        );

        return -1;
    }

    CassFuture *future =
        cass_session_execute(
            session,
            statement
        );

    cass_statement_free(
        statement
    );

    if (!future_ok(future)) {
        cass_future_free(
            future
        );

        return -1;
    }

    const CassResult *result =
        cass_future_get_result(
            future
        );

    cass_future_free(
        future
    );

    if (result == NULL) {
        return -1;
    }

    const CassRow *row =
        cass_result_first_row(
            result
        );

    if (row == NULL) {
        cass_result_free(
            result
        );

        return 1;
    }

    memset(
        &tls_parent,
        0,
        sizeof(tls_parent)
    );

    const CassValue *id_value =
        cass_row_get_column_by_name(
            row,
            "id"
        );

    const CassValue *account_value =
        cass_row_get_column_by_name(
            row,
            "account_number"
        );

    const CassValue *created_value =
        cass_row_get_column_by_name(
            row,
            "created_at"
        );

    cass_int64_t parsed_id = 0;
    cass_int64_t parsed_account = 0;
    cass_int64_t parsed_created = 0;

    if (
        id_value == NULL ||
        account_value == NULL ||
        created_value == NULL ||
        cass_value_get_int64(
            id_value,
            &parsed_id
        ) != CASS_OK ||
        cass_value_get_int64(
            account_value,
            &parsed_account
        ) != CASS_OK ||
        cass_value_get_int64(
            created_value,
            &parsed_created
        ) != CASS_OK ||
        !copy_text(
            row,
            "status",
            tls_parent.status,
            sizeof(tls_parent.status)
        ) ||
        !copy_text(
            row,
            "payload",
            tls_parent.payload,
            sizeof(tls_parent.payload)
        )
    ) {
        cass_result_free(
            result
        );

        return -1;
    }

    tls_parent.id =
        (int64_t)parsed_id;

    tls_parent.account_number =
        (int64_t)parsed_account;

    timestamp_to_iso(
        (int64_t)parsed_created,
        tls_parent.created_at,
        sizeof(tls_parent.created_at)
    );

    cass_result_free(
        result
    );

    return 0;
}

int64_t bc_parent_id(void) {
    return tls_parent.id;
}

int64_t bc_parent_account_number(void) {
    return tls_parent.account_number;
}

const char *bc_parent_status(void) {
    return tls_parent.status;
}

const char *bc_parent_created_at(void) {
    return tls_parent.created_at;
}

const char *bc_parent_payload(void) {
    return tls_parent.payload;
}

void bc_shutdown(void) {
    if (parent_prepared != NULL) {
        cass_prepared_free(
            parent_prepared
        );

        parent_prepared = NULL;
    }

    if (health_prepared != NULL) {
        cass_prepared_free(
            health_prepared
        );

        health_prepared = NULL;
    }

    if (session != NULL) {
        CassFuture *close_future =
            cass_session_close(
                session
            );

        cass_future_wait(
            close_future
        );

        cass_future_free(
            close_future
        );

        cass_session_free(
            session
        );

        session = NULL;
    }

    if (cluster != NULL) {
        cass_cluster_free(
            cluster
        );

        cluster = NULL;
    }
}
EOF

for d in nim-cassandra v-cassandra zig-cassandra
do
  cp /tmp/cassandra_bridge.h "api/$d/cassandra_bridge.h"
  cp /tmp/cassandra_bridge.c "api/$d/cassandra_bridge.c"
done


###############################################################################
# NIM + CASSANDRA
###############################################################################

cat > api/nim-cassandra/main.nim <<'EOF'
import mummy
import mummy/routers

import std/json
import std/os
import std/strutils


const
  WorkerThreads = 50
  BridgeLib = "libbenchmark_cassandra_bridge.so"


proc bc_init(host: cstring): cint
  {.cdecl, importc, dynlib: BridgeLib.}

proc bc_health(): cint
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_get_parent(id: int64): cint
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_id(): int64
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_account_number(): int64
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_status(): cstring
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_created_at(): cstring
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}

proc bc_parent_payload(): cstring
  {.cdecl, importc, dynlib: BridgeLib, gcsafe.}


proc jsonHeaders(): HttpHeaders =
  result["Content-Type"] =
    "application/json"


proc healthHandler(
  request: Request
) {.gcsafe.} =
  if bc_health() == 0:
    request.respond(
      200,
      jsonHeaders(),
      """{"status":"ok"}"""
    )
  else:
    request.respond(
      503,
      jsonHeaders(),
      """{"status":"database unavailable"}"""
    )


proc parentHandler(
  request: Request
) {.gcsafe.} =
  const prefix =
    "/parent/"

  if not request.path.startsWith(
    prefix
  ):
    request.respond(
      404,
      jsonHeaders(),
      """{"error":"not found"}"""
    )

    return

  let idText =
    request.path[
      prefix.len .. ^1
    ]

  if idText.len == 0:
    request.respond(
      404,
      jsonHeaders(),
      """{"error":"parent not found"}"""
    )

    return

  var id: int64

  try:
    id =
      parseBiggestInt(
        idText
      ).int64

  except ValueError:
    request.respond(
      400,
      jsonHeaders(),
      """{"error":"invalid parent id"}"""
    )

    return

  let rc =
    bc_get_parent(
      id
    )

  if rc == 1:
    request.respond(
      404,
      jsonHeaders(),
      """{"error":"parent not found"}"""
    )

    return

  if rc != 0:
    request.respond(
      500,
      jsonHeaders(),
      """{"error":"query failed"}"""
    )

    return

  let body = %*{
    "id":
      bc_parent_id(),

    "account_number":
      bc_parent_account_number(),

    "status":
      $bc_parent_status(),

    "created_at":
      $bc_parent_created_at(),

    "payload":
      $bc_parent_payload()
  }

  request.respond(
    200,
    jsonHeaders(),
    $body
  )


let cassandraHost =
  getEnv(
    "CASSANDRA_HOST",
    "benchmark_cassandra"
  )

if bc_init(
    cassandraHost.cstring
  ) != 0:
  quit(
    "Unable to initialize Cassandra"
  )


var router: Router

router.get(
  "/health",
  healthHandler
)

router.get(
  "/parent/*",
  parentHandler
)


let server =
  newServer(
    router,
    workerThreads =
      WorkerThreads
  )


echo "Nim/Mummy Cassandra benchmark API listening on :8080"
echo "Worker threads: ", WorkerThreads


server.serve(
  Port(8080),
  "0.0.0.0"
)
EOF

cat > api/nim-cassandra/Dockerfile <<'EOF'
FROM nimlang/nim:2.2.4 AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       cmake \
       git \
       libuv1-dev \
       libssl-dev \
       zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone \
      --depth 1 \
      --branch 2.17.1 \
      https://github.com/apache/cassandra-cpp-driver.git \
      /tmp/cassandra-cpp-driver \
    && cmake \
      -S /tmp/cassandra-cpp-driver \
      -B /tmp/cassandra-cpp-driver/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=11 \
      -DCASS_BUILD_SHARED=ON \
      -DCASS_BUILD_STATIC=OFF \
      -DCASS_BUILD_EXAMPLES=OFF \
      -DCASS_BUILD_TESTS=OFF \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake \
      --build /tmp/cassandra-cpp-driver/build \
      --parallel \
    && cmake \
      --install /tmp/cassandra-cpp-driver/build \
    && ldconfig

RUN nimble install -y mummy

WORKDIR /src

COPY cassandra_bridge.h .
COPY cassandra_bridge.c .
COPY main.nim .

RUN cc \
      -O3 \
      -fPIC \
      -shared \
      cassandra_bridge.c \
      -I/usr/local/include \
      -L/usr/local/lib \
      -lcassandra \
      -Wl,-rpath,/usr/local/lib \
      -o /usr/local/lib/libbenchmark_cassandra_bridge.so \
    && ldconfig

RUN nim c \
    -d:release \
    --opt:speed \
    --threads:on \
    --mm:orc \
    --out:/out-benchmark-nim-cassandra-api \
    main.nim


FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       libuv1 \
       libssl3 \
       zlib1g \
       libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build \
    /usr/local/lib/libcassandra.so* \
    /usr/local/lib/

COPY --from=build \
    /usr/local/lib/libbenchmark_cassandra_bridge.so \
    /usr/local/lib/

RUN ldconfig

COPY --from=build \
    /out-benchmark-nim-cassandra-api \
    /usr/local/bin/benchmark-nim-cassandra-api

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-nim-cassandra-api"]
EOF


###############################################################################
# V + CASSANDRA
###############################################################################

cat > api/v-cassandra/main.v <<'EOF'
module main

import os
import strconv
import veb


#flag -I/usr/local/include
#flag -L/usr/local/lib
#flag -lbenchmark_cassandra_bridge

#include "cassandra_bridge.h"


fn C.bc_init(&char) int
fn C.bc_health() int
fn C.bc_get_parent(i64) int

fn C.bc_parent_id() i64
fn C.bc_parent_account_number() i64

fn C.bc_parent_status() &char
fn C.bc_parent_created_at() &char
fn C.bc_parent_payload() &char


pub struct Context {
	veb.Context
}


pub struct App {}


pub struct HealthResponse {
pub:
	status string
}


pub struct ErrorResponse {
pub:
	error string
}


pub struct ParentResponse {
pub:
	id             i64
	account_number i64
	status         string
	created_at     string
	payload        string
}


fn c_string(
	value &char
) string {
	return unsafe {
		cstring_to_vstring(
			value
		)
	}
}


@['/health']
pub fn (
	app &App
) health(
	mut ctx Context
) veb.Result {
	if C.bc_health() != 0 {
		return ctx.json(
			HealthResponse{
				status:
					'database unavailable'
			}
		)
	}

	return ctx.json(
		HealthResponse{
			status: 'ok'
		}
	)
}


@['/parent/:id']
pub fn (
	app &App
) parent(
	mut ctx Context,
	id string
) veb.Result {
	parent_id :=
		strconv.parse_int(
			id,
			10,
			64
		) or {
			return ctx.json(
				ErrorResponse{
					error:
						'invalid parent id'
				}
			)
		}

	rc :=
		C.bc_get_parent(
			parent_id
		)

	if rc == 1 {
		return ctx.json(
			ErrorResponse{
				error:
					'parent not found'
			}
		)
	}

	if rc != 0 {
		return ctx.json(
			ErrorResponse{
				error:
					'query failed'
			}
		)
	}

	return ctx.json(
		ParentResponse{
			id:
				C.bc_parent_id()

			account_number:
				C.bc_parent_account_number()

			status:
				c_string(
					C.bc_parent_status()
				)

			created_at:
				c_string(
					C.bc_parent_created_at()
				)

			payload:
				c_string(
					C.bc_parent_payload()
				)
		}
	)
}


fn main() {
	host_env :=
		os.getenv(
			'CASSANDRA_HOST'
		)

	host :=
		if host_env == '' {
			'benchmark_cassandra'
		} else {
			host_env
		}

	if C.bc_init(
		host.str
	) != 0 {
		panic(
			'Unable to initialize Cassandra'
		)
	}

	app :=
		&App{}

	println(
		'V Cassandra benchmark API listening on :8080'
	)

	mut server_app :=
		app

	veb.run_at[App, Context](
		mut server_app,
		family: .ip
		port: 8080
	) or {
		panic(
			err
		)
	}
}
EOF

cat > api/v-cassandra/Dockerfile <<'EOF'
FROM thevlang/vlang AS build

RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    linux-headers \
    libuv-dev \
    openssl-dev \
    zlib-dev \
    gc-dev

RUN git clone \
      --depth 1 \
      --branch 2.17.1 \
      https://github.com/apache/cassandra-cpp-driver.git \
      /tmp/cassandra-cpp-driver \
    && cmake \
      -S /tmp/cassandra-cpp-driver \
      -B /tmp/cassandra-cpp-driver/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=11 \
      -DCASS_BUILD_SHARED=ON \
      -DCASS_BUILD_STATIC=OFF \
      -DCASS_BUILD_EXAMPLES=OFF \
      -DCASS_BUILD_TESTS=OFF \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake \
      --build /tmp/cassandra-cpp-driver/build \
      --parallel \
    && cmake \
      --install /tmp/cassandra-cpp-driver/build

WORKDIR /src

COPY cassandra_bridge.h \
     /usr/local/include/cassandra_bridge.h

COPY cassandra_bridge.c .

RUN cc \
      -O3 \
      -fPIC \
      -shared \
      cassandra_bridge.c \
      -I/usr/local/include \
      -L/usr/local/lib \
      -lcassandra \
      -Wl,-rpath,/usr/local/lib \
      -o /usr/local/lib/libbenchmark_cassandra_bridge.so

COPY main.v .

RUN v \
    -d new_veb \
    -prod \
    -cc gcc \
    -o /out-benchmark-v-cassandra-api \
    main.v


FROM alpine:3.20

RUN apk add --no-cache \
    libuv \
    openssl \
    zlib \
    gc \
    libgcc \
    libstdc++

COPY --from=build \
    /usr/local/lib/libcassandra.so* \
    /usr/local/lib/

COPY --from=build \
    /usr/local/lib/libbenchmark_cassandra_bridge.so \
    /usr/local/lib/

COPY --from=build \
    /out-benchmark-v-cassandra-api \
    /usr/local/bin/benchmark-v-cassandra-api

ENV LD_LIBRARY_PATH=/usr/local/lib

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-v-cassandra-api"]
EOF


###############################################################################
# ZIG + CASSANDRA
###############################################################################

cat > api/zig-cassandra/src/main.zig <<'EOF'
const std = @import("std");
const zap = @import("zap");

const c = @cImport({
    @cInclude("cassandra_bridge.h");
});


fn send500(
    r: zap.Request,
) void {
    r.setStatus(
        .internal_server_error,
    );

    r.sendJson(
        \\{"error":"query failed"}
    ) catch {};
}


fn send404(
    r: zap.Request,
) void {
    r.setStatus(
        .not_found,
    );

    r.sendJson(
        \\{"error":"parent not found"}
    ) catch {};
}


fn cSpan(
    ptr: [*c]const u8,
) []const u8 {
    return std.mem.span(
        @as(
            [*:0]const u8,
            @ptrCast(ptr),
        ),
    );
}


fn health(
    r: zap.Request,
) void {
    if (
        c.bc_health() != 0
    ) {
        r.setStatus(
            .service_unavailable,
        );

        r.sendJson(
            \\{"status":"database unavailable"}
        ) catch {};

        return;
    }

    r.sendJson(
        \\{"status":"ok"}
    ) catch {};
}


fn parent(
    r: zap.Request,
    id_text: []const u8,
) void {
    const id =
        std.fmt.parseInt(
            i64,
            id_text,
            10,
        ) catch {
            r.setStatus(
                .bad_request,
            );

            r.sendJson(
                \\{"error":"invalid parent id"}
            ) catch {};

            return;
        };

    const rc =
        c.bc_get_parent(
            id,
        );

    if (rc == 1) {
        send404(r);
        return;
    }

    if (rc != 0) {
        send500(r);
        return;
    }

    const status =
        cSpan(
            c.bc_parent_status(),
        );

    const created_at =
        cSpan(
            c.bc_parent_created_at(),
        );

    const payload =
        cSpan(
            c.bc_parent_payload(),
        );

    var json_buffer:
        [8192]u8 =
        undefined;

    const body =
        std.fmt.bufPrint(
            &json_buffer,
            "{{\"id\":{d},\"account_number\":{d},\"status\":\"{s}\",\"created_at\":\"{s}\",\"payload\":\"{s}\"}}",
            .{
                c.bc_parent_id(),
                c.bc_parent_account_number(),
                status,
                created_at,
                payload,
            },
        ) catch {
            send500(r);
            return;
        };

    r.sendJson(
        body,
    ) catch {};
}


fn onRequest(
    r: zap.Request,
) !void {
    const path =
        r.path orelse {
            r.setStatus(
                .not_found,
            );

            r.sendJson(
                \\{"error":"not found"}
            ) catch {};

            return;
        };

    if (
        std.mem.eql(
            u8,
            path,
            "/health",
        )
    ) {
        health(r);
        return;
    }

    const prefix =
        "/parent/";

    if (
        std.mem.startsWith(
            u8,
            path,
            prefix,
        )
    ) {
        const id_text =
            path[
                prefix.len..
            ];

        if (
            id_text.len == 0 or
            std.mem.indexOfScalar(
                u8,
                id_text,
                '/',
            ) != null
        ) {
            send404(r);
            return;
        }

        parent(
            r,
            id_text,
        );

        return;
    }

    r.setStatus(
        .not_found,
    );

    r.sendJson(
        \\{"error":"not found"}
    ) catch {};
}


fn env(
    map:
        *const std.process.Environ.Map,
    key:
        []const u8,
    fallback:
        []const u8,
) []const u8 {
    return map.get(
        key,
    ) orelse fallback;
}


pub fn main(
    init: std.process.Init,
) !void {
    const host =
        env(
            init.environ_map,
            "CASSANDRA_HOST",
            "benchmark_cassandra",
        );

    const host_z =
        try std.heap.smp_allocator.dupeZ(
            u8,
            host,
        );

    defer std.heap.smp_allocator.free(
        host_z,
    );

    if (
        c.bc_init(
            host_z.ptr,
        ) != 0
    ) {
        return error.CassandraInitFailed;
    }

    var listener =
        zap.HttpListener.init(
            .{
                .port = 8080,
                .on_request = onRequest,
                .log = false,
                .max_clients = 100000,
            },
        );

    try listener.listen();

    std.debug.print(
        "Zig/Zap Cassandra benchmark API listening on :8080\n",
        .{},
    );

    zap.start(
        .{
            .threads = 50,
            .workers = 1,
        },
    );
}
EOF

cat > api/zig-cassandra/build.zig <<'EOF'
const std = @import("std");

pub fn build(
    b: *std.Build,
) void {
    const target =
        b.standardTargetOptions(
            .{},
        );

    const optimize =
        b.standardOptimizeOption(
            .{},
        );

    const zap_dep =
        b.dependency(
            "zap",
            .{
                .target = target,
                .optimize = optimize,
                .openssl = false,
            },
        );

    const exe =
        b.addExecutable(
            .{
                .name =
                    "benchmark-zig-cassandra-api",

                .root_module =
                    b.createModule(
                        .{
                            .root_source_file =
                                b.path(
                                    "src/main.zig",
                                ),

                            .target =
                                target,

                            .optimize =
                                optimize,

                            .imports =
                                &.{
                                    .{
                                        .name =
                                            "zap",

                                        .module =
                                            zap_dep.module(
                                                "zap",
                                            ),
                                    },
                                },
                        },
                    ),
            },
        );

    exe.root_module.addIncludePath(
        .{
            .cwd_relative =
                "/usr/local/include",
        },
    );

    exe.root_module.addLibraryPath(
        .{
            .cwd_relative =
                "/usr/local/lib",
        },
    );

    exe.root_module.linkSystemLibrary(
        "benchmark_cassandra_bridge",
        .{},
    );

    exe.root_module.link_libc =
        true;

    b.installArtifact(
        exe,
    );
}
EOF

cat > api/zig-cassandra/build.zig.zon <<'EOF'
.{
    .name = .app,

    .version =
        "0.0.0",

    .fingerprint =
        0xc96e70cf21d19483,

    .minimum_zig_version =
        "0.16.0",

    .dependencies = .{
        .zap = .{
            .url =
                "git+https://github.com/zigzap/zap?ref=master#b12c07dd8cbbbacb2aa52790fb87fb2af185023f",

            .hash =
                "zap-0.10.6-GoeB8y-IJAD3m9zkAkeTQalzU1NuvO072u8hA78Irdp8",
        },
    },

    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
EOF

cat > api/zig-cassandra/Dockerfile <<'EOF'
FROM kassany/alpine-ziglang:0.16.0 AS build

USER root

RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    linux-headers \
    libuv-dev \
    openssl-dev \
    zlib-dev

RUN git clone \
      --depth 1 \
      --branch 2.17.1 \
      https://github.com/apache/cassandra-cpp-driver.git \
      /tmp/cassandra-cpp-driver \
    && cmake \
      -S /tmp/cassandra-cpp-driver \
      -B /tmp/cassandra-cpp-driver/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=11 \
      -DCASS_BUILD_SHARED=ON \
      -DCASS_BUILD_STATIC=OFF \
      -DCASS_BUILD_EXAMPLES=OFF \
      -DCASS_BUILD_TESTS=OFF \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake \
      --build /tmp/cassandra-cpp-driver/build \
      --parallel \
    && cmake \
      --install /tmp/cassandra-cpp-driver/build

WORKDIR /src

COPY cassandra_bridge.h \
     /usr/local/include/cassandra_bridge.h

COPY cassandra_bridge.c .

RUN cc \
      -O3 \
      -fPIC \
      -shared \
      cassandra_bridge.c \
      -I/usr/local/include \
      -L/usr/local/lib \
      -lcassandra \
      -Wl,-rpath,/usr/local/lib \
      -o /usr/local/lib/libbenchmark_cassandra_bridge.so

COPY build.zig .
COPY build.zig.zon .
COPY src ./src

RUN zig build --fetch

RUN zig build \
    -Doptimize=ReleaseFast


FROM alpine:3.20

RUN apk add --no-cache \
    libuv \
    openssl \
    zlib \
    libgcc \
    libstdc++

COPY --from=build \
    /usr/local/lib/libcassandra.so* \
    /usr/local/lib/

COPY --from=build \
    /usr/local/lib/libbenchmark_cassandra_bridge.so \
    /usr/local/lib/

COPY --from=build \
    /src/zig-out/bin/benchmark-zig-cassandra-api \
    /usr/local/bin/benchmark-zig-cassandra-api

ENV LD_LIBRARY_PATH=/usr/local/lib

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/benchmark-zig-cassandra-api"]
EOF


###############################################################################
# HASKELL + CASSANDRA
###############################################################################

cat > api/haskell-cassandra/Main.hs <<'EOF'
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Exception
    ( SomeException
    , try
    )

import Control.Monad.Identity
    ( Identity (..)
    )

import Control.Monad.IO.Class
    ( liftIO
    )

import Data.Aeson
import Data.Int
import Data.Text
    ( Text
    )

import Data.Time
    ( UTCTime
    )

import Database.CQL.IO
    as Client

import Network.HTTP.Types.Status
import System.Environment
    ( lookupEnv
    )

import Web.Scotty


type ParentRow =
    ( Int64
    , Int64
    , Text
    , UTCTime
    , Text
    )


parentQuery
    :: PrepQuery
        R
        (Identity Int64)
        ParentRow

parentQuery =
    "SELECT id, account_number, status, created_at, payload \
    \FROM benchmark.parent_by_id \
    \WHERE id = ?"


healthQuery
    :: PrepQuery
        R
        ()
        (Identity Text)

healthQuery =
    "SELECT release_version \
    \FROM system.local"


parentJson
    :: ParentRow
    -> Value

parentJson
    ( pid
    , accountNumber
    , parentStatus
    , createdAt
    , payload
    ) =
        object
            [ "id" .=
                pid

            , "account_number" .=
                accountNumber

            , "status" .=
                parentStatus

            , "created_at" .=
                createdAt

            , "payload" .=
                payload
            ]


main :: IO ()
main = do
    host <-
        maybe
            "benchmark_cassandra"
            id
            <$> lookupEnv
                "CASSANDRA_HOST"

    let settings =
            setContacts
                host
                []

            . setPortNumber
                9042

            . setLogger
                nullLogger

            $ defSettings

    client <-
        Client.init
            settings

    scotty
        8080
        $ do

        get
            "/health"
            $ do

            result <-
                liftIO
                    $ try
                    $ runClient
                        client
                    $ query1
                        healthQuery
                        ( defQueryParams
                            One
                            ()
                        )

            case
                result
                :: Either
                    SomeException
                    (Maybe (Identity Text))
            of
                Right
                    (Just _) ->
                        json
                            $ object
                                [ "status" .=
                                    ("ok" :: Text)
                                ]

                _ -> do
                    status
                        status503

                    json
                        $ object
                            [ "status" .=
                                ("database unavailable" :: Text)
                            ]


        get
            "/parent/:id"
            $ do

            pid <-
                pathParam
                    "id"
                    :: ActionM Int64

            result <-
                liftIO
                    $ try
                    $ runClient
                        client
                    $ query1
                        parentQuery
                        ( defQueryParams
                            One
                            (Identity pid)
                        )

            case
                result
                :: Either
                    SomeException
                    (Maybe ParentRow)
            of
                Right
                    (Just row) ->
                        json
                            (parentJson row)

                Right
                    Nothing -> do

                        status
                            status404

                        json
                            $ object
                                [ "error" .=
                                    ("parent not found" :: Text)
                                ]

                Left
                    _ -> do

                        status
                            status500

                        json
                            $ object
                                [ "error" .=
                                    ("query failed" :: Text)
                                ]
EOF

cat > api/haskell-cassandra/benchmark-haskell-cassandra-api.cabal <<'EOF'
cabal-version: 3.0
name: benchmark-haskell-cassandra-api
version: 0.1.0.0
build-type: Simple

executable benchmark-haskell-cassandra-api
  main-is: Main.hs

  default-language:
    GHC2021

  ghc-options:
    -O2
    -threaded
    -rtsopts

  build-depends:
      base >=4.17 && <5
    , aeson
    , cql-io >=2.0 && <2.1
    , scotty
    , text
    , time
EOF

cat > api/haskell-cassandra/Dockerfile <<'EOF'
FROM haskell:9.10.3-bookworm AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       libssl-dev \
       pkg-config \
       zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY benchmark-haskell-cassandra-api.cabal .

RUN cabal update \
    && cabal build \
       --only-dependencies \
       -j2

COPY Main.hs .

RUN cabal build \
       -j2 \
    && mkdir -p /out \
    && cp \
       "$(cabal list-bin exe:benchmark-haskell-cassandra-api)" \
       /out/benchmark-haskell-cassandra-api


FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       libssl3 \
       zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build \
    /out/benchmark-haskell-cassandra-api \
    /usr/local/bin/benchmark-haskell-cassandra-api

EXPOSE 8080

ENTRYPOINT [
  "/usr/local/bin/benchmark-haskell-cassandra-api",
  "+RTS",
  "-N2",
  "-RTS"
]
EOF


###############################################################################
# BUILD/RUN HELPER
###############################################################################

cat > benchmark/setup_remaining_cassandra.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

for lang in nim v zig haskell
do
  echo
  echo "=================================================="
  echo "BUILDING ${lang^^} + CASSANDRA"
  echo "=================================================="

  docker build \
    -t "benchmark-${lang}-cassandra-api" \
    "api/${lang}-cassandra"
done

for lang in nim v zig haskell
do
  docker rm -f \
    "benchmark_${lang}_cassandra" \
    2>/dev/null || true

  docker run -d \
    --name "benchmark_${lang}_cassandra" \
    --network api_benchmark_network \
    --cpus 2 \
    --memory 2g \
    --memory-swap 2g \
    -e CASSANDRA_HOST=benchmark_cassandra \
    "benchmark-${lang}-cassandra-api"
done

sleep 5

docker ps -a \
  --filter name=benchmark_nim_cassandra \
  --filter name=benchmark_v_cassandra \
  --filter name=benchmark_zig_cassandra \
  --filter name=benchmark_haskell_cassandra \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
EOF

chmod +x \
  benchmark/setup_remaining_cassandra.sh

cat > benchmark/smoke_remaining_cassandra.sh <<'EOF'
#!/usr/bin/env bash
set -u

cd "$(dirname "$0")/.."

for lang in nim v zig haskell
do
  echo
  echo "=================================================="
  echo "${lang^^} HEALTH"
  echo "=================================================="

  docker run --rm \
    --network api_benchmark_network \
    curlimages/curl:8.12.1 \
    -sS \
    --connect-timeout 3 \
    --max-time 5 \
    "http://benchmark_${lang}_cassandra:8080/health"

  echo

  echo
  echo "${lang^^} PARENT 50000"

  docker run --rm \
    --network api_benchmark_network \
    curlimages/curl:8.12.1 \
    -sS \
    --connect-timeout 3 \
    --max-time 5 \
    "http://benchmark_${lang}_cassandra:8080/parent/50000"

  echo
done
EOF

chmod +x \
  benchmark/smoke_remaining_cassandra.sh

echo
echo "Created:"
echo "  api/nim-cassandra"
echo "  api/v-cassandra"
echo "  api/zig-cassandra"
echo "  api/haskell-cassandra"
echo
echo "Build/run helper:"
echo "  benchmark/setup_remaining_cassandra.sh"
echo
echo "Smoke helper:"
echo "  benchmark/smoke_remaining_cassandra.sh"
echo
echo "Tomorrow:"
echo "  ./benchmark/setup_remaining_cassandra.sh"
echo "  ./benchmark/smoke_remaining_cassandra.sh"
