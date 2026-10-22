---
title: Improving Your Zig Language Server Experience (Loris Cro, 2024)
url: https://kristoff.it/blog/improving-your-zls-experience/
kind: article
commit:
for: [zig-build]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Add a check step that compiles without installing (-fno-emit-bin) and point ZLS build-on-save at it
---
# Improving Your Zig Language Server Experience (Loris Cro, 2024)

Why: fast type-check step in build.zig.

## Assessment

- Evidence: B. Zig team member; Jul 2024 (0.13), edited Nov 2024 to point at ZLS docs.
- Reasoning: fair.
- Interests: ZSF.
- Weigh: the `addExecutable(.{ .root_source_file = ...})` form is pre-0.15; use
  `.root_module`. The check-step idea stands.

## Findings

- [zig/build] ZLS can't resolve complex comptime, so type errors need the compiler. ^f1
  > it is not able to resolve complex comptime expressions.
- [zig/build] Add a `check` step that builds the same artifact without installing it; that passes `-fno-emit-bin`, so analysis runs and codegen is skipped. ^f2
  > This one-line difference will have a big impact on the resulting behavior of the build as it will add the `-fno-emit-bin` flag to the compiler invocation
- [zig/build] Point ZLS at it with `enable_build_on_save` and `build_on_save_step: check`. ^f3
  > "build_on_save_step": "check"

## Read

- Whole post.
