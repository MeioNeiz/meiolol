---
title: 'Mobalytics: match details page and post-game insights'
url: https://mobalytics.gg/lol/match/euw/
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (match details page of a Challenger EUW player's ranked game, desktop 1280 and 1600, inline expanded match row on the profile)
relevance: high
grade: B/fair
description: Mobalytics' web match page: five "best of" cards, a mirrored lane-by-lane scoreboard, mirrored damage bars, sorted income and ward bars, and a Cheat Sheet of written achievements and things to improve; no timeline or gold graph
---
# Mobalytics: match details page and post-game insights

Why: how a coaching-first site lays out one game after it ends, for the meio.lol game detail rebuild (kind 1). Profile and match rows: [[mobalytics-profile-ui]].

## Assessment

- Evidence: B. One of the largest LoL sites (Similarweb global rank #1,257, [[similarweb-opgg-competitors#^f3]]); live page.
- Reasoning: fair. No design rationale on the page.
- Interests: vendor; pushes its desktop app (the web page has no timeline data). A 250 px empty ad slot sits above the title at 1280.
- Weigh: shots in data/team/2026-10-24-ui/refs/game-detail/ (mobalytics-match-scoreboard.png, mobalytics-match-bars.png, mobalytics-row-expanded.png). The URL is cut to the path; the page was a Challenger EUW player's game.

## Findings

- [ux/postgame] The header is only "Match Details", queue and duration; no result, champion or KDA of the player in the header: the result shows as a "Lost"/"Won" chip on each team's bar. ^f1
  > Ranked Solo∙24:22
- [ux/postgame] Five award cards head the page, each a big number and the player who got it: Highest CS, Best DMG, MVP, Best Gold, Highest KDA. (seen in screenshot mobalytics-match-scoreboard.png, 24 Oct) ^f2
  > Game Highlights
- [ux/layout] The scoreboard is mirrored by lane: each row is one lane, blue player on the left, the red lane opponent on the right, the role icon between them, so the lane comparison is the row itself. Per side: name, rank chip, K/D/A over KDA, CS with CS per minute over KP, placement chip (7th, 10th, MVP), spells, runes, 7 item slots. (seen in screenshot mobalytics-match-scoreboard.png) ^f3
- [ux/density] Rows are about 115 px tall at 1280, so the 10 players take two screens; the team bar carries team K/D/A and gold (20 / 45 / 31, 47.1k). (seen in screenshot) ^f4
- [ux/charts] Damage dealt and damage received are two cards of mirrored horizontal bars, blue bars growing right from the left player, red bars growing left from the right player, one lane per row, number at the bar's root. ^f5
  > DAMAGE RECEIVED
- [ux/charts] Income and wards are vertical bar charts of all ten players sorted high to low, bar colour = team, champion icon and number under each bar, with a two-way toggle in the card header (Overall or CS; Cleared or Placed). (seen in screenshot mobalytics-match-bars.png) ^f6
- [learning] A right-hand Cheat Sheet lists "Your achievements" and "Things to improve", each a named badge with a paragraph of advice. ^f7
  > Things to improve
  > You didn't place a single control ward all game. I know you want to save money for those juicy items, but knowledge gives you the power to get more items.
- [learning] Insights carry the player's number inside the sentence, then generic advice; about 40-60 words each, four of them for this game, about 200 words in all. ^f8
  > In the first 15 minutes you had 5 cs per minute, which means you only last hit less than half of each wave.
- [ux/trust] Badge names are jokey and blunt (No Control, Anti-KDA Player, Where Are Your Dragons?), the same set reused as chips on the match rows ([[mobalytics-profile-ui#^f9]]). ^f9
  > Where Are Your Dragons?
- [ux/postgame] Checked, not there: no gold or win chance graph, no timeline of kills or objectives, no skill order or build order on the web match page; a team objectives table (Bans, Damage, KDA, Gold, Towers, Drakes, Elder Dragons, Barons) under the Cheat Sheet is the only game-flow summary. (seen in page text and screenshots 24 Oct) ^f10
- [ux/postgame] The same game also opens inline under the match row on the profile: achievement chips, "OPEN POST GAME", then two stacked team tables with a tier average per team and a damage bar per player, about 66 px a row. (seen in screenshot mobalytics-row-expanded.png) ^f11
- [ux/features] The expanded row adds a lane CS difference at 10 minutes under CS, for the players that have one (+23.0 @ 10m). (seen in screenshot mobalytics-row-expanded.png) ^f12

## Read

- Match details page (scoreboard, award cards, damage, income, wards, Cheat Sheet, objectives table), inline expanded row.

## Not read

- Desktop app post-game (where Mobalytics keeps timelines and GPI per game); phone layout of the match page.
