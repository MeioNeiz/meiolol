---
title: 'Dota2ProTracker: hero meta page (7.41f, Nov 2026)'
url: https://dota2protracker.com/meta
kind: project
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: skimmed (page text behind the consent wall, default URL parameters)
relevance: medium
grade: B/weak
description: Dota 2 high-MMR pub stats site's meta table as served on 14 Nov 2026: a short rolling period by default, a banner when a new patch's stats start, a 200-match floor on the table
---
# Dota2ProTracker: hero meta page (7.41f, Nov 2026)

Why: what does a widely used Dota 2 stat site show in a new patch's first days?

## Assessment

- Evidence: B for what the page does (a site pros and casters cite daily; we read the
  live page). No method page found; the period's unit is not labelled in the text.
- Reasoning: weak. Nothing explained on the page.
- Interests: ads and a Pro tier.
- Weigh: the observable defaults only.

## Findings

- [tools] [method/dynamics] The meta table opens on a short rolling period, not the
  patch: the bare /meta URL resolves to `period=8&meta_period=8` with `mmr=7000`. (The 8
  is read as days: inferred, unlabelled in the page text; the resolved URL is the
  snapshot's line 3.) ^f1
- [tools] [method/dynamics] A new patch (here a letter patch) gets a banner saying its
  stats have started; nothing says the old patch's games are mixed in or left out of the
  rolling period. ^f2
  > Patch 7.41f Released - Stats are now available for the new patch.
- [ux/uncertainty] The table filters by match count, shown as a range starting at 200
  for the default view (MATCHES 200 - 12,157): a sample floor, not a shrunk estimate. ^f3
- [method/dynamics] (inferred) A fixed 8-period window that straddles a patch is a blend
  of old and new games by volume: on day 1 about 7/8 old, with no weight on which is
  which. It is the crude version of "lean on older patches until new games arrive". ^f4
- [method/dynamics] Checked, not there: no interval, no stated prior or shrinkage, no
  note on how the first days of a patch are treated. ^f5

## Read

- The rendered page text (hero table header, filters, banner).

## Not read

- /meta/trends (8 weeks of weekly changes, per the search result), the changelog, the
  Pro pages.
