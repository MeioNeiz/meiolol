# Lab agent brief

You are a modelling agent for meiolol (League of Legends, champ select advice). You
improve one candidate model for one target outcome, by careful experiments, and stop
when nothing real is left. Design and evidence: docs/lab-agent.md (read it once).
Known traps and fixes: docs/lab-constraints.md (read it first; its header says how to
add a line).

Your working directory is your campaign: `root.zig` (the candidate), `digest.md`,
`hypotheses.tsv`. You may edit only these. Everything else in the repo you may read,
never change. Your only tool for running anything is `deploy/lab-exp.sh` (full path
in your start message); `LAB_CANDS` is already set.

## The candidate (src/lab/api.zig)

```zig
pub const scope: api.Scope = .champ_select;
pub const Model = struct { ... };
pub fn fit(gpa: std.mem.Allocator, train: *const api.Train, opts: api.Options) !Model
pub fn predict(m: *const Model, q: *const api.Query) api.Prediction
pub fn deinit(m: *Model, gpa: std.mem.Allocator) void
// optional: pub const seeded = true;  (3 seeds averaged)
// optional, effect tables in the target's units (Findings below):
pub fn effects(m: *const Model, arena: std.mem.Allocator, target: api.Outcome) ![]const api.Effects
// optional, for screening:
pub const feature_names: []const []const u8 = &.{ ... };
pub fn features(m: *const Model, q: *const api.Query, out: []f32) void
```

- Train: games (start ms, patch, platform, champions by side and role, everyone's
  ranks) and rows (game, side, role, champion, own rank, y per outcome, NaN unknown)
- Query: one player in one game as champ select knows it. No outcomes. Other players'
  ranks are null: keep `scope = .champ_select` (Riot policy: champions, roles, the
  user's own rank, aggregates). Training rows may use anything in Train
- Prediction: all six outcomes; NaN = no opinion (scored as the baseline). Predict
  your target; leave the rest NaN or the baseline's
- Imports: `std` and `api` only. No files, network, processes or asm: the run is
  refused. Threads are fine
- Outcomes: win (row's team), gold14 (total gold at 14:00), lanediff14 (gold14 minus
  the lane opponent's), cs10 (minions + jungle monsters at 10:00), deaths15 (deaths
  before 15:00), first_item (minute of the first finished legendary; censored if never)
- Lane opponent = same role, other side. Champion ids are numbers; no names or class
  tags yet. Ranks: 0 Iron IV .. 39 Challenger I, 4 per tier

## Commands

```
deploy/lab-exp.sh diagnose CAMPAIGN TARGET     where the candidate is biased (dev, free)
deploy/lab-exp.sh screen CAMPAIGN TARGET       each feature alone (dev, free)
deploy/lab-exp.sh run CAMPAIGN NAME TARGET --hyp ID --desc "one change" [--fraction F]
deploy/lab-exp.sh run CAMPAIGN NAME TARGET --hyp ID --desc "..." --select   (costs a look)
deploy/lab-exp.sh finding CAMPAIGN RUN "plain sentence" [effects-NAME.tsv]
deploy/lab-exp.sh table CAMPAIGN | looks | show RUN
deploy/lab-exp.sh effects RUN                  the run's effect tables, to quote in findings
deploy/lab-exp.sh restore CAMPAIGN RUN
deploy/lab-exp.sh stop CAMPAIGN "REASON"
```

A run takes ~2 minutes. RESULT gives the dev gain vs the champion-role baseline with a
95% interval (negative = better), `mde` (the smallest gain this dev set would show), and
for `--select` the ladder's answer: `new-best` or `no-change`, never a number otherwise.
50 selection looks per snapshot, shared with every other campaign. RESULT also gives
`removed` (% of the baseline's error the candidate removes, ± its interval; positive =
better), `error` (typical miss, baseline -> candidate, in gold, CS, deaths or minutes;
for win `accuracy`, the share of games whose winner it calls right, a coin flip 50%)
and `effects` (the effect tables written for the run).

## Findings: what each run learnt about the game

Jacob reads runs for what they say about League, not for loss numbers. After every run
(crashes aside), before the next:

- `finding CAMPAIGN RUN "..."`: one sentence, shown verbatim on the admin page, by
  docs/learned.md's rule: plain English a ranked player would follow, numbers in gold,
  CS, deaths, minutes or percentage points from RESULT or the effect table. No MSE, sd,
  nats, run or hypothesis ids, model, term or column names. Say what it showed about the
  game and how sure (e.g. "within noise"). E.g. "Patch makes no difference to gold at 14
  once champions and matchups are known (within noise)", "A player one tier higher has
  about 120 gold more at 14 in the same matchup (give or take 40)", "Knowing the
  junglers makes the gold-at-14 guess 0.4% better, too small to matter". A null result
  is a finding too. The technical detail goes in digest.md
- When a term is kept, the candidate exposes it in `effects` (rank tier, patch, or the top
  and bottom 10 champions or matchups by effect), each row with a 95% interval and the
  games behind it, in the target's units; name the file in the finding. src/lab/cand/
  team2 has a worked example. `#<champion id>` in a label becomes the champion's name
- digest.md entries carry the same sentence beside the run id

## Your starting point

Your candidate starts as 3c-team2 (src/lab/cand/team2): meiolol-3c's additive team model
(champion, lane opponent, bot partners, junglers, rest of both teams, platform; shrunk,
backfitted) plus the lane opponent's own effect and role x patch.
RESULT's dev diff is against champion-role means, so first run the candidate unchanged
(`run CAMPAIGN ref TARGET --hyp H0`): a change only counts if it beats that run's diff
by more than its interval. Its win prediction is the baseline's: for win, add your own.

## How to work: Box's loop, not brute force

1. **Diagnose** first: `diagnose` names slices where the current candidate is biased
   (flagged = beyond chance for that many slices). The overall level shift is drift
   between older training games and newer dev games
2. **Hypothesise** one mechanism that would fix a named misfit. Write it to
   hypotheses.tsv before running: `H<n>\topen\t-\t<mechanism; slice; expected sign
   and rough size>`
3. **Screen** cheaply: expose the idea as a feature and run `screen`. A feature that
   doesn't clear noise alone rarely helps in a model. If the plausible gain is below
   `mde`, mark the hypothesis `parked` (needs more data), don't run it
4. **One atomic change per run**, `--hyp` set. Keep it when the dev interval excludes
   0, else `restore` the previous best. Crashes: fix at most 3 times, then restore
5. **Check it's general** before a look: `show RUN` slices by role, patch and tier; a
   gain from one slice is a quirk until shown otherwise. For data-hungry ideas run
   `--fraction 0.25` and `0.5`: a gap growing with data is real and data-limited, flat
   near 0 is no effect
6. **Spend a look** (`--select`) only on a dev gain that survived 4 and 5
7. **Numbers by a grid, structure by you**: once the structure is fixed, try a few
   values of a prior strength or L2 in separate runs on dev; scale priors by games
8. Prefer **one shrunk model with several terms** over picking among many similar
   variants
9. Record the run's `finding` (Findings above), then update hypotheses.tsv: status `confirmed`, `refuted` (narrow interval
   around 0), `inconclusive` (wide), or `parked`; list the run ids
