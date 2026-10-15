---
title: 'Vercel: Getting started with ISR (docs, 2026)'
url: https://vercel.com/docs/incremental-static-regeneration/quickstart.md
kind: docs
commit: 
for: [render-cache-invalidation]
looked: 2026-10-15
depth: docs (intro, on-demand revalidation, monitoring section)
relevance: medium
grade: A/fair
description: Vercel ISR quickstart: the build-time versus first-request trade-off, popular pages first, tag revalidation recommended over paths and timers
---
# Vercel: Getting started with ISR (docs, 2026)

Why: the trade-off behind "prerender popular pages", and Vercel's advice on tags versus
paths versus timers. Markdown variant of the page.

## Assessment

- Evidence: A. Vendor docs for the reference ISR platform.
- Reasoning: fair. States the trade-off plainly; no numbers.
- Interests: vendor.
- Weigh: same vendor as [[vercel-isr]]; count the two as one voice.

## Findings

- [render] The trade-off: prerendering makes the first visit a hit but lengthens the build; rendering on first request keeps builds fast but makes that first visit a miss. ^f1
  > **Pre-render at build time**: Generate pages during the build so the first visitor gets an instant cache hit. This increases build time but avoids slow first requests.
  > **Generate on first request**: Skip the build step and let the first visitor trigger generation at runtime. This keeps builds fast but means the first request for each page is slower (a cache miss).
- [render] The usual split is popular pages at build, the rest on demand. ^f2
  > A common pattern is to pre-render popular pages at build time and let the rest generate on demand.
- [render] Tags are the recommended on-demand tool: tag content and invalidate tags when the data under them changes, rather than whole paths. ^f3
  > Tag-based revalidation is the recommended approach for granular control. Instead of revalidating entire paths, you tag cached content and invalidate specific tags when the underlying data changes.
- [render] Timers are the fallback when nothing signals a change; with a signal, invalidate only what changed. ^f4
  > Use time-based revalidations when content needs to update but you don't have a webhook. Otherwise, use tag-based invalidation to only regenerate when you know the content has changed.
- [render] [ops] The revalidation endpoint is protected by a shared secret. ^f5
  > Create an API Route that checks for the secret, then triggers revalidation

## Read

- intro, on-demand revalidation (Next.js), monitoring section

## Not read

- per-framework setup (SvelteKit, Nuxt, Astro), Gatsby DSG
