---
title: 'PracTools vignette: Design effects and effective sample size'
url: https://cran.r-universe.dev/PracTools/doc/Design-effects.html
kind: docs
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: listed (whole vignette)
relevance: medium
grade: B/fair
description: Vignette of the PracTools R package (Valliant et al., survey sampling) on Kish's weighting design effect, the clustering design effect 1 + rho(n-1), and effective sample size
---
# PracTools vignette: Design effects and effective sample size

Why: two of our problems are textbook survey-sampling ones: decay weights by patch age
shrink the effective n (Kish), and many games from the same player are a cluster
(design effect 1 + rho(m - 1)).

## Assessment

- Evidence: B. Vignette for a CRAN package by survey statisticians (Valliant, Dever,
  Kreuter textbook authors); restates Kish 1965, the canonical source.
- Reasoning: fair. States formulas and their assumptions and limits.
- Interests: none.
- Weigh: formulas are standard; the vignette's own caveat that Kish's formula assumes
  a simple design applies to us too (fine as a display heuristic).

## Findings

- [stats] Effective sample size is n divided by the design effect: the simple random
  sample size giving the same variance. ^f1
  > the effective sample size is the size of an SRS that would yield the same variance as that produced by the complex design.
- [stats] Kish's weighting design effect is 1 + relvariance of the weights, i.e.
  n_eff = (sum w)^2 / sum w^2; easy but derived under restrictive assumptions. ^f2
  > The most common formula for the weighting component of the design effect is the one proposed by Kish (1965)
  > Kish’s formula only accounts for an increase in variance due to having unequal weights and is derived under some extremely restrictive assumptions.
- [stats] Clustering increases the design effect with within-cluster homogeneity rho
  and cluster size: deff = 1 + rho (n-bar - 1). ^f3
  > As can be seen, as the homogeneity 𝜌 increases and as cluster sample size 𝑛∗ℎ increases, the design effect increases.
  > which comes from the variance for an estimated mean or total.
- [stats] Even a small positive rho matters when clusters are big. ^f4
  > Also note that even a small positive roh can have a big impact on the design effect if ¯𝑛 is large.
- [stats] [method] (inferred) For matchup curves: with patch-decay weights w_g, use
  n_eff = (sum w)^2 / sum w^2 in the shrinkage weight and the "n" shown to users; with
  players contributing m games each, n_eff ~ n / (1 + rho (m-bar - 1)). Estimate rho
  once per role from data (variance of player means vs within-player variance); if
  one-tricks are rare in a matchup, deff is near 1 and can be ignored. ^f5

## Read

- Whole vignette

## Not read

- Spencer and Chen-Rust formulas in detail
