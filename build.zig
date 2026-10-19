const std = @import("std");
const builtin = @import("builtin");
const Translator = @import("translate_c").Translator;

// 0.x releases break APIs; move versions on purpose
comptime {
    const v = builtin.zig_version;
    if (v.major != 0 or v.minor != 17) {
        @compileError(std.fmt.comptimePrint(
            "meiolol is pinned to Zig 0.17.x, found {d}.{d}.{d}",
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

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const test_filters = b.option(
        []const []const u8,
        "test-filter",
        "Run only tests whose name contains this (repeatable)",
    ) orelse &.{};

    const fmt_paths = [_]std.Build.LazyPath{ b.path("build.zig"), b.path("build.zig.zon"), b.path("src") };
    const m = modules(b, target, optimize);
    const exes = [_]struct { name: []const u8, mod: *std.Build.Module, about: []const u8 }{
        .{ .name = "meiolol", .mod = m.backend, .about = "backend: crawl, stats" },
        .{ .name = "meiolol-app", .mod = m.app, .about = "player tool: suggest, watch" },
    };
    const test_step = b.step("test", "Run unit tests (-Dtest-filter=NAME for some)");
    // The box and jomify get meiolol only: a plain install also builds meiolol-app (~25 s)
    const backend_step = b.step("backend", "Install meiolol only (deploy/box.sh, jomify.sh)");
    for (exes) |e| {
        const exe = b.addExecutable(.{ .name = e.name, .root_module = e.mod });
        const install = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&install.step);
        if (std.mem.eql(u8, e.name, "meiolol")) backend_step.dependOn(&install.step);
        const run = b.addRunArtifact(exe);
        run.addPassthruArgs();
        b.step(e.name, b.fmt("Run {s} ({s})", .{ e.name, e.about })).dependOn(&run.step);
    }
    for ([_]*std.Build.Module{ m.backend, m.app, m.core, m.store, m.tpl }) |mod| {
        const t = b.addTest(.{ .root_module = mod, .filters = test_filters });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    b.step("fmt", "Format the Zig sources").dependOn(&b.addFmt(.{ .paths = &fmt_paths }).step);

    const windows = b.resolveTargetQuery(ci_targets[0]);
    const desktop_step = b.step("desktop", "Build the desktop window for Windows (meiolol-desktop.exe)");
    if (desktopExe(b, windows, optimize)) |exe| desktop_step.dependOn(&b.addInstallArtifact(exe, .{}).step);
    const shot_step = b.step("desktop-shot", "Render the desktop window's states to PNG " ++
        "(-- --stats FILE --curves FILE [--out DIR])");
    // Once per build: dvui's module takes the raster backend as an import, so a second
    // copy would rewire the first
    const shot = desktopShot(b, target, optimize);
    if (shot) |exe| {
        const run = b.addRunArtifact(exe);
        run.addPassthruArgs();
        shot_step.dependOn(&run.step);
    }

    // Host build for Mac CPU jobs in zig-out/bin, gpu-box build in zig-out/gpu-box
    const cand = b.option([]const u8, "cand", "Lab agent candidate dir (docs/lab-agent.md)") orelse "src/lab/cand/base";
    const lab_mod = labModule(b, target, optimize, cand);
    const lab = b.addExecutable(.{ .name = "meiolol-lab", .root_module = labModule(b, b.resolveTargetQuery(gpu_box), .ReleaseFast, cand) });
    const lab_step = b.step("lab", "Build meiolol-lab for this machine and the gpu-box (x86_64 Linux, CUDA)");
    const lab_native = &b.addInstallArtifact(b.addExecutable(.{ .name = "meiolol-lab", .root_module = lab_mod }), .{}).step;
    const lab_gpu_box = &b.addInstallArtifact(lab, .{ .dest_dir = .{ .override = .{ .custom = "gpu-box" } } }).step;
    lab_step.dependOn(lab_native);
    lab_step.dependOn(lab_gpu_box);
    // One target each: deploy/lab-run.sh builds only the host a run goes to
    b.step("lab-native", "Build meiolol-lab for this machine only").dependOn(lab_native);
    b.step("lab-gpu-box", "Build meiolol-lab for the gpu-box only").dependOn(lab_gpu_box);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = lab_mod, .filters = test_filters })).step);
    // win-draft copies the shipped draft model, as a candidate sees only std and api
    const lab_api = b.createModule(.{ .root_source_file = b.path("src/lab/api.zig"), .target = target, .optimize = optimize });
    const win_draft = b.createModule(.{
        .root_source_file = b.path("src/lab/cand/win-draft/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "api", .module = lab_api }},
    });
    const win_draft_test = b.createModule(.{
        .root_source_file = b.path("src/lab/windraft_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = m.core },
            .{ .name = "api", .module = lab_api },
            .{ .name = "win_draft", .module = win_draft },
        },
    });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = win_draft_test, .filters = test_filters })).step);

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
    if (desktopExe(b, windows, .Debug)) |exe| ci.dependOn(&exe.step);
    if (shot) |exe| ci.dependOn(&exe.step);
    // Debug: ci only needs it to compile, and ReleaseFast spends up to a minute in LLVM
    const lab_check = labModule(b, b.resolveTargetQuery(gpu_box), .Debug, cand);
    ci.dependOn(&b.addExecutable(.{ .name = "meiolol-lab", .root_module = lab_check }).step);
    ci.dependOn(lint(b, "shellcheck", "shellcheck -S warning deploy/*.sh deploy/hooks/*"));
    ci.dependOn(lint(b, "git", "deploy/check-deploy.sh"));
    ci.dependOn(lint(b, "node", "for f in src/site/static/*.js; do node --check \"$f\" || exit 1; done"));
}

