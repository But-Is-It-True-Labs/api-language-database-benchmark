const std = @import("std");
const zap = @import("zap");
const pg = @import("pg");

const pool_size = 50;

var db_pool: *pg.Pool = undefined;

const Parent = struct {
    id: i64,
    account_number: i64,
    status: []const u8,
    created_at: []const u8,
    payload: []const u8,
};

fn send500(r: zap.Request) void {
    r.setStatus(.internal_server_error);
    r.sendJson(
        \\{"error":"internal server error"}
    ) catch {};
}

fn send404(r: zap.Request) void {
    r.setStatus(.not_found);
    r.sendJson(
        \\{"error":"not found"}
    ) catch {};
}

fn health(r: zap.Request) void {
    var row = (db_pool.row(
        "SELECT 1",
        .{},
    ) catch {
        send500(r);
        return;
    }) orelse {
        send500(r);
        return;
    };

    defer row.deinit() catch {};

    r.sendJson(
        \\{"status":"ok"}
    ) catch {};
}

fn parent(r: zap.Request, id_text: []const u8) void {
    const id = std.fmt.parseInt(
        i64,
        id_text,
        10,
    ) catch {
        r.setStatus(.bad_request);
        r.sendJson(
            \\{"error":"invalid parent id"}
        ) catch {};
        return;
    };

    var row = (db_pool.row(
        \\SELECT
        \\    id,
        \\    account_number,
        \\    status,
        \\    created_at,
        \\    payload
        \\FROM benchmark_parent
        \\WHERE id = $1
    ,
        .{id},
    ) catch {
        send500(r);
        return;
    }) orelse {
        send404(r);
        return;
    };

    defer row.deinit() catch {};

    const result = Parent{
        .id = row.get(i64, 0) catch {
            send500(r);
            return;
        },

        .account_number = row.get(i64, 1) catch {
            send500(r);
            return;
        },

        .status = row.get([]const u8, 2) catch {
            send500(r);
            return;
        },

        .created_at = row.get([]const u8, 3) catch {
            send500(r);
            return;
        },

        .payload = row.get([]const u8, 4) catch {
            send500(r);
            return;
        },
    };

    var json_buffer: [1024]u8 = undefined;

    const body = std.fmt.bufPrint(
        &json_buffer,
        "{{\"id\":{d},\"account_number\":{d},\"status\":\"{s}\",\"created_at\":\"{s}\",\"payload\":\"{s}\"}}",
        .{
            result.id,
            result.account_number,
            result.status,
            result.created_at,
            result.payload,
        },
    ) catch {
        send500(r);
        return;
    };

    r.sendJson(body) catch {};
}

fn onRequest(r: zap.Request) !void {
    const path = r.path orelse {
        send404(r);
        return;
    };

    if (std.mem.eql(u8, path, "/health")) {
        health(r);
        return;
    }

    const prefix = "/parent/";

    if (std.mem.startsWith(u8, path, prefix)) {
        const id_text = path[prefix.len..];

        if (
            id_text.len == 0 or
            std.mem.indexOfScalar(u8, id_text, '/') != null
        ) {
            send404(r);
            return;
        }

        parent(r, id_text);
        return;
    }

    send404(r);
}

fn env(
    map: *const std.process.Environ.Map,
    key: []const u8,
    fallback: []const u8,
) []const u8 {
    return map.get(key) orelse fallback;
}

pub fn main(init: std.process.Init) !void {
    const host = env(
        init.environ_map,
        "PGHOST",
        "benchmark_postgres",
    );

    const port = try std.fmt.parseInt(
        u16,
        env(
            init.environ_map,
            "PGPORT",
            "5432",
        ),
        10,
    );

    const username = env(
        init.environ_map,
        "PGUSER",
        "benchmark",
    );

    const password = env(
        init.environ_map,
        "PGPASSWORD",
        "benchmark_password",
    );

    const database = env(
        init.environ_map,
        "PGDATABASE",
        "benchmark",
    );

    db_pool = try pg.Pool.init(
        init.io,
        std.heap.smp_allocator,
        .{
            .size = pool_size,

            .connect = .{
                .host = host,
                .port = port,
            },

            .auth = .{
                .username = username,
                .password = password,
                .database = database,
                .timeout = 10_000,
            },
        },
    );

    defer db_pool.deinit();

    var listener = zap.HttpListener.init(.{
        .port = 8080,
        .on_request = onRequest,
        .log = false,
        .max_clients = 100000,
    });

    try listener.listen();

    std.debug.print(
        "Zig/Zap benchmark API listening on :8080\nPostgreSQL pool: {d}\n",
        .{pool_size},
    );

    zap.start(.{
        .threads = 50,
        .workers = 1,
    });
}
