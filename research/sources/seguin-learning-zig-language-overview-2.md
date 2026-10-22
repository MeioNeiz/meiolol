---
title: Learning Zig - Language Overview Part 2 (Karl Seguin)
url: https://www.openmymind.net/learning_zig/language_overview_2/
kind: book
commit:
for: [zig-errors-safety, zig-style, zig-api-design]
looked: 2026-10-22
depth: skimmed (switch, enums, tagged unions, optionals, undefined, errors)
relevance: medium
grade: B/fair
description: Chapter on control flow, enums, tagged unions, optionals, undefined and error unions
---
# Learning Zig - Language Overview Part 2 (Karl Seguin)

Why: the error-handling idioms taught to newcomers.

## Assessment

- Evidence: B. Widely read intro; revised for 0.16.
- Reasoning: fair. Gives reasons for `anyerror` and `else` cautions.
- Interests: none known.
- Weigh: mainstream advice; he leans on inferred error sets, which TigerBeetle-style
  explicit sets argue against for libraries.

## Findings

- [zig/errors] `catch |err| switch (err)` is the idiomatic way to handle specific errors and pass or map the rest. ^f1
  > The `switch` version is more idiomatic:
  > action(req, res) catch |err| switch (err) {
- [zig/errors] `try` is shorthand for `catch |err| return err`, and errors must be handled. ^f2
  > This is particularly useful given that **error must be handled**.
- [zig/errors] He uses inferred error sets heavily; libraries may prefer explicit sets as documentation. Function pointers to inferred-set functions need `anyerror`. ^f3
  > Library developers might see advantages to being more explicit, such as self-documenting code. Still, I think both the implicit error sets and the inferred error union are pragmatic; I make heavy use of both.
- [zig/errors] `anyerror` in a return type overstates what can fail; keep it for parameters or fields that hold any error. ^f4
  > using `anyerror` in a function signature is likely to signal that your function can return errors that, in reality, it cannot.
- [zig/errors] `!?T` returns are common; `(try f()) orelse default` unwraps both. ^f5
  > const save = (try Save.loadLast()) orelse Save.blank();
- [zig/style] An `else` arm on an enum switch silently absorbs newly added variants, losing exhaustiveness. ^f6
  > Be careful when using the `else` clause of a `switch` though, as it'll match any newly added enum values, which may or may not be the behavior that you want.
- [zig/api] Tagged unions serve as closed interfaces when every implementation is known up front. ^f7
  > tagged unions can be used somewhat like interfaces, as long as all possible implementations are known ahead of time and can be baked into the tagged union.
- [zig/safety] `.?` on null panics; `if (opt) |v|` or `orelse` unwrap safely. ^f8
  > But we'll get a runtime panic if we use `.?` on a null.

## Read

- Switch, enums, tagged unions, optionals, undefined, errors sections.

## Not read

- Loops and ranges in detail.
