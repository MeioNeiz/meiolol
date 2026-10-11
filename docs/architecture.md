# Architecture

```
build.zig            modules: core (pure), store (SQLite C), backend, app
src/
  main.zig           `meiolol` backend CLI: crawl, stats, site, status, champions
  ddragon.zig        Data Dragon: champion ids/names; item classes, rune and spell names
  date.zig           UTC dates (Date: format, parse, epoch days)
  pipeline_test.zig  fixture games through stats, curves and the site
  daily.zig          Daily Draft puzzles (data/daily), published by `meiolol site`
  learn.zig          Learn page data: champion facts, practice draft pack
  curves.zig         lane matchup curves from timelines (`meiolol curves`)
  builds.zig         builds per champion and role (`meiolol builds`, JSON for the site)
  pool.zig           Pool: who mains X also plays Y, hard-lane options, ban fallback
  learning.zig       learning curves: results by games played on a champion
  stats.zig          model file from the matches table (`meiolol stats`)
  eval.zig           draft model on held-out newer games (`meiolol eval`, docs/model.md)
  api/               "Your games" service (`meiolol api`, docs/your-games.md): cache.zig
                     (api.db), fetch.zig (the one Riot caller), game.zig (lane vs curve)
  backup.zig         `meiolol backup|restore`: state snapshots + append-only segments
  forget.zig         `meiolol forget`: GDPR erasure, `forgotten` suppression list
                     (both: docs/data-safety.md)
  site/              public website generator (`meiolol site`): html.zig layout and
                     boilerplate, prose.zig fixed pages, static/ (css, draft.js)
  wasm.zig           recommender in the browser (wasm32-freestanding),
                     embedded into the backend binary by build.zig
  riot/              Riot API: ratelimit, client (std.http), endpoints (platforms and
                     regions), match parser, timeline (compact format), crawl
  store/             sqlite.zig (thin wrapper), schema.zig, raw.zig (compression)
  core/              pure, std only, shared: roles, statsfile (model file format),
                     score (recommender), curvesfile (lane curves format)
  lcu/               League client: lockfile/process discovery, https (TLS to
                     127.0.0.1 trusting only riotgames.pem), session (champ select)
  app_main.zig       `meiolol-app`: suggest (offline), watch (live), session, get
deploy/box.sh        cross-compile (static musl, for the host's CPU) and run on the box
deploy/systemd/      the box's loops as systemd user services (docs/hosting.md)
deploy/*-loop.sh     box loops in tmux: web (site upload), backup, health (ntfy);
                     health.sh the checks, mac-watch.sh the Mac side (launchd)
testdata/lcu/        champ select fixtures (session-synthetic.json is made up)
src/riot/testdata/   one real match-v5 JSON, PUUIDs and names replaced
```

Only C dependency: SQLite amalgamation, fetched by build.zig.zon, compiled by Zig.
Cross-compiles to Windows, Linux and macOS from the Mac; nothing to install on the box.

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
  timelines and rank snapshots stay. Re-storing a match keeps its PUUIDs and rank
- Privacy (crawler writer, hourly): players no ladder page or match has shown for 30 days
  are deleted with their mastery, and mastery older than 30 days is refetched (Riot's
  monthly refresh; erased accounts drop out). A mastery refetch that Riot answers 404
  deletes the player at once. Matches older than 24 months lose their PUUIDs.
  `forgotten` (plain PUUIDs, so a rekey can translate them and the Your games service
  can exchange them; written by `meiolol forget`, src/forget.zig)
  is honoured: never stored as players or mastery, blanked in participants, and no
  raw summary or raw timeline kept for their matches
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

Each bucket's limiter paces requests evenly (one per window / limit) instead of filling
a window in a burst, and `--reserve PCT` (box: 20) only applies while another process
uses the key: Riot's -Count headers show requests we did not send (ignored for one
window after start, when they are a previous run's), then for 10 minutes the crawler
keeps under 100 - PCT of the limit. The log says "another process is using the key".
So the crawler takes the whole key unless the Your games service is busy.
Only Riot's key errors, OOM and SQLite errors outside a match stop the crawler; a bad
page, player or match (including one SQLite cannot store) is logged and skipped.
Limits come from Riot's headers (X-App/Method-Rate-Limit and their -Count, which also
corrects for requests made by another process); 429s honour Retry-After. Exit code 3
when Riot rejects the key; deploy/box.sh's restart loop stops on it.

