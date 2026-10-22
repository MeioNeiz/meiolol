---
title: Programming Aphorisms (matklad, 2026-02-11)
url: https://matklad.github.io/2026/02/11/programming-aphorisms.html
kind: article
commit: 
for: [zig-api-design, zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Redesigning a Zig 0.16 readHistory signature: options struct with a from_environment shortcut, gpa naming, "options" naming, positional DI for io/gpa
---
# Programming Aphorisms (matklad, 2026-02-11)

Why: API signature conventions in post-std.Io Zig. Zig 0.16 (environment threaded as
`std.process.Environ.Map` from main; `getEnvVarOwned` going away), current.

## Assessment

- Evidence: B. Expert's habits, with origins named (Zig compiler, TigerBeetle, kernel,
  Django article).
- Reasoning: strong. Names six moves; says explicitly it is a starting point, not "the
  right way", and doesn't argue the why of each.
- Interests: none.
- Weigh: a direct template for meiolol function signatures after the 0.16 IO change.

## Findings

- [zig/api] For a ziggit question on threading env into `readHistory`, his start is
  `HistoryOptions { file: []const u8, pub fn from_environment(environment: *const
  std.process.Environ.Map) HistoryOptions }` and `readHistory(io, gpa, options)`. ^f1
  > pub fn from_environment(
- [zig/api] Raise the abstraction level: give the thing a name and a type. ^f2
  > I “raised the abstraction level” by giving _it_ a name and a type (`HistoryOptions`).
- [zig/api] Avoid the midlayer mistake: every option user-configurable (easy with public
  fields); add a shortcut (`from_environment`) that cuts across layers. ^f3
  > I avoided “midlayer mistake” by making sure that every aspect of options is user-configurable.
  > I provided a “shortcut”, the `from_environment` convenience function that cuts across abstraction layers.
- [zig/style] [zig/memory] Rename `alloc` to `gpa` (as opposed to `arena`), naming taken
  from the Zig compiler. ^f4
  > I instinctively renamed `alloc` to “gpa” (in opposition to “arena”), the naming I spotted in the Zig compiler.
- [zig/style] [zig/api] Name the configuration parameter `options`, not config, props or
  params (TigerBeetle). ^f5
  > I named the configuration parameter “options”, not `config`, `props` or `params`
- [zig/api] Positional DI: dependencies with unique types go positionally with canonical
  names (`io`, `gpa`); arguments that directly vary behaviour go by name in an Options
  struct. ^f6
  > Arguments that are dependencies, resources with unique types are injected positionally (and have canonical names like `io` or `gpa`).
  > Arguments that _directly_ vary the behavior of function (as opposed to affecting transitive callees) are passed by name, in the `Options` struct.
- [zig/api] Zig is removing ambient IO: environment access is threaded from main. ^f7
  > Zig is in the process of removing ambient IO capabilities.

## Read

- Whole post.

## Not read

- The ziggit thread itself (not linked directly).
