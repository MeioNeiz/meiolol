---
title: 'Mobalytics: player profile, match rows and LP gains'
url: https://mobalytics.gg/lol/profile/euw/
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (Overview and LP Gains tabs of a Challenger EUW player's profile, desktop and phone)
relevance: high
grade: B/fair
description: Mobalytics' profile: playstyle tags, rank cards, LP sparkline, GPI radar, role table, six performance tiles, a 120-day activity heatmap, played-with list, last-10 summary strip and day-grouped match rows with LP and tag chips
---
# Mobalytics: player profile, match rows and LP gains

Why: match history list and profile layout (kind 2) from the coaching-first big site. Game page: [[mobalytics-match-ui]].

## Assessment

- Evidence: B. Large site ([[similarweb-opgg-competitors#^f3]]); live page.
- Reasoning: fair.
- Interests: vendor; a "download the desktop app" banner sits between the summary and the match list, plus a floating video ad at 1280.
- Weigh: shots in data/team/2026-10-24-ui/refs/profile/ (mobalytics-header.png, mobalytics-summary.png, mobalytics-match-rows.png, mobalytics-lp-gains.png, mobalytics-phone.png).

## Findings

- [ux/features] Six playstyle tags under the name, green for strengths and yellow for mixed (Damage Dealer, Early Farmer, Ready to Rumble, Vision Focused, Solid Laner, Strong Start). (seen in screenshot mobalytics-header.png, 24 Oct) ^f1
  > Ready to Rumble
- [ux/charts] An LP sparkline of the last 50 games sits in the left column under the rank cards, x labels only "50 games ago", "25", "Last game". ^f2
  > LP PROGRESS TRACKING
- [ux/density] Six big-number tiles: GD@15, Gold Share, Damage Share, Solo Deaths, Solo Kills, Vision Score, each a number over a two-word label, no benchmark. ^f3
  > PERFORMANCE OVERVIEW
- [ux/charts] A 120-day calendar heatmap (weekday rows, week columns) colours each day by result from "bad day" pink to "good day" green and greys days by games played, with totals: 1900 games played, 864 hours played. (seen in screenshot mobalytics-summary.png) ^f4
  > RECENT ACTIVITY
- [fun] A "Most played with" card lists duo partners with games as W-L and win rate. ^f5
  > MOST PLAYED WITH
- [ux/density] "Recent summary, last 10 games": W-L with a two-colour bar, average K/D/A, the same per top champion or role, then a strip of 10 champion portraits (ring coloured by result) each with K/D/A and "17h ago". ^f6
  > 6.3 / 7.0 / 7.6 ( 2.0 ) KDA
- [ux/layout] Match rows are grouped under day headers that carry the day's record and win rate. ^f7
  > 17 HOURS AGO · 1W 1L · 50.0%
- [ux/density] A match row is about 150 px at 1280 with a result-tinted background (teal win, plum loss): queue, age, duration, patch, "Match Details" link; portrait with role badge; spells and runes; K/D/A over KDA; CS (per minute) over lane CS diff at 10 ("+27.0 @ 10m"); KP over wards; 7 items; LP chip ("+25LP", "-35LP"); up to about 10 tag chips; 10 players with lane-paired champion icons; a chevron that expands the game inline ([[mobalytics-match-ui#^f11]]). (seen in screenshot mobalytics-match-rows.png) ^f8
- [learning] Tag chips on rows are the post-game badges (Early Game Farmer, Never Slacking, Ouch You Hurt, Wrecking Ball, Lane Tyrant), one game showing 16 of them, so a row can wrap to two lines of chips. ^f9
  > Not A Fan Of Early Game CS
- [ux/charts] LP Gains tab: a 150-game LP line with dashed vertical lines and labels at each patch start (16.17 ... 16.20), x ticks every 50 games with dates, filters Last 150 Games, All Patches, role, champion; the hover card is the only place for per-game detail. ^f10
  > The graph shows additional info about the date, matchup, LP gain, and more.
- [ux/controls] Profile filters sit above the summary: queue dropdown, six role icon toggles (all plus five roles), champion search, reset; tabs Overview, Champion Pool, Matchup Pool, LP Gains. (seen in screenshot mobalytics-summary.png) ^f11
- [ux/layout] On a 390 px phone the left column stacks above the match list and the GPI radar, role table and tiles come before the games, so the first game sits several screens down; the role table's KDA, CS/M and LP columns are cut off at the right edge. (seen in screenshot mobalytics-phone.png) ^f12
- [ux/postgame] Checked, not there: the GPI page path guessed from the nav (/gpi) returned 404; the profile's GPI box shows only an 8-axis radar with icons, no numbers, on the web. (seen 24 Oct) ^f13

## Read

- Overview tab (header, tags, rank cards, LP sparkline, GPI radar, role table, tiles, heatmap, top roles, played-with, summary, rows), LP Gains tab, phone overview.

## Not read

- Champion Pool and Matchup Pool tabs; GPI detail page; desktop app.
