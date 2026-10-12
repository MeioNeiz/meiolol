# Your games: the service

The dynamic part of the site (docs/concept.md, product 1): enter a Riot ID, see each
recent ranked solo game's lane laid over the typical curve for that matchup at your rank,
then a weekly roll-up and per-matchup trend. `meiolol api` (src/api) serves JSON at
/api/ behind nginx on the jomove server; site/your.html + your.js (src/site/your.zig,
static/your.js) is the page. Live in preview (/api/ behind basic auth): Deploy below.

## How it works

- Lookups never call Riot in the request. GET /api/games?id=Name%23TAG answers from
  api.db at once and queues a job; one fetcher task (src/api/fetch.zig) is the only Riot
  caller and works the queue oldest first; the page polls every 3 s and shows progress
- Per new Riot ID: account-v1 by Riot ID and active region (europe route), league-v4
  by PUUID (visible rank), match-v5 ids (queue 420, last 60 days), then match +
  timeline for up to 10 games not yet cached. ~23 regional calls plus 1 platform call
  for a first lookup; a refresh (at most every 30 min, on a visit) costs 2 plus 2 per new
  game
- Cache by match id (api.db `matches`): a summary of the match (champions, positions,
  results, K/D/A; no names) and the compact timeline (riot/timeline.zig, ~8 KB gz). A
  match shared by two looked-up players is fetched once
- Analysis on read (src/api/game.zig), reusing src/curves.zig `lane()` so a player's
  numbers are computed exactly as the curves are: per minute gold/XP/CS difference to
  the lane opponent (same teamPosition, other team), deaths and kills before 14 min,
  CS at 10, level 6 and first legendary item times (yours and theirs)
- Typical curve: `Curves.get(role, bracket, me, them)` from the curves file covering
  the game's patch (else the newest), bracket from the player's visible solo tier at the
  last refresh; all ranks when that bracket is too thin (the page says so). Every chart
  caption names bracket, patch and n; under 200 games it is grey ("more data needed"),
  minutes with n < 10 are not drawn
- Facts, never verdicts: gold difference at 14 against the typical middle half;
  biggest 3-minute fall and rise against the typical median (against an even lane when
  there is no curve) with deaths and kills in those minutes, shown only when 200+ gold;
  weekly games, wins, mean gold difference at 14 and mean against typical; per matchup
  the gold difference at 10 oldest to newest and the older vs newer half's mean
- Whole game (any role, lane opponent or not): the team's win chance per minute
  (src/winchance.zig: objectives.zig's "+ objectives held" state model fitted at every
  minute by `meiolol winchance`; weights in src/winchance_weights.zig, refit when the
  game changes), the turning minute (biggest one-minute change, with that minute's
  kills, deaths and objectives) and death cost per death (bounty and shutdown gold to
  the enemy, objectives the enemy took in the next minute, win chance before and after).
  Plate events after 14:00 are ignored (Riot sends them, worth nothing then)
- Tier is the visible rank (league-v4), never inferred MMR. It is the rank now, not at
  game time; the curves bracket games by the median visible rank of their players
- Not yet: the experienced-players curve (needs champion-mastery per player, more
  calls), recalls (not in match-v5 timelines), flex or other queues (curves are solo
  only)

## Example

your.html offers "See an example" (and `your.html?example`) when data/your-example.json
exists, so a visitor or Riot reviewer sees the page without a Riot ID (/api/ sits behind
basic auth in preview). `meiolol your-example` (src/api/example.zig, read-only, ~25 s on
the box) picks one EUW player with the most lane games with timelines in the last 7
days, Gold to Emerald first, never a `forgotten` one, and writes their 10 newest ranked
solo games through the same report() as the API. No name, PUUID or match id; game starts
cut to the day (UTC). The web loop runs it daily and copies the file into each site build.

## API

