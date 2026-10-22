---
title: 'U.GG: Darius build page (patch 26.20)'
url: https://u.gg/lol/champions/darius/build
kind: docs
commit: 
for: [dense-stat-layout, champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text plus fold and full-page screenshots at 1440 on 20 Oct; re-read at 1920x1080 and 390x844 on 22 Oct)
relevance: medium
grade: B/fair
description: U.GG's champion build page: summary stat strip, runes, toughest matchups as cards, skill path grid, item slots each with win rate and matches
---
# U.GG: Darius build page (patch 26.20)

Why: how a champion page groups many small numbers into cards.

## Assessment

- Evidence: B. Top-two LoL stats site; live page.
- Reasoning: weak. Layout only.
- Interests: vendor.
- Weigh: layout read off screenshots
  (data/team/2026-10-19-night/design-shots/ugg-darius-build*.png).

## Findings

- [ux/density] Every choice carries its win rate and its sample in one fixed pattern, number then matches in brackets. ^f1
  > 49.94% WR (39,010 Matches)
- [ux/layout] Toughest matchups are a row of eight cards (icon, name, red win rate, matches), the counters page compressed to one strip (seen in screenshot ugg-darius-build-full.png). ^f2
  > Toughest MatchupsThese champions counter Darius
- [ux/density] Skill path is an 18-column grid with one blue numbered square per level per row, readable at a glance because only filled cells have colour (seen in screenshot ugg-darius-build-full.png). ^f3
- [ux/features] A Plus upsell sits inside the matchup strip: blurred "Personal Counters" cards with placeholder numbers. ^f4
  > PLUSPersonal Counters
- [ux/uncertainty] Failure: late item slots show win rates from 968 to 1,410 matches beside 23,587, in the same weight and colour (seen in screenshot ugg-darius-build-full.png). ^f5
- [ux/layout] Section order (re-read 22 Oct at 1920x1080): header (portrait, tier badge, ability icons, patch chip), tabs, filter bar, headline strip (tier, win rate, rank, pick rate, ban rate, matches, then a Plus teaser), app banner, Recommended runes with summoner spells, Toughest Matchups, Skill Priority beside Skill Path, five item columns, Role Quest and Role Rewards (seen in screenshot ugg-darius-build-desk-full.png). ^f6
  > Tier S+ Win Rate 51.25% Rank 14 / 62 Pick Rate 6.9% Ban Rate 10.9% Matches 17,070
- [ux/density] First 1920x1080 screen: only header, strip and runes with spells; about 10 real numbers (6 in the strip, win rate and matches for runes and spells); Toughest Matchups starts at about y 1,015. A 60 px app banner and a 260 px app ad sit inside the column above the fold; the column is about 1,014 px of 1,920 (53%). Full page 2,408 px (seen in screenshot ugg-darius-build-desk-fold.png). ^f7
- [ux/density] Phone (390x844): the first screen is an ad, the header, tabs, filter icons, the strip as two rows of three and the Plus teaser; no build content (seen in screenshot ugg-darius-build-phone-fold.png). ^f8
- [ux/features] Item columns carry a one-line hint each: starting items "Best for most matchups", core "Build this every game", later slots "Options after core build"; skill priority is drawn as three ability icons with arrows and its own win rate. ^f9
  > Build this every game
  > Options after core build
- [ux/features] A Role Quest card lists the points per action (kills, minions, plates, towers, epic monsters) and Role Rewards gives the reward text and a quest completion time goal. ^f10
  > Extra power for the late game in top lane
  > Darius top quest completion goal: 12:19
- [ux/trust] The tier letter moved from B on patch 26.20 (20 Oct) to S+ on 26.21 while showing 17,070 matches; no note on how young the patch sample is. ^f11
  > Ban Rate 10.9% Matches 17,070

## Read

- Whole page text; screenshots

## Not read

- ARAM and Pro Builds tabs
