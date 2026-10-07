const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zap_dep = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    });

    const exe = b.addExecutable(.{
        .name = "benchmark-zig-api",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "zap",
                    .module = zap_dep.module("zap"),
                },
            },
        }),
    });

    exe.addCSourceFile(.{
        .file = b.path("src/mariadb_bridge.c"),
        .flags = &.{"-O3"},
    });
    exe.addIncludePath(b.path("src"));
    exe.linkSystemLibrary("mariadb");
    exe.linkLibC();

    b.installArtifact(exe);
}
