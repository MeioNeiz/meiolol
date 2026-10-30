const std = @import("std");
const builtin = @import("builtin");
const Translator = @import("translate_c").Translator;
const tpl_errors = @import("src/tpl/compile_errors.zig");
const ui_errors = @import("src/site/ui/compile_errors.zig");

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
    wasm_dev = b.option(bool, "wasm-dev", "ui.wasm with safety checks and a zjb handle " ++
        "leak check after each event, over its size budget (qa.sh)") orelse false;
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
    const app_step = b.step("app", "Install meiolol-app only");
    for (exes) |e| {
        const exe = b.addExecutable(.{ .name = e.name, .root_module = e.mod });
        const install = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&install.step);
        if (std.mem.eql(u8, e.name, "meiolol")) backend_step.dependOn(&install.step);
        if (std.mem.eql(u8, e.name, "meiolol-app")) app_step.dependOn(&install.step);
        const run = b.addRunArtifact(exe);
        run.addPassthruArgs();
        b.step(e.name, b.fmt("Run {s} ({s})", .{ e.name, e.about })).dependOn(&run.step);
    }
    // Stub islands: the 41 wasm builds took ~50 s of `test` after a ui edit. ci still
    // builds them all (uiSizes, the cross builds), and the dev server on each edit
    const stub = modulesWith(b, target, optimize, uiStub);
    for ([_]*std.Build.Module{ stub.backend, stub.app, stub.core, stub.store, stub.tpl, stub.net }) |mod| {
        const run = b.addRunArtifact(b.addTest(.{ .root_module = mod, .filters = test_filters }));
        test_step.dependOn(&run.step);
        if (mod == stub.backend) siteFiles(b, run);
    }
    // Component work's inner loop (deploy/zb.sh test-ui): the backend imports ui, so a ui
    // edit under plain `test` rebuilds the backend's tests too
    const test_ui_step = b.step("test-ui", "Run the ui module's tests only (-Dtest-filter=NAME)");
    test_ui_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = m.ui, .filters = test_filters })).step);
    test_ui_step.dependOn(errorChecks(b, "ui", m.ui, "src/site/ui/compile_errors.zig", &ui_errors.cases));
    test_step.dependOn(test_ui_step);

    test_step.dependOn(errorChecks(b, "tpl", m.tpl, "src/tpl/compile_errors.zig", &tpl_errors.cases));
    const shell_options = desktopOptions(b, 0, .private).createModule();
    const shell_test = b.createModule(.{
        .root_source_file = b.path("src/shell/test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "desktop", .module = desktopModule(b, stub, target, optimize, shell_options) },
            .{ .name = "build_options", .module = shell_options },
        },
    });
    shellUi(b, shell_test, stub.ui, uiStub);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = shell_test, .filters = test_filters })).step);

    b.step("fmt", "Format the Zig sources").dependOn(&b.addFmt(.{ .paths = &fmt_paths }).step);

    const windows = b.resolveTargetQuery(ci_targets[0]);
    // The updater never installs an exe of the same or an older release (update.zig)
    const desktop_version = b.option(u64, "desktop-version", "Release number for the desktop " ++
        "exe (deploy/desktop-release.sh; 0, the default, is unreleased)") orelse 0;
    const edition = b.option(Edition, "edition", "Desktop edition: private (testers, the " ++
        "default) or public (docs/plan/app.md)") orelse .private;
    const desktop_step = b.step("desktop", "Build the desktop window for Windows (meiolol-desktop.exe)");
    if (desktopExe(b, windows, optimize, desktop_version, edition)) |exe| desktop_step.dependOn(&b.addInstallArtifact(exe, .{}).step);
    // Opt in: dvui's SDL3 dependency would be fetched on every host otherwise
    const dev_step = b.step("desktop-dev", "Run the desktop window on this Mac or Linux " ++
        "via SDL3 (-Ddev-window -fsys=sdl3; deploy/mock-cs.sh)");
    if (b.option(bool, "dev-window", "Configure desktop-dev (needs SDL3 installed)") orelse false) {
        if (desktopDev(b, target, optimize)) |exe| {
            const run = b.addRunArtifact(exe);
            run.addPassthruArgs();
            dev_step.dependOn(&run.step);
            b.step("desktop-dev-install", "Install meiolol-desktop-dev").dependOn(&b.addInstallArtifact(exe, .{}).step);
        }
    } else dev_step.dependOn(&b.addFail("desktop-dev needs -Ddev-window -fsys=sdl3 (deploy/mock-cs.sh)").step);
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

    // The webview app (src/shell, docs/plan/ui/stack.md), beside the dvui one until it
    // takes over: Windows exe, and the Mac window for the dev loop
    const shell = shellExe(b, windows, optimize, desktop_version, edition);
    b.step("shell", "Build the webview app for Windows (meiolol-shell.exe)").dependOn(&b.addInstallArtifact(shell, .{}).step);
    const shell_mac_step = b.step("shell-mac", "Run the webview app on this Mac (-- [--dir PATH] [--page P] [--demo])");
    if (b.graph.host.result.os.tag == .macos) {
        const run = b.addRunArtifact(shellMac(b, target, optimize));
        run.addPassthruArgs();
        shell_mac_step.dependOn(&run.step);
    } else shell_mac_step.dependOn(&b.addFail("shell-mac runs on macOS only").step);

    // A mock League client for trying the app without League (deploy/mock-cs.sh)
    const mock_exe = b.addExecutable(.{ .name = "meiolol-mock-lcu", .root_module = b.createModule(.{
        .root_source_file = b.path("src/mocklcu_main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "core", .module = m.core }, .{ .name = "net", .module = m.net } },
    }) });
    const mock_install = b.addInstallArtifact(mock_exe, .{});
    const mock_run = b.addRunArtifact(mock_exe);
    mock_run.addPassthruArgs();
    b.step("mock-lcu", "Run a mock League client (-- SCENARIO [--speed X] [--manual])").dependOn(&mock_run.step);
    b.step("mock-lcu-install", "Install meiolol-mock-lcu only").dependOn(&mock_install.step);

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
    // Lab code never ships: its tests stay out of ci (deploy/lab-run.sh runs them before a
    // build). ci still compiles meiolol-lab, so a core change can't break it unseen
    const test_lab_step = b.step("test-lab", "Run the lab's and nn's unit tests (-Dtest-filter=NAME)");
    test_lab_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = lab_mod, .filters = test_filters })).step);
    const nn_test = b.addTest(.{ .root_module = nnModule(b, target, optimize), .filters = test_filters });
    test_lab_step.dependOn(&b.addRunArtifact(nn_test).step);
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
    for ([_][]const u8{ "wasmsize", "fmtlint" }) |t| {
        const mod = hostTool(b, t).root_module;
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = mod, .filters = test_filters })).step);
    }

    // What the pre-push hook runs (deploy/hooks/pre-push): every push to main deploys
    const ci = b.step("ci", "Everything before a push: fmt, tests, cross-builds, scripts");
    ci.dependOn(&b.addFmt(.{ .paths = &fmt_paths, .check = true }).step);
    ci.dependOn(test_step);
    // The app's and net's tests again in ReleaseSafe, as the desktop app ships: a header
    // slice into a returned frame read fine in Debug (lcu/https.zig RequestParts)
    const safe = modules(b, target, .ReleaseSafe);
    for ([_]*std.Build.Module{ safe.app, safe.net }) |mod| {
        ci.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = mod, .filters = test_filters })).step);
    }
    for (ci_targets) |q| {
        const cm = modules(b, b.resolveTargetQuery(q), .Debug);
        for ([_]*std.Build.Module{ cm.backend, cm.app }, [_][]const u8{ "meiolol", "meiolol-app" }) |mod, name| {
            ci.dependOn(&b.addExecutable(.{ .name = name, .root_module = mod }).step);
        }
    }
    if (desktopExe(b, windows, .Debug, 0, .public)) |public| if (desktopExe(b, windows, .Debug, 0, .private)) |private| {
        const editions = b.addSystemCommand(&.{"deploy/check-edition.sh"});
        editions.addFileArg(public.getEmittedBin());
        editions.addFileArg(private.getEmittedBin());
        editions.setCwd(b.path("."));
        ci.dependOn(&editions.step);
    };
    if (shot) |exe| ci.dependOn(&exe.step);
    ci.dependOn(&shellExe(b, windows, .Debug, 0, .private).step);
    if (b.graph.host.result.os.tag == .macos) ci.dependOn(&shellMac(b, target, .Debug).step);
    ci.dependOn(&mock_exe.step);
    // ui.wasm per page family: built, and its size against the budget (stack.md) and the
    // last pushed main's; no number formatting through std.fmt in what compiles to it
    ci.dependOn(&uiSizes(b, &ui_families).step);
    ci.dependOn(&fmtLint(b).step);
    // Debug: ci only needs it to compile, and ReleaseFast spends up to a minute in LLVM
    const lab_check = labModule(b, b.resolveTargetQuery(gpu_box), .Debug, cand);
    ci.dependOn(&b.addExecutable(.{ .name = "meiolol-lab", .root_module = lab_check }).step);
    ci.dependOn(lint(b, "shellcheck", "shellcheck -S warning deploy/*.sh deploy/hooks/*"));
    ci.dependOn(lint(b, "git", "deploy/check-deploy.sh"));
    ci.dependOn(lint(b, "sh", "deploy/hooks/claude-bash-guard.sh --test > /dev/null"));
    ci.dependOn(lint(b, "perl", "for f in deploy/*.pl; do perl -c \"$f\" 2> /dev/null || { perl -c \"$f\"; exit 1; }; done"));
    ci.dependOn(lint(b, "node", "for f in src/site/static/*.js deploy/training/*.js deploy/*.js; do node --check \"$f\" || exit 1; done"));

    // `zig build ui-sizes -- --base REV` compares with another recorded commit
    const sizes = uiSizes(b, &ui_families);
    sizes.addPassthruArgs();
    b.step("ui-sizes", "ui.wasm sizes against budgets and the last pushed main").dependOn(&sizes.step);
    for (ui_families) |f| {
        b.step(b.fmt("ui-{s}-size", .{f}), b.fmt("Size of ui-{s}.wasm", .{f})).dependOn(&uiSizes(b, &.{f}).step);
    }
    // `zig build fmtlint -- --write-allow` rewrites the allow file after a review
    const lint_step = fmtLint(b);
    lint_step.addPassthruArgs();
    b.step("fmtlint", "Number formatting in code that compiles to ui.wasm").dependOn(&lint_step.step);

    // The backend's threads under ThreadSanitizer, by hand after a threading change (not
    // in ci: slow). The tests that run threads; -Dtest-filter picks others
    const backend_tsan = modules(b, target, .Debug);
    const backend_check = b.step("backend-check", "Backend tests that run threads, under ThreadSanitizer");
    const tsan_filters: []const []const u8 = if (test_filters.len > 0) test_filters else &.{
        "par.test", "ahead.test", "server.test", "proxy.test", "ratelimit.test", "idle keep-alive", "pipeline_test",
    };
    for ([_]*std.Build.Module{ backend_tsan.backend, backend_tsan.store, backend_tsan.net }) |t| {
        t.sanitize_thread = true;
        const run = b.addRunArtifact(b.addTest(.{ .root_module = t, .filters = tsan_filters }));
        if (t == backend_tsan.backend) siteFiles(b, run);
        backend_check.dependOn(&run.step);
    }
    // The crawler's threads need a run: zig-out/tsan/meiolol crawl --fake-api (libraries.md)
    b.step("backend-tsan", "meiolol under ThreadSanitizer in zig-out/tsan").dependOn(&b.addInstallArtifact(
        b.addExecutable(.{ .name = "meiolol", .root_module = backend_tsan.backend }),
        .{ .dest_dir = .{ .override = .{ .custom = "tsan" } } },
    ).step);

    // Desktop release checks (deploy/desktop-release.sh), slower than ci so not in it:
    // core, app and net tests under ThreadSanitizer, and their fuzz tests searched for
    // --fuzz=N inputs (plain `zig build test` runs each fuzz test once)
    const tsan = modules(b, target, .Debug);
    const fuzz = modules(b, target, .Debug);
    const check_step = b.step("desktop-check", "Desktop release: core, app and net tests under ThreadSanitizer");
    const fuzz_step = b.step("desktop-fuzz", "Desktop release: fuzz the parsers it downloads (--fuzz=N)");
    // -Dtest-filter picks fuzz tests, here and in backend-fuzz
    const fuzz_filters: []const []const u8 = if (test_filters.len > 0) test_filters else &.{"fuzz"};
    for ([_]*std.Build.Module{ tsan.core, tsan.app, tsan.net }, [_]*std.Build.Module{ fuzz.core, fuzz.app, fuzz.net }) |t, f| {
        t.sanitize_thread = true;
        check_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = t, .filters = test_filters })).step);
        fuzz_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = f, .filters = fuzz_filters })).step);
    }

    // The backend's untrusted input (Riot replies, stored blobs, packs, API requests),
    // searched by hand before a crawler or API change
    const backend_fuzz = modules(b, target, .Debug);
    const backend_fuzz_step = b.step("backend-fuzz", "Fuzz the backend's parsers of Riot " ++
        "replies, stored blobs and API requests (--fuzz=N)");
    for ([_]*std.Build.Module{ backend_fuzz.backend, backend_fuzz.store }) |f| {
        backend_fuzz_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = f, .filters = fuzz_filters })).step);
    }
}