| Call | Answer |
| --- | --- |
| GET /api/games?id=Name%23TAG | state (queued, fetching, ready, not_found, opted_out), progress (ahead, pending, total), player, report |
| POST /api/forget?id=... | starts an objection: state pending, then issued with an icon |
| POST /api/forget?id=...&check=1 | checks the icon: checking, then done or mismatch |
| GET /api/forget?id=... | the objection's state (none, pending, issued, checking, mismatch, done, not_found, failed, expired) |
| GET /api/health | {ok, jobs} |

Queue capped at 30 jobs (503 "busy" beyond); objection checks jump the queue.

## Rate limits

The service shares the Riot key, so Riot's per-route app limits (100 per 2 min on a
personal key) with the crawler. On top of Riot's own limits (the shared Limiter, synced
from Riot's -Count headers, so it sees the crawler's calls), the service keeps to its own
budget: `--budget 20:120` per route by default. The crawler leaves room with
`meiolol crawl --reserve 20` (meiolol-de, c2a8d67): without it a lookup waits behind a
saturated bucket (measured 2026-10-11: 429 on the first call, ~2 min queued). The
reserve only applies for 10 minutes after the crawler sees the service's requests in
Riot's counts, and the crawler paces its requests evenly, so the first call finds a
slot within seconds and the rest of a lookup gets 20 per 2 min (docs/architecture.md,
Crawler). So a first lookup fits in about one budget window; a few lookups a minute is
the most the personal key allows, which is plenty in preview.

## Privacy: what is stored and shown, and why

Decided 2026-10-11 from research/questions/identity-and-privacy.md (meiolol-44):

- Any Riot ID may be looked up, on legitimate interests: League policy has no consent
  rule for ranked history (C1), and that is how lookup sites work (C8). The page shows
  only the looked-up player's own lane: their champion, the lane opponent's champion and
  the numbers. No other player's name or Riot ID, anywhere. Why the opponent's
  champion: the comparison is a champion matchup, and the curves are champion level.
  Teammates and the other eight players do not appear at all
- Stored per looked-up player: PUUID, Riot ID as Riot spells it, platform, visible rank,
  times of last refresh and lookup, and which slot they had in each game. Per match: the
  summary above without names or Riot IDs; the ten PUUIDs only as truncated SHA-256
  hashes (so a later lookup can find its slot in a cached match without refetching; a
  hash is pseudonymous, not anonymous: anyone with the PUUID can recompute it); and the
  compact timeline (per-minute stats per slot, no identities)
- Retention: a player nobody has looked up for 30 days is deleted (hourly prune), with
  matches no remaining player uses: Riot's advice to refresh stored players at least
  every 30 days (C7) and the privacy policy's promise. Each visit refreshes from Riot (at
  most every 30 min) and restarts the 30 days, so a player who comes back keeps their
  history for the per-matchup trend
- Objection and removal, open to anyone who owns the Riot ID: the page issues a random
  starter profile icon (ids 0-28, never the current one), the player sets it in the
  client within 15 min and presses check; the service re-reads it via summoner-v4 and on
  a match deletes everything about the player and blocks the PUUID (blocked table: PUUID
  and time, the minimum to honour the objection). Later lookups of that Riot ID answer
  "opted_out" without fetching. A random guess passes 1 time in 28. Squads will use the
  same check for consent. RSO replaces it once the production key allows (C6, C13)
- Riot's erasure lists and emailed requests: `api.cache.forget(db, puuid, now)` deletes
  and blocks; data-safety-af's `meiolol forget` calls it for api.db
- The box holds the same players (crawler DBs, backups). Forgotten PUUIDs sync both ways
  through the exchange directory, hourly and on each honoured objection: the service
  writes forgotten.txt (every blocked PUUID, one per line, no Riot IDs), the box pulls it
  and runs `meiolol forget --list`; the box pushes its own list as box-forgotten.txt and
  the service blocks those too. Both files are complete lists, so either side can rerun
- Logs: no Riot IDs. The service never logs them, and the Riot client shows account
  lookups by endpoint name instead of path. nginx does not log /api/ (`access_log off`
  below), since the query string holds the Riot ID
- Privacy page: "Your games" section on the site (src/site/prose.zig) and in
  docs/legal/privacy.md, matching the above
