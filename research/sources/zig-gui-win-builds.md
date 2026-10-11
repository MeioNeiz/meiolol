---
title: Windows cross-compile test builds of Zig GUI candidates from macOS (Zig 0.16.0, 2026-10-11)
url: local:scratchpad-builds
kind: dataset
commit:
for: [zig-gui-options]
looked: 2026-10-11
depth: ran (7 builds for x86_64-windows, ReleaseSmall, on macOS arm64; none run on Windows)
relevance: high
grade: B/strong
description: Our own builds: which GUI candidates compile for Windows from macOS with the local Zig 0.16.0, exe sizes and DLL imports
---
# Windows cross-compile test builds of Zig GUI candidates from macOS (Zig 0.16.0, 2026-10-11)

Why: README claims about Zig versions and cross-compiling are cheap; does each candidate
actually build for `x86_64-windows` from this Mac with the Zig meiolol pins?

## Assessment

- Evidence: B. First-hand, exact commands and outputs saved; one machine, one day.
- Reasoning: strong for "compiles"; says nothing about runtime (no Windows run yet).
- Interests: none.
- Weigh: sizes are ReleaseSmall and include Zig 0.16's std.Io overhead
  ([[ziggit-releasesmall-size#^f1]]). DLL lists come from `strings`, so they include
  names loaded dynamically (GLFW probes GLES, Vulkan, OSMesa) not just imports. Builds
  were from shallow clones at the commits in [[dvui-repo]], [[sokol-zig-repo]],
  [[zgui-repo]], [[raylib-zig-repo]], [[zigwin32-repo]], [[capy-repo]].

## Findings

- [gui] dvui main (00ea4f6c) with the dx11 backend: a hello window with a label and a
  `plotXY` line chart built for Windows from macOS on Zig 0.16.0, no SDK, about 34 s
  cold. ^f1
  > Build Summary: 10/10 steps succeeded
  > zig-out/bin/hello.exe: PE32+ executable (GUI) x86-64, for MS Windows
- [gui] dvui hello size: 3405312 bytes with defaults (tree-sitter on for dx11), 2588160
  bytes with tree-sitter off. Imports d3d11.dll and D3DCOMPILER_47.dll. ^f2
  > 3405312 11 Oct 03:32 hello.exe
  > 2588160 11 Oct 03:32 hello.exe
  > D3DCOMPILER_47.dll
- [gui] sokol-zig HEAD (e12ece1c) builds all its examples for Windows on Zig 0.16.0;
  debugtext.exe 153600 bytes, clear.exe 500736 (std formatting); d3d11.dll. ^f3
  > 153600 11 Oct 03:33 debugtext.exe
  > zig-out/bin/debugtext.exe: PE32+ executable (console) x86-64, for MS Windows
- [gui] sokol-zig-imgui-sample HEAD (sokol + dcimgui) fails on Zig 0.16.0 inside the
  translate_c and aro packages it pulls in (they target 0.17). ^f4
  > error: invalid builtin function: '@backingInt'
  > error: no field named 'debug' in enum 'builtin.OptimizeMode'
- [gui] zgui HEAD (a25eb043) with `-Dbackend=win32_dx12 -Dwith_implot=true` compiles
  ImGui, ImPlot and the C++ Win32/DX12 backends for Windows on 0.16.0; its test exe is
  1448960 bytes. No window app built. ^f5
  > Build Summary: 7/7 steps succeeded
  > 1448960 11 Oct 03:34 zgui-tests.exe
- [gui] raylib-zig at 8758f4cd3a (last 0.16 commit) builds its examples for Windows on
  0.16.0; basic_window.exe is 985600 bytes, OpenGL via GLFW. ^f6
  > 985600 11 Oct 03:34 .zig-cache/o/96e7c07558c6b9c1c42e62408039ded8/basic_window.exe
  > WGL: Failed to load opengl32.dll
- [gui] zigwin32 HEAD (9f15c276): a minimal hand-written Win32 window builds on 0.16.0
  at 5120 bytes. ^f7
  > Build Summary: 3/3 steps succeeded
  > 5120 11 Oct 03:35 hello.exe
- [gui] capy HEAD (fd77077e) fails on Zig 0.16.0 before compiling: its build.zig.zon
  uses old-format dependency hashes. ^f8
  > error: invalid hash: incomplete
- [gui] (inferred) Every candidate that declares 0.16 support cross-compiled from macOS
  with no MSVC or Windows SDK; Zig's bundled MinGW headers and import libraries were
  enough for D3D11, D3D12 and OpenGL. ^f9

## Read

- All seven build outputs in full

## Not read

- Runtime behaviour: none of the exes has been launched on Windows (DPI, fonts, idle
  CPU, D3DCompile availability). Next step: run dvui hello on a Windows PC
