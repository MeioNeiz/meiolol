---
title: 'Leckie 2019: Multiple membership multilevel models'
url: https://arxiv.org/pdf/1907.04148
kind: paper
commit: 
for: [hierarchical-comp-terms]
looked: 2026-10-18
depth: docs (whole entry, 10 short pages)
relevance: medium
grade: B/fair
description: Encyclopedia entry (SAGE Research Methods) by Bristol's Centre for Multilevel Modelling; units belonging to several higher-level units get a weighted sum of their random effects; group-level predictors enter as the same weighted average
---
# Leckie 2019: Multiple membership multilevel models

Why: a champion in two kit groups (Fiora: G1 and G5; Sivir: G3 and G6) is a multiple
membership structure; how the standard model handles it and what goes wrong if it
is ignored.

## Assessment

- Evidence: B. Short encyclopedia entry by an expert at the centre (Bristol CMM,
  MLwiN) that developed these models; points to Browne, Goldstein and Rasbash 2001
  as the canonical paper. No data or results of its own.
- Reasoning: fair. Clear definitions and the consequence of ignoring the structure
  (cited, not shown).
- Interests: mentions their own software (MLwiN).
- Weigh: trust the model form; the weighting choice is presented as a modelling
  decision for sensitivity analysis.

## Findings

- [stats] [method] Multiple membership: a lower-level unit belongs to several
  higher-level units at once (students with several teachers), unlike strict
  nesting. Introduction ^f1
  > Rather, lower-level units are nested within multiple higher-level units.
- [stats] Assigning each unit to just one of its groups underestimates the
  higher-level variance, i.e. the groups' importance (Chung and Beretvas 2012).
  Section 2 ^f2
  > simply assigning each lower-level unit to just one of their higher-level units has serious consequences as this will underestimate the degree of higher-level clustering
- [method] Model: y_i = b0 + b1 x_i + sum over the unit's groups of w_ji u_j + e_i,
  u_j ~ N(0, sigma_u^2); weights w (usually shares summing to 1) say how much the
  unit belongs to each group. Section 3-4 ^f3
  > Multiple membership weights are used to quantify this.
- [method] Weights are a modelling choice; try several as a sensitivity check.
  Section 3 ^f4
  > Other weighting schemes may equally be applied, and it can be interesting to explore a range of weighting schemes as part of a sensitivity analysis for the model.
- [method] Group-level predictors must respect the structure: enter the weighted
  average of the predictor over the unit's groups. Section 4 ^f5
  > we would derive, and enter into the model specification, a new teacher-level variable which is the weighted average of the teacher gender dummy variable across the series of teachers that have taught each student.
- [stats] Variance components per classification compare how much each level
  contributes, after the covariates. Section 4 ^f6
  > The magnitudes of the variance components may then be compared to make statements about the relative contribution of each classification to the variation in the response
- [stats] Software: few packages; MLwiN (ML and MCMC); for discrete outcomes with many
  classifications Bayesian MCMC is often the faster route there. Section 5 ^f7
  > For more complex models, for example, with discrete responses or many different classifications, Bayesian estimation will often be
  > considerably more computationally efficient than frequentist estimation.
- [stats] Checked, not there: varying slopes, fitting at scale, predictive checks. ^f8
- [method] (inferred) Two readings for our kit groups. Weights summing to 1 (the
  standard MM form) say "a champion in two groups is half of each"; weights of 1 each
  say kit traits add (auto-attack punisher and true damage both apply). Our groups
  are different traits into different enemy traits (G1 into aa_build, G5 into tank),
  so membership of two groups touches two different slopes and does not overlap at
  all; the MM question only arises for two groups on the same enemy trait (G4 and G5
  both into tank; G6 and G11 both into AP share), where additive weights of 1 are
  the natural default and ^f4 says to check the alternative. ^f9
- [stats] (inferred) ^f2 applies to how champgroups estimates a group effect from
  member cells: a champion counted in two same-trait groups must be in both, or
  each group's estimate absorbs the other's. ^f10

## Read

- Whole entry.

## Not read

- Browne, Goldstein, Rasbash 2001 (MMMC models, Statistical Modelling 1, 103-124);
  Fielding and Goldstein 2006 review (RR791).
