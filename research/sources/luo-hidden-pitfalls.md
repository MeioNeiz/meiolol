---
title: 'The More You Automate, the Less You See: Hidden Pitfalls of AI Scientist Systems (Luo, Kasirzadeh, Shah, 2025)'
url: https://arxiv.org/html/2509.08713
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: listed (sections 1, 3-8; appendix prompts skipped)
relevance: high
grade: B/strong
description: Controlled audit (CMU) of Agent Laboratory and AI Scientist v2 on a synthetic task for four pitfalls (benchmark choice, leakage, metric misuse, post-hoc test selection) plus dataset fabrication; logs and code lift an LLM auditor from 55% to 82% accuracy
---
# The More You Automate, the Less You See (Luo, Kasirzadeh, Shah, 2025)

Why: which methodological failures audits find in experiments that AI scientist systems
run, how often, and which checks catch them.

## Assessment

- Evidence: B. Controlled experiments with a purpose-built synthetic task (no
  contamination), randomised order, control vs manipulated conditions, chi-squared tests;
  1,000 runs for benchmark choice, 200 trials per condition for selection bias. But only
  two systems, 5-10 repeats for leakage and metrics, and the detection test uses 20 items
  per pitfall with many positives injected by hand. Nihar Shah is a peer-review
  methodology researcher.
- Reasoning: strong. Each pitfall isolated by design, limits section admits it covers
  four modes and two systems only.
- Interests: academic; argues for journals mandating logs and code.
- Weigh: trust the mechanisms (test score visible to the selector, silent subsampling or
  synthetic data, metric substitution). Rates are per-system and for o3-mini / default
  configs; the auditor numbers are small-sample.

## Findings

- [lab] Four audited pitfalls: inappropriate benchmark selection, data leakage, metric
  misuse, post-hoc selection bias; dataset fabrication added after it showed up. Abstract,
  6.1 ^f1
  > we identify four potential failure modes in contemporary AI scientist systems: inappropriate benchmark selection, data leakage, metric misuse, and post-hoc selection bias.
- [lab] Post-hoc selection: both systems' internal reward (which picks the run to report)
  sees test-set scores and favours strong test results even with weak train/validation.
  Section 1 ^f2
  > We find that the internal reward mechanism for both systems has access to evaluations on the test set and systematically favors experiments with strong test performance, even when training or validation results are weak.
- [lab] Size of that bias, test scores inverted against train/val ranking: Agent
  Laboratory picked the train/val best 78.5% in control vs 43.5% manipulated, the worst
  1% vs 10%; AI Scientist v2 picked the worst nearly half the time vs never (Cramér's V
  0.39 and 0.66, 200 trials each). 5.4 ^f3
  > the top-ranked candidate (which has good performance on the train/validation data but now poor performance on the test data) is now chosen only 43.5% of the time as compared to 78.5% in the control condition
  > Nearly half of the time, it selects the lowest-ranked candidate in the manipulated condition, despite these candidates having poor training/validation performance, whereas it never selects the lowest-ranked candidate in the control condition.
- [lab] Leakage proper (peeking at test labels) not found in either system, but both
  silently subsampled the given data or generated synthetic data and did not say so in
  the paper. Section 1 ^f4
  > Neither system peeks at the test data. Worryingly though, both systems occasionally generate their own synthetic datasets or subsample from the provided datasets, without documenting these choices in the generated papers.
- [lab] Frequency: Agent Laboratory 2 of 20 leakage runs (one evaluated on a subset and
  beat the noise ceiling, one made a synthetic dataset "for faster prototyping"); AI
  Scientist v2 5 of 20 runs (3, 7, 8, 11, 13), with test accuracy above the provided
  ceiling. 5.2 ^f5
  > in this run, the Agent Laboratory had selected only a subset of the provided benchmark dataset, rather than using the complete evaluation set.
  > in runs 3, 7, 8, 11, and 13, although the input prompt included scripts to load the full benchmark datasets locally, the system frequently subsampled the provided datasets or synthesized new datasets for its experiments.
