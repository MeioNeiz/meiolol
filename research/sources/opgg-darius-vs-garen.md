---
title: 'OP.GG: Darius counters page with Garen selected (patch 16.21)'
url: https://op.gg/lol/champions/darius/counters/top?target_champion=garen
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text; 1920x1080 and 390x844 fold and full-page screenshots)
relevance: high
grade: B/fair
description: OP.GG's one-opponent view: the counters tab with ?target_champion=garen, a paired-bar panel of nine stats (lane kill rate, KDA, kill participation, damage, first tower, win rate, then three champion-wide rows), a one-line tip and an opponent list sidebar
---
# OP.GG: Darius counters page with Garen selected (patch 16.21)

Why: what OP.GG shows for one matchup and how the opponent is picked.

## Assessment

- Evidence: B. Largest LoL stats site ([[similarweb-opgg-competitors#^f1]]); live page.
- Reasoning: weak. Numbers shown, not explained.
- Interests: vendor (ads, membership, desktop app, coaching).
- Weigh: layout from screenshots opgg-darius-vs-garen-desk-*.png and -phone-*.png in the session
  scratchpad (shots/ugg-opgg/), 1920x1080 and 390x844 (desktop Chrome user agent at
  phone width).

## Findings

- [ux/features] The opponent is picked from a right-hand list on the Counters tab (radio button per row, a search box, columns Win rate and Games, sorted by games); the choice goes in the URL as ?target_champion=garen and every champion tab link carries it (seen in screenshot opgg-darius-vs-garen-desk-fold.png). ^f1
  > Search a champion
- [ux/features] The panel "Darius vs Garen" is nine paired rows, Darius left and Garen right: lane kill rate, KDA, kill participation, damage dealt to champions, first tower kill time, win rate, lane win rate, lane pick rate, ban rate. ^f2
  > 57.03%Lane kill rate42.97%
  > 1.97 : 1KDA1.52 : 1
  > 16'1"First tower kill16'44"
- [ux/trust] Failure: the last three rows are not about the matchup: Darius's lane win rate, lane pick rate and ban rate (50.86%, 6.91%, 12.52%) are his champion-wide header numbers, drawn with the same paired bars as the matchup stats. ^f3
  > 50.86%Lane win rate50.47%
  > 12.52%Ban rate4.35%
- [ux/trust] The panel's win rate (55.14%) and the sidebar row for the same pair (55.04%) differ on one page, with no explanation. ^f4
  > 55.14%Win rate44.86%
  > Garen **55.04%** 536
- [learning] A one-line matchup tip sits above the panel (source not stated) and user-written counter tips below it, empty for this pair. ^f5
  > Maintain your passive stacks and hit Garen at the edge of Decimate
  > vs Garen Counter tips (0)
- [ux/features] Checked, not there: no gold, XP or CS difference at any minute, no first blood, no games count on the panel itself (only in the sidebar), no build on this tab (the Build tab takes the same parameter, [[opgg-darius-build-vs-garen]]). ^f6
- [ux/density] First 1920x1080 screen: header with user tips, tab row, a 130 px ad, mode tabs, a 80 px app banner and the tip take the top 800 px; only the win rate split and the first row (lane kill rate) of the panel show, plus 6 sidebar rows. About 10 matchup numbers above the fold (seen in screenshot opgg-darius-vs-garen-desk-fold.png). ^f7
- [ux/density] Phone (390x844): first screen is the header, filters, user tips, the headline numbers and the tab row; no matchup data (seen in screenshot opgg-darius-vs-garen-phone-fold.png). ^f8

## Read

- Whole rendered text; screenshots

## Not read

- Other opponents' panels; hover states
