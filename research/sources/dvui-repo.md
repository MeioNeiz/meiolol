---
title: 'dvui (david-vanderson/dvui): README, build.zig.zon, CI, dx11 backend, PlotWidget'
url: https://github.com/david-vanderson/dvui
kind: project
commit: 00ea4f6c123d60568abcabfae052513294e9d36d
for: [zig-gui-options]
looked: 2026-10-11
depth: code (README, build.zig.zon, build.zig, CI, dx11 backend, PlotWidget, plotXY)
relevance: high
grade: B/fair
description: Pure-Zig immediate-mode GUI toolkit for whole apps; main targets Zig 0.16, has a native DX11 backend and a line-plot widget
---
# dvui (david-vanderson/dvui): README, build.zig.zon, CI, dx11 backend, PlotWidget

Why: leading Zig-native GUI candidate; does it build on Zig 0.16, cross-compile to
Windows without an SDK, and cover text, lists and line charts at high DPI?

## Assessment

- Evidence: B. Created 2022-05, last push 2026-10-09, 1695 stars, 147 forks, 83
  contributors, MIT licence (LICENSE file; GitHub shows "Other"), release v0.4.0
  (2026-04-16, the Zig 0.15 line). CI compiles sdl2, sdl3, web and raylib on Linux and dx11 on Windows. Eleven
  featured projects in the README, mostly hobby apps (pixel editor, podcast player).
- Reasoning: fair. README states design trade-offs of immediate mode (advantages and
  drawbacks) and how frame throttling works.
- Interests: author's own project.
- Weigh: Zig 0.16 support is current on main, but main will move to 0.17 (issue #839,
  2026-10, port in progress by a collaborator); pin a commit or the v0.4.0-style tag line
  that matches our Zig. Our own build confirmed the Windows cross-compile
  ([[zig-gui-win-builds#^f1]]).

## Findings

- [gui] main is tested on Zig 0.16.0; older Zig uses a branch or tag. `README.md` ^f1
  > Tested with Zig v0.16.0 (for Zig v0.15.2, use DVUI branch zig15 or [tag v0.4.0]
- [gui] The package declares Zig 0.16.0 as its minimum. `build.zig.zon` ^f2
  > .minimum_zig_version = "0.16.0",
- [gui] Aimed at whole applications, not only debug overlays. `README.md` ^f3
  > GUI toolkit for whole applications or debugging windows in existing apps/games.
- [gui] The DX11 backend depends on zigwin32 (a fork branch patched for Zig 0.16), so
  the Windows backend is Zig plus Win32 bindings, no C SDK. `build.zig.zon` ^f4
  > // required for the directx11 backend
  > .url = "git+https://github.com/kristoff-it/zigwin32.git?ref=fix/zig16#
- [gui] CI builds the dx11 backend on a Windows runner; other backends on Linux. Native
  Windows CI, not cross-compile from macOS. `.github/workflows/test.yml` ^f5
  > # Add one extra job on windows for dx11
- [gui] Example executables on Windows embed a manifest declaring per-monitor v2 DPI
  awareness (`PerMonitorV2`) and use the GUI subsystem; the dx11 backend sizes windows with
  GetDpiForWindow. `src/main.manifest`, `build.zig`, `src/backends/dx11.zig` ^f6
  > exe.win32_manifest = b.path("./src/main.manifest");
  > const dpi = win32.GetDpiForWindow(hwnd);
- [gui] The dx11 backend compiles its shaders at runtime with D3DCompile, so the exe
  imports D3DCOMPILER_47.dll (ships with Windows 10+). `src/backends/dx11.zig` ^f7
  > const compile_shader = win32.D3DCompile(
- [gui] Has a plot widget: `plotXY` draws a line from xs/ys arrays; axes support linear
  and log scale, auto ticks and mouse hover. `src/dvui.zig`, `PlotWidget.zig` ^f8
  > pub fn plotXY(src: std.builtin.SourceLocation, init_opts: PlotXYOptions, opts: Options) void {
  > mouse_hover: bool = false,
- [gui] Built-in widgets cover our needs: text layout, scroll area, dropdown, combo box,
  reorderable lists (drag to reorder), data grid, tooltips. `README.md` ^f9
  > Drag to reorder/remove/add
- [gui] Can render only when needed (events, animations, timers), so an idle window does
  not spin the GPU. `README.md` ^f10
  > If you want to only render frames when needed, add `dvui.Window.beginWait()` at the start and `dvui.Window.waitTime()` at the end.
- [gui] Immediate-mode API: widgets are functions called each frame, not retained
  objects. `README.md` ^f11
  > Widgets are not stored between frames like in traditional GUI toolkits (GTK, Win32, Cocoa).
- [gui] Other backends: SDL2, SDL3, SDL3GPU, raylib, GLFW/OpenGL, wio (OpenGL/Vulkan),
  pugl, web. The DX11 one is the only native-Windows backend without a C windowing
  library. `README.md` ^f12
- [gui] Zig 0.17 port is open and in progress (issue #839, read with `gh issue view`, not
  snapped); the owner prefers to wait for experience before upgrading. ^f13
- [gui] Draws its own widgets (not native controls); fonts via FreeType or stb_truetype.
  `build.zig` ^f14
  > Freetype (or stb_truetype if false) for font rendering
- [web/wasm] [gui] Has a Web backend (a `web-app` example, demo page), served as files from any web server; it draws the whole UI itself rather than producing HTML. `README.md` ^f15
  > To load examples for this backend, they must first be served through a (local) web server

## Read

- `README.md` fully; `build.zig.zon`; CI; `build.zig` dx11 and example sections;
  `src/backends/dx11.zig` DPI and shader parts; `PlotWidget.zig` head; `plotXY`
- Issues searched for 0.16, dx11, cross compile; #839 read

## Not read

- dx11 backend input and IME handling; text rendering quality at 150% scale on a real
  Windows box (needs a run on Windows)
- dvui-demo template repo
