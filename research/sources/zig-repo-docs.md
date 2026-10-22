---
title: 'ziglang/zig repo docs at 0.17.0: README Contributing, doc/build.zig.zon.md, zig init template, compiler build.zig'
url: https://codeberg.org/ziglang/zig
kind: project
commit: 7647adab80dd088f4de3610fd245915a912eb6ad
for: [zig-build, zig-testing, zig-good-practice]
looked: 2026-10-22
depth: code (README.md Contributing, doc/build.zig.zon.md, lib/init/*, build.zig options, fmt and test steps)
relevance: high
grade: A/strong
description: Zig's own repo at the 0.17.0 tag: the zig init template (the official commented build.zig), the build.zig.zon field reference, the compiler's build.zig as a large real example, and the contribution rules
---
# ziglang/zig repo docs at 0.17.0

Why: the conventions the core team writes into the repo itself; the `zig init` template
is the most direct official statement of how build.zig should look in 0.17.

## Assessment

- Evidence: A. The canonical repo; moved from GitHub (43k stars, 3.1k forks, about 1,334
  contributors, last GitHub push 2025-11-27) to codeberg.org/ziglang/zig, which the site
  links as Source. Tag 0.17.0 = 7647adab; master (b9c3d39b, 2026-10-22) differs only in
  two comments in lib/init and three lines in the zon doc.
- Reasoning: strong in the init template (each call explained, alternatives named) and
  the zon doc (why `hash` is the source of truth, why the fingerprint never changes).
- Interests: none.
- Weigh: no CONTRIBUTING.md or style guide file exists; the README's Contributing
  section is process, not code style. Style lives in the langref (other reader).

## Findings

- [zig/build] build.zig only mutates a graph that an external runner executes, which is
  what lets it parallelise and cache. `lib/init/build.zig:3` ^f1
  > Although this function looks imperative, it does not perform the build
- [zig/build] Default to `standardTargetOptions(.{})` and `standardOptimizeOption(.{})`
  with no preferred release mode; the user decides. `lib/init/build.zig:14` ^f2
  > set a preferred release mode, allowing the user to decide how to optimize.
- [zig/build] Modules are the preferred way to share Zig code; `b.addModule` needs a name
  because a package can expose several. `lib/init/build.zig:26` ^f3
  > Zig modules are the preferred way of making Zig code available to consumers.
  > We must give it a name because a Zig package can expose
- [zig/build] [zig/style] A module's root file is its public surface: re-export from it
  what consumers need. `lib/init/build.zig:32` ^f4
  > this module will only be able to access public declarations contained
- [zig/build] The template splits a library module (src/root.zig) from the CLI
  (src/main.zig) and says to delete the split if neither part needs the other.
  `lib/init/build.zig:44` ^f5
  > it's sometimes preferable to split business
  > logic and the CLI into two separate modules.
  > If neither case applies to you, feel free to delete the declaration you
- [zig/build] `b.createModule` defines a module without exposing it, so it needs no
  name; use it for executable root modules. `lib/init/build.zig:63` ^f6
  > b.createModule defines a new module just like b.addModule but,
  > unlike b.addModule, it does not expose the module to consumers of
- [zig/build] Target and optimize must be wired explicitly into the root module of every
  executable or library (or hardcoded, e.g. firmware). `lib/init/build.zig:67` ^f7
  > Target and optimization levels must be explicitly wired in when
- [zig/build] Imports are named by the importer: `.imports = &.{ .{ .name = ..., .module =
  mod } }`, renamable to avoid collisions. `lib/init/build.zig:75` ^f8
  > repeated because you are allowed to rename your imports, which
- [zig/build] Run step pattern for 0.17: `addRunArtifact`, depend on the install step so
  it runs from the prefix, `addPassthruArgs()` for `zig build run -- args`.
  `lib/init/build.zig:105` ^f9
  > run_cmd.addPassthruArgs();
- [zig/build] [zig/test] A test executable tests one module, so the template makes one
  `addTest` per module and one `test` step depending on both run steps, which run in
  parallel. `lib/init/build.zig:119` ^f10
  > Note that test executables only test one module at a time,
  > hence why we have to create two separate ones.
- [zig/build] The build system is userland and simple: watch the subcommand invocations
  and read its source to master it. `lib/init/build.zig:145` ^f11
  > reading its source code will allow you to master it.
- [zig/style] [zig/build] root.zig is the conventional root source file of a package. `lib/init/src/root.zig:1` ^f12
  > By convention, root.zig is the root source file when making a package.
- [zig/api] Accept `*Io.Writer` to write reusable output code; return
  `Io.Writer.Error!void`. `lib/init/src/root.zig:7` ^f13
  > Accepting an `Io.Writer` instance is a handy way to write reusable code.
- [zig/api] [zig/memory] main gets `std.process.Init`: `init.arena` for process-lifetime
  allocations, `init.io` for I/O; stdout through a stack buffer and
  `Io.File.Writer`, then flush. `lib/init/src/main.zig:10` ^f14
  > This is appropriate for anything that lives as long as the process.
  > try stdout_writer.flush(); // Don't forget to flush!
- [zig/api] stdout is for program output only; debug messages go to stderr via
  `std.debug.print`. `lib/init/src/main.zig:22` ^f15
  > Stdout is for the actual output of your application
- [zig/memory] [zig/test] Unmanaged containers in 0.17: `var list: std.ArrayList(i32) =
  .empty; defer list.deinit(gpa); try list.append(gpa, 42);` with
  `std.testing.allocator` catching leaks. `lib/init/src/main.zig:35` ^f16
  > defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
- [zig/test] The template ships a fuzz test: `std.testing.fuzz({}, testOne, .{})` with a
  `*std.testing.Smith` that draws values, bytes and ranges. `lib/init/src/main.zig:42` ^f17
  > try std.testing.fuzz({}, testOne, .{});
- [zig/build] `name` should not contain "zig" (redundant inside the Zig package
  namespace). `doc/build.zig.zon.md:20` ^f18
  > It is redundant to include "zig" in this name because it is already within the
- [zig/build] `fingerprint` never changes; regenerate it when forking a maintained
  project, else the fork is hostile. `doc/build.zig.zon.md:29` ^f19
  > When forking a Zig project, this fingerprint should be regenerated if the upstream
- [zig/build] `hash` is the source of truth, `url` only a mirror; change the url, delete
  the hash. `doc/build.zig.zon.md:81` ^f20
  > This field is the source of truth; packages do not come from a `url`; they
  > When updating this field to a new URL, be sure to delete the corresponding
- [zig/build] `lazy = true` fetches a dependency only if used; `path` deps skip hashing. `doc/build.zig.zon.md:100` ^f21
  > When this is set to `true`, a package is declared to be lazily fetched.
- [zig/build] `paths` rule of thumb: files needed to compile plus licences; only listed
  files are hashed and kept. `lib/init/build.zig.zon:66` ^f22
  > As a rule of thumb, one should list
  > files required for compilation plus any license(s).
- [zig/build] `minimum_zig_version` is advisory only. `doc/build.zig.zon.md:65` ^f23
  > This is currently advisory only; the compiler does not yet do anything
- [zig/build] [zig/test] The compiler's build.zig derives options from options
  (`skip-release` defaults to `no-matrix`) so one flag narrows the test matrix.
  `build.zig:108` ^f24
  > const skip_release = b.option(bool, "skip-release", "Main test suite skips release builds") orelse no_matrix;
- [zig/build] Enum-typed and list-typed build options: `b.option(IoMode, ...)`,
  `b.option([]const []const u8, "test-filter", ...)` passed to each test step. `build.zig:203` ^f25
  > const io_mode = b.option(IoMode, "io-mode", "How the compiler performs IO") orelse .threaded;
  > const test_filters = b.option([]const []const u8, "test-filter", "Skip tests that do not match any filter") orelse &[0][]const u8{};
- [zig/build] [zig/style] A `fmt` step (rewrite) and a `test-fmt` step (`.check = true`)
  over the same path lists; `test` depends on the check. `build.zig:466` ^f26
  > const check_fmt = b.step("test-fmt", "Check source files having conforming formatting");
- [zig/build] Helper functions take `b` plus an options struct
  (`addCompilerMod(b, options)`) to share module setup between the exe and its tests. `build.zig:890` ^f27
  > fn addCompilerMod(b: *std.Build, options: AddCompilerModOptions) *std.Build.Module {
- [zig/build] [zig/perf] Memory budgets as build facts: `max_rss` on the compiler step,
  "should never be raised". `build.zig:907` ^f28
  > This number should never be raised. If the value is exceeded, then
- [toolchain] 0.17.0's own build.zig uses `std.lang.Optimize` with lowercase
  `.debug/.safe/.fast/.small`. `build.zig:437` ^f29
  > var chosen_opt_modes_buf: [4]std.lang.Optimize = undefined;
- [zig] Governance is BDFN: Kelley has the final say; language proposals are not
  accepted; real use cases are the most valued argument. `README.md:461` ^f30
  > keep in mind that Zig governance is BDFN (Benevolent
  > Language proposals are not accepted.
  > The most highly regarded argument in such a discussion is a real world use case.
- [zig] Strict no-LLM policy for issues, patches and tracker comments. `README.md:489` ^f31
  > No LLMs for patches / pull requests.
- [zig/style] Checked, not there: no CONTRIBUTING.md, style guide or lint config in the
  repo at 0.17.0; formatting is enforced by `zig fmt` via `test-fmt`. ^f32

## Read

- README.md Contributing and Testing sections; doc/build.zig.zon.md; lib/init/ whole;
  build.zig lines 1-120, 430-640, 880-960.

## Not read

- doc/langref (other reader); test/tests.zig (test matrix helpers); tools/.
