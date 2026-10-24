---
title: 'DEEPLOL: filter row and region-in-search typeahead (Ahri mid)'
url: https://www.deeplol.gg/champions/ahri/build/middle
kind: project
commit:
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (filter row, search with "mf")
relevance: low
grade: B/weak
description: DEEPLOL's champion page controls, Oct 2026: role pill with share, ARAM pill, small select-style dropdowns for rank, region (KR by default) and patch; search with region chip and grouped results
---
# DEEPLOL: filter row and region-in-search typeahead (Ahri mid)

Why: another LoL site's filter row and search, for meio.lol's controls. Screenshots in
data/team/2026-10-24-ui/refs/controls/ (deeplol-*.png).

## Assessment

- Evidence: B. Live page through real Chrome, 24 Oct 2026; a Korean LoL site.
- Reasoning: weak. No rationale.
- Interests: vendor.
- Weigh: the grouped search is fine; the dropdowns look like plain selects.

## Findings

- [ux/controls] Filter row: current role as a pill with share (100%), an ARAM pill, then
  right-aligned select-style dropdowns with small triangles: Emerald+, KR, 16.21. Region
  defaults to KR even though the header search says EUW. Screenshot 24 Oct. ^f1
  > AhriMid Build, Emerald, Patch 16.21
- [ux/controls] Header search has a region chip (EUW) at its left; "mf" lists Miss Fortune
  and Malphite under "Tierlist&Build" (each with icon), then a matching summoner under
  "Summoner", each group in its own bordered box. Screenshot 24 Oct. ^f2
- [ux/controls] Build variants are tabs with games and win rate (AP 2,479 games 51.3%, AP
  980 games 54.4%). Screenshot 24 Oct. ^f3

## Read

- Ahri mid filter row, header search "mf"

## Not read

- Dropdowns open (layout shifted under ads), phone
