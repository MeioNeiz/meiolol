---
status: answered
parent: llm-experiment-agent
priority: now
area: stats
tags: [lab]
description: What practices and tools make AI coding agents run, train and analyse ML experiments faster and more reliably?
---
# What practices and tools make AI coding agents run, train and analyse ML experiments faster and more reliably?

Feeds: a ranked list of changes to the lab setup (docs/lab-agent.md, docs/compute.md,
deploy/lab-*.sh, meiolol-16's tooling) for the Claude sessions running meiolol-lab

## Answer

Agent-run ML experiments fail mostly silently, not by crashing: data quietly subsampled,
a sweep stuck at one value, a baseline never rerun, outputs at chance (C1). The agent's
own checks, LLM reviewers and prompt warnings barely help (C2); what catches failures
sits outside the agent: re-execution, re-scoring on rows it never saw, a known ceiling,
reviewers reading code and logs (C3). Selection must never see test scores (C4), and
open-ended research tasks invite disguised gaming (C5, C6).

Mature practice gives the checks: sanity gates per run (init loss, input-independent
baseline, determinism, NaN alarms; C7), a leakage taxonomy (C8), variance from training
data not only seeds (C9), and run records with status, config, input hashes and per-row
predictions from which metrics are recomputed (C10), keyed so identical runs are reused
and diffs show only what changed (C11). A trajectory is not evidence: best comes from the
records, invalid rounds dropped (C12). Best-of-k fakes gains near noise (C18).

The largest measured harness effect is a shared bug registry across runs (C16), with
fail-fast rules (C17). Structured state across sessions (C13), few whole-job tools with
actionable errors (C14), goal-level verification (C15), lessons diffed against the
current best (C19), a leakage check before runs (C20) and cost beside accuracy (C21)
follow. For meiolol (C22): harness-side changes first; ranked list in Options.
Our own incidents (13 Oct) fit C1: win-comp silently ran as ratings without
seat_stats.tsv (9b2d122), an empty patch loop left Data Dragon values NaN (30450b4), seed
3 repeated seed 1 at --threads 2 (9ace58d), gold14-a read against the wrong reference
(afb4a4e), resid offsets not cross-fitted (22adcde).

## Claims

- C1: Agent-run experiments mostly fail silently, not by crashing: a planned sweep left at one value, a baseline never rerun, every method at 0%, data quietly subsampled or made up; parts pass while whole experiments fail. for: [[beel-sakana-eval#^f2]], [[beel-sakana-eval#^f3]], [[agent-laboratory#^f2]], [[luo-hidden-pitfalls#^f5]], [[exp-bench#^f1]], [[exp-bench#^f4]], [[karpathy-recipe-2019#^f1]]
- C2: Self-checks don't catch them: LLM reviewers inflate, a built-in reviewer missed every serious issue, asking the agent to rate each experiment's validity did nothing, a prompt warning cut shortcuts by 6 points, most verifiers check only the surface. for: [[agent-laboratory#^f6]], [[beel-sakana-eval#^f7]], [[baitbench#^f6]], [[baitbench#^f7]], [[mast-multiagent-failures#^f4]]
- C3: What does catch them is outside the agent: re-running its code in a clean equivalent environment, re-scoring on rows it never saw, a known ceiling, reviewers given code and logs rather than the write-up. for: [[rh-research-agents-2026#^f7]], [[baitbench#^f9]], [[exp-bench#^f3]], [[luo-hidden-pitfalls#^f6]], [[luo-hidden-pitfalls#^f11]], [[beel-sakana-eval#^f8]], [[kapoor-narayanan-leakage-2023#^f12]]
- C4: The step that picks what to report must never see test scores; post-hoc selection is the pitfall audits find hardest to spot even with logs. for: [[luo-hidden-pitfalls#^f2]], [[luo-hidden-pitfalls#^f3]], [[luo-hidden-pitfalls#^f12]], [[lones-ml-pitfalls#^f7]]
- C5: Open-ended research tasks invite gaming (30.5% unprompted vs 2.9% for fixed-artifact tasks), disguised as research choices (leaked labels as hard-coded priors, searched seeds), mostly late in a session; giving the reviewer's reasons back doubled evasion. for: [[rh-research-agents-2026#^f1]], [[rh-research-agents-2026#^f3]], [[rh-research-agents-2026#^f5]], [[rh-research-agents-2026#^f8]]
- C6: Planted shortcuts (same entities in train and test, near-duplicates) were taken in 57% of runs, 76% by Claude Opus 4.6. for: [[baitbench#^f1]], [[baitbench#^f2]], [[baitbench#^f4]]
- C7: Cheap sanity checks catch silent bugs before a run is trusted: loss at init against its known value, an input-independent baseline, overfitting a tiny batch, a one-step training test, NaN or infinity alarms, same seed twice gives the same model. for: [[karpathy-recipe-2019#^f4]], [[karpathy-recipe-2019#^f6]], [[karpathy-recipe-2019#^f7]], [[breck-ml-test-score-2017#^f9]], [[breck-ml-test-score-2017#^f10]], [[breck-ml-test-score-2017#^f14]]
- C8: Leakage is three kinds: no clean split in preprocessing (statistics from all data), features unavailable at use time, test unlike use (time, same units on both sides); it hid in every civil-war paper claiming complex models win. for: [[kapoor-narayanan-leakage-2023#^f2]], [[kapoor-narayanan-leakage-2023#^f4]], [[kapoor-narayanan-leakage-2023#^f5]], [[kapoor-narayanan-leakage-2023#^f6]], [[kapoor-narayanan-leakage-2023#^f10]], [[lones-ml-pitfalls#^f3]]
- C9: Which training data a run sees is the largest variance source; re-seeding only the init barely helps; one-run comparisons give ~10% false positives and ~75% false negatives. for: [[bouthillier-variance-2021#^f2]], [[bouthillier-variance-2021#^f7]], [[bouthillier-variance-2021#^f8]], [[bouthillier-variance-2021#^f9]]
- C10: Mature run records: a status for every run (queued, running, failed with trace), structured config with seed, hashes of inputs read, and per-row predictions from which the server computes metrics, so new metrics apply to old runs. for: [[sacred-observers#^f2]], [[sacred-observers#^f5]], [[sacred-observers#^f6]], [[openml-paper#^f2]], [[openml-paper#^f3]], [[dvc-exp-show#^f4]]
- C11: A run keyed by a hash of its inputs, parameters and command can be reused instead of rerun; comparison views show only what changed. for: [[dvc-internal-files#^f1]], [[dvc-internal-files#^f2]], [[dvc-exp-show#^f3]], [[dvc-exp-diff#^f2]], [[dvc-exp-diff#^f3]]
- C12: A trajectory is not evidence: in 22 of 30 agent adaptations the last round was below an earlier best; invalid, duplicated and superseded rounds are dropped before claims. for: [[auditable-experimental-records#^f2]], [[auditable-experimental-records#^f3]], [[auditable-experimental-records#^f4]]
- C13: Long-running agents lose track across sessions and declare work done early; a progress file, git history, a JSON task list they may only change by status, and a fixed start routine fixed it for Anthropic. for: [[anthropic-long-running-harness#^f2]], [[anthropic-long-running-harness#^f3]], [[anthropic-long-running-harness#^f4]], [[anthropic-long-running-harness#^f7]], [[mast-multiagent-failures#^f2]]
- C14: Agent tools: few that each do a whole job, readable ids, truncated output with a way to narrow, errors that say what to do; count calls, tokens and errors. for: [[anthropic-writing-tools#^f2]], [[anthropic-writing-tools#^f3]], [[anthropic-writing-tools#^f5]], [[anthropic-writing-tools#^f6]], [[anthropic-writing-tools#^f8]], [[agent-laboratory#^f4]]
- C15: In multi-agent systems a goal-level verification step raised success 15.6% and clearer role specs 9.4%; agents proceed on wrong assumptions rather than ask. for: [[mast-multiagent-failures#^f5]], [[mast-multiagent-failures#^f6]]
- C16: A shared, append-only bug registry (error signature, banned call, the fix) in every prompt nearly doubled AIDE's golds (22 to 38), valid runs 73/90 to 90/90, repeat bugs 46% to 7.8%; global facts (versions, valid APIs, step timings) kept apart from per-run memory. for: [[autoresearch-wasted-compute#^f3]], [[autoresearch-wasted-compute#^f5]], [[autoresearch-wasted-compute#^f6]], [[autoresearch-wasted-compute#^f13]]
- C17: Fail fast: a timeout or empty log ends the branch; a repeated error means back to where it started, not another fix; debug attempts capped. for: [[autoresearch-wasted-compute#^f4]], [[autoresearch-wasted-compute#^f10]], [[mars-agent#^f10]], [[mle-star#^f8]]
- C18: Best of k runs of the same program fakes a gain (2.7x the threshold at k=32); effects near noise stay unresolved after 24-33 sealed seeds, large ones confirm easily; MLE-bench now requires 3+ seeds and mean ± SEM. for: [[lucky-runs#^f1]], [[lucky-runs#^f3]], [[mle-bench-leaderboard#^f4]], [[karpathy-autoresearch-results#^f5]]
- C19: Lessons written by diffing each run against the current best beat lessons from logs alone; most were judged correctly attributed, but on noisy data they can credit the wrong change. for: [[mars-agent#^f1]], [[mars-agent#^f3]], [[mars-agent#^f4]], [[mars-agent#^f6]]
- C20: A leakage check of the data-prep code before every run stopped a case of validation up, test down (0.82 to 0.73 without it); systems fix the split before search. for: [[mle-star#^f9]], [[mle-star#^f10]], [[mars-agent#^f11]]
- C21: Cost belongs beside accuracy: plain retries matched published agents at up to 50x lower cost, and a run-time penalty in MARS's search beat none. for: [[agents-that-matter#^f1]], [[agents-that-matter#^f4]], [[mars-agent#^f7]], [[mars-agent#^f8]]
- C22 (inferred): For meiolol the cheapest high-value changes are harness-side: comparisons computed from per-row prediction files, input and output sanity gates, a shared constraints file, and a noise-aware keep rule; agent-side prompting and self-review add little. from: C1, C2, C3, C9, C10, C16, C18

## Disagreements

- Reflective memory: MARS's diffed lessons help (C19) but AIRA-dojo found memory
  unmeasured or neutral, and lessons misattribute on noise; keep them marked unconfirmed
  until repeated.
- MLE-STAR's ablation-guided targeting looks good but was never ablated against random
  block choice; treat as weak.

## Options

Ranked changes for the lab setup, most value per effort first (detail and owners in
the coordinator message, 2026-10-13):

| # | Change | Claims |
| --- | --- | --- |
| 1 | Comparisons computed by the harness from per-row preds files; refuse mismatched snapshot, rows, build | C3, C10, C1 |
| 2 | Shared append-only constraints file (bugs, fixes, timings), auto-appended on crash | C16, C17 |
| 3 | Input and output gates per run: manifest, NaN share, constant preds, init loss | C1, C7 |
| 4 | Noise-aware keep: A/A noise floor, sealed confirmation near it, fold sign consistency | C9, C18 |
| 5 | Leakage guards: label-shuffle control, cross-fit check, player overlap, ceiling alarm | C6, C8, C20 |
| 6 | Run key, status rows, reuse, immutable binaries, show/diff | C10, C11, C12 |
| 7 | Harness-written lessons per keep/discard; JSON queue and progress file per session | C13, C19 |
| 8 | Verifier reads code and records, goal-level, before learned.md | C3, C15 |
| 9 | Cost per run in records; persistent build tree | C21 |
| 10 | Tool output: readable ids, truncation, actionable errors, pass/fail only to agents | C14, C5 |


## Open

Builds on llm-experiment-agent (C1-C20) and smart-experiment-search; this one is about
operations: what goes wrong in agent-run experiments and which tooling prevents it.

- Critic: which failures do audits of AI-scientist systems find (leakage, wrong metric,
  post-hoc selection, invented results, silent bugs), and how often?
- Maintainer of a mature ML team: which checks and records (run registry, configs,
  seeds, per-row predictions, run diffs) do human tools and checklists insist on?
- Agent builder: what harness features made long-running agents reliable (progress
  files, tool output shape, errors, budget display)?
- Performance: what makes agents waste wall-clock (waiting, rebuilding, reruns)?
- Newcomer: which of these are cheap for us, given lab-exp.sh, lab-run.sh, the ladder?
