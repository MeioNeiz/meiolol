---
title: 'Verve (sirhco/verve): README, build.zig.zon'
url: https://github.com/sirhco/verve
kind: project
commit: f353184e062234733c6558f3021dac7890a52045
for: [zig-web-ui]
looked: 2026-10-12
depth: docs (README, build.zig.zon)
relevance: low
grade: D/fair
description: Pure-Zig full-stack framework: SSR plus wasm islands with signals, and desktop via system webview; pre-1.0, one contributor
---
# Verve (sirhco/verve): README, build.zig.zon

Why: is there a Zig framework that does SSR plus interactive wasm islands?

## Assessment

- Evidence: D. Created 2026-05-15, 5 stars, 1 contributor, v0.53 in three months with 1,353 tests: signs of agent-driven development; volume says little.
- Reasoning: fair. Explains its design bets; author says not production-ready.
- Interests: author's own project.
- Weigh: the architecture (SSR + wasm islands + signals) is the interesting part, not the dependency.

## Findings

- [web] SSR pages plus a wasm32-freestanding client runtime with signals, split into per-island wasm chunks. `README.md` ^f1
  > Server-side rendering with fine-grained reactivity, a wasm32-freestanding
- [web] Author says pre-1.0, APIs will break, use for learning and personal projects. `README.md` ^f2
  > Use for learning, experiments,
  > and personal projects. Not production-ready.
- [web] [toolchain] Targets Zig 0.16.0. `build.zig.zon` ^f3
  > .minimum_zig_version = "0.16.0",
- [web] Output is an HTTP server binary (or desktop webview), not a static site; our site is static nginx. `README.md` ^f4
  > `zig build` produces either an HTTP server with the WASM client

## Read

- `README.md`: top 70 lines
- `build.zig.zon`: version line

## Not read

- docs/, ROADMAP.md: whether a static export exists