/// A backend test run: pipeline_test.zig reads src/testdata/site-files.txt at run time,
/// not embedded, so an edit to it reruns the tests without recompiling them (Zig skips a
/// test run whose inputs match)
fn siteFiles(b: *std.Build, run: *std.Build.Step.Run) void {
    run.setCwd(b.path("."));
    run.addFileInput(b.path("src/testdata/site-files.txt"));
}

const Modules = struct {
    core: *std.Build.Module,
    tpl: *std.Build.Module,
    ui: *std.Build.Module,
    net: *std.Build.Module,
    store: *std.Build.Module,
    backend: *std.Build.Module,
    app: *std.Build.Module,
};

fn modules(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Modules {
    return modulesWith(b, target, optimize, uiWasm);
}

const Island = fn (*std.Build, []const u8) UiWasm;

fn modulesWith(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode, island: Island) Modules {
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

    // The component system (docs/plan/ui/stack.md): std, tpl and core only, as it builds
    // for the backend and for ui.wasm
    const ui = b.createModule(.{
        .root_source_file = b.path("src/site/ui/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "tpl", .module = tpl }, .{ .name = "core", .module = core } },
    });

    // HTTP pieces std leaves out (rate limits, signatures): std only, library-grade (src/net/root.zig)
    const net = b.createModule(.{
        .root_source_file = b.path("src/net/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const store = b.createModule(.{
        .root_source_file = b.path("src/store/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "core", .module = core }},
        .link_libc = true,
    });
    store.addCSourceFile(.{
        .file = sqlite.path("sqlite3.c"),
        // Optimised in Debug too: the site's data step is mostly SQL, and at -O0 a dev
        // server's data load or a test run waits minutes on it. Not instrumented under
        // --fuzz: Zig's fuzzer has no hooks for C comparisons (undefined symbols), and
        // sqlite's own paths are not what backend-fuzz searches
        .flags = &.{
            "-DSQLITE_DQS=0",
            "-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1",
            "-O2",
            "-fno-sanitize=undefined",
            "-fno-sanitize-coverage=trace-cmp,inline-8bit-counters,pc-table",
        },
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
            .{ .name = "ui", .module = ui },
            .{ .name = "net", .module = net },
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
    // The app's poller and screens for its review pages on the private site
    // (src/site/appreview.zig), with the mock client's scenarios
    const desktop_options = desktopOptions(b, 0, .private).createModule();
    backend.addImport("build_options", desktop_options);
    backend.addImport("desktop", b.createModule(.{
        .root_source_file = b.path("src/desktop_app.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "core", .module = core }, .{ .name = "net", .module = net }, .{ .name = "build_options", .module = desktop_options } },
    }));
    backend.addAnonymousImport("scenarios", .{ .root_source_file = b.path("testdata/lcu/scenarios/all.zig") });
    const app = b.createModule(.{
        .root_source_file = b.path("src/app_main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "core", .module = core }, .{ .name = "net", .module = net } },
    });

    // The stylesheet minified and every hashed asset's name, by tools on the host: at
    // comptime they took minutes of each backend compile (src/site/assets.zig)
    const host_tpl = b.createModule(.{ .root_source_file = b.path("src/tpl/root.zig"), .target = b.graph.host });
    const host_core = b.createModule(.{ .root_source_file = b.path("src/core/root.zig"), .target = b.graph.host });
    const host_ui = b.createModule(.{
        .root_source_file = b.path("src/site/ui/root.zig"),
        .target = b.graph.host,
        .imports = &.{ .{ .name = "tpl", .module = host_tpl }, .{ .name = "core", .module = host_core } },
    });
    const cssmin = b.addRunArtifact(b.addExecutable(.{ .name = "cssmin", .root_module = b.createModule(.{
        .root_source_file = b.path("src/tools/cssmin.zig"),
        .target = b.graph.host,
        .imports = &.{.{ .name = "ui", .module = host_ui }},
    }) }));
    const style_min = cssmin.addOutputFileArg("style.min.css");
    cssmin.addFileArg(b.path("src/site/static/inter.woff2"));
    backend.addAnonymousImport("style.min.css", .{ .root_source_file = style_min });
    const names = b.addRunArtifact(b.addExecutable(.{ .name = "assetnames", .root_module = b.createModule(.{
        .root_source_file = b.path("src/tools/assetnames.zig"),
        .target = b.graph.host,
    }) }));
    const names_zig = names.addOutputFileArg("asset_names.zig");
    for ([_]struct { []const u8, std.Build.LazyPath }{
        .{ "style.css", style_min },
        .{ "inter.woff2", b.path("src/site/static/inter.woff2") },
    }) |f| {
        names.addArg(f[0]);
        names.addFileArg(f[1]);
    }

    // The site's islands, per page family (src/site/ui/wasm), with zjb's loaders
    for (ui_families) |f| {
        const u = island(b, f);
        backend.addAnonymousImport(b.fmt("{s}.wasm", .{u.name}), .{ .root_source_file = u.wasm });
        backend.addAnonymousImport(b.fmt("{s}.js", .{u.name}), .{ .root_source_file = u.js });
        for ([_][]const u8{ "wasm", "js" }, [_]std.Build.LazyPath{ u.wasm, u.js }) |ext, p| {
            names.addArg(b.fmt("{s}.{s}", .{ u.name, ext }));
            names.addFileArg(p);
        }
    }
    backend.addAnonymousImport("asset_names", .{ .root_source_file = names_zig });

    return .{ .core = core, .tpl = tpl, .ui = ui, .net = net, .store = store, .backend = backend, .app = app };
}

/// ui.wasm files, one per page family so each page loads only its islands (Jacob 25 Oct)
const ui_families = [_][]const u8{ "stats", "champion", "champbuild", "champmore", "champcharts", "matchup", "matchmore", "app", "games", "gamemore", "gamelane", "practice", "finder", "findergrid", "learn", "patch", "pool", "poolgrid", "daily", "dailyseat", "dailydays", "home", "homegame", "tester", "testercand", "your", "yourviews", "yourtime", "yourlookup", "yourfriends", "forget", "account", "sitesearch", "notes", "admin", "admincharts", "admintraffic", "adminops", "adminmodels", "adminlab", "adminruns" };
/// gzip bytes per family: stack.md's 40 KB
const ui_budget = 40 * 1024;
/// -Dwasm-dev
var wasm_dev = false;
/// Families only logins load (/admin, /private): 64 KB (Jacob 27 Oct)
const ui_private = [_][]const u8{ "ui-tester", "ui-testercand", "ui-notes", "ui-admin", "ui-admincharts", "ui-admintraffic", "ui-adminops", "ui-adminmodels", "ui-adminlab", "ui-adminruns" };
const ui_private_budget = 64 * 1024;

const UiWasm = struct { name: []const u8, wasm: std.Build.LazyPath, js: std.Build.LazyPath };

/// src/site/ui/wasm/<family>.zig as ui-<family>.wasm, and zjb's loader for it
fn uiWasm(b: *std.Build, family: []const u8) UiWasm {
    const exe = uiExe(b, family, true);
    const zjb = b.dependency("zjb", .{});
    const gen = b.addRunArtifact(zjb.artifact("generate_js"));
    const js = gen.addOutputFileArg(b.fmt("{s}.js", .{exe.name}));
    // The loader's global class: one per family, as a page may load several (champion,
    // champbuild, champmore) and a second classic script declaring the same name throws
    gen.addArg(b.fmt("Zjb_{s}", .{family}));
    gen.addArtifactArg(exe);
    gen.addArg("--loader");
    return .{ .name = exe.name, .wasm = exe.getEmittedBin(), .js = js };
}

/// A family's files for the tests, which only embed them and link them by hashed name:
/// distinct bytes per family, so no two share a name
fn uiStub(b: *std.Build, family: []const u8) UiWasm {
    const name = b.fmt("ui-{s}", .{family});
    const files = b.addWriteFiles();
    return .{
        .name = name,
        .wasm = files.add(b.fmt("{s}.wasm", .{name}), b.fmt("stub {s}\n", .{name})),
        .js = files.add(b.fmt("{s}.js", .{name}), b.fmt("// stub {s}\n", .{name})),
    };
}

/// The family's wasm; `strip` false keeps a name section for src/tools/wasmsize.zig
fn uiExe(b: *std.Build, family: []const u8, strip: bool) *std.Build.Step.Compile {
    const wasm_target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const zjb = b.dependency("zjb", .{});
    const tpl = b.createModule(.{ .root_source_file = b.path("src/tpl/root.zig") });
    const core = b.createModule(.{ .root_source_file = b.path("src/core/root.zig") });
    const ui = b.createModule(.{
        .root_source_file = b.path("src/site/ui/root.zig"),
        .imports = &.{ .{ .name = "tpl", .module = tpl }, .{ .name = "core", .module = core } },
    });
    const options = b.addOptions();
    options.addOption(bool, "dev", wasm_dev);
    const exe = b.addExecutable(.{ .name = b.fmt("ui-{s}", .{family}), .root_module = b.createModule(.{
        .root_source_file = b.path(b.fmt("src/site/ui/wasm/{s}.zig", .{family})),
        .target = wasm_target,
        .optimize = if (wasm_dev) .ReleaseSafe else .ReleaseSmall,
        .strip = strip,
        .imports = &.{
            .{ .name = "ui", .module = ui },
            .{ .name = "zjb", .module = zjb.module("zjb") },
            .{ .name = "wasm_options", .module = options.createModule() },
        },
    }) });
    exe.entry = .disabled;
    exe.rdynamic = true;
    return exe;
}

/// src/tools/wasmsize.zig over the families: gzip size as served against the budget and
/// the last pushed main's, failing over a budget; on growth over 200 B or a failure, the
/// functions that grew, their files and our callers of std code (from a build with
/// names). All families from a clean tree (pre-push ci's) are the next baseline
fn uiSizes(b: *std.Build, families: []const []const u8) *std.Build.Step.Run {
    const run = b.addRunArtifact(hostTool(b, "wasmsize"));
    run.setCwd(b.path("."));
    if (families.len == ui_families.len and !wasm_dev) run.addArg("--record");
    for (families) |f| {
        const w = uiWasm(b, f);
        const budget: u32 = if (wasm_dev) std.math.maxInt(u32) else for (ui_private) |p| {
            if (std.mem.eql(u8, p, w.name)) break ui_private_budget;
        } else ui_budget;
        run.addArgs(&.{ w.name, b.fmt("{d}", .{budget}) });
        run.addFileArg(w.wasm);
        // Builds beside the tests' compile, off ci's critical path: a ui change's ci
        // takes about as long without these (measured on the gpu-box, 80-105 s either way)
        run.addFileArg(uiExe(b, f, false).getEmittedBin());
    }
    run.has_side_effects = true;
    return run;
}

/// src/tools/fmtlint.zig over the code that compiles to ui.wasm: uiExe's modules, core
/// as far as ui imports it
fn fmtLint(b: *std.Build) *std.Build.Step.Run {
    const run = b.addRunArtifact(hostTool(b, "fmtlint"));
    run.addArgs(&.{ "--module", "core=src/core/root.zig", "src/site/ui", "src/tpl" });
    run.setCwd(b.path("."));
    run.has_side_effects = true;
    return run;
}

/// src/tools/<name>.zig (std only), built for this machine
fn hostTool(b: *std.Build, name: []const u8) *std.Build.Step.Compile {
    return b.addExecutable(.{ .name = name, .root_module = b.createModule(.{
        .root_source_file = b.path(b.fmt("src/tools/{s}.zig", .{name})),
        .target = b.graph.host,
    }) });
}

/// The desktop window (src/desktop_main.zig): dvui with its Direct3D 11 backend, tree-sitter
/// off. Null until the lazy dvui dependency is fetched (the build reruns after)
const Edition = enum { public, private };

fn desktopExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode, version: u64, edition: Edition) ?*std.Build.Step.Compile {
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
                .{ .name = "net", .module = modules(b, target, optimize).net },
                .{ .name = "dvui", .module = dvui.module("dvui_dx11") },
            },
        }),
    });
    exe.root_module.addOptions("build_options", desktopOptions(b, version, edition));
    exe.root_module.addWin32ResourceFile(.{ .file = b.path("src/desktop/meiolol.rc") });
    exe.subsystem = .windows;
    return exe;
}

/// The exe's release and edition. Private compiles both editions' code in (the edition
/// shown is a runtime choice), public only its own (src/desktop/widgets.zig private_code)
fn desktopOptions(b: *std.Build, version: u64, edition: Edition) *std.Build.Step.Options {
    const options = b.addOptions();
    options.addOption(u64, "desktop_version", version);
    options.addOption(bool, "public", edition == .public);
    return options;
}

/// The app's poller and what it publishes (src/desktop_app.zig), for the shell: the dvui
/// window imports the same files by path from src/
/// `options` is the importer's build_options too, and `m` gives the shell its ui: one
/// module each, as Zig refuses a file in two (core, which ui imports)
fn desktopModule(b: *std.Build, m: Modules, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode, options: *std.Build.Module) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("src/desktop_app.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = m.core },
            .{ .name = "net", .module = m.net },
            .{ .name = "build_options", .module = options },
        },
    });
}

