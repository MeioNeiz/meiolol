---
title: 'htmx essay: When Should You Use Hypermedia?'
url: https://htmx.org/essays/when-to-use-hypermedia/
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (whole essay)
relevance: high
grade: B/strong
description: Carson Gross (htmx author, 2022) on which apps and features suit server-rendered HTML swaps and which need client-side state
---
# htmx essay: When Should You Use Hypermedia?

Why: whether meiolol's interactive features can be server-rendered Zig fragments swapped
in by one generic script, instead of per-page JS

## Assessment

- Evidence: B. The htmx author; htmx is widely used (tens of thousands of GitHub stars,
  not counted here). Cites one port (Contexte) for its numbers.
- Reasoning: strong. Lists where its own approach fails (spreadsheets, maps, offline,
  frequent updates) with reasons.
- Interests: author of htmx; argues for hypermedia.
- Weigh: the fit/no-fit lists are reasoned and match our page types; the 67% codebase
  cut is one team's port, not a general result.

## Findings

- [web] Hypermedia fits UIs that are mostly text and images, CRUD, nested with updates inside well-defined blocks, and need deep links and good first render. ^f1
  > If your UI is mostly text & images
  > If you need “deep links” & good first-render performance
- [web] (claim) A React to htmx port at Contexte cut the codebase 67%; the author says that app was unusually suited to the style. ^f2
  > replacing React with htmx lead to a 67% reduction in the total codebase
- [web] Updating disjoint parts of the screen is hypermedia's weak spot; the fix is to co-locate dependent elements in one region with its own endpoint. ^f3
  > how do you update disjoint parts of the UI cleanly?
  > colocate dependent elements for a given resource within a given region or area on the screen
- [web] Not a fit: many dynamic interdependencies, offline functionality, very frequent state updates; those parts go client side. ^f4
  > If your UI has many, dynamic interdependencies
  > If you require offline functionality
  > If your UI state is updated extremely frequently
- [web] Mixing is the recommended shape: client-side islands inside a hypermedia app, easier than the reverse. ^f5
  > it is typically easier to embed SPA components _within_ a larger hypermedia architecture, than vice-versa

## Read

- whole essay

## Not read

- The Contexte port talk (the 67% source)