- [lab] Check that caught it: test labels carried a known noise rate, so any reported
  accuracy above 1 minus noise is impossible without leakage or a changed eval set. 4.2 ^f6
  > If its reported test accuracy significantly exceeds the theoretical upper bound, we treat this as evidence of data leakage.
- [lab] Authors' explanation: the system's own feedback rewards expedient high scores,
  not following the protocol, so it swaps in smaller or easier data. 5.2 ^f7
  > the system sometimes bypasses the intended use of the full local datasets in favor of smaller or synthetic datasets that are computationally easier to handle.
- [lab] Metric misuse: no deliberate cherry-picking found, but metric choice followed
  the order metrics were listed in, and AI Scientist v2 often replaced the asked-for
  metrics with F1, training loss or its own. 5.3 ^f8
  > in a substantial percentage of cases, it did not select any of the specified metrics (SWA or CWA) but instead chose to report alternative measures such as F1 score, training loss, or other self-devised metrics.
- [lab] Agent Laboratory with "SWA first" in the prompt reported only test SWA in all 20
  runs; the choice is made at planning and never revisited. 5.3 ^f9
  > In the SWA first setting, Agent Laboratory consistently selected only Test SWA as its primary evaluation metric across all 20 experiments
- [lab] Benchmark choice: Agent Laboratory took the first four listed benchmarks in
  82.4% of 945 runs (79.6% without SOTA hints); AI Scientist v2 shifted to easy
  benchmarks (47.1% vs 18.0%) when SOTA numbers were shown. 5.1 ^f10
  > among the 945 successful runs under the setting with SOTA reference, 82.4% selected the first four benchmarks listed in the provided benchmark list, regardless of the benchmark order.
- [lab] Detection: an LLM auditor (Gemini 2.5 Flash) given only the paper was at chance
  (55% accuracy, F1 0.51); given paper plus trace logs plus code, 82% (F1 0.81), p =
  6.3e-5. Code mattered most for leakage and fabrication, logs for selection and
  metrics. Section 1, 6.3 ^f11
  > Using only the final paper as the evaluation target misses the opportunity for finding many critical failure modes, particularly those involving decision-making processes during experimentation. (Binary classification accuracy 55%, F1 score 0.51.)
  > Access to code substantially improves the auditor's ability to detect pitfalls such as data leakage and dataset fabrication.
- [lab] Weakest detection even with logs: post-hoc selection bias, 70% accuracy, TPR
  60%, FPR 20%. Table 11 ^f12
  > | Post-hoc selection bias | 50.0% | 40.0% | 40.0% | 0.44 | 70.0% | 60.0% | 20.0% | 0.67 |
- [lab] Leakage and metric misuse were absent from natural runs, so the auditor's
  positives were injected by hand: the detection numbers measure a synthetic mix. 6.2 ^f13
  > naturally occurring instances of certain pitfalls (e.g., data leakage, dataset fabrication) were rare or absent.
- [lab] Leakage is wider than peeking: any flow of evaluation information back into
  model building or tuning, including repeated testing, which their detectors may miss.
  Section 7 ^f14
  > AI scientist systems can risk data leakage whenever information from the evaluation domain feeds back into any stage of model building or tuning, which also refers to multiple testing.
- [lab] (inferred) For meiolol: the selector (agent or harness) must never see the
  test score; the harness should fix the eval rows and metric and record row counts, so
  a run on a subset or other data is visible; an impossible score (above a known
  ceiling or far above best) triggers review. ^f15

## Read

- Sections 1, 3, 4, 5, 6, 7, 8: fully.

## Not read

- Appendices A-D (task instructions and auditor prompt templates): would help if we
  build an LLM audit step; code at github.com/niharshah/AIScientistPitfalls.
- Tables 5-10 as data (HTML tables not rendered in the snapshot).
