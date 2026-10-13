---
title: 'ML-Master: Towards AI-for-AI via Integration of Exploration and Reasoning'
url: https://arxiv.org/html/2506.16499
kind: paper
commit:
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (sections 3-5)
relevance: medium
grade: C/weak
description: SJTU MLE agent (June 2025, v1): parallel MCTS over draft, debug, improve with stagnation pruning and parent-plus-sibling memory; 29.3% any medal on MLE-bench in 12 hours; no ablations
---
# ML-Master: Towards AI-for-AI via Integration of Exploration and Reasoning

Why: an early-2025 MLE-bench leader (its 2.0 is #7 on the leaderboard); what it did to
avoid wasted work and how it shares results across parallel branches.

## Assessment

- Evidence: C. Technical report, MLE-bench 75 tasks x 3 seeds with DeepSeek-R1, 12-hour
  budget on slightly weaker hardware than MLE-bench's; AIDE re-run with the same LLM.
  No ablation of any component.
- Reasoning: weak. Mechanisms are asserted to reduce hallucination and redundancy
  without measurement.
- Interests: authors' own system.
- Weigh: useful only for its concrete stop rules and parameters; nothing about what
  each mechanism is worth.

## Findings

- [lab] Stagnation pruning: a node is closed after more than 3 improve attempts that
  each fail to beat the best ancestor by a relative 0.001. `§3.1.1`, `§4.1` ^f1
  > If the number of failed improvements—i.e., those not exceeding a predefined threshold t—exceeds a tolerance level τimprove, the node is considered terminal
  > In our experiments, we use t\=0.001 and τimprove\=3.
- [lab] Debug budget: each debug sequence stops at depth 3 and a node is closed after 20
  consecutive debug operations. `§3.1.1`, `§4.1` ^f2
  > a debug depth constraint τdebug\=20 is enforced: nodes exceeding this limit are marked terminal. Additionally, each debug action sequence ends once it reaches a depth of 3
- [lab] Parallel search without duplicated work: workers take the top-k UCT children as
  separate entry points, and a finished worker picks the best child no other worker is
  exploring. Parallelism 3. `§3.1.2` ^f3
  > it returns to the root and selects the best available child node—based on UCT score—from among those not currently being explored by other threads.
- [lab] Memory is scoped, not the whole history: the parent node's insights and results
  plus sibling nodes at the same depth in other branches, so the model sees what is
  already being tried in parallel. `§3.2` ^f4
  > The inclusion of sibling-node information introduces contrastive signals, allowing the model to recognize and avoid producing reasoning paths that mirror those already explored in parallel
- [lab] Each expansion records validation metric, execution log and error diagnostics
  in the tree. `§3.2` ^f5
  > (1) performance metrics from model evaluation on validation data, (2) execution logs from code compilation and runtime, and (3) error diagnostics when solutions fail to execute properly
- [lab] Result: 29.3% any medal, 93.3% valid submissions on full MLE-bench in 12 hours
  (3 seeds). `§4.2` ^f6
  > ML-Master receives a medal in 29.3% of the machine learning tasks, with 17.3% achieving gold medals.
- [lab] Checked, not there: no ablation; the authors defer it. `§4.3` ^f7
  > We are actively conducting further ablation experiments on ML-Master and will report them in updated versions of this report.

## Read

- Sections 3, 4, 5.

## Not read

- ML-Master 2.0 (arXiv 2601.10402, "cognitive accumulation", warm-up on 407
  Kaggle competitions): the version on the leaderboard.
