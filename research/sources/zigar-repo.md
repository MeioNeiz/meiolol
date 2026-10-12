---
title: 'Zigar (chung-leong/zigar): README'
url: https://github.com/chung-leong/zigar
kind: project
commit: 2f05db5c7f7a43643229d32292d0562d8f83659f
for: [zig-web-ui]
looked: 2026-10-12
depth: docs (README)
relevance: low
grade: B/fair
description: Zigar: use Zig from JS/PHP projects, full type marshalling, via Node or bundler plugins (Webpack, Rollup, Vite)
---
# Zigar (chung-leong/zigar): README

Why: is there a Zig-JS interop toolkit?

## Assessment

- Evidence: B. Created 2023-05, pushed 2026-10-10, 442 stars, 1 contributor; versioned per Zig release.
- Reasoning: fair. README is a feature list; details in the wiki.
- Interests: none known.
- Weigh: aimed at JS apps importing Zig through a bundler: the opposite direction to a Zig-first static site.

## Findings

- [web] Marshals all Zig types to JS and calls both ways. `README.md` ^f1
  > Access to all Zig data types in JavaScript/PHP
- [web] The WebAssembly route runs through bundler plugins. `README.md` ^f2
  > Support for Webpack, Rollup, and Vite (WebAssembly)
- [web] [toolchain] Version 0.16.0 matches Zig 0.16. `README.md` ^f3
  > Use version 0.16.0
  > if you're still using that version of Zig.

## Read

- `README.md`: all

## Not read

- wiki: wasm setup without a bundler
