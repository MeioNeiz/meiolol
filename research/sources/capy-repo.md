---
title: 'capy (capy-ui/capy): README, build.zig.zon, CI'
url: https://github.com/capy-ui/capy
kind: project
commit: fd77077e296a969ae258c595e75a0723183b3138
for: [zig-gui-options]
looked: 2026-10-11
depth: code (README, build.zig.zon, CI)
relevance: medium
grade: C/fair
description: Declarative Zig GUI library over native OS controls; pinned to Zig 0.14.1, not production ready, quiet since 2025
---
# capy (capy-ui/capy): README, build.zig.zon, CI

Why: the only native-controls Zig GUI candidate; is it usable on Zig 0.16?

## Assessment

- Evidence: C. Created 2021-03, last push 2025-12-25 (a Nix fix; last code work
  2025-07), 2702 stars, 106 forks, 27 contributors, no releases. Stars outrun activity.
- Reasoning: fair; README is honest about not being production ready.
- Interests: none.
- Weigh: would give native Win32 controls and small binaries, but it is two Zig
  releases behind (0.14.1 vs our 0.16) and our 0.16 build fails at the manifest.

## Findings

- [gui] Author says it is not ready for production. `README.md` ^f1
  > **As of now, Capy is NOT ready for use in production as I'm still making breaking changes**
- [gui] Targets Zig 0.14.1, waiting for a Mach nominated version. `README.md`,
  `build.zig.zon` ^f2
  > **Capy targets Zig version `0.14.1`, the plan is to return to
  > .minimum_zig_version = "0.14.1",
- [gui] Uses native OS controls, claims any-to-any cross-compile and examples under 2 MB.
  `README.md` ^f3
  > It is mainly intended for creating applications using native controls from the operating system.
  > Cross-compilable from any platform to any other platform
  > Every [example](https://github.com/capy-ui/capy/tree/master/examples)'s size < 2MB
- [gui] CI cross-compiles to Windows but on Zig 0.14.1. `.github/workflows/ci.yml` ^f4
  > version: 0.14.1
  > run: zig build -Dtarget=x86_64-windows
- [gui] Checked, not there: no issue or PR mentioning Zig 0.15 or 0.16 (gh search). ^f5
- [gui] Our Zig 0.16.0 build stops at build.zig.zon (old-format dependency hashes)
  ([[zig-gui-win-builds#^f8]]). ^f6

## Read

- README top half, build.zig.zon, CI, last 8 commit titles

## Not read

- Source; capy-template; Matrix channel activity
