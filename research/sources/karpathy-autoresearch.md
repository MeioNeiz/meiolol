---
title: 'karpathy/autoresearch: agent edits train.py, 5-minute runs, keep or reset'
url: https://github.com/karpathy/autoresearch
kind: project
commit: 228791fb499afffb54b46200aca536f79142f117
for: [llm-experiment-agent]
looked: 2026-10-12
depth: code (README.md, program.md, prepare.py, train.py)
relevance: high
grade: B/fair
description: Karpathy's minimal agent-run research loop; a coding agent edits one training file, runs fixed 5-minute trainings, keeps commits that lower val loss, resets the rest
---
# karpathy/autoresearch: agent edits train.py, 5-minute runs, keep or reset

Why: the simplest loop design for LLM-driven ML experiments, and what the agent is given.

## Assessment

- Evidence: B. Created March 2026, ~98k stars, ~13.6k forks, 9 contributors, no
  licence field on GitHub (README says MIT). No tests, no measured results in the repo
  beyond a teaser plot. Popular as a pattern; the loop itself is a Markdown prompt.
- Reasoning: fair. Explains the fixed time budget and single-file scope with their
  costs; says nothing about run-to-run noise or validation overfitting.
- Interests: none (personal project, deliberately bare bones).
- Weigh: trust it as a design template (tools, protocol, logging). Its keep rule is
  "strictly lower val_bpb" on one fixed seed and one pinned val shard: on a noisy metric
  like ours that keeps noise. Verify any keep with a paired interval.

## Findings

- [lab] The agent's only tools are a general coding agent's (shell, edit) in the repo;
  the loop is a Markdown "skill" the human writes, not a framework. `README.md` ^f1
  > Simply spin up your Claude/Codex or whatever you want in this repo (and disable all permissions)
  > The `program.md` file is essentially a super lightweight "skill".
- [lab] The human programs `program.md` (the research org); the agent edits one file,
  `train.py`. `README.md` ^f2
  > Instead, you are programming the `program.md` Markdown files that provide context to the AI agents and set up your autonomous research org.
  > **Single file to modify.** The agent only touches `train.py`. This keeps the scope manageable and diffs reviewable.
- [lab] Evaluation, data and constants live in a read-only file; the agent may not edit
  the harness or add packages. `program.md` ^f3
  > Modify `prepare.py`. It is read-only. It contains the fixed evaluation, data loading, tokenizer, and training constants
  > Modify the evaluation harness. The `evaluate_bpb` function in `prepare.py` is the ground truth metric.
- [lab] Fixed wall-clock budget of 5 minutes per run, so runs are comparable whatever
  the agent changes, about 12 an hour, about 100 a night. `README.md` ^f4
  > Training always runs for exactly 5 minutes, regardless of your specific platform. This means you can expect approx 12 experiments/hour and approx 100 experiments while you sleep.
  > First, this makes experiments directly comparable regardless of what the agent changes
- [lab] Loop: edit, git commit, run with output to a log file, grep the metric, log to
  TSV, advance the branch if better, else `git reset`. `program.md` ^f5
  > 8. If val_bpb improved (lower), you "advance" the branch, keeping the git commit
  > 9. If val_bpb is equal or worse, you git reset back to where you started
- [lab] Output stays out of the agent's context: redirect to a log and grep one line;
  read the tail only on a crash. `program.md` ^f6
  > do NOT use tee or let output flood your context
  > If the grep output is empty, the run crashed. Run `tail -n 50 run.log` to read the Python stack trace and attempt a fix.
- [lab] Experiment log: untracked `results.tsv` with commit, metric, memory,
  keep/discard/crash status and a short description. `program.md` ^f7
  > commit	val_bpb	memory_gb	status	description
  > status: `keep`, `discard`, or `crash`
- [lab] Keep rule weighs a simplicity cost against the gain; deleting code for equal
  results is a keep. `program.md` ^f8
  > A 0.001 val_bpb improvement that adds 20 lines of hacky code? Probably not worth it. A 0.001 val_bpb improvement from deleting code? Definitely keep. An improvement of ~0 but much simpler code? Keep.
- [lab] Timeouts and crashes: kill runs over 10 minutes; fix trivial bugs, else log
  `crash` and move on. `program.md` ^f9
  > If a run exceeds 10 minutes, kill it and treat it as a failure (discard and revert).
- [lab] Runs unattended: the agent must never stop to ask; when out of ideas it re-reads
  code, combines near-misses, tries radical changes. `program.md` ^f10
  > If you run out of ideas, think harder [...] read papers referenced in the code, re-read the in-scope files for new angles, try combining previous near-misses, try more radical architectural changes.
- [lab] Greedy hill climb on one branch; backtracking allowed but discouraged.
  `program.md` ^f11
  > If you feel like you're getting stuck in some way, you can rewind but you should probably do this very very sparingly (if ever).
- [lab] Validation is one pinned shard and training uses a fixed seed 42, so the keep
  decision compares single runs with no noise estimate. `prepare.py`, `train.py` ^f12
  > VAL_SHARD = MAX_SHARD  # pinned validation shard (shard_06542)
  > torch.manual_seed(42)
- [lab] Checked, not there: no repeated seeds, no significance test, no separate test
  set; the same val_bpb picks every keep for the whole night. ^f13
- [lab] (inferred) For meiolol (eval at noise level on ~8k games), the strict "lower is
  better" keep would ratchet in noise; the template (locked eval, one editable file,
  log-to-file, TSV ledger, git keep/reset) carries over, the keep rule does not. ^f14
- [lab] Parallel runs are by branch per GPU, e.g. `autoresearch/mar5-gpu0`; no shared
  memory between agents. `program.md` ^f15
  > The experiment runs on a dedicated branch (e.g. `autoresearch/mar5` or `autoresearch/mar5-gpu0`).

## Read

- `README.md`, `program.md`: whole.
- `prepare.py`: constants, val split, `evaluate_bpb`.
- `train.py`: seed and time-budget lines only.

## Not read

- `analysis.ipynb`, `progress.png`: Karpathy's own results; the linked tweets with
  outcomes of overnight runs.
- Notable forks (macOS, MLX, Windows, AMD).
