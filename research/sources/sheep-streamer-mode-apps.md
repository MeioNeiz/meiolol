---
title: "Riot API change hides streamer-mode players from U.GG, OP.GG and Porofessor (Sheep Esports on X, 2025-10-17)"
url: https://x.com/Sheep_Esports/status/1979286341809770888
kind: thread
commit:
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (post and follow-up)
relevance: medium
grade: B/weak
description: Esports news account reporting the Oct 2025 live-game API change that removed scouting in third-party apps, with an update that it hit all players
---
# Riot API change hides streamer-mode players from U.GG, OP.GG and Porofessor (Sheep Esports on X, 2025-10-17)

Why: what the Oct 2025 streamer mode change did to third-party scouting.

## Assessment

- Evidence: B. Established esports news account, 169.1k views; a short post, not Riot's
  words. Its update credits a third party for the clarification.
- Reasoning: weak. Reports, no detail.
- Interests: none known.
- Weigh: read with [[riotdevrel-tweet-spectator-anonymity]]: Riot switched Spectator-v5
  off on 17 Oct 2025 and brought the live-game endpoint back on 20 Oct 2025, so the
  "ALL players" outage lasted about three days; streamer-mode hiding stayed.

## Findings

- [tools/removed] [privacy] Loading screen and in game: from 17 Oct 2025 third-party apps
  (U.GG, OP.GG, Porofessor named) can no longer show the identity of players in your game
  who use streamer mode; post-game data unaffected. ^f1
  > Riot 👊 is making changes to its API that will remove the ability to see players' identities in your game using third party applications such as U.​GG, OP​.GG, and Porofessor if they're using streamer mode. Post-game data will remain unaffected and available.
- [tools/removed] Initially the deactivation hit every player: scouting, live pro game
  tracking and more broke across apps. ^f2
  > removes the ability of 3rd party apps to track ALL players, removing the apps' scouting functions, live pro player game tracking, and more.
- [needs] [privacy] One visible reply objects to anonymity. ^f3
  > Anonymity is never a good thing
- [tools/removed] (inferred) Timeline of live-scouting cuts: 12.22 (Nov 2022) names out of
  ranked solo/duo champ select ([[riot-champ-select-anon-apps-1222#^f1]]); 17 Oct 2025
  streamer-mode players hidden from loading screen and in-game scouting; post-game match
  history untouched throughout. ^f4

## Read

- post, Sheep's update, first reply

## Not read

- remaining replies (login wall)
