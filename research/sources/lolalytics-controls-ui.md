---
title: 'LoLalytics: filter bar, lane picker, search and tooltips (Ahri build, tier list)'
url: https://lolalytics.com/lol/ahri/build/?lane=middle
kind: project
commit:
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (filter bar, rank and patch pickers open, search typeahead, a tooltip, phone)
relevance: high
grade: B/weak
description: LoLalytics' controls, Oct 2026: one sticky strip of icon buttons (lane with pick share, rank emblem, patch, queue, region) over every champion and tier list page; grid pop-overs; search with champion sub-links
---
# LoLalytics: filter bar, lane picker, search and tooltips (Ahri build, tier list)

Why: Jacob's reference site; how its controls look and work, for meio.lol's filter bar,
role picker, search and tooltips. Screenshots in data/team/2026-10-24-ui/refs/controls/
(lolalytics-*.png, gitignored).

## Assessment

- Evidence: B. Live pages through real Chrome, 24 Oct 2026, patch 16.21; a major stats site
  with years of use.
- Reasoning: weak. No design rationale; what it does, not why.
- Interests: vendor; ads take a third of the first screen.
- Weigh: the control strip is the part Jacob likes; the ads and the prose paragraph are not.

## Findings

- [ux/controls] Champion page filter strip is one row of ~37 px square icon buttons: champion
  portrait, five lane icons each with its pick share under it, rank emblem, Patch, queue,
  region; summary numbers right-aligned on the same row. ^f1
  > Average Emerald+ Win Rate: 51.52%
- [ux/controls] Lane picker shows where the champion is played: Ahri middle 94.9%, top
  3.1%, jungle 0.0%, bottom 0.8%, support 1.1%; each lane is a plain link (`?lane=top`), so
  the role lives in the URL. Screenshot 24 Oct. ^f2
- [ux/controls] Rank picker opens a 4 x 5 grid of rank emblems with labels (All ranks,
  1trick, Challenger, G.Master, G.Master+, Master, Master+, Diamond, D2+, Diamond+, Emerald,
  Emerald+ ... Unranked): one click to open, one to pick. Screenshot 24 Oct. ^f3
- [ux/controls] Patch picker opens a 4 x 3 grid of tiles: 7, 14, 30 days, then the last
  nine patches; current choice underlined in the strip. Screenshot 24 Oct. ^f4
- [ux/controls] Tier list puts minimums in the same strip as three small number boxes
  (Min Lane % 2, Min Games 100, Min Pick % 0), never behind a menu. Screenshot 24 Oct; the
  labels are in [[lolalytics-tierlist-pbi]]'s snapshot. ^f5
- [ux/controls] Tier list role picker: Main (each champion in its main lane) plus Top, Jng,
  Mid, Bot, Sup icons in the same strip; any column header sorts on click (Games put
  Kai'Sa, 124,677, first), the active one marked by a thin underline, no arrow, and the
  Rank column keeps the tier rank. Run 24 Oct. ^f6
- [ux/controls] Search typeahead: typing "miss" shows Miss Fortune with icon and three
  coloured sub-links (Leaderboard, Counters, Pro Builds), a "Vs" shortcut to Ahri vs Miss
  Fortune from the page you are on, then a summoner guess (miss#NA1). Screenshot 24 Oct. ^f7
- [ux/controls] Checked, not there: no nicknames; "mf" and "j4" find no champion, only a
  summoner guess (mf#NA1, j4#NA1). Screenshot 24 Oct. ^f8
- [ux/controls] Tooltips are a 12 px white "?" beside a label, hover only; WR Delta's opens
  a ~75-word box above it, covering the stat ("Champion win rate and win rate delta. The
  win rate delta is the difference between..."). Screenshot 24 Oct. ^f9
- [ux/controls] Build toggle is two full-width tabs, Highest Win Build and Most Common
  Build: one view at a time. ^f10
  > Highest Win Build
- [ux/controls] Phone (390): the same strip at the same size, cut off at the right (Ranked
  and region off screen, sideways scroll); nothing folds into a menu. Screenshot 24 Oct. ^f11
- [ux/controls] On phone a tap on the WR Delta "?" opened nothing (touch emulation): the
  explanations are hover only, so phone users never see them. Run 24 Oct. ^f12

## Read

- Ahri build page top, rank and patch pickers open, search with "mf", "j4", "miss", WR Delta tooltip, phone top
- Tier list filter strip

## Not read

- Queue and region pickers open; counters page controls
