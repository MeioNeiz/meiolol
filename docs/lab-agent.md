# Lab agent: LLM-run model experiments

A Claude Code session proposes, runs and analyses model experiments on the gpu-box; a
harness it cannot change scores them and keeps the record. Built 2026-10-12: harness,
search tools, brief (docs/lab-brief.md), launcher (deploy/lab-agent.sh); no campaign
run yet (Build order). Evidence:
research/questions/llm-experiment-agent.md (C1-C20) and smart-experiment-search.md
(S1-S12 below means its C1-C12).

## Why this shape

- Narrow, purpose-built loops beat general agents with many tools (C1, C7); search
  policy (tree, evolutionary) adds nothing until the steps themselves are good (C4)
- Our binding constraint is the eval signal, not the search (C20): effects sit at the
  noise level, and an agent reusing one held-out set manufactures wins from noise (C11,
  C13, C14). None of the published loops guard against that (C15); we must
- Agents game scorers they can see and invent results (C17, C19): scoring and records
  belong to the harness, never the agent
- Smart, not brute force: diagnose, screen cheaply, size the effect, then run few
  experiments fully (S1-S12, "Search" below)

## Pieces

| piece | who writes it | what |
|---|---|---|
| src/lab/api.zig | us, read-only to the agent | the candidate interface |
| src/lab/harness.zig | us, read-only | splits, queries, baseline, scoring, ladder |
| src/lab/exp.zig | us, read-only | `meiolol-lab exp`: records, summary, final |
| ~/ml/agent/<campaign>/ | the agent, only here | root.zig, digest.md, hypotheses.tsv |
| src/lab/cand/base | us | the starting candidate |
| src/lab/search.zig | us, read-only | `exp screen`, `exp diagnose` |
| deploy/lab-exp.sh | us | the agent's only way to run and read results |
| deploy/lab-agent.sh | us | starts a headless agent session on a campaign |
| ~/ml/lab/<snapshot>/ on the host | harness only | runs.tsv, looks.tsv, best-*.tsv, finals.tsv |
| docs/lab-brief.md | us | the agent's brief (program.md in autoresearch) |

The agent is a plain Claude Code session with the brief and narrow permissions, not a
framework (autoresearch's form, C2).

## Candidate interface (src/lab/api.zig)

A candidate fits on the visible training games, then predicts one query at a time:

```zig
pub const scope: api.Scope = .champ_select; // or .post_game
pub const Model = struct { ... };
pub fn fit(gpa: Allocator, train: *const api.Train, opts: api.Options) !Model;
pub fn predict(m: *const Model, q: *const api.Query) api.Prediction;
pub fn deinit(m: *Model, gpa: Allocator) void;
pub const seeded = true; // optional: the harness averages 3 seeds
```

- Train: the phase's visible games and rows, every outcome (training labels)
- Query: one player in one game as champ select knows it: start, patch, platform, side,
  role, champion, own rank, both teams' champions by role. Never an outcome; other
  players' ranks only for `post_game` (docs/production-key.md; meiolol-cf's two rules:
  scope enforced by the harness, no leakage by construction). A test checks Query has
  no outcome field
- Prediction: every outcome; NaN means no opinion, scored as the baseline, so a
  candidate can work on one target
- The candidate module imports only `std` and `api` (build.zig); Zig refuses imports
  outside the module's directory. deploy/lab-exp.sh also refuses candidates that name
  std.Io, fs, process, posix, os, c, net, http or asm. Hidden tests are what stopped
  gaming in ImpossibleBench (C18)

## Splits

Protocol's split stays (docs/model.md "Shared protocol"): test = newest 20% of EUW1.
Inside train, by time on EUW1: selection = newest 20% of non-test EUW1 games, dev-val =
the next 20%. Each phase sees only older games, every platform:

