---
title: 'Vite guide: Features (CSS, build optimisations)'
url: https://raw.githubusercontent.com/vitejs/vite/main/docs/guide/features.md
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (Build Optimizations: CSS Code Splitting, preload, async chunk loading)
relevance: medium
grade: A/fair
description: Vite's automatic CSS code splitting: CSS used by an async chunk becomes its own file, linked when that chunk loads, JS held until the CSS is in
---
# Vite guide: Features (CSS, build optimisations)

Why: the bundler under SvelteKit, Astro, Nuxt and React Router; how its CSS follows imports.

## Assessment

- Evidence: A. Official docs; Vite underlies most non-Next frameworks.
- Reasoning: fair. States behaviour, little on trade-offs.
- Interests: none beyond the tool.
- Weigh: splitting unit is the async JS chunk, so pages split only where code does.

## Findings

- [web] CSS follows dynamic imports: each async chunk's CSS becomes a file, linked when the
  chunk loads; no developer declaration. ^f1
  > Vite automatically extracts the CSS used by modules in an async chunk and generates a separate file for it.
- [web] [web/wasm] FOUC guard: the async chunk does not run until its CSS has loaded. ^f2
  > the async chunk is guaranteed to only be evaluated after the CSS is loaded to avoid
- [web] Opt-out gives one file for the whole project. ^f3
  > If you'd rather have all the CSS extracted into a single file, you can disable CSS code splitting by setting
- [web] Shared code lands in Rollup common chunks; Vite preloads a common chunk in parallel
  with the async chunk that needs it, saving a round trip. ^f4
  > Rollup often generates "common" chunks - code that is shared between two or more other chunks.
  > Vite automatically rewrites code-split dynamic import calls with a preload step so that when `A` is requested, `C` is fetched **in parallel**

## Read

- Build Optimizations section

## Not read

- CSS pre-processor, CSS modules and Lightning CSS sections