## Model file (src/core/statsfile.zig)

The contract between backend and app: `MEIOSTAT` v1, champion-role games/wins plus
dense ally and enemy pair tables per role pair (~12 MB). Format spelled out at the top
of statsfile.zig; bump the version on any change. Written by `meiolol stats` (default:
newest patch; `--patch 16.19,16.20` for several; `--platform` picks platforms, default
EUW1, since the site says EUW) to data/export/stats-<patch>.bin. Only ranked solo
games with no remake, a winner and all ten positions count.

## Lane curves (src/curves.zig, src/core/curvesfile.zig, curvefit.zig, src/site/matchup.zig)

`meiolol curves` (--platform as stats, --min-games default 1: all) reads every ranked
solo game with a timeline: by default every patch of the last --days (30) to
data/export/recent-curves.bin (label "last 30 days"); with --patch, those patches to
data/export/curves-<patch>.bin (the Your games service reads these per patch). Per lane
matchup (role, champion pair), bracket (all, Iron-Silver, Gold-Emerald, Diamond+;
median visible tier of the game's players, never MMR) and experience (all games, or a
or b with 100k+ mastery): per minute 1..25 the raw p25/p50/p75 of gold, XP and CS (lane
+ jungle) difference with n still playing, and the estimated mean with its standard
error (below); who leads in gold at 14 min and how often each side then wins; comeback
odds (games and wins by lane gold lead at 10 and 15 min in five buckets); games where
each takes part in killing the other before 6, 6-14 and after 14 min; median level 6 and
first finished item times; `own`, the share of the 14-min gold estimate from the
matchup's own games. A role baseline record a = b = 0 per bracket counts every lane from
both sides: comeback counts, and per minute n and the role's spread (quartiles,
median 0). Pairs are stored once (lower champion id first, a mirror from blue's side);
`Curves.get(role, bracket, me, them)` returns a View from `me`'s side that negates and
swaps quartiles and estimates. The file also holds the fit (per role, bracket, level,
metric and minute: sigma^2 and tau^2; smoothing per role and metric) for the method
page. Format at the top of curvesfile.zig; bump the version on any change.

Estimation (src/core/curvefit.zig, research/questions/curve-statistics-method.md), per
role, metric and minute, closed form: champion effects by ridge least squares on the
pairs' means (baseline A vs B = e_A - e_B; ridge by method of moments); tau^2 = unweighted
mean over pairs with 2+ games of (r^2 - s^2/n), r = mean - baseline, s^2 the pair's own
variance (rare pairs vary more than the pooled sigma^2), floored at sigma^2/100, so k =
sigma^2/tau^2 <= 100; estimate = baseline + n/(n+k) r. Brackets shrink toward the
all-ranks curve and experienced curves toward their bracket's, tau^2 from each unit
against the rest of its parent's games (the parent holds the unit's games). Then a
Whittaker smoother (second differences) across minutes, its strength per role and
metric picked by a split-half test (fit on half the games by game hash, score against
the other half's raw means; leave-one-minute-out would pick too little, as a curve's
minutes share their games). The command logs per role and metric sd/tau/k at 5, 10, 14
and 20 min, nested k, lambda and the split-half error of zero, baseline, raw, shrunk and
smoothed predictors. Not yet: patch decay weights, same-player clustering (n_eff), tau^2
smoothed across minutes.

Measured 2026-10-11 on 18.8k games (all regions, Platinum IV+ crawl, mostly 16.19):
sd of gold difference at 14 min 790 (support) to 1650 (bot); tau 140-240 gold; k at 14
min gold: top 67, jungle 73, mid 29, bot and support at the cap (100). Split-half rms
error at 14 min (top gold, 1611 pairs, noise of the other half 1054): raw means 1445,
role mean 0 1130, baseline 1078, shrunk 1073: thin raw means are far worse than the
baseline, and at this volume the baseline carries almost all of it; too few pairs have
50+ games to see the matchup term pay. Smoothing chosen near zero (lambda 0 to 1) except
support gold (100). Nested k is noisy (few units with games in both parts). On the box
(27k games, 15:29Z): pairs with 50+ games in the fitting half (bot 63, support 32): the
baseline alone did as well as or better than shrunk (bot gold 173 vs 204, noise 182), so
the matchup term does not pay yet; a higher k cap (300, 1000) did not help overall
(tried on the Mac). ReleaseFast on the Mac: 4 s and 163 MB peak for those 18.8k games,
file 37 MB (13.7k matchups, every bracket and experience variant with 1+ game). On the
micro with the crawler running: EUW 7.6k games 2.5 min, all regions 27k games 6.3 min
(~30 s of fitting per role). Memory grows with lanes (~180 B each, 5
per game): ~2.7 GB at 30 days of all regions at ~100k games/day, beyond the micro's 1
GB; the A1 (12 GB) holds it.

