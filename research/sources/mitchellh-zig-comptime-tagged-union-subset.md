---
title: Tagged Union Subsets with Comptime in Zig (Mitchell Hashimoto)
url: https://mitchellh.com/writing/zig-comptime-tagged-union-subset
kind: article
for: [zig-comptime, zig-api-design]
looked: 2026-10-22
depth: docs (full)
relevance: high
grade: B/strong
description: Sept 2024 post: generate subset tagged unions at comptime so each handler switches exhaustively without else; scoped() converts via inline else; Zig 0.13 @Type syntax
---
# Tagged Union Subsets with Comptime in Zig (Mitchell Hashimoto)

Why: how to keep exhaustive switches when a function handles only part of a tagged union?

## Assessment

- Evidence: B. Author of [[ghostty-repo]] (A) and of much of Zig's `@Type` reification code
  (he says so); a real Ghostty refactor.
- Reasoning: strong. Shows two rejected versions (else, listing no-ops) and why, the
  generated version, the conversion cost (profiled, invisible) and that the reverse
  construction also works with other trade-offs.
- Interests: none.
- Weigh: code is Zig 0.13: `@typeInfo(T).Union.fields` and `@Type(.{ .Union = ...})` are stale.
  In 0.17 build the type with `@Union(...)` from `field_names`/`field_types` as in
  [[ghostty-repo#^f46]]. Ideas hold; syntax doesn't.

## Findings

- [zig/api] Exhaustive switch on a tagged union is the safety net: adding a case breaks every switch that misses it. ^f1
  > This ensures that when I add a new keybind action, I also add the code to handle it.
- [zig/api] An `else` prong loses that safety: the compiler can't flag a new tag the function forgot. ^f2
  > That's a catch-all case and when there is a catch-all case, the compiler can't error if I add a new action
- [zig/api] Listing ignored tags as no-ops keeps safety but is verbose and lets the signature accept tags it never handles. ^f3
  > From a types perspective, I don't like that `performAppAction` can accept terminal-specific actions.
- [zig/api] Both subsets and the full union are needed: the config parser must parse all actions. ^f4
  > other parts of the codebase need to work with the single `Action`.
- [zig/comptime] One exhaustive `scope()` function classifies each tag; a type function filters the union's fields by it and builds a new union. ^f5
  > It is verbose since we need to include every case, but it is centralized in a single location and easy to maintain.
  > pub fn ScopedAction(comptime s: Scope) type {
- [zig/style] Capitalised function names signal that a function returns a type. ^f6
  > When a function is capitalized, it signals to the caller that it will return a type.
- [zig/comptime] `@unionInit(Action, name, undefined)` makes a value just to call a tag-only method at comptime; touching undefined at comptime is a compile error, so it is safe. ^f7
  > If we ever access undefined memory in comptime, we'll get a compiler error, so this is safe.
- [zig/comptime] Ordinary functions run at comptime unchanged; `scope()` doesn't know which it is in. ^f8
  > Note that our `scope()` function above has no idea if it is being executed in comptime or runtime.
- [zig/comptime] The subset types cost nothing at runtime and generate no new code. ^f9
  > There is no runtime cost to doing any of this.
- [zig/comptime] `scoped(self, comptime s) ?ScopedAction(s)`: `inline else` makes the tag comptime-known per prong; a comptime `if` prunes tags outside the scope. ^f10
  > Because it is inline, the compiler will provide the `tag` as a compile-time known value.
- [zig/comptime] A parameter used in the return type must be `comptime`. ^f11
  > If we didn't have the `comptime` prefix on `s`, the compiler would error because we can't use a runtime value to generate information that must be compile-time known (a type).
- [zig/perf] The conversion has a runtime switch; profiled in a synthetic loop, it didn't show up. ^f12
  > it didn't show up in the profile, so I'm not worried about it.
- [zig/comptime] He calls this advanced and likely overwhelming for newcomers; he is a type pragmatist. ^f13
  > For newcomers to Zig, the techniques and language features used here are likely to be overwhelming.
- [toolchain] Written for Zig 0.13: `@typeInfo(Action).Union.fields` and `@Type(.{ .Union = .{...} })`, both changed since (0.14 lowercased, 0.17 split `@Type` and SoA type info). ^f14
  > const all_fields = @typeInfo(Action).Union.fields;

## Read

- Full post

## Not read

- Ghostty's current keybind Action code (may no longer use ScopedAction)
