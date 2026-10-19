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

## Neural nets

Neural nets paused (14 Oct): big, small, set and embedding nets only draw level with
ratings at 2253Z, and research (draft-predictor-methods, gnn-match-outcome) puts the
lever in data volume. Next net run: one rerun of the reference nets on the next re-pin
(due when the crawl passes +50% of 2253Z's 363k played games, ~545k on the box, about
15 Oct), against additive v2 as well as ratings. Big net's test look: not yet. Work
goes to shipping what won (additive v2 in the Draft tester since 14 Oct 21:08, the
in-game state model) and to the production review list.
