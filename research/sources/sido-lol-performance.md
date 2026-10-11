---
title: 'Zhang and Naidu 2024: The SIDO Performance Model for League of Legends'
url: https://arxiv.org/pdf/2403.04873v2
kind: paper
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: docs (sections 4-6.2, 7.2.3 stability)
relevance: medium
grade: B/strong
description: arXiv stat.AP 2024 hierarchical Bayesian model of player gold and damage in high-elo solo queue with crossed champion and player random effects, by game phase
---
# Zhang and Naidu 2024: The SIDO Performance Model for League of Legends

Why: closest published work to ours: a hierarchical (shrinkage) model of gold in LoL
solo queue with champion and player effects, by game phase.

## Assessment

- Evidence: B. arXiv preprint (stat.AP, v2 May 2024), two authors, real Riot API data
  (top 1000 accounts NA, KR, EUW, patches 13.14-13.18); stability checked across
  patches. Not peer reviewed as far as seen.
- Reasoning: strong. Explains model choices, priors, filtering by simulation.
- Interests: none known.
- Weigh: scope is player skill at the very top, not matchup curves; transferable parts
  are crossed random effects, phase-based gold windows, and the warning that player and
  champion effects confound.

## Findings

- [stats] [method] Player gold is modelled as intercept + champion random effect +
  player random effect + noise, fitted as a Bayesian hierarchical model. ^f1
  > goldpg = β0 + bc + bp + ϵpg ,
- [stats] They chose hierarchical Bayes because it works with scarce and imbalanced
  data through shrinkage and pooling. ^f2
  > The model is fit in a Bayesian paradigm, which has been shown to perform well in applications with scarce and/or imbalanced data, a property which is often attributed to hierarchical shrinking and information pooling
- [stats] Heavy-tailed (Student t, 3 df) random effects so outlier champions or players
  are not over-shrunk. ^f3
  > A Student’s-t distribution is used instead of a normal density because it has heavier tails, which allows for outliers in the champion or player random effects.
- [data] [method] Gold is split by phase (0-7, 7-15, 15-25 minutes) as differences of
  cumulative totals, i.e. gold earned within each window. ^f4
  > 7 minutes and 15 minutes roughly correspond to the end of the early and mid-game phases.
  > So, when considering gold at 25 minutes, we subtract total gold at 15 minutes from total gold at 25 minutes
- [data] Data filters chosen by simulation: role mains with 50+ games; champions played
  by at least 30 accounts; games with a disconnect (under 500 damage taken by minute
  7) removed because they skewed results. ^f5
  > As these games were found to skew model results, we removed them by excluding games where any single player took less than 500 damage by the 7-minute mark.
  > For each role, we consider only games with champions played by at least 30 separate accounts.
- [stats] Player and champion effects confound: most players stick to a few champions,
  so a model without a champion effect credits champion strength to the player. ^f6
  > the BA model, to some degree, conflates the player scores with the champion effect, since most players will stick to the subset of champions they are comfortable with.
- [stats] Champion effects are stable across patches (concordance typically above 0.8
  on EUW and NA). ^f7
  > In the EUW and NA servers, concordance is typically above 0.8 for the champion effect.
- [stats] (inferred) For matchup curves: remove AFK or disconnect games before
  averaging (a lane "win" against an absent player is not the matchup); and one-trick
  players may dominate a rare champion's games, so a thin matchup may measure a few
  players, not the champions. ^f8

## Read

- Sections 4-5 (data, filters), 6.1-6.2 (player gold model, priors), 7.2.3 stability

## Not read

- Ally and enemy models (6.3-6.5), discrimination results, champion prioritisation
