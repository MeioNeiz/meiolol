---
title: 'Maystre, Kristof, Grossglauser 2019: Pairwise Comparisons with Flexible Time-Dynamics (KDD, kickscore)'
url: https://arxiv.org/pdf/1903.07746
kind: paper
commit: 
for: [frontier-dynamics]
looked: 2026-10-21
depth: docs (sections 1-2, 4.1, 5; Table 3)
relevance: high
grade: A/strong
description: KDD 2019 (EPFL); each competitor's strength is a Gaussian process in time with a composable kernel (constant, piecewise constant, Wiener, Matern, linear), inferred in linear time via its state-space form; kickscore package; measured vs constant, Elo and TrueSkill on a forward split
---
# Maystre, Kristof, Grossglauser 2019: Pairwise Comparisons with Flexible Time-Dynamics (KDD, kickscore)

Why: the general form of a dynamic champion rating. Which time kernel fits, how much it
gains over a static fit on future games, and whether it scales to our size.

## Assessment

- Evidence: A. KDD paper, reused as the benchmark by TrueSkill Through Time's JSS paper
  ([[trueskill-through-time-2025]]); public code (kickscore, gokick).
- Reasoning: strong. Forward protocol with hyperparameters picked on training data only;
  reports constant (static) as a baseline, which most rating papers omit.
- Interests: authors' own method.
- Weigh: datasets are 1-v-1 sports with strong, slowly drifting signal (tennis accuracy
  70%); our signal is far weaker, which shrinks any dynamic gain. Trust the ordering and
  the kernel menu; expect smaller gains.

## Findings

- [method/dynamics] Strength of each competitor is a Gaussian process over time; the
  kernel menu: constant, piecewise constant (jumps between periods, e.g. seasons),
  Wiener (Brownian), Matern (mean-reverting at a timescale), linear, and sums of these.
  Section 2 ^f1
  > Piecewise Constant Given a partition of R into disjoint intervals, this covariance is constant inside a partition and zero between partitions. It can, for instance, capture discontinuities across seasons
  > When ν = 1/2, it corresponds to a mean-reverting version of Brownian motion.
- [method/dynamics] A constant plus Matern kernel means strength that fluctuates around a
  fixed mean: the GP form of "stationary rating plus a decaying offset". Section 2 ^f2
  > the composite covariance k(t, t ′ )  ka (t, t ′ ) + kb (t, t ′ ) captures dynamics that fluctuate around a (non-zero) mean value
- [method/dynamics] Inference is linear in the number of observations by rewriting each
  GP as a state-space (Kalman) model; Elo, Glicko, TrueSkill and TTT are its Wiener
  special case. Sections 3, 5 ^f3
  > it is not necessary to restrict the dynamics to Brownian motion in order to get linear-time inference
  > Brownian motion is simply a special case of our model obtained by using the Wiener kernel
- [method] [stats] Protocol: first 70% train, last 30% test in time order, each test
  outcome predicted from all games up to the day before; hyperparameters from training
  data only. Section 4 ^f4
  > we use all the data (in both training and test sets) up to the day preceding t ∗
- [method/dynamics] [stats] Table 3 log loss, constant / Elo / TrueSkill / best GP:
  tennis 0.581 / 0.563 / 0.563 / 0.552 (affine + Wiener); NBA 0.692 / 0.634 / 0.634 /
  0.630; world football 0.929 / 0.950 / 0.937 / 0.926; chess small 1.030 / 1.035 /
  1.030 / 1.026 (football and NBA best with constant + Matern 1/2, chess with constant +
  Wiener). Over the best simple tracker the GP gains 0.004-0.011 nats; on football and
  chess Elo is worse than the static fit. Table 3 ^f5
  > different datasets are best modeled by using different covariance functions
- [method/dynamics] (inferred) Where the per-game signal is weak (football, chess),
  naive tracking (Elo) loses to a static fit and only a kernel with a constant component
  beats it, by 0.003-0.004 nats. Our draft signal is weaker still, so expect a dynamic
  champion model to gain only if it keeps a stationary part and shrinks the moving one.
  ^f6
- [method/dynamics] Fitted timescale of the moving part: 1.75 years for NBA teams, 7.47
  for tennis players; kernels and timescales are learnt by marginal likelihood, so the
  data choose how fast strength moves. Section 4.1 ^f7
  > the characteristic timescale of the dynamic covariance component is 1.75 and 7.47 years for basketball and tennis
- [method] Features: a competitor's score can be a sum of feature processes (e.g. a
  home advantage), so a team of five champion-role processes fits the same frame.
  Section 4.2 ^f8
  > Including this additional feature
- [method/dynamics] Checked, not there: no known change-point times given to the model
  (piecewise kernel is offered but not tested), no team-sum experiments, no weak-signal
  dataset like a draft. ^f9

## Read

- Abstract, sections 2 (model, kernels), 4.1 (protocol, Table 3), 5 (related work).

## Not read

- Section 3 inference details, appendix B hyperparameter tables (timescales per kernel).
