# 13. Build system and packages

## 13.1 Start from the 0.17 `zig init` template

It is the core team's commented reference [[zig-repo-docs#^f1]]:

```zig
// ziglang/zig lib/init/build.zig:31 @ 0.17.0
    const mod = b.addModule("_NAME", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
    });
...
    const exe = b.addExecutable(.{
        .name = "_NAME",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            ...
            .target = target,
            .optimize = optimize,
            ...
            .imports = &.{
                ...
                .{ .name = "_NAME", .module = mod },
            },
        }),
    });
...
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);
    ...
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
```

What it teaches:

- `b.addModule` exposes a named module to dependants; `b.createModule` is for internal
  modules (executable roots, tests). An application nobody depends on can use
  `createModule` everywhere [[zig-talk-build-system-intro#^f6]], [[zig-repo-docs#^f6]]
- always `.root_module`; `root_source_file` on `addExecutable` is gone
  [[zig-015-release-notes#^f27]]
- `standardTargetOptions` and `standardOptimizeOption`, wired into every root module;
  never hardcode a release mode or output paths [[zig-learn-build-system#^f7]],
  [[zig-learn-build-system#^f3]]
- one `addTest` plus `addRunArtifact` per module, all under one `test` step (they run in
  parallel); a test step with no Run step never executes [[zig-learn-build-system#^f12]]
- splitting core logic (library module) from the CLI (exe module) is optional by the
  team's own words [[zig-repo-docs#^f5]]
- steps are cheap: the graph builds only what a requested step reaches
  [[zig-learn-build-system#^f11]]

## 13.2 0.17: configure is cached and pure

build.zig now runs in a separate debug "configurer" whose graph is serialised and
cached; a release "maker" executes it, and `zig build --help` went from 150 ms to 14 ms
[[zig-devlog-2026#^f1]], [[zig-devlog-2026#^f2]]. So the configure phase must have no side
effects and cannot see run arguments; declare inputs (`dependOnFileContents`), prefer
`findProgramLazy` (an eager `findProgram` poisons the cache), and use `b.addTempFiles`
[[zig-017-release-notes#^f33]], [[zig-017-release-notes#^f5]]:

```zig
// ziglang/zig lib/init/build.zig:105 @ 0.17.0
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    run_cmd.addPassthruArgs();
```

## 13.3 Options, generated files, formatting

- build config reaches code through `b.addOptions()`; values are comptime, so code can
  branch or `@compileError` on them; options can default from other options so one flag
  narrows a whole test matrix [[zig-learn-build-system#^f9]], [[zig-repo-docs#^f24]]
- generated files come from an in-tree Zig tool built for `b.graph.host`, passed on as
  LazyPaths (`addOutputFileArg`, `addAnonymousImport`); never use system tools like jq;
  commit generated files only through `UpdateSourceFiles` behind an explicit step
  [[zig-learn-build-system#^f17]], [[zig-learn-build-system#^f20]], [[zls-repo#^f4]]
- the compiler enforces formatting through the graph [[zig-repo-docs#^f26]]:

```zig
// ziglang/zig build.zig:464 @ 0.17.0
    const fmt_include_paths = b.pathList(&.{ "lib", "src", "test", "tools", "build.zig", "build.zig.zon" });
    const fmt_exclude_paths = b.pathList(&.{ "test/cases", "test/behavior/zon" });
    const do_fmt = b.addFmt(.{
        .paths = fmt_include_paths,
        .exclude_paths = fmt_exclude_paths,
    });
    b.step("fmt", "Modify source files in place to have conforming formatting").dependOn(&do_fmt.step);

    const check_fmt = b.step("test-fmt", "Check source files having conforming formatting");
    check_fmt.dependOn(&b.addFmt(.{
        .paths = fmt_include_paths,
        .exclude_paths = fmt_exclude_paths,
        .check = true,
    }).step);
    test_step.dependOn(check_fmt);
```

## 13.4 Entry points and version pin

- a no-install `check` step compiles with full semantic analysis and no codegen, for
  editor and ZLS build-on-save [[kristoff-zls-experience#^f2]]
- one `ci` step as the CI entry point (TigerBeetle runs modes and per-step `max_rss`
  under it); keep entry points few (run, test, fuzz, deploy) and add filters rather than
  steps [[tigerbeetle-code#^f7]], [[matklad-o1-build-file#^f2]]
- pin the Zig version at comptime; Zig breaks APIs every minor and a clear error beats a
  wall of std errors [[ghostty-repo#^f85]], [[tigerbeetle-code#^f1]]:

```zig
// ghostty src/build/zig.zig:4 @ 08a9518
/// Require a specific version of Zig to build this project.
pub fn requireZig(comptime required_zig: []const u8) void {
    // Fail compilation if the current Zig version doesn't meet requirements.
    const current_vsn = builtin.zig_version;
    const required_vsn = std.SemanticVersion.parse(required_zig) catch unreachable;
    if (current_vsn.major != required_vsn.major or
        current_vsn.minor != required_vsn.minor or
        current_vsn.patch < required_vsn.patch)
    {
        @compileError(std.fmt.comptimePrint(
            "Your Zig version v{f} does not meet the required build version of v{f}",
            .{ current_vsn, required_vsn },
        ));
    }
}
```

- build.zig imports nothing from src, to keep build compile time low
  [[tigerbeetle-architecture#^f14]]
- the team's dev loop: `zig build -fincremental --watch` on a native-only test step
  [[zig-016-release-notes#^f38]]. 0.17 incremental is x86_64 Linux only; on macOS a
  `-Dno-bin` check step may still be the fast loop
- `--time-report` finds slow declarations [[zig-015-release-notes#^f29]]

## 13.5 Large builds

Ghostty split a build.zig that "became far too complex" into a `src/build/` package: one
`Config` struct holds every `-D` option, one struct per artifact takes `*const Config`
and `*const SharedDeps`, and the same Config is written into a `build_options` module and
rehydrated at comptime in app code [[ghostty-repo#^f82]], [[ghostty-repo#^f83]]. ZLS
factors module creation into functions taking an options struct
[[zls-repo#^f3]]. Since 0.16 a file may belong to only one module per compilation, so
create a shared dependency module once [[ghostty-repo#^f88]].

## 13.6 Packages (build.zig.zon)

- the hash is the truth, the url a mirror: change the url, delete the hash
  [[zig-repo-docs#^f20]]
- `fingerprint` plus name identify a package; regenerate it only when forking a live
  project; `paths` lists only what is compiled plus licences [[zig-repo-docs#^f22]]
- 0.17 keeps fetched deps in a project-local `zig-pkg/`: git-ignore it; same fingerprint
  and version with a different hash is now an error, so bump versions
  [[zig-devlog-2026#^f6]], [[zig-devlog-2026#^f8]]
- optional heavy dependencies are lazy (`b.lazyDependency`; 0.17 adds
  `dependencyLazy`, which returns an error you can `try`) so they are fetched only when
  used [[zig-017-release-notes#^f35]], [[zls-repo#^f2]]
- `minimum_zig_version` is advisory only [[zig-repo-docs#^f23]]
- `--fork` replaces editing a `.path` into the zon for co-development
  [[zig-devlog-2026#^f7]]
- TigerBeetle's policy for long-lived projects: zero dependencies, and scripts written
  in Zig too, so there is one language and no shell dialect
  [[tigerbeetle-tiger-style#^f46]], [[tigerbeetle-blog-automation#^f1]]
