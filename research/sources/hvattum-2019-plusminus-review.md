---
title: 'Hvattum 2019: A comprehensive review of plus-minus ratings for evaluating individual players in team sports'
url: https://sciendo.com/pdf/10.2478/ijcss-2019-0001
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (intro, basketball, ice hockey, soccer Bayesian parts, future work, conclusions)
relevance: high
grade: A/fair
description: IJCSS 2019 survey of 41 plus-minus papers (NBA, NHL, soccer, volleyball); ridge, lasso, Bayesian and hierarchical variants, and the few attempts at player-pair interaction terms
---
# Hvattum 2019: A comprehensive review of plus-minus ratings

Why: what do regularised plus-minus models do about pairs (synergy) and opponents, how is
the penalty chosen, and what did pair terms find?

## Assessment

- Evidence: A. Peer-reviewed survey of 41 contributions (20 peer reviewed) by a
  researcher who publishes plus-minus models; the standard map of the field.
- Reasoning: fair. Descriptive survey, little synthesis of effect sizes; says itself
  there is no common quality measure.
- Interests: none known; cites own soccer work.
- Weigh: trust as a map and for the pair-term results it relays (Gramacy 2013, Thomas
  2013); the underlying numbers are in those papers.

## Findings

- [method] [stats] Plus-minus models face both kinds of interaction we care about:
  teammates and opponents. ^f1
  > interactions between the individual players and their teammates, as well as interactions between the individual players and the opposing players, both make the performance of a player difficult to isolate
- [stats] Ridge is a Gaussian prior; it stabilises ratings with few observations and
  under collinearity; lambda by cross-validation. ^f2
  > This corresponds to using a Gaussian prior distribution, stabilizing the estimated ratings, both in cases with few observations and when multicollinearity is present
- [stats] [method] Alternative to CV: Fearnhead and Taylor 2011 estimate the prior
  variances (separate offence and defence Gaussians) by maximum likelihood, an
  empirical Bayes variance component per block. ^f3
  > Fearnhead and Taylor (2011) used maximum likelihood to estimate the hyperparameters of the prior Gaussians
- [method] [stats] NHL logistic plus-minus (Gramacy et al. 2013): L1 or L2 penalised
  logistic regression on which side scored each goal, MCMC for the full posterior, so
  pairwise "player A better than B" probabilities. ^f4
  > MCMC was used to estimate the full posterior distribution. This allowed statements regarding the probability that a given player is better than another player on the same team.
- [stats] [draft] Gramacy 2013 tested player-pair synergy terms and found little
  evidence; the few non-zero pairs barely moved the main effects. ^f5
  > the authors concluded that there was little evidence of significant player interaction effects. Also, includ ing the few non-zero interactions found had a very limited effect on the individual player estimates.
- [stats] [method] Thomas et al. 2013 screened the 1,000 pairs with most shared minutes,
  lasso to select, MCMC to fit: 221 pairs non-zero. ^f6
  > Lasso regression was then employed to reduce the number of non-zero pairs, and finally MCMC was used to obtain the final results. In total, 221 of the player pairs had an effect not equal to zero
- [method] Cost: MCMC took up to 60 processor hours for 200,000 outcomes and 2,600
  variables. ^f7
  > This resulted in relatively large runtimes, up to 60 processorhours for 200,000 outcomes and 2,600 independent variables.
- [stats] Under L1 most players are not distinguishable from their team's average;
  lasso logistic leaves only half the estimates non-zero (Smith 2016). ^f8
  > Using the Laplacian prior to estimate player ratings, the authors found that few players are distinguishable from the average player of their team.
- [stats] Gramacy 2017 penalised only the player effects (team-season effects free)
  and chose the penalty by corrected AIC instead of CV. ^f9
  > the authors chose to penalize only the player effects. Furthermore, to decide on an appropriate penalty term, they use the corrected Akaike information criterion instead of cross validation.
- [stats] Informative priors: centring each player's prior on a video game rating
  instead of zero predicted results better than plain ridge (Matano 2018). ^f10
  > instead of assuming that all player ratings should be shrunk towards zero, the prior for each player’s rating is centered around a value based on a subjective score
- [stats] The field has no agreed quality measure; out-of-sample prediction of future
  results is one used option. ^f11
  > There is at this point no common method to measure the quality of different plusminus ratings.
- [stats] Covariates that are significant can still barely change ratings when balanced
  across players (home advantage in soccer). ^f12
  > since most players have a similar amount of appearances both away and at home, the effect tends to cancel out
- [method] Checked, not there: no review of factorised (low-rank) pair models, no
  variance share of pair terms vs main effects, no esports. ^f13
- [draft] [stats] (inferred) In sports with far fewer distinct pairs than we have, pair
  synergy mostly came out null or sparse; with ~170 champions and 10 ally role pairs
  per game, an undetected ally synergy at 90k games is the expected result, not a bug.
  Screen to well-sampled pairs (as Thomas did) or factorise. ^f14
- [stats] (inferred) Penalise only the pair block and leave main effects (champion by
  role, patch) lightly penalised, as Gramacy 2017 left team effects free; otherwise
  shrinkage on the main effects leaks into the pairs. ^f15

## Read

- Introduction, basketball and ice hockey sections, soccer Bayesian parts, future
  work, concluding remarks.

## Not read

- Table 2 (paper by paper summary) in detail; soccer details; volleyball.
- Primary papers: Gramacy, Jensen, Taddy 2013 (JQAS) and Thomas et al. 2013 for pair
  effect sizes.
