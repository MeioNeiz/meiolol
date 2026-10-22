---
title: 'The Truth about Rust/WebAssembly Performance (Greg Johnston, 2023)'
url: https://www.youtube.com/watch?v=4KtotxNAwME
kind: video
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (transcript, sections on the DOM myth, string interop, bundle size)
relevance: high
grade: B/strong
description: Leptos's author walks the js-framework-benchmark to explain where wasm UI frameworks lose time: UTF-8 to UTF-16 string copies on element creation, not DOM calls; startup bound by CSS for small apps
---
# The Truth about Rust/WebAssembly Performance (Greg Johnston, 2023)

Why: a write-up of where the cost of wasm DOM frameworks actually is.

## Assessment

- Evidence: B. Greg Johnston, author of Leptos, reading the public benchmark (Chrome 103
  era, 2023); 218k views.
- Reasoning: strong. Goes benchmark by benchmark and names the mechanism.
- Interests: author of one of the frameworks compared; says so.
- Weigh: three years old; JS String Builtins (2024-25) target exactly the string cost
  he names, but only for wasm that keeps strings as JS strings, not UTF-8 in linear
  memory as Zig does. Auto captions.

## Findings

- [web/wasm] Direct DOM access would close only a small gap; the main cost is copying
  strings from wasm to JS. @2:08 ^f1
  > the main constraint is not actually the ability to call um Dom apis from webassembly it's actually the cost of copying strings from webassembly over into JavaScript
- [web/wasm] On the 2023 run hand-written wasm-bindgen was about 4% slower than vanilla
  JS. @5:24 ^f2
  > it's typically about four percent slower right than the JavaScript equivalent
- [web/wasm] Creation is where wasm pays: every UTF-8 string is copied and re-encoded to
  UTF-16. @9:55 ^f3
  > to pass them through to JavaScript they have to be actually not only byte wise copied from webassembly into JavaScript but then re-encoded from utf-8 into utf-16
- [web/wasm] Dioxus's Sledgehammer gets close to vanilla by batching and encoding element
  names as ids instead of strings. @11:25 ^f4
  > they actually have their own special encoding that doesn't pass element names as strings
- [web/wasm] Updates that need diffing but few DOM calls (swap rows) favour wasm
  frameworks. @8:33 ^f5
  > you only make one or two calls out to the Dom
- [web/wasm] For a small app the load time was bound by CSS, not wasm or JS. @25:37 ^f6
  > What's blocking the loading time is not actually JavaScript or webassembly it's actually the CSS
- [web/wasm] Wasm binaries are larger than JS and still need JS glue on top. @22:37 ^f7
  > webassembly binary sizes are large they're larger than JavaScript and you also have to ship JavaScript

## Read

- Transcript 0:00-11:30 and 22:37-end.

## Not read

- 11:30-22:37 (virtual DOM vs fine-grained reactivity internals).
