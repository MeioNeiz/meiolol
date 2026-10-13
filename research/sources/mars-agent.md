---
title: 'MARS: Modular Agent with Reflective Search for Automated AI Research'
url: https://arxiv.org/html/2602.02660
kind: paper
commit:
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (sections 1, 4-7, appendices A, B, D, E, F, G)
relevance: high
grade: B/fair
description: Google Cloud AI Research MLE agent (Feb 2026), #3 on the MLE-bench leaderboard (MARS+ 62.7% any medal): time-penalised MCTS, modular repo with diff edits, lessons distilled by diffing each run against the best
---
# MARS: Modular Agent with Reflective Search for Automated AI Research

Why: a current top MLE-bench system with component ablations, cost table and a check of
whether its run-to-run "lessons" are causally right.

## Assessment

- Evidence: B. Google Cloud AI Research, 2026; MLE-bench, 3 runs, controlled
  re-runs of AIDE and AIRA-dojo on the same hardware and LLMs (good practice); ablations
  on Lite (22 tasks) plus 10-task samples of Medium and High. Ablation numbers are in
  figures only (not in the snapshot), so effect sizes per component are not readable
  here.
- Reasoning: fair. States costs, limits (lessons can misattribute), compares in a
  controlled setting; the "Aha!" framing is marketing.
- Interests: authors' own system; Gemini vendor.
- Weigh: trust the cost table, the effective-solution rate and the lesson audit as
  reported numbers; take the ablation claims as direction only.

## Findings

- [lab] Comparative reflective memory: after each valid run, one agent reads the logs for
  objective findings, another diffs the solution against the best-known one and writes a
  lesson: the isolated change, its impact, a general rule. `§4.3` ^f1
  > a Lesson Distillation Agent performs a comparative reflection by analyzing the delta between the current solution and the previous best-known solution
  > resulting in a structured lesson containing: (1) The isolated causal change, (2) A comparative impact analysis, and (3) A generalized rule for future iterations.
- [lab] Failed runs give separate debugging lessons (error, fix, how to spot it again);
  a review agent drops redundant lessons; only the 30 most recent are kept in context
  and the agent must cite the lessons it applies. `§4.3`, `§5.1` ^f2
  > To ensure interpretability, the agent is instructed to explicitly cite specific lessons whenever they are applied.
  > We set the maximum number of lessons in the agent’s memory to Km\=30
- [lab] Ablation: removing memory drops performance sharply; lessons from log analysis
  alone (no diff against the best) do worse than comparative ones; the authors say
  without the delta the agent over-generalises from noisy logs. Numbers only in Fig. 3.
  `§5.3` ^f3
  > Complete removal of memory mechanisms results in a drastic performance drop.
  > Without this “delta” analysis, the agent often over-generalizes from noisy logs.
- [lab] Audit of lessons: an LLM judged 88.34% of 3,611 lessons correctly attributed the
  metric change to the code change; 18 of 20 hand-checked (90%). `§6` ^f4
  > This audit confirmed that 88.34% of the lessons correctly attributed validation metric shifts to specific code changes
- [lab] Lessons are used and travel: 65.8% of solutions cite a lesson and 63.0% of used
  lessons come from another branch of the tree. `§6` ^f5
  > MARS achieves a lesson-utilization rate of 65.8%±1.1% and a lesson-transfer rate of 63.0%±1.8% on MLE-Bench.
- [lab] Admitted limit: lessons can credit an incidental change for a gain; suggested
  fix is confidence from repeated runs, not done. `App. A` ^f6
  > the distilled lessons in the memory pool remain susceptible to hallucinations or misattributions, where the model might incorrectly credit an incidental code change for a performance gain.
  > lesson-confidence scoring based on repeated empirical validation across multiple runs.
- [lab] Budget: the search reward is the min-max normalised score times a penalty on
  run time against its limit (w = -0.07), so of two equal scores the faster run wins.
  `§4.4.3`, `§5.1` ^f7
  > we design a reward function R⁡(v) that rewards performance gains and penalizes long execution time.
  > prioritizing efficient solutions – such as favoring a 1-hour training run over a 4-hour run if performance is comparable
