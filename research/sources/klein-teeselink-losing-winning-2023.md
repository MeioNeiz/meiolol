---
title: 'Klein Teeselink, van den Assem and van Dolder 2023: Does losing lead to winning? An empirical analysis for four sports'
url: https://papers.tinbergen.nl/20049.pdf
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (abstract, sections 1-2, tables 2 and 4)
relevance: medium
grade: A/strong
description: Management Science 2023 replication of Berger and Pope 2011 (slightly behind at half-time wins more); regression discontinuity on half-time score difference over four sports, meta-analysis finds no effect
---
# Klein Teeselink, van den Assem and van Dolder 2023: Does losing lead to winning? An empirical analysis for four sports

Why: the standard natural-experiment design for "does the state itself cause the result"
(Berger and Pope's half-time regression discontinuity), and its large replication. Read
instead of Berger and Pope 2011 because it states the original design and result and
tests it on far more data.

## Assessment

- Evidence: A. Management Science; four sports, many competitions, pre-registered-style
  extension to out-of-sample periods, robust bandwidths, meta-analysis.
- Reasoning: strong. States the identifying assumption, tests it (skill continuity at the
  cutoff), says where the design fails (low-scoring sports).
- Interests: academic; a replication, so its incentive leans to finding a null.
- Weigh: trust the design advice; the topic (motivation from trailing) is not ours, the
  method is.

## Findings

- [stats] Berger and Pope's original claim: NBA teams slightly behind at half-time were
  5.8 to 8.0 percentage points more likely to win than teams slightly ahead. Section 1 ^f1
  > BP find that National Basketball Association (NBA) teams that are slightly behind are between 5.8 and 8.0 percentage points more likely to win the match than those that are slightly ahead.
- [stats] It does not replicate: no effect in Australian football, American football or
  rugby, nor in NBA games outside BP's period; meta-analytic effect 1.2 points, not
  significant. Abstract, Section 1 ^f2
  > We extend their analysis to large samples of Australian football, American football, and rugby matches, but find no evidence of such an effect for these three sports.
  > the effect of trailing at half-time on winning the match is 1.2 percentage points. Statistically this estimate is not significant.
- [method] [stats] Design: regression discontinuity with the half-time score difference
  as running variable and cutoff zero; a jump in win rate at zero is causal if everything
  else is continuous there. Section 2 ^f3
  > Under the assumption that all other determinants of the outcome variable are continuous through this cutoff value, the variation in the treatment status is “as good as randomized by an experiment”
  > In our main analyses, the running variable is the score difference at half-time and the cutoff value is zero.
- [stats] Estimation: local-linear regression with the Calonico et al. (2014) MSE-optimal
  bandwidth, bias correction and triangular weights, plus robustness to other bandwidths.
  Section 2 ^f4
  > we use the local-linear method proposed by Calonico et al. (2014). This method selects the bandwidth that minimizes the mean squared error
- [stats] Validity check: re-run the same discontinuity with pre-match team skill as the
  outcome; it must show no jump. Section 2 ^f5
  > Our RDD requires that the skill difference between home and away teams is continuous at the cutoff.
- [stats] The design fails where one unit of score is decisive (low-scoring sports): the
  win curve is not linear even near the cutoff. Section 2 ^f6
  > for low-scoring sports, the assumption of linearity is violated even within a small bandwidth around the cutoff.
- [stats] (inferred) The lesson for event values: a strong published "effect of being in a
  state" shrank to nothing at scale and out of sample; per-event values from one patch
  or one sample need held-out checks before we print them. ^f7
- [method] (inferred) LoL designs in this spirit: (a) randomised events: drake elements and
  the soul type are random, so the win effect of a given soul or drake type (and its
  interaction with the comp) is identified without the "already ahead" bias, conditional
  on having taken it; (b) near-even states: compare who takes a contested objective when
  the gold lead at that minute is near zero, with gold lead as running variable, checking
  that draft win chance and rank are continuous across it. ^f8

## Read

- Abstract, sections 1-2, Australian and American football result tables

## Not read

- Basketball and rugby sections, meta-analysis details, online supplement
