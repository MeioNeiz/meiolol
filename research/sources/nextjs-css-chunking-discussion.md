---
title: 'vercel/next.js discussion #70168: CSS from unrelated pages merged via a shared component'
url: https://github.com/vercel/next.js/discussions/70168?sort=old
kind: thread
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: listed (whole thread)
relevance: high
grade: A/strong
description: Users report other pages' CSS in their chunk after Next 14.2; webpack author sokra explains why merging, never duplicating, keeps cascade order on client navigation, and the 30 KB / 100 KB chunk thresholds
---
# vercel/next.js discussion #70168: CSS from unrelated pages merged via a shared component

Why: the maintainers' own reasons for merging CSS across routes rather than per-page sheets.

## Assessment

- Evidence: A. Answers from Tobias Koppers (sokra, webpack and Turbopack author) and a
  Next.js collaborator (samcx); reports from large sites and Josh Comeau's blog.
- Reasoning: strong. Walks through the client-navigation case where duplicated CSS breaks
  order; admits the chunk sizes are guesses.
- Interests: maintainers defend their default; users want smaller first loads.
- Weigh: the order problem is specific to client-side navigation that keeps old sheets
  loaded; a full page load per navigation avoids it.

## Findings

- [web] Report: since 14.2 (14.1.4 fine) a page's CSS chunk includes styles from unrelated
  pages that share a component. ^f1
  > CSS Styles from unrelated pages and components are merged if they're using the same shared component
- [web] Maintainer: the merging is expected behaviour; more requests also hurt; the plugin
  merges until a chunk is too large, then splits. ^f2
  > The other side of this to consider is that more requests will also punish site performance.
  > I believe essentially what we do is we merge until a chunk is too large, then we split it is as needed.
- [web] Why not per-page sheets with shared CSS copied in: duplicated CSS breaks order once
  client navigation leaves both sheets loaded. ^f3
  > Duplicating CSS is a red flag, because it breaks CSS order.
  > This means the CSS order is violated for other page and navigating back to that page might show incorrect styling.
- [web] Scoped class names (CSS Modules) do not remove the order problem: two modules styling
  one element, often via a passed `className`. ^f4
  > Even with CSS Modules order matters in same cases. E. g. when applying styles from two different CSS modules to the same element:
  > This often happens with components that allow to pass a `className` prop.
- [web] They chose correctness over first-load size; a runtime that loads only the missing
  bundles was tried for Turbopack dev and found hard. ^f5
  > We usually optimize with the focus on initial page load, but here we have to make trade-offs for correctness.
  > it turned out that is a little bit harder due to the many ways of CSS being loaded (RSC, SSR, dynamic import) and state need to be maintained between them.
- [web] Thresholds, on unminified CSS: chunks under 30 KB merge with an overlapping small
  chunk; over 100 KB split for independent caching. ^f6
  > If a chunk would be smaller than 30kb, we merge it with another small chunk (usually from a different page) that has some overlap.
  > If a chunk would be bigger than 100kb we split it into chunks that are smaller than 100kb. This allows both chunks to be cached independently
- [web] Why merge small chunks: request overhead beats a few extra bytes, compression works
  better on bigger files, and a second page finds it cached. ^f7
  > the request overhead is much bigger than the few extra bytes downloaded, compression is also more efficient on larger files
- [web] The maintainer admits the numbers are guesses; best first load would be no merging
  and no splitting. ^f8
  > So it's more number guessing. If you want to optimize for best initial page load you probably want to go with 0kb and ∞kb.
- [web] Cost seen by a user: most pages load 20-40 KB of unused CSS, homepage 38 KB with 4 KB
  used, about 500 ms later FCP on mobile per Lighthouse. ^f9
  > Most pages have 20-40kb of unused CSS being loaded. My homepage, for example, loads 38kb of CSS but only uses 4kb
  > According to Lighthouse, the FCP has been pushed back by ~500ms on mobile
- [web] Order bugs show up in production but not dev, after an unrelated import change. ^f10
  > So a seemingly unrelated change of importing a component somewhere or removing its import from somewhere would mess up CSS ordering and break things.
- [web] Outcome: an opt-out flag (`cssChunking: false`) and an experimental inline-CSS flag. ^f11
  > We recently shipped an experimental flag to disable the CSS Chunking Algorithm altogether
- [web] The other extreme also bites: one large app got about 90 CSS requests on first load. ^f12
  > on initial load, 90 css request goes which impacts our FCP and Critical rendering path shows a delay of 2.5 ses

## Read

- whole thread as captured (5 comments, 23 replies)

## Not read

- PR #63157 (the change), #73286 (opt-out), issue #65480 (order bug)
