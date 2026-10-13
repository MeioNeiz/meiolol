---
title: 'Thomas, Ventura, Jensen, Ma 2013: Competing process hazard function models for player ratings in ice hockey'
url: https://arxiv.org/pdf/1208.0799
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (abstract, model, shrinkage and implementation, team results, out-of-sample table, sections 5.1-5.2 on players and pairs)
relevance: high
grade: B/strong
description: Annals of Applied Statistics 2013; NHL goal rates as competing hazards with offensive and defensive player terms, hierarchical partial pooling per position group (variance components by MCMC) or lasso; lasso pair-interaction screen over the 1,000 most-shared pairs with the pair penalty chosen on held-out likelihood
---
# Thomas, Ventura, Jensen, Ma 2013: hazard models for hockey player ratings

Why: the hockey paper that fits pair (chemistry) terms on top of shrunk player effects
with a held-out penalty; what sizes did pairs reach and how were main effects held?

## Assessment

- Evidence: B. Peer-reviewed (Annals of Applied Statistics), five NHL seasons, held-out
  20% of games for every model comparison; with Gramacy 2013 the two references Hvattum
  relays for pair terms.
- Reasoning: strong. Explains when to use hierarchical variance components versus a
  single CV-chosen penalty, admits low information per player and team.
- Interests: none.
- Weigh: trust the protocol (fix main-effect penalties, screen pairs by exposure, choose
  the pair penalty on held-out likelihood); pair sizes are in log-rate units of goal
  scoring, not win probability.

## Findings

- [method] [stats] Two shrinkage modes: a full hierarchical Bayesian model that
  partially pools players by position (variance components estimated by MCMC), or
  penalised likelihood to select the few effects that stand out. ^f1
  > full Bayesian hierarchical models that partially pool parameters according to player position, and penalized maximum likelihood estimation to select a smaller number of parameters that stand out as being substantially different from average
- [stats] Cross-validation works for one penalty; several pooled groups need the
  hierarchical model to estimate the variances jointly. ^f2
  > If we are considering multiple partially pooled groups, cross-validation may no longer be computationally feasible, since searching the space of possible parameters becomes more difficult the more dimensions we add.
- [stats] Every comparison is on withheld games: a random 20% of each season's games. ^f3
  > For each season, we divide the games into two groups, uniformly at random – one for insample training (all observations from 80% of the games) and one for out-of-sample validation
- [stats] Held-out log likelihood: player terms beat team-only terms in all five
  seasons (total doubled negative log likelihood 76,087 vs 76,397 team, 76,416 score
  only), though single-game prediction barely improves. ^f4
  > Even with a large number of extra parameters, the model with player effects yields considerably better fit for the withheld data than the alternatives.
- [stats] Even team effects are rarely distinguishable from average: few team-season
  95% intervals exclude zero. ^f5
  > very few of these parameters have 95% credible intervals that do not contain zero, suggesting that the amount of information to distinguish a team from being truly “average” is quite small
- [method] [stats] Pair procedure: fix the player-effect penalties from the main model,
  add the 1,000 pairs with most shared shifts (same position group only), lasso on the
  pair block alone, penalty swept. ^f6
  > we use the mean value of each σg and λg as Laplace-Gaussian penalty terms that we will keep fixed for the individual player effects, to allow for and moderate adjustments due to the pair terms
  > we took the top 1000 pairs of players in terms of the number of shifts they played together over the five-year period
- [stats] [draft] Held-out likelihood picks pair penalty 8.5, which keeps 247 of 2,000
  pair parameters (221 pairs): about a quarter of the best-sampled pairs show some
  chemistry. ^f7
  > we find that the penalty λpair = 8.5 minimizes the test-set likelihood under cross-validation for these events. Of the 2000 possible parameters to select from (1000 each for ω and δ), this routine selects 247 non-zero parameters for player pairs for 221 unique player pairs.
- [draft] Sizes: top and bottom pair ratings +0.39 to -0.55 on the log scoring-rate
  scale, against a scale where a team rating of 0.1 is about 0.3 goals per game; the
  worst pair cancelled both players' individual positives. ^f8
  > A rating of 0.1 corresponds to a differential of roughly 0.3 goals per game scored or prevented.
  > whose mutual rating is so low that they effectively wiped out their positive total individual ratings during their time together
- [stats] Adding the pairs left individual ratings mostly unchanged (one swap at the
  top). ^f9
  > the positions of players in the grand rating table are mostly unchanged, so that the original player ratings are reasonably robust to these new additions
- [stats] Checked, not there: no held-out gain of the pair model over the player model
  reported as a number, no intervals on pair effects (lasso point estimates only), no
  variance component for pairs. ^f10
- [method] [draft] (inferred) The protocol to copy: fit main effects first with their
  own penalties, freeze them, then add a pair block restricted to pairs with enough
  games and pick its penalty on held-out log loss. For us the block is per role pair
  (10 ally, 25 enemy), each with its own penalty or variance, so lane opponents (large,
  75-200 gold) are not shrunk as hard as off-lane enemy pairs (35-45). ^f11
- [stats] (inferred) Freezing main effects is also the confounding guard: a pair term
  then only absorbs what is left after both champions' own strength, unlike
  [[ramler-2019-lol-symbiosis#^f6]]. ^f12

## Read

- Abstract, sections 3 (model, shrinkage, implementation), 4.2-4.3 (teams, fit
  table), 5.1-5.2 (exceptional players, pair interactions).

## Not read

- Supplementary pair list; time-varying hazard extension; goaltender results.
