---
title: 'OP.GG: summoner profile and match list, Oct 2026'
url: https://op.gg/lol/summoners/euw
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text of Summary, Champions and Highlights tabs; screenshots desktop and phone)
relevance: high
grade: A/fair
description: OP.GG profile of a Challenger EUW player: sidebar of rank, play style, champions, performance vs season and played-with; match rows with laning split, tags and ten names; Champions tab with per-opponent rows
---
# OP.GG: summoner profile and match list, Oct 2026

Why: lol-site-ui, kind 2 (match history and profile). Screenshots in
data/team/2026-10-24-ui/refs/profile/ (gitignored): opgg-profile-summary.png,
opgg-profile-sidebar-rows.png, opgg-champions-matchups.png, opgg-phone.png. Raw is an
excerpt of the rendered text, player names removed.

## Assessment

- Evidence: A. The largest LoL stats site, the profile everyone knows.
- Reasoning: fair. Every stat a player could want, laid out with no priority.
- Interests: ad funded (a 130 px ad slot above the list, a video ad in the header, an
  in-list banner), AI prompts and OP Score upsells.
- Weigh: copy the row and the vs-season block; the sidebar is a column of everything.

## Findings

- [ux/layout] Desktop: a 330 px left sidebar (rank, past seasons, play style, activity
  hours, champions, performance, 7-day win rate, played with) beside a 740 px match
  column. The first screen holds the header, tabs, an ad slot and the summary box; the
  first match row starts about 570 px down (screenshot 24 Oct). ^f1
  > Summary | Style | Champions | Highlights | Mastery | Live game | Teamfight Tactics
- [ux/postgame] Summary box over the list: a win rate donut (20G 8W 12L), average K/D/A
  and KDA with kill share, the top three champions with record and KDA, and five role
  bars; then four AI question chips and a patch notes card push the rows down. ^f2
  > 20G 8W 12L | 40% | 5.7 / 6.8 / 7.3 | 1.9 : 1 | P/Kill 51%
  > Analyze my recent matches. | What is my skill level? | How is my team luck lately?
- [ux/postgame] [ux/density] Match row, about 110 px, tinted red or blue with a coloured
  left edge: queue, time ago, result and LP change, duration; champion with level, two
  spells, two runes; K/D/A over KDA; laning split, kill share, CS, average rank of the
  game; seven items; place pill (10th, MVP) and one tag (Struggle, Unstoppable); ten
  names with icons in two columns; expand chevron. About 30 values per row. ^f3
  > Ranked Solo/Duo 17 hours ago Defeat 35 24m 22s 12 3 / 10 / 5 0.80:1 KDA Laning 18 : 82 P/Kill 40% CS 133 (5.5) Challenger 2,501 10th Struggle
- [ux/postgame] (inferred) "Laning 18 : 82" is a lane-phase share against the lane
  opponent, red when lost; the only lane comparison on the row, with no tooltip text. ^f4
  > Ranked Solo/Duo 2 days ago Victory 25 25m 20s 17 9 / 2 / 8 8.50:1 KDA Laning 61 : 39
- [ux/postgame] [ux/density] Performance block compares the last 20 games with the
  season: four cards (win rate, KDA, kill participation, game length), each with the
  value, a signed change chip (-14%) and a bar with a tick at the season value. The
  clearest "how am I doing lately" element on the page. ^f5
  > Recent 20 games vs season 1,904 games | Win rate | 40% | -14% | Season 54%
- [ux/postgame] Played with: rows of name, level, W/L and games, win rate; also a 7-day
  win rate per champion as a blue/red W-L bar. ^f6
  > Recently played with (recent games) | [player] | Level 220 | 2W / 2L | 4 Games | 50%
- [ux/postgame] [ux/density] Champions tab: one sortable table row per champion (played as
  a W/L bar, KDA, OP Score, laning split, damage per minute, wards, CS, gold, multi-kills);
  a row expands into one sub-row per lane opponent with the same columns. Champion stats
  and matchup history in one table. ^f7
  > # Champion Played KDA OP Score Laning DMG Wards CS Gold Double kill Triple kill Quadra kill Penta kill
  > vs Jayce 35W 24L 59% 2.68:1
- [policy] Champions tab opens on "Recommended champions" cards with a rank label
  ("Strong pick #7"), the wording our product rules avoid. ^f8
  > Recommended champions | BETA | Based on this summoner's most-played champions, results, and key stats.
  > Style fit | Matchup cover | Strong pick #7
- [ux/features] Highlights tab: video clips filtered by event type (solo kill, multi kill,
  object steal); empty for this player, so it needs their desktop app recording. ^f9
  > Event type | Solo kill | Normal kill | Multi kill | Object steal | No search results.
- [ux/layout] Phone (390 px): one column in sidebar order, so the first match row is past
  3,200 px of rank, play style, champions and played-with (screenshot opgg-phone.png). ^f10
- [ux/charts] Checked, not there on Summary: no LP or rank chart (a separate "Tier graph"
  button in the header). ^f11

## Read

- Summary, Champions, Highlights; phone Summary.

## Not read

- Style and Mastery tabs; the Tier graph popup.
