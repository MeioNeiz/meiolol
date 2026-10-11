---
title: CommunityDragon/awesome-league (list of apps using League APIs)
url: https://github.com/CommunityDragon/awesome-league
kind: project
commit: 4384ac39c4ebc56898cc8745a481828d183edf90
for: [league-tools-landscape]
looked: 2026-10-11
depth: docs (README, Applications, External Apps, Content Creation sections)
relevance: high
grade: B/fair
description: Community-curated list of ~60 apps built on the League client, game and Riot APIs: client utilities, external sites, content-creation tools
---
# CommunityDragon/awesome-league (list of apps using League APIs)

Why: a map of what hobby and small developers actually build on League's APIs, beyond the
big stats sites.

## Assessment

- Evidence: B. Created 2019-05, 665 stars, 54 forks, 30 contributors, CC0, last push 2026-07-30; maintained by the CommunityDragon group linked to the Riot third-party dev community.
- Reasoning: fair; one-line entries, no usage numbers.
- Interests: entries are self-submitted by their authors.
- Weigh: good for categories and existence; says nothing about traction or whether entries are alive or Riot-approved.

## Findings

- [tools] List scope: apps on client/game APIs, external apps on the Riot API, and Replay API content tools. `README.md` ^f1
  > * [Applications](#applications) - Apps that work directly with client/game APIs.
  > * [External Apps](#external-apps) - Apps that work externally using Riot API.
  > * [Content Creation](#content-creation) - Tools made for Content Creators, mostly made with Replay API.
- [tools] (inferred) Most "Applications" are client utilities (rune importers, status masking, loot, friend list, profile cosmetics), not data products; the client (LCU) is where hobby developers build. ^f2
- [fun] [data] A yearly recap of a player's stats "in a fun and entertaining way" exists (YearIn.LoL): a Spotify-Wrapped style data product. `README.md` ^f3
  > [YearIn.LoL](https://yearin.lol) - A yearly recap that presents your League of Legends stats in a fun and entertaining way.
- [fun] [tools] Social/group tools listed: a flex-squad team tracker, a lobby and voice-room community platform with ranked leaderboards, a profile leaderboard tracker. `README.md` ^f4
  > [LoL-Tracker](https://lol-tracker.com/) - Team performance tracker for League of Legends Flex squads and competitive teams.
  > [Weered](https://weered.ca) - Lobby and voice-room platform for League communities; pulls summoner profiles, ranked leaderboards, and free rotation via the Riot API.
- [learning] [tools] Learning-by-watching tools: launch pro players' live games or replays in the client, and stream VODs searchable by champion, lane or opponent. `README.md` ^f5
  > [Proview](https://proview.es/) - Launch any pro player's live game or replay directly in your League client to spectate and learn from them, plus pro stats, builds and tier lists.
  > [LeagueStreams.gg](https://leaguestreams.gg) - Browse through Live League of Legends Streams with in-Game Informations or watch thousands of VODs by Champion, Lane or even Opponent.
- [learning] [tools] Game recording with key-event timestamps (LeagueRecord) and a post-game improvement coach (Baron Buff) are listed. `README.md` ^f6
  > [LeagueRecord](https://github.com/FFFFFFFXXXXXXX/league_record) - A lightweight program that automatically records LoL games and saves the timestamps of the most important events in the game.
  > [Baron Buff](https://baronbuff.com) - Draft assistant and coaching tool with champion recommendations, gameplay tips, and post-game improvement insights.
- [fun] Riot API Challenge 2018 entries survive as listed apps: club missions and a personal trophy wall. `README.md` ^f7
  > [Trophy Hunter](https://github.com/TiFu/riot-api-challenge-2018) - Creates your personalized trophy wall based on completed challenges.
- [fun] Checked, not there: no quiz, guessing game, LoLdle-style daily game or draft puzzle in the list. ^f8
- [tools] Content creation is anchored by Riot's own open-source League Director (replay staging). `README.md` ^f9
  > [League Director](https://github.com/RiotGames/leaguedirector) - Official tool for making advanced League of Legends replays.

## Read

- `README.md` sections Documentation to Content Creation.

## Not read

- Developer Tools and DevOps Tools sections (libraries; out of scope).
