---
title: 'Tracker.gg LoL: profile overview, match rows and match modal'
url: https://tracker.gg/lol/profile/riot/EUW/
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (Overview of a Challenger EUW player's profile, match rows, a match opened as a modal; desktop only)
relevance: medium
grade: B/fair
description: Tracker.gg League profile: queue tabs, rank history with a 70-day rating line, a graded Tracker Score with percentiles, last-25 summary, day-grouped compact match rows with a 0-1000 TRS score, and a scoreboard modal with lane diffs
---
# Tracker.gg LoL: profile overview, match rows and match modal

Why: match history (kind 2) and game detail (kind 1) on a multi-game tracker network whose Valorant pages lead on round timelines ([[valtracker-match-ui]]). Launch and nav: [[tracker-lol-launch]].

## Assessment

- Evidence: B. Large multi-game network ([[tracker-lol-launch#^f4]]); live page.
- Reasoning: weak.
- Interests: vendor; ad-free Premium sold in a banner inside the page and a video ad at 1280.
- Weigh: shots in data/team/2026-10-24-ui/refs/ (profile/tracker-overview.png, game-detail/tracker-match-modal.png). URL cut to the path.

## Findings

- [ux/layout] Queue tabs across the page (Ranked Solo, Ranked Flex, ARAM, Swiftplay, Normal Draft, Arena) and a season selector filter everything below. ^f1
  > Ranked Solo Ranked Flex ARAM Swiftplay Normal Draft Arena
- [ux/charts] The ranked overview shows current LP, season best, all-time best and previous seasons as small chips, next to a "Last 70 Days" rating change (+660) and a line of rating over time with rank emblems at its ends. ^f2
  > Last 70 Days +660 Rating
- [ux/uncertainty] A "Tracker Score" out of 1,000 sits over four stats, each with a letter grade and the player's percentile in the population. ^f3
  > Tracker Score 561 /1,000
  > Kill Participation 49.3% S Top 15.0%
- [ux/colour] Grades show both directions in words (Top 39.0%, Bottom 38.0%), with a large faint grade letter behind each tile. (seen in screenshot tracker-overview.png, 24 Oct) ^f4
- [ux/density] "Last 25 matches" opens with a summary strip: win rate with W-L, average damage per minute, KDA (with K/D/A), gold per minute, each with its per-match total under it. ^f5
  > LAST 25 MATCHES
- [ux/layout] Matches are grouped by day; each day header carries games, W-L and the day's DPM, KDA and GPM averages. ^f6
  > Oct 23 2 1 W 1 L Avg DPM 698.5
- [ux/density] A row is about 75 px with a thin result stripe at the left and a tinted background for wins: age // duration, queue, LP change chip (or "?"), champion with level, spells and runes, items, a TRS score with a coloured emblem, K/D/A over a coloured KDA, CS per minute, a menu. (seen in screenshot tracker-overview.png) ^f7
- [ux/postgame] Clicking a row opens the game as a modal over the profile with "Open in New Tab" and "Copy Share Link", and two tabs, Scoreboard and Matchups. ^f8
  > Open in New Tab
- [ux/postgame] Scoreboard rows carry rank LP, TRS, K/D/A, damage dealt over taken (green/red), and two signed numbers that mirror between lane opponents (1,079 / 2.5% against -1,079 / -2.5%; 49 against -49), so each row shows the gap to its lane opponent. In our 1280 capture the column headers and the name and champion columns had scrolled out of view. (seen in screenshot tracker-match-modal.png) ^f9
- [ux/postgame] Checked, not there: no timeline, graph or win probability on the LoL match view; the Matchups tab did not open in our capture. (seen 24 Oct) ^f10

## Read

- Overview (rank, Tracker Score, last 25 summary, rows), match modal Scoreboard.

## Not read

- Matches and Champions tabs, Matchups tab of the modal, phone layout.
