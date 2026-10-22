---
title: Copy Hunting (TigerBeetle blog, matklad, 2023)
url: https://tigerbeetle.com/blog/2023-07-26-copy-hunting
kind: article
commit:
for: [zig-perf, zig-comptime]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: grep LLVM IR (-femit-llvm-ir) for large implicit memcpys and for comptime monomorphisation bloat; copyhound.zig
---
# Copy Hunting (TigerBeetle blog, matklad, 2023)

Why: practical ways to find hidden copies and comptime code bloat in Zig.

## Assessment

- Evidence: B. Tool used on TigerBeetle and the Zig compiler (found a 10 KB stack
  frame, fixed upstream); `src/copyhound.zig` still in the repo at 0450c32.
- Reasoning: strong: minimal example first, then the tool, admits it is not in CI.
- Interests: none.
- Weigh: Zig 0.10/0.11 syntax in snippets (`for (a) |x, i|`, `@setCold`,
  `std.meta.trait`, `callconv(.C)`), all stale for 0.17 (`@branchHint(.cold)`,
  `for (a, 0..) |x, i|`).

## Findings

- [zig/perf] Idiomatic Zig can compile to implicit copies of large values; by-value
  loop captures are a known case, fixed with `|*item|`. ^f1
  > naive compilation of idiomatic code can introduce a bunch of local variable copies.
  > One particular issue we fixed a couple of times in TigerBeetle is replacing by-value with by-pointer loops:
- [zig/perf] `zig build-lib -femit-llvm-ir` gives greppable text IR; copyhound scans
  it for `memcpy` above a size threshold. ^f2
  > $ zig build-lib -femit-llvm-ir example.zig
  > look for lines with `memcpy`, do some comma counting to find the third argument, and check it against a threshold.
- [zig/perf] [zig/comptime] `std.meta.eql` on plain byte structs caused copies;
  replaced by `equal_bytes`, which asserts at comptime that bytewise comparison is
  valid. ^f3
  > a bunch of copies were traced back to the `std.meta.eql` function.
- [zig/comptime] Each comptime parameter value monomorphises a new copy; counting IR
  lines per generic name finds bloat. A `comptime` field name and value in a print
  helper cost 300 bytes for nothing. ^f4
  > is duplicated in the machine code for every value of `T` it is actually used with.
  > The following works and shaves off 300 bytes from the release binary:
- [zig/perf] A rarely used slow path inlined into a hot function can blow up its stack
  frame; mark it cold. ^f5
  > Although the _code_ for slow path was rarely executed, the function’s frame size would have to account for memory there every time.

## Read

- Whole post.
