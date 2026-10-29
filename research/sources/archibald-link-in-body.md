---
title: 'Jake Archibald: The future of loading CSS'
url: https://jakearchibald.com/2016/link-in-body/
kind: article
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: medium
grade: A/strong
description: Jake Archibald (Chrome DevRel, Feb 2016) on Chrome adopting link-in-body semantics: per-component sheets placed before their content, loaded in parallel, applied in series; costs of the loadCSS two-phase pattern
---
# Jake Archibald: The future of loading CSS

Why: the original case for per-component sheets in the body, from the Chrome team.

## Assessment

- Evidence: A. Chrome DevRel at the time, describing a change Chrome made; one real measurement (wiki-offline, 0.6 s on 3G).
- Reasoning: strong: weighs head-split, loadCSS two-phase and link-in-body, names layout shift risks.
- Interests: none (announcing his employer's change).
- Weigh: browser behaviour is as of 2016-2018; check current Lighthouse flags in-body sheets (see [[devtools-renderblocking-insight#^f1]]).

## Findings

- [web] Under HTTP/2 many small CSS files cost little overhead and cache independently, unlike HTTP/1. The current state ^f1
  > This isn't the case with SPDY and HTTP/2, where many smaller resources can be delivered with little overhead, and independently cached.
- [web] Per-component sheets in the head still block on all of them: one slow sheet delays the whole page, and the head must know the page's content up front, which can block streaming. ^f2
  > A slow loading `/site-footer.css` will delay the rendering of _everything_.
- [seo] [web] Inline-critical plus async rest (loadCSS) gave wiki-offline a 0.6 s faster first render on 3G. ^f3
  > 0.6s faster first render on 3g.
- [web] Its costs: needs a JS library, and only two phases; with more async files they arrive out of order and content shifts. ^f4
  > If you scale this to two or more CSS files they're likely to load out-of-order, resulting in content shifting around as it loads
- [web] Link-in-body: each sheet blocks only content after it; sheets load in parallel and apply in series, no fold to decide, streaming friendly. A simpler, better way ^f5
  > The stylesheets load in parallel, but they apply in series.
- [web] Progressive render exposes layout shift where content sizes layout (tables, flexbox); grid for page layout avoids it. ^f6
  > You need to take care when using layout systems where content dictates layout (such as tables & flexbox) to avoid content-shifting during load.
- [seo] [web] (inferred) For meio.lol's short pages the base sheet blocks first paint anyway, so link-in-body would only help where a page sheet's content sits below the first screen; and Lighthouse still flags in-body sheets fetched at VeryHigh priority before first paint ([[devtools-renderblocking-insight#^f1]]). ^f7

## Read

- Whole article
