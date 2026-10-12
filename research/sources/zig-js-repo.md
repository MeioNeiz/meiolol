---
title: 'zig-js (mitchellh/zig-js): README'
url: https://github.com/mitchellh/zig-js
kind: project
commit: 3c23860e47fdcdc5af805efb7fd0bdac5fd3e9bc
for: [zig-web-ui]
looked: 2026-10-12
depth: docs (README)
relevance: medium
grade: B/fair
description: Mitchell Hashimoto's zig-js: Zig wasm calls into a JS host through glue objects; JS-to-Zig not covered; JS glue in its js/ folder
---
# zig-js (mitchellh/zig-js): README

Why: is there a thin Zig-to-JS interop layer?

## Assessment

- Evidence: B. Created 2022-12, pushed 2026-04-16, 290 stars, 3 contributors; by Ghostty's author.
- Reasoning: fair. States scope (Zig to JS only) and costs (deinit, error handling).
- Interests: none known.
- Weigh: the JS glue is a TypeScript package not yet on npm; README build example uses the pre-0.12 API.

## Findings

- [web/wasm] Lets Zig in wasm get, set and call JS values; JS calling Zig is out of scope. `README.md` ^f1
  > Note this makes it particularly easy for Zig to call into JS. This
  > doesn't help for JS calling into Zig.
- [web/wasm] Host-side values must be released with deinit. `README.md` ^f2
  > `deinit` calls are necessary to dereference garbage-collected
- [web/wasm] JS side is a glue package in the repo's js/ folder, not yet published to npm. `README.md` ^f3
  > this will be published to npm
- [web/wasm] [toolchain] build.zig.zon declares minimum Zig 0.15.1. `build.zig.zon` ^f4
  > .minimum_zig_version = "0.15.1",

## Read

- `README.md`: top 60 lines
- `build.zig.zon`

## Not read

- `js/` glue size
