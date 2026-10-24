---
title: 'Dotabuff hero stats: labelled segmented filters and quick search hero grid'
url: https://www.dotabuff.com/heroes
kind: project
commit:
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (filter bar, quick search typed, phone)
relevance: high
grade: B/weak
description: Dotabuff's hero stats page, Oct 2026 redesign: every filter visible as a labelled segmented control (group by, date range, mode, rank tier as emblems, position as icons), wrapping on phone; a hero grid by attribute that lights matches as you type
---
# Dotabuff hero stats: labelled segmented filters and quick search hero grid

Why: a non-LoL stats site whose filter bar shows every choice at once, for meio.lol's
filter bar, role picker and champion grid. Screenshots in
data/team/2026-10-24-ui/refs/controls/ (dotabuff-*.png).

## Assessment

- Evidence: B. Live page through real Chrome, 24 Oct 2026; the biggest Dota stats site, years of use.
- Reasoning: weak. No rationale beyond the intro line.
- Interests: vendor; heavy ads.
- Weigh: the filter bar is the best seen for "all choices visible"; check it with League's
  larger rank list (10 tiers plus "and above").

## Findings

- [ux/controls] Filter bar is five labelled groups, small caps label above each: Group by
  (Heroes | Facets), Date range (Last 7 days, the only dropdown), Game mode (All Pick |
  Turbo), Rank tier (All plus 8 rank emblems as one segmented control), Position (All plus
  5 role icons). Every option is one click, nothing hidden. ^f1
  > Filter by position, rank, game mode, and date range to see the most popular heroes and how they perform.
  > Group by Date range Game Mode Rank tier Position
- [ux/controls] Phone (390): the same groups wrap to four lines at full size, still all
  visible, about 170 px tall; the table below keeps hero, tier, win, pick and ban rates
  with a thin bar under each number. Screenshot 24 Oct. ^f2
- [ux/controls] Quick Search: a box over a fixed grid of all hero portraits grouped by
  attribute (Strength, Agility, Intelligence ...); typing "wraith" lights Wraith King in
  colour and greys the rest, so the grid never reflows. Screenshot 24 Oct. ^f3
- [ux/controls] Checked, not there: no abbreviations; "wk" lights nothing. Screenshot 24 Oct. ^f4
- [ux/controls] Table views are text tabs over the table (Meta snapshot, Popular heroes,
  Winning heroes, Combat, Economy, Vision). Screenshot 24 Oct. ^f5

## Read

- Heroes page filter bar, quick search with "wk" and "wraith", phone first screen

## Not read

- Date range dropdown open; column header tooltips
