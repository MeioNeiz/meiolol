---
title: U.GG live game page for a player in game (2026-10-20)
url: https://u.gg/lol/profile/euw1/built-2603/live-game
kind: docs
commit:
for: [streamer-mode-names]
looked: 2026-10-20
depth: docs (rendered live game tab, logged out, 15 s wait and scroll)
relevance: low
grade: C/weak
description: U.GG's Live Game tab said the player was not in game while Riot's spectator-v5 returned his game, so how U.GG shows streamer-mode players could not be seen
---
# U.GG live game page for a player in game (2026-10-20)

Why: does U.GG's live game view hide streamer-mode players.

## Assessment

- Evidence: C. One try; spectator-v5 returned the game (gameLength 769 s) minutes later.
- Reasoning: weak. Observation only.
- Interests: vendor.
- Weigh: may need the Update button or a logged-in user; inconclusive on streamer mode.

## Findings

- [ux/features] U.GG reported the player not in game while Riot's spectator-v5 had him
  in EUW game 8019181098 (our own Riot API call on 20 Oct, not snapshotted). ^f1
  > 'BUILT #2603' is not currently in game.
- [privacy] Checked, not there: nothing on how U.GG shows streamer-mode players could
  be seen. ^f2

## Read

- Live Game tab text

## Not read

- u.gg/lol/lg-splash (Live Games splash)