/// The webview app for Windows (src/shell/win.zig): WebView2's COM API through
/// translate-c of Microsoft's header, vendored in src/shell/wv2 with the loader dll
fn shellExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode, version: u64, edition: Edition) *std.Build.Step.Compile {
    const wv2: Translator = .init(b.dependency("translate_c", .{}), .{
        .c_source_file = b.path("src/shell/wv2/wv2.h"),
        .target = target,
        .optimize = optimize,
    });
    const options = desktopOptions(b, version, edition).createModule();
    const m = modules(b, target, optimize);
    const exe = b.addExecutable(.{
        .name = "meiolol-shell",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/shell/win.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c", .module = wv2.mod },
                .{ .name = "desktop", .module = desktopModule(b, m, target, optimize, options) },
                .{ .name = "build_options", .module = options },
            },
        }),
    });
    shellUi(b, exe.root_module, m.ui, uiWasm);
    exe.root_module.addWin32ResourceFile(.{ .file = b.path("src/desktop/meiolol.rc") });
    for ([_][]const u8{ "user32", "gdi32", "ole32", "shlwapi", "shell32", "advapi32", "psapi" }) |l|
        exe.root_module.linkSystemLibrary(l, .{});
    exe.subsystem = .windows;
    return exe;
}

/// The app's page (src/shell/screens.zig): the ui module, ui-app.wasm and ui-practice.wasm
/// with their loaders
fn shellUi(b: *std.Build, mod: *std.Build.Module, ui: *std.Build.Module, island: Island) void {
    mod.addImport("ui", ui);
    // Practice's file is embedded in the private edition only (files.zig)
    for ([_][]const u8{ "app", "practice" }) |f| {
        const u = island(b, f);
        mod.addAnonymousImport(b.fmt("{s}.wasm", .{u.name}), .{ .root_source_file = u.wasm });
        mod.addAnonymousImport(b.fmt("{s}.js", .{u.name}), .{ .root_source_file = u.js });
    }
}

