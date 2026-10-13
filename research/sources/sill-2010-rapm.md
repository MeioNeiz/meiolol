---
title: 'Sill 2010: Improved NBA adjusted +/- using regularization and out-of-sample testing'
url: https://cdn.prod.website-files.com/68d6be744d7efccc2207f571/68d6be744d7efccc220807d7_SSAC10%20-%20Basketball_Sill.pdf
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (whole paper, 7 pages)
relevance: high
grade: A/fair
description: Sloan 2010 best paper and origin of RAPM; ridge regression on lineup stints, lambda and data window picked by 10-fold CV, scored on a held-out later block of games
---
# Sill 2010: Improved NBA adjusted +/- using regularization and out-of-sample testing

Why: the RAPM origin. How was the ridge penalty chosen, how was it tested out of sample,
and how much did shrinkage help over plain regression on lineup indicators?

## Assessment

- Evidence: A. The canonical reference for RAPM (cited as its origin by every later
  plus-minus paper); best paper at Sloan 2010. Single season split, one test block.
- Reasoning: fair. Clear Bayesian reading of ridge and a proper held-out test, but 7
  pages, no intervals on the ratings and no pair or lineup terms.
- Interests: author's consultancy (hoopnumbers.com).
- Weigh: trust the protocol (CV for lambda, later games as pure test) and the size of
  the gain; R-squared numbers are NBA margin specific.

## Findings

- [method] [stats] APM is a regression of each no-substitution stint's margin on +1/-1
  indicators of the ten players on court, plus a home constant; ratings are the
  effect of replacing an average player. ^f1
  > x is a vector of 0s,1s, and -1s with the 1s representing the presence of the home players on the court and -1s representing the road players
- [stats] Sill blames overfitting more than collinearity: too many parameters on noisy
  data. ^f2
  > it is the opinion of the author that multicollinearity is only part of the story behind the struggles of the APM technique
- [method] [stats] Protocol: lambda, minutes cutoff and past-season weight chosen by
  10-fold CV on games to February; March and April games held out as a pure test set
  and scored by RMSE of game margin. ^f3
  > The March and April games were used as the pure test set, so they were not included during the cross-validation phase for tuning the meta-parameters.
- [stats] Plain APM on one season predicts the held-out games worse than the trivial
  home-court model (RMSE 12.76 vs 12.58). ^f4
  > the test RMSE of this model with M =1200 on the March/April test set is 12.76, or worse than is achieved by the trivial home-court-advantage model
- [stats] Three seasons, plain regression: test RMSE 12.01, R-squared 0.088. ^f5
  > The test RMSE of this model was 12.01 (R-squared 0.088).
- [stats] [method] Ridge with lambda 3000 on three seasons: test RMSE 11.47, R-squared
  0.169, about double; one season with ridge gets 0.159, so shrinkage matters more
  than extra data. ^f6
  > This model achieves a test RMSE of 11.47 (R-squared 0.169).
  > With just 1 year of data and M =0, the optimal λ is found to be 2000 and the corresponding test RMSE achieved is 11.54 (test R-squared 0.159)
- [stats] Lambda is the noise to prior variance ratio; the CV lambdas imply a prior SD
  of about 3 points per player, so the penalty doubles as an estimate of the spread of
  true effects. ^f7
  > The λ in the equation is corresponds to the ratio of the variance of the inherent, unpredictable noise to the variance of this gaussian prior.
  > It is possible to deduce that a λ of 3000 corresponds to a gaussian prior with standard deviation 2.71
- [stats] Shrinkage reorders players a lot, not just a fine tuning. ^f8
  > Dramatic changes in the rankings of players can occur.
- [method] Checked, not there: no interaction (pair or lineup) terms, no intervals on
  ratings, no per-player uncertainty. ^f9
- [method] [draft] (inferred) Our win model is the same design with champions in place
  of players and a logistic link: ridge on +1/-1 champion (by role) indicators, with
  pair indicators added as a second block that needs its own, larger penalty. Choose
  each penalty by CV and test on a later patch block, as Sill holds out later games. ^f10
- [stats] (inferred) Ridge on unpenalised main effects plus penalised pairs gives
  lambda_pair = sigma^2_noise / tau^2_pair; reading tau_pair from the CV lambda is a
  cheap estimate of how big pair effects are, comparable with the bounds we already
  have (35-45 gold for non-lane enemy pairs). ^f11

## Read

- Whole paper.

## Not read

- hoopnumbers.com extra results (four factors RAPM): not about pairs.
