---
title: 'Mobalytics: filter row, rank dropdown, search and build list (Ahri)'
url: https://mobalytics.gg/lol/champions/ahri/build
kind: project
commit:
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (filter row, rank dropdown open, search with "mf", build list)
relevance: medium
grade: B/weak
description: Mobalytics' champion page controls, Oct 2026: role segmented icons plus caret dropdowns and a reset button; build variants as a side list with win rate on every row
---
# Mobalytics: filter row, rank dropdown, search and build list (Ahri)

Why: controls on a big polished LoL site, for meio.lol's filter bar, search and the
"most played vs highest win rate" toggle Jacob dislikes. Screenshots in
data/team/2026-10-24-ui/refs/controls/ (mobalytics-*.png).

## Assessment

- Evidence: B. Live page through real Chrome, 24 Oct 2026; a top LoL site.
- Reasoning: weak. No rationale.
- Interests: vendor (app download, Plus).
- Weigh: the build list is worth taking; the search is not.

## Findings

- [ux/controls] Filter row: five role icons as one segmented control (roles the champion
  is rarely played in drawn dimmer), then caret dropdowns Emerald +, All Regions, Ranked
  Solo (greyed, not changeable here), 16.21, and a reset-to-default icon button. Screenshot 24 Oct. ^f1
  > Ahri Mid has a 51.4% win rate with 9.8% pick rate in Emerald +
- [ux/controls] Rank dropdown is a short list with emblem and label (Diamond +, Diamond 2 +,
  Platinum +, Master +, All Ranks ...), bordered in the accent colour. Screenshot 24 Oct. ^f2
- [ux/controls] Build variants are a side list, not a toggle: Most Popular 51.6%, Highest
  WR 54.6%, Alternative 50.9%, Off-Meta 56.0%, each row with its rune and item icons; the
  chosen row fills the detail panel. All four summaries visible at once. ^f3
  > Most Popular 51.6% Highest WR 54.6% Alternative 50.9% Off-Meta 56.0%
- [ux/controls] Checked, not there: no nicknames; "mf" in the header search lists only
  player profiles (names starting MF), no Miss Fortune. Screenshot 24 Oct. ^f4

## Read

- Ahri build page filter row, rank dropdown, header search "mf", build list

## Not read

- Phone, tier list controls
