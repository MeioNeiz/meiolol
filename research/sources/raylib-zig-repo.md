---
title: 'raylib-zig (raylib-zig/raylib-zig): README, build.zig.zon, CI, last 0.16 commit'
url: https://github.com/raylib-zig/raylib-zig
kind: project
commit: 50d450099da664bedd7dcc6ed40204ab0bb861a5
for: [zig-gui-options]
looked: 2026-10-11
depth: code (README, build.zig.zon at HEAD and at 8758f4cd3a, CI)
relevance: medium
grade: B/fair
description: Zig bindings for raylib; devel moved to Zig 0.17 on 2026-10-07, commit 8758f4cd3a (2026-07-18) is the last on Zig 0.16
---
# raylib-zig (raylib-zig/raylib-zig): README, build.zig.zon, CI, last 0.16 commit

Why: raylib option; which commit supports Zig 0.16 and how it builds for Windows.

## Assessment

- Evidence: B. Created 2020-02, pushed 2026-10-07, 1897 stars, 272 forks, 84
  contributors, no GitHub releases (tags v5.5, v5.6-dev). Note `Not-Nik/raylib-zig` is an
  archived stub; the live repo moved to the raylib-zig org.
- Reasoning: fair.
- Interests: none.
- Weigh: bindings follow the newest Zig quickly, so a 0.16 project must pin a commit and
  will not get fixes. raylib is a game library: UI means raygui or hand drawing.

## Findings

- [gui] HEAD needs Zig 0.17.0 and raylib 6.1-dev. `README.md`, `build.zig.zon` ^f1
  > Bindings tested on raylib version 6.1-dev and Zig 0.17.0
  > .minimum_zig_version = "0.17.0",
- [gui] The commit before the bump (8758f4cd3a, 2026-07-18) targets Zig 0.16.0 and raylib
  6.0. `commit-8758f4cd3a/README.md`, `commit-8758f4cd3a/build.zig.zon` ^f2
  > Bindings tested on raylib version 6.0 and Zig 0.16.0
  > .minimum_zig_version = "0.16.0",
- [gui] CI builds examples on Linux, Windows and macOS with Zig 0.17.0.
  `.github/workflows/check-examples.yml` ^f3
  > os: [ubuntu-latest, windows-latest, macos-latest]
  > version: 0.17.0
- [gui] Bindings are generated then hand-tweaked. `README.md` ^f4
  > Manually tweaked, auto-generated [raylib](https://github.com/raysan5/raylib) bindings for zig.
- [gui] Commit 8758f4cd3a builds its examples for x86_64-windows from macOS with Zig
  0.16.0 in our run ([[zig-gui-win-builds#^f6]]). ^f5

## Read

- README, zon and CI at HEAD; README and zon at 8758f4cd3a; devel commit titles

## Not read

- raygui bindings and widget set; examples source
