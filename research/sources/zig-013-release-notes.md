---
title: Zig 0.13.0 release notes
url: https://ziglang.org/download/0.13.0/release-notes.html
kind: docs
commit: 
for: [zig-good-practice, zig-api-design, zig-memory, zig-build]
looked: 2026-10-22
depth: docs (all except target tables)
relevance: low
grade: A/fair
description: Official release notes for Zig 0.13.0 (2024-06): small release; StaticStringMap, PriorityQueue like ArrayList, std.process.Child, new std.Progress, .zig-cache
---
# Zig 0.13.0 release notes

Why: idiom changes and stated API design direction in 0.13.

## Assessment

- Evidence: A. Canonical reference from the Zig team.
- Reasoning: fair. A short release (LLVM 18 the stated motive); the Progress and
  process.Child sections explain design intent well.
- Interests: none.
- Weigh: few idiom changes; the API-design direction (minimal lifetimes, no undefined
  fields; static buffers with bounds) is the durable part.

## Findings

- [zig/api] Stated direction: types with minimal lifetimes and minimal state with
  undefined fields; e.g. spawn takes options and returns the Child, instead of
  set-fields-then-spawn. ^f1
  > This is a practice that we have been moving more towards in Zig, which is to have types designed to have minimal lifetimes and minimal states with undefined fields.
- [zig/memory] PriorityQueue changed to store items plus cap like ArrayList; the old
  full-slice items field led to reading undefined memory. ^f2
  > This was inconsistent with ArrayList and led to the mistake of accessing undefined memory.
- [zig/api] ComptimeStringMap renamed StaticStringMap(T).initComptime(kvs): one type
  parameter, a named struct, to cut very long type names; faster by storing KVs as
  struct of arrays. ^f3
  > const map = std.StaticStringMap(T).initComptime(kvs_list);
  > Speedup from storing KVs as a struct of arrays
- [zig/perf] New std.Progress: thread-safe, lock-free, infallible Node.start/end over a
  statically allocated buffer, bounded by terminal size. ^f4
  > the `Node.start` and `Node.end` APIs are thread-safe, lock-free, infallible, and do minimal amount of memory loads and stores.
  > A static buffer is sufficient because we can set an upper bound on supported terminal width and height.
- [zig/api] std.Progress.Node is passed by value; std.Progress is initialised once, in
  main; lock stderr (std.debug.lockStdErr) around writes. ^f5
  > Pass around `std.Progress.Node` instead of `*std.Progress.Node` (no longer a pointer).
  > It is illegal to initialize `std.Progress` more than once. Do that in main() and nowhere else.
- [toolchain] std.ChildProcess renamed std.process.Child. ^f6
  > std.process.Child
- [zig/build] `zig-cache` renamed `.zig-cache` (ephemeral, hidden from editors);
  `zig-out` unchanged. ^f7
  > It communicates to new users of Zig that these files are ephemeral.
- [zig/build] A Run step that inherits stdio has side effects, always runs, and takes a
  global lock. ^f8
  > Causes the Run step to be considered to have side-effects, and therefore always execute when it appears in the build graph.
- [zig/build] Windows DLLs install to bin/ by default, matching CMake. ^f9
  > These defaults match CMake's behavior.

## Read

- Standard Library, Build System, Compiler, Toolchain, Roadmap: fully

## Not read

- Target support tables
