---
title: 'Blitz.gg: match page (performance scores, graphs, win probability)'
url: https://blitz.gg/lol/match/euw1/
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (one 30-minute ranked game of a Challenger EUW player: header, Overview, Stats, Timeline, Graphs, Win Probability tabs; desktop and phone)
relevance: high
grade: B/fair
description: Blitz match page: two 0-100 gauges (Combat, Farming) against a chosen benchmark, a rune value card, a two-block scoreboard, per-player cumulative line graphs with your line highlighted, and a per-minute win probability bar chart
---
# Blitz.gg: match page (performance scores, graphs, win probability)

Why: game detail (kind 1) on a big desktop-app site that has both a graph tab and a win probability tab. Profile and rows: [[blitz-profile-ui]].

## Assessment

- Evidence: B. Major site and app ([[blitz-lol]]); live page.
- Reasoning: fair.
- Interests: vendor; "Rank up faster with Premium" ads fill the right column.
- Weigh: shots in data/team/2026-10-24-ui/refs/game-detail/ (blitz-match-header.png, blitz-win-probability.png, blitz-graphs.png, blitz-phone.png). URL cut to the path.

## Findings

- [ux/postgame] Header: champion portrait framed in the result colour, the result word, queue, duration, age, and a badge for the game ("CS Master"); no K/D/A in the header. (seen in screenshot blitz-match-header.png, 24 Oct) ^f1
- [ux/features] The first screen is two 0-100 gauges, Combat (64, "Good") and Farming (33, "Fair"), each over three bar rows; a "vs" selector picks what the player is compared with (Rank, or the champion, here Draven). ^f2
  > CS Gained - Lane Phase
- [ux/postgame] A third card lists each rune with what it did this game, as a value and share of total. ^f3
  > 6.9% of total 1,837
- [ux/layout] Game sections are tabs under the header: Overview (scoreboard), Stats, Timeline, Graphs (marked New), Win Probability; bans sit at the right of the tab bar. ^f4
  > Win Probability
- [ux/density] Scoreboard: two team blocks with a totals bar (K/D/A, towers, dragons, barons, gold, damage), rows about 47 px: level, spells and runes, name, placement chip (7th, MVP, SVP), rank emblem with LP, 7 items, K/D/A over KDA, CS over KP, damage with a team-coloured bar. (seen in screenshot, 24 Oct) ^f5
- [ux/charts] Graphs tab: one cumulative line per player over minutes, the player's own line yellow and the other nine dimmed, a champion icon at each line's end, and a side list per team with totals and per-player values; sub-tabs pick the measure. ^f6
  > Damage Taken CS Gold Level Team Gold Lead
- [ux/charts] Win Probability tab: one bar per minute from 3:00, drawn up from a middle baseline in teal when the player's team is favoured and down in red when not; only the extremes are labelled (+99%, 40%), no axis numbers. (seen in screenshot blitz-win-probability.png) ^f7
- [ux/postgame] Timeline tab: a vertical list of the player's own events with time and icons, including every trinket ward placed, so the first screen of it is five "Placed a trinket" lines before the first kill. (seen in screenshot 24 Oct) ^f8
- [ux/density] Stats tab: a ten-column grid (one per champion) of about 25 numbers each, the best value per row bold white and the player's column yellow; in our capture the row labels did not render. (seen in screenshot 24 Oct) ^f9
- [ux/layout] On a 390 px phone the three header cards become tabs (Combat, Farming, Runes) with one card shown, a good fold; the scoreboard follows. (seen in screenshot blitz-phone.png) ^f10
- [ux/trust] On a 24-minute game the analysis area was an empty 500 px box reading "Match too short to analyze", with the rest of the page unchanged. (seen in screenshot 24 Oct) ^f11

## Read

- Header cards, all five tabs, phone first screen.

## Not read

- Graph sub-tabs other than Damage Dealt; Win Probability hover; how the gauges are scored.
