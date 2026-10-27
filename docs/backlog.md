# Backlog

Open next steps by area, older than the docs/plan/ area files. plan.md "Now" ranks what
matters; this is the pool it draws on. Move an item into its docs/plan/ area file when
you pick it up, and delete it here when done (the commit is its record). Some may be
overtaken: check the code and git log before acting.

## Ops and data

- Storage, off-site backups and a rolling window: docs/plan/ops.md "Storage and hosts"
- Lossy timeline compaction, if disk gets tight
- Crawl pages per match, untested: `--no-participant-players` and dropping the
  participants_puuid index (only `forget` reads it); deploy/bench-crawl.sh with
  `--no-mastery` on a scratch copy
- Rank at game time for participants and drafts from rank_history (not wired)
- Smart timeline picking (only matches with an under-sampled lane matchup) adds only
  +2-12% matches today, since 77-95% of matches still need one: revisit with the
  production key, when matchups saturate
- Oracle box loose ends (it is stopped since the move to C01; moot if terminated): one-off `meiolol rebuild` for
  the gold10/14/15 migration; remove OCI dynamic group meiolol-box, policy
  meiolol-box-launch and service meiolol-a1-launch; remove gpu-box ~/.ssh/migrate_cloud
  and its pubkey from meiolol-cloud's authorized_keys; jodrive oracle login's enrolment
  path is untested (don't rerun it); stale vault group jodrive/oracle (old TOTP): Jacob
- Disk scheduler: mq-deadline is set at runtime only (docs/hosting.md); persist it with
  a udev rule only if crawler and batch jobs do no worse

## Your games and Squads

- Extras: experienced-players curve, flex/normal once curves cover them, rank at game
  time
- Friends: architecture.md's api/ list
- Squads (concept part 4), design agreed: join by profile-icon challenge (purpose=join),
  leave any time; api.db squads/members; private invite-link pages, noindex, Riot IDs
  visible to the squad only; games together by intersecting members' match ids; queues
  420/440/400/450/900/700/1700/1750 (not Mayhem 2400); lane awards on Summoner's Rift
  only; weekly recap on read with curve awards; squad Daily Draft needs a score endpoint;
  Discord PNG via canvas; coach kind = roster + weekly review + chart export; refresh
  on visit at most every 30 min
- Short games (under 15:00, remake=0) are early surrenders after a leaver, real
  results: an ended_early flag for stats and models needs an owner
- Then, in Jacob's order of interest: spike window, level spikes, counter-item timing,
  builds that worked, tilt check, snowball vs comeback, pool health, baron calls,
  sidelane, fingerprint, role lenses, pre-game brief (desktop), squad scouting
- Record book: full history only on request by the account owner (icon check), kept
  while used; needs privacy.md text

## Curves, matchup pages, Patch day

- Brackets for a Platinum IV+ crawl: Iron-Silver is near empty and Gold-Emerald mostly
  Platinum-Emerald; maybe Platinum-Emerald, Diamond, Master+ (Jacob)
- Estimator checks at 291k games (keep in mind before changing it): within-player
  correlation of gold@14 in a matchup 0.007-0.04 (design effect under 1.015, ignored);
  16.19 to 16.20 moved matchup means by sd ~44 gold against a spread of 476 (patch decay
  deferred to a big patch); tau^2 smoothed across minutes not picked by split-half in 13
  of 15 role-metrics. Thin pairs sit at the other half's noise, so an embedding prior for
  them can't show a split-half gain
- Old patches' curves files are never deleted (226 + 350 MB a patch on the box)
- Champion comeback rate (patchday.zig computes it) unused on the page
- Learning curves: read participants.gold14 instead of their own timeline pass
- Champion shape labels (lane bully / scaler / spikes at 6 / even) from curves, rule on
  the method page
- Daily Draft "easy daily" for new players

## Builds

- `meiolol builds` reads ~7.5 ms a game (disk), so a full patch at volume takes hours:
  aggregate each day's games once and merge before volume grows
- Builds by matchup once pairs reach volume
- A nav entry for builds only if Jacob wants them that visible (the application text
  does not mention builds)

## Learn

- Counters lesson: our own learning-curve numbers instead of the Reddit 44% vs 51.5%
  once learning points exist
- Practice difficulty: add the lane-curve sign (laneBehind() in src/learn.zig) once pairs
  reach 200+ games; re-check lesson examples at 20k+ patch games
- If the draft model shows real lift: model reasons below 50 games, Medium graded on spread

## Draft model

The programme is docs/plan/lab-frontier.md and docs/model.md "Next steps"; check them
before picking up these older ones:
- Experience term (src/experience.zig): rerun at 300+ train / 100+ test per variant; if
  "user only" beats no-experience beyond its interval, wire it into recommend() as the
  "your pool" reason (wasm `pool` field). Mastery is a post-match snapshot and flatters
  it; history-based numbers are the honest ones
- Lane gold at 14 (lanegold.zig): reports from 500 train / 100 test with timelines; if it
  wins, champion and pair gold into the model file (statsfile v2)
- empiricalPriors as default once it gains at volume; then comp features, rank brackets

## Site build and deploy

- Screenshots or a short video for the application (Riot accepts them, research C1)
- `--index-min-games` reaches neither the views file nor meiolol-render's flags; it must
  before `--public`. Indexing is to be decided on evidence of what gets clicks, not just
  a game floor (Jacob)
- Prerender the most visited pages into the static upload, only if render latency shows
  in traffic
- Counts stored, derived on reading: each part's tally code in its own file (the key
  covers only it); the views file keeps the raw tallies (pool's n x n mains, the
  spread's 101 bins a champion, learning's bins, the filter cells: ~1 MB plus the cells)
  and pool, spread, learning and filter JSON are made from them as the renderer reads it
  (milliseconds). A change to how counts become pages then changes no part key: a 2 min
  code swap. Then incremental counts for the routine refresh (filters and stats by day,
  a sliding window; player-history tallies would need per-player state, ~2.7M players),
  and refresh scaled by how much pages change or are visited (Jacob)
- The core build could need no database if the home page came from the renderer

## Code safety

- Run the lab tests in Debug or ReleaseSafe before long runs (both silent memory bugs so
  far were in ReleaseFast lab code); keep shipped binaries ReleaseSafe (ReleaseFast is
  ~15% on `meiolol eval`, box jobs are disk-bound). A proven CPU-bound box loop gets
  `@setRuntimeSafety(false)` locally, not the binary
- Rate limiter records a request into several windows one after another: an OOM midway
  leaves some counted. Reserve first, then infallible updates (docs/zig/memory.md 5.7)

## Ideas not started

Jungle routes and gank timing from positions; region styles (KR vs EUW per matchup);
Daily Draft modes ("which line is Darius?", "did the lane winner win?"); matchup
flashcards with spaced repetition; season "lane story" share cards.

Daily Draft with real pick order: match-v5 has none, but the app's champ select watch
sees the LCU session's real turns. With consent, keep the order (anonymised) for app
users' ranked games and draw puzzles from them: hide the real last pick, replay the real
order. Never stage a made-up order meanwhile (Jacob ruled it out).
