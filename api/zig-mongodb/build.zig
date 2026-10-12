const std=@import("std");
pub fn build(b:*std.Build) void {
 const target=b.standardTargetOptions(.{});const optimize=b.standardOptimizeOption(.{});
 const dep=b.dependency("zap",.{.target=target,.optimize=optimize,.openssl=false});
 const exe=b.addExecutable(.{.name="benchmark-zig-mongodb-api",.root_module=b.createModule(.{.root_source_file=b.path("src/main.zig"),.target=target,.optimize=optimize,.imports=&.{.{.name="zap",.module=dep.module("zap")}}})});
 exe.root_module.addLibraryPath(.{.cwd_relative="/usr/local/lib"});exe.root_module.linkSystemLibrary("benchmark_mongo_bridge",.{});exe.root_module.link_libc=true;
 b.installArtifact(exe);
}
