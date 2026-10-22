---
title: Things Zig comptime Won't Do (matklad, 2025-04-19)
url: https://matklad.github.io/2025/04/19/things-zig-comptime-wont-do.html
kind: article
commit: 
for: [zig-comptime, zig-build]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Zig comptime as partial evaluation, its limits (no host leakage, no eval, no DSLs, no RTTI, no new methods, no IO) and a hand-rolled RTTI to trade monomorphisation for code size
---
# Things Zig comptime Won't Do (matklad, 2025-04-19)

Why: how to think about comptime and where it stops. Zig 0.14 (`~/zig-0.14/zig`,
`.@"struct"` type info tags); 0.17 changed struct type info to struct-of-arrays, so the
`info.fields` iteration code is stale in detail; the concepts hold.

## Assessment

- Evidence: B. Expert, runnable examples with output.
- Reasoning: strong. Each limit with what you get in exchange, and the cost (no
  declaration-site type checking).
- Interests: none.
- Weigh: the frame "comptime is partial evaluation, not codegen" is the key idea; check
  `@typeInfo` field shapes against 0.17.

## Findings

- [zig/comptime] Comptime doesn't leak the host: cross compiling to big-endian 32-bit
  shows target `usize` bytes at comptime. ^f1
  > Zig doesn’t give comptime code access to host architecture
- [zig/comptime] No eval: there is no dynamic source generation; instead partial
  evaluation/specialisation covers most uses. ^f2
  > In contrast, there’s absolutely no facility for dynamic source code generation in Zig.
  > Zig has a completely different feature, partial evaluation/specialization
- [zig/comptime] Marking a parameter `comptime` guarantees the function is partially
  evaluated per value, leaving one branch. ^f3
  > the compiler will partially evaluate `f`, so only one branch will be left.
- [zig/comptime] `comptime for` evaluates the whole loop at compile time; `inline for`
  needs only the length known, for bodies that depend on runtime values. ^f4
  > `comptime for(xs)` evaluates the entire loop at compile time, requiring that `xs` is comptime-known, and `inline for(xs)` requires that just the length of `xs` is known at comptime.
- [zig/comptime] Struct printing by recursive `print(comptime T: type, value: T)` over
  `@typeInfo(T)` with `inline for (info.fields)` and `else => comptime unreachable`. ^f5
  > inline for (info.fields) |field| {
- [zig/comptime] No DSLs: Zig syntax can't be passed to comptime functions; a custom
  syntax goes as a comptime string, as `print(comptime fmt, args: anytype)` does. ^f6
  > Here, `fmt` is an embedded DSL, which is checked at compile time to match the arguments.
- [zig/comptime] [zig/perf] Types exist only at comptime; one copy of print per type costs
  code size and compile time, so roll your own RTTI: compute it at comptime, store it as
  data, use one `print_dyn(rtti, *const anyopaque)`. ^f7
  > Our code will be smaller, and will compile faster if there’s just a single `print` that takes an opaque pointer and runtime parameter describing the type of the value
  > we need `comptime` to _compute_ the type information, but then we reify it as some real bytes in the binary
- [zig/comptime] [zig/api] Comptime can create types but can't add methods; an API is
  always hand written, so serialisation is a top-level `to_json(comptime T, value,
  writer)`, with opt-in via a `pub const JSONOptions` declaration. ^f8
  > it is impossible to add methods to generated types, they must be inert bundles of fields.
  > In Zig, types’s API is always hand written, but it can use comptime reflection internally.
- [zig/comptime] [zig/build] No IO at comptime: evaluation is hermetic and cacheable;
  generate code that needs IO through build.zig and `@import` it. ^f9
  > In exchange, compile time evaluation is hermetic, reproducible, safe, and cacheable.
  > just through the build system!
- [zig/comptime] Cost: no declaration-site type checking of comptime code. ^f10
  > Zig doesn’t have declaration-site type checking of comptime code.

## Read

- Whole post.

## Not read

- mitchellh.com posts on comptime conditional disable and tagged union subset (linked):
  other blog; lead.
