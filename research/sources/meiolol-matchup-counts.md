---
title: 'meiolol site: matchup page counts and game counts (measured 2026-10-12)'
url: https://meiolol.jomify.lol/matchup/
kind: dataset
commit: 
for: [hybrid-rendering-seo]
looked: 2026-10-12
depth: ran (find and grep over data/site on the box)
relevance: high
grade: B/fair
description: Our own count of matchup pages per site view and how many reach 30, 100 and 200 games
---
# meiolol site: matchup page counts and game counts (measured 2026-10-12)

Why: how many matchup pages have enough games to be worth indexing or prerendering?

## Assessment

- Evidence: B. Our own measurement of the live site build, one snapshot.
- Reasoning: fair. Counts from each page's first "N games." line; pages without it are
  not counted, so totals are below the file counts.
- Interests: none.
- Weigh: counts grow with the crawl; the shape (a few hundred thick, tens of thousands
  thin) is what matters.

## Findings

- [render] [seo] The site holds about 50,000 matchup pages across four views, 990 MB, about 80% of the site. ^f1
  > Size: matchup 239M, patch/matchup 137M, all/matchup 375M, all/patch/matchup 240M
- [seo] [stats] All regions, last 30 days: 165 of 12,925 matchup pages have 200+ games, 635 have 100+, 2,576 have 30+. ^f2
  > all/matchup        12925  165   635   2576
- [seo] [stats] EUW, last 30 days: 12 of 7,508 have 200+ games, 54 have 100+. ^f3
  > matchup            7508   12    54    707
- [seo] Every page is noindex while in preview. ^f4
  > (preview mode until the production key)
- [seo] (inferred) Each matchup exists at four URLs (EUW or all regions, by 30 days or patch), so for search they are near duplicates of one another. ^f5

## Read

- data/site on the box, all four matchup directories

## Not read

- per-role split of the thresholds
