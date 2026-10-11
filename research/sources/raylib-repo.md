---
title: 'raylib (raysan5/raylib): README features, build.zig platforms, Zig minimum at 6.0 and master'
url: https://github.com/raysan5/raylib
kind: project
commit: 453cc35f27d652155e6f3d62907f381a08bb8b03
for: [zig-gui-options]
looked: 2026-10-11
depth: code (README features, build.zig.zon at master and tag 6.0, build.zig Windows parts)
relevance: medium
grade: A/fair
description: raylib C game library with its own build.zig; 6.0 needs Zig 0.16, master needs 0.17; OpenGL or software renderer on Windows
---
# raylib (raysan5/raylib): README features, build.zig platforms, Zig minimum at 6.0 and master

Why: raylib's own build.zig is the base for raylib-zig and a dvui backend; what Zig and
renderer does it need on Windows?

## Assessment

- Evidence: A. Created 2013-10, pushed 2026-10-10, 35148 stars, 3325 forks, 100+
  contributors, release 6.0 on 2026-04-23.
- Reasoning: fair.
- Interests: none.
- Weigh: very mature, but it is a game library; desktop-app concerns (native text
  rendering, idle CPU, accessibility) are not its focus.

## Findings

- [gui] Master's build.zig.zon needs Zig 0.17.0; release 6.0 needs 0.16.0.
  `build.zig.zon`, `tag-6.0/build.zig.zon` ^f1
  > .minimum_zig_version = "0.17.0",
  > .minimum_zig_version = "0.16.0",
- [gui] Renders with OpenGL, or a software renderer that needs no OpenGL. `README.md` ^f2
  > Hardware accelerated with OpenGL: **1.1, 2.1, 3.3, 4.3, ES 2.0, ES 3.0**
  > **Software Renderer** backend (no OpenGL required!)
- [gui] On Windows, default platform is GLFW (bundled) with opengl32; there is also a
  native Win32 platform layer. `build.zig` ^f3
  > raylib_mod.addCMacro("PLATFORM_DESKTOP_GLFW", "");
  > raylib_mod.addCMacro("PLATFORM_DESKTOP_WIN32", "");
  > if (opengl) mod.linkSystemLibrary("opengl32", .{});
- [gui] No external dependencies; everything is vendored. `README.md` ^f4
  > **NO external dependencies**, all required libraries are
- [gui] Checked, not there: no widget toolkit in raylib itself; UI is the separate raygui
  library. ^f5

## Read

- README features list; build.zig platform and Windows link sections; zon at master and 6.0

## Not read

- HIGHDPI flag behaviour on Windows; raygui
