---
title: Generic Programming and anytype (Ziggit docs topic, 2024)
url: https://ziggit.dev/t/generic-programming-and-anytype/3228
kind: thread
commit:
for: [zig-comptime, zig-api-design]
looked: 2026-10-22
depth: docs (whole thread)
relevance: low
grade: C/fair
description: Ziggit doc on anytype: duck typing costs, alternatives (explicit comptime T, interface structs)
---
# Generic Programming and anytype (Ziggit docs topic, 2024)

Why: when to prefer `comptime T` or an interface over `anytype`.

## Assessment

- Evidence: C. Ziggit Docs topic by a moderator (AndrewCodeDev), Mar 2024, 0.12.
- Reasoning: fair.
- Interests: none.
- Weigh: consistent with std practice (`std.mem.eql(comptime T, ...)`).

## Findings

- [zig/comptime] Each distinct `anytype` argument type instantiates a new copy of the function. ^f1
  > Due to type deduction, there will now be two separate versions of `foo` that get created - one for `arg: usize` and `arg: isize`.
- [zig/comptime] Heavy `anytype` makes signatures unreadable: callers dig into bodies to learn the contract. ^f2
  > Heavy reliance on `anytype` can make function declarations difficult to read, requiring the user to dig into function implementations to understand how a type is used.
- [zig/comptime] Prefer an explicit `comptime T: type` that shapes the other parameters, as `std.mem.eql` does. ^f3
  > pub fn eql(comptime T: type, a: []const T, b: []const T) bool

## Read

- First post (the doc); replies skimmed.
