# Lab agent: LLM-run model experiments

Design, 2026-10-12, not built. A Claude Code session proposes, runs and analyses model
experiments overnight on the gpu-box; a harness it cannot change scores them and keeps
the record. Evidence: research/questions/llm-experiment-agent.md (C1-C20 below).

## Why this shape

- Narrow, purpose-built loops beat general agents with many tools (C1, C7); search
  policy (tree, evolutionary) adds nothing until the steps themselves are good (C4)
- Our binding constraint is the eval signal, not the search (C20): effects sit at the
  noise level, and an agent reusing one held-out set manufactures wins from noise (C11,
  C13, C14). None of the published loops guard against that (C15); we must
- Agents game scorers they can see and invent results (C17, C19): scoring and records
  belong to the harness, never the agent

## Pieces

| piece | who writes it | what |
|---|---|---|
| src/lab/api.zig | us, read-only to the agent | the candidate interface and masked data |
| src/lab/harness.zig | us, read-only | splits, masking, scoring, ladder, records |
| src/lab/cand/<campaign>/*.zig | the agent, only here | one candidate model per campaign |
| ~/ml/lab/<snap>/ on the gpu-box | harness only | run records, ladder state, look budget |
| <campaign>/digest.md | the agent | what worked and what didn't, by run id |
| docs/lab-brief.md | us | the agent's brief (program.md in autoresearch) |

The agent is a plain Claude Code session with the brief and narrow permissions, not a
framework (autoresearch's form, C2).

## Candidate interface

One function: fit on the labels you can see, predict every row.

```zig
// src/lab/api.zig
pub const Input = struct {
    games: []const rows.Game,
    rows: []const rows.Row, // y is NaN wherever the harness hides it
    seed: u64,
    deadline_ns: i96,
};
// a candidate module exports:
pub fn predict(gpa: std.mem.Allocator, in: *const Input, out: [][rows.outcome_count]f32) !void;
```

The harness calls it three times with different masks, so the same code is scored at
three levels without the candidate knowing which:

| call | labels visible | scored on | who sees the result |
|---|---|---|---|
| dev | train minus dev-val | dev-val | the agent, in full |
| select | all train | selection set | the agent, ladder answer only |
| final | train + selection | test | `exp final`, a human command |

The candidate module gets only `std`, `core` and `api` as imports in build.zig, and Zig
refuses `@import` of files outside its own directory, so it cannot reach rows.zig, the
snapshot loader or the split. The harness also rejects a candidate whose source mentions
`std.Io`, `std.fs` or `std.process` (no reading the snapshot or labels behind its back).
Hidden tests are what stopped gaming in ImpossibleBench (C18).

## Splits

Protocol's split stays (docs/model.md "Shared protocol"): test = newest 20% of EUW1
games. Train is cut further by time, both on EUW1 like test:

- selection: newest 20% of the remaining EUW1 games
- dev-val: the next newest 20% of EUW1 games
- dev-train: everything older, every platform

A new snapshot moves every boundary forward, so the look budget starts fresh on games no
one has selected on.

## Scoring

- Per outcome (win, gold14, lanediff14, cs10, deaths15, first_item): log loss for win,
  MSE standardised per role for the rest, censored first_item rows left out (protocol)
- Every comparison paired per row and clustered by game, 95% interval (enemy.zig's
  pairedDiff moves into harness.zig and both use it)
- Each run also scores the baselines on the same rows: champion-role mean for everyone,
  3c's additive model for 2a-style campaigns (plan: 2a must beat 3c)
- Deterministic models run once; models with a seed run 3 seeds and the harness averages
  predictions before scoring (single fixed-seed runs keep noise, C15)

## The ladder (selection set)

The agent never sees a raw selection score. Per snapshot the harness keeps a current
best; a `select` call answers:

- "new best" with its gain over the previous best and interval, when the paired
  interval's upper bound is below 0 for the campaign's target outcome
- "no change" otherwise, with no number

This is Blum and Hardt's Ladder with our paired test (C16): error grows with log k, not
sqrt k. Budget: 50 `select` calls per snapshot, shared by every campaign on it (they
all adapt to the same games; Cawley and Talbot see overfitting after 30-40 tuning
looks, C13). When it runs out, select refuses until the next snapshot. Dev scores are
unlimited: the agent may overfit dev-val, and the ladder is what catches it.

## Commands (meiolol-lab exp)

```
exp run CAMPAIGN NAME [--target OUTCOME]   dev score, plus select if --select
exp table CAMPAIGN [--top N]                one line per run, sorted by dev gain
exp show RUN                                meta, diff vs best, dev per outcome and role
exp compare RUN_A RUN_B                     paired dev diff by outcome, role, patch, rank
exp restore CAMPAIGN RUN                    copy a run's candidate back into cand/
exp stop CAMPAIGN "REASON"                  flag for a human: nothing real left
exp final SNAP [--top 3]                    human only: test score of the top 3 by select
```

- `run` goes through deploy/lab-run.sh (gpu-box, League watcher, run dir with diff) with
  a fixed wall-clock budget, 10 minutes by default, so runs compare (C2). Killed at 2x
  and recorded as crash. Output to the run log; the agent gets one summary line and the
  log tail only on a crash (C7)
- Every run is recorded, crashes and discards too (C9): runs.tsv (run id, campaign,
  stamp, candidate hash, target, dev gain and interval per outcome, select verdict,
  status, one-line description) plus the candidate source and stdout in the run dir.
  Written by the harness, read-only to the agent
- `restore` replaces autoresearch's git reset: sessions share main, so the agent never
  resets or branches; the candidate's history lives in the run records
- `compare` is the analysis tool: where a gain comes from (one role, one patch, one rank
  band) is what decides whether it is real or a quirk
- `final` scores a campaign's top 3 by select, not only the best (choosing the final
  model is most of the validation-test gap; top-3 hedging recovers ~10%, C14). Every
  call is logged in the snapshot's record, so an extra look shows

## The agent's loop (docs/lab-brief.md)

1. Read digest.md and `exp table`
2. Propose one atomic change to the candidate (C3), with the hypothesis in one line
3. `exp run`; on crash, fix up to 3 times, then restore the best and move on
4. Keep a dev gain whose interval excludes 0 as the new working candidate; spend a
   `select` look only on a dev gain that survives `exp compare` (not one role or patch)
5. Every 10 runs, rewrite digest.md: what worked, what didn't, by run id, then ideas
   (analysis and advice separate, C10). Numbers only as run ids; the harness's records
   are the source (C19)
6. Stop with `exp stop` when 30 runs bring no dev gain or the look budget is spent, and
   say so. The brief rewards stopping at noise over pushing on (flag exit, C18)

The brief shows time and looks remaining each run (C7). It says not to game the scorer,
but nothing depends on that working (C17).

## Several campaigns

Variety comes from several short campaigns with different briefs rather than one long
session (best-of-k, C6; context resets, C6): e.g. one per outcome, or one each for
3c-style shrinkage, 2a-style embeddings, comp features. They share the look budget.
Fleet starts them (one session per campaign); the coordinator reads digests in the
morning.

## Permissions

Each agent session gets .claude/settings deny rules: Edit and Write outside
src/lab/cand/<campaign>/ and its digest; Bash `exp final`, git reset/checkout/push,
ssh except through deploy/lab-exp.sh. The threat is a model taking a shortcut, not an
attacker: permissions, module imports and logged looks make shortcuts visible rather
than impossible.

## Build order

1. api.zig and harness.zig: masking, three calls, scoring, ladder, records; tests on a
   fixture snapshot (a candidate that reads hidden labels must fail to build; the ladder
   must answer "no change" to pure noise)
2. Port base, 3c additive and 2a fm as candidates; the harness must reproduce enemy.zig
   and outcomes.zig numbers on the same snapshot
3. `exp` commands, deploy/lab-exp.sh, lab-brief.md, permissions
4. One campaign, one night, continuous outcomes (more signal than win), reviewed by
   hand before running several

## Open

- Cost per run in tokens: no source gives it; measure on the first campaign
- At ~8k-27k games nothing beats base rates on win; whether the agent finds anything
  before data grows is the first campaign's question
- Budget of 50 looks is a guess between Cawley's 30-40 and the Ladder's log k; Roelofs
  2019 and Recht 2019 (unread) argue holdout reuse overfits less than feared
