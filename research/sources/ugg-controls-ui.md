---
title: 'U.GG: filter row, rank dropdown, More toggle, nickname search (tier list, Ahri build)'
url: https://u.gg/lol/tier-list?allChampions=true
kind: project
commit:
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (tier list and Ahri build filter rows, rank dropdown and More open, search with "mf", phone)
relevance: high
grade: B/weak
description: U.GG's controls, Oct 2026: a row of dark pill buttons (Filters, role segmented icons, rank with emblem, queue, patch, region, Show All) with rarely used ones behind More; search knows nicknames and offers each mode
---
# U.GG: filter row, rank dropdown, More toggle, nickname search (tier list, Ahri build)

Why: how a polished big site builds its filter row, dropdowns and champion search, for
meio.lol's controls. Screenshots in data/team/2026-10-24-ui/refs/controls/ (ugg-*.png).

## Assessment

- Evidence: B. Live pages through real Chrome, 24 Oct 2026; a top-three LoL stats site.
- Reasoning: weak. No rationale given.
- Interests: vendor; Plus upsell and ads push the filter row below the first screen at 1280 x 900.
- Weigh: the controls are well made; the page around them is ad-heavy.

## Findings

- [ux/controls] Tier list filter row, one line of 40 px dark pills: Filters, a six-icon
  role segmented control (all roles plus five lanes, selected one lit), rank with emblem,
  queue, patch, region with globe, and a Show All checkbox. ^f1
  > Filters Emerald + Ranked Solo 26.21 World Show All
- [ux/controls] Show All is the minimum-sample switch as a single checkbox in the row; it
  sets `?allChampions=true` and lists about 40% more cells. Run 24 Oct. ^f2
- [ux/controls] Rank dropdown is a plain list under the pill, emblem plus label, right
  aligned, current choice highlighted: Platinum +, Emerald +, Diamond +, Diamond 2 +, Master +,
  All Ranks, then single tiers. Screenshot 24 Oct. ^f3
- [ux/controls] Champion page row: Filters, build variant (Rec. with two rune icons),
  roles, rank, a "vs. Champion..." search box, and More...; More unfolds a second row in
  place (World, Ranked Solo, 26.21, Less...), so rare filters cost one click and no popup.
  Screenshot 24 Oct. ^f4
- [ux/controls] Header search knows nicknames: "mf" gives Miss Fortune four times with mode
  tags (Ranked, ARAM, Arena, Counters), then summoner profiles with level and region tag.
  Screenshot 24 Oct. ^f5
- [ux/controls] Region lives inside the search box as a small orange tag (NA), not a
  separate control. Screenshot 24 Oct. ^f6
- [ux/controls] Phone (390): the champion row folds to a filter icon, the role segmented
  control and More..., on one line; rank and patch go behind them. Screenshot 24 Oct. ^f7
- [ux/density] Tier list columns: Role, Champion, Tier, Win Rate, Pick Rate, Ban Rate,
  Counter Picks, Matches. ^f8
  > Champion Tier Win Rate Pick Rate Ban Rate Counter Picks Matches

## Read

- Tier list filter row and Show All; Ahri build filter row, rank dropdown, More; search "mf"; phone top

## Not read

- The Filters drawer and the "vs. Champion" typeahead (ads moved the layout under the click)
