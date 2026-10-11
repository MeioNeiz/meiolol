# Architecture

```
build.zig            modules: core (pure), store (SQLite C), backend, app
src/
  main.zig           `meiolol` backend CLI: crawl, stats, site, status, champions
  ddragon.zig        champion ids/names from Data Dragon
  daily.zig          Daily Draft puzzles (data/daily), published by `meiolol site`
  curves.zig         lane matchup curves from timelines (`meiolol curves`)
  pool.zig           Pool: who mains X also plays Y, hard-lane options, ban fallback
  learning.zig       learning curves: results by games played on a champion
  stats.zig          model file from the matches table (`meiolol stats`)
  eval.zig           draft model on held-out newer games (`meiolol eval`, docs/model.md)
  api/               "Your games" service (`meiolol api`, docs/your-games.md): cache.zig
                     (api.db), fetch.zig (the one Riot caller), game.zig (lane vs curve)
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
deploy/box.sh        cross-compile (x86_64-linux-musl, static) and run on gpu-box
testdata/lcu/        champ select fixtures (session-synthetic.json is made up)
src/riot/testdata/   one real match-v5 JSON, PUUIDs and names replaced
```

Only C dependency: SQLite amalgamation, fetched by build.zig.zon, compiled by Zig.
Cross-compiles to Windows, Linux and macOS from the Mac; nothing to install on the box.

## Storage (on the box, ~/ml/meiolol/data)

- `raw.db`: fetched JSON, gzip (early rows from the retired Python crawler are zstd;
  std decompresses both, compresses only deflate; told apart by magic bytes). Rolling,
  pruned hourly by the crawler: `raw_docs` match summaries 30 days
  (`--raw-match-days`), `timeline_docs` timelines 7 days (`--raw-timeline-days`; ones
  that failed to parse are kept). `meiolol rebuild` re-parses kept summaries into the
  tables after a parser or schema change. Mastery is not kept raw
- `timeline.db`: `timelines`, one compact blob per match (src/riot/timeline.zig: per
  minute per participant gold, xp, level, CS, position, damage, CC; events: kills
  with position, items, skills, wards, buildings, plates, monsters, transforms). ~8.6
  KB vs ~60 KB raw gz, lossless for those fields; `timeline.decode` reads it.
  Participant id = slot + 1. Kept forever
- `meiolol.db`: crawl state (players, ladder_pages, match_queue, timeline_queue) and
  tables kept forever: matches, participants (incl. final items, full rune page, and
  tier/division = rank snapshot when the match was stored), bans, mastery (one
  compact blob per player, src/riot/mastery.zig, ~0.7 KB), champions. Text-keyed
  tables are WITHOUT ROWID (no second copy of the key in an index)
- Match ID is the permanent key and carries the platform (EUW1_, KR_); matches.platform
  and players.platform/region let stats pool or split regions
- PUUIDs are encrypted per app: switching app (dev -> personal -> production) gives
  new PUUIDs. `meiolol rebuild` then `meiolol rekey` forgets players, ladder and
  mastery (re-seeded from the ladders) and blanks old PUUIDs in participants; matches,
  timelines and rank snapshots stay. Re-storing a match keeps its PUUIDs and rank
- Privacy (crawler, hourly): players no ladder page or match has shown for 30 days
  are deleted with their mastery, and mastery older than 30 days is refetched (Riot's
  monthly refresh; erased accounts drop out). Matches older than 24 months lose their
  PUUIDs. `forgotten` (sha256 of PUUIDs, written by `meiolol forget`, src/forget.zig)
  is honoured: never stored as players or mastery, blanked in participants, and no
  raw summary or raw timeline kept for their matches
- Schema changes: `schema.zig` migrate() alters or rebuilds tables in place (checks
  inside the write lock, so concurrent opens are safe). Back up before a first run
- Scale at full rate (4 regions, ~135k matches/day): kept forever ~8.6 KB timeline +
  ~3 KB rows per match, ~1.6 GB/day, ~570 GB/year; rolling raw ~50 GB summaries + ~60
  GB timelines; mastery ~1 KB per ranked player, bounded. Real headroom ~250 GB: the
  WSL disk (df shows a 1 TB cap) lives on C: with ~250 GB free, so ~3 months at full
  rate until it moves to the 2 TB NVMe

## Crawler (src/riot/crawl.zig)

All regions by default (`--regions` to limit). A personal key's limits apply per
routing value, so one thread per bucket, each with its own DB connection, HTTP client
and limiter (no shared state but atomics): 4 regional + 15 platform threads. Platform
to region map: `platforms` in src/riot/endpoints.zig.

