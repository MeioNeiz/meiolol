---
title: Porofessor.gg on the Overwolf app store
url: https://www.overwolf.com/app/trebonius-porofessor.gg
kind: docs
commit: 
for: [league-tools-landscape, desktop-app-layout]
looked: 2026-10-11
depth: docs (whole listing)
relevance: high
grade: B/fair
description: Porofessor's Overwolf listing (v2.16.30, Oct 2026): 17.7M downloads, free with ads plus subscription; pre-game scouting, in-game timers and gold diff, @10/@20 stats, post-match graphs
---
# Porofessor.gg on the Overwolf app store

Why: size and feature set of the leading in-game companion app, and what time-based
stats it already shows.

## Assessment

- Evidence: B. Store listing with platform-counted downloads (17.7M) and 322 ratings;
  updated Oct 9 2026.
- Reasoning: weak. Marketing feature list.
- Interests: vendor and platform both promote it.
- Weigh: download count is Overwolf's figure (cumulative, includes reinstalls).

## Findings

- [market] 17.7M downloads on Overwolf; free, contains ads, subscription available; by M.O.B.A Network. ^f1
  > Downloads 17.7M
  > Free Contains Ads Subscription available
- [tools] [draft] Before the match: meta overview with counter picks, ban suggestions and rune import; scouting of both teams' champion stats, rank, roles and recent games. ^f2
  > gives you a detailed overview of your champions current standing in the meta, including counter picks and ban suggestions, and recommended runes that you can import straight into the game.
  > Gain detailed insights into your team and the enemy team, uncovering their strengths and vulnerabilities.
- [tools] [data] During the match: jungle and objective timers, live team gold difference, and each player's gold, CS and wards at 10 and 20 minutes with graphs. ^f3
  > Team Gold Difference: Track the gold gap between teams in real time
  > Gold Tracking: Gold earned at @10 and @20 minutes, including easy-to-read graphs.
  > CS Insights: Minions killed at @10 and @20 minutes with visual trends.
- [draft] Lane matchup analysis is only win rate against the lane opponent. ^f4
  > Lane Matchup Analysis: Win rate against the lane opponent for informed gameplay.
- [learning] Post-match analytics with graphs of the player's, team's and opponents' performance. ^f5
  > Porofessor records and presents everything you need to know in intuitive graphs and detailed stats
- [market] (inferred) The @10/@20 per-player stats mean Porofessor already reads timelines (or live game data) at scale, but uses them for scouting the people in this game, not for teaching a matchup. ^f6
- [learning] [ux/features] Checked, not there: no matchup guide, no "how this lane usually goes minute by minute", no power-spike content. ^f7

- [ux/desktop] Champ select window: a separate dark window beside the client (logo, Discord,
  help, settings, minimise, close), wide, about 1.8:1 and roughly as tall as the client. Top half: five ally cards in a
  row, one column per player (name, champion win rate with KDA, rank, main role icon,
  12 hour and 30 day games and wins, tag pills), plus a sixth column at the right for the
  player's own champion runes with arrows and "Export runes to LoL". Bottom half: enemy
  picks as they lock, one card per champion (popularity, win rate, main roles, "Is
  countered by:" with five champion icons). Footer: three boxes (Did you know?, Average
  Team Damage / min as blue vs red bars, Team comp analysis tags). Ally names show, so the shot predates the 2022 solo/duo name hiding (seen in screenshot
  overwolf-porofessor-champselect.jpg). ^f8
- [ux/desktop] In game the same layout opens as an overlay over the game (Show / Hide Ctrl
  + X; tabs Overview and Live Charts): two rows of five player cards, ally row then
  enemy row, and a right column with the own champion's build (starting, core, boots,
  end items, level 1-2-3, skill order, See More) over a team comp analysis of the enemy
  team (Good dive, Good engage, Good CC) (seen in screenshot overwolf-porofessor-ingame.jpg). ^f9
- [ux/desktop] Hover explains: a tag hover shows a tooltip with the tag in its colour and
  the reason with the number in bold ("High Damage: This player deals high damage per
  minute (22.7% top damage per minute with Zed)"); hovering a rank emblem shows season
  and split history (seen in screenshot overwolf-porofessor-ingame-tooltips.jpg). ^f10
- [ux/desktop] Newer cards (2026) add past-season rank badges under the name, and
  mid-card one of the three rings is coloured by value (33.3% red, 50.9% orange)
  (seen in screenshot overwolf-porofessor-ingame-tooltips.jpg). ^f11
- [ux/desktop] Ally ult timers are portraits with seconds above and HP / mana bars;
  jungle timers are numbers on the minimap; the live stats overlay is six rows with
  deltas vs tier (seen in screenshot overwolf-porofessor-overlay.jpg). ^f12
- [ux/desktop] The main app (between games) has a top nav Profile, Champions, Meta,
  Matches, Rankings with back and forward arrows and a breadcrumb; the profile groups
  personal ratings, player tags and a performance radar vs the tier average (seen in
  screenshot overwolf-porofessor-profile.jpg). ^f13
- [ux/desktop] Tier list: icon and list toggle, role icon filter, dropdowns (All
  champions, VS, Platinum+, All regions, Ranked), rows with a coloured tier letter and
  rates as short coloured bars over the number (seen in screenshot
  overwolf-porofessor-tierlist.jpg). ^f14
- [needs] Recent reviews praise breadth and low PC load, not layout: 4 / 5 from 322
  ratings. ^f15
  > the app does everything you need and it does not consume your pc even a bit
- [ux/desktop] Ships two builds, an Overwolf client and an Electron standalone (99.7 MB), per the listing's App Info. ^f16

## Read

- Whole listing
- Gallery screenshots (23 Oct): raw/overwolf-porofessor-*.jpg

## Not read

- Overwolf listings for Blitz-alternatives (Mobalytics, U.GG, iTero) download counts
