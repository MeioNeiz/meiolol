# Plan

Updated 2026-10-11 (end of the first multi-session day).

## Goal now: production key

Product: "scout your own games" (docs/concept.md "Identity draft four", Jacob
2026-10-12; replaces "learn your lane"): the player's own games first, as stats nobody
else shows (game rewind, highlights and on-request record book, scouting report, matchup
notebook, pre-game brief, squads), with the minute-by-minute matchup curves as the
benchmark; Daily Draft, Learn, Pool kept; picks only as several options with reasons.
Crawl is Platinum IV+ only, so "typical" means Platinum+. Research behind it in
research/questions/ (josearch). Production application started by Jacob 2026-10-11 (text
in docs/production-key.md); review takes 3-9 months, Riot looks at the site at review
time, so keep building and keep the site up. Don't edit the application while it queues.

## How we work

Several Claude sessions in parallel, all on main in the one checkout (Jacob,
2026-10-11: no more branches or worktrees). Commit only by explicit path (`git commit -m
... -- <paths>`): the index may hold another session's staged work. Every push to main
deploys to the box (deploy/box.sh builds from a clean checkout of the commit; history in
ml/meiolol/DEPLOYED), so the pre-push hook runs `zig build ci` on a clean checkout of the
pushed commit first (CLAUDE.md). Push the tested commit by sha, `git push origin
<sha>:main`, never `git push origin main`: over HTTPS git re-reads main after the hook,
so a commit another session makes during CI goes out untested (055b97d, 2026-10-12).

Until the site goes public (Jacob, 2026-10-11): sessions merge, push and redeploy the
preview site and box binary without asking. Still ask first: anything irreversible
(deleting data, key or registration changes, Riot applications), nginx/systemd changes on
the jomove server, changes to Jacob's Mac. Live DB migrations: backup and rehearsal on a
copy first.

Jacob's standing asks: the coordinator reviews regularly for gaps nobody owns (risks,
safety nets, doc requirements with no work behind them) and hands out work. Close a
session once it passes ~30% context: it commits, reports done/next/questions, and its
next steps land here.

Team size (lesson of the 13-14 Oct night, ~60 sessions, 396 commits): 4-5 agents at
once. Beyond that, coordination ate the gain: name clashes, a whole snapshot's runs
voided by a mid-night re-cut, the gpu-box at load 41-58 on 20 threads (jobs 5-10x
slow), by-path commits sweeping in other sessions' hunks. Fix the split and pin before
starting runs on a snapshot, not during.

Neural nets paused (14 Oct): big, small, set and embedding nets only draw level with
ratings at 2253Z, and research (draft-predictor-methods, gnn-match-outcome) puts the
lever in data volume. Next net run: one rerun of the reference nets on the next re-pin
(due when the crawl passes +50% of 2253Z's 363k played games, ~545k on the box, about
15 Oct), against additive v2 as well as ratings. Big net's test look: not yet. Work
goes to shipping what won (additive v2 in the Draft tester since 14 Oct 21:08, the
in-game state model) and to the production review list.

## State (2026-10-11 ~04:15 BST)

- Keys: personal app MEIOLOL (890240), key in .env (`jodrive riot key --app 890240
  --env-file .env`), no expiry. New key = new PUUIDs (players re-seeded). Dev key, if
  ever needed: standing ok to regenerate (`jodrive riot key --regenerate --submit
  --env-file .env`, captcha in a window, old key dies at once, new one live in ~2 min)
- Box moved off the gpu-box PC to Oracle Cloud (2026-10-11 ~05:30 BST, docs/hosting.md):
  stopgap 1 GB micro `meiolol-cloud` until A1 capacity (retry loop running); crawl.args
  is plain `--reserve 20` (default raw windows, 30 d / 7 d); first backup there 04:00Z 2026-10-12, on its own
  disk only (no migrations, f90a5ad; no second run on restart); off-host target: Jacob;
  gpu-box data + D: backup kept as the restore point. Crawler stable since 7320adf
  (migrate once per process) but slow: ~11k matches/day (gpu-box ~135k), 153 lock
  waits in 27 min, europe 0 timelines in that run; the 1/8-OCPU micro (~20% steal, slow
  disk) with 19 writer threads is the bottleneck. A1 launch retry now runs on the box
  (systemd user service meiolol-a1-launch, instance principal, ntfy on success)
- Crawler (box, deployed 6f6b65b): all 15 platforms, 4 regional buckets at their caps,
  ~33k matches + timelines/day per region (europe EUW-first), compact timelines
  (timeline.db, ~8.5 KB/match), raw summaries kept 30 days, raw timelines 7, compact
  mastery, participants with items/runes/rank snapshot/gold10/14/15. Privacy in the
  crawler: 30-day unseen expiry, players Riot 404s deleted, PUUIDs blanked after 24
  months, plain-PUUID `forgotten` honoured. Per-match errors non-fatal
