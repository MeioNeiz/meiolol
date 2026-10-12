---
title: 'AlphaEvolve: evolutionary coding agent with a program database and evaluators'
url: https://arxiv.org/pdf/2506.13131
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: docs (sections 1, 2, 3.3 in part, 4, 6)
relevance: high
grade: B/fair
description: Google DeepMind white paper (June 2025); LLM ensemble proposes diffs to marked code blocks, evaluators score them, a MAP-Elites plus islands database keeps the population
---
# AlphaEvolve: evolutionary coding agent with a program database and evaluators

Why: how an evolutionary LLM system keeps a population of programs, picks parents, keeps
diversity and evaluates candidates; what that costs.

## Assessment

- Evidence: B. Google DeepMind, results checked externally in part (math constructions
  provable, fleet scheduling measured after rollout). Closed source; the database
  algorithm is described in one paragraph, no parameters.
- Reasoning: fair. Ablations on two tasks (three seeds each) show each component helps,
  but only on problems with exact, cheap-to-check scores; says plainly that it needs an
  automated evaluator.
- Interests: vendor showcase for Gemini.
- Weigh: trust the architecture (database, cascade, multi-metric, ensemble) as the
  reference evolutionary design. Its regime is thousands of LLM samples on noiseless
  metrics; ours is hundreds of runs on a noisy AUC, so the search needs care with
  selection on noise. Open-source clones (OpenEvolve, ShinkaEvolve) give the missing
  database details.

## Findings

- [lab] Loop: sample a parent and inspirations from the database, build a prompt, LLM
  emits a diff, apply, evaluate, add child and scores back to the database.
  `figure 2` ^f1
  > parent_program, inspirations = database.sample()
  > database.add(child_program, results)
- [lab] The user supplies an `evaluate` function returning a dict of scalar metrics
  (maximised), and marks code blocks the system may evolve; the rest is fixed
  skeleton. `2.1` ^f2
  > This mechanism takes the form of a function ℎ mapping a solution to a set of scalar evaluation metrics.
  > simply by adding special markers (# EVOLVE-BLOCK-START and # EVOLVE-BLOCK-END) as comments into the code.
- [lab] Memory of past experiments is the program database: every solution with its
  scores and outputs, meant to resurface old ideas while keeping diversity; the
  algorithm mixes MAP-Elites and island models. `2.5` ^f3
  > These solutions are stored in an evolutionary database, the primary goal of which is to optimally resurface previously explored ideas in future generations.
  > the evolutionary database implements an algorithm that is inspired by a combination of the MAP elites algorithm [74] and island-based population models
- [lab] Prompts carry several past solutions with their scores and outputs, plus
  optional human context (literature, equations), randomised template wording, and
  LLM-written meta prompts co-evolved in their own database. `2.2` ^f4
  > This prompt comprises multiple previously discovered solutions sampled from the program database
  > Meta prompt evolution: instructions and context suggested by the LLM itself in an additional prompt-generation step
- [lab] Evaluation cascade: cheap small-scale tests first, harder stages only for
  candidates that pass, to prune bad ideas early. `2.4` ^f5
  > new solutions are evaluated on the next stage only if they achieve sufficiently promising results in all earlier stages.
- [lab] Qualities hard to code (such as simplicity) can be scored by an LLM and added
  to the metrics, or used to discard solutions. `2.4` ^f6
  > These properties can be graded using separate LLM calls and added to the dictionary of scores to steer evolution
- [lab] Optimising several metrics at once often improves the single target metric too,
  which they attribute to more diverse parents in prompts. `2.4` ^f7
  > we find that even if one metric is of particular interest, optimizing for multiple metrics often improves results for the single target metric.
- [lab] Model mix: a fast cheap model for volume, a strong model for occasional better
  ideas (Gemini 2.0 Flash and Pro). `2.3` ^f8
  > Gemini 2.0 Flash, with its lower latency, enables a higher rate of candidate generation
  > Gemini 2.0 Pro, possessing greater capabilities, provides occasional, higher-quality suggestions
- [lab] Cost regime: thousands of LLM samples suffice (FunSearch needed millions); an
  evaluation can take up to about 100 compute-hours if parallelised. `table 1, 2.4` ^f9
  > thousands of LLM samples suffice
  > it feasible to spend on the order of 100 compute-hours to evaluate any new solution.
- [lab] Pipeline is asynchronous and tuned for throughput: as many ideas proposed and
  evaluated as the budget allows, not fast single runs. `2.6` ^f10
  > The entire pipeline is optimized for throughput (rather than the speed of any one particular computation)
- [lab] Ablation: removing evolution (always prompting from the initial program),
  removing prompt context, or using only a small LLM each did clearly worse, on two
  math tasks, three seeds each. `4` ^f11
  > we consider an alternative approach, which repeatedly feeds the same initial program to the language model.
  > each of the components is responsible for a significant improvement in the results.
- [lab] [method] Where scores come from data, they split train and held-out sets: the
  scheduling heuristic was checked on unseen recent workloads, kernel shapes split in
  half for search and evaluation. `3.3` ^f12
  > We measure the performance of AlphaEvolve’s heuristic function on an unseen test dataset of recent workloads and capacity to ensure generalization.
  > Half of these input shapes form the training set, providing the optimization targets during the evolutionary process.
- [lab] Stated main limit: needs an automated evaluator; LLM-judged ideas are possible
  but not what it is tuned for. `6` ^f13
  > The main limitation of AlphaEvolve is that it handles problems for which it is possible to devise an automated evaluator.
- [lab] Checked, not there: no database parameters (island count, migration, MAP-Elites
  features), no dollar or token cost per run, no analysis or write-up step: output is
  the best program plus scores. ^f14

## Read

- Sections 1, 2 (all), 4 (ablations), 6 (discussion); 3.3 scheduling and kernel parts.

## Not read

- Section 3.1-3.2 and appendices A-B (math results): outcomes, not method.
