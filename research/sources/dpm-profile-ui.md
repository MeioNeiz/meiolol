---
title: 'DPM.LOL: summoner profile and match list, Oct 2026'
url: https://dpm.lol/profile
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text of Overview and DPM Lens; screenshots desktop and phone)
relevance: high
grade: B/fair
description: dpm.lol profile of a Challenger EUW player: LP line with 30 and 7 day change, peak and MMR; role and champion performance; played with; last-30 summary with average place; rows grouped by day (or session) with a day summary and the lane opponent's portrait in each row
---
# DPM.LOL: summoner profile and match list, Oct 2026

Why: lol-site-ui, kind 2. Screenshots in data/team/2026-10-24-ui/refs/profile/
(gitignored): dpm-profile-top.png, dpm-rows-days-friends.png, dpm-lens.png,
dpm-deeplol-phone.png (left half).

## Assessment

- Evidence: B. Newer, popular site with a clean, consistent design system.
- Reasoning: fair. Clear hierarchy, few words, groups by what players remember.
- Interests: ad light on this page; Premium in the header.
- Weigh: the best-designed profile of the four; the row is the one to model.

## Findings

- [ux/charts] [ux/postgame] Rank card holds an LP line (about 250 x 170 px) for the
  season with "Last 30d ▲ 295 LP" and "Last 7d ▼ -15 LP" above it, peak and an MMR
  estimate below; the first screen shows it beside the match list. ^f1
  > Last 30d | ▲ | 295 | LP | Last 7d | ▼ | -15 | LP | PEAK | 4417 LP | MMR | 2474 LP
- [ux/postgame] Summary over the list: a half-ring win rate (16W - 14L), top three
  champions with record and KDA, big KDA with K/D/A, and "AVG. PLACE 5.6/10" with MVP and
  ACE counts. About 25 words. ^f2
  > LAST 30 GAMES | 53% | WINRATE | 16W - 14L
  > AVG. PLACE | 5.6/10 | MVP ×3 | ACE ×3
- [ux/controls] [ux/postgame] Above the list: role icon filter (six icons) and a grouping
  toggle Day / Session / None, plus Filters. ^f3
  > Day | Session | None | Filters
- [ux/postgame] [ux/layout] Each day group opens with the date and chips: average DPM
  Score, wins, losses and the day's net LP (-55 LP), so a bad day shows before reading
  the rows. ^f4
  > Oct 22 | DPM Score : 55.2 | 3 wins | 3 losses | -55 LP
- [ux/postgame] [ux/density] Match row only 62 px: duration, time ago, queue, LP change
  chip; champion with role icon; K/D/A over a team-quality tag (Bad team, Great team);
  KDA, CS or vision per minute (vision for supports), kill share; runes; items; the lane
  opponent's portrait with "VS"; a score ring 0 to 100 with the place (10th, MVP); video
  and expand buttons. No teammate names on the row. ^f5
  > 24:22 | 17h ago | Solo/Duo | - 35 LP | 3 / 10 / 5 | Bad team | 0.8 KDA | 5.5 CS/m | 40% KP | VS | 5 | 10th
  > 26:18 | 2d ago | Solo/Duo | - 35 LP | 3 / 11 / 16 | Bad team | 1.7 KDA | 2.6 VS/m | 66% KP | VS | 46 | 6th
- [ux/postgame] Sidebar: champion performance (win rate, record, KDA, CS/m), role
  performance (games, win rate, record per role), played with (games, win rate, record,
  across all time, not just the last 20), and total pings by type. ^f6
  > ROLE PERFORMANCE | Top | 1063 games | 57.1% WR | 607W - 456L
  > PLAYED WITH | [player] | 85 games | 61% WR | 52W - 33L
- [fun] Total pings by type per game ("On my way 40.3 / game"): a light, shareable stat. ^f7
  > TOTAL PINGS | On my way | 77,343 | 40.3 / game
- [ux/charts] DPM Lens tab: seven skill areas, each a 0-100 ring against a chosen
  reference (vs Challenger by default, or a pro or one-trick), one marked "Skill to
  improve", around a node graph with the overall 53.6; a Compare / My progress toggle. ^f8
  > COMPARE | MY PROGRESS | Timeframe | Queue
  > SURVIVABILITY | SKILL TO IMPROVE | vs | 28
- [ux/layout] Phone (390 px): one column, rank card and LP line first, then champions,
  roles, the summary and the role/day controls; first row near 1,550 px; the row keeps
  its 62 px two-line form (screenshot dpm-deeplol-phone.png). ^f9
- [ux/postgame] Linked accounts sit as tabs above the header (five accounts of the same
  player), one click between them. ^f10
  > Linked accounts strip: [player] | [player] EUW | ... (five accounts as tabs above the header)

## Read

- Overview and DPM Lens, desktop; Overview phone.

## Not read

- Champions and Live tabs; Lens sub-tabs and My progress.
