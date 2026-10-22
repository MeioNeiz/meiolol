---
title: Minimal Viable Zig Error Contexts (matklad, 2026-05-03)
url: https://matklad.github.io/2026/05/03/zig-error-context.html
kind: article
commit: 
for: [zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: matklad on adding context to Zig errors in script-y code with an errdefer key=value log line, and its drawback
---
# Minimal Viable Zig Error Contexts (matklad, 2026-05-03)

Why: how to get useful error messages from Zig without a full diagnostics sink. Zig
0.16 era (std.Io, `Io.Dir.cwd().openFile(io, ...)`), so current for 0.17.

## Assessment

- Evidence: B. Alex Kladov (rust-analyzer author, TigerBeetle engineer) reporting his own
  practice; short post, no project-wide data.
- Reasoning: strong. Walks three options, names the costs, admits the main drawback.
- Interests: none known.
- Weigh: a pragmatic pattern for tools and scripts; he says the Diagnostics sink is the
  idiom for production code. The logged-even-if-handled drawback matters with 0.16
  cancelation.

## Findings

- [zig/errors] Zig error codes cover handling; reporting is left to the user, and the
  idiomatic solution is a Diagnostics out parameter (sink). ^f1
  > Out of the box, Zig provides minimal and sufficient facilities for error _handling_ — strongly-typed error codes
  > Idiomatic solution is to pass a `Diagnostics` out parameter (“sink”) to materialize human-readable strings as needed.
- [zig/errors] For script-y code the sink is too much friction; a plain `try` gives an error
  trace but not which file failed. ^f2
  > Diagnostics pattern works well for “production” code, but for more script-y code it adds too much friction
- [zig/errors] He rejects per-call `catch |err| { log.err(...); return err; }`: high
  friction, obscures the happy path, repeated per fallible call. ^f3
  > Unsatisfactory. The friction is high, you need to come up with a reasonably-sounding error message, the “happy path” of the code is obscured
- [zig/errors] [zig/memory] Pattern: `errdefer log.err("path={s}", .{path});` at the top of
  the block, then plain `try`s; context is per block and each frame in the call stack
  adds its own. ^f4
  > just log error context as `key=value` pairs, guarded by `errdefer`.
  > The context is “telescopic” every function in the call-stack can add its own context.
- [zig/errors] Drawback: the context is logged even when a caller later handles the error,
  which matters in 0.16 where cancelation can surface from any IO operation and is meant
  to be handled. ^f5
  > the error message is logged, even if the error is subsequently handled. This is especially important in Zig 0.16, where cancelation
- [zig/errors] (inferred) So the errdefer log suits CLI and tool code where errors bubble
  to main; not library code whose callers handle errors (e.g. error.Canceled). ^f6

## Read

- Whole post.

## Not read

- https://goldstein.lol/posts/error-progress/ (linked; argues no language feature fixes
  this). Other blog, out of scope.
