---
title: Packages, Modules, Dependencies - Zig Build System Basics (Loris Cro, Zig SHOWTIME 2025)
url: https://www.youtube.com/watch?v=jy7w_7JZYyw
kind: video
commit:
for: [zig-build]
looked: 2026-10-22
depth: docs (whole transcript, uploader's captions)
relevance: high
grade: A/strong
description: ZSF VP Loris Cro on build.zig basics for 0.14: build graph not build, packages expose modules and artifacts, b.addModule vs b.createModule, imports, b.dependency, zig fetch --save, .path deps for co-development
---
# Packages, Modules, Dependencies - Zig Build System Basics

Why: fills the gap the official build guide leaves ([[zig-learn-build-system#^f23]]):
modules, `addModule` vs `createModule`, dependencies. Linked from the 2025 devlog.

## Assessment

- Evidence: A. Loris Cro (ZSF VP of Community) in the official Zig SHOWTIME channel,
  announced on the ziglang.org devlog; uploader-written captions, so wording is exact.
- Reasoning: strong. Explains why each call exists (naming exposes a module, add vs
  create, why install is explicit) and when to choose each style.
- Interests: none beyond the project.
- Weigh: made for 0.14.0 (he says so); concepts unchanged in 0.17, but zig fetch's
  path-to-url bug is fixed or moot and 0.17 adds zig-pkg/ and `--fork`
  ([[zig-devlog-2026#^f6]], [[zig-devlog-2026#^f7]]), a better co-development tool than
  editing `.path` into the zon.

## Findings

- [zig/build] The build system is userland code that invokes compiler subcommands; read
  the CLI invocations (`--verbose`) to debug. @0:29 ^f1
  > The build system is entirely implemented in userland and all it does is invoke other Zig compiler subcommands with their cli arguments set correctly.
- [zig/build] build.zig describes a graph, it does not perform the build; that is what
  buys dependency tracking, parallelism and caching. @0:29 ^f2
  > The code you write in your build.zig file will describe a build graph, instead of performing the build immediately.
- [zig/build] A package can expose modules, static and dynamic libraries, objects,
  executables, any source file, and files generated on demand. @1:27 ^f3
  > A Zig package can expose to consumers: - Zig Modules (that's what you import
- [zig/build] build.zig.zon `paths` lists the package's files; anything not listed is
  deleted after download (keep test data out). @3:09 ^f4
  > Any file not listed here will be deleted after the package is downloaded as a dependency, which is useful to exclude stuff like data files only used for tests.
- [zig/style] [zig/build] Convention: sources under `src/`, a module's entry point named
  `root.zig`; consumers see only the root file, so re-export from it. @4:39 ^f5
  > it's not a bad idea to put your source code under a directory named `src` and to name the entry point of a module `root.zig`
  > consumers of your module will only be able to access the root file, so you need to make sure to re-export from it any declaration defined in other files that belong to the module
- [zig/build] `b.addModule(name, ...)` registers a named module in the graph that
  dependants can get by name, even if the return value is discarded. @5:55 ^f6
  > addModule returns a pointer to our module, which we are now discarding, but the module itself still exits and it also has been registered in the graph, meaning that even if we discard here the return value, consumers will still be able to access the module via its name
- [zig/build] Use `b.createModule` for modules you don't want to expose, such as an
  executable's root module; add registers in the graph, create does not, and the build
  API uses add/create with that meaning often. @7:21 ^f7
  > instead of using b.addModule we use b.createModule
  > the main difference between these functions is that addModule also adds the module to graph, while createModule does not. The build system tends to use the verbs "add" and "create" with that implication often times.
- [zig/build] Split business logic (an exposed library module) from the CLI (its own
  unexposed root module importing the library), to keep CLI-only deps away from
  consumers. @9:09 ^f8
  > In a realistic scenario you would probably want to add dependencies to the executable that have nothing to do with the core parsing library and keeping the two separate helps reducing complexity for your consumers.
- [zig/build] Import names are set by the importer and can rename modules; the module's
  registered name is only the lookup key. @8:14 ^f9
  > in the Zig build system you have the ability to rename your imports, which is extremely useful in case of collisions for example
- [zig/build] Without target and optimize options an executable can't be cross-compiled
  or release-built by users. @9:09 ^f10
  > If we leave this part unspecified, users won't be able to cross-compile the CLI tool, nor create optimized release builds.
- [zig/build] Installing is explicit because some executables only run inside the build
  pipeline or behind a flag. @10:22 ^f11
  > not all executables defined in a build script should be installed unconditionally
- [zig/build] `.imports = ...` in createModule and `mod.addImport(...)` are equivalent;
  addImport suits conditional or circular imports. @14:08 ^f12
  > Neither is preferable to the other so choose which style works best for your use case.
  > the addImport function call has the advantage that you can easily place it under branching and that you can also use it to define circular imports
- [zig/build] Share Zig code as modules, not static libraries; static libraries are for C
  ABI interop (the 0.14 zig init template misled people). @13:18 ^f13
  > I suspect that some people might have mistaken it as the preferred way of sharing Zig code, while in reality that would be modules
- [zig/build] `b.dependency(name, .{ .target = ..., .optimize = ... })` passes the
  dependency's own -D options; `dep.module("json")` fetches its named module. @14:08 ^f14
  > These options are the same CLI options that we defined in the myjson build script.
- [zig/build] `zig fetch --save git+https://...` pins a ref to a commit hash in the zon. @12:26 ^f15
  > When the ref you pass is not a commit, it will be resolved to a commit first, and then hardcoded in the zon file as a commit hash.
- [zig/build] [toolchain] Stale for 0.17 detail: setting `root_source_file` directly on
  addExecutable was deprecated then in favour of an explicit root module (now the only
  way). @7:21 ^f16
  > it's possible to define directly a root file for the executable, but that it's being deprecated in favor of defining a module explicitly

## Read

- Whole transcript.

## Not read

- Follow-up videos in the series (fingerprint, lazy deps), if made.
