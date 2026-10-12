---
title: 'Pek (nektro/zig-pek): README'
url: https://github.com/nektro/zig-pek
kind: project
commit: 40db1115429b81e7dfac44ac2ccb08e82c22cf9b
for: [zig-web-ui]
looked: 2026-10-12
depth: docs (README)
relevance: low
grade: C/weak
description: Comptime HTML preprocessor with a small template syntax, by nektro; Zig 0.15 badge, zigmod packaging
---
# Pek (nektro/zig-pek): README

Why: is there a small comptime HTML DSL for Zig we could use or copy?

## Assessment

- Evidence: C. Created 2021-08, pushed 2026-09-27, 58 stars, one main author. Packaged with zigmod, not build.zig.zon.
- Reasoning: weak. README is one example.
- Interests: none known.
- Weigh: shows the comptime-DSL idea is doable; not a dependency we would take (zigmod, 0.15).

## Findings

- [web] Pek parses an HTML-like DSL at comptime and fills it with a builtin template engine. `README.md` ^f1
  > A comptime HTML preprocessor with a builtin template engine for Zig.
- [web] [toolchain] README badges say Zig 0.15 and Zigmod; it ships zig.mod, no build.zig.zon. `README.md`, `zig.mod` ^f2

## Read

- `README.md`: all

## Not read

- `test.zig`, `src/`: how the comptime parser works, if we write our own
