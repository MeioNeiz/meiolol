# Architecture

```
build.zig            modules: core (pure), store (SQLite C), backend, app
src/
  main.zig           `meiolol` backend CLI: crawl, stats, site, status, champions
  ddragon.zig        champion ids/names from Data Dragon
  stats.zig          model file from the matches table (`meiolol stats`)
  site/              public website generator (`meiolol site`): html.zig layout and
                     boilerplate, prose.zig fixed pages, static/ (css, draft.js)
  wasm.zig           recommender for the site's draft helper (wasm32-freestanding),
                     embedded into the backend binary by build.zig
  riot/              Riot API: ratelimit, client (std.http), endpoints, match parser,
                     crawl (threaded crawler)
  store/             sqlite.zig (thin wrapper), schema.zig, raw.zig (compression)
  core/              pure, std only, shared: roles, statsfile (model file format),
                     score (recommender)
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

- `raw.db`: every fetched document (match JSON, mastery) as compressed JSON keyed by
  (source, key). gzip for new rows; early rows from the retired Python crawler are
  zstd. std decompresses both, compresses only deflate; told apart by magic bytes
- `meiolol.db`: crawl state (players, ladder_pages, match_queue) and normalised tables
  (matches, participants, bans, mastery, champions)
- Match ID is the permanent key. PUUIDs are encrypted per API key: a new key (eg
  personal -> production) gives new PUUIDs for the same players
- Scale: ~60k matches/day, ~15 KB raw each, ~330 GB/year. 945 GB free on the box

## Crawler (src/riot/crawl.zig)

Two threads on separate Riot rate limit buckets, each with its own DB connection,
HTTP client and limiter (no shared state but atomics):

- platform (euw1): league-exp ladder pages for every tier (players + rank snapshot,
  refreshed daily), then champion mastery with spare budget
- regional (europe): match ids per player (last 14 days, queue 420), then match
  details, newest first; refills the queue only when under 300 pending (~3% overhead)

Players are scanned in PUUID order (effectively random): no rank or activity bias.
Limits come from Riot's headers (X-App/Method-Rate-Limit and their -Count, which also
corrects for requests made by another process); 429s honour Retry-After. Exit code 3
when Riot rejects the key; deploy/box.sh's restart loop stops on it.

## Model file (src/core/statsfile.zig)

The contract between backend and app: `MEIOSTAT` v1, champion-role games/wins plus
dense ally and enemy pair tables per role pair (~12 MB). Format spelled out at the top
of statsfile.zig; bump the version on any change. Written by `meiolol stats` (default:
newest patch; `--patch 16.19,16.20` for several) to data/export/stats-<patch>.bin. Only
ranked solo games with no remake, a winner and all ten positions count.

## Recommender (src/core/score.zig)

DraftGap-style additive log-odds: champion base rating plus synergy with allies plus
matchups against enemies, each pair smoothed toward what the two base ratings predict
(prior games, default 1000), so sparse pairs contribute ~0. Unknown roles (enemies in
ranked) inferred by brute force over role permutations using play rates. Returns
several options with reasons. A trained model replaces this later behind the same API.

## Website (src/site, src/wasm.zig)

`meiolol site --contact EMAIL` writes static files to data/site: tier list per role,
a page per champion (lane matchups, duos), draft helper, about, download, privacy,
terms, robots.txt, optional riot.txt, data/stats.bin + data/champions.json. Champion
icons hotlink Data Dragon. Edges and tiers use the same maths as the app
(score.roleWin, matchupPp, duoPp). Draft helper: draft.js runs core.recommend compiled to
wasm (~80 KB), so site and app always agree. Preview mode by default (noindex,
robots.txt disallow, banner): Riot forbids serving the public on a personal key;
`--public` only once the production key is granted. `deploy/box.sh site EMAIL` builds
it on the box and rsyncs it to data/site. `meiolol serve` (src/serve.zig) serves a site
directory over HTTP with .gz siblings; `deploy/box.sh web` runs it on the box
(localhost:8080) with a daily rebuild. Public hosting planned on the jomove server
(docs/plan.md).

Known gaps: stats.bin is dense (~12 MB raw; brotli helps while sparse), no rank
brackets (statsfile has none), no per-patch history.

## App (src/app_main.zig, src/lcu)

- Finds the client via --lockfile, MEIOLOL_LOCKFILE, the install path, then the process
  list. Polls the champ select session every second; read-only GETs only
- Redacts identity fields (gameName, puuid, ...) from anything it prints or saves
- Never shows other players' names or stats (Riot policy, docs/production-key.md)
- Known gaps: no network timeouts in Zig 0.16 Threaded IO; refused connect on Windows
  surfaces as error.Unexpected (mapped to ClientNotRunning)
