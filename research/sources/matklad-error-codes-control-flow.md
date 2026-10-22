---
title: Error Codes for Control Flow (matklad, 2025-11-06)
url: https://matklad.github.io/2025/11/06/error-codes-for-control-flow.html
kind: article
commit: 
for: [zig-errors-safety, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Reporting vs handling errors; Zig error sets as typed error codes, explicit discards, inferred sets and the Diagnostics sink (std.zon fromSlice)
---
# Error Codes for Control Flow (matklad, 2025-11-06)

Why: the model behind Zig's error sets and why payloads go elsewhere. Zig 0.15 era
(`*Reader` with `error{ReadFailed, EndOfStream}`, std.zon `fromSlice`), current.

## Assessment

- Evidence: B. Expert analysis, with std code shown (std.Io.Reader, std.zon).
- Reasoning: strong. Separates two concerns and shows how each maps to a type.
- Interests: none known.
- Weigh: the core frame for Zig error design; the follow-ups (diagnostics factory,
  error contexts) build on it.

## Findings

- [zig/errors] Reporting an error to a user and branching on an error are different
  aspects; think about them separately. ^f1
  > Displaying an error message to the user is a different aspect of error handling than branching based on a specific error condition.
- [zig/errors] In Zig error sets are strongly typed error codes, not poor man's sum
  types. ^f2
  > In Zig, error sets are strongly typed error codes, not poor man’s sum types.
- [zig/errors] Two destinations: bubble to an isolation boundary and show the operator, or
  handle with a recovery action. ^f3
  > An error can be bubbled to an isolation boundary and presented to the operator
- [zig/errors] If you know the final destination up front, render the error immediately;
  otherwise make it a structured product type. ^f4
  > If you know the ultimate destination up front, it usually is simpler to render the error immediately.
- [zig/errors] Branching needs a sum type, but only a finite number of handling paths
  exist, so a lean handling type is an enumeration: an error code. ^f5
  > a lean handling type might be just an enumeration of all different code-paths — an error code.
- [zig/errors] Zig requires `catch {}` to ignore an error, and `_ = x` for a value; `_ =
  can_fail()` fails with "error union is discarded", so an infallible call that later
  becomes fallible can't silently drop errors. ^f6
  > This protects from a common error when initially a result of an infallible function is ignored, but then the function grows a failing path
- [zig/errors] (claim) After using Zig, mandatory use of all return values is a non-issue:
  trivial discards are rare. ^f7
  > After using Zig, I can confidently say that trivial discards happen rarely and are a non-issue
- [zig/errors] [zig/api] std's Reader declares exact sets: `readSliceAll` returns
  `error{ReadFailed, EndOfStream}!void`, `readSliceShort` `error{ReadFailed}!usize`. ^f8
  > ) error{ReadFailed, EndOfStream}!void {
- [zig/errors] Sets compose additively and subtractively; whole-program compilation infers
  sets and gives each error a unique numeric code, allowing `anyerror`. ^f9
  > The tracking works additively (calling two functions unions the error sets) and subtractively
- [zig/errors] [zig/api] Diagnostic info goes out of band via a sink: std.zon
  `fromSlice(T, gpa, source, diag: ?*Diagnostics) error{ OutOfMemory, ParseZon }!T`;
  pass null to switch on the code, pass Diagnostics to show the user. ^f10
  > If the caller wants to handle the error, they pass `null` sink and `switch` on the error value.

## Read

- Whole post.

## Not read

- Linked Rust internals thread on #[must_use]: Rust.
