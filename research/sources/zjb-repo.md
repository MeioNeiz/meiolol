---
title: 'zjb (scottredig/zig-javascript-bridge): README'
url: https://github.com/scottredig/zig-javascript-bridge
kind: project
commit: eecd2de950c8b4c8c03a7f73671b0d1f7f177d66
for: [zig-web-ui]
looked: 2026-10-12
depth: docs (README)
relevance: high
grade: B/strong
description: Zig JavaScript Bridge: call JS from Zig wasm via handles; a Zig tool generates only the JS glue the wasm uses; Zig 0.16
---
# zjb (scottredig/zig-javascript-bridge): README

Why: is there a thin Zig-to-JS interop layer that fits a static site on Zig 0.16 with no npm?

## Assessment

- Evidence: B. Created 2024-03, pushed 2026-04-16, 89 stars, 4 contributors; tracks Zig releases.
- Reasoning: strong. Explains the problem, compares with Go syscall/js, states costs (manual release, memory views invalidated on growth).
- Interests: none known.
- Weigh: small and focused; verify a build in meiolol and the generated JS size.

## Findings

- [web/wasm] Calls JS from Zig, e.g. `zjb.global("console").call("log", ...)`. `README.md` ^f1
  > This library creates bindings for accessing Javascript from within a WASM runtime.
- [web/wasm] [toolchain] Known to work with Zig 0.16.0. `README.md` ^f2
  > As of 2026-04-16, zjb is only known to work with Zig 0.16.0.
- [web/wasm] A generator reads the wasm and writes JS glue for only the calls used; the generator is Zig (`src/generate_js.zig`), no npm. `README.md` ^f3
  > Run an extract methods program on the WASM file, producing a Javascript file to use along with your WASM file.
- [web/wasm] JS objects live in a JS-side map; Zig holds integer handles and must release them. `README.md` ^f4
  > zjb requires manual Handle releasing.
- [web/wasm] Exposes Zig functions to JS (`exportFn`, `fnHandle` for callbacks such as event listeners). `README.md` ^f5
  > `zjb.fnHandle` uses `zjb.exportFn` and additionally returns a `zjb.ConstHandle` to that function.
- [web/wasm] Author calls it fully functional and ready for use; 1.0 waits for Zig 1.0. `README.md` ^f6
  > ZJB is fully functional and is ready to be used in other projects.

## Read

- `README.md`: all

## Not read

- `src/zjb.zig`, `src/generate_js.zig`, `example/`: size of glue, how the build step runs
