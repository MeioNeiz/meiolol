---
title: Zig Build System guide (ziglang.org/learn)
url: https://ziglang.org/learn/build-system/
kind: docs
commit:
for: [zig-build, zig-testing]
looked: 2026-10-22
depth: docs (whole page)
relevance: high
grade: A/fair
description: The official build.zig guide: steps DAG, install prefix, options, libraries, tests, generated files, multi-target release; examples run on 0.17.0 CI
---
# Zig Build System guide (ziglang.org/learn)

Why: the main official build.zig doc; what it says about steps, options, modules, tests,
generated files and cross-compilation, and why.

## Assessment

- Evidence: A. Official ziglang.org page; its shell outputs are produced by the site's CI
  on zig-x86_64-linux-0.17.0, so the examples that print success ran on 0.17.
- Reasoning: fair. Gives the why for the install prefix, the DAG, standard options, package
  deps over system libs and in-tree tools over system tools; most sections are just
  examples.
- Interests: none beyond promoting the build system.
- Weigh: trust the examples with a CI success output. Two parts are stale: the testing
  example fails to compile on 0.17 (its own output shows the error), and the "Mutating
  Source Files" example uses pre-0.14 API with no CI output. Large gaps: nothing on
  `b.addModule` vs `b.createModule`, `b.dependency`, build.zig.zon, lazy dependencies,
  exposing modules or artifacts to dependants, C source files or translate-c.

## Findings

- [zig/build] Use the build system when the command line gets unwieldy, there are many
  steps, options, target-dependent logic, dependencies, or to avoid cmake/make/python. ^f1
  > You want to avoid an unnecessary dependency on cmake, make, shell, msvc, python, etc., making the project accessible to more contributors.
- [zig/build] The build is a DAG of steps run independently and concurrently; the default
  step is Install, which starts empty, so a build script must add what to install. ^f2
  > the main step in the graph is the **Install** step, whose purpose is to copy build artifacts into their final resting place
- [zig/build] Never hardcode output paths: the user picks the prefix; hardcoding breaks
  caching, concurrency and composability. ^f3
  > The build script cannot hardcode output paths because this would break caching, concurrency, and composability, as well as annoy the final user.
- [zig/build] `.zig-cache` is not for source control and can be deleted at any time. ^f4
  > these files are not intended to be checked into source-control and this directory can be completely deleted at any time with no consequences
- [zig/build] Run convenience step pattern: `b.addRunArtifact(exe)` then
  `b.step("run", ...).dependOn(&run_exe.step)`. `build-system` "Adding a Convenience Step" ^f5
  > const run_step = b.step("run", "Run the application");
- [zig/build] `b.option` makes the script configurable for end users and for projects that
  depend on it as a package; options appear in `zig build --help` automatically. ^f6
  > Use `b.option` to make the build script configurable to end users as well as other projects that depend on the project as a package.
  > This part of the help menu is auto-generated based on running the `build.zig` logic.
- [zig/build] Prefer `standardTargetOptions` and `standardOptimizeOption` over hand-rolled
  options: they set the naming convention (-Dtarget, -Doptimize). ^f7
  > In order to encourage standard naming conventions for these options, Zig provides the helper functions, `standardTargetOptions` and `standardOptimizeOption`.
- [zig/build] No release mode is the default preference: the user must choose to make a
  release build. ^f8
  > By default none of the release options are considered the preferable choice by the build script, and the user must make a decision in order to create a release build.
- [zig/build] [zig/comptime] Pass build config into code with `b.addOptions()` and
  `root_module.addOptions("config", options)`; the values are comptime-known in the code,
  so `@compileError` can gate on them. ^f9
  > the data provided by `@import("config")` is comptime-known, preventing the `@compileError` from triggering
