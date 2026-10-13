---
title: 'Landfried and Mocskos 2025: TrueSkill Through Time, reliable initial skill estimates and historical comparability (JSS)'
url: https://www.jstatsoft.org/index.php/jss/article/view/v112i06/4680
kind: paper
commit: 
for: [gnn-match-outcome]
looked: 2026-10-13
depth: docs (abstract, sections 1-2, model comparison and Table 1, message passing appendix skimmed)
relevance: medium
grade: A/strong
description: Journal of Statistical Software 2025; TrueSkill Through Time (Dangauthier, Herbrich, Minka, Graepel 2007) as Julia, Python and R packages; message passing over the whole player-game graph, forward and backward; on forward prediction it barely beats TrueSkill, the big gain is hindsight
---
# Landfried and Mocskos 2025: TrueSkill Through Time, reliable initial skill estimates and historical comparability (JSS)

Why: (c) the classical "message passing over the player graph" model. Does propagating
information through who-played-whom give better ratings for players with few games,
and does that help forecasting?

## Assessment

- Evidence: A. JSS paper with packages on CRAN and PyPI; the model is the 2007 MSR
  TrueSkill Through Time; comparison reuses Maystre et al. 2019's four datasets and
  70/30 forward protocol (Elo, TrueSkill, KickScore, constant).
- Reasoning: strong. Separates prior (forward) prediction from hindsight smoothing
  (LOOCV) and says only the first is fair for model comparison.
- Interests: authors maintain the packages.
- Weigh: trust the forward numbers; the "reliable initial estimates" claim is about
  estimating a player's early skill in hindsight, using their later games.

## Findings

- [method] TTT propagates information through one causal network of all games and
  players in both directions; Elo and TrueSkill only forward. Abstract ^f1
  > propagate information in only one direction, from the past to the future, preventing them from obtaining reliable initial estimates
  > the model TrueSkill Through Time (TTT) propagates all historical information throughout a single causal network
- [method] Inference is message passing (sum-product, expectation propagation) with
  repeated forward and backward sweeps until convergence; cheap even for millions of
  nodes. Abstract, appendix ^f2
  > The general idea is to repeatedly update forward and backward all messages in the shortest
- [method] Forward protocol: first 70% to tune hyperparameters, last 30% to evaluate,
  each game predicted from all games up to the day before. Section 3 ^f3
  > To predict the outcome of one observation at time t, we use all the data up to the day preceding t (in both training and test sets).
- [method] Table 1, geometric mean probability of the observed result on the forward
  test (TrueSkill vs TTT): tennis (186,361 test games) 0.5722 vs 0.5760; basketball
  0.5316 vs 0.5318; chess 0.3580 vs 0.3584; football 0.3921 vs 0.3963. Elo tennis
  0.5695, KickScore 0.5758. Per game, the gains over TrueSkill are 0.0002 to 0.004. ^f4
  > The TTT model outperforms KickScore in the tennis database by 93 orders of magnitude
- [method] The large gain is hindsight: using all other games including later ones
  (LOOCV) lifts tennis to 0.5908, which the authors exclude from model comparison.
  Section 3, Table 1 ^f5
  > Although we do not use these offline predictions to compare models (Bayes Factor), it is interesting to note that incorporating all historical information into the TTT model improves its estimates by hundreds of orders of magnitude.
- [method] Simulation: a new player joining a known community is tracked well, but by
  smoothing their whole learning curve after the fact. Section 2.3 ^f6
  > This example exhibits that TrueSkill Through Time can follow the evolution of a new player’s skill.
- [method] Checked, not there: no team-game benchmark with ad hoc teammates (the
  examples are 1v1 and fixed teams), no cold-start breakdown on the forward test, no
  extra features beyond results. ^f7
- [method] (inferred) For us: message passing over the player graph is what a jointly
  fitted logistic player-term model already approximates; on a forward split TTT beat
  TrueSkill by under 0.4 points of probability per game. Smoothing that uses a player's
  later games is a leak for held-out prediction; only the forward version is fair. For
  a player with no earlier game it gives the prior, like everything else. ^f8

## Read

- Abstract, sections 1-2 (model, examples, skill evolution, ATP), model comparison
  section and Table 1; appendix message passing skimmed

## Not read

- Code walkthroughs in full, multi-dimensional skill section, Julia/R specifics