- Site (https://meiolol.jomify.lol, preview mode, riot.txt served): "Learn your lane"
  landing, matchup curve pages (empty until timelines accumulate), Daily Draft, Learn
  (lessons + practice drafts), Pool, learning curves, comeback odds, method page. Win-rate
  edges gated by game counts (draft-model thresholds)
- Your games live on jomove in preview (`meiolol api`, /api/ behind basic auth, 30-day
  retention; docs/your-games.md). Built, not wired: Patch day core (src/patchday.zig); data safety (`meiolol backup|restore|forget`,
  deploy/health.sh) running on the box (meiolol-backup, meiolol-health)
- Draft model (docs/model.md): at ~8k games nothing beats champion base rates beyond
  noise; daily eval on the box appends data/eval-history.tsv
- Legal drafts: docs/legal/ (privacy, terms, LIA, objection form), waiting on Jacob
- Desktop app: lane card window built (meiolol-desktop.exe, dvui dx11, 2026-10-12),
  checked only as PNGs from the raster backend; never run on Windows or against a real
  champ select
- Disk: the micro has ~40 GB free; ~1.6 GB/day kept forever at the full all-region rate:
  weeks. A1 (up to ~150 GB free), EUW-only or paid disk (PAYG): Jacob's call

## Next steps

### Ops and data (was meiolol-de, data-safety-af)

- Data safety is on main (fad705a; docs/data-safety.md): start the box backup loop (D:)
  and health loop (ntfy): running on the box since ~04:20. Mac launchd notifier: Jacob's
  call
- Backup loop: pull exchange/forgotten.txt from jomove, push box-forgotten.txt
- Measure real per-match sizes after a day; recheck disk runway
- Rekey translation (done 2026-10-12, src/rekey.zig): `meiolol rekey` carries
  `forgotten` and Your games `blocked` over (old PUUID -> Riot ID -> new PUUID, both
  keys, Riot ID never stored), in one transaction with the crawl-state clear; stops
  if the keys share encryption. Runbook: docs/data-safety.md "Key switch". Next: when
  the production key arrives, `rekey --dry-run` with both keys tells whether Riot
  linked the apps; Jacob: delete pre-switch backups (gpu-box, old snapshots) after?
- 429 storms (done 2026-10-12): a request that gets 429 on all 6 tries is RateLimited,
  left pending with no attempt counted, and a player scan it cuts short is not marked
  checked (that skipped their games since the last scan). A writer Sqlite error counts an
  attempt instead of failing the match at once. The box's 32 failed matches (all "not
  stored: Sqlite" from 2026-10-11 04:4xZ) requeued by hand
- Optional: lossy timeline compaction if disk gets tight
- Four-view site (region EUW/all x period 30 days/patch, 9096d0f): check
  /all/patch/index.html goes live after a full web-loop pass on the micro (10+ min, any
  restart starts it over); measure site size (~2x, est. ~400 MB), upload time, disk
- Check europe's EUW1-first scanning holds on the new host (players.matches_checked_at
  by platform, region europe)
- Crawl speed (meiolol-83, 2026-10-11). Ceiling on the free key: 20/1 s + 100/2 min
  per routing value; matches + timelines use the 4 regional buckets, ~2.13 calls per
  match, so ~130k matches+timelines/day all regions at 5% reserve (~33k/region; the
  gpu-box did 135k). More keys for one product is against policy; the production key
  is the only way up. The micro's limit is random disk I/O (~200 reads/s, 40-90% steal),
  not the key: 43 GB written + 32 GB read in 4 h for ~2k matches with 19 writers.
  Done and deployed (e6d3841, crawl.args `--reserve 5 --no-mastery --raw-timeline-days
  0 --raw-match-days 3 --keep-days 60 --ladder-per-hour 20`): one writer thread
  (merged worktree-writer), done rows leave the queues, chunked prune in the writer,
  linger, WAL cap, page counters in the report, weekly ladder refresh skipping unchanged
  rows, per-platform ladder cap. Bench (deploy/bench-crawl.sh micro, fake API): 150k vs
  56k matches/day at minute 3 vs the old 19 writers, no busy waits.
  EUW-first gate (d315740, deployed 10:47Z): other regions and mastery pause while
  europe's slack (rate-limit waits + idle) is under 10%, resume at 30%; ladder keeps
  --ladder-per-hour. First 8 min: others paused, europe 160m 134t (~29k/day, cap ~33k),
  slack 16%, disk ~360 r/s at ~50% util. Ranks table (eb173b0: ladder writes ranks by
  PUUID hash for everyone, players rows only for 1 in --player-sample N; old 8.9M
  players rows expire via the 30-day prune) deployed after it with `--player-sample
  16`. Next: watch the report's "others", "priority slack", "writes N in M commits" and
  "pages written/read" per match; once slack stays over 30% the other regions run.
  If ladder still dominates, lower --ladder-per-hour. 14 min after ranks (11:13Z): disk
  ~9 r/s, <1% util (was ~360 r/s); europe ~34k/day (at cap), others on, each ~20k/day,
  total ~95k/day; slack swings 16-30% (120 s window), gate never re-closed. Disk
  runway: ~1.1 GB/day kept at this rate x --keep-days 60 = ~65 GB vs 37 GB free on the
  micro: full around early November unless A1, PAYG disk or a shorter --keep-days.
  11:09-11:33Z: all four regions at the key's cap (~31-33k/day each, ~128k total),
  load 0.08: the key is the bottleneck now. Not tested yet: --no-participant-players and
  dropping the participants_puuid index (only `forget` reads it): bench round
  scratch-only, rerun deploy/bench-crawl.sh with --no-mastery for pages/match.
  Before ~2026-11-25 (first matches pass --keep-days 60): per-patch aggregates kept
  forever and Pool learning curves on them, or raise/drop --keep-days. `meiolol status`
  read-only since 2026-10-12 (src/status.zig): no migration or write lock, estimates (~)
  for players (1/16 PUUID sample, within 0.2%), participants (10 per match), timelines
  and drafts (rowid range); `--exact` counts every row. On the A1 with the crawler
  running: 0.3-1.4 s, ~0 writes (was 1.5-5.5 s, 1800 blocks written, and once 478 s
  waiting on the writer); --exact 1.4-2 s. ranks and rank_history from a 1/64 key sample
  (ranks within 0.6%), plus rank_history rows for the newest 3 days
  Crawler rework on the A1 (6401336, 5298abe, 2026-10-11 ~20:30Z): slack gate gone (it
  kept the other regions off for ~1.5 h after each restart), EUW first via its region's
  queues and the writer's queue (others wait at half full); RegionCrawler and
  PlatformCrawler. crawl.args now `--reserve 20 --timelines 50` (EUW keeps every
  timeline): the reserve only applies for 10 min after another process shows in Riot's
  fixed-window counts (tested: 3 manual calls, europe reserved within 1 s, no false
  alarms), requests paced evenly. Measured 20:36-20:46Z: every region ~50 req/min (was
  ~47), still 1:1 timelines while the old 100% backlog drains (~300-460 per region).
  Expect ~33k EUW + ~43k per other region, ~160-170k/day. Europe's 7.3k older EUW
  timelines only drain when EUW runs out of players due (in practice never)
