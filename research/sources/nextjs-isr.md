---
title: 'Next.js: How to implement Incremental Static Regeneration (docs, 2026)'
url: https://nextjs.org/docs/app/guides/incremental-static-regeneration
kind: docs
commit: 
for: [hybrid-rendering-seo]
looked: 2026-10-12
depth: docs (example walkthrough, caveats)
relevance: high
grade: A/fair
description: Next.js ISR: prerender a listed subset at build, render the rest on first request and cache, regenerate stale pages in the background
---
# Next.js: How to implement Incremental Static Regeneration (docs, 2026)

Why: the best-known framework form of "prerender some, render the rest on demand".

## Assessment

- Evidence: A. The framework that named the pattern; widely deployed.
- Reasoning: fair. Clear mechanism and caveats.
- Interests: vendor (Vercel), though the guide covers self-hosting.
- Weigh: the mechanism is framework-independent; we would build it ourselves in Zig.

## Findings

- [render] A build prerenders the listed pages; others that exist render on their first request and are then cached; unknown ones 404. ^f1
  > If `/blog/26` is requested, and it exists, the page will be generated on-demand.
- [render] After the revalidate time, a request still gets the stale page while a new one renders in the background. ^f2
  > After 60 seconds has passed, the next request will still return the cached (now stale) page
  > The cache is invalidated and a new version of the page begins generating in the background
- [render] Needs a running server: ISR does not work with a pure static export. ^f3
  > ISR is not supported when creating a [Static Export](https://nextjs.org/docs/app/guides/static-exports).
- [render] The cache is per instance by default; several instances need a shared cache. ^f4
  > When running multiple instances, the default file-system cache is per-instance.

## Read

- example walkthrough (time-based), caveats, deployment table

## Not read

- on-demand revalidation API details, self-hosting cache handler page
