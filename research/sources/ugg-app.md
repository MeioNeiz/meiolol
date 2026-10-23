---
title: U.GG desktop app page
url: https://u.gg/app
kind: project
commit: 
for: [riot-production-key, desktop-app-layout]
looked: 2026-10-11
depth: docs (whole page)
relevance: medium
grade: B/weak
description: U.GG (Outplayed Inc.) desktop app page: champ select scouting with best picks, counters and synergies; "Riot Games Compliant" badge
---
# U.GG desktop app page

Why: a top-tier stats site's desktop app; what it offers in champ select and how it labels its Riot status.

## Assessment

- Evidence: B. Major site, (c) 2017-2026 Outplayed Inc.; live Oct 2026.
- Reasoning: weak. Marketing.
- Interests: vendor.
- Weigh: trust the feature list; compliance badge is self-declared.

## Findings

- [policy] Shows a "Riot Games Compliant" badge, alongside the "isn't endorsed" boilerplate. ^f1
  > Riot Games Compliant
  > U.GG Stats isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games
- [tools] [ux/features] Champion select scouting recommends best picks, counters and team synergies. ^f2
  > Champion Select Scouting
  > Scout everything, from the best picks & counters to team synergies
- [ux/features] Auto-imports builds tailored by elo, role and matchup. ^f3
  > Auto-import the best builds, tailored by elo, role, and matchup
- [policy] Checked, not there: no mention of production key, Riot approval, AI/ML, or removed features. ^f4

- [ux/desktop] Champ select scouting: one wide row per player, ally rows on a blue band
  and enemy rows on a red band; a row holds role icon, champion portrait, spells, name
  and state (Locked In), champion win rate in the role (55.2% Bottom), and a matchup
  rate (54.5% vs. icon) or, on enemy rows, "Caitlyn Counters" as three icons with
  their win rates in red (seen in screenshot ugg-app-champselect.png). ^f5
- [ux/desktop] Live game card: champion portrait with role, spells and a "Runes >" button,
  then rank (Diamond 3 68 LP, 54% 264 games, last season badge), then champion record
  (70% 50 games, 4.23:1 KDA); rates coloured orange high and blue middling (seen in
  screenshot ugg-app-livegame.png). ^f6
- [ux/desktop] Rune import: "Recommended" dropdown, an Import Build button, Auto-Import
  toggle, include checkboxes Runes, Summoner Spells, Items (seen in screenshot
  ugg-app-import.png). ^f7
- [ux/desktop] Post game: a gold difference line by minute, blue above zero and red
  below, with a hover readout "52 Gold at 9m" (seen in screenshot ugg-app-postgame.png). ^f8
- [ux/desktop] The page names the phases it covers. ^f9
  > Scout everything, from the best picks & counters to team synergies

## Read

- Whole page

## Not read

- u.gg/faq (403 to curl; not fetched)
