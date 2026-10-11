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

Several Claude sessions in parallel, coordinated by one. Code sessions use git worktrees
and hand branches to the coordinator, who merges in the main checkout, checks build +
test + windows on a clean checkout of the merge, and pushes. In the shared main checkout
commit only by explicit path (`git commit -m ... -- <paths>`): the index may hold another
session's staged work. Every push to main deploys to the box (deploy/box.sh builds from a
clean checkout of the commit; history in ml/meiolol/DEPLOYED).

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
- Disk: C: 249 GB free; ~1.6 GB/day kept forever + ~110 GB rolling raw: full in ~3
  months (early December with 50 GB slack) unless WSL moves to the 2 TB NVMe

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
- Newest-first timeline queue (FIFO per region today) so the current patch fills sooner
- Optional: lossy timeline compaction if disk gets tight

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
- Zig 0.17 move: small (docs/zig-0.17.md); dvui not on 0.17 yet

### Ideas not started (concept extensions, 2026-10-11)

Jungle routes and gank timing from positions; region styles (KR vs EUW per matchup);
Daily Draft modes ("which line is Darius?", "did the lane winner win?"); matchup
flashcards with spaced repetition; season "lane story" share cards.

## Open decisions (Jacob)

- Legal: controller name, privacy contact (suggested privacy@jomify.lol ->
  jombirds@gmail.com), ICO fee (52 GBP/yr, 47 by direct debit), EEA representative,
  retention periods (docs/legal/privacy.md top)
- Squads as private invite-link pages with Riot IDs shown to members only
- Disk: move WSL to the 2 TB NVMe (673 GB unallocated) before ~20 Nov, at the PC
- Budget for EUNE/TR/RU/ME in the europe bucket (EUW takes it all while it has players due)
- Patch day movers bar: z 1.96 or 2.58
- Zig 0.17 timing (recommended: now, add dvui when it catches up)
- Name/domain: "lol" in name and TLD is a mild Riot-trademark risk

## Reference

- Hosting: jomove server (Oracle uk-london-1, `ssh -i ~/.ssh/oci_instance-20260714-1317
  ubuntu@193.123.180.81`; jomove's own nginx config: leave alone).
  /etc/nginx/conf.d/meiolol.conf, root /var/www/meiolol, user `meiolol` with an rrsync
  key from the box; Let's Encrypt via webroot. deploy/web-loop.sh on the box builds and
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
