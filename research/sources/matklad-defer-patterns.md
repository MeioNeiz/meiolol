---
title: Zig defer Patterns (matklad, 2024-03-21)
url: https://matklad.github.io/2024/03/21/defer-patterns.html
kind: article
commit: 
for: [zig-memory, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Non-RAII uses of defer and errdefer: postcondition asserts, errdefer comptime unreachable, errdefer error logging, defer as post-increment; and why defer is a poor RAII substitute
---
# Zig defer Patterns (matklad, 2024-03-21)

Why: defer/errdefer placement and idioms. Zig 0.11/0.12 era: the std hash_map example
uses `@setCold(true)` (replaced by `@branchHint(.cold)` in 0.14) and
`readAll` on `process.stdout` (pre-0.15 IO), so example code is stale; patterns hold.

## Assessment

- Evidence: B. Examples from TigerBeetle (grid.zig, benchmark_driver.zig, scan_buffer.zig)
  and Zig std hash_map.zig.
- Reasoning: strong. States his view on defer vs RAII with the reason.
- Interests: none.
- Weigh: trust the patterns; update API names.

## Findings

- [zig/memory] (claim) Humans are not good at not forgetting defers, especially with
  optional ownership transfer (takes ownership unless an error is returned). ^f1
  > I am relatively confident that humans are just not good at not forgetting defers, especially when “optional” ownership transfer is at play
- [zig/memory] [zig/perf] But defer discourages RAII-style per-object resources and pushes
  towards batching: many objects share one pool, e.g. all strings in one buffer. ^f2
  > Because RAII with defer is painful, Zig naturally pushes you towards batching your resource acquisition and release calls, such that you have far fewer resources than objects in your program.
- [zig/safety] Contracts: `assert(precondition); defer assert(postcondition);`, e.g.
  `assert(!grid.free_set.opened); defer assert(grid.free_set.opened);`. ^f3
  > `defer` gives you poor man’s contract programming in the form of
  > defer assert(grid.free_set.opened);
- [zig/errors] [zig/safety] `errdefer comptime unreachable` statically proves no error path
  after that point; std hash_map grow: `try map.allocate(...)` then `errdefer comptime
  unreachable;` then swap and deinit. ^f4
  > But `comptime unreachable` straight up fails compilation if the compiler tries to generate the corresponding runtime code. The three together ensure the absence of error-returning paths.
- [zig/errors] Errors give only a code and a trace; an application often has enough
  context where the error starts to report it there. ^f5
  > Often, there’s enough context at the point where the error originates in the first place to produce a user-facing report right there.
- [zig/errors] Inside a labeled block: `errdefer |err| log.err("failed to read the port
  number: {}", .{err});` before the `try`s. ^f6
  > errdefer |err| log.err("failed to read the port number: {}", .{err});
- [zig/style] defer as post-increment: `defer self.scan_buffer_used += 1; return
  &self.scan_buffers[self.scan_buffer_used];` after a limit check returning
  `Error.ScansMaxExceeded`. ^f7
  > defer self.scan_buffer_used += 1;
- [zig/perf] Buffer sized at comptime from the format: `var buf: [fmt.count("{}\n",
  .{maxInt(u16)})]u8 = undefined;`. ^f8
  > var buf: [fmt.count("{}\n", .{maxInt(u16)})]u8 = undefined;

## Read

- Whole post.

## Not read

- The linked TigerBeetle files: reader "tigerbeetle".