- Keep more data (Jacob, 2026-10-11): deletion was for the micro's disk, not by choice.
  On the A1: `--keep-days 0` (matches, rows, compact timelines forever, ~1.4 GB/day at
  ~120k/day), raw summaries 30 days and raw timelines for a 10% sample over 30 days
  (~50 + ~26 GB): Jacob will run the model over every field to choose what the compact
  rows keep forever, so the raw window has to hold all of them first; older segments and backups to an off-host Storage
  Box once local disk fills (Jacob to order; or paid OCI disk). Privacy rules stay:
  PUUIDs blanked at 24 months, forget, Riot 404 deletes
- Rank history (Jacob, 2026-10-11: keep ranks): done 2026-10-12. rank_history (puuidKey,
  day, rank, lp, wins, losses) gets a row when a ladder sighting differs from ranks
  (which now keeps lp/wins/losses too); same-day changes replace that day's row. Goes 24
  months after a player's newest row (privacy.md), removed by forget, in backup segments
  by whole day. docs/architecture.md Storage. Rehearsed on a VACUUM INTO copy of the
  live DB: migration 3 s; 5.39M ranks rows as history = 141 MB. With 12 h ladder
  refreshes expect ~1-1.5M rows/day, ~15-20 GB a year (plan said 2: weekly refresh).
  Next: measure the real rows/day after a day (`SELECT day, count(*) FROM rank_history
  GROUP BY 1`) and fix the estimate in architecture.md; rank at game time for
  participants/drafts from it (not wired). Open for Jacob: backup segments are kept
  forever, so their PUUIDs (participants) and rank_history outlive the 24 months
  (segments need the same sweep); history under old keys after a rekey can't be
  forgotten by PUUID (it ages out in 24 months)
- Tier floor (Jacob, 2026-10-11): only Platinum IV and up, every region. `--min-tier
  PLATINUM` stops the ladder walk and filters the scan pool; ladder cap raised 20 -> 40
  an hour so the weekly refresh reaches Platinum IV (at 20 it restarted at the top
  around Platinum II). Sub-Platinum players rows expire via the 30-day prune. Kept
  2026-10-12 (Jacob: "for now plat plus only") although the identity targets Silver to
  Emerald: models and curves describe Platinum+ games. Smart
  timeline picking (only matches with an under-sampled lane matchup that can reach 100+
  games this patch) simulated on 16.19-16.20 EUW picks: 77-95% of matches still need
  one, so only +2-12% matches; revisit with the production key, when matchups saturate
- Newest patch only (Jacob, 2026-10-12): `--patch-only` starts match ids at each
  platform's first game seen on its newest patch; older-patch matches get no timeline.
  Before: ~2/3 of fetched matches were 16.19 four days into 16.20 (first scans take 14
  days). Active first (research/questions/crawl-discovery.md): 54% of 90 random EUW
  Plat+ ladder players had 0 games on 16.20 after 5 days; over ~20 h, 131 of 160 had
  none, and ladder wins+losses growth matched their new ids for 156 of 160. So players
  are scanned most-new-games-first by ladder growth since their last scan
  (players.games_checked, index players_new_games), then never-scanned/stalest as
  before; ladder refreshed every 12 h (--ladder-refresh-hours 12, --ladder-per-hour
  500; EUW1/KR ~4.7k Plat+ pages) on the otherwise idle platform buckets. Report shows
  `Nids Mnew` per region: watch new ids per ids call (was ~0.5 per call on rescans)
- Box ops loose ends (meiolol-5a): cut crawl.args raw windows once disk matters, after
  the writer fix (first prune is heavy on the micro); one-off `meiolol rebuild` for the
  gold10/14/15 migration, not run (do it on A1); once on A1 remove the dynamic group
  meiolol-box, policy meiolol-box-launch and service meiolol-a1-launch; after the move
  settles remove gpu-box ~/.ssh/migrate_cloud and its pubkey from meiolol-cloud
  authorized_keys; jodrive oracle login: enrolment path untested, don't rerun it; stale
  vault group jodrive/oracle (old TOTP), forget or re-import: Jacob
- Storage plan (research/questions/free-hosting-storage.md, C18/C19), if Jacob agrees:
  `meiolol prune` keeps a rolling window of match rows + compact timelines on the box
  (60 days to start), per-patch aggregates kept forever, Pool learning curves moved onto
  them; older segments and daily backups off-host, encrypted (rclone crypt, file per
  file so `forget --backups` scrubs still work), to a Hetzner Storage Box
