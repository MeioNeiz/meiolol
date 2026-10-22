---
title: 'Ziex (nurulhudaapon/ziex): README, build.zig.zon, client runtime'
url: https://github.com/nurulhudaapon/ziex
kind: project
commit: d654002a4d575ec7aa4abe40a3e9d7a5fa467d0c
for: [zig-web-ui, zig-only-frontend]
looked: 2026-10-22
depth: code (README, build.zig.zon at 22241f7; client runtime at d654002)
relevance: medium
grade: B/fair
description: Full-stack Zig web framework with JSX-like .zx components: SSR, static export, client rendering via a DOM command buffer flushed to a TypeScript runtime; Zig 0.17, 0.1.0-rc.4
---
# Ziex (nurulhudaapon/ziex): README, build.zig.zon, client runtime

Why: is there a Zig framework with components like React that could render our pages and add interactivity?

## Assessment

- Evidence: B. Created 2025-10, pushed 2026-10-08, 364 stars, 14 contributors, an rc release. Young.
- Reasoning: fair. States clearly what is stable (SSR) and what is not (client side).
- Interests: own project's README.
- Revisited 2026-10-22: 398 stars, 54 commits since 12 Oct, v0.1.0-rc.4 on 18 Oct, still
  a developer preview by its release notes; that commit pace suggests agent-assisted work.
- Weigh: needs its own .zx transpiler and CLI; main line is Zig 0.17, 0.16 branch outdated. Client-side rendering not documented yet.

## Findings

- [web/template] Components are Zig functions returning `zx.Component`, written in JSX-like markup with Zig control flow. `README.md` ^f1
  > A Ziex Component is a Zig function that returns a `zx.Component`.
- [web/template] [web/wasm] Server-side rendering is called production-ready; client-side rendering and state are still evolving and undocumented. `README.md` ^f2
  > server-side rendering (SSR) features are production-ready, Ziex continues to evolve with ongoing improvements to client-side rendering and state management
- [web/template] Supports static site generation, which is what meiolol's site is. `README.md` ^f3
  > Pre-render pages at build/export time into static HTML for fast CDN delivery.
- [web/template] [toolchain] Latest release targets Zig 0.17; the 0.16 line is marked outdated. `README.md` ^f4
  > Ziex 0.1.0 is planned for release after `Zig 0.17.0` is available.
- [web/template] [toolchain] build.zig.zon on main requires Zig 0.17.0. `build.zig.zon` ^f5
  > .minimum_zig_version = "0.17.0",

- [web/wasm] Client rendering: Zig writes 24-byte DOM op records (create element, set
  attr, insert, remove...) into a buffer instead of calling DOM APIs one by one.
  `src/runtime/client/dom_cmd.zig` ^f6
  > /// Wire opcodes -> `pkg/ziex/src/wasm/dom_cmd.ts`.
  > pub const RECORD_SIZE: usize = 24;
- [web/wasm] One import call flushes the whole buffer to JS. `src/runtime/client/window/extern.zig` ^f7
  > /// Apply a packed DomCmd buffer written in WASM linear memory.
- [web/wasm] The JS side holds the real nodes in a Map keyed by number: the handle
  pattern, not externref. `pkg/ziex/src/wasm/index.ts` ^f8
  > const domNodes = new Map
- [web/wasm] The JS runtime is TypeScript, about 1,700 lines in `pkg/ziex/src/wasm` and
  `app.ts` (wc -l), packaged as npm package "ziex"; it instantiates the wasm itself.
  `pkg/ziex/src/wasm/index.ts` ^f9
  > const source = await WebAssembly.instantiateStreaming(fetch(url), importObject);
- [web/wasm] It vendors Mitchell Hashimoto's zig-js externs (u32 ids, freed with
  valueDeinit) for general JS access. `vendor/jsz/src/extern.zig` ^f10
  > pub extern "zig-js" fn valueDeinit(id: u32) void;
- [web/template] (claim) At d654002 the README lists client-side rendering as a feature
  without the SSR-only caveat quoted in ^f2 (README not re-snapped; read 22 Oct). ^f11
- [web/wasm] (inferred) Even the most active Zig framework keeps hand-written JS for the
  DOM and batches across the boundary, the lesson of [[openui-rust-wasm-parser]]. ^f12

## Read

- `README.md`: all
- `build.zig.zon`: version line
- Client runtime files above (d654002): op list, flush, node map

## Not read

- ziex.dev/learn docs; how .zx files are transpiled; `render.zig` (diffing); wasm size of a page; bench/ziex js-framework-benchmark page (not in the official run)
