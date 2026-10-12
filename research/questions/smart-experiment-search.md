---
status: answered
parent: llm-experiment-agent
priority: soon
area: stats
tags: [lab, method, stats]
description: How should an experiment agent choose what to try next, instead of brute-forcing many runs?
---
# How should an experiment agent choose what to try next, instead of brute-forcing many runs?

Feeds: docs/lab-agent.md search strategy (how the agent picks the next experiment)

## Answer

Don't search blindly: work in Box's loop. Diagnose where the current model is wrong,
expand the model to fix that named misfit, and keep the sequence of models (C1, C2). In
a controlled test, LLM-proposed features helped mainly through domain context; their
keep rule was not a statistical test (C3). Before running an idea, screen it
cheaply: a score test needs only the current fit and gives a z for a candidate term in
milliseconds (C4). Also set the smallest effect worth detecting, and park ideas whose
plausible gain is below what the data can show rather than run and "refute" them (C5).
Never retest the same idea on more data until it passes (C6).

Split the work. The LLM chooses structure, hypotheses and warm starts, where it helps
most at small run counts. A classical routine (BO/TPE, or a small grid) tunes the
numbers inside a fixed structure, where surrogates are better calibrated (C7). Cheap
fidelities (data subsets) only help when they rank candidates like full runs. With our
small data and close scores they should catch crashes and clear losers, not rank
near-ties (C8, C9). Learning curves on nested subsets separate "needs more data" from
"no effect" for under two runs (C10). Fancy schedulers (bandits, the agent choosing
everything) show no consistent gain over fixed rules rotating action types with the LLM
choosing the concrete experiment (C11).

## Claims

- C1: Expand a model in response to a named failure, new data or computation trouble, not blind search. for: [[bayesian-workflow-2020#^f3]]
- C2: Held-out errors grouped by a covariate the model lacks expose misfit; per-item held-out scores work as residuals. for: [[bayesian-workflow-2020#^f7]], [[blei-2014-box-loop#^f3]]
- C3: CAAFE's LLM features gained mostly from domain context (hiding names cut 0.822 to 0.8 AUROC); its keep rule is no statistical test. for: [[caafe-2023#^f1]], [[caafe-2023#^f10]], [[caafe-2023#^f5]]
- C4: A score test needs only the current model: candidate (residualised) dotted with residuals gives a z without refitting. for: [[statmod-glm-scoretest#^f1]], [[statmod-glm-scoretest#^f4]]
- C5: Fix the smallest effect worth detecting before the experiment; if it needs more games than exist, don't run it as a test. for: [[campelo-2019-sample-size#^f2]], [[campelo-2019-sample-size#^f7]]
- C6: The unit is the paired per-instance difference; adding data and retesting until significant inflates false positives. for: [[campelo-2019-sample-size#^f5]], [[campelo-2019-sample-size#^f8]]
- C7: LLMs help at small run counts (warm start, proposals); Gaussian-process surrogates are better calibrated once runs accumulate. for: [[llambo#^f1]], [[llambo#^f5]], [[llambo#^f8]]
- C8: Low fidelities mislead when cheap results are noisy, data is small, or a setting's best value depends on data size. for: [[bohb#^f8]], [[hyperband#^f6]], [[hyperband#^f9]]
- C9: Candidates with close final scores need high fidelity to separate: run few, fully. for: [[hyperband#^f2]], [[hyperband#^f3]]
- C10: Where a learning curve flattens answers "would more data help"; intervals are wide on small subsets. for: [[mohr-learning-curves-survey#^f3]], [[mohr-learning-curves-survey#^f7]]
- C11: Rule-based action types with the agent choosing the experiment matched bandit or fully agent-chosen schedules. for: [[agentx-model#^f3]], [[agentx-model#^f5]]
- C12: Choosing among many similar models by validation overfits; nesting candidates in one bigger shrunk model avoids it. for: [[bayesian-workflow-2020#^f11]], [[bayesian-workflow-2020#^f16]], [[bayesian-workflow-2020#^f12]]

## Disagreements

- CAAFE keeps a feature on any validation gain (C3) while Campelo and the Workflow
  paper warn this overfits (C6, C12). Our ladder sides with the latter.

## Open

- Whether the score test works for our shrunk additive models (approximation, inferred)
- MDE for log loss at our sizes: measure from the first runs' realised intervals
- Leads: Bouthillier 2021 (benchmark variance), Piironen and Vehtari 2017 (projection
  predictive selection), arXiv 2606.03656 (clustered evaluation)
