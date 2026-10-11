---
title: 'Counterwatch: How Counterwatch calculates hero counters and synergies'
url: https://www.counterwatch.gg/blog/how-counterwatch-calculates-hero-counters-and-synergies-896ef42c
kind: article
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: listed (whole post)
relevance: medium
grade: C/fair
description: Overwatch/Marvel Rivals stats app's own methodology post (2026): counter rates with opponent and hero baseline removed ("double normalization"), selection-bias reasoning
---
# Counterwatch: How Counterwatch calculates hero counters and synergies

Why: a rare published methodology from a stats product on separating a pair effect
from each side's overall strength, for comparison with our additive baseline.

## Assessment

- Evidence: C. Single developer's app, ~60,000 matches a week from opted-in users;
  methodology post, no validation numbers.
- Reasoning: fair. Explains each choice with a worked example and admits limits.
- Interests: vendor (Overwolf app marketing its own numbers).
- Weigh: the additive centring idea is sound and matches [[draftgap#^f8]]; no
  low-sample handling is described in the post.

## Findings

- [tools] [stats] Raw matchup rates are biased by each side's overall strength; they
  subtract the opponent's average rate, then the hero's average normalised rate, and
  show the remainder (the pair effect) re-centred on 50%. ^f1
  > Pass 1, opponent and ally normalization, subtracts each opponent's (or ally's) average win rate across all heroes
  > The output of the two passes is a delta, how much better or worse the matchup runs than each hero's overall strength alone predicts.
- [tools] [stats] Worked example: a raw 48% matchup becomes about 51% after removing both
  heroes' overall strength, i.e. the sign flips. ^f2
  > A raw aggregate site might tell you Cassidy wins 48% against Winston, which looks like a losing matchup. After double normalization the displayed number is roughly 51%.
- [stats] Selection bias from context: a hero picked into strong comps looks worse in
  raw matchup numbers than the matchup really is. ^f3
  > Raw aggregation blamed that on Cassidy losing the matchup, when the real signal is that Cassidy does better than expected against those dive heroes
- [stats] Survivorship in weighting: countered heroes get swapped out, so playtime
  weighting would hide the counter; each pair counts as 1 instead. ^f4
  > Weight pairs by playtime and you downweight the data that proves the counter works
- [data] Volume limits slicing: enough for hero-vs-hero overall, not per map. ^f5
  > 60,000 matches a week is plenty for reliable hero-versus-hero numbers across the roster, but not enough to break those down per map.
- [stats] Checked, not there: no minimum sample, shrinkage or Bayesian adjustment is
  described in this post (a search summary claimed shrinkage; the page text does not
  say so). ^f6
- [stats] (inferred) Two sequential mean-subtractions are an approximation of the
  additive two-way fit; with unbalanced counts (popular vs rare opponents) a proper
  additive fit (alternating means, i.e. backfitting) is better and just as cheap. ^f7

## Read

- Whole post