- platform (euw1, kr, na1, ...): league-exp ladder pages for every tier (players +
  rank snapshot, refreshed daily), then champion mastery with spare budget
- regional (americas, asia, europe, sea): match ids per player of its platforms (last
  14 days, queue 420), match details, then timelines of non-remakes (`--timelines PCT`,
  default all, picked by match id hash). Queues are FIFO per region; ids refill only
  under 300 pending. Timeline batches (60) outsize match batches (40) so a backlog
  drains. Per match ~2.13 calls (match + timeline + ids), so ~33k matches/day/region
- main thread: per-region report every minute, raw pruning hourly. On first start with
  an empty timeline_queue, queues timelines for already crawled matches

Players are scanned in PUUID order (effectively random): no rank or activity bias.
`--priority` platforms (default EUW1) are scanned before the rest of their region, so
EUW gets the whole europe bucket while it has players due. `--reserve PCT` leaves part
of every bucket to other processes on the key (the Your games service).
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

## Lane curves (src/curves.zig, src/core/curvesfile.zig, src/site/matchup.zig)

`meiolol curves` (same --patch/--platform as stats, --min-games default 20) reads every
ranked solo game with a timeline and writes data/export/curves-<patch>.bin. Per lane
matchup (role, champion pair) and bracket (all, Iron-Silver, Gold-Emerald, Diamond+;
median visible tier of the game's players, never MMR): per minute 1..25 the p25/p50/p75
of gold, XP and CS (lane + jungle) difference with n still playing; who leads in gold at
14 min and how often each side then wins; comeback odds (games and wins by lane gold
lead at 10 and 15 min in five buckets, plus a role baseline record a = b = 0 counting
every lane from both sides); games where each takes part in killing the
other before 6, 6-14 and after 14 min; median level 6 time. Pairs are stored once (lower
champion id first, a mirror from blue's side); `Curves.get(role, bracket, me, them)`
returns a View from `me`'s side that negates and swaps quartiles. Format at the top of
curvesfile.zig; bump the version on any change. Memory: ~170 B per lane record, ~1 GB
at 1M games; fine on the box (15 GB).

`meiolol site` reads the curves file for its patches when present: a page per matchup
with an all-ranks curve (matchup/<role>/<a>-vs-<b>.html, lower id first), three SVG
charts (median line, middle-half band; patch, tier and n in every caption), a lane and
game table, comeback odds (src/site/comeback.zig: win rate per gold bucket at 10/15
min beside the role baseline, one fact line), a by-rank table, and "Lane curves" links
on champion pages. Under 200 games
charts and rows are grey with "more data needed". Not yet: first-item timing (needs an
item list from Data Dragon), experienced-players filter (mastery), core-item split,
region filter. Curves are not built by the web loop yet: run `meiolol curves` (daily is
plenty) before `meiolol site`.

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

`meiolol site --contact EMAIL` writes static files to data/site, framed as "learn your
lane" for the production review (docs/concept.md "Application wording": no tier list,
draft helper, best pick or recommend wording): landing page, matchup index and pages,
Daily Draft, a page per role (role/<role>.html, most played first, no tier grades), a
page per champion (lane opponents and teammates by edge, lane curve links), method,
download (desktop app, in development), privacy, terms, robots.txt, optional riot.txt,
data/stats.bin (for the app) + data/champions.json, meiolol.wasm (core.recommend in the
browser, for pages that score drafts). Champion icons hotlink Data Dragon. Edges use the
same maths as the app (score.matchupPp, duoPp). Preview mode by default (noindex,
robots.txt disallow, banner): Riot forbids serving the public on a personal key;
`--public` only once the production key is granted. `deploy/box.sh site EMAIL` builds
it on the box and rsyncs it to data/site. `meiolol serve` (src/serve.zig) serves a site
directory over HTTP with .gz siblings; handy for local previews. Hosting:
meiolol.jomify.lol, static nginx on the jomove server, uploaded from the box by
deploy/web-loop.sh (often early in a patch, then daily; docs/plan.md step 2).

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
profile-icon check, then delete and block the PUUID. Players not looked up for 90 days
are pruned.

## App (src/app_main.zig, src/lcu)

- Finds the client via --lockfile, MEIOLOL_LOCKFILE, the install path, then the process
  list. Polls the champ select session every second; read-only GETs only
- Redacts identity fields (gameName, puuid, ...) from anything it prints or saves
- Never shows other players' names or stats (Riot policy, docs/production-key.md)
- Known gaps: no network timeouts in Zig 0.16 Threaded IO; refused connect on Windows
  surfaces as error.Unexpected (mapped to ClientNotRunning)
