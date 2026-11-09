---
title: 'League of Legends Patch 26.21 Notes (Riot, 2026-10-20)'
url: https://www.leagueoflegends.com/en-us/news/game-updates/league-of-legends-patch-26-21-notes/
kind: docs
commit: 
for: [lol-site-ui, league-tools-2025-2026]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900; Replay Download Limits section)
relevance: medium
grade: A/fair
description: Riot's official 26.21 notes, read for layout: portrait, designer quote, then per ability old ⇒ bold new lines; no buff or nerf label
---
# League of Legends Patch 26.21 Notes (Riot, 2026-10-20)

Why: the source text every site copies; its layout. Shot: data/team/2026-10-24-ui/refs/patch/riot-patch-champs.png.

## Assessment

- Evidence: A. Canonical.
- Reasoning: fair (a reason per champion).
- Interests: publisher.
- Weigh: layout only.

## Findings

- [ux/features] Per champion a designer quote giving the reason, then per ability the old value ⇒ new value, new bold. ^f1
  > Darius has moved a bit too far away from being a persistently durable
  > **Cooldown**: 9 / 8 / 7 / 6 / 5s ⇒ **9 / 8 / 7 / 6 / 4s**
- [ux/colour] Checked, not there: no buff or nerf label or colour; the reader works it out from the numbers (seen in screenshot riot-patch-champs.png). ^f2
- [ux/layout] 400 to 700 px per champion with a 128 px portrait (seen in screenshot riot-patch-champs.png). ^f3

- [tools/removed] [policy] From 26.21 (20 Oct 2026) replay downloads are capped at 10 an hour, replacing the 26.20 plan to make replays private ([[lol-patch-26-20#^f2]]); own, friends' and others' replays stay downloadable. ^f4
  > Starting during Patch 26.21, replay downloads will be limited to 10 per hour.
- [policy] Riot's stated reason is mass scraping by AI-built apps, its second 2026 cut blamed on AI after the memory block ([[riot-memory-access-removed#^f3]]). ^f5
  > This change is necessary to prevent large-scale abuse of downloaded replays by bad actors using vibecoded apps to scrape thousands upon thousands of replays.
- [learning] (inferred) Replay-based review tools still work for one player's own games; bulk replay crawling for training data does not. ^f6

## Read

- Champion section
- Replay Download Limits section (for league-tools-2025-2026)

## Not read

- Modes, items
