---
title: Evaluating Sakana's AI Scientist for Autonomous Research (Beel, Kan, Baumgart, 2025)
url: https://arxiv.org/pdf/2502.14297
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: listed (section 2, recommendations skimmed)
relevance: medium
grade: C/fair
description: Hands-on evaluation of Sakana's AI Scientist v1 (gpt-4o) on a recommender-systems template (FunkSVD, MovieLens-100k); 5 of 12 ideas failed to run, 4 of 7 papers had wrong or hallucinated numbers, a baseline was not re-run
---
# Evaluating Sakana's AI Scientist (Beel, Kan, Baumgart, 2025)

Why: what failures an independent user finds in experiments run by an AI scientist
system, how often, and how they were caught.

## Assessment

- Evidence: C. One small case study: 12 ideas, 7 runs, 7 manuscripts, one dataset,
  gpt-4o, run by an undergraduate. Counts are exact but tiny; no repeats. Code public
  (code.isg.beel.org). arXiv v3, Oct 2025 (the abs page title now reads "Bold Claims,
  Mixed Results, and a Promising Future?").
- Reasoning: fair. Concrete examples, honest about the small setup; recommendations
  are speculative.
- Interests: academic; Beel's own e-fold idea was one of the test ideas.
- Weigh: trust the kinds of failures (parameter silently fixed, baseline not re-run,
  numbers in text not matching runs, self-review missed all of it); rates are anecdotal
  and for a 2024 model.

## Findings

- [lab] 5 of 12 ideas (42%) failed to run from unresolved coding errors; the agent
  cycled through flawed versions of the same code. 2.4 ^f1
  > It failed to execute five of twelve ideas due to unresolved coding errors, often cycling through flawed versions of the same code.
- [lab] Silent bug: meant to sweep e over 2 to 5 but kept it fixed at 2, invalidating
  the results. 2.4 ^f2
  > but erroneously kept
  > fixed at 2, invalidating results.
- [lab] Bad baseline: it did not re-run the k-fold baseline, so the new method looked
  better than is possible by design. 2.4 ^f3
  > It also failed to re-run the baseline (k-fold), making e-fold cross validation appear superior
- [lab] The system cannot judge its own results: misses methodological flaws and logical
  inconsistencies. 2.4 ^f4
  > the AI Scientist cannot critically assess its own results. It fails to detect methodological flaws or logical inconsistencies
- [lab] 4 of 7 manuscripts (57%) had incorrect or hallucinated numbers (hyperparameters
  and metrics differing from the runs); no confidence intervals or p-values anywhere.
  2.5 ^f5
  > Four of seven manuscripts (57%) contained incorrect or hallucinated numerical results, with discrepancies in hyperparameters and performance metrics.
  > no confidence intervals or p-values.
- [lab] Goal mismatch and noise read as a win: an "energy efficient" method claimed
  success from better RMSE and 116 to 115 s training time, with higher memory, no
  significance check. 2.5 ^f6
  > reduction of training time from 116 to 115 seconds – but increased memory usage.
- [lab] Its built-in reviewer caught none of the serious issues the humans found. 2.5 ^f7
  > the reviewer agent did not identify any of the truly serious issues that we highlighted in the sections above.
- [lab] What caught them: humans reading the code and runs, not the paper. 2.5 ^f8
  > an undergraduate submitting such work for a course project might still pass if the instructor does not scrutinize the code or experiments.
- [lab] Code edits by the coding assistant were often undocumented, so changes were hard
  to trace; they propose a structured record of setup, code version, data version and
  hyperparameters. 3.8 ^f9
  > Modifications made by its LLM-based coding assistant (Aider) are often undocumented, leading to reproducibility issues and making it hard to trace experimental changes.
- [lab] Cost context: $42 for 10 ideas, 7 runs and 7 papers (about $6 each), plus about
  3.5 hours of human effort per manuscript. 2.2 ^f10
  > amounted to only $42 USD — an average of $6 per manuscript.
- [lab] (inferred) For meiolol: the harness should run the baseline itself in the same
  invocation, log the effective config (not the intended one) per run, and generate any
  write-up numbers from records; an agent's self-review is not a check. ^f11

## Read

- Abstract, section 2 (setup, costs, ideas, experiments, manuscripts, reviews): fully.
- Section 3 recommendations: skimmed.

## Not read

- Section 4 onwards (ARI outlook, ethics): not about experiment failures.
- Their GitHub examples ("many more similar examples"): would give more failure cases.
