# Model agents: how the modelling work is run

The coordinator session's handbook. Jacob decides; the coordinator keeps the model
sessions agreed, unduplicated and inside policy, collects questions for Jacob with a
recommendation, and records results. It does not model itself.

Where things live:
- Results and method: docs/model.md ("Shared protocol, 2026-10-12" first, then dated
  sections). Plain findings: docs/learned.md (wording rule in its header). Decisions and
  next steps: docs/plan.md "Draft model". Research: research/questions/
  draft-predictor-methods.md (honest draft-only ceiling, levers in order)
- Compute: docs/compute.md (gpu-box, lab-run, snapshots). Lab: docs/lab-agent.md,
  docs/lab-brief.md. Data fields and retention: docs/fields.md, docs/data-safety.md
- Admin Models tab and Draft tester: https://meiolol.jomify.lol/admin/#models/all and
  #models/draft (admin only)

## Goals (Jacob)

- App and site: learning-first lessons with intervals for ranked climbers; claims
  limited by docs/learned.md "Site:" lines and docs/production-key.md (champ select
  never uses other players' stats)
- Personal: the best League draft predictor (internal). Honest target: beat ~53-54%
  draft-only on a time split; with pre-game player features 55-57%. Report both our
  time split and a LoLDraftAI-style random split for comparison

## Sessions and what they own (2026-10-13 ~01:10; names change on handover)

Coordinator: meiolol-78 (from meiolol-cf, 2026-10-13).

| Session | Owns |
| --- | --- |
| (none) | win / draft predictor rerun: closed (meiolol-db done 2026-10-13); new session when the coordinator pins a snapshot with ~a week of rank_history and pre-game mastery (model.md Next steps) |
| meiolol-ff (closed) | review fixes done: winchance smooth weights (live), playstyle clustered intervals, bootstrap bounds (31338cb) |
| meiolol-3f (closing) | playstyle clustering done (47fdfb2, 57d50d0): beyond the full 14:00 state style adds almost nothing; types and sequence net not detected |
| meiolol-12 (closing) | lab harness: rank_start done (9eb6982, after_game_rank dev-only gate); campaign plan in model.md Next steps; fresh lab session at the pin |
| meiolol-0d (closing) | admin Models tab, Draft tester: lane, blind and draft lists live with the 1% role floor; last check: Models tab renders struck lines |
| meiolol-11 [1f36a8] | box, archive operation, rows.zig, snapshots (weekly Sun, first 19 Oct), mastery for all players, flex sample |
| meiolol-47 | overnight code review; shared src/analysis.zig refactor committed (3324cd3..c2b1a73), all analysis files free |
| meiolol-82 | Riot application text (drafted; waits on Jacob: ownership, privacy.md 24-month retention, meiolol-ef's deploy) |

Two sessions can share a name: message by the `from=` socket or the `[ref]` ListAgents
shows (meiolol-ff [2c6351] and meiolol-11 [b35536] are unrelated chats). When an agent hands over, get the successor's name and tell the others.

## Rules given to every model agent

- Shared protocol in docs/model.md: one hashed snapshot, eval's time split, test touched
  once per model; choose variants on dev; gains with paired intervals clustered by game
- Label train-time and use-time features; champ-select models use only champions,
  roles, the user's own rank and experience; `internal` scope (Jacob's predictor) may see
  all ten players' pre-game data and never feeds the site or app
- Snapshot: snap-20261012T2055Z stays pinned for all work in flight (gold14-a, db's
  models, ff's checks, 6f's bench), so results compare. A new weekly snapshot is a new
  game set: start new models on it only once the coordinator pins it in docs/model.md,
  and rescore any reference model on it before comparing. Re-packs (SNAP/pack/) never
  change rows; code changes can
- Both sides of a paired comparison from the same build; rerun the older side if a
  pair straddles a numeric change. The gpu-box x86_64_v3 switch (516fce3) is not one:
  byte-identical output (strict float mode), 2x faster
- An effect table from the train fit is not a test result, however clear: per-effect
  claims in learned.md need the effect to hold on held-out games (test refit with
  train-derived features, or a pre-declared test), with train vs test side by side
- Condition on game state for items, objectives, playstyle (teams ahead buy and take)
- Rank in participants is post-game (leaks); rank at game start comes from
  rank_history (from 12 Oct, so later snapshots)
- Don't declare exclusions or effects without a measurement (Jacob, via meiolol-47)
- learned.md lines in plain English first; commit by path only, new files with their
  first import; pre-push CI must pass (one failing commit blocks every push)
- Hand over past ~40% context with a focused brief; tell the coordinator the new name
- gpu-box: check League isn't running; lab runs queue on ~/ml/locks

## Open, waiting

- Jacob: none pending at handover
- Collected: gold14-a final (rank on 3c-team holds on test at half dev size, learned.md
  e4f8335; recheck with rank at game start and on team2 in the next campaign)
- Collected: sub-15:00 exclusion makes no detectable difference (db, 289f63a; kept);
  champlevel shrinkage no gain on dev (12, 3b28e60): off-role lane cells are real
  farming, the Draft tester's 1% role floor is the fix
- Collected: draft predictor test finals (db, 1abb887): champions only 53.2%,
  everything pre-game 54.5%; skill slopes not detected; stored rank leaks
- Agreed: meiolol-12's rank-at-game-start campaign (model.md Next steps); harness work
  now, campaign on the pinned snapshot
- Collected: GPU vs CPU (6f, ccfbd95, docs/compute.md): deep draft net on the 3080
  (3.9x at 175k games, ~11x from 2.8M); fm and additive models on the CPU (sweeps tie)
- Collected: winchance smooth weights (ff, 6c7d50d; ties per-minute refit on test, jump
  from weights 19.2 -> 4.4 pp; ff installs the jomove API binary); playstyle clustered
  intervals (8c84735, about the same width)
- Collected: field ranking (48, d94c875): champ-select fields don't move win, do move
  early outcomes (association); early stats add <0.5% beyond 14:00 state; kit and
  lane opponent explain much of skillshot/CC/ward stats
- Jacob: keep the five champ-select fields in compact rows? (recommended: yes)
- Collected: bootstrap upper bounds (ff, 31338cb): comeback slope per champion under
  ~2-4.5 pp per 1000 gold (4-7 pp from 2k behind at 15:00), so "not detected", not
  ruled out; team counters and champion x item bounded in model.md
- Jacob: may a session check Your games live with a Riot ID (his own)? If yes, fresh
  session checks the win chance turning minute live
- Collected: playstyle (3f): b0's 8 style +0.00020 ± 0.00011 on test with objectives in
  the state (half the gold/XP-only gain); clusters, components, net not detected;
  train-fit leanings didn't hold on test, dropped
- Collected: mastery for all participants live (11, 170e409, 02:16Z): matches/day
  127,914 before, 130,215 after; catch-up ~2.5 days, then ~25k mastery calls/day
- Collected: flex sample live (11, 0a4a787, 02:41Z, --flex-calls-per-day 500): 27 EUW1
  games in 45 min, isolation tested, solo matches/day unchanged (~130k); mastery_pre
  (b424a24) in snapshots from 19 Oct
- Results to collect: flex games per full day (11, 14 Oct; lever is the cap), next snapshot pinned in docs/model.md
- Admin follow-ups for the next admin session (0d, not done: admin.js held by
  meiolol-9f's Your games proxy edits): All-view cards take a category's first two
  learned.md lines in file order, so replacement lines can hide newer ones; stable-sort
  by leading date newest first in learnedList's short mode before slice(0, 2), don't
  reorder learned.md. Run detail fetches metrics.tsv for every run (404s on runs
  without one); lab-push.sh lists it in runs.tsv, runDetail fetches only when listed
