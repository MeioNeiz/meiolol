---
title: 'Ingram 2021: How to extend Elo, a Bayesian perspective (JQAS)'
url: https://www.degruyterbrill.com/document/doi/10.1515/jqas-2020-0066/pdf
kind: paper
commit: 
for: [frontier-dynamics]
looked: 2026-10-21
depth: skimmed (abstract and appendix D only; body paywalled)
relevance: medium
grade: B/fair
description: J. Quantitative Analysis in Sports 2021; Elo as steady-state Kalman filtering, extended to margin of victory, correlated skills across surfaces and tournament level; on 2018-19 ATP tennis 65.8% vs Elo 63.7% and Glicko 63.5%
---
# Ingram 2021: How to extend Elo, a Bayesian perspective (JQAS)

Why: a measured case where a richer state-space rating beats Elo and Glicko, and the
idea of correlated skills (one per context, linked) which maps to a champion's strength
per patch or per role.

## Assessment

- Evidence: B. Peer-reviewed, two ATP seasons held out; only the abstract and an
  appendix were readable (paywall).
- Reasoning: fair from the abstract; the Kalman link is shown in the appendix.
- Interests: author's own models.
- Weigh: the gain comes from extra structure (surface, margin, level), not from
  better time dynamics; the per-part split is not visible to us.

## Findings

- [method/dynamics] Elo is approximate Bayesian posterior mode estimation, and its
  approximations are justified as a steady-state Kalman filter; that view gives a recipe
  for extending it. Abstract ^f1
  > We provide a novel justification of the approximations made by linking Elo to steady-state Kalman filtering.
- [method/dynamics] Extensions derived this way: margin of victory, correlated skills
  across playing surfaces, and skill by tournament level. Abstract ^f2
  > We use the procedure to derive versions of Elo incorporating margins of victory, correlated skills across different playing surfaces, and differing skills by tournament level in tennis.
- [method/dynamics] [stats] On 2018 and 2019 men's tennis the full model reached 65.8%
  accuracy and mean log-likelihood -0.615 against Elo 63.7% (-0.632) and Glicko 63.5%
  (-0.633). Abstract ^f3
  > The best-performing model was able to predict matches with higher accuracy than both Elo and Glicko (65.8% compared to 63.7 and 63.5%, respectively) and a higher mean log-likelihood (−0.615 compared to −0.632 and −0.633, respectively)
- [method/dynamics] (inferred) Correlated skills per context are the state-space form of
  "shared strength plus shrunk offsets": a champion's patch-specific strengths as
  correlated components, so a patch's few games borrow from the champion's other
  patches by a learnt correlation instead of a hand-set L2. Glicko's variance tracking
  alone adds nothing over Elo here (63.5 vs 63.7%). ^f4
- [method/dynamics] Checked, not there (in what we could read): no gain split by
  extension, no team games. ^f5

## Read

- Abstract; appendix D (comparison with Glicko) skimmed.

## Not read

- Body (paywalled): model sections, per-extension results.
