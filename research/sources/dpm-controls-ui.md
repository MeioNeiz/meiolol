---
title: 'DPM.LOL: role picker with shares, rank grid, Ctrl+K search, phone (Ahri)'
url: https://dpm.lol/champions/Ahri/build
kind: project
commit:
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (filter row, rank picker open, Ctrl+K search with "mf", phone)
relevance: high
grade: B/weak
description: DPM.LOL's champion page controls, Oct 2026: lolalytics' lane-with-share picker in a cleaner style, queue segmented, rank as an emblem grid, Ctrl+K search that knows nicknames; on phone only the role picker stays
---
# DPM.LOL: role picker with shares, rank grid, Ctrl+K search, phone (Ahri)

Why: the cleanest modern take on lolalytics' controls, for meio.lol's filter bar, role
picker and search. Screenshots in data/team/2026-10-24-ui/refs/controls/ (dpm-*.png).

## Assessment

- Evidence: B. Live page through real Chrome, 24 Oct 2026; a newer LoL site with growing use.
- Reasoning: weak. No rationale.
- Interests: vendor (app, premium).
- Weigh: the visual style is closest to what meio.lol wants; data depth is thinner than lolalytics.

## Findings

- [ux/controls] Role picker: five 36 px lane icons in one group, each with the champion's
  share under it (3.2%, -, 94.7%, 1.0%, 1.1%), current lane lit; a dash where it is never
  played. Same idea as lolalytics, quieter styling. ^f1
  > 94.7% 1.0% 1.1%
- [ux/controls] Right side of the same row: Ranked / ARAM segmented control, then Emerald+,
  All Regions, 16.21 as compact caret pills, a reset icon and a "?" help button. ^f2
  > Improve your gameplay with the best build for League of Legends.
- [ux/controls] Rank picker opens a 3-column grid of emblem tiles (Challenger, Grandmaster,
  Master+, Master, Diamond+, Diamond, Emerald+, Emerald, Platinum+ ... Iron) with ALL
  full-width at the bottom; current tile highlighted. Screenshot 24 Oct. ^f3
- [ux/controls] Ctrl+K search (hint shown in the box): "mf" gives Miss Fortune with icon and
  the subtitle "Builds, Runes & Counters" under a Champions heading. Screenshot 24 Oct. ^f4
- [ux/controls] Build variants are tabs that carry their numbers: AP haste 12,944 games
  51%, AP burn 5,776 54%, AP burst 1,071 54%, so the choice is informed before clicking. Screenshot 24 Oct. ^f5
- [ux/controls] Phone (390): the role picker with shares stays, centred; rank, region,
  patch and queue disappear from the first screen. A tap on an ability icon opened its
  tooltip as a full-width panel at the bottom of the screen. Screenshot 24 Oct. ^f6

## Read

- Ahri build filter row, rank grid, search "mf", phone first screen

## Not read

- Where the phone hides rank and region; matchups page controls
