---
title: 'Ziex (nurulhudaapon/ziex): README, build.zig.zon'
url: https://github.com/nurulhudaapon/ziex
kind: project
commit: 22241f7deb7d120dc0d48bdefc907d107115004b
for: [zig-web-ui]
looked: 2026-10-12
depth: docs (README, build.zig.zon)
relevance: medium
grade: B/fair
description: Full-stack Zig web framework with JSX-like .zx components: SSR, static export, client rendering in progress; 0.1.0 targets Zig 0.17
---
# Ziex (nurulhudaapon/ziex): README, build.zig.zon

Why: is there a Zig framework with components like React that could render our pages and add interactivity?

## Assessment

- Evidence: B. Created 2025-10, pushed 2026-10-08, 364 stars, 14 contributors, an rc release. Young.
- Reasoning: fair. States clearly what is stable (SSR) and what is not (client side).
- Interests: own project's README.
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

## Read

- `README.md`: all
- `build.zig.zon`: version line

## Not read

- ziex.dev/learn docs; how .zx files are transpiled (build step or CLI); client-side wasm design
