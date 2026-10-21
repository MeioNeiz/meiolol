---
title: Validating the win-rate of Heroes in Dota 2 using instrumental variable estimation (David van der Maas, TU Delft CSE3000 research project poster)
url: https://cse3000-research-project.github.io/static/719e7cd11aa48e6ef80362801ea60cfd/poster.pdf
kind: talk
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: listed (whole poster)
relevance: medium
grade: D/weak
description: Bachelor research poster: Dota 2 Single Draft (each player offered 3 random heroes, blind to others) as an instrument for hero choice; Viper's observed and IV win rates agree, Meepo's 53.7% observed drops to 47.2%
---
# Validating hero win rates in Dota 2 with instrumental variables (TU Delft poster)

Why: one of the few attempts to estimate a hero's win rate free of who chooses it, using
a game mode that restricts choice at random.

## Assessment

- Evidence: D. Undergraduate poster, two heroes, no sample sizes, method details absent;
  part of a TU Delft CSE3000 cohort on causal inference in Dota 2 (sibling theses on
  randomised data and g-formula not reachable: host timed out).
- Reasoning: weak; exclusion restriction asserted, the author doubts the result.
- Interests: none.
- Weigh: the idea (a random restriction of choice as an instrument, and an All Random
  mode as the benchmark) is the useful part; numbers are illustrative at best.

## Findings

- [method/causal] Instrument: Dota 2 Single Draft, where each player picks from 3 random
  heroes without seeing others' picks; assumed not to affect skill or team building. ^f1
  > This game mode only lets players select
  > from a 3 hero pool whilst being unable to see what other
- [method/causal] [stats] Result: Viper's observed win rate (49.03%) and IV win rate
  (48.73%) agree; Meepo, a specialist hero, drops from 53.71% observed to 47.22% by IV,
  with a larger variance from a weaker instrument. ^f2
  > Meepo            53.71%             47.22%            0.49%
  > Viper           49.03%*             48.73%            0.24%
- [method/causal] The author's own comparison with a fully randomised (All Random)
  experiment still found Meepo's IV win rate too high, and calls IV unreliable here. ^f3
  > IV is too unreliable within these complex
- [method/causal] (inferred) The pattern fits selection by specialists: a hero that
  rewards practice and is chosen mainly by those who practised it shows a raw win rate
  far above its "random player" win rate, a typical hero does not. In LoL the same
  shows up as mastery-by-champion gaps (learned.md: Rengar 39% new vs 51% practised). ^f4

## Read

- Whole poster.
