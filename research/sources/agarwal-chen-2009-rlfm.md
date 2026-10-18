---
title: 'Agarwal and Chen 2009: Regression-based latent factor models (RLFM)'
url: http://web.archive.org/web/2020id_/https://web.njit.edu/~zhiwei/CS732/papers/Regression-basedLatentFactorModels_KDD2009.pdf
kind: paper
commit: 
for: [hierarchical-comp-terms]
looked: 2026-10-18
depth: docs (abstract, 1, 2, 3.1, 5)
relevance: high
grade: A/fair
description: KDD 2009 (Yahoo! Research); user and item biases and factors get Gaussian priors centred on a regression on their features instead of 0; fitted by Monte Carlo EM, linear in data; MovieLens, EachMovie, Yahoo! Front Page
---
# Agarwal and Chen 2009: Regression-based latent factor models (RLFM)

Why: the recommender-system form of "shrink each id towards what its attributes
predict", with held-out comparisons against zero-mean shrinkage and features only.

## Assessment

- Evidence: A. KDD 2009, Yahoo! Research, highly cited; the basis of a chapter of
  their 2016 Cambridge book; three datasets incl. a production one (1.9M clicks).
- Reasoning: fair. Clear model, special cases and fitting choices (MCEM over ICM and
  ALS, with a table); results without intervals; RMSE gains reported as "significant"
  without tests.
- Interests: authors' method; the Yahoo! data is theirs.
- Weigh: trust the structure and the direction (attribute prior >= zero prior >
  features only); sizes are rating RMSE, not log loss on a near-coin-flip outcome.

## Findings

- [method] [stats] RLFM: biases and latent factors of users and items get a Gaussian
  prior whose mean is a regression on their features, not zero. Section 1 ^f1
  > Our method also assumes a Gaussian prior but replaces the zero mean with a feature-based regression
- [method] Second stage, per id: alpha_i = g0' w_i + eps, beta_j = d0' z_j + eps, each
  eps with its own variance (a_alpha, a_beta) estimated from data. Table 1 ^f2
  > RLFM is a two-stage hierarchcial latent factor model
- [stats] Sparse ids fall back to the feature prediction, heavy ids deviate from it
  as data allows; zero-mean shrinkage instead pulls light users towards 0 (biased).
  Section 1, Figure 1 ^f3
  > users/items with sparse data are deemed more unreliable to deviate and “shrunk” aggresively to the global one
  > For light users, ZeroMean “shrinks” the profiles close to zero and leads to biased estimates.
- [stats] Nesting: zero variance for the id deviations gives the features-only model;
  zero feature coefficients give plain zero-mean factorisation. Section 2.5 ^f4
  > the pure feature based model is obtained as a special case of RLFM by assuming a zero variance for random effects
- [stats] Prediction for a new id is the feature prediction; for a known id, the
  posterior mean balancing both. Section 2.4 ^f5
  > For new users and items, the posterior means are just prior means predicted purely by features
- [method] Fit: Monte Carlo EM; the M-step is five ordinary regressions of the current
  id estimates on their features, each variance updated as (RSS + summed posterior
  variances) / n. MCEM beat ICM (posterior mode, overfits at larger rank) and ALS.
  Section 3.1, Algorithm 1 ^f6
  > Each M-step mainly consists of solving five standard linear regression problems.
  > found MCEM to be the best, both in terms of predictive accuracy and resistance to overfitting with increasing number of latent dimensions r.
- [stats] MovieLens-100K, 5-fold, no new users or items in test: RLFM 0.8956 RMSE vs
  zero-mean 0.9064 vs features only 1.0968; the whole gain is the feature prior's
  better regularisation of known ids. Section 5, Table 3 ^f7
  > the gain obtained through RLFM relative to ZeroMean is entirely due to better regularization achieved through feature-based prior
- [stats] MovieLens-1M time split (last 25% test): RLFM 0.9742 / 0.9528 / 0.9363 vs
  zero-mean 0.9862 / 0.9614 / 0.9422 at 30 / 60 / 75% training; the gain shrinks as
  data grows. Features only ~1.09 throughout. Table 3 ^f8
- [stats] Features alone are weakly predictive, worse than item popularity; features
  help when combined with id terms. Section 5 ^f9
  > Models purely based on features are inferior to those based on user-item specific statistics.
  > the features are predictive and when combined together with past interaction data through our model provides significant improvement in accuracy.
- [stats] Advice: evaluate on time-based splits; random splits only tell you about
  persistent dyads. Section 5 ^f10
  > We believe future work in this area should evaluate algorithms using a time-based split to get a realistic estimate of an algorithm’s performance.
- [stats] Checked, not there: overlapping or hand-made groups as features (features are
  demographics and genres, linear), intervals on the gains, logistic results beyond
  an ROC plot. ^f11
- [method] (inferred) Our mapping: id = champion-role, response = its slope on an enemy
  trait, feature vector = kit-group memberships (0/1, several allowed) plus profile
  stats; deviation variance a = the remaining champion spread tau^2. Same structure as
  [[gelman-2006-multilevel-can-cant#^f2]], fitted by alternating "fit slopes with the
  prior, regress slopes on features" (^f6). ^f12
- [stats] (inferred) ^f8 predicts the size of our gain: the feature prior helps most
  when per-id data is thin and fades as ids fill in. At ~14k games per champion-role
  most slopes are thin (about 2 pp/sd detection), so a real but small gain is the
  expected outcome, concentrated in thin champions; the kit prior miss (docs/model.md
  "Armour tanks into AD", g real but tiny) is the features-weak case of ^f9. ^f13

## Read

- Abstract, 1, 2 (model, special cases), 3.1 (MCEM, ICM), 5 (experiments).

## Not read

- 3.2 logistic variational details, 4 dynamic model details, related work.
