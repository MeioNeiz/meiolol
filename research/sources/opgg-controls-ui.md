---
title: 'OP.GG: champion filter row and counter picker (Ahri mid)'
url: https://op.gg/lol/champions/ahri/build/mid?region=euw
kind: project
commit:
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (filter row, vs counter picker open and typed, tier list search)
relevance: medium
grade: B/weak
description: OP.GG's champion page controls, Oct 2026: a row of caret dropdowns (role with share, rank, class, vs counter, region, patch); the counter picker is a search plus the eight most-faced opponents as icons
---
# OP.GG: champion filter row and counter picker (Ahri mid)

Why: how the biggest LoL site builds filters and an opponent picker, for meio.lol's
controls. Screenshots in data/team/2026-10-24-ui/refs/controls/ (opgg-*.png).

## Assessment

- Evidence: B. Live pages through real Chrome, 24 Oct 2026; the most visited LoL site.
- Reasoning: weak. No rationale given.
- Interests: vendor; a full-page takeover ad and video ads covered the controls until
  stripped by script, and 1752 consent partners.
- Weigh: the counter picker is the idea worth taking; the page around it is not.

## Findings

- [ux/controls] Filter row of six caret dropdowns, 40 px high: current role as a lit pill
  with its share (100%), rank with emblem (Emerald +), Class, vs. Counter, region (EUW),
  Patch 16.21. Every control looks like a select box. Screenshot 24 Oct. ^f1
  > Build for Middle, Patch 16.21
- [ux/controls] vs. Counter opens a panel: title "Counter pick", one line of help, a
  champion search box, then "Most often played against" as eight portrait icons, so the
  common opponents are one click and no typing. Screenshot 24 Oct. ^f2
- [ux/controls] Typing "le" in that box narrows the icon grid to LeBlanc and Kayle
  (substring match, name under each icon). Screenshot 24 Oct. ^f3
- [ux/controls] Mode switch below the build tabs is a text tab row: Ranked Solo/Duo, ARAM:
  Mayhem, Classic, Arena, Today's hot, Show more. ^f4
  > Ranked Solo/Duo
- [ux/controls] Role choice is in the URL path (`/build/mid`), region and patch in the query. ^f5
- [ux/controls] Tier list page has a full-width "Search a champion" box with Recent
  champions under it; headless Chrome got no table, so search results were not seen. ^f6
- [ux/controls] Tips list filters are two plain checkboxes worded as the result. ^f7
  > Show patch 16.21 only

## Read

- Ahri mid page filter row, counter picker, mode tabs; tier list header

## Not read

- Rank and patch dropdowns open (clicks did not land), tier list table and role tabs (did not render headless), phone
