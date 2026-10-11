const std = @import("std");
const builtin = @import("builtin");

// 0.x releases break APIs; move versions on purpose
comptime {
    const v = builtin.zig_version;
    if (v.major != 0 or v.minor != 16) {
        @compileError(std.fmt.comptimePrint(
            "meiolol is pinned to Zig 0.16.x, found {d}.{d}.{d}",
            .{ v.major, v.minor, v.patch },
        ));
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sqlite = b.dependency("sqlite", .{});

    // Pure: std only, shared by backend and app (draft model, stats file, scoring)
    const core = b.addModule("core", .{
        .root_source_file = b.path("src/core/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const store = b.addModule("store", .{
        .root_source_file = b.path("src/store/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    store.addCSourceFile(.{
        .file = sqlite.path("sqlite3.c"),
        .flags = &.{ "-DSQLITE_DQS=0", "-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1" },
    });
    store.addIncludePath(sqlite.path("."));

    const backend = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core },
            .{ .name = "store", .module = store },
        },
        .link_libc = true,
    });
    const app = b.createModule(.{
        .root_source_file = b.path("src/app_main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "core", .module = core }},
    });

    // The recommender for the website's draft helper, embedded by `meiolol site`
    const wasm = b.addExecutable(.{
        .name = "meiolol",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .optimize = .ReleaseSmall,
            .imports = &.{.{ .name = "core", .module = b.createModule(.{
                .root_source_file = b.path("src/core/root.zig"),
            }) }},
        }),
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;
    backend.addAnonymousImport("draft.wasm", .{ .root_source_file = wasm.getEmittedBin() });

    const exes = [_]struct { name: []const u8, mod: *std.Build.Module, about: []const u8 }{
        .{ .name = "meiolol", .mod = backend, .about = "backend: crawl, stats" },
        .{ .name = "meiolol-app", .mod = app, .about = "player tool: suggest, watch" },
    };
    const test_step = b.step("test", "Run unit tests");
    for (exes) |e| {
        const exe = b.addExecutable(.{ .name = e.name, .root_module = e.mod });
        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        if (b.args) |args| run.addArgs(args);
        b.step(e.name, b.fmt("Run {s} ({s})", .{ e.name, e.about })).dependOn(&run.step);
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = e.mod })).step);
    }
    for ([_]*std.Build.Module{ core, store }) |m| {
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = m })).step);
    }
}
