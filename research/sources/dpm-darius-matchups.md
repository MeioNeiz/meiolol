---
title: 'dpm.lol: Darius matchups tab (streamer VODs)'
url: https://dpm.lol/champions/Darius/matchups?lane=top
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text, fold and full screenshots at 1920x1080 and 390x844)
relevance: medium
grade: B/fair
description: dpm.lol's Matchups tab is not a stats table but a player of recent streamer games on the champion, filterable by opponent, with jump points into each VOD
---
# dpm.lol: Darius matchups tab (streamer VODs)

Why: the 20 Oct lead guessed a full matchup table; what the tab holds and how a matchup is
taught there.

## Assessment

- Evidence: B. Live, well-used site (pro and streamer data).
- Reasoning: weak. No explanation.
- Interests: vendor (premium, ads both sides).
- Shots: scratchpad shots/others/dpm-darius-matchups-{1920,390}-{fold,full}.png.

## Findings

- [ux/features] [learning] The Matchups tab is video, not numbers: an embedded Twitch player
  of a recent streamer game, and below it a list of games to pick from. ^f1
  > Master every matchup by learning from the best with our videos.
  > CLICK ON A GAME TO WATCH IT!
- [learning] [ux/features] The player has jump buttons to the moments that matter in a
  lane: first kill, first death, first drake, baron, 15 and 25 minutes. ^f2
  > Quick Access First Kill First Death First Drake Baron 15m 25m
- [ux/layout] Opponent filter (a VS slot with crossed swords and a "?" champion picker in
  the header), role icons, and a Playing Darius | Against Darius toggle, so the same list
  serves "how to play it" and "how to beat it". ^f3
  > Playing Darius Against Darius Filters Streamers
- [ux/density] Game rows (about 50 px each, 15 per page, 19 pages): time ago, patch, region
  chip, both champions with VS, streamer name, runes and items, KDA, and a 0-100 score in a
  ring coloured by value; no win or loss marker other than the ring (seen in screenshot
  dpm-darius-matchups-1920-full.png). ^f4
- [ux/layout] Failure as a first screen: at 1920x1080 the player fills it (about 600 px of
  black until clicked) between two ad columns; the first game row starts below the fold
  and an ad banner overlaps the list (seen in screenshot
  dpm-darius-matchups-1920-fold.png). ^f5
- [ux/features] Checked, not there: no matchup win rate, lane stats, gold or XP diffs, tips
  or difficulty on this tab; the numbers per opponent live on the Build page's matchup
  chips ([[dpm-darius#^f1]]). ^f6

## Read

- Rendered text; screenshots at both viewports

## Not read

- Build page with an opponent chosen (whether the build filters by matchup)
