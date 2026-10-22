---
title: 'zjb patched for Zig 0.17, and a tpl island spike (our run, 2026-10-22)'
url: https://meio.lol/?measured=zjb-tpl-island-spike
kind: dataset
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: ran
relevance: high
grade: A/fair
description: Patched zjb's two @typeInfo call sites for Zig 0.17 and built a filter-like island in Zig (tpl render, click, localStorage, fetch) with a 5-line JS loader; ran in Chrome
---
# zjb patched for Zig 0.17, and a tpl island spike (our run, 2026-10-22)

Why: Jacob asked whether we can update the Zig to JS bridge rather than keep JS. Does
zjb come back on 0.17 cheaply, and can meiolol's tpl components run as a browser island
with no hand-written JS beyond a loader?

## Assessment

- Evidence: A for what we built and ran; one small island, a local server, desktop
  Chrome only; no phone, no Safari, no real data size.
- Reasoning: fair.
- Interests: none.
- Weigh: proves feasibility and size, not ergonomics at scale or Safari behaviour.

## Findings

- [web/wasm] [toolchain] zjb builds on Zig 0.17 after changing its two @typeInfo call sites (struct `field_types`, fn `param_types`, `Fn.ParamAttributes`); the example runs in Chrome. ^f1
  > const fields = @typeInfo(@TypeOf(args)).@"struct".field_types;
  > zjb example builds and runs in Chrome: console shows Hello from Zig
- [web/wasm] A Zig island rendered rows with meiolol's tpl, re-summed them on a rank click, kept the pick in localStorage across a reload, and loaded data by fetch, all from Zig. ^f2
  > diamond+: Garen | 51.9% | 160
  > after reload pressed: Diamond+
- [web/wasm] tpl's escaping holds in the browser: a name containing a script tag rendered as text. ^f3
  > script tags in table: 0
- [web/wasm] Size: 6.0 KB gzip wasm plus 0.9 KB gzip generated glue; the only hand-written JS is a 5-line loader. ^f4
  > island.wasm ReleaseSmall 11433 bytes, gzip 6004; zjb.js 4446 bytes, gzip 870
  > load.js 174 bytes (5 lines, the only hand-written JS)
- [web/wasm] (inferred) Pain points seen: every Handle needs a release, async is callbacks (fetch then text then a second callback), and JS strings reach Zig through TextEncoder.encodeInto into a buffer. ^f5
  > const res = enc.call("encodeInto", .{ text, view }, zjb.Handle);

## Read

- Our build and run output, `raw/zjb-tpl-island-spike.md`

## Not read

- Safari and phone behaviour; Debug build stepping in Chrome
