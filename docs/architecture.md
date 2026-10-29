# Architecture

```
build.zig            modules: core (pure), store (SQLite C), backend, app
src/
  main.zig           `meiolol` backend CLI: crawl, stats, site, status, champions
  cmd/               its commands, each beside its usage text: crawl.zig (crawl, stats,
                     champions, draft-backfill, digest), sitedata.zig (curves, builds,
                     pool, lean, draft-model, lane-model), analysis.zig (eval and the
                     analyses), site.zig (site, dev, render, serve), ops.zig (api,
                     your-example, status, admin), data.zig (raw-export, rebuild,
                     rekey, backup, restore, forget)
  ddragon.zig        Data Dragon: champion ids/names; item classes, rune and spell names
  patchnotes.zig     what Riot changed between two patches, from Data Dragon (cached
                     in DATA/ddragon/<version>/; `meiolol patchnotes OLD NEW`)
  cdragon.zig        CommunityDragon's ability numbers per champion and patch (cached
                     beside Data Dragon's version, cdragon.cache_file)
  date.zig           UTC dates (Date: format, parse, epoch days)
  pipeline_test.zig  fixture games through stats, curves and the site
  daily.zig          Daily Draft puzzles (data/daily), made by full loads (site --views)
  learn.zig          Learn page data: champion facts, practice draft pack
  curves.zig         lane matchup curves from timelines (`meiolol curves`)
  builds.zig         builds per champion and role (`meiolol builds`, JSON for the site)
  pool.zig           Pool: who mains X also plays Y, hard-lane options, ban fallback
  learning.zig       how hard champions are to pick up: win rate by mastery points
  stats.zig          model file from the matches table (`meiolol stats`)
  fitted.zig         the draft model in it (additive v2 on its games; additive.zig fits)
  partials.zig       views partials (data/partials): the views write's games and mastery
                     contributions kept between writes (arch-site.md "Views partials")
  eval.zig           draft model on held-out newer games (`meiolol eval`, docs/model.md)
  draftfile.zig      the admin Draft tester's model file: shapes, writer (shared with
                     lab/draft.zig; docs/model.md "Draft model file"); its scorer is
                     core/draftscore.zig, which ui.wasm scores the tester page with
  testerbin.zig      `meiolol tester-bin`: that file as draft-model.bin (ui/testerdata.zig)
  draftmodel.zig     `meiolol draft-model`: the shipped model as that file, daily on the box
  lanefile.zig       the tester's lane model file, as draftfile.zig (lab/lane.zig shares it)
  lanemodel.zig      `meiolol lane-model`: lab candidate team2 (imported as a module,
                     build.zig) on every played game as that file, daily on the box
  analysis.zig       shared by eval, objectives, playstyle: the held-out split, games
                     with a timeline by role, paired gains, shrinkage priors,
                     prediction files
  api/               "Your games" service (`meiolol api`, docs/your-games.md): cache.zig
                     (api.db), fetch.zig (the one Riot caller), game.zig (lane vs curve)
  livestate.zig      the game state by minute from a timeline, per seat and team (shared
                     by lab/stateexport.zig and statemodel.zig)
  statemodel.zig     in-game win chance (richc) for Your games; model file
                     state_model.bin embedded (py/state/stateship.py writes it; format:
                     docs/model.md "In-game model file"). winchance.zig: the fallback
                     when a game lacks full roles
  admin.zig          `meiolol admin`: private ops page (/admin, static/admin.js charts)
  admin_api.zig      /admin/api/ in `meiolol render`: live data, logs, actions (hosting.md)
  site/tester.zig    /private/tester (`admin --private-out`): the new Draft tester island
                     (ui/testerpage.zig, ui-tester.wasm fetches /private model bins) and its
                     candidate panel (ui/testercand.zig, lazy ui-testercand.wasm, no
                     model: the board via the URL, the seat's options handed over as a
                     Feed), beside admin.zig private()'s old page until it reaches parity
  backup.zig         `meiolol backup|restore`: state snapshots + append-only segments
  forget.zig         `meiolol forget`: GDPR erasure, `forgotten` suppression list
                     (both: docs/data-safety.md)
  status.zig         `meiolol status`: read-only counts, estimates for big tables
  site/              public website generator (`meiolol site`): html.zig layout and
                     boilerplate (markup through tpl/ or ui trees), textpages.zig fixed
                     text pages (markdown on ui.textpage) and the account pages
                     (ui.account), static/ (css, admin scripts)
  wasm.zig           recommender in the browser (wasm32-freestanding),
                     embedded into the backend binary by build.zig
  riot/              Riot API: ratelimit, client (std.http), endpoints (platforms and
                     regions), match parser, timeline (compact format), crawl
  store/             sqlite.zig (thin wrapper), schema.zig, raw.zig (compression)
  tpl/               HTML templates (module "tpl", std only, library-grade): named holes,
                     escaping by position, compile-time checks; usage in root.zig's
                     header; tests.zig the contract, compile_errors.zig templates that
                     must not compile (each built by `zig build test`, expecting its error)
  nn/                training the lab's nets on the CPU (module "nn", std only,
                     library-grade): named parameters in one flat buffer, Adam(W),
                     clipping, the minibatch loop with early stopping, layers, metrics,
                     a gradient checker; a worked example in root.zig's header. Nets
                     write their own forward and backward (no autograd)
  core/              pure, std only, shared: roles, statsfile (model file format),
                     score (recommender), curvesfile (lane curves format), draftscore
                     (Draft tester scorer, a pick's why)
  lcu/               League client: lockfile/process discovery, https (TLS to
                     127.0.0.1 trusting only riotgames.pem), session (champ select),
                     me (own mastery and solo tier)
  app_main.zig       `meiolol-app`: suggest (offline), watch (live), session, get
  lab_main.zig       `meiolol-lab`: modelling experiments (docs/model.md, compute.md);
                     lab/rows.zig loads model rows (lab/rowsql.zig: layout, production
                     from SQLite), lab/pack.zig packed rows,
                     lab/mastery_pre.zig pre-game mastery from the raw archive,
                     lab/seatstats.zig end-of-game seat stats (rows.Row.stats),
                     lab/nnexport.zig tensors for the draft nets (SNAP/nn/)
  lanecard.zig       the lane card's content (pure): opponent, sentence, curve, options
  desktop_main.zig   `meiolol-desktop`: the lane card in a window (dvui, Direct3D 11)
  desktop/           ui.zig (the window, drawn from a View), poller.zig (data and
                     client poller), update.zig (data and exe updates from meio.lol),
                     raster.zig (dvui backend drawing into memory, for
                     desktop_shot.zig's PNGs)
  shell/             `meiolol-shell`: the app as a WebView2 window (win.zig) and its
                     Mac dev loop (WKWebView, mac.zig), replacing dvui (stack.md 5);
                     channel.zig the typed messages to and from pages
deploy/box.sh        cross-compile (static musl, for the host's CPU) and run on the box
deploy/systemd/      the box's loops as systemd user services (docs/hosting.md)
deploy/*-loop.sh     box loops in tmux: web (site upload), backup, health (ntfy);
                     health.sh the checks, mac-watch.sh the Mac side (launchd)
testdata/lcu/        champ select fixtures (session-synthetic.json is made up)
src/riot/testdata/   one real match-v5 JSON, PUUIDs and names replaced
```

