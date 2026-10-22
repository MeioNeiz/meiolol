---
title: Simplistic Comptime Column Safety in SQLite Queries (Loris Cro, 2025)
url: https://kristoff.it/blog/simplistic-comptime-sqlite/
kind: article
commit:
for: [zig-comptime, zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: A 20-line comptime parse of a SELECT string to map column names to indices with compile errors; debug-only unused-column check; on keeping comptime simple
---
# Simplistic Comptime Column Safety in SQLite Queries (Loris Cro, 2025)

Why: where comptime cleverness should stop.

## Assessment

- Evidence: B. Zig team member's own project (Awebo); Dec 2025, Zig 0.16-dev
  (`@EnumLiteral()`).
- Reasoning: strong; explicit about what it doesn't handle and why simple is chosen.
- Interests: none beyond his project.
- Weigh: trust the judgement calls.

## Findings

- [zig/comptime] A type generic over a comptime string can parse the query and build a `StaticStringMap` of column indices at compile time. ^f1
  > /// Note how this is type is generic over a comptime string,
  > const col_map: std.StaticStringMap(u8) = .initComptime(columns);
- [zig/comptime] Getters take `comptime col: @EnumLiteral()` and turn a wrong name into `@compileError`, at no runtime cost. ^f2
  > @compileError("column '" ++ @tagName(col) ++ "' not found in query");
- [zig/comptime] A deliberately incomplete parser is fine when its failure modes are compile errors, not runtime surprises. ^f3
  > it’s not correct for the general case, but it’s good enough for the current needs of my project, also because the failure modes (e.g. trying to parse a query that makes use of SQL functions) will produce obvious compile errors, and not surprising behavior at runtime.
- [zig/comptime] He picks a thin, mostly comptime-free dependency on nightly Zig, because complex comptime in dependencies breaks. ^f4
  > I’m using Zig’s ‘nightly’ builds, and it’s annoying when complicated comptime code breaks in a dependency.
- [zig/build] Code generation in a build step can beat comptime for readability: output you can goto-definition into. ^f5
  > A build step would be able to generate straight-forward code that you can even ‘goto definition’ into.
- [zig/safety] Debug-only checks via a field typed `if (builtin.mode == .Debug) T else void`. ^f6
  > col_set: if (builtin.mode == .Debug)
- [zig/comptime] Abstraction always costs; a simple partial solution can beat a complete complex one. ^f7
  > complexity and abstraction **always** have a cost, and a simpler simplistic solution can be better than a complex complete solution

## Read

- Whole post.
