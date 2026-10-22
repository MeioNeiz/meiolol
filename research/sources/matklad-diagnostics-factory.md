---
title: Diagnostics Factory (matklad, 2026-02-16)
url: https://matklad.github.io/2026/02/16/diagnostics-factory.html
kind: article
commit: 
for: [zig-errors-safety, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: matklad's default error reporting: a struct of add_* constructor functions (TigerBeetle tidy.zig) instead of an error payload union
---
# Diagnostics Factory (matklad, 2026-02-16)

Why: how Zig code should report errors to users. Zig 0.15/0.16 era (TigerBeetle 0.16.73,
`captured.writer(errors.gpa)` unmanaged ArrayList), current.

## Assessment

- Evidence: B. First-hand from TigerBeetle's tidy.zig (a real lint script in a large,
  heavily tested Zig codebase).
- Reasoning: strong. Lists properties, the trade-off (one central list of errors is
  "either a benefit or a drawback"), and the general principle.
- Interests: none known.
- Weigh: trust as a default for reporting; it does not replace error codes for control
  flow, it sits beside them.

## Findings

- [zig/errors] His default for reporting: don't design error payload types; give a set of
  functions that construct errors. ^f1
  > avoid_ thinking about error payloads, and what the type of error should be. Instead, provide a set of functions for constructing errors.
- [zig/errors] [zig/api] TigerBeetle tidy.zig has `const Errors = struct` with methods
  `add_long_line`, `add_banned`, `add_dead_declaration`; call sites call
  `errors.add_long_line(file, line_index)`. ^f2
  > errors.add_long_line(file, line_index);
- [zig/errors] Fail fast is `errors.add_...(...)` then `return error.Tidy;`: the error code
  is deliberately independent of which error was reported. ^f3
  > Note that the error code is intentionally independent of the specific error produced.
- [zig/errors] Why: callers don't care what happens inside, so you needn't decide up front
  what to do with errors and can change your mind later. ^f4
  > This is why the error factory is my _default_ solution — I don’t have to figure out up-front what I’ll do with the errors, and I can change my mind later.
- [zig/errors] The constructor is the natural place to convert data to a user form (e.g.
  byte offset to line and column). ^f5
  > There’s a natural place to convert information from the form available at the place where we emit the error to a form useful for the user.
- [zig/style] Naming tip: `line_index` for 0-based internal indexes, `line_number` for
  1-based user-visible ones. ^f6
  > use `line_index` for 0-based internal indexes, and `line_number` for user-visible 1-based ones
- [zig/errors] Uniform call syntax makes all error sites greppable (`rg 'errors.add_'`). ^f7
  > This syntactic uniformity in turn allows easily grepping for all error locations
- [zig/errors] [zig/test] Polymorphism for tests: in a run errors go to stderr, in tests to
  an in-memory buffer (`if (errors.captured) |*captured|` else `std.debug.print`). ^f8
  > When running the script, errors are directly emitted to stderr. But when testing it, errors are collected into an in-memory buffer
- [zig/safety] [zig/comptime] `emit` takes `comptime fmt` and does
  `comptime assert(fmt[fmt.len - 1] == '\n');`: a comptime assert on a format string. ^f9
  > comptime assert(fmt[fmt.len - 1] == '\n');
- [zig/errors] No giant `union(enum)` of all errors, because the use case doesn't need it. ^f10
  > There isn’t a giant `union(enum)` of all errors, because it’s not needed for the present use-case.
- [zig/api] Principle: an interface has a user side and an implementor side that may want
  different shapes; one big error enum couples emitting and reporting code. ^f11
  > Using a single big enum for errors couples error emitting and error reporting code, as they have to meet in the middle.

## Read

- Whole post.

## Not read

- TigerBeetle src/tidy.zig (linked at 0.16.73): reader "tigerbeetle" owns that repo.