- Draft table kept forever: done 2026-10-11 (docs/architecture.md Storage,
  src/store/draft.zig). `drafts` in meiolol.db, one row per complete ranked game, 74
  bytes measured (10M games ~0.7 GB): platform, queue, patch, day, median rank (5+
  known) and count known, blue win, 10 x champion + role, bans, length in minutes. No PUUID, Riot ID, match
  id or start time; forget leaves it alone (docs/data-safety.md). Written by the writer
  when it first inserts a match; in backup segments by id range; `meiolol status` counts
  it and the backfill list. Why kept: synergy and good-pick models need 1-3M games (5M+
  for a LoLDraftAI-level model, ~55-56%) pooled over 2-4 patches; ±2 pp needs ~2,400
  games per cell (common pairs ~500k games, typical ~3M); one model with rank as input.
  Next:
  - Live since 15:01Z (crawler restarted on 65123e9; drafts rows arriving, ~95% with a
    rank). A push does not restart the crawler, and the web loop's first open had made
    the table while the old crawler still ran, so with it stopped every match was
    listed again (drafts was empty): 35,944 matches in draft_backfill
  - On A1 after the move (not on the micro): `deploy/box.sh run draft-backfill` once
    (chunks of 200 with 1 s pauses, resumable). Until it finishes the `--keep-days`
    prune skips listed matches, so run it before 2026-11-25. Check `meiolol status`:
    draft_backfill 0
  - Move stats/eval onto `draft.Reader` once the window drops games they need (eval's
    lane gold and experience sections still join per-match data by match id)
  - Game length (Jacob: yes): `minutes` column, u8 capped at 255, 74 bytes a row. The
    first binary with it adds the column, empties drafts and lists every match again
    (all rows' matches are still stored), so the backfill rewrites them with a length;
    rehearsed on a copy (2,182 rows rewritten, no NULLs). Restart the crawler on it
    after the A1 move so its rows carry the length
  - Open (Jacob): matches stored before the ranks table have no
    participants rank, so their rows have no rank: fall back to the current ranks
    entry in the backfill?

### Your games and Squads (was your-games-e0)

- Done 2026-10-11: jomove deploy, basic auth on /api/, crawler --reserve 20 default,
  index link, privacy section, Riot IDs out of client logs
- Extras: experienced-players curve, flex/normal once curves cover them, rank at game time
- Squads (concept part 4), design agreed: join by profile-icon challenge (purpose=join),
  leave any time; api.db squads/members; private invite-link pages, noindex, Riot IDs
  visible to the squad only; games together by intersecting members' match ids; queues
  420/440/400/450/900/700/1700/1750 (not Mayhem 2400); lane awards on Summoner's Rift
  only; weekly recap on read with curve awards; squad Daily Draft needs a score endpoint;
  Discord PNG via canvas; coach kind = roster + weekly review + chart export; refresh
  on visit at most every 30 min

### Identity draft four (meiolol-27, 2026-10-12)

- Done: home page leads with the Riot ID lookup, six pillars marked live or coming;
  Highlights tiles on Your games (d24c299)
- Done: Death Cost and the Turning Minute on Your games (win chance by minute,
  src/winchance.zig; docs/your-games.md). The jomove API binary needs a rebuild and
  install for them to show for looked-up players (docs/your-games.md Deploy); the
  example page shows them after the box's next `your-example`
- Short games (under 15:00, remake=0) are early surrenders after a leaver, real
  results (meiolol-cf): an ended_early flag for stats and models needs an owner
- Then, in Jacob's order of interest: spike window, level spikes, counter-item timing,
  builds that worked, tilt check, snowball vs comeback, pool health, baron calls,
  sidelane, fingerprint, role lenses, pre-game brief (desktop), squad scouting
- Record book: full history only on request by the account owner (icon check), kept
  while used; needs privacy.md text
- Before Jacob presses Verify on prod app 890243 (still editable): new application text
  (identity, Platinum+ scope, data kept, desktop app + LCU endpoints, PUUID-link note)
  and privacy.md retention (raw summaries indefinitely, compact forever, pseudonymised
  raw archive on the gpu-box until PUUID blanking at 24 months). Jacob: not yet

### Curves, matchup pages, Patch day (was meiolol-b5, pool-9f)

- Done 2026-10-11 (curves v4): estimation per research/questions/curve-statistics-method.md
  in src/core/curvefit.zig (champion baseline by ridge least squares, MoM shrinkage
  with each pair's own variance, nested brackets and experienced curves, Whittaker
  smoothing picked by a split-half test); matchup pages draw the estimate (±2 SE,
  role band under 200 games, grey when mostly baseline, dotted 15-min line and share
  ended by 20/25), first-item row, experienced toggle (10+ games, CSS only); method page
  "games to stabilise" table. Numbers in docs/architecture.md "Lane curves". First real
  curves looked sane (Caitlyn vs Jhin, 359 games: lane gold within ±100, level 6 7:14 vs
  7:16, first item ~11 min); no bugs found in the curves step itself. Deployed f6bf5d6
  15:18Z (box v4 curves logged at 15:22-15:29Z: 27k games all regions in 6.3 min on the
  micro); Your games API binary on jomove updated to read v4 (15:23Z; it has 0 curves
  until the box pushes v4 per-patch files). Not yet checked: the live matchup pages
  after the first v4 upload (the box move to A1 started first)
- Split-half on the box (27k games): for pairs with 50+ games in a half (bot 63,
  support 32), the baseline alone beat shrunk (bot gold rms 173 vs 204, noise 182), so
  the matchup term does not pay yet; a higher k cap did not help. Recheck at volume
- Curves checked at 291k games (snap 2253Z, all platforms; meiolol-df, 14 Oct): the
  estimator stands as is. n_eff for same-player games: within-player correlation of
  gold@14 in a matchup 0.007-0.04, design effect under 1.015, dropped. Patch decay:
  16.19 to 16.20 moved matchup means by sd ~44 gold vs a spread of 476, under ~10 gold
  at any d, deferred to a big patch. tau^2 smoothed across minutes: split-half picks none
  in 13 of 15 role-metrics, not shipped. k: top 18-57, middle 25-100, jungle and bottom
  at the cap (100); cap 1000 is mixed (jungle gold all pairs 548 to 555, thick 135 to
  134), kept. Bot's matchup term now pays (thick pairs shrunk 166 vs baseline 170, noise
  147). Thin pairs sit at the other half's noise, so an embedding prior for them can't
  show a split-half gain: not started