- Preview gating (Jacob left it to us, 2026-10-11): /api/ behind HTTP basic auth until
  the production key, since a personal key may not serve the public. User `meiolol`,
  password in vault (group meiolol/local, key MEIOLOL_API_BASIC_AUTH; also in .env). The
  browser asks once; your.html itself is public and harmless without the API

## Deploy (live since 2026-10-11, jomove server)

Jacob left the deploy and the preview gating to us. Server: jomove (x86_64, 1 GB RAM,
~540 MB free; the service uses ~11 MB plus up to 2 curves files).

- Binary: /usr/local/bin/meiolol (root 755), built on the Mac from a clean commit with
  `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSafe`. Not part of the box's
  push deploy: after a change to src/api or the curves file format (curvesfile.zig
  version), rebuild, `scp` to /tmp, `sudo install`, then `sudo systemctl restart
  meiolol-api`. Curves v4 binary installed 2026-10-11 15:23Z (f6bf5d6)
- User `meiolol-api` (system, no shell). /var/lib/meiolol-api (750): api.db. Exchange
  /var/lib/meiolol-api/exchange (meiolol:meiolol-api, 2770; `meiolol` is in the group):
  curves/ from the box, forgotten.txt out, box-forgotten.txt in
- Key: /etc/meiolol-api.env (root 600, RIOT_API_KEY only), the same key as the box
- systemd: meiolol-api.service (`meiolol api --data /var/lib/meiolol-api --exchange
  /var/lib/meiolol-api/exchange`, UMask 0007, Restart=on-failure, not on exit 3,
  MemoryMax 400M, ProtectSystem=strict); meiolol-api-reload.path watches exchange/curves
  and restarts the service through meiolol-api-reload.service. Logs: `sudo journalctl
  -u meiolol-api`
- nginx: /etc/nginx/conf.d/meiolol.conf only (jomove.conf untouched; the previous version
  is /etc/nginx/meiolol.conf.bak-2026-10-11). `limit_req_zone meiolol_api 60r/m` at the
  top; `location /api/` in the 443 server: auth_basic (/etc/nginx/meiolol-api.htpasswd,
  root:www-data 640), limit_req burst 30, access_log off, proxy_pass 127.0.0.1:8090,
  client_max_body_size 1k. `location /admin/` (the ops page, src/admin.zig): same
  htpasswd and realm, previous config /etc/nginx/meiolol.conf.bak-2026-10-12
- Preview gating: basic auth on /api/ until the production key (a personal key may not
  serve the public). User `meiolol`; password in vault (meiolol/local,
  MEIOLOL_API_BASIC_AUTH) and in .env. Remove /api/'s two auth_basic lines once the
  production key is granted; /admin/ keeps its own
- Box: ssh alias `meiolol-exchange` (key ~/.ssh/meiolol_exchange) is the rrsync user
  limited to the exchange dir (`command="/usr/bin/rrsync /var/lib/meiolol-api/exchange",
  restrict` in ~meiolol/.ssh/authorized_keys; the site key stays limited to
  /var/www/meiolol). deploy/web-loop.sh pushes the newest two curves files after each
  `meiolol curves` (push_curves); deploy/backup-loop.sh swaps the forgotten lists daily
  (data-safety-af)
- Crawler: `deploy/box.sh start` now defaults to `--reserve 20`
- Check: `curl -s -o /dev/null -w '%{http_code}' https://meiolol.jomify.lol/api/health`
  answers 401; with the password, {"ok":true,"jobs":N}. Live lookup tested through nginx
  on 2026-10-11 (10 games)

## Testing locally

`zig build && RIOT_API_KEY=... zig-out/bin/meiolol api --data /tmp/x --cors '*'` and
`zig-out/bin/meiolol serve --out <site dir>`; your.js talks to 127.0.0.1:8090 when the
page is on localhost. Live run 2026-10-11 (one Challenger EUW account, ~40 calls): 10
games cached in ~2.5 min (queued behind the crawler), objection issue, mismatch, success
(icon forced in the scratch DB), opted_out after.