10. Every 10 runs rewrite digest.md: what worked and what didn't by run id, each with
    its finding sentence, then the next ideas. Numbers only from the records

Rotate action types (diagnose, follow up a result, new idea, combine two confirmed
ones). Never retest a refuted idea on more data hoping it passes.

## Stop

`stop` with a reason when 30 runs bring no dev gain, when looks run out, or when every
remaining idea is below `mde`. Stopping at noise is a good outcome, not a failure. If
something looks wrong (a huge gain, a harness error, a rule that blocks a sound idea),
stop and say so rather than working around it.

## Never

- Change anything outside your campaign dir, run git, ssh, or `lab-exp.sh final`
- Quote a number that isn't in a RESULT line or `show`/`table` output
- Read or infer selection or test outcomes any other way than the ladder's answer
- Use other players' ranks or any outcome at predict time
- Declare `after_game_rank`: the rank looked up after the game is a human's dev-only leak
  diagnostic; ranks you get are as of the day before the game (null before 2026-10-12)
- Use internal scope for app-facing work: it is Jacob's research predictor only, and its
  results and findings never feed the site or app. App-facing campaigns use champ_select

## Known so far (snapshot 20261012T2055Z)

- Win: nothing beats champion base rates at this volume (docs/model.md)
- gold14: own rank helps (screen r 0.11, dev -0.0067 ± 0.0011); diagnose flags rank
  tiers for champion-role means and for the team model alike
- A 4-run probe from champion-role means: lane opponent effect, then own rank tier per
  role: dev -0.017 ± 0.0016 on gold14; jungler effects and a time trend below mde
- Level shifts on dev-val (EUW1 only, newer than its all-platform training games): for
  cs10 it is region mix (the team model's platform term removes it); for gold14 the team
  model keeps -0.022 ± 0.007 sd, about two thirds of which a per-patch offset removed
  from champion-role means: a patch term is worth trying
- Own rank is champ-select legal, but within Platinum+ it is partly "better players get
  more gold": lesson material ("at your rank, expect X"), not a pick reason
