---
title: 'Scripty (kristoff-it/scripty): README, vm.zig'
url: https://github.com/kristoff-it/scripty
kind: project
commit: 51a03222e9a125a65888a5df6e2a41e36c86ccd5
for: [zig-html-templates]
looked: 2026-10-12
depth: code (README, src/vm.zig field and builtin lookup)
relevance: medium
grade: C/fair
description: Expression language embedded in SuperHTML/SuperMD attributes; runtime VM over a host-defined Value union, lookups by comptime reflection, errors at eval time
---
# Scripty (kristoff-it/scripty): README, vm.zig

Why: how SuperHTML templates reach Zig data, and when a wrong field is caught.

## Assessment

- Evidence: C. Created 2024-06, 38 stars, 3 contributors, no release; used by
  SuperHTML and Zine.
- Reasoning: fair. README explains embedding; API admitted unpolished.
- Interests: author's own.
- Weigh: shows the dynamic-lookup cost we would avoid with comptime.

## Findings

- [web/template] [toolchain] Requires Zig 0.17-dev. `build.zig.zon` ^f1
  > .minimum_zig_version = "0.17.0-dev.1471+ff10b90bc",
- [web/template] SuperHTML hardcodes no evaluation context; the host defines what
  `$page` etc. are. `README.md` ^f2
  > Note that SuperHTML does not hardcode any evaluation context.
- [web/template] Field access is resolved at eval time by walking struct fields with
  comptime reflection; a missing field becomes an error value at run time, not a
  compile error. `src/vm.zig` ^f3
  > const not_found: ValueUnion = .{ .err = "field not found" };
  > inline for (info.field_names, info.field_types) |name, t| {
- [web/template] Structs must opt in to dot access with a `Dot` declaration. `src/vm.zig` ^f4
  > if (!@hasDecl(T, "Dot") or !T.Dot) return no_fields;

## Read

- `README.md`: all; `src/vm.zig`: lines 340-440

## Not read

- `src/Parser.zig`, `src/Tokenizer.zig`: expression grammar
