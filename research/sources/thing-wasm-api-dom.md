---
title: 'thi.ng wasm-api and wasm-api-dom: READMEs'
url: https://github.com/thi-ng/umbrella
kind: project
commit: 4733a9388fb1f112b764420979c8c87c4fa2ca0c
for: [zig-web-ui]
looked: 2026-10-12
depth: docs (READMEs)
relevance: medium
grade: A/fair
description: thi.ng wasm-api and wasm-api-dom: TypeScript host bridge plus Zig bindings to create and update DOM from Zig wasm, with events
---
# thi.ng wasm-api and wasm-api-dom: READMEs

Why: how do Zig wasm apps drive the DOM, and is there a mature bridge?

## Assessment

- Evidence: A for the umbrella (since 2018, 3,829 stars, one prolific maintainer); the Zig DOM part is a niche corner of it.
- Reasoning: fair. Documents the handle model and init pattern.
- Interests: none known.
- Weigh: needs the TypeScript host package (npm); supports Zig 0.15+, 0.16 not stated. Shows the bridge pattern we would write ourselves.

## Findings

- [web] A TypeScript core plus Zig bindings to create and change DOM elements from Zig wasm. `packages/wasm-api-dom/README.md` ^f1
  > Browser DOM bridge API for hybrid TypeScript & WASM (Zig) applications.
- [web] DOM objects stay on the JS side; Zig refers to them by integer handles. `packages/wasm-api-dom/README.md` ^f2
  > the bridge API caches those on the host side and [uses
  > managed ID (integer)
- [web] Event handlers for input, key, mouse, pointer, scroll, touch and wheel are bound from Zig. `packages/wasm-api-dom/README.md` ^f3
  > Event handlers, event types
- [web] [toolchain] Zig versions older than 0.15.1 are no longer actively supported. `packages/wasm-api/README.md` ^f4
  > older Zig versions than
  > [v0.15.1](https://ziglang.org/download/0.15.1/release-notes.html), are not
  > actively supported anymore

## Read

- `packages/wasm-api-dom/README.md`: About to DOM tree creation
- `packages/wasm-api/README.md`: Zig version section

## Not read

- the zig-todo-list example: size of a real app; wasm-api-dom/zig/*.zig
