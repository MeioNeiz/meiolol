---
title: 'Riot Support: Anonymizing Your Riot ID (streamer mode, 2026-02-10)'
url: https://support.riotgames.com/en-us/riot/account/anonymizing-your-riot-id
kind: docs
commit:
for: [identity-and-privacy]
looked: 2026-10-11
depth: docs (whole article)
relevance: high
grade: A/fair
description: Riot's player-facing description of streamer mode: hides Riot ID from third-party apps during a match only; match history unaffected
---
# Riot Support: Anonymizing Your Riot ID

Why: what privacy control players have against lookup tools, and whether streamer mode
hides match history from apps like meiolol.

## Assessment

- Evidence: A. Riot player support article, dated 10 Feb 2026.
- Reasoning: fair.
- Interests: Riot.
- Weigh: player-facing simplification; complements the 2025 dev blog
  ([[riot-dev-streamer-mode-2025#^f1]]) which says third-party apps are covered.

## Findings

- [privacy] [policy] Streamer mode stops third-party apps retrieving the player's Riot ID. ^f1
  > Streamer Mode is a feature allowing you to protect your privacy both in-game and out, by not allowing third-party apps to retrieve your Riot ID.
- [privacy] Hiding lasts only for the match; match history and replays are not affected. ^f2
  > Hides your Riot ID from the other players in Champion Select Lobby, Loading Screen, and in-game, but only for the duration of the match. Match History and Replays are not affected.
- [privacy] (inferred) Riot gives players no opt-out from post-game match history lookup;
  the hiding is aimed at live scouting. A lookup-your-own-games feature reads post-game
  match-v5, which this does not hide; but the general policy still bars de-anonymising
  players hidden by the game ([[riot-policies-general#^f10]]), so meiolol must not
  surface a hidden player's identity from live data. ^f3

## Read

- whole article
