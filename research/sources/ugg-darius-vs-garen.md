---
title: 'U.GG: Darius build vs Garen (patch 26.21)'
url: https://u.gg/lol/champions/darius/build?opp=garen
kind: docs
commit: 
for: [champion-matchup-gap]
looked: 2026-10-22
depth: docs (rendered text; 1920x1080 and 390x844 fold and full-page screenshots)
relevance: high
grade: B/fair
description: U.GG's one-opponent page is the build page with a vs filter (?opp=garen); header strip shrinks to matchup win rate and matches, runes and early items refilter, late item options and the counters strip do not, no lane stats
---
# U.GG: Darius build vs Garen (patch 26.21)

Why: what U.GG shows for one matchup, and how the opponent is picked.

## Assessment

- Evidence: B. Top-two LoL stats site; live page.
- Reasoning: weak. Layout only; no note on which sections the filter applies to.
- Interests: vendor (ads, Plus, desktop app).
- Weigh: layout from screenshots ugg-darius-vs-garen-desk-*.png and -phone-*.png in the
  session scratchpad (shots/ugg-opgg/), viewport 1920x1080 and 390x844 (desktop Chrome
  user agent at phone width).

## Findings

- [ux/features] No separate matchup page: the opponent is a "vs. Champion..." search box in the build page's filter bar, stored as ?opp=garen; the chip then reads "vs. Garen" with a clear button (seen in screenshot ugg-darius-vs-garen-desk-fold.png). ^f1
- [ux/layout] With an opponent set, the six-number headline strip (tier, win rate, rank, pick, ban, matches) becomes three cells: matchup win rate, matches, and the opponent's icon and name; the Plus Personal Stats teaser goes. ^f2
  > 53.87% Win Rate 659 Matches VS.Garen
- [ux/features] Runes, spells, skill priority, starting items and core items refilter to the matchup with their own samples: here Precision primary instead of Sorcery, runes on 218 games, core build on 65. ^f3
  > 54.13% WR (218 Matches)
  > 53.85% WR 65 Matches
- [ux/trust] Failure: fourth to sixth item options do not refilter: the top fourth item shows 3,087 matches when the whole matchup has 659, and the fifth item rows (943, 869, 819 matches) are the unfiltered page's numbers, with nothing saying so. ^f4
  > 58.92% WR 3,087 Matches
  > 59.92% WR 943 Matches
- [ux/features] The Toughest Matchups strip stays the champion-wide one (Kled 43.5% on 138, same as without the filter), so the page shows "counters" of Darius next to a single chosen opponent. ^f5
  > Toughest MatchupsThese champions counter Darius
- [ux/features] Checked, not there: no lane stats for the pair (no gold, XP or CS difference at 15, no lane kill or first blood rate), no tips, no link to the opponent's side; GD@15 for this pair exists only as a cell on the Matchups table ([[ugg-darius-matchups#^f7]]). ^f6
- [ux/density] First 1920x1080 screen: header, tabs, filters, the three-cell strip (about 75 px for 2 numbers), a 60 px app banner, runes and spells beside a 215 px app ad; about 6 matchup numbers above the fold. Full page 2442 px (seen in screenshots). ^f7

## Read

- Whole rendered text; desktop and phone screenshots

## Not read

- Hover tooltips on runes and items (per-rune rates may sit there)
