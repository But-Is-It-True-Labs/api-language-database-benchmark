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
