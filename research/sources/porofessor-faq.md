---
title: Porofessor FAQ (Wayback, Aug 2026)
url: https://porofessor.gg/faq
kind: docs
commit: 
for: [league-tools-landscape]
looked: 2026-10-11
depth: docs (whole page, Wayback copy 2026-08-15; live site behind Cloudflare challenge)
relevance: medium
grade: B/fair
description: Porofessor's FAQ: data source (Riot API, last 30 days of normal and ranked), role inference, replay system, same creator as League of Graphs, part of the M.O.B.A. Network
---
# Porofessor FAQ (Wayback, Aug 2026)

Why: what one of the "big three" companion apps uses for data and who owns it.

## Assessment

- Evidence: B. One of the big three companion apps ([[itero-companion-apps#^f2]]); site
  live since 2017.
- Reasoning: fair. Short, candid answers.
- Interests: vendor.
- Weigh: Wayback copy (Aug 2026); trust as self-description.

## Findings

- [data] Stats use all normal and ranked 5v5 games from the last 30 days, via the Riot API. ^f1
  > All normal and ranked 5v5 games, from the last 30 days, are taken into account to compute the stats.
  > Where do you grab your data? Riot APIs !
- [data] Infers each player's role from global champion usage plus that player's history. ^f2
  > Using the data I have (global champion usage + each player history), I try to find what is the most probable role distribution.
- [tools] Same creator as League of Graphs; player-champion rank reuses League of Graphs' ranking (rank, KDA, win rate). ^f3
  > I'm the creator of League of Graphs :)
  > This rank uses the leagueofgraphs.com ranking mechanism, which is based on global rank (silver, gold...), kda, winrate...
- [tools] [learning] Has a replay system in the desktop app, which needs Vanguard exited to open the game client. ^f4
  > Currently Vanguard prevents other applications from opening the Game Client, which includes the Porofessor app. Exiting Vanguard allows our replay system to work as expected.
- [market] Part of the M.O.B.A. Network alongside MOBAFire, League of Graphs and Counterstats (plus many non-LoL sites): an ad-funded network. ^f5
  > [M.O.B.A. Network](https://wearemoba.com/)
- [market] (inferred) Ownership is concentrated: League of Graphs, Porofessor, MOBAFire and Counterstats share one network; U.GG and Icy Veins share Enthusiast Gaming ([[ugg-faq#^f7]]). ^f6

## Read

- Whole FAQ

## Not read

- porofessor.gg feature pages (live game scouting, "pre-made" detection, tags)
