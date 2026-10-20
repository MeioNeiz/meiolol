---
title: 'Kills and objectives in the first 10 minutes of ranked solo (our measurement, 2026-10-20)'
url: https://meio.lol/?measured=first-8-minutes-measured
kind: dataset
commit: 
for: [coach-stat-claims]
looked: 2026-10-20
depth: ran
relevance: high
grade: A/fair
description: Kills, jungler kills, first blood, first dragon, grubs and towers by 30-second bin in the first 10 minutes of 291k ranked solo games, with per-tier means
---
# Kills and objectives in the first 10 minutes of ranked solo (our measurement, 2026-10-20)

Why: check [[coachrogue-first-8-minutes]]'s timers (3:00 gank window, calm 4-5
minutes, 5:00 dragon, 8:00 grubs) on our games.

## Assessment

- Evidence: A. 290,807 ranked solo games with timelines (events.tsv,
  snap-20261013T2253Z), patches 16.19-16.20, all regions.
- Reasoning: fair. Counts by 30-second bin; per-tier means only as a check.
- Interests: none.
- Weigh: event times are when the kill or objective landed, not when a gank started;
  roles are the timeline's. Kills from any source count (a lane 2v2 at 3:00 counts like
  a gank). Script: ev.awk, ev2.awk, report.py in the session scratchpad.

## Findings

- [data] The early kill rate has a clear peak at 3:00-3:30 (2.05 kills a game-minute,
  the highest before 8:30), a dip at 4:00-5:00 (1.54 and 1.42) and a rise again from
  5:30 (1.86). ^f1
  > 2:30 | 220756 | 1.52 | 36035 | 5223 | 0 | 0 | 0
  > 3:00 | 297408 | 2.05 | 24573 | 7427 | 0 | 0 | 0
  > 4:30 | 206098 | 1.42 | 1332 | 298 | 0 | 0 | 0
  > 5:30 | 270229 | 1.86 | 718 | 184 | 26570 | 0 | 5
- [data] Jungler kills peak at 3:00-3:30 (90,754), more than twice 2:30-3:00 (40,486)
  and 4:30-5:00 (45,221), and rise again at 5:30 (64,634). ^f2
  > jungler kills | 0 | 4403 | 6700 | 10891 | 39320 | 40486 | 90754 | 71358 | 54539 | 45221 | 49401 | 64634
- [data] First blood comes early: mean 2.07 minutes, most often 2:00-2:30; the jungler
  gets it in 14% of games; top laners (28%) and supports (22%) die first most often. ^f3
  > 2:00 | 229593 | 1.58 | 71185 | 11637 | 0 | 0 | 0
  > jungle | 14.3% | 9.7%
  > top | 25.4% | 28.1%
- [data] First dragon is rarely taken at the 5:00 spawn: 10% of games by 6:00, 36% by
  7:00, 53% by 8:00, 77% by 10:00. ^f4
  > dragon total 288645: by 6:00 10.0% by 7:00 36.0% by 8:00 53.3% by 8:30 59.6% by 9:00 66.8% by 10:00 76.9%
- [data] Grubs: none before 8:00; 37% of games have the first grub by 8:30, 67% by 9:00. ^f5
  > grub total 288725: by 6:00 0.0% by 7:00 0.0% by 8:00 0.0% by 8:30 36.9% by 9:00 67.2% by 10:00 90.5%
- [data] Rank barely changes the early game: 11.1 to 11.6 kills before 8:00, first
  dragon at a mean 8.15 to 8.44 minutes, first tower 13.3 to 13.6, from Gold and below
  to Master+. ^f6
  > Gold and below | 11.1 | 2.04 | 8.15 | 8.96 | 13.64 | 16.88
  > Master+ | 11.6 | 2.08 | 8.37 | 8.89 | 13.32 | 16.86

## Read

- `raw/first-8-minutes-measured.md`: all