const Modules = struct {
    core: *std.Build.Module,
    tpl: *std.Build.Module,
    store: *std.Build.Module,
    backend: *std.Build.Module,
    app: *std.Build.Module,
};

fn modules(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Modules {
    const sqlite = b.dependency("sqlite", .{});

    // Pure: std only, shared by backend and app (draft model, stats file, scoring)
    const core = b.createModule(.{
        .root_source_file = b.path("src/core/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // HTML templates checked at compile time: std only, library-grade (src/tpl/root.zig)
    const tpl = b.createModule(.{
        .root_source_file = b.path("src/tpl/root.zig"),
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
    const sqlite_h: Translator = .init(b.dependency("translate_c", .{}), .{
        .c_source_file = sqlite.path("sqlite3.h"),
        .target = target,
        .optimize = optimize,
    });
    store.addImport("sqlite_c", sqlite_h.mod);

    const backend = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core },
            .{ .name = "store", .module = store },
            .{ .name = "tpl", .module = tpl },
        },
        .link_libc = true,
    });
    // A lab candidate whose model the box exports daily for the admin Draft tester
    // (src/lanemodel.zig): it sees only std and the lab api, as in the lab
    const lab_api = b.createModule(.{ .root_source_file = b.path("src/lab/api.zig"), .target = target, .optimize = optimize });
    backend.addImport("api", lab_api);
    backend.addImport("team2", b.createModule(.{
        .root_source_file = b.path("src/lab/cand/team2/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "api", .module = lab_api }},
    }));
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

    // The lane chart for Your games (src/site/chart_wasm.zig), embedded the same way
    const chart_wasm = b.addExecutable(.{
        .name = "chart",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/site/chart_wasm.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .optimize = .ReleaseSmall,
            .imports = &.{.{ .name = "tpl", .module = b.createModule(.{
                .root_source_file = b.path("src/tpl/root.zig"),
            }) }},
        }),
    });
    chart_wasm.entry = .disabled;
    chart_wasm.rdynamic = true;
    backend.addAnonymousImport("chart.wasm", .{ .root_source_file = chart_wasm.getEmittedBin() });

    return .{ .core = core, .tpl = tpl, .store = store, .backend = backend, .app = app };
}

/// The desktop window (src/desktop_main.zig): dvui with its Direct3D 11 backend, tree-sitter
/// off. Null until the lazy dvui dependency is fetched (the build reruns after)
fn desktopExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) ?*std.Build.Step.Compile {
    const dvui = b.lazyDependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .dx11,
        .@"tree-sitter" = false,
    }) orelse return null;
    const exe = b.addExecutable(.{
        .name = "meiolol-desktop",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/desktop_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = modules(b, target, optimize).core },
                .{ .name = "dvui", .module = dvui.module("dvui_dx11") },
            },
        }),
    });
    exe.subsystem = .windows;
    return exe;
}

