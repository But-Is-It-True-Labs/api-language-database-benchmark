const std = @import("std");
const zap = @import("zap");

const c = @cImport({
    @cInclude("mariadb_bridge.h");
});

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

fn cSlice(ptr: [*c]const u8) []const u8 {
    return std.mem.span(@as([*:0]const u8, @ptrCast(ptr)));
}

fn health(r: zap.Request) void {
    if (c.mariadb_bridge_health() != 1) {
        send500(r);
        return;
    }

    r.sendJson(
        \\{"status":"ok"}
    ) catch {};
}

fn parent(r: zap.Request, id_text: []const u8) void {
    const id = std.fmt.parseInt(i64, id_text, 10) catch {
        r.setStatus(.bad_request);
        r.sendJson(
            \\{"error":"invalid parent id"}
        ) catch {};
        return;
    };

    const rc = c.mariadb_bridge_parent(id);
    if (rc < 0) {
        send500(r);
        return;
    }
    if (rc == 0) {
        send404(r);
        return;
    }

    const status = cSlice(c.mariadb_bridge_parent_status());
    const created_at = cSlice(c.mariadb_bridge_parent_created_at());
    const payload = cSlice(c.mariadb_bridge_parent_payload());

    var json_buffer: [4096]u8 = undefined;
    const body = std.fmt.bufPrint(
        &json_buffer,
        "{{\"id\":{d},\"account_number\":{d},\"status\":\"{s}\",\"created_at\":\"{s}\",\"payload\":\"{s}\"}}",
        .{
            c.mariadb_bridge_parent_id(),
            c.mariadb_bridge_parent_account_number(),
            status,
            created_at,
            payload,
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
        if (id_text.len == 0 or std.mem.indexOfScalar(u8, id_text, '/') != null) {
            send404(r);
            return;
        }
        parent(r, id_text);
        return;
    }

    send404(r);
}

fn env(map: *const std.process.Environ.Map, key: []const u8, fallback: []const u8) []const u8 {
    return map.get(key) orelse fallback;
}

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.smp_allocator;

    const host = try allocator.dupeZ(u8, env(init.environ_map, "MYSQLHOST", "benchmark_mariadb"));
    defer allocator.free(host);
    const user = try allocator.dupeZ(u8, env(init.environ_map, "MYSQLUSER", "benchmark"));
    defer allocator.free(user);
    const password = try allocator.dupeZ(u8, env(init.environ_map, "MYSQLPASSWORD", "benchmark_password"));
    defer allocator.free(password);
    const database = try allocator.dupeZ(u8, env(init.environ_map, "MYSQLDATABASE", "benchmark"));
    defer allocator.free(database);

    const port = try std.fmt.parseInt(
        u16,
        env(init.environ_map, "MYSQLPORT", "3306"),
        10,
    );

    _ = c.mariadb_bridge_init(host.ptr, port, user.ptr, password.ptr, database.ptr);

    var listener = zap.HttpListener.init(.{
        .port = 8080,
        .on_request = onRequest,
        .log = false,
        .max_clients = 100000,
    });

    try listener.listen();

    std.debug.print(
        "Zig/Zap MariaDB benchmark API listening on :8080\n",
        .{},
    );

    zap.start(.{
        .threads = 50,
        .workers = 1,
    });
}
