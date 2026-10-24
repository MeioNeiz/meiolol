# Plan: data and model

Where the data and model go next, and what reaches the site and app from them. Each
step is measured in `meiolol eval` (docs/model.md) before anything public.

## Where the app goes next, with ~800k games (Jacob, 2026-10-17)

The product stays "scout your own games", with picks as several options with reasons
(docs/production-key.md: no other players' stats in ranked champ select, no "+X% win
rate" wording, no public draft win chance). What the data now supports, and where it goes:

What we know (docs/learned.md "Win"): lane matchups matter most (top and mid ~2 points of
win chance), ally pairs only bot with support; champions lean into team comps beyond
their matchups: 22 clear leans on the shipped model, all about magic damage and
tankiness (Malphite into AP-heavy teams about 1.1 points worse per step, Galio and
Kassadin better; Lillia, Brand, Senna better into tanky teams, Nautilus worse; AD carries
better beside AP allies); champions lean early or late; the draft model still gains with
every doubling of games (54.8% on 17 Oct, no plateau).

In order:
1. Measure the comp leans like the draft model: champcomp's terms as a row in the box's
   daily `meiolol eval` (ported out of the lab into src/, offset the shipped model), then
   one pre-declared held-out look on a snapshot of games after 17 Oct 13:20Z (~24 Oct).
   The same look also takes champgroups' six detected kit groups and Rammus jungle into
   auto-attackers (docs/model.md "Kit groups and a property scan", 18 Oct: their dev
   numbers are the predictions; rerun `meiolol-lab champgroups` on the new snapshot).
   Nothing public before that look passes. Admin Draft tester has them now (17 Oct); its
   draft and lane models refit daily on the box (`meiolol draft-model`, `lane-model`, 17
   Oct); the comp terms still come from the lab (`champcomp --export`, `lab-push.sh use`).
   Blocker for porting them (and for step 2's nightly refit): their champion profiles
   are means of per-player seat stats (damage split, CC, engage, dive, tank, sustain,
   early power) from raw match summaries, which the box keeps ~2 days before the archive
   moves them to the gpu-box; participants holds only the basic columns. Options (for
   Jacob): a per-seat stats table in meiolol.db written at crawl time plus a one-off
   backfill from the archive (recommended: steps 2 and 6 need it too), or profiles from
   the weekly snapshot pushed to the box with the fit daily there (the Mac stays in the
   loop)
2. Champion pages: an "Into which teams" block beside early/late lean: only clear leans,
   plain lines with a range ("about 1 point worse per step towards a magic-damage enemy
   team"), refitted nightly on the box like `meiolol lean`
3. Suggest reasons (app and site draft tool): a comp lean as one reason among an
   option's matchup and duo reasons, only when clear and only champion and aggregate
   statistics, worded as context ("weaker into magic-heavy teams like this one"), never
   as a pick order or a percentage
4. Your games (post-game, own games): "what your draft was up against": the comp leans
   of your own champion in that game, beside the win-chance-by-minute review
5. Daily Draft and Learn: lessons and puzzles built from clear leans and lane matchups
   ("which top laner into this AP-heavy team?")
6. Model work, measured in eval first: separate duo, lane and matchup priors (term
   weights near 1, so shown numbers stay near the data); more traits (range and poke,
   waveclear, scaling) and leans by rank bracket and patch; rerun as games grow (each
   doubling ~-0.0008 log loss)
7. Data and ops (proposal 17 Oct, decisions under Open decisions "Storage and
   hosting"): the box keeps a ~30-day window of games plus per-patch aggregates; the PC
   holds everything, raw pseudonymised (~6 GB a day) and the backups; a Hetzner Storage
   Box (BX11, EUR 3.20 a month) is the off-site copy; raw timelines (88% of the archive)
   reviewed ~mid January against what the compact timelines lack. The production key
   multiplies all of it

Open for Jacob: the storage decisions; whether comp-lean reasons may appear in the
desktop app in champ select once the held-out look passes (policy allows options with
reasons; the app shows champion and aggregate stats only)

## DM1: ship A4, pair cells that borrow strength (Jacob's call)

Done 24 Oct (Jacob's go; 133d11b, live 03:23 UTC): every site view's stats file is fitted
with pair parents, guarded; `meiolol stats` defaults to it (`--no-pair-prior` for v2);
the daily eval's and draft-model page's current model too (eval's `--pair-prior` row
gone). Ally and enemy reasons under 20 pair games are left out with a fitted model
(score.Options.min_reason_games). On the box: the views write refitting all four views
443 s; the core build's EUW 30-day stats load 210 s (206-380 s before). Downloads,
gzip, before then after: EUW 30 days 2.08 to 4.05 MB, EUW patch 1.23 to 3.45, every
platform 30 days 3.08 to 4.68, every platform patch 2.01 to 4.01. The desktop app does
not get it yet: web-loop.sh strip_fitted cuts the fitted block from the app's stats.bin
(v1, counts), due to go now that the 23 Oct releases read v2; dropping it gives the app
A4 with no release. Revert: src/site/load.zig's `.pair_prior` back to `.v2` (and
cmd/crawl.zig's stats default, `&.{}` for the classes in eval.zig and draftmodel.zig)

What: the site's and app's draft model (additive v2 in the stats file, src/fitted.zig)
with every pair cell shrunk toward two parents instead of 0: the same two champions in
any slot of the kind (ally pairs; matchups, signed) and a kit-class pair per block (Data
Dragon tags). Evidence: docs/model.md "Pair cells that borrow strength (A4)" and "A4 on
the new pin, shipped form": in the shipped form (no damage mix, no side term, floor 20 on
a cell's own part, f16) on 521k games no A4 run had scored (snap-20261023T2004Z, dev
only) it predicts -0.99 +- 0.12 milli-nats a game better than today's model, every block
better, both resamples, controls clean; it wins back all v2 lost to its shipping
simplifications (0.84). End to end in `meiolol eval --dev`: -0.0009 ± 0.0002 log loss.
Code is on main behind a flag, off (aefe235); nothing live uses it.

Cost (Mac, measured while a lab run shared the CPU, so times run high; per stats view,
v2 then v2 + parents):

| view | games | time | peak memory | stats.bin gzip |
| --- | --- | --- | --- | --- |
| EUW, 16.21 | 48k | 7.5 s, 11.6 s | 743, 796 MB | 1.0, 3.3 MB |
| EUW, 16.20-16.21 | 354k | 28 s, 43 s | 948, 882 MB | 2.0, 4.0 MB |
| every platform, 16.20-16.21 | 1.56M | 163 s, 363 s | 1.26, 1.62 GB | 3.0, 4.6 MB |

- Scorer: no change. Parents are folded into statsfile v2's dense cells (fitted.attach),
  so a draft is still 55 reads (10 strength, 20 ally, 25 matchup), no format change, no
  client change; the desktop strip (deploy/web-loop.sh strip_fitted) is untouched
- Download grows 1.6-3x: today's floor leaves most cells 0, which gzip packs; with parents
  every cell holds a value. If that matters, statsfile v3: parents as their own tables
  (pair parents 2 x n x n, kit 25 x 27 x 27, ~120 KB f16) and cells sparse; then 3 reads a
  pair term (165 a draft) and the scorer, wasm and desktop change together
- Fit: parent steps add 2 working-residual passes, 4 sweeps over pair entries and a loss
  check per pass. The check (a guarded step, below) is most of the extra time; checking
  only the first pass after each variance update, or a quadratic bound, would cut it

The guard (new in the ship code): the lab's parent step is a diagonal Newton step over
parents that share game sides (a team's 10 ally pairs), so where data outweighs the prior
it overshoots; a dense 12-champion toy ran it to 4 million logits. additive.zig halves a
parent step until the penalised loss doesn't rise (Config.parent_guard; false is the frozen
lab step, equal to pairprior's to 1e-9). On real fits it halves 9-48 of ~170 steps and
scores as the frozen candidate (2004Z's fresh games: -0.98 ± 0.12 against -0.99 ± 0.12). The production key's volume makes the overshoot likelier, so ship guarded.

Steps once Jacob says go:
1. Eval row (`meiolol eval --pair-prior`): run on dev 24 Oct (2004Z, every platform,
   dev-val 161k games): log loss -0.0009 ± 0.0002 against the current model, AUC 0.576
   against 0.572, accuracy 55.3% against 55.1%. On the test window only as a declared P3
   look (`--test-look`), if Jacob wants a test number before switching
2. Switch: src/site/load.zig's `.v2` to `.pair_prior` (and `meiolol stats`'s default),
   so every site view, the draft helper, Daily Draft, Learn, lane cards and app suggest
   score with it; src/eval.zig's buildShipped to pass kit classes, so the daily eval's
   "current model" follows. kitClasses reads the champions table's tags (already there)
3. Box headroom: time one site round on the box with it (deploy/box.sh web status) before
   leaving it on; if the 30-day all-platform view runs long, cut the guard's cost first
4. Reasons and pages: a matchup's fitted value can now be non-zero with 0 games in that
   slot (its parents). Lane cards and suggest reasons that show fitted matchups must keep
   a games floor from the counts; "X counters Y in any role" is a new reason the pair
   parent supports (C5's purification: parents vs cells)
5. pipeline_test: the helper's model file with parents (fitted.zig's test covers the
   file; the site pipeline test should build one view with `.pair_prior`)

Where to start: src/fitted.zig (Fit.init classes, attach's dense loop), src/stats.zig
(Fit, kitClasses), src/additive.zig (Parents, the guard in fit), src/eval.zig
(Options.pair_prior). Blocks: Jacob's go; the P3 look if he wants a test number first.

## Neural nets

Superseded as the programme by docs/plan/lab-frontier.md (21 Oct); below is the 14 Oct
state.


Neural nets paused (14 Oct): big, small, set and embedding nets only draw level with
ratings at 2253Z, and research (draft-predictor-methods, gnn-match-outcome) puts the
lever in data volume. Next net run: one rerun of the reference nets on the next re-pin
(due when the crawl passes +50% of 2253Z's 363k played games, ~545k on the box, about
15 Oct), against additive v2 as well as ratings. Big net's test look: not yet. Work
goes to shipping what won (additive v2 in the Draft tester since 14 Oct 21:08, the
in-game state model) and to the production review list.
