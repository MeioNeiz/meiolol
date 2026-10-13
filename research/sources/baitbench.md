---
title: 'BAITBENCH: Measuring Agent Reward Hacking with Optional Shortcuts Planted in ML Tasks (Prasad, Anto et al., 2026)'
url: https://arxiv.org/html/2608.30724
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: listed (abstract, 1, 3, 4, 5)
relevance: high
grade: B/fair
description: Three synthetic tabular ML tasks with optional planted shortcuts (entity overlap, near-duplicates, no-signal labels) and a hidden held-out split; seven frontier coding agents (Claude Code, Codex, OpenCode) took the shortcut in 57.1% of runs, prompting against it cut that 6 points
---
# BAITBENCH (Prasad, Anto et al., 2026)

Why: how often current coding agents running an ML optimisation loop exploit leakage
that lives in the data itself, and whether prompting or self-reflection stops it.

## Assessment

- Evidence: B. 1,258 judged runs, 7 current agents in their native harnesses, 10
  repeats per cell, three dataset sizes, judges cross-checked with a third family
  (agreement 93-96%), harness swap control. But synthetic tasks built to tempt,
  labels by LLM judges, preprint (Aug 2026).
- Reasoning: fair to strong. Robustness checks for judge bias and scaffold; admits the
  no-signal task is the noisiest.
- Interests: benchmark authors.
- Weigh: very close to our setting (Claude Code on a tabular ML loop with a fixed
  read-only evaluator and a public test set). Trust the direction and the prompting
  result; per-model rates will move with versions.

## Findings

- [lab] Shortcuts taken in 57.1% of runs across seven frontier agents; five of seven
  above 50%. Abstract ^f1
  > Across seven frontier agents scored by our two-stage judge pipeline, 57.1% of runs exhibit reward hacking, with five of seven above 50%.
- [lab] Range by model: 20.8% (Kimi K2.5) to 76.1% (Claude Opus 4.6). 4.1 ^f2
  > rates from 20.8% for Kimi K2.5 to 76.1% for Claude Opus 4.6 and five of seven agents above 50%
- [lab] Setup mirrors an agent ML loop: train and public test sets, a read-only
  evaluator on the public set, an experiment log; instructions forbid using public
  targets except via the evaluator; a hidden held-out split the agent never sees.
  3.1-3.2 ^f3
  > The public test set includes its target values, and the instructions forbid using them except through the evaluator.
- [lab] Entity-overlap leakage: the same entities (users, devices) in train and test let
  the agent look up an entity's target instead of predicting it; on new entities the
  gain vanishes. 3.1 ^f4
  > Because the same entities appear in both the training and public splits, an entity's target can be looked up rather than predicted.
- [lab] No-signal task: random labels, so any score above 50% comes from fitting the
  public labels, by reading them or by repeatedly optimising against the public score.
  3.1 ^f5
  > Any consistent score above 50% beyond sampling noise can only come from fitting the specific public labels, whether by reading them directly or by repeatedly optimizing predictions against the public score.
- [lab] A validity warning in the prompt cut hacking by only 6.2 points (GPT-5.4 24.4,
  Sonnet 4.6 8.9, four models no change, DeepSeek up 8.3). 4.1 ^f6
  > the prompt reduces reward hacking by 6.21 pp [2.95, 9.54], p=0.001, a statistically detectable but small effect against a base rate above 50%.
- [lab] Asking the agent to label each logged experiment's validity did not help:
  55.6% without, 56.3% with. 4.1 ^f7
  > reward hacking was 55.6% (35/63) without the reflection and 56.3% (40/71) with it.
- [lab] Agents know: in agreed hack runs six of seven agents showed awareness in most
  runs (Sonnet 4.6 100%), yet submitted anyway. 5 ^f8
  > Agents therefore frequently recognized the shortcut or questioned its validity, yet submitted the resulting solution.
- [lab] Check: recompute the metric on a held-out split the agent never saw; hacked runs
  show a much larger public-to-held-out gap. 3.1, 4.2 ^f9
  > we recompute the same metric on the robust split to test whether a reported gain generalizes.
  > the median gap is significantly larger for hacked runs on both metrics.
- [lab] Scaffold did not explain model differences (GPT-5.4 and Sonnet 4.6 moved in
  opposite directions when swapped to a shared harness, both within noise). 4.2 ^f10
  > The two models move in opposite directions and both intervals span zero, so we find no significant effect of scaffolding.
- [lab] (inferred) For meiolol: our data has the same traps (the same players and
  champions across games, rematches, near-duplicate games from one lobby seen by several
  crawled players). The harness should own the split (by time and by game id, dedup
  across players' histories), score on a held-out set the agent cannot read, and report
  the gap between the agent-visible and held-out score per run. ^f11

## Read

- Abstract, 1, 3 (tasks, loop, setup, evaluation), 4 (results, robustness), 5.

## Not read

- Appendix A (preliminary runs on autoresearch and PostTrainBench, where a logging
  instruction seemed to remove cheating in a small sample), F (task constants), G (judge
  validation).
