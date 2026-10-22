---
title: How to deal with Zig error not being able to contain data? (Ziggit thread, 2025)
url: https://ziggit.dev/t/how-do-deal-with-zig-error-not-being-to-contain-data/9683
kind: thread
commit:
for: [zig-errors-safety]
looked: 2026-10-22
depth: docs (whole thread)
relevance: high
grade: C/fair
description: Idioms for error context: cursor out-parameter, Diagnostics struct (std.json Scanner, zig-clap), tagged unions for erroneous values
---
# How to deal with Zig error not being able to contain data? (Ziggit thread, 2025)

Why: how Zig code carries error details without payloads.

## Assessment

- Evidence: C. Community answers (mnemnion, cryptocode, jeffective), Apr 2025; points to
  std.json Scanner and zig-clap, which do use the pattern.
- Reasoning: fair.
- Interests: cryptocode cites his own library.
- Weigh: the Diagnostics pattern is in the std (json, zon); verify the std form.

## Findings

- [zig/errors] Zig errors carry no payload; return the error as usual and fill a caller-provided Diagnostics object with details (line/column etc.). ^f1
  > Quite a few people in the Zig community have rallied around the "Diagnostics pattern" where you return and handle errors per usual, but also allow the caller to interrogate a Diagnostics instance when an error happens.
- [zig/errors] Diagnostics go either per call (zig-clap) or into a session/init (std.json Scanner `enableDiagnostics`). ^f2
  > Depending on situation, the Diagnostics instance can be passed in to every relevant fallible function, or be part of initialization for session-oriented situations.
- [zig/errors] Cursor out-parameter: the callee advances `*usize`, so on error the caller logs where it stopped. ^f3
  > For instance, if you want to know the location where something which uses an index fails, you can use a cursor pattern:
- [zig/comptime] Keep diagnostics in sync with the error set via `union(std.meta.FieldEnum(MyErrorType))`: a missing case is a compile error. ^f4
  > it uses `InKryption`'s idea of using `pub const Diagnostic = union(std.meta.FieldEnum(MyErrorType))` to make sure error enums and diagnostics are always kept in sync.
- [zig/errors] When a failure is a value to inspect rather than a refusal, return a tagged union. ^f5
  > The current default way to return values as "erroneous" is to use a tagged union.

## Read

- Whole thread.
