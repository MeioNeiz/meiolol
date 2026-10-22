---
title: Zig devlog 2024 (ziglang.org/devlog/2024)
url: https://ziglang.org/devlog/2024/
kind: article
commit:
for: [zig-good-practice, zig-api-design, zig-perf, zig-style]
looked: 2026-10-22
depth: docs (all 10 entries, Sep to Dec 2024)
relevance: medium
grade: A/fair
description: Core-team devlog entries Sep to Dec 2024: naming integers with non-exhaustive enums, anonymous struct types removed, labeled switch tokenizer, multi-object for loops, incremental, --watch
---
# Zig devlog 2024

Why: core-team statements on how they write Zig, from their own work log.

## Assessment

- Evidence: A for what the team does (first-hand, by Andrew Kelley and Matthew Lugg).
- Reasoning: fair. Short entries; the naming-integers one gives its reason (compile errors
  over runtime bugs), the tokenizer one a measured number.
- Interests: none beyond promoting the project.
- Weigh: the idioms (index enums, labeled switch, multi-object for) are current in 0.17;
  the incremental notes are early-state and stale.

## Findings

- [zig/api] [zig/safety] Andrew Kelley names integer indexes as distinct non-exhaustive
  `enum(u32) { _ }` types in all his projects, so the type system catches mixed-up
  indexes at compile time. "The Unreasonable Effectiveness of Naming Integers" ^f1
  > It’s uncanny how effective it is to avoid bugs by simply naming integers and thereby giving Zig’s type system a chance to catch mistakes.
- [zig/api] Optional index without `?`: a sibling enum with a `none = maxInt(u32)` tag and
  `unwrap`/`toOptional` conversions, keeping the index 4 bytes. ^f2
  > none = std.math.maxInt(u32),
  > pub fn unwrap(i: OptionalObjectFunctionIndex) ?ObjectFunctionIndex {
- [zig/style] Each index type carries a doc comment naming the array it indexes. ^f3
  > /// Index into `function_imports`.
- [zig/comptime] [toolchain] Anonymous struct types are gone (0.14): `.{ .x = 123 }`
  without a result type gets an ordinary struct type with no structural coercion. ^f4
  > You can still write `.{ .x = 123 }` without a result type, but it’s given a “normal” struct type, with no magical coercions allowed.
- [zig/perf] Labeled switch with `continue :state` for state machines: rewriting the
  tokenizer measured a 13% wall-time gain for `zig ast-check`. ^f5
  > measuring a 13% wall time performance increase for the `zig ast-check` command
  > state: switch (State.start) {
- [zig/style] Multi-object `for` over parallel slices with pointer captures, `@min` and
  `@abs` replace an index loop with casts (stb_truetype port). ^f6
  > for (scanline, scanline2, result.pixels[j*result.stride..][0..result.w]) |s, s2, *p| {
- [zig/build] `zig build --watch` reruns invalidated steps on any file-system input
  change (macOS and BSDs from Oct 2024). ^f7
  > This feature tracks all file system inputs, automatically repeating invalidated build steps.
- [zig/build] [toolchain] Incremental compilation in 2024 needed `use_llvm = false` and
  was buggy (stale; see [[zig-devlog-2026]] for LLVM incremental). ^f8
  > Make sure your `Step.Compile` has `.use_llvm = false, .use_lld = false`
- [zig/comptime] Self-referential global values (a const holding a pointer to itself)
  compile since late 2024. ^f9
  > Previously, both of the examples above would have failed with a “dependency loop detected” error

## Read

- All entries on the 2024 page (the page starts at Sep 2024; earlier ones are in the
  old devlog, not read).

## Not read

- Pre-September 2024 devlog (old single page).
