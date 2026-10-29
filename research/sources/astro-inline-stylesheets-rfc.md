---
title: 'Astro RFC 0036: Inline stylesheets (build.inlineStylesheets)'
url: https://raw.githubusercontent.com/withastro/roadmap/main/proposals/0036-inline-stylesheets.md
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (whole RFC)
relevance: high
grade: A/strong
description: Astro's 2023 RFC for never/auto/always stylesheet inlining; motivated by per-page chunking splitting CSS into many tiny sheets (20 on the docs homepage, 14 under 1 KB); 4 KB default cut-off; order kept across style and link tags
---
# Astro RFC 0036: Inline stylesheets (build.inlineStylesheets)

Why: the reasoning behind Astro inlining small sheets, from its design record.

## Assessment

- Evidence: A. Accepted RFC of a major static-first framework, shipped 2.4 (experimental),
  2.6 stable; 'auto' became the default in 3.0 (per release notes seen in search, not read).
- Reasoning: strong. Motivation with a measured case, goals and non-goals, drawbacks,
  rejected alternatives.
- Interests: none.
- Weigh: written when "never" was default; Astro later flipped to "auto".

## Findings

- [web] Problem with per-page splitting: shared chunks get tiny; Astro docs homepage had
  20 stylesheets, 14 under 1 KB. ^f1
  > large websites are overoptimized for cacheability, since our chunking splits the styles too granularly. Case in point, Astro docs homepage has 20 linked stylesheets, 14 of them are less than 1kb
- [web] [render] The other end: a one-page site gains nothing from an external sheet, as no
  other page reuses the cache. ^f2
  > Simple one-page websites do not benefit from an external stylesheet, since there is no other page that could use the cached stylesheet.
- [web] Three modes; 'auto' inlines sheets under Vite's `assetsInlineLimit`, 4 KB by default;
  decided at build time. ^f3
  > stylesheets smaller than `ViteConfig.build.assetsInlineLimit` (or 4kb if not defined by the user) are inlined
  > The decision to inline a stylesheet should be made at build time (`astro build`)
- [web] Non-goals: critical-rule extraction, a single external stylesheet. ^f4
  > Identify "critical" CSS rules.
  > Enable a single external stylesheet.
- [web] Order: Astro already fixes link order to avoid ordering bugs; inline and linked
  sheets must share one ordered list. ^f5
  > Astro has run into CSS ordering issues and currently ensures that the `<link>` tags are in a specific order.
  > an implementation must pass both inline and external stylesheets in the same array or set that preserves the order
- [web] Inlined sheet content is added to every page that uses it (duplicated per page, not
  cached). ^f6
  > its contents should be added to `PageBuildData` of each page that it is used in.
- [web] Drawback: many tiny chunks each under the limit means more inlined than expected. ^f7
  > it tends to create a lot of tiny stylesheets, and each of them might be under the limit, leading to more CSS being inlined than the user might expect.
- [web] Rejected: critical-CSS tooling (crawls on large sites) and a per-style `critical`
  attribute (developer overhead, unproven gain). ^f8
  > it's viable only for static builds of small sites, as it slows to a crawl trying to match every CSS rule against every DOM element on every page.
  > implementation cost, mental overhead for developers, lack of evidence that the granularity will be worth it.

## Read

- whole RFC

## Not read

- implementation PR withastro/astro#6659; PR #8118 that made 'auto' the default
