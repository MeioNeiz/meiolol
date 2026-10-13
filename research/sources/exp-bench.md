---
title: 'EXP-Bench: Can AI Conduct AI Research Experiments? (Kon et al., 2025)'
url: https://arxiv.org/html/2505.24785
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: listed (abstract, sections 4.1-4.3, appendices G-H)
relevance: medium
grade: B/fair
description: Benchmark of 461 end-to-end experiment tasks from 51 AI papers (Michigan, Berkeley et al.); agents (OpenHands, IterativeAgent) score 20-35% on parts but 0.5% fully correct and executable; failure taxonomy from 3,238 judge notes and an integrity monitor for fake data
---
# EXP-Bench (Kon et al., 2025)

Why: what goes wrong when agents run whole experiments, how often, and which checks
(monitor, re-execution, conjunctive scoring) catch it.

## Assessment

- Evidence: B. 461 tasks, 7 agent/model pairs (o3-mini, Claude 3.7 Sonnet, Haiku 3.5,
  Nova Pro, DeepSeek R1), 40 min per task. But scoring is by an LLM judge (o3-mini),
  failure categories were grouped by an LLM, and execution was only checked on a subset.
  Same group as the Curie agent (interest in rigour tooling).
- Reasoning: fair. Good on why single metrics over-credit; failure percentages are
  shares of judge-noted failures, not of runs, and categories overlap.
- Interests: benchmark authors; sell the benchmark's difficulty.
- Weigh: trust the direction (plausible write-ups without real runs, mock code that
  executes, conclusions not grounded) and the check designs; treat percentages as rough.

## Findings

- [lab] Parts look fine, wholes fail: 20-35% on design or implementation, 0.5% for
  complete, executable experiments. Abstract ^f1
  > while scores on individual experimental aspects such as design or implementation correctness reach 20-35%, the success rate for complete, executable experiments was a mere 0.5%.
- [lab] Integrity monitor over agent logs flags reading the paper, git checkouts, and
  fake, hardcoded or placeholder data in place of real runs; flagged traces are discarded
  before execution. 4.1 ^f2
  > used fake, hardcoded, or placeholder data rather than generating results through real experimentation.
- [lab] Second check: re-run the agent's code changes in a clean, equivalent container
  to verify it executes and produces expected outputs. 4.1 ^f3
  > runs the agent-generated code modifications in a clean and equivalent containerized environment.
- [lab] Agents write plausible answers without running anything: OpenHands models
  often stopped early with a write-up and no experiment, earning high partial scores.
  4.2 ^f4
  > OH models often produced plausible responses without actually running the experiment, leading to high partial scores (e.g., design, implementation)
- [lab] Single checks over-credit: conclusions can be plausible with no valid
  experiment, and mock or wrong code still executes; requiring design, implementation,
  conclusion and execution together is stabler. 4.2 ^f5
  > for C, agents can produce plausible but unfounded conclusions without a valid experimental foundation; for E, even incorrect or mock implementations may successfully execute, introducing overestimation bias.
- [lab] Stacking checks: passing the monitor 20.6%, plus design and conclusion 3.7%,
  plus implementation 0.4%, plus execution 0.2%. 4.2 ^f6
  > applying only the initial monitoring check (M) yields an average score of 20.6%. Adding design (D) and conclusion (C) correctness criteria reduces the score sharply to 3.7%.
- [lab] Most common failures (share of 3,238 judge notes grouped into 361 types):
  missing essential implementation components 39.7%, environment or dependency errors
  29.4%, script and file errors 23.8%, missing conclusions 26.2%, incorrect
  interpretation 19.7%. 4.3 ^f7
  > the most prevalent issues emerged during the implementation phase, with 39.71% of failures stemming from missing essential components.
  > In the execution phase, failures were most commonly due to environment or dependency misconfigurations (29.38%)
- [lab] Wrong conclusions include claiming a gain with no comparison to the baseline
  (e.g. INT4 with Hadamard "improves" without baseline INT4). 4.3 ^f8
  > Another frequent error (19.66%) was incorrect interpretation, such as claiming Hadamard-enhanced INT4 inference improves performance without substantiating comparisons to baseline INT4.
- [lab] Design errors: incomplete or misclassified experimental variables 16.1%, and
  added knobs not asked for 7.6%: agents mix essential factors with noise. 4.3 ^f9
  > These design errors suggest that agents often fail to distinguish between essential experimental factors and implementation noise.
- [lab] Running longer did not help: little correlation between runtime or cost and
  overall performance. 4.2 ^f10
  > we found little correlation between runtime/cost and overall performance.
- [lab] Checked, not there: no separate counts for leakage, test-set misuse or
  post-hoc selection; numeric errors in conclusions only 3.2% of conclusion failures.
  App. G ^f11
- [lab] (inferred) For meiolol: a run counts only if the harness itself executed it
  and the metric came from its output; reject results whose stated comparison lacks a
  baseline row from the same run; a fixed checklist of required variables per
  experiment catches the commonest design gaps. ^f12

## Read

- Abstract, 4.1 (setup, judge), 4.2 (cost-time, conjunctive metrics, stability), 4.3
  (failure patterns), App. G table, App. H description.

## Not read

- Section 3 (dataset construction) and the full judge prompts in App. H: only if we
  build an LLM monitor.
