---
title: 'Lim, Hastie 2015: Learning interactions through hierarchical group-lasso regularization (glinternet)'
url: https://arxiv.org/pdf/1308.2719
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-2.4, 8 skimmed)
relevance: medium
grade: A/fair
description: JCGS 2015 (Stanford); pairwise interactions of categorical variables with any number of levels, each whole interaction (all level pairs) one group in a group lasso, overlapped so strong hierarchy holds; optional screening by depth-2 boosting; R package glinternet; simulations on FDR vs number found
---
# Lim, Hastie 2015: glinternet

Why: the standard penalised way to choose which categorical x categorical interactions
(seat pairs) exist, with hierarchy, as a baseline for any black-box detector.

## Assessment

- Evidence: A. JCGS 2015, Hastie; CRAN package maintained for a decade; simulations
  and a GWAS.
- Reasoning: fair. Clear derivation; selection is by whole variable pairs, not level
  pairs, and the FDR shown is empirical in simulation, not controlled.
- Interests: authors' package.
- Weigh: matches our block structure; our per-block empirical Bayes variance is the
  ridge cousin of this group selection.

## Findings

- [method] [stats] Strong hierarchy: an interaction enters only with both main effects;
  motivated by categorical variables with arbitrary numbers of levels. Abstract ^f1
  > We introduce a method for learning pairwise interactions in a manner that satisfies strong hierarchy: whenever an interaction is estimated to be nonzero, both its associated main effects are also included in the model.
- [method] Each categorical interaction's indicator matrix is one group: the group lasso
  keeps or drops all its level pairs together. Section 2.4 ^f2
  > In our application, each indicator matrix X will represent a group.
  > If an estimate β̂i is nonzero, then all its components are usually nonzero.
- [method] Two phases: screen candidates (depth-2 boosting picks an interaction only
  after a split on its main effect), then group lasso on the candidates with lambda by
  cross-validation or a stop after a set number of interactions. Section 1 ^f3
  > boosting with depth-2 trees naturally gives rise to an interaction selection process that enforces hierarchy
- [method] No identifiability constraints on mains and interactions are needed. Abstract ^f4
  > Our approach allows us to dispense with explicitly applying constraints on the main effects and interactions for identifiability
- [stats] Simulation: 500 three-level categoricals, 800 observations, 10 true mains and 10
  interactions at signal-to-noise 1; FDR plotted against interactions found; comparable
  to hierNet, better when the truth is anti-hierarchical. Section 1.1, 8 ^f5
  > glinternet is competitive with hierNet when the truth obeys strong or weak hierarchy, and does better when the truth is anti-hierarchical.
- [method] Checked, not there: selection within a categorical pair (which level pairs),
  error-controlled FDR, low-rank structure for many levels. ^f6
- [method] (inferred) For us: one group per role pair (35 blocks of about 170 x 170
  champion cells) gives "does this role pair interact at all", which the shipped
  per-block empirical Bayes variance already answers continuously; glinternet adds a
  sparse path and hierarchy, not champion-level pairs. ^f7

## Read

- Abstract, 1, 2.1-2.4, comparison section skimmed.

## Not read

- Screening by strong rules (5), GWAS application, proofs.
