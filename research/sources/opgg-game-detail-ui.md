---
title: 'OP.GG: game detail (expanded match row), Oct 2026'
url: https://op.gg/lol/summoners/euw/matches
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text of all five tabs and the Timeline modal, screenshots 1280 wide)
relevance: high
grade: A/fair
description: OP.GG's game detail, opened inside a match row on the profile: Overview scoreboard, OP Score line, Team analysis donuts and kill feed with map, Build, gold/XP/CS lines
---
# OP.GG: game detail (expanded match row), Oct 2026

Why: lol-site-ui, kind 1 (game detail). A Challenger EUW player's latest ranked loss,
opened from the profile. Screenshots in data/team/2026-10-24-ui/refs/game-detail/
(gitignored): opgg-overview.png, opgg-team-analysis.png, opgg-build.png,
opgg-timeline-modal.png. Raw is an excerpt of the rendered text, player names removed.

## Assessment

- Evidence: A. The largest LoL stats site; this layout is the template others copy.
- Reasoning: fair. Dense and complete, but no hierarchy: every tab is equal weight.
- Interests: ad funded (video ad and banner over the profile), OP Score and AI upsells.
- Weigh: the scoreboard is the reference shape; the analysis tabs are filler charts.

## Findings

- [ux/postgame] [ux/layout] No game page of its own: the detail expands inside the match
  row (chevron at the row's right edge, 1 click), about 850 px tall, five tabs, plus a
  Copy Link bar with a per-game permalink. ^f1
  > Overview OP Score Team analysis Build Etc.
- [ux/postgame] [ux/density] Overview scoreboard: two team tables of five rows (about 42 px
  each), columns champion with level, spells and runes, name with rank and LP, OP Score
  with place pill (MVP, ACE, 2nd to 10th), K/D/A with kill share, damage dealt and taken as
  two numbers each over a thin bar, wards (placed / killed), CS with per minute, seven
  item icons. The viewed player's row is tinted. ^f2
  > Defeat(Blue team) OP Score KDA Damage Wards CS Items
  > 12 [player] Challenger 4,292 2.8 10th 3/10/5(40%) 0.80:1 12,595 23,339 0 9 / 3 133 5.5/m
- [ux/postgame] [ux/density] Between the teams, a strip compares totals as two-coloured
  bars (Total kills 20 v 45, Total gold 47,113 v 58,949) with objective icon counts
  (grubs, herald, dragons, baron, towers, inhibitors) at either end. ^f3
  > 20 Total kills 45 47,113 Total gold 58,949
- [ux/charts] OP Score tab: one line of the player's score by minute (0 to 24 m) with a
  hover dot, ten champion chips coloured as the legend, and a one-word verdict with a
  sentence ("Struggle"). (screenshot 24 Oct of the OP Score tab shows the line and chips) ^f4
  > Struggle Faced challenges and struggled to perform as desired.
- [ux/charts] Team analysis: six donut-and-bar blocks (kills, gold, damage, wards, damage
  taken, CS), each with five bars per side and the team totals in the donut; 30 bars to
  say what the scoreboard already says. ^f5
  > Champion Kills 7 8 16 13 1 45 20
- [ux/postgame] [ux/charts] Timeline opens a modal: a map, a kill feed by minute ("2m X
  killed Y", team-coloured left edge), Kill and Tower check boxes, a gold-lead dot line
  and a scrubber under the map. Moments are listed, never placed on a win chance curve. ^f6
  > Timeline | Winning team (Red team) | Losing team (Blue team) | Kill | Tower | First Blood 1:55
- [ux/postgame] Build tab for the viewed player only: item purchases grouped by minute
  with arrows (15 groups, two rows), skill order as a Q/W/E letter strip with R
  highlighted and the max order as three icons, runes as the full faded tree with picks lit. ^f7
  > Item builds 0 min 3 min 4 min 5 min 7 min 10 min
- [ux/charts] Etc. tab: gold, XP and CS lines for one champion at a time, picked from ten
  coloured chips (the chips are a colour key). ^f8
  > Gold acquired by champion Exp over time CS per champion
- [ux/postgame] Checked, not there: no win chance or gold lead curve on the first tab, no
  "what decided this game" line, no lane opponent comparison (only the "Laning 18 : 82"
  split on the row, [[opgg-profile-ui#^f4]]). ^f9
- [policy] (inferred) OP Score ranks all ten players 1st to 10th with MVP and ACE: fine on
  a post-game page under our rules, but a public grade of named teammates. ^f10

## Read

- All five tabs and the Team analysis Timeline modal for one game.

## Not read

- Timeline map at a scrubbed minute (the map was empty at minute 0); Runes subtab detail.