/// The same UI drawn into memory by src/desktop/raster.zig, for PNGs on any host
fn desktopShot(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) ?*std.Build.Step.Compile {
    const dvui = b.lazyDependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .custom,
        .libc = true,
        .freetype = true,
        .@"stb-image" = true,
        .@"tree-sitter" = false,
    }) orelse return null;
    const dvui_mod = dvui.module("dvui");
    const raster = b.createModule(.{
        .root_source_file = b.path("src/desktop/raster.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "dvui", .module = dvui_mod }},
    });
    dvui_mod.addImport("backend", raster);
    return b.addExecutable(.{
        .name = "meiolol-desktop-shot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/desktop_shot.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = modules(b, target, optimize).core },
                .{ .name = "dvui", .module = dvui_mod },
                .{ .name = "raster", .module = raster },
            },
        }),
    });
}

/// A non-Zig check run from the repo root. A missing tool fails the step, not the
/// build script, so `zig build test` works without it
fn lint(b: *std.Build, tool: []const u8, script: []const u8) *std.Build.Step {
    const check = b.fmt(
        "command -v {s} >/dev/null || {{ echo '{s} not found: install it to run `zig build ci`'; exit 1; }}\n",
        .{ tool, tool },
    );
    const run = b.addSystemCommand(&.{ "sh", "-c", b.fmt("{s}{s}", .{ check, script }) });
    run.setCwd(b.path("."));
    run.setName(tool);
    return &run.step;
}

/// glibc, not musl: libcuda is a glibc library loaded with dlopen. x86_64_v3: the
/// i5-13600KF has AVX2 and FMA (baseline x86-64 has neither); deploy/lab-run.sh's meta
/// records it, since float results differ in the last bits from a baseline build
const gpu_box: std.Target.Query = .{
    .cpu_arch = .x86_64,
    .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 },
    .os_tag = .linux,
    .abi = .gnu,
};

/// Modelling experiments (src/lab_main.zig). Kernels (src/gpu/kernels.zig) go to PTX, which
/// the driver compiles for the card at load; without libcuda the GPU commands fail soft
/// A lab agent candidate (cand) sees only std and src/lab/api.zig: Zig refuses imports
/// outside a module's own directory, so it can't reach the snapshot, split or labels
fn labModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode, cand: []const u8) *std.Build.Module {
    const kernels = b.addObject(.{
        .name = "kernels",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gpu/kernels.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .nvptx64,
                .os_tag = .cuda,
                .cpu_model = .{ .explicit = &std.Target.nvptx.cpu.sm_86 },
            }),
            .optimize = .ReleaseFast,
        }),
    });
    const m = modules(b, target, optimize);
    const mod = b.createModule(.{
        .root_source_file = b.path("src/lab_main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "store", .module = m.store },
            .{ .name = "core", .module = m.core },
        },
    });
    const api = b.createModule(.{ .root_source_file = b.path("src/lab/api.zig"), .target = target, .optimize = optimize });
    mod.addImport("api", api);
    mod.addImport("cand", b.createModule(.{
        .root_source_file = b.path(b.fmt("{s}/root.zig", .{cand})),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "api", .module = api }},
    }));
    mod.addAnonymousImport("kernels.ptx", .{ .root_source_file = kernels.getEmittedAsm() });
    return mod;
}
