---
title: 'sokol-zig-imgui-sample (floooh): Dear ImGui with sokol-zig, README, deps, CI'
url: https://github.com/floooh/sokol-zig-imgui-sample
kind: project
commit: 165d2883b8129d9dfe11709b6c4bcf1e5bd33424
for: [zig-gui-options]
looked: 2026-10-11
depth: code (README, build.zig.zon, build.zig, CI)
relevance: high
grade: B/fair
description: Official sample wiring Dear ImGui (floooh/dcimgui) into sokol-zig; currently requires Zig 0.17-dev
---
# sokol-zig-imgui-sample (floooh): Dear ImGui with sokol-zig, README, deps, CI

Why: the canonical way to get sokol + Dear ImGui in Zig; which Zig does it need?

## Assessment

- Evidence: B. 74 stars, pushed 2026-10-04, by the sokol author. dcimgui (Dear Bindings
  based C API): 104 stars, 6 contributors, pushed 2026-10-04.
- Reasoning: fair.
- Interests: none beyond the author's ecosystem.
- Weigh: follows Zig master; for a Zig 0.16 project we would have to find and pin an
  older dcimgui and translate_c combination, or write our own build glue.

## Findings

- [gui] README says the sample requires Zig 0.17-dev, not 0.16. `README.md` ^f1
  > requires zig 0.17.0-dev (as of 0.17.0-dev.1737+de207594e)
- [gui] Dear ImGui comes from floooh/dcimgui as a Zig package. `build.zig.zon` ^f2
  > .url = "git+https://github.com/floooh/dcimgui.git#b5c946894651f3e12dbf9ae04c245e13424e0444",
- [gui] CI builds against Zig master. `.github/workflows/main.yml` ^f3
  > version: master
- [gui] Issue #11 ("Currently unable to build against 0.16+", closed) reported aro and
  translate-c dependencies failing on 0.16.0; read with `gh issue view`, not snapped. ^f4
- [gui] Our Zig 0.16.0 Windows build of HEAD fails inside the translate_c dependency
  pulled by dcimgui ([[zig-gui-win-builds#^f4]]). ^f5

## Read

- `README.md`, `build.zig.zon`, CI; commit history titles (moved to 0.17-dev by July 2026)

## Not read

- `src/main.zig` sample code; a dcimgui commit that still builds on 0.16 (not searched)
