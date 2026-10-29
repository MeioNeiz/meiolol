---
title: 'evanw/esbuild issue #608: CSS + code splitting + multiple entry points'
url: https://github.com/evanw/esbuild/issues/608
kind: thread
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: listed (whole thread)
relevance: high
grade: A/strong
description: esbuild's author lays out the design space for splitting CSS across entry points (per-entry duplication, shared runs via @import, CSS-in-JS) and why CSS order forbids the usual JS sharing
---
# evanw/esbuild issue #608: CSS + code splitting + multiple entry points

Why: a bundler author's first-principles account of why shared CSS chunks are hard.

## Assessment

- Evidence: A. Evan Wallace (esbuild author); closed by the v0.12.0 CSS import changes.
- Reasoning: strong. Three options with costs, an order rule, and his choice.
- Interests: none.
- Weigh: written 2021, before he shipped; the final behaviour is in #1293, not read.

## Findings

- [web] His working rule: CSS order is a depth-first post-order walk over the import graph, and a
  bundler may not deviate even for a smaller bundle. ^f1
  > I assume CSS order should be determined by a depth-first post-order traversal over the graph, including from JS files into the CSS files they import
  > I also assume that it's not ok for the bundler to deviate from this order at all since that could result in visual changes, even if deviating from this order would make a smaller bundle.
- [web] Option 1: one CSS file per entry point, shared CSS duplicated; simple. ^f2
  > Just generate a separate CSS file for each entry point without any code splitting or sharing. Common CSS would be duplicated across separate entry points. Mostly simple and straightforward.
- [web] Lazy chunks: simplest is to fold their CSS into the entry's file, one sheet per page,
  easy to reason about order. ^f3
  > The simplest way to solve this is just for dynamic entry points to not have any associated CSS, and to bundle the CSS for all dynamic entry points into the CSS for the top-level entry point.
  > Then there would only ever be a single CSS file per page which makes order easy to reason about.
- [web] Option 2: shared contiguous runs as separate chunks keep exact order and no
  duplication, but chunk count explodes combinatorially. ^f4
  > But there would potentially be a huge number of CSS chunks if there are a couple dozen entry points due to combinatorics, which I assume would be a non-starter for most people.
- [web] Why CSS can't share like JS: no lazily evaluated library; a rule applies once loaded. ^f5
  > Unfortunately CSS doesn't have any mechanism for abstraction so you can't have a "CSS library" with lazily-evaluated code that can be triggered later.
- [web] [web/wasm] Option 3, CSS in JS strings injected at run time: no order or duplication
  problem, but slow and loses parallel CSS download. ^f6
  > I assume it would be slow because of JavaScript processing and because the browser can't download, parse, and interpret the CSS in parallel with the JavaScript.
- [web] His lean: option 1, no CSS code splitting; a commenter says webpack does the same for
  dynamic chunks. ^f7
  > I'm currently considering doing option 1 (no code splitting for CSS).
  > I think Webpack goes with option 1 (disregard dynamic chunks as far as css output is concerned)

## Read

- whole thread

## Not read

- PR #1293 and the v0.12.0 release notes (what shipped)
