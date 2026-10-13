---
title: 'Gramacy, Jensen, Taddy 2013: Estimating player contribution in hockey with regularized logistic regression'
url: https://arxiv.org/pdf/1209.5026
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (sections 1-3 skimmed, appendix B on player-pair interactions)
relevance: high
grade: B/strong
description: JQAS 2013; NHL goals as a binary outcome, L1 logistic on player and team indicators with a gamma hyperprior on the penalty, MCMC posterior; appendix adds all observed player-pair interaction terms
---
# Gramacy, Jensen, Taddy 2013: regularised logistic regression for hockey players

Why: the primary source behind the "pair synergy found little" result relayed by
[[hvattum-2019-plusminus-review#^f5]]; how were pairs added and what came out?

## Assessment

- Evidence: B. Peer-reviewed (JQAS), widely cited in hockey analytics, open R packages
  (textir, reglogit). One league, four seasons, 18k goals.
- Reasoning: strong. Explains prior choices (L1 for players, L2 for nuisance team
  effects), compares with and without team control, admits interaction posterior is
  infeasible with their sampler.
- Interests: none (authors' own packages).
- Weigh: the pair result is from 18k binary outcomes and 27k pairs, a much thinner
  data-to-pair ratio than ours per pair class but similar in spirit.

## Findings

- [method] [data] Data: every even-strength NHL goal over four seasons, 1,467 players,
  18,154 goals; outcome is which side scored. ^f1
  > There were np = 1467 players involved in ng = 18154 goals.
- [method] Model: logistic on team indicators (alpha) and +1/-1 player indicators
  (beta) per goal. ^f2
  > where qi = p(yi = 1), xP i = [xP i1 · · · xP inp ]0 is the vector corresponding to the ith row of XP , xT i is similarly the ith row of XT , α is the length-30 vector of team effects and β is the length-np vector of player effects.
- [stats] [method] Priors: Laplace (L1) on player effects for selection, normal (L2) on
  nuisance team effects; the L1 penalty gets a hyperprior so the data pick it. ^f3
  > We also employ a L2 penalty/normal prior for coefficients on “nuisance” variables, such as the team effects α.
  > We place an additional hyperprior distribution on the λj parameters so that the data can help us infer these penalty parameters along with their coefficients.
- [stats] Pairs are badly imbalanced: about 27k of over a million possible pairs are
  ever on ice together for a goal. ^f4
  > only about 27K of the greater than one million possible player pairs are actually observed on the ice for a goal
- [method] Pair terms: add columns that are row-wise products of pairs of player
  columns; sparse fitting made it 20 seconds, other solvers failed. ^f5
  > simply add columns to the design matrix that are row-wise products of unique pairs of columns in the original XP
  > Inference on the fully interaction-expanded design takes about 20 seconds on an Apple Mac Desktop.
- [stats] [draft] Result: little evidence of pair effects; only four non-zero
  interactions under the lasso, and they barely move the player effects. ^f6
  > our results indicate little evidence of significant player interaction effects
  > four non-zero interactions are found when augmenting the team–player model to include player–player interaction terms.
- [stats] Full posterior with interactions was infeasible; they sampled only a model
  with the four selected pairs added (a post-selection posterior). ^f7
  > Using reglogit to obtain samples from the full posterior distribution of the interactionexpanded model is not feasible
- [stats] Checked, not there: no out-of-sample test of the interaction model, no
  variance share of pairs, no low-rank pair model. ^f8
- [stats] [draft] (inferred) Lasso on raw pair indicators at sparse data selects
  almost none; this is a statement about power, not that synergy is zero. Our "ally
  synergy not detected at 90k" matches; to get intervals rather than a selection,
  use L2 (Gaussian) pair priors with a variance fitted to the data, not L1. ^f9

## Read

- Abstract, introduction, data and model (section 2), prior choice (2.3, 3 start),
  appendix B.

## Not read

- Section 4 posterior comparisons, MCMC details (appendix A).