- Curves next: brackets for a Platinum IV+ crawl (Iron-Silver is near empty,
  Gold-Emerald is mostly Platinum-Emerald: maybe Platinum-Emerald, Diamond, Master+;
  Jacob)
- Experienced toggle is starved: the box runs --no-mastery, so 3.7k of 189k participants
  have a mastery row; ~1k matchup pages show it at all. Mastery back on (A1), or
  experience from crawled match history (learning.zig game numbers): Jacob
- Curves at full volume: lanes are held in memory, ~180 B x 5 per game, so 30 days of
  all regions (~3M games) is ~2.7 GB: not on the micro; on A1 fine, or aggregate per
  day and merge. Site: 13.7k matchup pages, 252 MB with .gz, in the all-regions 30-day
  view at 19k games, growing with distinct pairs; a page floor (--min-games) if the
  upload gets too big
- Patch day: wire patchday.zig (main.zig passes previous patch + curvesPath(prev);
  root.zig builds previous Stats and curves); patch.html of the biggest clear movers;
  "Since patch X" per role on champion pages; on matchup charts a dashed previous-patch
  median (Site.curves_prev, chart() `prev: ?View`, `.median.prev`, caption "dashed:
  patch X"); nav `.patch` after matchups; web loop runs `meiolol curves --patch <prev>`
  once on patch change; multiple-comparisons note or stricter z
- Learning curves: read participants.gold14 instead of their own timeline pass
- Champion shape labels (lane bully / scaler / spikes at 6 / even) from curves, rule on
  the method page
- Daily Draft "easy daily" for new players

### Builds (2026-10-11)

- Done: `meiolol builds` + build pages in the patch views (docs/architecture.md
  "Builds"), Platinum IV+ per player, gated like champion-page pairs; web loop runs it
  daily. First box run (micro, 15:01Z, crawler running): EUW 16.20 3.9k games 29 s,
  19 MB RSS; all regions 10.5k games 77 s, 25 MB. ~7.5 ms a game there (disk), so a
  full patch at ~30k EUW/day would take ~1 h EUW and hours for all regions on the
  micro: before volume grows, aggregate each day's games once and merge (or move to
  A1). Next: check data/builds.log after the loop's runs ("dropped options" lines,
  time) and a few pages on the site; builds index done 2026-10-12, linked from the
  champions pages (a nav entry only if Jacob wants builds that visible: the application
  text does not mention builds);
  first-three skill levels; first-item timing per core; builds by matchup once pairs
  reach volume

### Learn (was learn-draft-6b)

- Counters lesson: our own learning-curve numbers instead of the Reddit 44% vs 51.5%
  once learning points exist
- Practice difficulty: add the lane-curve sign (laneBehind() in src/learn.zig) once pairs
  reach 200+ games; re-check lesson examples at 20k+ patch games
- If the draft model shows real lift: model reasons below 50 games, Medium graded on spread

### Draft model (was draft-model-19)

