---
title: 'meiolol: champion page filter prototype (Ahri, 2026-10-12)'
url: https://meiolol.jomify.lol/champion/ahri.html
kind: project
commit: 2530524
for: [hybrid-rendering-seo]
looked: 2026-10-12
depth: ran (live page, data file sizes, filters.zig header)
relevance: high
grade: B/fair
description: Our own prototype: one JSON of summable slices per champion, filtered in the browser, so any region, rank, period mix needs no server and no page per combination
---
# meiolol: champion page filter prototype (Ahri, 2026-10-12)

Why: can the browser replace the per-view page copies (EUW or all regions, 30 days or
patch) that multiply the site's files?

## Assessment

- Evidence: B. Our own code, live on one champion page.
- Reasoning: fair. The header states why it works (counts add up).
- Interests: none.
- Weigh: one champion; size for all 173 and for matchup curves not yet measured.

## Findings

- [render] [web/wasm] One JSON per champion holds games, wins and gold at 14 split by region, rank, patch, role and opponent; the browser sums the slices picked, so any filter mix needs no server and no page per combination. ^f1
  > The page's filter bar (static/filters.js) sums the slices picked. Counts add
  > up, so any mix of filters needs neither a server nor a page per combination
- [render] [ops] The data file is small: 35 KB gzipped for Ahri. ^f2
  > data/filters/ahri.json 34666 bytes gzipped
- [render] [stats] Only summable numbers filter: model estimates (lane-curve gold at 14) and rates with other denominators (pick, ban) do not. ^f3
  > gold at 14 falls back from the lane-curve estimate to a plain average; pick and ban rate tiles are dimmed

## Read

- live page, filters.zig header, data file sizes

## Not read

- data size for every champion; whether matchup curves fit a per-champion file
