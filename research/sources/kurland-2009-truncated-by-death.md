---
title: 'Kurland et al. 2009: Longitudinal data with follow-up truncated by death'
url: https://arxiv.org/pdf/1001.2697
kind: paper
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: docs (abstract, sections 4.1-4.4)
relevance: medium
grade: A/strong
description: Statistical Science 2009 review of how to summarise trajectories when subjects stop being observed for a reason tied to the response (death); unconditional vs partly conditional vs joint models
---
# Kurland et al. 2009: Longitudinal data with follow-up truncated by death

Why: games ending (surrender from 15 minutes) truncate the per-minute gold-diff series
in a way tied to the lead itself. What should a curve past 15 minutes mean?

## Assessment

- Evidence: A. Statistical Science 2009, four biostatisticians; the standard reference
  for "truncation by death" estimands.
- Reasoning: strong. Lays out each estimand, when it fits, and its bias.
- Interests: none.
- Weigh: medical setting, but the structure maps exactly: a game ending is a "death"
  after which gold diff is undefined, and ending is caused by the lead.

## Findings

- [stats] Partly conditional summaries are cross-sectional means among those still
  observed at each time point, describing the dynamic cohort of survivors, not
  individual trajectories. ^f1
  > Partly conditional models are serial cross-sectional snapshots of the response, reflecting the average response in survivors at a given timepoint rather than individual trajectories.
- [stats] Unconditional models (e.g. random effects on unbalanced data) implicitly
  impute values after death, describing an "immortal cohort"; valid only if deaths do
  not happen or are independent of the response. ^f2
  > Unconditional models, such as random effects models fit to unbalanced data, may implicitly impute data beyond the time of death.
  > An unconditional model, f (Yi ), is appropriate if deaths do not occur, are independent of the response process, or do not result in truncation
- [stats] Fully conditional models stratify trajectories by time of death. ^f3
  > Fully conditional models stratify the longitudinal response trajectory by time of death.
- [stats] Joint models describe the whole cohort at each time point with a combined
  outcome (alive and healthy), so data stay balanced. ^f4
  > Unlike the partly conditional model, the entire cohort is described at each timepoint, not only survivors.
- [stats] The choice must match the research aim. ^f5
  > Researchers using longitudinal data should consider which method of accommodating deaths is consistent with research aims, and use analysis methods accordingly.
- [stats] [method] (inferred) For matchup curves: the honest default is partly
  conditional (plain mean of games still running at minute t), labelled "games still
  running"; do not smooth or model across minutes in a way that imputes ended games
  (a smoother weighted by n_t is fine, it only borrows across minutes). A joint view
  for later minutes: share of games ended (by side) plus mean diff among running ones;
  or a fully conditional view: curves for games that reached 25 minutes. ^f6

## Read

- Abstract, Table 2 summary, sections 4.1-4.4

## Not read

- Section 5 (estimation via GEE, weighting), causal principal stratification parts
