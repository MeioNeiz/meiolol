---
title: 'Next.js docs: cssChunking (next.config.js, canary 2026)'
url: https://raw.githubusercontent.com/vercel/next.js/canary/docs/01-app/03-api-reference/05-config/01-next-config-js/cssChunking.mdx
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (whole page)
relevance: high
grade: A/strong
description: Next.js App Router CSS chunking modes (true, false, strict, Turbopack graph) and the cost model that trades unused bytes against extra requests
---
# Next.js docs: cssChunking (next.config.js, canary 2026)

Why: how the biggest React framework picks each route's CSS, and the knobs it exposes.

## Assessment

- Evidence: A. Official docs of the most used React framework; the graph mode is new (2026).
- Reasoning: strong. Explains the bytes-versus-requests trade, the ordering cost of
  merging, and how to measure unused CSS.
- Interests: vendor docs (Vercel).
- Weigh: the numbers (20 KB request cost) are defaults, not measurements shown here.

## Findings

- [web] Goal: a route loads close to only its CSS, by splitting and re-ordering into
  chunks; no per-route declaration, it follows imports. ^f1
  > This lets a route load close to only the CSS it needs, instead of loading all the application's CSS at once.
- [web] Default `true` merges files across routes and infers dependencies from import order
  to cut requests. ^f2
  > Next.js will try to merge CSS files whenever possible, determining explicit and implicit dependencies between files from import order to reduce the number of chunks and therefore the number of requests.
- [web] `'strict'` exists for correctness: default merging assumes files with differing
  import orders are independent, which breaks a sheet that depends on another. ^f3
  > if `b.css` depends on `a.css`, `'strict'` prevents the merge and loads them in import order, at the cost of more chunks and requests.
- [web] `false` turns merging and re-ordering off (webpack only). ^f4
  > Next.js will not attempt to merge or re-order your CSS files.
- [web] Turbopack `'graph'` mode prices each extra request in bytes (`requestCost`, default
  20000) and minimises total cost across all routes. ^f5
  > the estimated cost, in bytes, of each additional CSS request. Larger values bias toward fewer, larger shared chunks, and fewer requests overall.
- [web] A route may carry CSS it never imported when that lowers the global total; small
  sheets ride along in shared chunks until they pass about 20 KB. ^f6
  > It optimizes that total, not each route on its own, so a route can end up carrying some CSS it never imported when that keeps the overall cost down.
  > With the default `requestCost` of about 20 KB, `only-a.css` would have to exceed roughly that size before it earns its own chunk, so small stylesheets stay merged.
- [web] Graph algorithm: files imported together by many routes get heavy edges, the graph
  is flattened to a line and cut into chunks; common base files end up in one shared
  chunk. ^f7
  > From these it builds a weighted graph where two CSS files get a heavier edge the more routes import them together in the same order.
- [web] Unused CSS has two causes: dead rules in imported sheets, or another route's CSS
  merged into a shared chunk. ^f8
  > Or the bundler merged another stylesheet into a shared chunk that your route loads.
- [web/qa] Coverage counts `:hover`, `:focus` and JS-toggled classes as unused until
  triggered, so "unused CSS" overstates waste. ^f9
  > watch out for styles that only apply on interaction, such as `:hover`, `:focus`, or classes toggled by JavaScript for menus and modals, since Coverage counts them as unused until you trigger them.

## Read

- whole page

## Not read

- css-chunking-plugin.ts source (merge thresholds are in the discussion note instead)