fn shellMac(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) *std.Build.Step.Compile {
    const options = desktopOptions(b, 0, .private).createModule();
    const m = modules(b, target, optimize);
    const mod = b.createModule(.{
        .root_source_file = b.path("src/shell/mac.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "desktop", .module = desktopModule(b, m, target, optimize, options) },
            .{ .name = "build_options", .module = options },
        },
    });
    shellUi(b, mod, m.ui, uiWasm);
    mod.linkFramework("AppKit", .{});
    mod.linkFramework("WebKit", .{});
    mod.linkSystemLibrary("objc", .{});
    return b.addExecutable(.{ .name = "meiolol-shell-mac", .root_module = mod });
}

/// The desktop window through dvui's SDL3 backend (src/desktop_dev.zig), for trying it
/// off Windows; SDL3 from the system (Homebrew's on the Mac)
fn desktopDev(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) ?*std.Build.Step.Compile {
    const dvui = b.lazyDependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .sdl3,
        .@"tree-sitter" = false,
    }) orelse return null;
    const mod = b.createModule(.{
        .root_source_file = b.path("src/desktop_dev.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = modules(b, target, optimize).core },
            .{ .name = "net", .module = modules(b, target, optimize).net },
            .{ .name = "dvui", .module = dvui.module("dvui_sdl3") },
        },
    });
    mod.addOptions("build_options", desktopOptions(b, 0, .private));
    // dvui's macOS monitor helper (Objective-C) needs these at link time
    if (target.result.os.tag == .macos) {
        mod.linkFramework("AppKit", .{});
        mod.linkSystemLibrary("objc", .{});
    }
    return b.addExecutable(.{ .name = "meiolol-desktop-dev", .root_module = mod });
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
    const exe = b.addExecutable(.{
        .name = "meiolol-desktop-shot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/desktop_shot.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = modules(b, target, optimize).core },
                .{ .name = "net", .module = modules(b, target, optimize).net },
                .{ .name = "dvui", .module = dvui_mod },
                .{ .name = "raster", .module = raster },
            },
        }),
    });
    exe.root_module.addOptions("build_options", desktopOptions(b, 0, .private));
    return exe;
}