| phase | visible (fit on) | scored on | who sees the result |
|---|---|---|---|
| dev | games older than dev-val | dev-val | the agent, in full |
| select | games older than selection | selection | the agent, ladder answer only |
| final | all train | test | `lab-exp.sh final`, humans only |

A new snapshot moves every boundary forward and starts a fresh look budget.

## Scoring

- Per row and outcome: log loss for win (the row's team), squared error in the role's
  standard deviation for the rest; NaN outcomes (no timeline to 15:00, censored
  first_item) left out
- Baseline: champion-role mean fitted on the same visible rows (win pulled to the role
  rate by 1000 rows); src/lab/cand/base is the same model, so a new campaign starts level
- Every comparison paired per row, 95% interval clustered by game
- First smoke run (2026-10-12, snapshot 20261012T2055Z): dev-val 80,190 gold14 rows,
  run time 16 s on the gpu-box plus ~80 s building

## The ladder (selection set)

The agent never sees a raw selection score. Per snapshot and target the harness keeps
a current best (the baseline until beaten). A `--select` run answers "new best" with
its gain over the previous best when the paired interval's upper bound is below 0, else
"no change" with no number: Blum and Hardt's Ladder with our paired test (C16). Budget:
50 looks per snapshot, shared by every campaign (overfitting shows after 30-40 tuning
looks, C13); then select refuses until the next snapshot. Dev scores are unlimited: the
agent may overfit dev-val, and the ladder catches it.

## Commands (deploy/lab-exp.sh)

```
new CAMPAIGN [FROM]                  candidate dir from FROM (default base)
run CAMPAIGN NAME TARGET [--select] [--desc TEXT]
table [CAMPAIGN] | looks | show RUN  records; summary.md: dev by outcome, role, patch, tier
restore CAMPAIGN RUN                 a run's candidate back (sessions share main: no git
                                     reset; the candidate's history is the run records)
stop CAMPAIGN REASON                 flag for a human: nothing real left
final CAMPAIGN TARGET [N]            humans only: test score of the last N select winners
```

- Each run builds HEAD plus the candidate in a clean temporary tree (as the pre-push
  hook does), so other sessions' half-done edits never break a run and scoring is
  always the committed harness. It runs through deploy/lab-run.sh (League watcher, run
  dir with candidate source, meta and log) with a fixed budget (LAB_BUDGET_S, 600 s
  of running time, killed at 2x, paused time not counted; C2)
- Output goes to the log; the agent gets the RESULT line, or the log tail on a crash
  (C7). Every run is a line in runs.tsv, crashes too (C9)
- `final` scores the last N winners, not only the best (final-model choice is most of
  the validation-test gap; top-3 hedging recovers ~10%, C14); every call is logged

## Search: how the agent decides what to run

Box's loop, not brute force (S1, S2): every experiment answers a named misfit, is sized
before it runs, and is recorded as a hypothesis with an outcome.

1. **Diagnose.** Read the current best's dev residuals sliced by covariates it doesn't
   use yet (enemy lane champion, ally jungler, champion class, patch, rank tier, side,
   game start hour). A slice with a consistent sign names a misfit (S2). Tool: `exp
   diagnose` (to build)
2. **Hypothesise.** One line: mechanism, the slice it fixes, expected direction and
   rough size. Written to the campaign's hypotheses.tsv before running (S6). Domain
   context (draft theory, field meanings) is what made LLM features work (S3)
3. **Screen without a full run.** The candidate's Model exposes cheap features; `exp
   screen` fits each alone on dev-train residuals (within champion-role, a score test,
   S4) and reports its dev gain and interval in seconds. Only features whose gain
   clears the dev interval go on (S5). Ideas below the detectable size are parked as
   "inconclusive at this data size", not run and called refuted (S5)
4. **Size it.** The smallest detectable gain is ~1.4x the dev interval half-width
   (80% power); runs.tsv's recent intervals give it. A plausible effect below it waits
   for data
5. **Run, one atomic change** (C3), full data (close scores need full fidelity, S9).
   Keep it as the working candidate when its dev interval excludes 0
6. **Check it's general before a look.** The summary's slices: a gain from one role,
   patch or tier is a quirk until shown otherwise. Then, for gains that need data,
   `--fraction 0.25/0.5` runs: a gap growing with data means real and data-limited;
   flat near 0 means no effect (S10). Subsets screen crashes and clear losers, never
   near-ties (S8)
7. **Spend a selection look** only on a dev gain that survived 5 and 6
8. **Numbers by a routine, structure by the LLM.** Once a structure is fixed, its
   numeric settings (prior strengths, L2, dims) go to a small grid or TPE on dev, not
   to the LLM's guesses (S7). Scale any prior by games, or subsets mislead (S8)
9. **Prefer one bigger shrunk model** over picking among many similar ones: add the
   candidate terms together under shrinkage (S12)

Schedule: the brief rotates action types (diagnose, follow up, new idea, combine) and
the agent picks the concrete experiment; no bandit (S11). Every 10 runs it rewrites
digest.md: what worked and what didn't by run id, then ideas (C10). Numbers only as run
ids, the harness's records are the source (C19). It stops with `stop` after 30 runs
without a dev gain or when looks run out; the brief rewards stopping at noise (C18).

## Several campaigns

Variety comes from several short campaigns with different briefs (best-of-k, C6): e.g.
one per outcome, or 3c-style shrinkage, 2a-style embeddings, comp features. They share
the look budget. Fleet starts them, one session per campaign; the coordinator reads
digests in the morning.

## Permissions and launch

`deploy/lab-agent.sh start CAMPAIGN TARGET [FOCUS]` makes the campaign in ~/ml/agent
(LAB_CANDS: outside the shared checkout) and starts `claude -p` there in the
background with the brief and its own settings (`lab-agent.sh settings CAMPAIGN` prints them): allow Read, Edit in
the campaign dir and `lab-exp.sh`; deny edits in the repo, `lab-exp.sh final`, git,
ssh, scp, rsync, curl, web. Checked with a headless session told to try each one.
No spend or run cap (Jacob, 2026-10-12): a campaign ends by the brief's stop rule or
the look budget; LAB_MAX_RUNS caps runs when set. The clean-tree build means edits
outside the candidate never reach a run anyway. The threat is a model taking a
shortcut, not an attacker: permissions, module imports, the clean build and logged
looks make shortcuts visible rather than impossible.

## Build order

1. Done (53b0577): api, harness (fit/predict, scope masking, cuts, baseline, paired
   clustered intervals, ladder), `exp run|final`, lab-exp.sh, tests (no scored game or
   other rank reaches a candidate; Query has no outcome; noise doesn't pass the ladder,
   a real gain does). Smoke run on the gpu-box
2. Done (75cd185, afd0cb0): hypotheses.tsv and `--hyp`; `--fraction`; `exp screen`
   (first real screen: own rank helps gold14, dev -0.0067 ± 0.0011); `exp diagnose`
   (slices relative to the overall drift, Bonferroni flag per group; flags rank tiers
   for gold14); `mde` in RESULT
3. Done: docs/lab-brief.md, deploy/lab-agent.sh, permission set (checked).
   Still to add: champion metadata (Riot class tags) in api.Train for comp features
4. Port base, 3c additive and 2a fm as candidates; the harness must reproduce their
   numbers on the same snapshot
5. One campaign, one night, continuous outcomes (more signal than win), reviewed by
   hand before running several

## Open

- Cost per run in tokens: no source gives it; measure on the first campaign
- Win: nothing beats base rates at current volume; the first campaigns target the
  continuous outcomes
- 50 looks is a guess between Cawley's 30-40 and the Ladder's log k; Roelofs 2019 and
  Recht 2019 (unread) argue holdout reuse overfits less than feared
- Build time (~80 s) dominates a 16 s run: a persistent build tree would cut it