`meiolol site` reads recent-curves.bin when present (curves-<patch>.bin with --patch;
the rest of the site stays on the newest patch): a page per matchup
with an all-ranks curve (matchup/<role>/<a>-vs-<b>.html, lower id first), three SVG
charts (line = estimated mean; band = the matchup's middle half of games from 200 games,
below that the role's middle half drawn around the line, said in the caption; ±2 SE at
14 min, period, tier and n in every caption; a dotted line at 15 min, surrender, and the
share of games ended by 20 and 25 min), a lane and game table (incl. first finished item
times), comeback odds (src/site/comeback.zig: win rate per gold bucket at 10/15 min
beside the role baseline, one fact line), a by-rank table (estimate ±2 SE), and "Lane
curves" links on champion pages. "Games counted" radios (all games, X or Y players with
100k+ mastery, offered from 10 such games) switch charts and table by CSS :has, no
script. Every matchup gets a page, as on lolalytics; under 200 games or with own < 0.5
("mostly the champions' baseline") charts and rows are grey, and a chart draws minutes
with at least min(10, games) still going. The method page shows k by role and minute
from the view with the most games. Size: 13.7k pages in the all-regions 30-day view at
18.8k games, 252 MB with .gz; raise --min-games if the upload grows too big. The index
has a min games selector (html.minGames, static/min-games.js; default 1). Not yet:
core-item split, older patches, rank filter. deploy/web-loop.sh rebuilds the four
curves files hourly and on a new patch.

## Builds (src/builds.zig, src/site/builds.zig)

