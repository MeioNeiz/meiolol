# Plan

Updated 2026-10-11 (end of the first multi-session day).

## Goal now: production key

Product: "learn your lane" (docs/concept.md, adopted 2026-10-11): your own games laid
over minute-by-minute matchup curves, public matchup pages, Daily Draft, Learn mode,
Pool, Squads; picks only as several options with reasons. Research behind it in
research/questions/ (josearch). Production application started by Jacob 2026-10-11 (text
in docs/production-key.md); review takes 3-9 months, Riot looks at the site at review
time, so keep building and keep the site up. Don't edit the application while it queues.

## How we work

Several Claude sessions in parallel, all on main in the one checkout (Jacob,
2026-10-11: no more branches or worktrees). Commit only by explicit path (`git commit -m
... -- <paths>`): the index may hold another session's staged work. Every push to main
deploys to the box (deploy/box.sh builds from a clean checkout of the commit; history in
ml/meiolol/DEPLOYED), so the pre-push hook runs `zig build ci` on a clean checkout of the
pushed commit first (CLAUDE.md).

Until the site goes public (Jacob, 2026-10-11): sessions merge, push and redeploy the
preview site and box binary without asking. Still ask first: anything irreversible
(deleting data, key or registration changes, Riot applications), nginx/systemd changes on
the jomove server, changes to Jacob's Mac. Live DB migrations: backup and rehearsal on a
copy first.

Jacob's standing asks: the coordinator reviews regularly for gaps nobody owns (risks,
safety nets, doc requirements with no work behind them) and hands out work. Close a
session once it passes ~30% context: it commits, reports done/next/questions, and its
next steps land here.

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
- Desktop app: LCU client works in tests; never run against a real champ select. Lane
  card not built; GUI choice dvui pending a Windows run
- Disk: the micro has ~40 GB free; ~1.6 GB/day kept forever at the full all-region rate:
  weeks. A1 (up to ~150 GB free), EUW-only or paid disk (PAYG): Jacob's call

## Next steps

### Ops and data (was meiolol-de, data-safety-af)

- Data safety is on main (fad705a; docs/data-safety.md): start the box backup loop (D:)
  and health loop (ntfy): running on the box since ~04:20. Mac launchd notifier: Jacob's
  call
- Backup loop: pull exchange/forgotten.txt from jomove, push box-forgotten.txt
- Measure real per-match sizes after a day; recheck disk runway
- Rekey translation for `forgotten` (old PUUID -> Riot ID -> new PUUID) before the
  production key
- Requeue matches failed by 429 storms (6x 429 then GaveUp counts as an attempt)
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
  micro: full around early November unless A1, PAYG disk or a shorter --keep-days Not tested yet: --no-participant-players and
  dropping the participants_puuid index (only `forget` reads it): bench round
  scratch-only, rerun deploy/bench-crawl.sh with --no-mastery for pages/match.
  Before ~2026-11-25 (first matches pass --keep-days 60): per-patch aggregates kept
  forever and Pool learning curves on them, or raise/drop --keep-days. `meiolol status`
  still counts whole tables and takes the write lock (store.open): slow on the micro
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

### Curves, matchup pages, Patch day (was meiolol-b5, pool-9f)

- Check the first real curves once timelines exist (matchup/index.html, a matchup page)
- Curve estimation per research/questions/curve-statistics-method.md: sigma/tau per
  role and metric from box data, baseline backfit, method-of-moments shrinkage, Whittaker
  smoothing, nested brackets, k per role/minute on the method page, "share of games
  ended" from minute 15; patch decay weights once two patches exist
- Matchup pages: show the experienced-players toggle (Curves.getExperienced) and
  first-item rows (View.firstItem), already in the curves file
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
- Curves memory at full volume: measure on the box

### Learn (was learn-draft-6b)

- Counters lesson: our own learning-curve numbers instead of the Reddit 44% vs 51.5%
  once learning points exist
- Practice difficulty: add the lane-curve sign (laneBehind() in src/learn.zig) once pairs
  reach 200+ games; re-check lesson examples at 20k+ patch games
- If the draft model shows real lift: model reasons below 50 games, Medium graded on spread

### Draft model (was draft-model-19)

- Experience term (src/experience.zig): rerun at 300+ train / 100+ test per variant; if
  "user only" beats no-experience beyond its interval, wire it into recommend() as the
  "your pool" reason (wasm `pool` field). Mastery is a post-match snapshot and flatters
  it; history-based numbers are the honest ones
- Lane gold at 14 (lanegold.zig): reports from 500 train / 100 test with timelines; if it
  wins, champion and pair gold into the model file (statsfile v2)
- "Model accuracy vs data" chart on the method page from data/eval-history.tsv
- empiricalPriors as default once it gains at volume; then comp features, rank brackets

### Before the production review

- Privacy/terms into src/site/prose.zig from docs/legal once Jacob fills the placeholders;
  objection by email (`meiolol forget`) until the form is live
- Site polish: screenshots/GIFs, a short demo video
- Desktop: run dvui on the Windows PC, build the lane card (concept part 6), test LCU in
  a real champ select (`meiolol-app session --save testdata/lcu/session-real.json`)
- Zig 0.17 move: small (docs/zig-0.17.md). Waiting (Jacob, 2026-10-11) until ZLS works
  with 0.17, ideally with dvui on 0.17 too; then one move

### Ideas not started (concept extensions, 2026-10-11)

Jungle routes and gank timing from positions; region styles (KR vs EUW per matchup);
Daily Draft modes ("which line is Darius?", "did the lane winner win?"); matchup
flashcards with spaced repetition; season "lane story" share cards.

## Open decisions (Jacob)

- Legal: controller name, privacy contact (suggested privacy@jomify.lol ->
  jombirds@gmail.com), ICO fee (52 GBP/yr, 47 by direct debit), EEA representative,
  retention periods (docs/legal/privacy.md top)
- Alerts and backups: an ntfy topic for phone alerts (NTFY_TOPIC in .env; the health loop
  only logs until then); install the Mac job (`deploy/box.sh watch install`: notifications
  + backup mirror); ok to delete de's pre-deploy copies in ml/meiolol/backup (1.8 GB)
  after a second nightly backup
- Squads as private invite-link pages with Riot IDs shown to members only
- Budget for EUNE/TR/RU/ME in the europe bucket (EUW takes it all while it has players due)
- Patch day movers bar: z 1.96 or 2.58
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
