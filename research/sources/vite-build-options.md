---
title: 'Vite config: build options (cssCodeSplit, assetsInlineLimit)'
url: https://raw.githubusercontent.com/vitejs/vite/main/docs/config/build-options.md
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (build.assetsInlineLimit, build.cssCodeSplit, build.cssMinify)
relevance: low
grade: A/fair
description: Vite build options reference; cssCodeSplit on by default (off for libraries), assetsInlineLimit 4 KiB, the origin of Astro's 4 KB inline threshold
---
# Vite config: build options (cssCodeSplit, assetsInlineLimit)

Why: the exact defaults behind CSS splitting and inlining in Vite-based frameworks.

## Assessment

- Evidence: A. Official reference.
- Reasoning: weak. Defaults stated, not justified.
- Interests: none.
- Weigh: reference only.

## Findings

- [web] `cssCodeSplit` default true: CSS imported in async chunks stays a chunk, fetched with
  it; false means one CSS file. ^f1
  > When enabled, CSS imported in async JS chunks will be preserved as chunks and fetched together when the chunk is fetched.
  > If disabled, all CSS in the entire project will be extracted into a single CSS file.
- [web] Asset inlining threshold is 4 KiB by default, to save requests. ^f2
  > Imported or referenced assets that are smaller than this threshold will be inlined as base64 URLs to avoid extra http requests.

## Read

- cssCodeSplit, assetsInlineLimit, cssMinify

## Not read

- the rest of build options