- Coordination of the model sessions (who owns what, rules, open items): docs/model-agents.md
- Jacob's personal goal (2026-10-12, separate from the app): the best League draft
  predictor. Owner meiolol-88 (win-* in the lab). Benchmark: LoLDraftAI reports 55-56%
  solo-queue accuracy (research loldraftai#^f6, #^f7). Lever is data volume: dev curve
  -0.0008 log loss per doubling, no plateau at 90k games; interactions not yet
  detectable; pool regions. Rank features need rank at game start (rank_history)
  Research answered (research/questions/draft-predictor-methods.md): honest draft-only
  ceiling ~53-54% on a time split (we are there); LoLDraftAI's 55-56% uses a random
  split, test-chosen checkpoint and stomp filters. Levers in order: data volume, player x
  champion experience before game start (internal scope only, meiolol-db; coverage 26%
  of rows today, mastery for all players is Jacob's call), factorised pairs from ~1M
  games, per-patch offset, deep MLP only at 10M+. Report both our split and a
  LoLDraftAI-style split. Admin Draft tester (meiolol-3b) with presets and a champion
  suggester (win model + team2 lane effects export from meiolol-39)
  Approved by Jacob 2026-10-13: internal scope (39's terms), mastery for all ten
  participants (deduped, weekly refresh, EUW first; meiolol-11), admin-only Draft
  tester link in the main site's menu (meiolol-3b)
  Also approved: a small EUW ranked flex sample (queue 440, a few thousand games a
  week, test only; site and stats stay solo/duo, meiolol-11) and meiolol-58's solo/duo
  lookup filter. Draft predictor next: everything pre-game internal model with
  per-champion skill sensitivity (meiolol-db), tested on solo and on flex
- Lab agent (docs/lab-agent.md, brief docs/lab-brief.md; built 2026-10-12, meiolol-f2):
  LLM campaigns on candidates behind a harness (scope and leakage by construction,
  ladder of 50 selection looks per snapshot, screen and diagnose tools, sandboxed
  headless launch, no spend cap: Jacob). 3c-team ported (src/lab/cand/team, matches
  3c-team.tsv; folded into cand/team2 on 2026-10-13, now the default start). A 4-run probe on smoke records: $1.09, behaved.
  Next: first real campaign (`deploy/lab-agent.sh start gold14-a gold14 "patch term,
  own rank, matchup interactions"`), review its digest before more; champion class
  tags in api.Train; port 2a fm once it beats 3c-team; meiolol-88 is starting win-*
  candidates; persistent build tree (build ~80 s vs 16 s run)
- Model agents (2026-10-12): meiolol-3c (CPU, interpretable shrinkage: additive enemy
  champions, class-tag comp types, per-item marginal effects, objective value given
  state, playstyle features) and meiolol-2a (gpu-box, `zig build lab`: embeddings,
  interactions, every-field ranking, sequence/playstyle clustering), run by a
  coordinator session. 2a's models must beat 3c's, not just base rates. Shared
  protocol and results in docs/model.md
- Decided (Jacob, 2026-10-12): outcomes win, gold@14, lane gold diff@14, CS@10, deaths
  before 15, first completed item minute; enemy team read both ways (additive per
  champion and Riot class tags, hand labels only if tags show signal); every field
  ranked by draft-time and post-game value, end-of-game stats never champ-select
  inputs; analysis snapshots hash PUUIDs with a salt, drop forgotten players, deleted
  when replaced; gpu-box long runs OK while League isn't running (watcher pauses);
  box WAL fix (meiolol-83)
- Retention (Jacob, 2026-10-12 ~22:45, applied by meiolol-3c on the box, crawl.args;
  old copy crawl.args.bak-20261012): keep more data until the models show what we
  need. Raw summaries forever (--raw-match-days 0), raw timelines on the box until
  archived (--raw-timeline-days 3650; the live value, 2026-10-13), never before the
  archive has them (the prune stops at the acked point), compact rows
  forever (--keep-days 0), mastery on. --timelines -> 100 (coordinator's call, Jacob deferred: only timeline outcomes show signal so far;
  revert if models show matches outside EUW matter more). Disk is not a constraint:
  Jacob plans to buy more space (see Storage and hosting under Open decisions). Disk runway ~30 days, so the gpu-box raw archive
  (meiolol-3c: `meiolol raw-export`, salted-hash pseudonymised, pull timer with acks,
  prune after ack, forget coverage) must be live within ~3 weeks. Archive kept until player ids
  are blanked at 24 months, as the crawler does (Jacob via meiolol-27). Privacy draft
  (30 days) update on hold until Jacob asks (meiolol-27)
  Archive live 2026-10-12 (meiolol-b0, took over from 3c): hourly pull to
  gpu-box /mnt/wsl/archive/meiolol-raw (1 TB partition, moved there the same night),
  ~6.6 GB/day at zstd -15 (summaries 0.7, timelines 5.9): ~5 months on the partition.
  Box ~29 days at ~3.5 GB/day while raw summaries stay forever there too
  Archive operation (export, pull, acks, alerts): meiolol-11 from 2026-10-12
- Result (meiolol-3c, docs/model.md "Team effects on early outcomes"): enemy and ally
  champions shift gold@14, lane diff, CS@10, deaths before 15 and first item
  additively, clear of 0; champion-specific team interactions (by class or champion)
  not detectable at 118k games. Site can show lane matchup + sum of enemy effects, not
  team counters. Next: 2a's embeddings vs 3c-team; 3c items, objectives, raw archive
- Result (meiolol-2a, docs/model.md "Champion embeddings against the enemy team"):
  interactions live in the lane only; lane embeddings beat 3c-team on lanediff14
  (+0.79 ± 0.19 % of base MSE) and gold14 (+0.22 ± 0.13) by letting thin lane pairs
  borrow from similar champions: candidate for lane curves on thin matchups. Other
  four enemies' interactions within noise. CPU suffices at this size (fits 1-5 s)
  Gain is all in thin matchups (<25 train games: lanediff14 +2.4%, cs10 +2.2%; 100+:
  none), so: embeddings or a count blend for lane curves under ~100 games (owner of
  curves to pick up). GPU vs CPU being benchmarked at 1x/4x/16x data (Jacob: test it)
- Findings ledger: docs/learned.md (plain one-liners, evidence, what the site may say)
- Lab campaign gold14-a running (meiolol-39, from 3c-team, no spend cap, Jacob)
- Results (meiolol-b0, 7ed9fe5, docs/model.md): 3c-team2 (adds the lane opponent's own
  effect and role x patch) is the new reference for early outcomes, beating 3c-team on
  all five and 2a-lane on cs10 and deaths15. Objectives add beyond the gold/XP lead at
  every minute (dragon ~1000 gold equivalent, soul ~4000, elder ~4800, inhib 900-2300).
  Items: given state at purchase, the item adds nothing measurable at 2.9M rows, so no
  build-by-win-rate claims; timing and lead matter. Items x enemy team deprioritised
- Playstyle (meiolol-b0, 5d0c22c): given the 14:00 leads, early style adds little
  (0.00038 ± 0.00015 nats); most apparent style effect is being ahead. Small survivors
  (trading damage, spare camps, support roams) are post-game lesson material only.
  Next: champion given state (scaling, converting leads), fresh session
- Scaling (meiolol-8a, e072351): champion matters beyond the team gold/XP lead at
  every minute (spread 3-11 pp, 500-2300 gold equivalent; e.g. Kayle top's team wins
  like one ~2,900 gold ahead at 25, Pyke like one ~2,600 behind). Per-minute curve
  real but small; converting leads or comebacks beyond that: nothing. Next: split who
  holds the gold, then objectives held in the state
  Done (f151e51, c71627d): gold lead per role predicts better than team gold, and the
  champion effects stay (they're value at equal gold, not gold on a low-value role);
  1000 gold is worth 1-3 pp on the support, 6-12 on bot; champion effects hold with
  objectives in the state. Review fixes queued: winchance weights (live bug in Your
  games), clustered playstyle intervals, after meiolol-47's refactor commit
- Draft predictor held-out (meiolol-db, 1abb887, snap-20261012T2055Z test, 10,604 EUW
  games): champions only 53.2% (AUC 0.544); everything pre-game, internal scope 54.5%
  (AUC 0.562), -0.0023 ± 0.0022 vs champions, just beyond noise. Random split
  flatters champions-only by ~0.5 pt (dev 54.15 vs 53.70). Per-champion skill slopes
  not detected; stored rank leaks (63.8% on dev). Next: rerun on a snapshot with ~a
  week of rank_history and pre-game mastery (coordinator pins it, fresh session);
  rank at game start campaign plan (meiolol-12) in docs/model.md Next steps, agreed
- Win (meiolol-88): joint ratings first to beat champion baseline on dev (-0.0031 ±
  0.0017); win rows need duration_s >= 900 (leaver forfeits out)
- Experience term (src/experience.zig): rerun at 300+ train / 100+ test per variant; if
  "user only" beats no-experience beyond its interval, wire it into recommend() as the
  "your pool" reason (wasm `pool` field). Mastery is a post-match snapshot and flatters
  it; history-based numbers are the honest ones
- Lane gold at 14 (lanegold.zig): reports from 500 train / 100 test with timelines; if it
  wins, champion and pair gold into the model file (statsfile v2)
- "Model accuracy vs data" chart on the method page from data/eval-history.tsv
- empiricalPriors as default once it gains at volume; then comp features, rank brackets

### Compute (2026-10-12, docs/compute.md "Plan")

- Done: eval on every core (src/par.zig, 38 s -> 7 s on the gpu-box), deploy/lab-run.sh
  (detached runs, gpu-box or Mac), League watcher, WSL 24 GB, wsl-watchdog (WSL back in
  ~30 s after a shutdown)
- Jacob, 2026-10-12: awake while busy (done: lab-watch.sh, ~/ml/awake.d), WSL starts
  after a reboot without login (wsl-watchdog task, logged out, elevated: registered,
  first reboot still to be seen), archive on the 1 TB Linux partition of the 2 TB NVMe
  (/mnt/wsl/archive/meiolol-raw; the rest is an old Pop!_OS home Jacob keeps). Box alert when the gpu-box stops acking the
  archive for 12 h: done (deploy/health.sh)
- Then: scripted snapshot cadence and packed rows (with 2a), run queue and checkpoints
  (for the lab agent), speed work only after measuring on the full snapshot

### Before the production review

- Privacy/terms into src/site/prose.zig from docs/legal once Jacob fills the placeholders;
  objection by email (`meiolol forget`) until the form is live
- Site polish: screenshots/GIFs, a short demo video
- Desktop: lane card built (docs/architecture.md "Desktop window"; `zig build
  desktop-shot` for PNGs). Next: run meiolol-desktop.exe on the Windows PC (DPI at 150%,
  fonts, idle CPU, D3DCOMPILER_47.dll; gpu-box was asleep), then a real champ select
  (`meiolol-app session --save testdata/lcu/session-real.json`; check mastery and
  ranked replies parse). Not yet: your own record in the matchup (concept part 6; LCU
  match history, needs a real reply to fix the schema), champion icons, window icon and
  DPI manifest, the download page shipping the exe with stats and curves
- Zig 0.17 move: done 2026-10-12 (docs/zig-0.17.md). dvui: pin PR #1012 (0.17.x
  branch) until it merges; ZLS built from its main until a 0.17 release

### Site build and deploy (2026-10-12, owner: the site session)

Push to live took 8-16 min: a deploy restarted the web loop cold (curves, eval and
builds reran), the site is 103k files / 1.2 GB rewritten and re-uploaded each round, and
nothing showed without a deploy. Research: research/questions/hybrid-rendering-seo.md

Done:
- Deploys signal the web loop (SIGUSR1: build and upload now); restart only when
  web-loop.sh, its unit or the contact changes
- Upload sends only changed files (checksum copy into data/site, rsync -z)
- nginx: Cache-Control no-cache on the site, so browsers revalidate (304) every load
- on-push skips pushes that touch only docs or research; box builds reuse .zig-cache
- `deploy/box.sh preview` (working tree, EUW views, localhost:8081, ~2 min),
  `preview static` (css and js, 1 s), `preview stop`; `meiolol site --euw-only`
- Pages as functions of (path, data): `load` per view, one router for the static build
  and rendering on request (`site.Loaded`); pipeline_test checks they agree byte for
  byte (docs/architecture.md "Code shape")
- Dev loop on the Mac: `deploy/box.sh snapshot` (data/snap, 454 MB, PUUIDs replaced,
  54 s), `deploy/dev.sh` (`meiolol dev`: render on request, live reload). CSS/JS edit
  visible at once, Zig edit ~20 s. Sqlite compiled -O2 in Debug too (Debug EUW site
  build 3:38 to 1:32; tests faster)
- Learn practice: match ids loaded once instead of an OFFSET query per try (13 s to 1 s
  of each site pass on the Mac snapshot)
- Filters on every champion page, one page per champion at the site root (the per-view
  copies dropped); header switches, early-data note, pick and ban tiles and gold at 14
  follow the filters (docs/architecture.md "Website"). Filter data ~0.5 s per build,
  4.5 MB gzipped for all champions. Ban rate by the game's rank (median player tier)
- Rendering on request (B, Jacob's OK 2026-10-12): meiolol-render on the box behind
  jomify's nginx (try_files, then proxy cache), over the private subnet; matchup pages
  under 200 games no longer uploaded (docs/hosting.md "Rendering on request"); deploys
  swap the renderer without a gap (two instances take turns on the port)
- Pool and learning tallied once per build for both regions, and their queries scan
  matches first (sqlite walked the puuid index, 6-8x slower): box site pass 171 s to
  ~45 s, renderer loads every view in ~44 s (was ~40 s root, ~3 min all). Output
  byte-identical
- `meiolol curves --site`: the four site curves files in one pass over the timelines
  (box 161 s to 100 s, files byte-identical); fitting is the rest
- gzip measured: level 1, 4 or 6 make no difference to pass time now; kept at 6
- `box.sh preview` builds HEAD plus the working tree's src/site edits (other paths as
  arguments), not the whole working tree; EUW preview build ~40 s

Direction (Jacob 2026-10-12, via meiolol-88: "build both"): stay static for the pages
search sees, plain JS on top, no framework; plus option B from the research: a renderer
on the box (`meiolol serve` with `site.Loaded`) behind jomify's nginx (try_files, then
proxy to the box with proxy_cache, use_stale, background_update) for the long tail,
unless it makes the site slower or less reliable. Thin matchups get server HTML, not
browser drawing; the browser does filters (region, rank, period, role) from per-champion
summable data. One page per champion or matchup instead of four view copies. Region:
every region selectable (groups only if data files grow too big). Indexing: open, to be
decided on evidence of what gets clicks, not just a game floor (Jacob 2026-10-12); build
canonical, sitemap and noindex support as settings.

Site UI pass (2026-10-12, meiolol-a0, from research/questions/site-design.md):
- Templates: src/site/tpl.zig (named holes checked at compile time, escaping by
  position); layout, matchup chart and the page files moved onto it, byte-identical
- Landing leads with one matchup's gold curve (matchup.featured) and links a Your games
  example (`meiolol your-example`, anonymised, written by the web loop); the champions
  table moved off it (577 KB to 7 KB)
- Win-rate colours orange / grey / blue (colour-blind safe, validated), not red/green;
  lane opponents ranked by the 95% bar's top end so thin data can't top the list
- SEO settings: `--origin` (canonical, sitemap per view, robots Sitemap lines; web loop
  passes it), `--index-min-games` (thinner matchups noindex); both only act with
  `--public`. meiolol-render's flags not yet given them
- Lane chart one component (lanechart.zig) for matchup pages and, as chart.wasm (12 KB),
  Your games; method page "Model accuracy vs data" (evalchart.zig, eval-history.tsv);
  builds index per patch view; Daily Draft marks without red/green
- Every HTML page on tpl (root.zig, matchup.zig last; byte-identical); phone width:
  every page type fits 360 to 412px, tables included, no sideways scrolling

Next:
1. Screenshots or a short video for the application (Riot accepts them, research C1);
   meiolol-render's flags still lack --origin and --index-min-games
2. Cached data load (Jacob: later): probably not worth it now that a load takes ~5 s on
   the Mac snapshot and ~44 s for every view on the box. Left of a pass: filters.make
   ~1 s, stats per view ~0.2 s (Mac). Renderer boot after a box reboot never verified
   on the box (only locally)

### Ideas not started (concept extensions, 2026-10-11)

Jungle routes and gank timing from positions; region styles (KR vs EUW per matchup);
Daily Draft modes ("which line is Darius?", "did the lane winner win?"); matchup
flashcards with spaced repetition; season "lane story" share cards.

## Open decisions (Jacob)

- Legal: EEA representative, retention periods (docs/legal/privacy.md top). Decided 14
  Oct: controller "Jacob Maschler, trading as meiolol", contact privacy@jomify.lol
  (Namecheap forward to add), ICO fee paid (number not shown on the site)
- Alerts and backups: an ntfy topic for phone alerts (NTFY_TOPIC in .env; the health loop
  only logs until then); install the Mac job (`deploy/box.sh watch install`: notifications
  + backup mirror); ok to delete de's pre-deploy copies in ml/meiolol/backup (1.8 GB)
  after a second nightly backup
- Squads as private invite-link pages with Riot IDs shown to members only
- Budget for EUNE/TR/RU/ME in the europe bucket (EUW takes it all while it has players due)
- Patch day movers bar: z 1.96 or 2.58
- Indexing (which pages and view search sees): open, decided on evidence of clicks
- Name/domain: "lol" in name and TLD is a mild Riot-trademark risk
- Storage and hosting (research/questions/free-hosting-storage.md): (1) Hetzner Storage
  Box BX11, 1 TB for EUR 3.20/month, for off-host backups and old segments (~1.5 years
  at full rate; B2 $6.95/TB second; no free option holds this); (2) keep a rolling
  window of match data on the box instead of everything (recommended, also less
  personal data kept); (3) Oracle Pay As You Go: still free within limits, A1 capacity
  sooner, paid disk possible; (4) ok to delete the unattached April 47 GB "Jomify (Boot
  Volume)" to free block storage. GitHub/Hugging Face ruled out: size limits, "not a
  backup tool", erasure from git history impractical

## Reference

- Hosting: jomove server (Oracle uk-london-1, `ssh -i ~/.ssh/oci_instance-20260714-1317
  ubuntu@193.123.180.81`; jomove's own nginx config: leave alone).
  /etc/nginx/conf.d/meiolol.conf, root /var/www/meiolol, user `meiolol` with an rrsync
  key from the box; Let's Encrypt via webroot. The box: docs/hosting.md (Oracle Cloud,
  `meiolol-cloud`). deploy/web-loop.sh on the box builds and
  uploads (often early in a patch, then hourly on new games); riot.txt from
  ml/meiolol/riot.txt
- Admin page: https://meiolol.jomify.lol/admin/ (/api/ basic auth; src/admin.zig).
  Crawl rates by region from crawl.log report lines, storage growth
  (data/admin-history.tsv), ingest mix, queues, eval, uploads, deploys; rebuilt every
  15 min by the web loop
- jodrive: `riot register --agree` handles the General Policies modal; `riot key --app
  ID` reads a registered app's key
- Personal key registration (Jacob's words, approved instantly): learning tool showing
  lane matchups minute by minute, compare your lane with the typical curve, daily draft
  puzzle; match-v5 with timelines, league-exp-v4, champion-mastery-v4; preview site

## Ruled out (do not revisit without new facts)

- Multiple keys or friends' keys to multiply limits: against Riot's terms, risks the
  production application
- A second "decoy" app to get a key for meiolol's data: one product per key
- lolalytics/op.gg/u.gg scraping, old datasets, pro play data: docs/data.md
- Replay-file analysis: Riot locked replays from 26.20 (research)
- Python: Jacob wants Zig for everything, including training if feasible