- [zig/build] Every artifact is built with `.root_module = b.createModule(.{...})`; the
  page never shows `b.addModule`. ^f10
  > .root_module = b.createModule(.{
- [zig/build] Declaring an artifact costs nothing unless a requested step depends on it:
  the DAG builds only what is needed. ^f11
  > the build system in fact does not waste any time building the `demo` executable unless it is requested with `-Denable-demo`
- [zig/build] [zig/test] Tests are two steps, Compile and Run; without `addRunArtifact`
  the tests are built but never run. ^f12
  > Without a call to `addRunArtifact`, which establishes a dependency edge between these two steps, the unit tests will not be executed.
- [zig/test] Writing to stdout in unit tests is problematic: the build runner and test
  runner talk over stdin/stdout to run suites concurrently. ^f13
  > This is one reason why [writing to _standard out_ in unit tests is problematic](https://github.com/ziglang/zig/issues/15091) - it will interfere with this communication channel.
- [zig/build] [zig/test] Test across targets by looping over `std.Target.Query` values and
  set `skip_foreign_checks = true` so foreign-target tests skip instead of failing. ^f14
  > run_unit_tests.skip_foreign_checks = true;
- [zig/test] [toolchain] Stale on the page itself: its testing example uses
  `std.ArrayList(i32).init(std.testing.allocator)`, which fails to compile on 0.17
  (unmanaged ArrayList), as the page's own CI output shows. ^f15
  > error: struct 'array\_list.Aligned(i32,null)' has no member named 'init'
- [zig/build] Get libraries through the build system (packages) by default: reproducible,
  every OS, cross-compiles, exact versions; system libraries are for distro packagers. ^f16
  > This is expected to be the generally preferred way to depend on external libraries.
  > for the use case of packaging software into repositories such as Debian, Homebrew, or Nix, it is mandatory to link against system libraries
- [zig/build] Prefer a Zig tool in the source tree over a system tool (jq) for generating
  files: system dependencies make the project harder to build. ^f17
  > Be aware that system dependencies will make your project harder to build for your users.
  > The next section will replace `jq` with a Zig tool included in the source tree, which is the preferred approach.
- [zig/build] Generated outputs flow as LazyPaths: `addOutputFileArg` on a Run step, then
  `addAnonymousImport` to import generated Zig or embed a generated asset. ^f18
  > exe.root_module.addAnonymousImport("word", .{
- [zig/build] Build tools for the host (`b.graph.host`), not the user's target. ^f19
  > .target = b.graph.host,
- [zig/build] Commit generated files only with UpdateSourceFiles behind an explicit step;
  never during the normal build (caching and concurrency bugs). ^f20
  > If it is done during the normal build process, it will cause caching and concurrency bugs.
- [zig/build] [toolchain] Stale: the UpdateSourceFiles example passes `.root_source_file`
  straight to `addExecutable` and uses `std.fs.cwd()` and `std.io.getStdIn()`, pre-0.15
  API, and shows no 0.17 CI output. ^f21
  > .root_source_file = b.path("tools/proto_gen.zig"),
- [zig/build] Cross-compiled releases: loop over target queries with
  `b.resolveTargetQuery`, install each into its own `zigTriple` subdirectory. ^f22
  > .custom = try t.zigTriple(b.allocator),
- [zig/build] Checked, not there: no section on `b.addModule` vs `b.createModule`,
  `b.dependency`, build.zig.zon, lazy dependencies or exposing artifacts to dependants; the
  system libraries section points to a "Package Management" section the page lacks. ^f23
  > Provide these libraries via the Zig Build System (see Package Management and
- [zig/build] [toolchain] The 0.17 help lists `--fork` to override projects in the
  dependency tree, `--test-timeout`, `-fincremental` and `--fuzz[=limit]`. ^f24
  > --fork=\[path\], --fork \[path\] Override one or more projects from dependency tree

## Read

- Whole page, including the 0.17 `zig build --help` output.

## Not read

- Linked issues (#15091 stdout in tests, #1356 expect panic, #14281 detect system mode).
