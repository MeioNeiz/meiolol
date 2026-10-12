---
title: 'LoLalytics Ahri build page: server response HTML (2026-10-12)'
url: https://lolalytics.com/lol/ahri/build/
kind: docs
commit: 
for: [zig-web-ui]
looked: 2026-10-12
depth: listed
relevance: medium
grade: A/weak
description: LoLalytics' raw server HTML for a champion page, read for how the site is built: Qwik SSR plus a data API
---
# LoLalytics Ahri build page: server response HTML (2026-10-12)

Why: is lolalytics a static site, or does it render per request?

## Assessment

- Evidence: A. One of the main League stats sites; this is its own served page.
- Reasoning: weak. Markup only; the architecture is our reading of it.
- Interests: none.
- Weigh: shows the stack, not why they chose it. Served through Cloudflare (403 to curl).

## Findings

- [web/template] The page is server-rendered by Qwik 1.20 (resumable SSR), per route, not a static file: the html tag carries q:render="ssr", q:container="paused", q:version="1.20.0" (attributes, so not quotable here). ^f1
- [web/wasm] Data comes from a separate API host. ^f2
  > https://a1.lolalytics.com/mega/
- [web] Checked, not there: no sign-in or login anywhere in the page. ^f3

## Read

- raw HTML: grepped for framework markers, API hosts, login

## Not read

- the API's endpoints and caching; how filters (rank, patch) reach it
