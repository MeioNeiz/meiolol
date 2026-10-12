---
title: 'Astro: On-demand rendering (docs, 2026)'
url: https://docs.astro.build/en/guides/on-demand-rendering/
kind: docs
commit: 
for: [hybrid-rendering-seo]
looked: 2026-10-12
depth: docs (overview, enabling on-demand rendering)
relevance: medium
grade: A/fair
description: Astro: static by default; per-page `prerender = false` renders that route on a server, the rest stays static files
---
# Astro: On-demand rendering (docs, 2026)

Why: a second mainstream framework's take on mixing static and on-demand pages.

## Assessment

- Evidence: A. Major static-first framework.
- Reasoning: fair. Advises static unless most pages need a server.
- Interests: none beyond the framework.
- Weigh: per-route choice, not per-page-within-a-route like ISR.

## Findings

- [render] Static by default; individual routes opt into server rendering, the rest stay static. ^f1
  > add `export const prerender = false` at the top of the individual page or endpoint you want to render on demand. The rest of your site will remain a static site
- [render] Advice: keep static mode unless most pages need rendering on demand, so static content does not depend on a server. ^f2
  > Start with the default `'static'` mode until you are sure that **most or all** of your pages will be rendered on demand!

## Read

- overview, server adapters intro, enabling on-demand rendering

## Not read

- adapter specifics, streaming, cookies, endpoints
