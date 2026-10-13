---
title: 'OpenML: networked science in machine learning (Vanschoren et al., SIGKDD Explorations 2013)'
url: https://arxiv.org/pdf/1407.7722
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (section 4.1 tasks, flows, runs; 6.1 studies)
relevance: high
grade: A/fair
description: The OpenML design paper; tasks fix data, splits and required outputs, runs upload per-instance predictions plus parameters and are scored server-side so every run compares
---
# OpenML: networked science in machine learning (Vanschoren et al., SIGKDD Explorations 2013)

Why: how a mature results store makes runs comparable and re-scorable (per-instance
predictions, fixed splits, server-side metrics), for meiolol's run records.

## Assessment

- Evidence: A. The canonical description of OpenML, running since 2013 with millions of
  runs; widely used in AutoML benchmarking (e.g. hyperband and cocktail papers in this
  store use OpenML datasets).
- Reasoning: fair. Describes the design and its purpose (objective comparison,
  verification) but not alternatives or costs (storage of all predictions).
- Interests: authors run the platform.
- Weigh: trust the run model; current platform details may have changed since 2013
  (see [[openml-runs-docs]] for the 2024 docs, which agree).

## Findings

- [lab] A task fixes the data, target, evaluation procedure and the exact split file,
  so results from different people compare objectively. Section 4.1.3 ^f1
  > the evaluation procedure (here: 10-fold cross-validation) and a file with the data splits for cross-validation. The latter ensures that results from different researchers can be objectively compared.
- [lab] The required output of a task is the predictions for every test instance;
  models and own evaluations are optional, and the server computes metrics itself.
  Section 4.1.3 ^f2
  > The required outputs for this task are the predictions for all test instances, and optionally, the models built and evaluations calculated by the user. However, OpenML will also compute a large range of evaluation measures on the server to ensure objective comparison.
- [lab] A run = outputs (predictions) + task id + flow id + parameter settings, plus a
  flag saying whether the settings are defaults, part of a sweep, or tuned. Section
  4.1.5 ^f3
  > They are submitted by uploading the required outputs (e.g. predictions) together with the task id, the flow id, and any parameter settings. There is also a flag that indicates whether these parameter settings are default values, part of a parameter sweep, or optimized internally.
- [lab] Runs keep per-fold distributions, not only the mean, plus confusion matrix
  and per-class results; runtime and hardware come from the user. Section 4.1.5 ^f4
  > OpenML stores the distribution of evaluations per fold (shown here as standard deviations), and details such as the complete confusion matrix and per-class results.
  > Runtimes and details on hardware are provided by the user.
- [lab] Flows (the code) are versioned by the server on every upload; ideally a flow
  takes a task id and produces the required outputs, so anyone can re-run it. Section
  4.1.4 ^f5
  > OpenML will again version each uploaded flow, while users can provide their own version name for reference.
  > Ideally, what is uploaded is software that takes a task id as
- [lab] Comparison is by task (one row per flow, one dot per run, switchable metric)
  and by flow across tasks, coloured by a parameter; plus an SQL endpoint for custom
  queries. Section 4.1.5 ^f6
  > Each row represents a flow and each dot represents the performance obtained in a specific run (for different parameter settings).
  > it provides an SQL endpoint so that users can (re)organize results as they wish by writing their own queries
- [lab] Studies group the runs behind one question or paper on one page. Section 6.1 ^f7
  > Such studies reference all runs of interest, either generated for this study or imported from other OpenML studies
- [lab] Checked, not there: no dedup of identical runs, and no protection against
  adaptive reuse of the shared splits (leaderboards are public). ^f8
- [lab] (inferred) For meiolol: an OpenML-style run would store per-game predicted
  probabilities for the eval set, keyed by game id, so a new metric or a paired test
  against any later run can be computed without retraining; and the eval split would
  be a pinned, hashed file shared by all runs. ^f9

## Read

- Sections 4.1.3 to 4.1.5, 6.1; skimmed the rest.

## Not read

- Sections on networked science motivation (1-3) and future work beyond studies.
