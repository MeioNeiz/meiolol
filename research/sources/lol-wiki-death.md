---
title: 'League of Legends Wiki: Death'
url: https://wiki.leagueoflegends.com/en-us/Death
kind: docs
commit:
for: [kill-vs-farm-value]
looked: 2026-10-20
depth: docs (death timer section)
relevance: medium
grade: B/fair
description: Community wiki page on champion death: death timer by level (BRW) and game time (TIF), Howling Abyss timers
---
# League of Legends Wiki: Death

Why: do death timers rise with level and game time (the video's reason for fewer kills
per minute late)?

## Assessment

- Evidence: B. Official community wiki; no patch history on the page, so the date of
  the current values is not shown. Riot's 26.1 notes change death timers only for
  Swiftplay ([[lol-patch-26-1#^f9]]); one web search found no Summoner's Rift change in
  2026.
- Reasoning: fair. Formula and a worked cap.
- Interests: none.
- Weigh: shape (rising with level and time) is safe; exact seconds worth checking
  against our own timeline data if we use them.

## Findings

- [learning] [data] Death timer by level (BRW): 10 s at levels 1 to 2, 16 at 6, 25 at
  8, 37.5 at 12, 52.5 at 18. ^f1
  > **BRW** = 10 / 10 / 12 / 12 / 14 / 16 / 20 / 25 / 28 / 32.5 / 35 / 37.5 / 40 / 42.5 / 45 / 47.5 / 50 / 52.5 seconds
- [learning] From 15 minutes a game-time factor adds up to 12.75% by 30 min, 21.75% by
  45, capped at 50% (max 78.75 s). ^f2
  > In Summoner's Rift, death timers increase both by champion **level** and by **game time**.
  > The TIFx has a hard cap of 50%, so the maximum possible death timer is at 55 minutes at champion level 18:
- [learning] (inferred) So the video's claim holds: a level 12 death at 25 min is about
  41 s against 10 s at level 2; longer timers mean fewer champions alive to die, though
  also a bigger reward per kill in map time (a 40 s death costs the victim more than
  one wave at 25 s waves). ^f3

## Read

- Death timer section

## Not read

- Death state effects, trivia
