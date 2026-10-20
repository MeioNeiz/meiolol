---
title: OP.GG live game page with four streamer-mode players (2026-10-20)
url: https://op.gg/lol/summoners/euw/BUILT-2603/ingame
kind: docs
commit:
for: [streamer-mode-names]
looked: 2026-10-20
depth: docs (rendered live game tab, logged out)
relevance: high
grade: B/fair
description: OP.GG's Live game tab for a Challenger in EUW game 8019181098, where spectator-v5 hides four of ten players: OP.GG lists only the six visible players
---
# OP.GG live game page with four streamer-mode players (2026-10-20)

Why: does OP.GG's live game view hide streamer-mode players, and how.

## Assessment

- Evidence: B. One live game, rendered through real Chrome about 13 minutes in;
  cross-checked with Riot's spectator-v5 for the same game
  (our own Riot API call on 20 Oct, not snapshotted).
- Reasoning: fair. Observation, no OP.GG explanation on the page.
- Interests: vendor.
- Weigh: text snapshot; champion icons are images, so whether hidden seats appear as
  icon-only rows is not visible in text (the screenshot was covered by the consent
  dialog). A first server-rendered fetch said the player was not in a game.

## Findings

- [ux/features] [privacy] The Live game tab lists each player with Riot ID, level,
  rank, ranked win rate and champion stats, per team with a tier average. ^f1
  > Tier average: **Grandmaster 2,623**
- [privacy] Only six of ten players have rows (two blue, four red): the four players
  spectator-v5 returns with a champion name and null puuid have no row and no name;
  12 "Played" counts = 6 players with season and champion games. ^f2
  > OBLITERATINGXZ#EUW
- [privacy] Checked, not there: no "Streamer Mode", "Hidden" or "Anonymous" label
  anywhere on the page. ^f3
- [ux/features] The first fetch (server-rendered, before scripts ran) said the player
  was not in a game while spectator-v5 returned it (that snapshot was replaced by the
  rendered one). ^f4

## Read

- Live game tab, rendered text

## Not read

- OP.GG's own Spectate pages (op.gg/lol/spectate/live/pro-gamer)