`meiolol builds` (--patch default the newest, --platform as stats, --min-tier default
PLATINUM per player from participants.tier, "any" for everyone) writes
data/export/builds-<patch>.json (all-builds-... with --platform all): per champion and
role the 10 most played options of each kind with games and wins, plus the kind's total
(the share's whole) and names/icons of what they use, so the site needs no network.
Kinds: keystone, rune page (both trees, secondary pair sorted), stat shards, summoner
spells (unordered pair) from participants; from timelines: starting items (bought in the
first 90 s, net of undo and sale, no trinkets), boots (first tier-2, tier 3 counted as
its tier 2; "no boots" once two items are finished without), first two and first three
finished items in purchase order (ddragon legendary rule, as first-item timing; an undone
purchase comes off), skill priority (Q/W/E by points after 13 skill-ups or the game's end
from 11, ties by who got there first; EVOLVE ups skipped). Needs Data Dragon's item.json,
runesReforged.json and summoner.json for the patch (ddragon.buildData); stat shard names
are a table in ddragon.zig.

Memory: one hash map of distinct options (~50 B each) capped by --max-keys (default
512k, ~30 MB); at the cap options at or under a rising count floor are dropped (logged),
totals never. Per game an arena reset, like curves. Measured on 3.8k EUW 16.20 games
(1.7k timelines): 1 s, 29 MB RSS, 25k options, 1.1 MB JSON; ~0.25 ms per timeline, so
a full EUW patch (~400k) is a couple of minutes on a fast disk; on the micro the
first run took ~7.5 ms a game (docs/plan.md "Builds"). deploy/web-loop.sh runs EUW and all
regions for the current patch daily and on a new patch, in the background at nice 10
(log data/builds.log); the next site build picks them up.

`meiolol site` reads the current patch's two files: a page per champion and role in the
patch views (patch/build/<slug>-<role>.html, all/patch/...) when the role has 10%+ of
the champion's games in the file; champion pages link to it from each role section (the
30-day views into their region's patch view; switches fall back to the champion page).
Rows most played first, never by win rate, no "best" or "recommended": games and share
on every row, a win rate only from 100 games and always with its 95% range (±1.96 SE),
rows under 400 greyed, a "more data needed" note under 400 for the champion-role. Item,
rune and spell icons hotlink Data Dragon like champion icons. Method page section
`#builds`. Not yet: a builds index or nav entry, first-three skill levels, item timing,
builds by rank or matchup.

## Pool (src/pool.zig, src/site/pool.zig, static/pool.js)

A player's main is their top champion; they play another when it has at least 10% of
the main's weight (games now, mastery points once that table fills; min 10 games).
"Players who main X also play Y" is lift: share of X-mains playing Y over Y's share
among players who don't main Y, shrunk toward 1 by 20 pseudo-players; lists from 30
mains, n shown. From the model file's lane pairs (score.matchupPp, 30+ games): X's
five worst lane matchups, the also-played champions in X's role that are positive into
them ("options", several, with reasons), and those positive into X's best lanes (ban
fallback). `meiolol site` writes data/pool.json, pool.html (pick up to three mains;
pool.html#garen,darius) and a section on each champion page; `meiolol pool` writes the
same JSON to data/export/pool.json for a look. Mastery source (points, champions
played in the last year, 50k total and 10k per champion) is used once it has more
players than the games source. Not yet: curves instead of win rates for hard lanes,
your own record per matchup.

## Learning curves (src/learning.zig, src/site/learning.zig)

For players whose match history was crawled, each ranked solo game's number on that
champion (all patches) goes into bins 1-5, 6-20, 21-50, 51+: games, win rate, and lane
gold difference at 14 (timeline frame 14, laner minus lane opponent) where a timeline
exists. "Usual by games X-Y": the first bin within 1 point of the champion's overall win
rate, only when every bin up to it has 400+ games; bins under 200 are greyed. Games
before the crawl window count as early games, so early bins hold some returning players
(the gap shown is too small, never too big); mastery can correct that once it fills.
`meiolol site` writes data/learning.json, a section on each champion page, a "How long
champions take to learn" table on pool.html, and a line per pool option.

## Recommender (src/core/score.zig)

DraftGap-style additive log-odds: champion base rating plus synergy with allies plus
matchups against enemies, each pair smoothed toward what the two base ratings predict
(prior games, default 1000), so sparse pairs contribute ~0. Unknown roles (enemies in
ranked) inferred by brute force over role permutations using play rates. Returns
several options with reasons. A trained model replaces this later behind the same API.
draftTerms/draftWin score a full draft (eval, Daily Draft). How well it predicts:
docs/model.md.

## Website (src/site, src/wasm.zig)

Views (html.View), as lolalytics' filters: region (EUW, or every platform) by period
(games started in the last 30 days, or EUW's newest patch). EUW over 30 days is the
default at the site root; the others under patch/, all/ and all/patch/. Each has its own
stats, pool and curves file (recent-curves.bin, curves-<patch>.bin, and all- versions
from `meiolol curves --platform all`). Header switches link to the same page in another
view (a matchup that view lacks: its matchup index); localStorage remembers the last
view so shared pages (Daily Draft, Learn, Your games, legal: at the root only, made
from the EUW patch view; learn.js reads patch/data/stats.bin) link back into it.

`meiolol site --contact EMAIL` writes static files to data/site, framed as "learn your
lane" for the production review (docs/concept.md "Application wording": no tier list,
draft helper, best pick or recommend wording): landing page, matchup index and pages,
Daily Draft, a page per role (role/<role>.html, most played first, no tier grades), a
page per champion (lane opponents and teammates by edge, lane curve links; a min games
selector, default 400 plus clearing chance, lower shows thinner pairs greyed: each card
carries the top 6 for every choice, hidden unless chosen), method,
download (desktop app, in development), privacy, terms, robots.txt, optional riot.txt,
data/stats.bin (for the app) + data/champions.json, meiolol.wasm (core.recommend in the
browser, for pages that score drafts). Champion icons hotlink Data Dragon. Edges use the
same maths as the app (score.matchupPp, duoPp). Preview mode by default (noindex,
robots.txt disallow, banner): Riot forbids serving the public on a personal key;
`--public` only once the production key is granted. `deploy/box.sh site EMAIL` builds
it on the box and rsyncs it to data/site. `meiolol serve` (src/serve.zig) serves a site
directory over HTTP with .gz siblings; handy for local previews. Hosting:
meiolol.jomify.lol, static nginx on the jomove server, uploaded from the box by
deploy/web-loop.sh (every 15 min early in a patch, then hourly; docs/plan.md step 2),
and at once on each push to main (deploy/on-push.sh).

Known gaps: stats.bin is dense (~12 MB raw; brotli helps while sparse), no rank
brackets (statsfile has none), no per-patch history.

## Daily Draft (src/daily.zig, src/site/daily.zig, static/daily.js)

One real ranked solo game a day, same for everyone: one slot hidden behind four options
(the played champion plus three from the 20 core.recommend rates highest in that draft),
then guess the winner. Pick order is not in match-v5, so "which was picked last" became
"which was played here". The reveal is facts plus numbers, never "the correct pick":
result, length, team kills and gold, blue's estimated win chance, the five same-role lane
edges with games (greyed under 200), and each option's points with reasons.

- Made by `meiolol site` (every web-loop build): puzzles for today to today+2 (UTC) that
  do not exist yet, from the site's patches and platforms. Puzzle #1 = 2026-10-11
- data/daily/<n>.json is the public puzzle, written once and never remade (the numbers
  are frozen at that day's data); data/daily/used.txt holds the match ids behind them so
  none repeats. used.txt stays on the box: never under site/
- GDPR: puzzles hold no PUUIDs; used.txt holds match ids, so a deletion that covers a
  match means dropping its line (the puzzle itself stays anonymous)
- A failure here (or a bad curves file) is logged and the rest of the site still builds
- Anonymised: no Riot IDs, PUUIDs, match ids or game dates; tier is the median visible
  rank of the players we have a rank for, only when 5+ are known
- Site: daily.html + daily.js, daily/index.json ([{n, date}]) and daily/<n>.json. The
  page shows the viewer's local date's puzzle (hence two days ahead), ?n= for the
  archive. Guesses, streak and archive in localStorage (key meiolol.daily.v1); share
  text is an emoji grid with the link

## Your games service (src/api, src/site/your.zig, static/your.js)

`meiolol api` on the jomove server behind nginx at /api/; details, privacy decisions and
deploy steps in docs/your-games.md. Requests answer from api.db (own SQLite file, not
the crawler's) and queue jobs; one fetcher task makes every Riot call within a budget per
route (default 20 per 2 min) on top of the shared Limiter. Matches cached by id (summary
without names, PUUIDs hashed; compact timeline). Per-game numbers come from curves.zig
`lane()`, compared with `Curves.get` for the player's visible-tier bracket. Objection:
profile-icon check, then delete and block the PUUID. Players not looked up for 30 days
are pruned.

## Learn (src/learn.zig, src/site/learn.zig, static/learn.js)

For new players: five lessons (roles, counters and why your own champion matters more,
early vs late, mixing damage, synergy), each with examples picked from the patch's games
and a three-question check, then unlimited practice drafts. No streaks or timers.

- Facts, made per site build: magic share of each champion's damage to champions (raw
  match JSON of the newest 3000 games), wins by game length (<25, 25-32, 32+ min) per
  champion and role, and team win rate by damage mix (<30% / 30-70% / 70%+ magic)
- Lessons show raw win rates with n, not model points: at a few thousand games the
  model's pair terms are noise (draft-model eval: AUC 0.52). Examples are ranked by the
  smoothed edge so thin pairs stay out of the top; an early-data note under 50k games
- Practice pack (learn/practice.json, ~240 drafts): real games anonymised as the Daily
  Draft, leaving out its used.txt games; remade daily from a seed of the day. Graded on
  facts, not pp spread: easy = the four teammates lean one damage type and exactly one
  option brings the other; medium = two do; hard = balanced team. Options are the
  recommender's candidates that are usual for the role (30%+ of their games, 15+)
- The reveal explains every option (damage fit, role win rate, game length, model
  reasons with 50+ games, lane gold curve when the curves file has the pair), never "the
  correct pick". Champions the player adds join the options (meiolol.wasm scores them,
  request field `pool`)
- Site: learn.html (checks and glossary as embedded JSON), learn.js, learn/champs.json,
  learn/practice.json. Progress in localStorage (key meiolol.learn.v1)

## App (src/app_main.zig, src/lcu)

- Finds the client via --lockfile, MEIOLOL_LOCKFILE, the install path, then the process
  list. Polls the champ select session every second; read-only GETs only
- Redacts identity fields (gameName, puuid, ...) from anything it prints or saves
- Never shows other players' names or stats (Riot policy, docs/production-key.md)
- Known gaps: no network timeouts in Zig 0.16 Threaded IO; refused connect on Windows
  surfaces as error.Unexpected (mapped to ClientNotRunning)