- [lab] Ablation: no time penalty (w = 0) and greedy search both did worse than w =
  -0.07; a stronger penalty (-0.15) chased trivial fast runs. Share of runs that beat the
  current best: 19.5% ± 1.5 with the penalty against 16.1% ± 1.3 without. `§5.3`, `§6` ^f8
  > Budget-aware MCTS achieves an effective solution rate of 19.5%±1.5%, notably higher than the 16.1%±1.3% observed with Vanilla MCTS.
  > a stronger penalty (w\=−0.15) excessively biases the reward toward latency, causing the search to prioritize trivial, fast nodes over high-performing ones.
- [lab] Modular repo: idea, then modules, each unit-tested by the coding agent with a
  validation script before the main script wires them; edits are diffs naming file and
  block, so validated modules are reused rather than regenerated. `§4.2` ^f9
  > it enables efficiency via caching, as validated modules can be reused without regeneration.
  > To prevent wasteful full-repository regeneration, we adopt a Diff-Based Editing mechanism.
- [lab] Debugging is bounded: up to 10 fix attempts per failure, with a debug lesson
  pool so the same error is not repeated. `§5.1`, `App. D` ^f10
  > We allow up to Nd\=10 debugging actions per failure to resolve runtime errors effectively.
  > We maintain a dedicated debugging lesson pool ℒd​e​b​u​g to store error-correction patterns. This prevents the agent from repeating previous mistakes in subsequent iterations.
- [lab] Before search, separate agents fix the split (stratified or grouped 80:20 if no
  validation set), check no leakage between splits and document it; the test set stays
  hidden and the final pick is the best validation node. `App. B`, `App. D` ^f11
  > Distinct agents perform key integrity checks (e.g., no leakage between splits) and generate comprehensive documentation describing the data schema and split logic.
  > Since Dt​e​s​t is unobservable, the agent optimizes via f⁡(s,Dv​a​l,M).
- [lab] Curriculum: first drafts use the most lightweight candidate model, then grow as
  lessons accumulate; improve steps are ablation-style local edits. `App. D` ^f12
  > When the solution lesson pool ℒs​o​l​u​t​i​o​n is empty, an Initial Idea Generation Agent proposes a solution based on the most lightweight model from the Ka candidates.
  > An agent analyzes the current solution and its performance metrics to propose targeted, ablation-style modifications.
- [lab] Cost (Gemini-2.5-Pro, per task): MARS 24 h $60.5, 43.1% any medal; AIRA-dojo
  $39.0, 24.4%; AIDE $10.6, 23.1%; MARS cut to 4 h $9.6, 28.4%. Memory makes input
  tokens 2.2x AIRA-dojo's. Table 11. `App. F.4` ^f13
  > a 4-hour version of MARS achieves a higher Any Medal Rate (28.4%) while spending significantly less ($9.6) than the 24-hour baselines.
- [lab] Leaderboard setups differ widely: one entry (Leeroo) stopped each run early once
  the MLE-bench grader (test labels) showed a medal; ML-Master 2.0 warmed up on 407
  other Kaggle competitions. Table 6. `App. E` ^f14
  > Stop early if the run achieves any medal according to the MLE-Bench grading library.
  > Use 407 kaggle competitions as a warm up dataset to build up a prior wisdom
- [lab] Rule audit: the official MLE-bench log checker (an LLM) found no violations in
  medal runs and no code over 60% similar to top public notebooks. `§6` ^f15
  > registering a 0% violation rate across all monitored dimensions
- [lab] (inferred) For a Claude lab harness: a lessons file written per run by diffing
  against the current best (change, effect with interval, rule), capped and cited, is
  the measured form of "rolling digest"; MARS's own limit (misattribution on noise) is
  exactly meiolol's case, so a lesson should carry the paired interval and be marked
  unconfirmed until repeated. ^f16

## Read

- Sections 1, 4-7 whole; appendices A, B, D, E, F.4, G.

## Not read

- Figure 3, 6, 7 ablation bar values (images); Appendix H prompts; github.com/jfc43/MARS
  trajectories.
