---
title: 'sokol-zig (floooh/sokol-zig): README, build.zig, CHANGELOG, CI'
url: https://github.com/floooh/sokol-zig
kind: project
commit: e12ece1c155fc7d2de91d3c6ad43617e2ab7e0ad
for: [zig-gui-options]
looked: 2026-10-11
depth: code (README, build.zig Windows section, CHANGELOG, CI)
relevance: high
grade: A/fair
description: Zig bindings for the sokol C headers (window, D3D11/Metal/GL graphics); no widgets of its own, Dear ImGui is a separate package
---
# sokol-zig (floooh/sokol-zig): README, build.zig, CHANGELOG, CI

Why: sokol is the low-level base for the sokol + Dear ImGui option; does it build on Zig
0.16 and cross-compile to Windows?

## Assessment

- Evidence: A for sokol itself (years of use; author maintains it daily). Bindings: repo
  created 2018-05, last push 2026-10-05, 735 stars, 94 forks, 30 contributors, no
  releases (track commits). CI builds on Linux, macOS and Windows against Zig master.
- Reasoning: fair; README is practical and states the risk of falling behind Zig.
- Interests: author's own project.
- Weigh: tracks Zig master, so HEAD can stop building on 0.16 at any time; pin a commit.
  Gives a window and a renderer, not a UI: text, lists and charts need Dear ImGui or
  hand drawing.

## Findings

- [gui] README targets Zig 0.16 and later, and warns bindings may lag Zig breaking
  changes. `README.md` ^f1
  > For Zig version 0.16+
  > In case of breaking changes in Zig, the bindings might fall behind.
- [gui] CI builds against Zig master on all three OSes, not against a pinned release.
  `.github/workflows/main.yml` ^f2
  > os: [ubuntu-latest, macos-latest, windows-latest]
  > version: master
- [gui] Windows uses D3D11 by default (GL optional); only system libraries are linked, no
  SDK step outside Linux. `README.md`, `build.zig` ^f3
  > - Windows: D3D11
  > All other platforms should build 'out of the box'.
  > mod.linkSystemLibrary("d3d11", .{});
- [gui] Dear ImGui is not bundled; sokol_imgui.h bindings are opt-in and expect a
  separate C binding (cimgui) supplied by the app. `build.zig` ^f4
  > "Add support for sokol_imgui.h bindings"
  > "Override the Dear ImGui C bindings header name (default: cimgui.h)"
- [gui] The ImGui route is shown in a separate sample project. `README.md` ^f5
  > Dear ImGui sample project
- [gui] HEAD (2026-10-05) builds all examples for x86_64-windows from macOS with Zig
  0.16.0 in our run ([[zig-gui-win-builds#^f3]]). ^f6

## Read

- `README.md`, `CHANGELOG.md` head, `build.zig` backend and Windows link sections, CI

## Not read

- sokol C headers (sokol_app.h high-DPI handling); `sokol_app` has a `high_dpi` flag per
  upstream docs, not checked here
