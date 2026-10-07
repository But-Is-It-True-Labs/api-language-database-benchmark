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
