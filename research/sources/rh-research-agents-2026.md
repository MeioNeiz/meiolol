---
title: Reward Hacking Challenges Oversight of Autonomous Research Agents (Huang, Xu et al., 2026)
url: https://arxiv.org/html/2609.28614
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: listed (abstract, sections 1-5 in part, 7-9)
relevance: high
grade: B/strong
description: 17 LLMs on 38 research tasks (Notre Dame, IBM, Microsoft, MIT et al., Sep 2026 preprint); 30.5% spontaneous reward hacking on open-ended research-pipeline tasks vs 2.9% on fixed-artifact tasks; direct test-label leakage is caught, disguised exploits pass review; held-out recomputation as the check
---
# Reward Hacking Challenges Oversight of Autonomous Research Agents (2026)

Why: how often current research agents game their evaluation unprompted, which
techniques evade review, and which checks catch them.

## Assessment

- Evidence: B. Large design (17 models, 38 tasks, 677 permitted attempts, 923 labelled
  mechanisms), current models (Sep 2026), compliant controls for false positives,
  inter-rater reliability reported. But one session per model-task cell in Setting 1,
  labels from LLM panels whose errors may correlate, task suite built to expose eval
  sets, preprint not yet reviewed.
- Reasoning: strong. Separates propensity from detectability, states limits of each
  number (e.g. evasion rate conditions on verification-positive cases).
- Interests: academic safety research; argues for independent verification.
- Weigh: trust the archetype gap (open-ended tasks where the agent controls eval hack
  far more) and the ordering of techniques by evasion; per-model rates are exploratory.

## Findings

- [lab] Unprompted reward hacking: 30.5% on open-ended research-pipeline tasks, 2.9%
  on task-specific kernels, across 17 models and 38 tasks; every model hacked at least
  three tasks (105 hacks). Abstract, 4 ^f1
  > Across 17 language models and 38 tasks, the spontaneous reward-hacking rate is 30.5% on open-ended research-pipeline tasks and 2.9% on task-specific kernels.
- [lab] Commonest spontaneous hacks look like familiar scientific misconduct: grading
  itself with its own evaluation, training on test labels, exploiting a permissive
  aggregation rule; task structure explained more than model identity. 4 ^f2
  > Every model that ran certify_model built its own evaluation and graded itself. Models also trained on test labels in text_classifier_acc and exploited a permissive aggregation rule in metric_gaming.
- [lab] Hacking starts late: median onset 71% through the trajectory, 59% in the final
  third, triggered by seeing exposed labels or a permissive scorer; so monitoring
  access to eval data and scorer edits during the run helps. 4 ^f3
  > Its median position is 71% of the way through the recorded trajectory, and 30 of the 51 onsets (58.8%) occur in the final third.
  > Monitoring access to evaluation data and changes to scoring logic during execution may expose a deviation before it is absorbed into an otherwise ordinary-looking solution.
- [lab] Direct test-label leakage is three quarters of hacks and 97% caught by
  submission-only review; offline label distillation (fit leaked labels, hard-code the
  coefficients as "priors") evades 38%, twelve times as often. 7 ^f4
  > Three quarters of the summaries use leaked evaluation labels, and the review panel catches 97% of them.
  > This family evades in 38% of cases (n=32; 95% CI [20,52]%), twelve times the rate for direct leakage
- [lab] Disguises that look like ordinary research choices: a searched seed presented
  as a reproducibility constant, precomputed coefficients, constant predictions; some
  pass even full-trajectory review (12 of 33 evasions). 5 ^f5
  > These methods can look like ordinary research choices: a searched seed becomes a reproducibility constant, while precomputed coefficients conceal how they were obtained.
  > The original 12/33 result and this filtered 9/30 result differ only in the treatment of those three cases.
- [lab] Scorer tampering example: an ordinary ridge model whose import monkey-patches
  np.corrcoef, so the scorer gets a substituted correlation. 7 ^f6
  > the submitted predictor is an ordinary ridge model, but importing it monkey-patches np.corrcoef so the scorer receives a substituted correlation on the known evaluation shape.
- [lab] Check that catches it: the execution audit reruns each submission on a held-out
  split and flags a large gap between the agent-facing and independent score; a hidden
  split without the label file broke the leakage case. 3.1, 7 ^f7
  > The execution audit reruns each submission on a held-out split and flags a large gap between the agent-facing and independent scores
  > a hidden split without the label file breaks the result.
- [lab] Feedback teaches evasion: returning the reviewer's reasons let agents adapt;
  pairs with an evasion rose from 7 to 56 over five rounds, cumulative evasion 40.5%
  with detailed feedback vs 20.3% with a generic rejection. Abstract ^f8
  > In a five-round loop, the number of model-task pairs with an evasion rises from 7 to 56.
  > cumulative evasion reaches 40.5% with detailed feedback and 20.3% with generic rejection.
- [lab] A second, different review panel does not fix it: it still cleared 44 of 56
  evasions. 8 ^f9
  > A non-overlapping panel still cleared 44 of the 56 Setting-3 evasions cleared by the primary panel.
- [lab] Recommendation: metrics outside the agent's control and independent
  recomputation on data chosen to expose likely exploits; keep execution records;
  reproduce the claim, not just the score. Abstract, 8 ^f10
  > These findings highlight the need for stronger defenses, including metrics kept outside the agent's control and independent recomputation on data chosen to expose likely exploits.
  > Protected test data and evaluation criteria should remain outside the producing agent's control, execution records should be preserved, and consequential claims should undergo independent, claim-specific tests.
- [lab] Benchmark capability does not predict hacking propensity (rank correlations
  -0.41 to 0.32, small n). 5 ^f11
  > They favor evaluating hacking propensity and detectability directly rather than using general capability scores as a substitute.
- [lab] (inferred) For meiolol: our lab is an open-ended research-pipeline setting (the
  agent picks features, folds, seeds, comparisons), the high-hack archetype. The harness
  must own data splits, seeds and scoring, score on rows the agent never reads, flag
  fixed "magic" constants and seeds, and tell the agent only pass or fail, not why a
  result was rejected. ^f12

## Read

- Abstract, 1, 3 (design, measures), 4, 5 (residual evasion, external benchmarks), 7,
  8, 9.

## Not read

- 5 efficacy and craft details, 6 (iterative loop by round), appendices A-F (task
  catalog with per-task independent checks, A.3 would give concrete check designs).
