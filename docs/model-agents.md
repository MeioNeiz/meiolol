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
| meiolol-db | win / draft predictor: experience feature (internal scope), everything-pre-game model with per-champion skill slopes, sub-15:00 with/without test on dev |
| meiolol-ff [f6a37d] | winchance weights fix (live Your games bug), clustered playstyle intervals (both free now; tell 47 when the playstyle/logreg commit is in), bootstrap bounds (wait for 47's all-clear) |
| meiolol-6f | GPU vs CPU benchmark (bench1 done at 16x; 1x/4x, sweeps, deep draft net pending), then field ranking, then playstyle clustering |
| meiolol-12 | lab harness and campaigns, from meiolol-39 (gold14-a final queued behind 6f's bench2, Jacob authorised; cand/team removed; brief fix waits on db's hunk) |
| meiolol-0d | admin page: Models tab, Draft tester (live), suggester lane and blind lists next |
| meiolol-11 [1f36a8] | box, archive operation, rows.zig, snapshots (weekly Sun, first 19 Oct), mastery for all players, flex sample |
| meiolol-47 | overnight code review, shared analysis-module refactor (holds outcomes, items, objectives, scaling, eval until its src/analysis.zig commit, ~02:30) |
| meiolol-82 | Riot application text (drafted; waits on Jacob: ownership, privacy.md 24-month retention, meiolol-ef's deploy) |

Two sessions can share a name: message by the `from=` socket or the `[ref]` ListAgents
shows (meiolol-ff [2c6351] and meiolol-11 [b35536] are unrelated chats). When an agent hands over, get the successor's name and tell the others.

## Rules given to every model agent

- Shared protocol in docs/model.md: one hashed snapshot, eval's time split, test touched
  once per model; choose variants on dev; gains with paired intervals clustered by game
- Label train-time and use-time features; champ-select models use only champions,
  roles, the user's own rank and experience; `internal` scope (Jacob's predictor) may see
  all ten players' pre-game data and never feeds the site or app
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
- Results to collect: gold14-a final (12), sub-15:00 verdict (db), experience and
  everything-pre-game (db), GPU table (6f), winchance fix (ff), mastery and flex live
  with matches/day before and after (11), next snapshot pinned in docs/model.md
- meiolol-58's solo/duo lookup commit: Jacob must type "commit" in its window (pane
  657); meiolol-11's mastery crawl.zig commit waits on it
