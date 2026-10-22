---
title: Comptime as Configuration (Karl Seguin, 2025)
url: https://www.openmymind.net/Comptime-as-Configuration/
kind: article
commit:
for: [zig-comptime, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Library hooks and settings detected on a user-supplied type with @hasDecl/hasFn, with a compileError on bad signatures; not for normal options
---
# Comptime as Configuration (Karl Seguin, 2025)

Why: where comptime configuration earns its rigidity.

## Assessment

- Evidence: B. Used in his httpz (Jetzig builds on it) and ztl libraries; Jan 2025, 0.14.
- Reasoning: strong; states the cost and when not to.
- Interests: his own libraries.
- Weigh: trust the limit he sets.

## Findings

- [zig/comptime] httpz detects an optional `handle` method on the user's type at comptime and rejects a wrong return type with `@compileError`. ^f1
  > if (comptime std.meta.hasFn(Handler, "handle")) {
  > @compileError(@typeName(Handler) ++ ".handle must return 'void'");
- [zig/comptime] Scalar settings via a nested decl struct, falling back to defaults with `@hasDecl`/`@field`. ^f2
  > if (App != void and @hasDecl(App, "ZtlConfig") and @hasDecl(App.ZtlConfig, field_name)) {
- [zig/perf] Comptime config allows real optimisation: pick `u8` vs `u16` and put the call stack on the stack. ^f3
  > ztl's VM will use a `u8` or a `u16` depending on the `max_locals` configuration, and because `max_call_frames` is known at compile time, the VM's call stack can be allocated on the stack.
- [zig/api] Use it for hooks on a type the user passes anyway; not for normal options, which become rigid. ^f4
  > Unless you have really good reason to, you probably should not do this for normal options - it makes your library much more rigid by requiring that the user of your library know the options at comptime.

## Read

- Whole post.
