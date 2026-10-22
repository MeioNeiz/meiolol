---
title: 'League of Graphs: Darius vs Kled matchup overview (Wayback, patch 13.9)'
url: https://web.archive.org/web/20230517005057/https://www.leagueofgraphs.com/champions/builds/darius/vs-kled
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (Wayback text, 1920 wide full-page screenshot)
relevance: medium
grade: B/fair
description: League of Graphs champion overview with the VS filter set to one opponent; three ring gauges then the usual build cards, all filtered to the matchup
---
# League of Graphs: Darius vs Kled matchup overview (Wayback, patch 13.9)

Why: what a vs page holds on a second-tier site. Live site and the vs-garen URL sit behind a
Cloudflare challenge (403) and Wayback has no 2025-26 copy that is not an error page; the
newest real vs capture found is this May 2023 one, so layout may have changed since.

## Assessment

- Evidence: B. Long-running site (2013-), M.O.B.A. Network; but a 2023 capture.
- Reasoning: weak. No explanations on the page.
- Interests: vendor (pushes the Porofessor app).
- Weigh: structure is likely still current (the 2025 error capture shows the same vs-
  links for every tab); numbers are old.
- Shots: scratchpad shots/others/log-darius-vs-kled-1920-full.png (1920x1080 viewport).

## Findings

- [ux/layout] Matchup is a filter, not a page type: a VS picker beside the champion picker
  in the filter bar, and every tab (stats, runes, skills, items, spells, probuilds) gets a
  /vs-<champ> variant. ^f1
  > Darius VS All Roles Platinum+ All regions
- [ux/density] Matchup header is three ring gauges side by side: overall win rate, win rate
  vs the opponent, gold difference at 15; no lane win rate, no XP or CS diff (seen in
  screenshot log-darius-vs-kled-1920-full.png). ^f2
  > 48.9% Winrate 44.4% Winrate (Vs Kled) -218 Gold diff @15
- [ux/layout] Below the gauges the normal overview cards, each filtered to the matchup and
  each with Popularity and Winrate in small grey italic under the icons: skill order,
  starting, core, boots and end build, spells, runes, pro builds, best replays, best
  players (seen in screenshot log-darius-vs-kled-1920-full.png). ^f3
  > Popularity: 30.7% - Winrate: 43.9%
- [ux/uncertainty] Failure: sample is one line in the header (599 matches, last 2 days) and
  never beside the build numbers, so a core build on 7.1% of 599 games (about 43) shows a
  33.3% win rate with no count. ^f4
  > 599 matches ( Last 2 days )
  > Popularity: 7.1% Winrate: 33.3%
- [ux/features] Checked, not there: no tips, power spikes, lane-phase text or difficulty
  label; the "how the lane plays" part is only gold @15 and the filtered builds. Its
  graphs by game length ([[leagueofgraphs-darius-stats#^f1]]) sit on the Stats tab, which
  also takes /vs- (link seen; Wayback has no capture of stats/darius/vs-*). ^f5
- [ux/density] At 1920 the content column is about 940 px wide in a two-column card grid
  with a 400 px sidebar and wide empty margins; first screen shows the gauges and the
  skill order only, about 6 numbers (seen in screenshot log-darius-vs-kled-1920-full.png). ^f6

## Read

- Whole Wayback text; full-page screenshot at 1920 wide

## Not read

- Live page (Cloudflare 403 on 22 Oct 2026, wait 12 s did not clear it)
- /champions/stats/darius/vs-<champ> (graphs per matchup), no capture
