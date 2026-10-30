# Plan: data and model

Where the data and model go next, and what reaches the site and app from them. Each
step is measured in `meiolol eval` (docs/model.md) before anything public.

## Where the app goes next, with ~800k games

The product stays "scout your own games", with picks as several options with reasons
(docs/production-key.md: no other players' stats in ranked champ select, no "+X% win
rate" wording, no public draft win chance). What the data now supports, and where it goes:

What we know (docs/learned.md "Win"): lane matchups matter most (top and mid ~2 points of
win chance), ally pairs only bot with support; champions lean into team comps beyond
their matchups: 22 clear leans on the shipped model, all about magic damage and
tankiness (Malphite into AP-heavy teams about 1.1 points worse per step, Galio and
Kassadin better; Lillia, Brand, Senna better into tanky teams, Nautilus worse; AD carries
better beside AP allies); champions lean early or late; the draft model still gains with
every doubling of games (no plateau).

In order:
1. Measure the comp leans like the draft model: champcomp's terms as a row in the box's
   daily `meiolol eval` (ported out of the lab into src/, offset the shipped model), then
   one pre-declared held-out look on a snapshot of games after 17 Oct 13:20Z. The same
   look also takes champgroups' six detected kit groups and Rammus jungle into
   auto-attackers (docs/model.md "Kit groups and a property scan": their dev numbers
   are the predictions; rerun `meiolol-lab champgroups` on the new snapshot). Nothing
   public before that look passes. The admin Draft tester has them; its draft and lane
   models refit daily on the box (`meiolol draft-model`, `lane-model`); the comp terms
   still come from the lab (`champcomp --export`, `lab-push.sh use`).
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
7. Data and ops: C01 keeps every game, Megatron is the off-site copy (J31); the PC holds
   the raw archive pseudonymised (~6 GB a day) and a backup mirror; raw timelines (88% of
   the archive) reviewed ~mid January against what the compact timelines lack. The
   production key multiplies all of it

Open for Jacob (decisions.md "Open decisions"): the per-seat stats table; comp-lean
reasons in the desktop app's champ select once the held-out look passes

## A4 shipped (DM1): pair cells that borrow strength

Live: every site view's stats file is the additive v2 draft model (src/fitted.zig) with
each pair cell shrunk toward two parents instead of 0: the same two champions in any
slot of the kind (ally pairs; matchups, signed) and a kit-class pair per block (Data
Dragon tags). `meiolol stats` defaults to it (`--no-pair-prior` for plain v2), as do the
daily eval's and draft-model page's current model. Evidence: docs/model.md "Pair cells
that borrow strength (A4)" and "A4 on the new pin, shipped form". Ally and enemy reasons
under 20 pair games are left out with a fitted model (score.Options.min_reason_games):
a matchup's fitted value can be non-zero with 0 games in that slot.
- Parents fold into statsfile v2's dense cells (fitted.attach): a draft is still 55
  reads, no format or client change. Downloads grew 1.6-3x (gzip packs zero cells, and
  with parents every cell holds a value); if that matters, statsfile v3 with parents as
  their own tables (~120 KB f16) and sparse cells, 3 reads a pair term
- The parent step is guarded: additive.zig halves it until the penalised loss doesn't
  rise (Config.parent_guard), as the lab's diagonal Newton step overshoots where data
  outweighs the prior; the guard is most of the extra fit time
- Revert: src/site/load.zig's `.pair_prior` back to `.v2` (and cmd/crawl.zig's stats
  default, `&.{}` for the classes in eval.zig and draftmodel.zig)

Left:
1. The desktop app: drop deploy/web-loop.sh's strip_fitted, which cuts the fitted block
   from the app's stats.bin; the current releases read v2, so it gets A4 with no release
2. "X counters Y in any role": a new reason the pair parent supports (C5's
   purification: parents vs cells)
3. pipeline_test: build one view with `.pair_prior` (fitted.zig's test covers the file)

Neural nets: docs/plan/lab-frontier.md.
