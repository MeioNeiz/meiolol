---
status: answered
priority: soon
tags: [gui]
description: Which GUI library fits a small Windows desktop window built in Zig 0.16 from macOS?
---
# Which GUI library fits a small Windows desktop window built in Zig 0.16 from macOS?

Feeds: docs/plan.md "Open decisions" GUI library; next step 4 (desktop app)

## Answer

dvui with its Direct3D 11 backend is the best fit. On local Zig 0.16.0 it was the only
candidate that built a hello window with a text label and a line chart for
x86_64-windows from macOS, with no MSVC or Windows SDK, at 2.6 to 3.4 MB (C1). It is
Zig-native, ships line plots, grids and lists, can redraw only on change, and declares
per-monitor high DPI (C2); 83 contributors and active as of 2026-10-09. Not yet run on a
real Windows PC.

Fallback: zgui (Dear ImGui plus ImPlot) supports 0.16 and its Win32 + D3D12 backend
compiles for Windows; looks like a dev tool unless styled (C4). sokol on its own builds,
but sokol + Dear ImGui needs 0.17-dev (C3). raylib on 0.16 means pinning an old
raylib-zig commit, OpenGL rendering and weak app UI (C5). capy (pins 0.14.1, not
production ready) and Knots (0.17 only, two weeks old) are out (C6). Native Win32 via
zigwin32 builds a 5 KB window but all drawing is by hand.

Zig 0.17.0 shipped on 2026-10-01 and most libraries already follow it, so whatever we
pick must be pinned to a commit and the 0.17 move planned (C7). Recommendation: dvui
main, dx11, tree-sitter off, pinned, plus our own DPI-aware manifest (C8).

| Candidate | Zig 0.16 | Windows from macOS | Backend | Size | Maintenance |
| --- | --- | --- | --- | --- | --- |
| dvui (dx11) | yes; 0.17 port open | built, label + plot | D3D11 | 2.6-3.4 MB | 83 contributors, active |
| sokol-zig alone | yes | built | D3D11 | ~150 KB | 30 contributors, mature core |
| sokol + Dear ImGui | needs 0.17-dev | failed | D3D11 | n/a | sample only |
| zgui (ImGui + ImPlot) | yes | library + test exe | D3D12 or GL3 | 1.4 MB test | 34 contributors |
| raylib-zig | pinned commit only | built | OpenGL | ~1 MB | 84 contributors |
| capy | pins 0.14.1 | fails | native controls | n/a | stalled since 2025-07 |
| Native Win32 | yes | built | GDI by hand | 5 KB | generated bindings |

Sizes within 0.5 MB are noise: Zig 0.16 adds about 500 KB to any Windows exe.

## Claims

- C1: dvui main builds a Windows GUI exe from macOS on Zig 0.16 with no SDK, via DX11 and zigwin32 (2.6 to 3.4 MB, needs D3DCOMPILER_47.dll from Windows 10). for: [[dvui-repo#^f1]], [[dvui-repo#^f2]], [[dvui-repo#^f4]], [[zig-gui-win-builds#^f1]], [[zig-gui-win-builds#^f2]]
- C2: dvui covers text, lists, grids and line charts, redraws on change, and declares per-monitor high DPI on Windows. for: [[dvui-repo#^f6]], [[dvui-repo#^f8]], [[dvui-repo#^f9]], [[dvui-repo#^f10]]
- C3: sokol + Dear ImGui does not build on Zig 0.16 today (sample needs 0.17-dev); sokol alone does. for: [[sokol-zig-imgui-sample#^f1]], [[zig-gui-win-builds#^f4]], [[zig-gui-win-builds#^f3]]
- C4: zgui is the working Dear ImGui route on 0.16, with ImPlot for charts and a Win32 + D3D12 backend that compiles for Windows. for: [[zgui-repo#^f1]], [[zgui-repo#^f2]], [[zig-gui-win-builds#^f5]]
- C5: raylib on 0.16 means pinning raylib-zig 8758f4cd3a or raylib 6.0; rendering is OpenGL and raygui is weak for app UI. for: [[raylib-zig-repo#^f1]], [[raylib-zig-repo#^f2]], [[raylib-repo#^f1]], [[zig-gui-win-builds#^f6]], [[ziggit-raylib-vs-sokol#^f1]]
- C6: capy and Knots are out: wrong Zig version and immature. for: [[capy-repo#^f1]], [[capy-repo#^f2]], [[zig-gui-win-builds#^f8]], [[knots-repo#^f1]]
- C7: Zig 0.17.0 shipped on 2026-10-01 and libraries follow master or already require 0.17, so meiolol must pin a commit and plan the 0.17 move. for: [[zig-download-page#^f1]], [[sokol-zig-repo#^f2]], [[raylib-zig-repo#^f1]], [[dvui-repo#^f13]]
- C8 (inferred): Use dvui with DX11, pinned; fallback zgui with Win32 + D3D12 and ImPlot. from: C1, C2, C4, C7

## Disagreements

None between sources. Size claims differ only by Zig's own overhead
([[ziggit-releasesmall-size#^f1]]).

## Open

- Run the dvui hello on a real Windows PC: DPI at 150%, font quality, idle CPU,
  D3DCOMPILER_47.dll present
- Full zgui Win32 + D3D12 window app not built
- Cost of moving meiolol to Zig 0.17 (release notes not read); whether 0.17 fixes the exe
  size regression
- Terminal UI fallback and what players expect from a desktop app not researched;
  zig-webui and Clay queued as leads
