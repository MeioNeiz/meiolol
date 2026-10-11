---
title: 'zgui (zig-gamedev/zgui): Dear ImGui + ImPlot Zig bindings, README, build.zig, CI'
url: https://github.com/zig-gamedev/zgui
kind: project
commit: a25eb0434a3e032e44e2e40238cd9a390aeec028
for: [zig-gui-options]
looked: 2026-10-11
depth: code (README, build.zig.zon, build.zig backend list and win32_dx12 section, CI)
relevance: high
grade: B/fair
description: Hand-written Zig bindings and build package for Dear ImGui with ImPlot; minimum Zig 0.16.0, has a native win32_dx12 backend
---
# zgui (zig-gamedev/zgui): Dear ImGui + ImPlot Zig bindings, README, build.zig, CI

Why: the Dear ImGui route that is on Zig 0.16 today (the sokol sample has moved to
0.17-dev), and it bundles ImPlot for line charts.

## Assessment

- Evidence: B. Repo created 2024-11 (split out of the older zig-gamedev monorepo), pushed
  2026-09-26, 164 stars, 83 forks, 34 contributors, no releases. Dear ImGui itself is A
  (canonical, used everywhere). CI runs `zig build test` on Linux, Windows and macOS with
  the zon's minimum Zig.
- Reasoning: fair.
- Interests: none known.
- Weigh: Dear ImGui looks like a tool, not a consumer app, unless styled. The win32_dx12
  backend is C++ from upstream ImGui compiled by Zig; we compiled it from macOS
  ([[zig-gui-win-builds#^f5]]) but did not run a window.

## Findings

- [gui] Declares Zig 0.16.0 as minimum. `build.zig.zon` ^f1
  > .minimum_zig_version = "0.16.0",
- [gui] Bindings for Dear ImGui plus extras, with ImPlot for data visualisation.
  `README.md` ^f2
  > Zig build package and bindings for [Dear Imgui](https://github.com/ocornut/imgui) & extras.
  > [Plot API](#plot-api) for advanced data visualizations
- [gui] Backends include a native Win32 + D3D12 one and GLFW + OpenGL3, among others.
  `build.zig` ^f3
  > .win32_dx12 => {
  > "libs/imgui/backends/imgui_impl_win32.cpp",
- [gui] The win32_dx12 backend compiles upstream ImGui's C++ backends and links
  d3dcompiler_47. `build.zig` ^f4
  > "libs/imgui/backends/imgui_impl_dx12.cpp",
  > imgui_mod.linkSystemLibrary("d3dcompiler_47", .{});
- [gui] All allocations go through a Zig allocator. `README.md` ^f5
  > All memory allocations go through user provided Zig allocator
- [gui] CI: build and test on three OSes with setup-zig defaulting to the zon minimum.
  `.github/workflows/main.yml` ^f6
  > os: [ubuntu-latest, windows-latest, macos-latest]
  > run: zig build test

## Read

- `README.md` top and versions, `build.zig.zon`, `build.zig` options and backend
  sections, CI

## Not read

- Sample apps (live in zig-gamedev samples repo); DPI handling of imgui_impl_win32
  (upstream has `ImGui_ImplWin32_EnableDpiAwareness`, not checked here)
