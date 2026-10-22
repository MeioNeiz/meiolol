---
title: Zig devlog 2025 (ziglang.org/devlog/2025)
url: https://ziglang.org/devlog/2025/
kind: article
commit:
for: [zig-good-practice, zig-api-design, zig-memory, zig-perf, zig-build]
looked: 2026-10-22
depth: docs (all 14 entries)
relevance: high
grade: A/strong
description: Core-team devlog 2025: std.Io async DNS connect example, DebugAllocator rework and SmpAllocator (benchmarks vs glibc), self-hosted x86 default in Debug, parallel codegen, watch+incremental loop
---
# Zig devlog 2025

Why: the core team's own reasoning on std.Io, allocators and the dev loop, with numbers.

## Assessment

- Evidence: A. First-hand by Andrew Kelley, Matthew Lugg and others; perf claims come
  with poop benchmark tables (runs, mean and sigma).
- Reasoning: strong for the allocator and backend entries (problem, design, measured
  result, remaining limits); the Io entry lists properties but no benchmark.
- Interests: promotion of Zig vs C/libc and LLVM.
- Weigh: SmpAllocator vs glibc numbers are on the compiler itself (one workload); the
  whole-compiler build is a wash (0.0%), so "outperforms" holds for one test case.
  Io code is 0.16-era master and close to 0.17 API, check names against std.

## Findings

- [zig/api] std.Io connect example: `io.async` plus `Io.Queue` and `Io.Group` race DNS
  and TCP connects, cancel the losers in `defer`, with no heap allocation (fixed
  buffers on the stack). "Async DNS Resolution" ^f1
  > var connect_many = io.async(connectMany, .{ host_name, io, port, &connect_many_queue, options });
  > No heap allocation.
- [zig/api] The same Io code behaves optimally whether Io is threads or an event loop,
  and still works with single-threaded blocking Io. ^f2
  > Regardless of whether `Io` is implemented via threads, or via an event loop, this code behaves optimally.
  > The code also works when using single-threaded, blocking `Io` even though the operations happen sequentially.
- [zig/api] [zig/errors] Design goal: async code reads like normal Zig, with try, defer
  and while and the usual resource patterns; no function colouring. ^f3
  > We still use all the reguar control flow: `try`, `defer`, `while`, etc.
  > we can insert `try foo` almost anywhere and rest assured that the same resource management patterns have the error handling taken care of
- [zig/api] Io convention: `io: Io` is passed as an explicit parameter, like an allocator,
  and every blocking call takes it (`getOne(io)`, `close(io)`). ^f4
  > pub fn connectMany(
- [zig/errors] Error handling style in std: switch over the error, return the fatal
  ones, aggregate the rest, map impossible `WouldBlock` to `error.Unexpected`. ^f5
  > error.WouldBlock => return error.Unexpected,
- [zig/build] Fast dev loop the creator uses: `--watch -fincremental` on a native-only
  test step; errors appear on save. ^f6
  > zig build test-std -Dno-matrix --watch -fincremental
- [zig/build] [zig/test] Add a build option that narrows the test matrix to native for
  inner-loop work (`-Dno-matrix`). ^f7
  > it only runs the default, native target tests
- [zig/memory] [zig/comptime] DebugAllocator rework: metadata inline on the page, slot
  counts computed by a comptime function, with an assert that turns bad constants into a
  compile error instead of a handcrafted table. "No-Libc Zig Now Outperforms Glibc Zig" ^f8
  > That assert at the end means if the constraints could not be satisfied you get a compile error.
- [zig/memory] [zig/perf] The DebugAllocator rework cut a debug ast-check run from 22.8 s
  to 20.5 s (10.1%) and peak RSS 6.2%. ^f9
  > wall_time          20.5s  ± 95.8ms    20.4s  … 20.6s           0 ( 0%)        ⚡- 10.1% ±  1.5%
- [zig/memory] SmpAllocator is designed for multi-threaded ReleaseFast programs: thread
  local state to avoid contention, cross-thread reclaim for producer-consumer patterns. ^f10
  > one that was designed for multi-threaded applications built in ReleaseFast mode
- [zig/memory] [zig/perf] SmpAllocator vs glibc malloc on one ast-check: 4.9% faster wall
  time, 12.1% less RSS; whole compiler self-build: no wall-time difference. ^f11
  > wall_time           149ms ± 1.87ms     146ms …  156ms          1 ( 3%)        ⚡-  4.9% ±  1.5%
  > wall_time          12.2s  ± 49.0ms    12.2s  … 12.3s           0 ( 0%)          +  0.0% ±  1.5%
- [zig/memory] [toolchain] Page size is runtime-known since 0.14; Kelley calls making it
  comptime-known his mistake. ^f12
  > My fault for originally making page size compile-time known.
- [zig/build] [zig/perf] Self-hosted x86_64 backend default for Debug on Linux/macOS from
  0.15: hello world 918 ms to 275 ms (70%), compiler 75 s to 20 s. ^f13
  > For a larger project like the Zig compiler itself, it takes the time down from 75 seconds to 20 seconds.
- [zig/build] Parallel codegen on self-hosted backends: 5% to 50% faster wall time; the
  LLVM backend stays single-threaded. ^f14
  > we saw anywhere from 5% through to 50% improvements in wall-clock time for compiling Zig projects
- [zig/safety] `zig cc` enables `-fsanitize=undefined` by default for C and now has a
  UBSan runtime that prints the error and location instead of SIGILL. ^f15
  > When compiling C with `zig cc`, Zig provides better defaults, including implicitly enabling `-fsanitize=undefined`.
- [zig/build] Loris Cro's build-system video shows exposing a module from a package and
  importing it from another project (lead, [[zig-learn-build-system]] lacks this). ^f16
  > In the video I show how to create a package that exposes a Zig module and then how to import that module in another Zig project.

## Read

- All entries on the 2025 page.

## Not read

- PR #25592 (std: Introduce Io Interface), SmpAllocator source, the build-system video
  (read separately if fetched).
