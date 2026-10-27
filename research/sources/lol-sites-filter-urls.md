---
title: 'LoL stat sites: filter URLs and canonical tags (measured 2026-10-27)'
url: https://op.gg/lol/champions/darius/build/top?region=euw&tier=diamond_plus
kind: dataset
commit: 
for: [site-url-scheme]
looked: 2026-10-27
depth: ran (curl and browse html of one filtered build page per site; Wayback for League of Graphs)
relevance: high
grade: B/fair
description: Our check of how lolalytics, op.gg, blitz, u.gg, mobalytics and League of Graphs put rank, region and patch filters in URLs and where their canonicals point
---
# LoL stat sites: filter URLs and canonical tags

Why: how competitors shape filtered URLs (rank, region, patch, queue) and whether filtered
views are their own canonical pages.

## Assessment

- Evidence: B. First-hand fetch of each site's live HTML, one page each.
- Reasoning: fair. Observations only; one page per site.
- Interests: none.
- Weigh: shows today's shape; League of Graphs from a March 2026 Wayback copy (live
  site behind a bot wall). Unfiltered champion URLs of all sites are in other notes'
  URLs (op.gg /lol/champions/darius/build/top, mobalytics
  /lol/champions/darius/counters/top/vs-garen, lolalytics /lol/darius/vs/garen/build/).

## Findings

- [seo] op.gg keeps role in the path and filters in the query; the canonical drops the query. ^f1
  > Canonical URL: https://op.gg/lol/champions/darius/build/top
- [seo] u.gg and mobalytics put rank and region in the query and canonical to the unfiltered page. ^f2
  > Canonical URL: https://u.gg/lol/champions/darius/build
  > Canonical URL: https://mobalytics.gg/lol/champions/darius/build
- [seo] Blitz redirects lowercase champion names to capitalised ones and canonicals without the query. ^f3
  > curl -L landed on https://blitz.gg/lol/champions/Darius/build/top?rank=diamond
- [seo] lolalytics, the odd one out: query filters, and each filtered URL is its own canonical. ^f4
  > Canonical URL: https://lolalytics.com/lol/darius/build/?tier=diamond_plus&region=euw&patch=30
- [seo] League of Graphs puts every filter in the path: role, rank, region and queue each as a segment after the champion. ^f5
  > /champions/stats/darius/diamond /champions/stats/darius/emerald /champions/stats/darius/eune /champions/stats/darius/euw
- [seo] League of Graphs stat rankings live under /rankings/ then kind, champion, region. ^f6
  > /rankings/summoners/aatrox/euw
- [seo] (inferred) Four of six sites keep filtered views out of the index (query plus canonical to the base page); only lolalytics indexes each filter combination. ^f7

## Read

- the canonical tag and filter links of one filtered build page per site

## Not read

- whether each site's filtered pages are actually indexed (site: search)
