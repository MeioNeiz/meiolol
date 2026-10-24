---
title: 'Blitz: filter row, matchup dropdown, command palette search (Ahri mid)'
url: https://blitz.gg/lol/champions/Ahri/build/mid
kind: project
commit:
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (filter row, matchup dropdown open, Cmd+K search)
relevance: medium
grade: B/weak
description: Blitz's champion page controls, Oct 2026: role segmented icons, rank and region dropdowns, a matchup dropdown listing every champion alphabetically, patch as plain text, a Cmd+K search palette
---
# Blitz: filter row, matchup dropdown, command palette search (Ahri mid)

Why: an opponent picker and a command palette search on a LoL site, for meio.lol's
controls. Screenshots in data/team/2026-10-24-ui/refs/controls/ (blitz-*.png). Raw is the
page's rendered text (the fetch got only the consent banner).

## Assessment

- Evidence: B. Live page through real Chrome, 24 Oct 2026; a large LoL app and site.
- Reasoning: weak. No rationale.
- Interests: vendor (desktop app, premium).
- Weigh: shows how not to build an opponent picker.

## Findings

- [ux/controls] Filter row: five role icons segmented, Emerald+ and World caret dropdowns,
  a "Select Matchup" dropdown, then "Patch: 26.21" as plain text (not changeable). ^f1
  > Recommended Ahri Mid runes, items, skill order, and build stats for Emerald+ on Patch 26.21.
- [ux/controls] Select Matchup opens a list of every champion A to Z with a small icon (Ahri,
  Akali, Akshan, Anivia ...), about 8 visible at a time, no search box and no ordering by how
  often they are met: finding Zed means scrolling ~170 rows. Screenshot 24 Oct. ^f2
- [ux/controls] Build variants are a three-way segmented control (Best, Win Rate, Common)
  over a build list. ^f3
  > Emerald+ Builds
- [ux/controls] Header search is a Cmd+K command palette: a dimmed page, a big input, a row
  of game icons to scope it; with "mf" or "j4" it showed only "Profiles: 1 characters
  required" and no champion in headless Chrome. Screenshot 24 Oct. ^f4

## Read

- Ahri mid filter row, matchup dropdown, Cmd+K palette

## Not read

- Whether the palette lists champions in a normal browser (it did not headless)
