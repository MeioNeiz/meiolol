---
title: 'Objectives and outer towers: win chance added in ranked solo (our measurement, 2026-10-20)'
url: https://meio.lol/?measured=coach-objectives-measured
kind: dataset
commit: 
for: [coach-stat-claims]
looked: 2026-10-20
depth: ran
relevance: high
grade: A/fair
description: Every tower, inhibitor and epic monster in 236k ranked solo timelines (lab snapshot 13 Oct, 16.19-16.20, test games left out): the taking team's eventual win rate minus its draft-aware state chance at the start of that minute, beside the lab's per-event regression values
---
# Objectives and outer towers: win chance added in ranked solo (our measurement, 2026-10-20)

Why: check the objective ranking in [[coachrogue-neutral-objectives]] (Broken by Concept's
30k games) and the mid tower claim in [[coachrogue-carry-when-fed]] on our data.

## Assessment

- Evidence: A. 236,227 ranked solo games with timelines (every platform, Platinum IV+,
  16.19-16.20): 929k dragons, 256k barons, 15k elders, 708k grubs, 205k heralds, 1.2M
  outer towers; chances from the lab's cross-fitted draft-aware state model.
- Reasoning: fair. Method: for each take, the taking team's eventual win rate minus its
  chance at the minute's start frame, the same kind of figure as the video's (won minus
  expected). Denominator: takes, not games. Limits: kills earlier in the same minute
  (the fight that opened a baron or elder) count towards the objective, so big
  objectives come out high; the lab's regression that shares a minute's credit among
  its events (copied into the raw file) is the cleaner value. Association, not cause:
  takers differ in ways the state misses.
- Interests: none.
- Weigh: no split by rank, so the video's "matters more at high rank" is untested.
  Atakhan can't be checked. Tower lanes: mid outer vs either side outer.

## Findings

- [data] Won minus chance just before, per take: first dragon +6.2 pp (video 6%), grub +1.7 per grub (video 1.37 for one or more, 1.97 for all three), herald +1.5 (video 1.5). ^f1
  > | dragon | first of game | 236046 | 61.9% | 55.7% | +6.2 pp |
  > | grub | all | 707794 | 56.2% | 54.5% | +1.7 pp |
  > | herald | all | 204835 | 66.6% | 65.1% | +1.5 pp |
- [data] Big objectives come out above the video's: baron +10.0 pp (video 6.2), soul +8.9 (6.15), elder +14.5 (8.29); the soul team wins 88.4% (video about 90%). ^f2
  > | baron | all | 256196 | 79.4% | 69.4% | +10.0 pp |
  > | dragon | soul (team's 4th) | 73581 | 88.4% | 79.5% | +8.9 pp |
  > | elder | all | 14578 | 80.1% | 65.7% | +14.5 pp |
- [data] With a minute's credit shared among its events (the lab's regression), the values fall to dragon 4.0-5.5 pp, baron 5.6-7.9, elder 9.2, grub 0.8, herald 0.6-0.75: the same order as the video's (elder > baron > dragon > grub, herald). ^f3
  > | dragon (any element) | 4.5 / 4.4-4.5 [±0.07] / 3.2-4.8 | 4.1 / 4.0-4.1 / 2.1-3.0 | 5.2-5.5 / 5.3-5.5 [±0.13] / 0.0-1.7 |
  > | baron | | 5.8 / 5.6 [5.6, 5.7] / 3.8 | 8.0 / 7.9 [7.8, 7.9] / 3.5 |
  > | elder | | | 9.2 / 9.2 [9.0, 9.3] / 4.4 |
  > | herald (15-19) | 0.75 / 0.61 / 0.21 | | |
- [data] Atakhan can't be checked: no Atakhan in our games (removed in patch 26.1). ^f4
  > no ATAKHAN rows at all (Atakhan was removed in patch 26.1)
- [data] A mid outer tower is followed by more than a side outer tower at the same state: +3.8 pp against +2.2 overall, and higher in every time band. ^f5
  > | outer tower mid | all | 385052 | 60.3% | 56.5% | +3.8 pp |
  > | outer tower side | all | 809605 | 57.0% | 54.8% | +2.2 pp |
- [data] No 14-minute turning point: the game's first mid outer tower adds about the same before 14 minutes (+3.5 pp) as at 14-19 (+3.4) or later (+3.8). ^f6
  > | game's first mid outer tower | <14 | 40531 | 76.9% | 73.4% | +3.5 pp |
  > | game's first mid outer tower | 14-19 | 184280 | 70.1% | 66.7% | +3.4 pp |
- [data] Objective values did not differ by who is ahead in the lab's earlier objective model, against the video's idea that behind teams waste buffs. ^f7
  > the value is the same whoever is ahead (objective x gold lead: nothing)

## Read

- `raw/coach-objectives-measured.md`: all
