---
title: 'Porofessor: live game player cards (Wayback, Apr 2026)'
url: https://web.archive.org/web/20260412131641/https://porofessor.gg/partial/live-partial/euw/
kind: project
commit: 
for: [lol-site-ui, showing-ranges]
looked: 2026-10-24
depth: skimmed (one archived Normal Draft live game: ten player cards)
relevance: high
grade: B/fair
description: Porofessor live game page: ten cards, five per team row, each with champion stats, rank, current and main roles, 12-hour and 30-day activity, and green, yellow and red tags (Hot Streak, AutoFilled?, Main banned, newbie)
---
# Porofessor: live game player cards (Wayback, Apr 2026)

Why: player cards and tags (kind 2) from the leading scouting tool; the brief names its tags ("on a win streak", "main"). Overwolf app: [[overwolf-porofessor]].

## Assessment

- Evidence: A. Biggest LoL companion app (17.7M Overwolf downloads, [[overwolf-porofessor#^f1]]); its card design has years of use.
- Reasoning: weak.
- Interests: vendor.
- Weigh: porofessor.gg served a Cloudflare challenge on 24 Oct; this is the archived live-game partial (12 Apr 2026) injected into an archived page shell, so the page frame is missing and some champion images did not load. Shot: data/team/2026-10-24-ui/refs/profile/porofessor-live-cards.png.

## Findings

- [ux/layout] Ten cards in two rows of five, the team in the card header colour (blue top row, red bottom), the header the player's name and a premade group icon with a number shared by duo partners. (seen in screenshot porofessor-live-cards.png, 24 Oct) ^f1
- [ux/density] Each card stacks five boxes: stats on the current champion (win rate, games, K/D/A, champion rank), ranked tier and LP with last season's emblem and this season's win rate and ladder rank, the role in this game and main roles, games and wins in the last 12 hours and 30 days, then tags. ^f2
  > Main Roles: AD Carry, Top
  > S26.S1: 51% Win (65 Played)
- [ux/colour] Main roles turn red when the player is not in one of them this game. (seen in screenshot) ^f3
- [ux/features] Tags are short phrases in coloured chips: green for strengths (Hot Streak, Great with Veigar, Unkillable Laner, Aggressive Laner), yellow for maybe (AutoFilled?, Invader, Waking up), red for weaknesses (Shyvana newbie, Main banned, Passive Laner, Vulnerable Laner, Bad vision, Ashe casual). ^f4
  > Great with Veigar Unkillable Laner Hot Streak Main banned Passive Laner
  > Hot Streak AutoFilled? Shyvana newbie
- [ux/uncertainty] Activity is two big faint numerals, 12H and 30D, each with games and wins beside them, so a cold or a busy player shows at a glance. ^f5
- [ux/controls] Two dropdowns scope every card: which queues the stats count and the time window. ^f6
  > NORMAL & RANKED STATS LAST 30 DAYS
- [policy] (inferred) These cards show other players' names and stats before and during a game, the thing meio.lol's product rules forbid in champ select; for meio.lol the card and tag design is reusable only for the player's own profile or a post-game page. ^f7

- [ux/uncertainty] The champion win rate on a card is shown however few the games,
  in the same dark text whether it rests on 1 game or 18; only the count after it, in
  lighter grey brackets, tells them apart. (style seen in screenshot) ^f8
  > "100% Win (1 Played)"
  > "72% Win (18 Played)"
- [ux/uncertainty] With no games on the champion in the window the card drops the rate
  and shows only the count, with dashes for K/D/A. ^f9
  > "0 Played - / - / -"
- [ux/uncertainty] Thin experience is also put in words as a red tag on the champion
  (Shyvana newbie on 2 games, Morgana casual on 2, LeBlanc newbie on 0, Ashe casual on
  0 with mastery 441); the rule behind newbie versus casual is not stated (mastery
  level appears to play a part, inferred). ^f10
  > "Hot Streak AutoFilled? Shyvana newbie"
- [ux/uncertainty] Checked, not there: no floor, fading or range on the champion win
  rate; a 0% on 2 games and a 100% on 1 game sit in the same style as the rest. ^f11

## Read

- One live game's ten cards.

## Not read

- Live site; ranked solo games; desktop app cards; expanded card details (each box has a chevron).
