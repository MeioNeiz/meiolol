---
title: 'DeepLoL: summoner profile and match list, element by element (Oct 2026)'
url: https://www.deeplol.gg/summoner/euw
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text of Summary; screenshots desktop and phone)
relevance: high
grade: B/fair
description: DeepLoL profile of a Challenger EUW player: rank bar between tier floor and rank one, 30-day LP line with peak, AI summary box, games grouped into sessions with a summary line each, rows with AI-Score and a Fate label
---
# DeepLoL: summoner profile and match list, element by element (Oct 2026)

Why: lol-site-ui, kind 2. [[deeplol-profile]] (22 Oct) lists the features; this note is
the layout. Screenshots in data/team/2026-10-24-ui/refs/profile/ (gitignored):
deeplol-profile-top.png, deeplol-rows-sessions.png, dpm-deeplol-phone.png (right half).

## Assessment

- Evidence: B. Smaller site in EUW; scores without a method.
- Reasoning: fair on layout, weak on the labels (Fate, AI Tier Prediction).
- Interests: ad funded: a 230 px video ad beside the header, a coaching ad in the sidebar.
- Weigh: copy the session grouping and the LP line; skip the AI labels.

## Findings

- [ux/charts] [ux/postgame] Rank card: LP as a position on a bar from the tier floor
  (C 2398 LP) to rank one (1st 4431 LP), then "Last 30d" with the LP change, the peak,
  and a 30-day LP line (about 280 x 160 px) with tier letters on the axis. ^f1
  > C | 2398 LP | 1st | 4431 LP | 4257 LP | Last 30d | 120 LP | PEAK: C-4417
- [ux/postgame] Summary box over the list: win rate ring, 20 games, W/L, KDA, average
  AI-Score; "AI Tier Prediction" (C > C) and "Fate" chips; three champions; role bars
  split by win and loss. ^f2
  > 20 Games | 8W 12L | 1.90 KDA | 5.7 / 6.8 / 7.3 | 49 | AI-Score | AI Tier Prediction
- [ux/postgame] [ux/layout] Games are grouped into play sessions, each opened by a one-line
  summary: when, games, W/L, win rate, average score, average rank of the lobbies, and
  time played. A session is the unit a player remembers ("last night"). ^f3
  > 1 day ago | 6 Games / 3W 3L / 50% / 49 / Grandmaster / 2h 41m
- [ux/postgame] [ux/density] Match row about 100 px: queue, time ago, Win/Lose with
  duration, a weather icon and a "Fate" word (Messy, Solid, Godlike); champion, spells,
  runes, K/D/A, KDA, items; the AI-Score in a coloured box with the place (10th, MVP);
  ten names with streamer and pro badges. An MVP game gets a gradient background. ^f4
  > Ranked Solo | 1 day ago | Win | 25:20 | Fate Messy | 9/2/8 | 8.50 KDA | AI-Score | 83 | MVP
- [ux/postgame] Played with has With and Against tabs (Summoner, Games, Win, Lose, WR). ^f5
  > Recently Played With (Recent 20 Games) | With | Against | Summoner Games Win Lose WR
- [ux/layout] Phone redirects to a separate light-theme site, m.deeplol.gg, with KR as the
  search default; rows keep the score box and items, drop the names, about 90 px each,
  and the first row is near 400 px down: the most list-first phone layout of the four. ^f6
  > Phone (390x844) redirects to m.deeplol.gg/summoner?userName=...&region=euw; its search box defaults to KR.
- [ux/trust] (inferred) "Fate" and "AI Tier Prediction" are labels with no visible method;
  Fate disagrees with the outcome (a 9/2/8 MVP win is "Messy"), which reads as noise. ^f7

## Read

- Summary tab, desktop and phone.

## Not read

- Champions, OTP Build, Live Game tabs.
