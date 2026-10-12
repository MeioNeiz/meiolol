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

/// Where the code must keep compiling besides the host: the app ships on Windows, the
/// box is Linux (x86_64 micro now, aarch64 A1 later; deploy/box.sh builds for its CPU)
const ci_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl },
};

const fmt_paths = [_][]const u8{ "build.zig", "build.zig.zon", "src" };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const test_filters = b.option(
        []const []const u8,
        "test-filter",
        "Run only tests whose name contains this (repeatable)",
    ) orelse &.{};

    const m = modules(b, target, optimize);
    const exes = [_]struct { name: []const u8, mod: *std.Build.Module, about: []const u8 }{
        .{ .name = "meiolol", .mod = m.backend, .about = "backend: crawl, stats" },
        .{ .name = "meiolol-app", .mod = m.app, .about = "player tool: suggest, watch" },
    };
    const test_step = b.step("test", "Run unit tests (-Dtest-filter=NAME for some)");
    for (exes) |e| {
        const exe = b.addExecutable(.{ .name = e.name, .root_module = e.mod });
        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        if (b.args) |args| run.addArgs(args);
        b.step(e.name, b.fmt("Run {s} ({s})", .{ e.name, e.about })).dependOn(&run.step);
    }
    for ([_]*std.Build.Module{ m.backend, m.app, m.core, m.store }) |mod| {
        const t = b.addTest(.{ .root_module = mod, .filters = test_filters });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    b.step("fmt", "Format the Zig sources").dependOn(&b.addFmt(.{ .paths = &fmt_paths }).step);

    // What the pre-push hook runs (deploy/hooks/pre-push): every push to main deploys
    const ci = b.step("ci", "Everything before a push: fmt, tests, cross-builds, scripts");
    ci.dependOn(&b.addFmt(.{ .paths = &fmt_paths, .check = true }).step);
    ci.dependOn(test_step);
    for (ci_targets) |q| {
        const cm = modules(b, b.resolveTargetQuery(q), .Debug);
        for ([_]*std.Build.Module{ cm.backend, cm.app }, [_][]const u8{ "meiolol", "meiolol-app" }) |mod, name| {
            ci.dependOn(&b.addExecutable(.{ .name = name, .root_module = mod }).step);
        }
    }
    ci.dependOn(lint(b, "shellcheck", "shellcheck -S warning deploy/*.sh deploy/hooks/*"));
    ci.dependOn(lint(b, "node", "for f in src/site/static/*.js; do node --check \"$f\" || exit 1; done"));
}

const Modules = struct {
    core: *std.Build.Module,
    store: *std.Build.Module,
    backend: *std.Build.Module,
    app: *std.Build.Module,
};

fn modules(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Modules {
    const sqlite = b.dependency("sqlite", .{});

    // Pure: std only, shared by backend and app (draft model, stats file, scoring)
    const core = b.createModule(.{
        .root_source_file = b.path("src/core/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const store = b.createModule(.{
        .root_source_file = b.path("src/store/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    store.addCSourceFile(.{
        .file = sqlite.path("sqlite3.c"),
        // Optimised in Debug too: the site's data step is mostly SQL, and at -O0 a dev
        // server's data load or a test run waits minutes on it
        .flags = &.{ "-DSQLITE_DQS=0", "-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1", "-O2", "-fno-sanitize=undefined" },
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

    return .{ .core = core, .store = store, .backend = backend, .app = app };
}

/// A non-Zig check run from the repo root. A missing tool fails the step, not the
/// build script, so `zig build test` works without it
fn lint(b: *std.Build, tool: []const u8, script: []const u8) *std.Build.Step {
    _ = b.findProgram(&.{tool}, &.{}) catch {
        return &b.addFail(b.fmt("{s} not found: install it to run `zig build ci`", .{tool})).step;
    };
    const run = b.addSystemCommand(&.{ "sh", "-c", script });
    run.setCwd(b.path("."));
    run.setName(tool);
    return &run.step;
}
