---
title: 'Mobalytics: Darius vs Garen matchup statistics (patch 26.20)'
url: https://mobalytics.gg/lol/champions/darius/counters/top/vs-garen
kind: docs
commit: 
for: [hybrid-rendering-seo, champion-matchup-gap]
looked: 2026-10-22
depth: docs (whole rendered page text 12 Oct; fold and full screenshots at 1920x1080 and 390x844 on 22 Oct, patch 26.21)
relevance: high
grade: B/fair
description: A Mobalytics per-matchup page, top search result for "darius vs garen": templated sentence with game count and win rate, matchup tables, tips behind the app
---
# Mobalytics: Darius vs Garen matchup statistics (patch 26.20)

Why: do the big sites have one page per lane matchup, and what is on it?

## Assessment

- Evidence: B. Major LoL site; its matchup pages fill the top results for two "X vs Y"
  searches (logged 2026-10-12).
- Reasoning: fair.
- Interests: vendor (pushes its desktop app).
- Weigh: shows the page type ranks; text snapshot only, so rendering method unknown.

## Findings

- [seo] [tools] Mobalytics has one page per champion, role and opponent, at /lol/champions/<champ>/counters/<role>/vs-<opponent>. ^f1
  > # Darius vs. Garen - Matchup Statistics - Patch 26.20
- [seo] The page opens with one templated sentence filled with the game count and win rate, the same on every matchup page. ^f2
  > Based on the analysis of 1 246 matches in Emerald + in Patch 16.20, Darius has a 49.8% win rate against Garen in the Top, which is 0.1% lower than expected win rate of Darius.
- [seo] Matchup-specific written tips are behind the app, not on the page. ^f3
  > Unlock matchup-specific advices

- [ux/layout] Matchup panel is two halves of one card: left the best and worst picks list
  for Darius, right the Darius vs Garen block (both portraits, both win rates, sample
  line, then the stat rows); at 1920x1080 the first four stat rows (level 2, KDA, GD@15,
  XPD@15) sit on the first screen, the rest below (seen in screenshot
  moba-darius-vs-garen-1920-fold.png, 22 Oct). ^f4
- [ux/density] Each lane stat row is mirrored: Darius's value left with a teal bar, the
  label centred, Garen's value right with a pink bar; the diff rows repeat one number
  with its sign flipped (555 and -555 for GD@15), so half of those cells carry nothing
  new (seen in screenshot moba-darius-vs-garen-1920-full.png, 22 Oct). ^f5
- [ux/features] Lane stats are all snapshots, none over time: level 2 rate, KDA, gold, XP
  and CS diff at 15, CS per minute, kill participation, DPM, solo lane kills, damage to
  structures (raw table cells). ^f6
  > matchup breakdown, including KDA, Gold Difference, XP difference, and more
- [ux/layout] At 390 wide the order flips: the Darius vs Garen stat block comes first,
  right under the header, and the picks list follows; the paid tips panel drops out of
  the phone layout (seen in screenshot moba-darius-vs-garen-390-full.png, 22 Oct). ^f7
- [ux/trust] Failure: the expected-win-rate sentence uses a sample of hundreds (729 games
  on 22 Oct) to state "4.0% higher than expected", with no interval; and the headline
  box (win rate 51.2%) and the list's Overall Average (48.8%) differ because the list
  shows opponents' win rates, unlabelled (seen in screenshot
  moba-darius-vs-garen-1920-full.png, 22 Oct; same flip in [[mobalytics-kaisa-vs-jinx#^f4]]). ^f8
- [tools/paid] The matchup tips slot is a full panel (about 200 px) under the stats with a
  GET PLUS button and both portraits: the free page shows where the advice would go
  (seen in screenshot moba-darius-vs-garen-1920-full.png, 22 Oct). ^f9

## Read

- the whole page as rendered text; screenshots 22 Oct (scratchpad shots/others/moba-darius-vs-garen-*)

## Not read

- raw HTML (Cloudflare blocks curl): whether it is server-rendered or static
