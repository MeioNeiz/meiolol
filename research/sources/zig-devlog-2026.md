---
title: Zig devlog 2026 (ziglang.org/devlog/2026)
url: https://ziglang.org/devlog/2026/
kind: article
commit:
for: [zig-good-practice, zig-build, zig-api-design, zig-memory, zig-errors-safety]
looked: 2026-10-22
depth: docs (all 16 entries; SPIR-V, @bitCast and ELF linker entries skimmed)
relevance: high
grade: A/strong
description: Core-team devlog 2026: build system maker/configurer split, package management moved to the build system, zig-pkg and --fork, swappable std.Io (Threaded, Evented), ArrayList pointer-stability locks, lazy type resolution, incremental with LLVM
---
# Zig devlog 2026

Why: the 0.16 and 0.17 changes in the core team's own words, with their reasons.

## Assessment

- Evidence: A. First-hand by Andrew Kelley, Matthew Lugg, Robbie Lyman; build-system
  claim measured (poop table).
- Reasoning: strong for the build rework (three stated goals, a benchmark, the trade-off
  of losing `b.args`) and package workflow (motives, ephemeral `--fork`); fair elsewhere.
- Interests: promotion of the project.
- Weigh: Evented Io is labelled experimental; ArrayList pointer locks landed Aug 2026,
  check they are in the 0.17.0 tag before relying on them.

## Findings

- [zig/build] [toolchain] build.zig now compiles into a small Debug "configurer" whose
  graph is serialised and cached; a Release "maker" runs it. Goal: faster `zig build`. ^f1
  > The primary motivation of this change was to make `zig build` faster, in three ways:
- [zig/build] [zig/perf] Measured: `zig build --help` 150 ms to 14.3 ms (90.4%) because
  the cached configuration skips rerunning build.zig. ^f2
  > wall_time          14.3ms ±  744us    13.2ms … 23.3ms          8 ( 2%)        ⚡- 90.4% ±  0.4%
- [zig/build] [toolchain] `if (b.args) |args| run_cmd.addArgs(args)` becomes
  `run_cmd.addPassthruArgs()`: build scripts can no longer observe run args, so changing
  them no longer rebuilds the script. ^f3
  > This removes a capability from build scripts since they can no longer observe those arguments.
- [zig/build] (inferred) Design consequence for build.zig authors: configure-phase logic must be a
  pure function of options and files it observes; the result is cached. (from
  the serialised, cached configuration) ^f4
  > After this logic finishes constructing a build graph in memory, it is serialized to a binary configuration file.
- [zig/build] Package management now lives in the maker (ReleaseSafe), so fetching runs
  with safety checks and is patchable without rebuilding the compiler. ^f5
  > package management in zig now has safety checks enabled when doing networking, since the maker executable is compiled in `ReleaseSafe` mode
- [zig/build] Fetched packages go to `zig-pkg/` next to build.zig; the team highly
  recommends git-ignoring it; a filtered, recompressed copy sits in the global cache. ^f6
  > It is highly recommended to add this directory to the project-local source control ignore file (e.g. `.gitignore`).
- [zig/build] `zig build --fork=<path>` overrides a package across the whole tree,
  ephemerally, for fixing ecosystem breakage without editing build.zig.zon. ^f7
  > The fact that it is a CLI flag makes it appropriately ephemeral.
- [zig/build] Same fingerprint and equal version with different hashes is now an error
  (fork without renaming, unbumped version, or unreleased changes): bump the version when
  a package changes. ^f8
  > package maintainer neglected to bump version after making changes
- [zig/build] Naked (no build.zig.zon) dependencies can declare `version` and `paths` to
  filter files and get stable, readable hashes (zlib 4.3M to 1.2M). ^f9
  > Now, Zig supports specifying `version` and `paths` for naked packages next to the URL.
- [zig/build] New `zig build --print-tree` (package tree) and `--configure`; `--fetch`
  now fetches all including lazy deps. ^f10
  > `--fetch` is changed to “Fetch all dependencies including lazy ones; exit without configuration”.
- [zig/api] Io is swappable: the same `fn app(io: std.Io)` runs on `std.Io.Threaded` or
  `std.Io.Evented` (io_uring, GCD); only main changes. Evented is experimental. ^f11
  > Key point here being that the `app` function is identical between those two snippets.
  > They should be considered **experimental** because there is important followup work to be done before they can be used reliably and robustly:
- [zig/api] [zig/memory] Construction pattern in that example: allocator first, then
  `var threaded: std.Io.Threaded = .init(gpa, .{...})`, `defer threaded.deinit()`, pass
  `threaded.io()` down. ^f12
  > var threaded: std.Io.Threaded = .init(gpa, .{
- [zig/memory] [zig/safety] `ArrayList.lockPointers()` / `unlockPointers()` assert that
  the list does not reallocate (or reorder) while pointers into it are held, turning a
  silent dangling slice into a panic with a stack trace. ^f13
  > add a call to `lockPointers()` when you first store a pointer to an element or a slice of elements backed by the `ArrayList`, and call `unlockPointers()` when those pointers are no longer needed
- [zig/memory] Slices into an ArrayList dangle after any growth; `pop` and
  `orderedRemove` also trip the lock since ordered lists move elements. ^f14
  > although `orderedRemove()` and `pop()` never allocate, they _will_ trigger the same assertion above after a call to `lockPointers()`
- [zig/style] [zig/comptime] Types that double as namespaces are a common modern pattern;
  since the 0.16 type resolution redesign their fields are analysed only if the type is
  instantiated. ^f15
  > This is important when you have a type which doubles as a namespace, a common pattern in modern Zig.
- [zig/comptime] Dependency loop errors now name every edge of the loop. ^f16
  > note: eliminate any one of these dependencies to break the loop
- [zig/build] Incremental works with LLVM since 0.16; the team has used
  `-fincremental --watch` daily for about a year and calls it relatively stable. ^f17
  > The Zig core team have benefited from incremental compilation in our workflows for a good year now
- [zig/api] std policy on Windows: prefer ntdll native APIs over kernel32, which adds heap
  allocations, failure modes and bloat. ^f18
  > This is why the Zig standard library policy is to [Prefer the Native API over Win32]
- [zig/build] zig libc: libc functions are moving to Zig std wrappers sharing one
  compilation unit, which removes redundant code across the libc boundary. ^f19
  > When the exported libc functions share the ZCU, redundant code is eliminated because functions can be optimized together.

- [zig/comptime] [toolchain] `@bitCast` is redefined on logical bits, endian-agnostic:
  `[2]u8` to `u16` puts element 0 in the low bits on every target (matches old
  little-endian behaviour). ^f20
  > Under the new semantics, because we only care about _logical_ bit representation (which is endian-agnostic), the operation behaves identically on every target
- [zig/perf] [toolchain] LLVM now stores odd-width integers (u4, u40) as ABI-sized in
  memory; the compiler itself got about 5% faster from restored optimisations. ^f21
  > the Zig compiler itself—despite not making heavy use of arbitrary bit width integers internally!—saw around 5% performance improvements from the better optimization

## Read

- All entries; SPIR-V, @bitCast semantics and ELF linker entries skimmed (compiler
  internals, little coding guidance).

## Not read

- codeberg PRs 35428 (maker/configurer), 31403 (type resolution), issue 31131.
