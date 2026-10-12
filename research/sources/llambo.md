---
title: 'Liu et al. 2024: Large Language Models to Enhance Bayesian Optimization (LLAMBO)'
url: https://arxiv.org/pdf/2402.03921
kind: paper
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: skimmed (abstract, sections 1, 2, 4, 5 and 6 insights, 7, 8, appendix E.2)
relevance: high
grade: B/fair
description: ICLR 2024 paper putting an LLM inside Bayesian optimisation (warm start, surrogate, candidate sampler) for hyperparameter tuning; gains are largest in the first few trials
---
# Liu et al. 2024: Large Language Models to Enhance Bayesian Optimization (LLAMBO)

Why: where in a tuning loop an LLM beats a classical optimiser, and at what budget, so
we know which choices to give meiolol's lab agent and which to give a BO routine.

## Assessment

- Evidence: B. ICLR 2024, Cambridge (van der Schaar lab); 74 tasks from Bayesmark and
  HPOBench, end-to-end on 50 tasks x 5 seeds x 25 trials, vs GP, SMAC3, Optuna TPE,
  SKOpt; includes private and synthetic datasets against memorisation. One LLM only
  (GPT-3.5); some ablations on a single seed.
- Reasoning: fair. Explains each component and ablates it; admits cost and low
  dimensionality; does not price the LLM calls against just running more trials.
- Interests: authors' own method; baselines run by them.
- Weigh: trust "helps most when observations are few"; discount any claim about large
  budgets or high-dimensional spaces (not tested). Search space is numeric
  hyperparameters, not code or model structure.

## Findings

- [lab] [method] An LLM helps BO through zero-shot warm starting, a surrogate model and
  candidate sampling, and the gains are largest early, while observations are sparse.
  Abstract ^f1
  > LLAMBO is effective at zero-shot warmstarting, and enhances surrogate modeling and candidate sampling, especially in the early stages of search when observations are sparse.
- [lab] Works in context, no fine-tuning; modular, so one component can be plugged into
  an existing BO framework. Abstract ^f2
  > Our approach is performed in context and does not require LLM finetuning. Additionally, it is modular by design, allowing individual components to be integrated into existing BO frameworks
- [lab] The prompt carries a problem description (model card, data card), the
  optimisation history as few-shot examples, and task instructions. Section 2.2 ^f3
  > The history contains the sequence of points and scores observed during the optimization process, captured in Dn . The observed points are provided as few-shot examples
- [lab] Warm start: describing the dataset helps, most in the first 5 trials, and the
  early lead is kept; but LLM starting points are less diverse than random ones.
  Section 4 ^f4
  > providing additional information about the dataset improves the search performance when warmstarting for both partial context and full context. This is particularly prominent in the early stages of the search (i.e. trials < 5).
  > their generalized variance is typically lower than that of randomly initialized points.
- [lab] Surrogate: LLM predicts better than GP and SMAC at few points, but a GP gives
  the best uncertainty estimates; the LLM only approaches it as n grows. Section 5 ^f5
  > GPs, with their probabilistic grounding, produce the best uncertainty estimates, particularly in LPD and empirical coverage.
- [lab] Sampling: conditioning on a target score gives good candidates but loses
  diversity; an exploration knob trades the two. Section 6 ^f6
  > Sampling candidate points by direct conditioning on desired target value can generate highquality points, although this can sacrifice diversity among sampled points.
- [lab] Budget tested: 25 trials per search, 5 random starting points shared by all
  methods; LLAMBO best overall, mainly early. Section 7 ^f7
  > for each task, we executed 5 seeded searches, each with 25 trials.
  > LLAMBO excels in earlier stages of the search, when fewer observations are available.
- [lab] Limits: much higher compute per step than classical BO; authors suggest using
  the LLM only early in the search or only one component; tested on low-dimensional
  tuning with one LLM. Section 8 ^f8
  > performing inference through LLMs incurs a much larger computational footprint than traditional BO algorithms.
  > For instance, deploying LLAMBO in earlier stages of the search, or only leveraging an individual component to complement existing BO frameworks.
  > Our study has primarily focused on HPT tasks, which are relatively low-dimensional.
- [lab] (inferred) For meiolol: the LLM's edge is prior knowledge when few runs exist
  (first ideas, warm-start values, structure); once a numeric knob has ~10+ evaluated
  points, a classical surrogate with calibrated uncertainty is the safer chooser. ^f9
- [lab] Checked, not there (in sections read): no comparison against spending the LLM's
  cost on more classical trials, and no study of noisy objectives. ^f10

## Read

- Abstract, sections 1, 2, 4 insights, 5 insights, 6 insights, 7, 8; appendix E.2

## Not read

- Section 3 related work, appendix C prompts (useful if we ever prompt for warm starts),
  appendix E per-task results and HPOBench results
