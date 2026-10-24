---
title: 'League of Graphs: player profile (Wayback, Jan 2026)'
url: https://web.archive.org/web/20260107221658/https://www.leagueofgraphs.com/summoner/euw/
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (archived Overview of a Master EUW player's profile: ratings, champions, recent games, personal patterns, roles, played-with)
relevance: medium
grade: B/fair
description: League of Graphs profile: personal ratings with ladder rank and top percent, played and win rate rings, champion table with per-champion ladder rank, compact recent games, personal patterns (surrender rate, win rate by game length), roles and played-with tables
---
# League of Graphs: player profile (Wayback, Jan 2026)

Why: match history and profile (kind 2); Porofessor's live cards reuse its player ranks ([[porofessor-faq#^f3]]).

## Assessment

- Evidence: B. Long-running site; archived page.
- Reasoning: weak.
- Interests: vendor; a "Scout your opponents" Porofessor banner.
- Weigh: live site behind a Cloudflare challenge on 24 Oct; Wayback capture of 7 Jan 2026. The URL is cut to the path. Shots: data/team/2026-10-24-ui/refs/profile/ (leagueofgraphs-header.png, leagueofgraphs-recent-games.png).

## Findings

- [ux/features] Header names the player's best per-champion ladder ranks under the name. ^f1
  > Level 424 - #33 Sion - #116 Ornn - #550 Volibear
- [ux/layout] Profile tabs and filters: Overview, Champions, Patterns, Records, Challenges; filters for champion, role, season and a Record button. ^f2
  > OVERVIEW CHAMPIONS PATTERNS RECORDS CHALLENGES
- [ux/uncertainty] Personal ratings give rank and LP plus the ladder position and a top percent, and an average enemies rating over the last 10 matches. ^f3
  > Average Enemies Rating (Last 10 matches)
- [ux/density] Champion table: champion with its ladder rank, played as a bar plus number, win rate as a bar plus number, K/D/A coloured green, red, orange, and a small trend icon per row. (seen in screenshot leagueofgraphs-header.png, 24 Oct) ^f4
- [ux/density] Recent games rows are about 100 px: champion with spells, result word coloured, queue, age, duration, LP change, K/D/A coloured, "163 CS - 37% Kills P.", items, ten players with truncated names. (seen in screenshot leagueofgraphs-recent-games.png) ^f5
  > 163 CS - 37% Kills P.
- [ux/features] Personal Patterns shows the player's surrender rate and win rate by game length as signed differences with small bars (+5.6% at 30 minutes, -3.4% at 20). ^f6
  > 30 min games winrate
- [fun] A "With" table lists players this player queued with: name, rank, played, win rate. ^f7
  > With 	Played	Winrate
- [ux/postgame] Checked, not there: no LP or rating chart over time on the Overview, no summary of the last N games. (seen in page text) ^f8

## Read

- Overview tab.

## Not read

- Champions, Patterns, Records, Challenges tabs; live site.