/// Code that must not compile (src/tpl/compile_errors.zig, src/site/ui/compile_errors.zig):
/// every case in one `zig test`, src/tools/compileerrors.zig matching its errors to the
/// cases. It runs every time, as Zig caches no failed compile
fn errorChecks(b: *std.Build, comptime name: []const u8, mod: *std.Build.Module, root: []const u8, cases: anytype) *std.Build.Step {
    const step = b.step(name ++ "-errors", "Check that bad " ++ name ++ " code fails to compile, each with its error");
    const run = b.addRunArtifact(hostTool(b, "compileerrors"));
    for (cases) |c| run.addArg(c.expect);
    run.addArgs(&.{ "--", b.graph.zig_exe, "test", "-fno-emit-bin" });
    var seen: std.ArrayList(*std.Build.Module) = .empty;
    run.addArgs(&.{ "--dep", name });
    run.addPrefixedFileArg("-Mroot=", b.path(root));
    moduleArgs(b, run, &seen, name, mod);
    run.setCwd(b.path("."));
    run.has_side_effects = true;
    step.dependOn(&run.step);
    return step;
}

/// The `zig` command line's `--dep`s and `-M` for `mod`, imported as `name`, and each
/// module under it once
fn moduleArgs(b: *std.Build, run: *std.Build.Step.Run, seen: *std.ArrayList(*std.Build.Module), name: []const u8, mod: *std.Build.Module) void {
    for (seen.items) |m| if (m == mod) return;
    seen.append(b.allocator, mod) catch @panic("OOM");
    for (mod.import_table.keys()) |k| run.addArgs(&.{ "--dep", k });
    run.addPrefixedFileArg(b.fmt("-M{s}=", .{name}), mod.root_source_file.?);
    for (mod.import_table.keys(), mod.import_table.values()) |k, m| moduleArgs(b, run, seen, k, m);
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

/// Training nets on the CPU: std only, library-grade (src/nn/root.zig)
fn nnModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) *std.Build.Module {
    return b.createModule(.{ .root_source_file = b.path("src/nn/root.zig"), .target = target, .optimize = optimize });
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
            .{ .name = "net", .module = m.net },
        },
    });
    const api = b.createModule(.{ .root_source_file = b.path("src/lab/api.zig"), .target = target, .optimize = optimize });
    mod.addImport("api", api);
    mod.addImport("nn", nnModule(b, target, optimize));
    mod.addImport("cand", b.createModule(.{
        .root_source_file = b.path(b.fmt("{s}/root.zig", .{cand})),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "api", .module = api }},
    }));
    mod.addAnonymousImport("kernels.ptx", .{ .root_source_file = kernels.getEmittedAsm() });
    return mod;
}
