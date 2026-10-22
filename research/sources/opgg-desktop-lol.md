---
title: 'OP.GG Desktop: League of Legends features and overlays'
url: https://op.gg/desktop/en/games/lol
kind: docs
commit: 
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (whole page)
relevance: high
grade: B/fair
description: OP.GG Desktop's LoL page, Oct 2026: 3 features (patch recap and tiers, match history, champion analysis) and 13 overlays (AI Agent, jungle timers and path, inhibitor timers, real-time stats, gold and item comparison, loading screen, healing item tracker, ward count)
---
# OP.GG Desktop: League of Legends features and overlays

Why: OP.GG's own per-overlay list for LoL, deeper than [[opgg-desktop]] and the
Overwolf listing ([[overwolf-opgg]]).

## Assessment

- Evidence: B. Vendor's current desktop site (has its own patch notes, status and
  download pages, with a macOS download).
- Reasoning: fair. One line per overlay, some with limits stated (no Herald or Baron).
- Interests: vendor.
- Weigh: "Enhanced overlays" repeats five overlays without saying what is enhanced or
  whether it is paid; not checked in the app.

## Findings

- [tools/phase] Between games: patch recap of buffs and nerfs with lane tiers, own match
  history across modes, champion analysis by region, tier and patch. ^f1
  > See every champion buffed, nerfed or adjusted this patch, then check lane-by-lane tiers to find who's strong right now.
  > Compare win, pick and ban rates and matchups by region, tier and patch
- [tools/phase] Loading screen: recent match details of players and the AD/AP ratio of all
  champions. ^f2
  > Check recent match details, overall AD/AP ratio for all champions and more.
- [tools/phase] In game: jungle camp and Scuttle timers on the minimap, but not Herald or
  Baron; inhibitor timers for both teams; most common jungle path for your champion. ^f3
  > Track jungle monster and Scuttle Crab respawn timers on the minimap. (Herald/Baron excluded)
  > You can check the respawn time of allied and enemy inhibitors after they are destroyed.
- [tools/phase] In game: real-time stats against the lane and tier average; gold and item
  difference between teams; enemy healing items against your anti-heal; your team's
  control ward count. ^f4
  > You can compare your current skill level using key metrics based on the lane you selected and the average tier.
  > Check the enemy team's healing items and your team's healing reduction items.
- [tools/phase] In game: AI Agent voice control from the overlay, push-to-talk. ^f5
  > Talk with the AGENT using voice and easily control your mic and speaker from the overlay.
- [tools/phase] Checked, not there: no champ select pick or ban assistant on this page
  (it is on the Overwolf listing, [[overwolf-opgg#^f2]]); no post-game review for LoL; no
  login, friends or premium named. ^f6
- [tools] OP.GG Desktop ships a macOS build, unlike Porofessor
  ([[porofessor-standalone-reddit#^f9]]); the header's download link has platform=macos. ^f7
- [tools/removed] (inferred) Herald and Baron excluded from jungle timers and no enemy
  ultimate or summoner spell timer listed: OP.GG keeps to timers of what the minimap
  shows. ^f8

## Read

- Whole page

## Not read

- op.gg/desktop/en/patch-notes (dated feature history, could date removals)
