---
title: 'js-framework-benchmark: Chrome 154 results (keyed)'
url: https://krausest.github.io/js-framework-benchmark/2026/chrome154.html
kind: dataset
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: ran (parsed the keyed tables for 13 columns)
relevance: high
grade: A/fair
description: Stefan Krause's standard DOM benchmark, Chrome 154 run (Oct 2026), 196 keyed implementations incl. Rust wasm (wasm-bindgen, Leptos, Sycamore, Dioxus, Yew) and Blazor
---
# js-framework-benchmark: Chrome 154 results (keyed)

Why: what does driving the DOM from wasm cost against vanilla JS, measured the same way
for every framework?

## Assessment

- Evidence: A. The reference benchmark for DOM frameworks since 2016 (7.5k stars, a run
  per Chrome release; this one released 2026-10-04). Same harness, same machine for all.
- Reasoning: fair. Numbers, not explanations; methodology in the repo, not on the page.
- Interests: none; implementations are written by each framework's fans, so effort varies.
- Weigh: a 1,000 to 10,000 row table on a desktop CPU (some tests with 4x CPU slowdown);
  no phone run. Numbers below are medians parsed from the raw page with
  a throwaway parser (cells read "20.10.2 (1.01)" = 20.1 ms ± 0.2, factor
  1.01 vs fastest). No Zig implementation exists in the benchmark.

## Findings

- [web/wasm] Chrome 154 run, 196 keyed implementations. ^f1
  > Chrome 154.0.8037.98
  > 196 implementations
- [web/wasm] Duration, geometric mean of slowdown vs fastest (ran: parsed): vanillajs
  1.05, vanillajs-lite 1.01, hand-written Rust wasm-bindgen 1.12, Solid 1.13, Leptos
  0.7 1.31, Sycamore 0.9 1.31, Dioxus 0.7 1.32, Yew 0.23 1.55, React hooks 19.2 1.59,
  Blazor wasm 10 4.84. ^f2
  > Duration in milliseconds ± 95% confidence interval (Slowdown = Duration / Fastest)
- [web/wasm] Hand-written wasm-bindgen calls (no framework) are within 7% of vanillajs on
  the duration mean, so the wasm-to-DOM boundary itself costs little here; the
  framework layer costs more (Leptos/Sycamore/Dioxus 25-30% over vanillajs). (inferred
  from ^f2) ^f3
- [web/wasm] Creating 1,000 rows (ran: parsed): vanillajs 20.6 ms, wasm-bindgen 22.2,
  Leptos 25.1, Dioxus 24.1, Yew 31.7, Blazor 72.9. ^f4
  > creating 1,000 rows. (5 warmup runs).
- [web/wasm] Memory after page load (ran: parsed): vanillajs 0.48 MB, wasm-bindgen 1.72,
  Leptos 1.77, Sycamore 1.68, Dioxus 1.90, Yew 1.76, Blazor 41.14: a wasm instance costs
  about 1.2 MB more at rest. ^f5
  > Memory usage after page load.
- [web/wasm] Size and first paint (ran: parsed): brotli size vanillajs 2.5 kB,
  wasm-bindgen 14.5, Leptos 48.8, Sycamore 47.2, Dioxus 114.9, Yew 56.8, React 51.4,
  Blazor 1,377.0; first paint vanillajs 53.8 ms, wasm-bindgen 73.9, Leptos 239.6,
  Sycamore 209.2, Dioxus 540.9, Yew 262.1, React 226.6. ^f6
  > brotli compressed size of all implementation files (excluding /css and http headers)
- [web/wasm] Startup geometric mean (size and first paint): vanillajs 2.29,
  wasm-bindgen 7.35, Leptos 25.96, Sycamore 23.07, Dioxus 59.04, Yew 28.75, React
  25.96: startup, not update speed, is where wasm frameworks lose most. (ran: parsed) ^f7
  > Transferred size (in kBs) and first paint
- [web/wasm] Last run to include non-keyed implementations (release note, chrome154 tag). ^f8

## Read

- Keyed duration, memory, size and first paint tables for the 13 columns named above.

## Not read

- Test environment section (collapsed on the page; machine and CPU not captured).
- Non-keyed tables.