Only C dependency: SQLite amalgamation, fetched by build.zig.zon, compiled by Zig.
Cross-compiles to Windows, Linux and macOS from the Mac; nothing to install on the box.

## Other parts

- docs/arch-stats.md: Lane curves, Builds, Early or late, Pool, How hard to pick up
- docs/arch-site.md: Website (Code shape, Views file, Views partials), Daily Draft, Your
  games service, Learn
- docs/arch-app.md: App (Webview shell, Desktop window)

## Storage (on the box, ~/ml/meiolol/data)

- `raw.db`: fetched JSON, gzip (early rows from the retired Python crawler are zstd;
  std decompresses both, compresses only deflate; told apart by magic bytes). Rolling,
  pruned hourly by the crawler: `raw_docs` match summaries 30 days
  (`--raw-match-days`), `timeline_docs` timelines 7 days (`--raw-timeline-days`, 0
  keeps none; ones that failed to parse are kept). `meiolol rebuild` re-parses kept summaries into the
  tables after a parser or schema change. Mastery is not kept raw
- `timeline.db`: `timelines`, one compact blob per match (src/riot/timeline.zig: per
  minute per participant gold, xp, level, CS, position, damage, CC; events: kills
  with position, items, skills, wards, buildings, plates, monsters, transforms). ~8.6
  KB vs ~60 KB raw gz, lossless for those fields; `timeline.decode` reads it.
  Participant id = slot + 1. Kept forever unless `--keep-days`
  `digests` (18 Oct): per timeline the part curves, lean, lane-model and builds read
  (src/riot/digest.zig: 27 frames of gold, XP and CS, kills, items, skills, objectives;
  ~5.0 KB uncompressed, decoded 11x faster than the full blob), keyed by the timelines
  rowid. Made by `meiolol digest` (src/digests.zig) each web loop round, not by the
  crawler; a game without a current digest is read in full and cut, so outputs never
  depend on it. Not backed up: rebuilt.
  On the box (18 Oct, niced, crawler running), wall/CPU s before -> after: curves --site
  2003/709 -> 1551/494, lean 1945/682 -> 1764/165, lane-model 1685/719 -> 1202/414,
  builds 1462/366 -> 1323/230; the box is disk-bound, so CPU falls more than wall.
  Catch-up from empty 1203 s; 4.8 GB for 878k timelines.
  Reads in flight (19 Oct, src/store/ahead.zig): a lister and 8 readers, each on its own
  read-only connection, read each game's digest and participants up to 4,096 games ahead
  of the pass (and stats.scan's with an io), so its own reads hit the page cache;
  its order and output are unchanged. Box, wall/CPU s before -> after: curves --site
  1315/517 -> 842/622, builds 1375/212 -> 266/228, lean 1356/154 -> 263/170, lane-model
  1186/448 -> 517/454; ~1 read in flight (~1,500/s at ~1 ms) -> 3,200-5,200/s, 6-12
  queued. curves and lane-model are CPU-bound now
- `meiolol.db`: crawl state (players, ladder_pages, match_queue and timeline_queue:
  pending, missing and failed only; stored ones leave) and tables kept forever (or
  `--keep-days` after game start: a rolling window): matches, participants (incl. final items, full rune page, and
  tier/division = rank snapshot when the match was stored, gold10/14/15 = total
  gold at those timeline minutes), bans, mastery (one
  compact blob per player, src/riot/mastery.zig, ~0.7 KB), champions. Text-keyed
  tables are WITHOUT ROWID (no second copy of the key in an index)
- `drafts` (meiolol.db, src/store/draft.zig): one row per complete ranked game (420/440,
  no remake, a winner, 5 v 5), kept forever whatever `--keep-days` says, for draft
  models that need millions of games over several patches. Platform, queue, patch, game
  day (unix day, not the start time), rank (median ladder rank snapshot of the players
  with one, schema.packRank, NULL under 5 known; `ranked` = how many known), blue win,
  picks (10 x u16: champion | (role + 1) << 13, blue then red), bans (10 x u16) and
  game length in whole minutes (capped at 255; added a few hours after launch, the
  migration put the rows written so far back on the backfill list to get theirs).
  No PUUID, Riot ID or match id: the Riot API turns a match id back into the players.
  74 bytes per row measured (10M games ~0.7 GB). Deduped without a key: the writer adds
  it in the transaction that first inserts the match row (same file as participants, so
  atomic under WAL; an attached file would not be). Matches stored before the table
  existed are listed in `draft_backfill` (match ids, transient) when a new binary first
  opens the database; `meiolol draft-backfill` drains it in short chunks, and the prune
  keeps listed matches until then. `draft.Reader` reads rows for stats and eval
- Match ID is the permanent key and carries the platform (EUW1_, KR_); matches.platform
  and players.platform/region let stats pool or split regions
- PUUIDs are encrypted per app: switching app (dev -> personal -> production) gives
  new PUUIDs. `meiolol rebuild` then `meiolol rekey` forgets players, ladder and
  mastery (re-seeded from the ladders) and blanks old PUUIDs in participants; matches,
  timelines and rank snapshots stay. Re-storing a match keeps its PUUIDs and rank.
  Before clearing, rekey carries the erasure lists over by Riot ID with both keys
  (src/rekey.zig, docs/data-safety.md "Key switch")
- `ranks` and `rank_history` (meiolol.db, keyed by schema.puuidKey: 8 bytes of PUUID
  hash, not the PUUID): ranks is every ranked player's latest ladder rank, LP, wins and
  losses and the day a ladder page last showed them (gone 30 days after; it gives
  participants their rank snapshot). rank_history (key, day, rank, lp, wins, losses;
  WITHOUT ROWID, key first) gets a row only when a sighting differs from ranks, so the
  day of each change; a second change the same day replaces that day's row. The writer
  does it in the ladder job: one INSERT ... WHERE NOT EXISTS against ranks (its page is
  already in cache for the ranks upsert), so unchanged players cost nothing extra. With
  `--ladder-refresh-hours 12` over Platinum+ (~5.3M players, all platforms), measured
  24 Oct: ~840-880k rows a day (`meiolol status` "rank_history by day"), 28 bytes a row
  (14.8M rows in 408 MB, dbstat), so ~24 MB a day, ~9 GB a year. A player's rows go
  24 months after their newest one, their last change: about their last ranked game,
  as privacy.md promises (hourly prune, a 168th of the key space per round, so
  weekly); forget deletes them; backup segments copy them by whole day. A rekey leaves
  them under the old keys (no mapping to the new PUUIDs): they match nobody and age out
- Privacy (crawler writer, hourly): players no ladder page or match has shown for 30 days
  are deleted with their mastery, and mastery older than 30 days is refetched (Riot's
  monthly refresh; erased accounts drop out). A mastery refetch that Riot answers 404
  deletes the player at once. Matches older than 24 months lose their PUUIDs.
  `forgotten` (plain PUUIDs, so a rekey can translate them and the Your games service
  can exchange them; written by `meiolol forget`, src/forget.zig)
  is honoured: never stored as players or mastery, blanked in participants, and no
  raw summary or raw timeline kept for their matches
- `partials/` (views partials, ~0.6 GB for 835k matches): the views write's copy of the
  games and mastery contributions it reads (docs/arch-site.md "Views partials"); derived,
  never backed up, safe to delete (the next write rebuilds it)
- Schema changes: `schema.zig` migrate() alters or rebuilds tables in place (checks
  inside the write lock, so concurrent opens are safe). Back up before a first run
- Scale at full rate (4 regions, ~135k matches/day): kept forever ~8.6 KB timeline +
  ~3 KB rows per match, ~1.6 GB/day, ~570 GB/year; rolling raw ~50 GB summaries + ~60
  GB timelines at default retention; mastery ~1 KB per ranked player, bounded. Disk on
  the box: docs/hosting.md

## Crawler (src/riot/crawl.zig)

All regions by default (`--regions` to limit). A personal key's limits apply per
routing value, so one thread per bucket, each with its own HTTP client, limiter and a
DB connection it only reads with: 4 regional + 15 platform threads. Platform to region
map: `platforms` in src/riot/endpoints.zig.

Race checks, by hand after a threading change (not in ci): `zig build backend-check` runs
the tests that start threads (par, store/ahead, httpd, the proxy, ratelimit, the API's
keep-alive test, the site pipeline) under ThreadSanitizer, about a minute once built. The
crawler's own threads need a run: `zig build backend-tsan`, then `TSAN_OPTIONS=log_path=F
RIOT_API_KEY=fake zig-out/tsan/meiolol crawl --data EMPTY_DIR --fake-api 20 --hours 0.025
--proxy 127.0.0.1:18092` (a few curls at the proxy meanwhile); no F.* file after is clean

One writer thread (src/riot/writer.zig) makes every crawler write. Workers parse and
compress outside any lock and queue owned jobs (at most 128 waiting, then they block);
the writer applies whatever has queued in one transaction, a savepoint per job, so a
row that cannot be stored marks its match or timeline failed and the rest commit. A
worker waits for its jobs' commit before reading queues they change (the next match
batch, the timelines of matches just stored), so nothing is fetched twice. A short
batch lingers up to 2 s for more jobs unless a worker is waiting (each commit rewrites
the index pages it touched). Between batches the writer prunes, one 500-row chunk at a
time: raw documents, unseen players and old mastery, PUUIDs past 24 months, and matches
past `--keep-days` with their participants, bans and timelines (not their draft rows;
not matches still waiting for the draft backfill). Only the writer's
connection has a big page cache (`--cache-mb`, default 64); WAL files are capped at 64
MB after a checkpoint. Why: on the 1/8-OCPU micro 19 writing threads waited on the lock
(holders descheduled mid-transaction, gzip inside it), and per-row commits with 2 MB
caches wrote 43 GB and read 32 GB in 4 hours for ~2k matches.

- platform (euw1, kr, na1, ...): league-exp ladder pages from Challenger down to
  `--min-tier` (default every tier; players +
  rank snapshot, refreshed weekly: `--ladder-refresh-days`; unchanged players are not
  rewritten), then champion mastery with spare budget (`--no-mastery` to skip)
- regional (americas, asia, europe, sea): match ids per player of its platforms (last
  14 days, queue 420), match details, then timelines of non-remakes (every `--priority`
  platform match; `--timelines PCT` of the rest, default all, picked by match id hash;
  the box runs 50). Queues put `--priority` platforms' matches first, then FIFO for
  matches and newest first for timelines; ids refill only under 300 pending. Each round
  (RegionCrawler.step) takes 40 matches and 40 timelines, so new games get theirs at
  once; a backlog of older timelines (60 a round) only drains when the match batch is
  short. Per match ~2.13 calls with a timeline (match + timeline + ids), ~1.13 without:
  ~33k matches/day/region with all timelines, ~43k at 50%.
  Participants also become players to scan unless `--no-participant-players` (the
  ladder already lists every ranked player)
- main thread: per-region report every minute, plus writer jobs, commits, queue length,
  busy retries and the writer's pages written and read (cache misses; page = 4 KB; a
  checkpoint writes pages again). On start, drops 'done' rows older crawlers left in the
  queues, and with an empty timeline_queue queues timelines for crawled matches

Benchmark: `deploy/bench-crawl.sh seed DIR`, then `run DIR MINUTES [slow|micro]` crawls
a clone of box-sized databases with `--fake-api` (fixture answers, no network or rate
limits, so it runs with `--priority none`); micro mode runs the process 1 slice in 8 at
background QoS, a rough stand-in for the micro.

Players are scanned in PUUID order (effectively random): no activity bias. The pool is
rank biased by design: the ladder walks top down and the box sets `--min-tier PLATINUM`
(Jacob: Platinum IV and up are the games wanted), so lower tiers are neither walked nor
scanned. Ladder pages use the platform buckets, so the floor costs no match volume;
`--ladder-per-hour` must cover a week's refresh of the walked tiers (EUW Platinum IV+
is ~5,500 pages, ~33 an hour) or the walk restarts at the top before reaching the floor.
`--priority` platforms (default EUW1) come first in two places, and nowhere else. Their
region's queues: EUW's players are scanned and its matches and timelines fetched before
the rest of europe, so EUW gets the whole europe bucket while it has players due (the
other regions never compete with EUW for the key, only for the machine). And the
writer's queue (Writer.submit): other buckets' jobs wait once it is half full (64),
the priority region's at 128, so when the box (disk, CPU) falls behind, the rest slow
down at once and EUW keeps going; on a box that keeps up the queue never fills and
every bucket runs at its cap. Ladder pages are never priority (~100x a match in
writes). This replaced a gate on europe's measured slack (2026-10-11), which took up to
1.5 h after every restart to let the other regions start.

One limiter per routing value (ratelimit.zig `Limiters`), shared by the route's crawl
thread and `--proxy` (proxy.zig, box: 10.0.0.3:8092), through which the Your games
service makes its Riot calls. The crawl paces requests evenly (one per window / limit)
instead of filling a window in a burst, so a slot frees every pace; proxied calls take
priority, unpaced, and the crawl holds back while one waits. So the crawler has the
whole key except for the slots a lookup takes (docs/your-games.md, Rate limits).
Only Riot's key errors, OOM and SQLite errors outside a match stop the crawler; a bad
page, player or match (including one SQLite cannot store) is logged and skipped.
Limits come from Riot's headers (X-App/Method-Rate-Limit and their -Count, which also
corrects for requests made by another process); 429s honour Retry-After. Exit code 3
when Riot rejects the key; deploy/box.sh's restart loop stops on it.

## Model file (src/core/statsfile.zig)

The contract between backend and app: `MEIOSTAT` v1, champion-role games/wins plus
dense ally and enemy pair tables per role pair (~12 MB). v2 adds the fitted draft model
(src/fitted.zig: additive v2 on the file's own played games, f16, both orientations,
+6 MB raw, ~+0.7 MB gzipped), which core.score drafts with; the site's views and
`meiolol stats` write v2, every other builder v1. Format spelled out at the top
of statsfile.zig; bump the version on any change. Written by `meiolol stats` (default:
newest patch; `--patch 16.19,16.20` for several; `--platform` picks platforms, default
EUW1, since the site says EUW) to data/export/stats-<patch>.bin. Only ranked solo
games with no remake, a winner and all ten positions count.

## Packed rows (src/lab/pack.zig)

A snapshot dir (docs/model.md "Shared protocol") holds meiolol.db, raw.db, timeline.db,
split.tsv, legendaries.tsv and, after `meiolol-lab pack SNAP`, pack/: rows.Data (every
game and row, unfiltered: the split is a field, cuts and fractions come after loading)
as one file per field. rows.load reads it when it matches, else SQLite with a one-line
note; `rows`, `enemy`, `exp` and the rest all go through rows.load.

- games.FIELD, rows.FIELD: little-endian, COUNT values per game or row in game/row
  order (rows.game indexes games). bool and u1 as u8 0/1, enums as their tag (u8),
  rank ?u8 with 255 as null, teams 10 u32 (side major), y 6 f32 per row (Outcome order,
  NaN unknown), stats 17 f32 per row (SeatStat order, NaN unknown). Strings: games.match_id the bytes concatenated, games.match_id.end u64
  end offsets
- manifest (text): `meiolol-lab pack VERSION`, `code` (hash of rowsql.zig, pack.zig,
  protocol.zig, stats.zig, seatstats.zig; not rows.zig, so loading paths and hooks there
  leave packs valid), `legendaries` (count, hash), per db its size
  and mtime (seconds: rsync drops ns) and its WAL's, seat_stats.tsv's size and mtime (0 0
  when absent), one `column NAME TYPE COUNT` line per file, then `games N`, `rows N`.
  Everything above the counts must equal what the loading binary computes, else the
  pack is stale. Bump pack.version when rows change through code not hashed (eval.split,
  timeline.decode)
- Written to pack.tmp-RANDOM, read back and compared, then renamed over pack/; the
  manifest is written last. A copy keeps the pack only if mtimes survive (rsync -a)

`meiolol-lab mastery-pre SNAP ARCHIVE` (src/lab/mastery_pre.zig) adds mastery_pre.tsv:
per queue 420 participant, the player's latest raw archive mastery fetch with
fetched_at < game_start (the snapshot's own mastery table is the latest fetch, mostly
post-game). Columns match_id, slot, fetched_at, level, points, last_play (the game's
champion, 0s if absent from the fetch), champions, total_points (the whole fetch); no
line without such a fetch. Two zstd -dc passes over ARCHIVE's mastery files (the first
keeps one best fetched_at per participant, the second decodes only the chosen blobs);
exports begun after the last game are skipped. Temp file, then rename. Beside it
mastery_pre_pool.tsv, from the same fetches: match_id, slot, champion, pool (the 15
champions with most points, `champion:points,...`), the pool the app would see; `meiolol
eval --replay` reads it.

`meiolol-lab seat-stats SNAP [DDRAGON [ARCHIVE]]` (src/lab/seatstats.zig) adds
seat_stats.tsv: per queue 420 seat, what the player did (api.SeatStat), for comp
features. Header line, then match_id, slot, 17 f32 columns in SeatStat order, `nan`
unknown; no line when the game has no raw summary or the summary names another champion.
From raw.db's riot_match summaries, then the raw archive's (src/lab/summaries.zig: the
box keeps summaries ~2 days, so raw.db alone covers only a snapshot's newest games;
parallel decode, par.zig): minutes (gameDuration / 60), damage dealt to and
taken from champions by type, damageSelfMitigated, timeCCingOthers,
challenges.enemyChampionImmobilizations, totalHeal (includes heals on teammates),
totalHealsOnTeammates, totalDamageShieldedOnTeammates, damageDealtToBuildings. From Data
Dragon of the game's own patch (DDRAGON/<patch>/champion.json and item.json, patch from
gameVersion; deploy/snapshot.sh make fetches each queue 420 patch's into SNAP/ddragon/):
armor_end, mr_end = base + growth at level 15 (Riot's curve) plus the flat armour/MR of
item0..item6 at the end, no ability resists; attack_range the base range. Real
minute-15 resists need raw timelines (championStats), archived only from 2026-10-12.
rows.loadSql joins it into rows.Row.stats by (match_id, slot); the pack stamps it, so
writing it makes the pack stale until `meiolol-lab pack` runs again. The harness copies
stats into api.Row for visible (training) games only; a Query has none.

`meiolol-lab nn-export SNAP` (src/lab/nnexport.zig) writes SNAP/nn/: rows.Data as one
little-endian file per column, one game per index, for GPU loaders (format agreed with
meiolol-f1; nnexport.read loads it back). champ.u8 [n][10] (dense index into
meta.champions, slot = side * 5 + role), platform.u8, patch.u8, start.i64, duration.u16,
blue_win.u8, split.u8 (0 dev's older half, 1-5 win-comp's forward-chaining fold blocks,
6 dev-val, 10 test, every platform, harness.Cuts; 7-9 empty since the 2253Z re-cut,
codes kept), flags.u8 (1 played 15:00+, 2 timeline to 15:00), aux.f32
[n][10][22] (the five early outcomes then SeatStat: targets, never inputs). meta.json:
names, test_cut, dev_cut, fold bounds and, per fit set (folds, dev-val, final) and
role, the aux mean, sd and count over played fit games only. nn.tmp, then renamed.

## Recommender (src/core/score.zig)

DraftGap-style additive log-odds: champion base rating plus synergy with allies plus
matchups against enemies, each pair smoothed toward what the two base ratings predict
(prior games, default 1000), so sparse pairs contribute ~0. Unknown roles (enemies in
ranked) inferred by brute force over role permutations using play rates. Returns
several options with reasons. From 23 Oct a stats file with a fitted model (v2) scores
drafts with that instead (additive v2: each block's shrinkage estimated, not a fixed
prior; Options.fitted); page rates (roleWin, duoPp, matchupPp) keep the counts.
draftTerms/draftWin score a full draft (eval, Daily Draft). How well it predicts:
docs/model.md.
