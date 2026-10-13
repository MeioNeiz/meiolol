---
title: 'MLE-STAR: Machine Learning Engineering Agent via Search and Targeted Refinement'
url: https://arxiv.org/html/2506.15692
kind: paper
commit:
for: [agent-ml-practice, smart-experiment-search]
looked: 2026-10-13
depth: docs (sections 1-6, appendices A, C, F, G, H)
relevance: high
grade: B/fair
description: Google Cloud's MLE agent (2025): web-searched starting models, ablation-chosen code block refined in an inner loop, ensemble planner, leakage and data-usage checker agents; 64% medals on MLE-bench Lite
---
# MLE-STAR: Machine Learning Engineering Agent via Search and Targeted Refinement

Why: which mechanisms (ablation-guided targeting, checker agents, debugging, final
selection) made an MLE agent better, and what its ablations show each is worth.

## Assessment

- Evidence: B. Google Cloud AI Research and KAIST, 2025; 22 MLE-bench Lite tasks x 3
  seeds, Gemini-2.0-Flash; baselines taken from MLE-bench's repo. Only the ensemble step
  has a controlled ablation over all tasks; the leakage and data-usage checkers are shown
  on one competition each; the ablation-guided targeting is never ablated on its own
  (web-search start and targeting are confounded in the AIDE comparison).
- Reasoning: fair. Explains each module with a failure example; no cost in tokens, no
  per-module ablation table.
- Interests: authors' own method against AIDE; Gemini vendor.
- Weigh: trust the mechanisms as designs and the ensemble table; treat the checker
  benefits as anecdotes; the headline gain mixes better starting models with targeting.

## Findings

- [lab] Two nested loops: the outer loop picks one code block via an ablation study, the
  inner loop refines only that block with several plans before moving on. `§3` ^f1
  > The outer loop targets one code block, which corresponds to the specific ML component extracted through an ablation study. The inner loop iteratively refines only this block until the outer loop moves to the next target
- [lab] The agent writes and runs an ablation script that disables or varies components
  of the current solution; summaries of earlier ablations are fed back so later steps
  explore other parts. `§3.2` ^f2
  > This script creates variations of st by modifying or disabling specific components. To encourage exploration of different pipeline parts across iterations, 𝒜𝚊𝚋𝚕 receives the summaries of previous ablation studies
- [lab] Raw ablation output is noisy (training logs), so a separate summariser parses it
  into a short per-component impact summary before the next agent sees it. `App. A.5` ^f3
  > Since rt often contains content unrelated to the ablation (for example, printing the loss value across training epochs), a summarization module 𝒜𝚜𝚞𝚖𝚖𝚊𝚛𝚒𝚣𝚎 is utilized
- [lab] The extractor picks the block with the largest measured impact and is given the
  list of blocks already refined, to prioritise untried ones. `§3.2` ^f4
  > To prioritize refinement of blocks not previously targeted, the set of already refined blocks {ci}i\=0t−1 is provided as context
- [lab] Inner loop memory is the list of (plan, score) pairs tried on this block; a
  candidate replaces the solution only if it improves the score. `§3.2` ^f5
  > The solution for the next outer step, st+1, is updated to stk∗ only if an improvement over st is found.
- [lab] (claim) Most of the gain comes in the first refinement steps, which the authors
  credit to the ablation targeting the most influential blocks first; no ablation
  without targeting is reported. `§5` ^f6
  > Significantly, the magnitude of improvement is notable in the early refinement stages. We posit that this stems from MLE-STAR’s ablation study module
- [lab] Checked, not there: no run of MLE-STAR with random or LLM-chosen blocks instead
  of ablation-chosen ones, so the targeting mechanism's own worth is unmeasured. ^f7
- [lab] Debugging: on a traceback, a debugger agent retries up to a fixed number of
  rounds, then falls back to the last version known to run. `§3.4` ^f8
  > If the bug cannot be resolved, MLE-STAR proceeds to the next task using the latest version of the script that is known to be executable.
- [lab] Leakage checker: before every execution, an agent extracts only the
  preprocessing block, judges leakage risk and rewrites it if needed. `§3.4` ^f9
  > All generated solutions are passed through a data leakage checker, 𝒜𝚕𝚎𝚊𝚔𝚊𝚐𝚎, prior to their execution for evaluation.
  > Recognizing that full-script analysis can be inefficient for lengthy code, we adopt a targeted approach.
- [lab] Without the leakage checker, one competition's validation accuracy rose 0.8188
  to 0.8677 while test fell 0.8033 to 0.7343: the agent engineered a feature from the
  target. Single example, Table 5. `§5` ^f10
  > In this example, the validation accuracy (_i.e._, the target objective) improves, but the test accuracy drops significantly. This is attributed to the LLM performing feature engineering using the target variable Transported
- [lab] Data usage checker: the agent ignored provided data files (loaded only
  train.csv); a checker comparing the script to the task description fixed it, RMSLE
  0.0591 to 0.0559 on one competition (Table 6). `§3.4`, `§5` ^f11
  > We observe that LLM-generated scripts sometimes neglect using provided data sources, focusing solely on simple formats like CSVs
- [lab] Final selection: combining two parallel solutions with an LLM-planned ensemble,
  refined over five rounds, beats picking the best validation score. Table 4 (any medal
  %, mean ± se, 3 seeds): none 37.9 ± 6.0, best-of-N 42.4 ± 6.1, average ensemble
  43.9 ± 6.2, theirs 43.9 ± 6.2 (gold 30.3 vs 28.8 best-of-N); within one standard
  error of each other. `§4.2` ^f12
  > While simpler strategies, such as selecting the solution with the best validation score or averaging final submissions, also offer benefits, MLE-STAR shows stronger effectiveness
- [lab] Budget: 4 retrieved models, 4 outer x 4 inner loops, 2 parallel solutions, 5
  ensemble rounds; 14.1 hours a solution on average against AIDE's 15.4, both capped at
  24 hours. `App. F` ^f13
  > MLE-STAR requires 14.1 hours to generate a single final solution, on average across 22 tasks and all three random trials
- [lab] Starting point matters: the LLM alone picks stale models (logistic regression for
  text, ResNet for images); web search for current models gave 37% medals on image tasks
  against AIDE's 26%. `§3.1`, `§5` ^f14
  > relying solely on an LLM for model suggestions can lead to suboptimal choices
- [lab] Human steering hook: a person can replace the ablation summary with written
  instructions to choose the target block, or add a model description. `§5` ^f15
  > In addition, users can also specify the target code blocks by replacing the ablation summary with manually written instructions.
- [lab] Headline: any-medal rate on MLE-bench Lite rose from AIDE's 25.8% to 43.9% with
  the same Gemini-2.0-Flash; over 60% with Gemini-2.5-Pro. `§4.1` ^f16
  > MLE-STAR improves AIDE’s any medal achieving rates in Kaggle competitions from 25.8% to 43.9%
- [lab] (inferred) For meiolol: an ablation run (drop or vary each feature group / net
  block on the current best, one batch) is a cheap way to choose what the agent edits
  next, and a fixed pre-run leakage check on the data-prep code is cheap insurance; the
  ensemble result says final choice by best validation leaves little on the table
  compared with averaging, at these sample sizes. ^f17

## Read

- Sections 1-6 whole; Table 4 (ensemble ablation) from the HTML table.
- Appendix A text (prompts are images, not in the snapshot), C, F, G, H.

## Not read

- Prompt figures 12-22 (images): exact debugger and checker prompts; the released code
  (github.com/google/adk-samples, machine-learning-engineering) if prompts matter.
- Appendix B algorithms in detail.
