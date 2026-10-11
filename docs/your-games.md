# Your games: the service

The dynamic part of the site (docs/concept.md, product 1): enter a Riot ID, see each
recent ranked solo game's lane laid over the typical curve for that matchup at your rank,
then a weekly roll-up and per-matchup trend. `meiolol api` (src/api) serves JSON at
/api/ behind nginx on the jomove server; site/your.html + your.js (src/site/your.zig,
static/your.js) is the page. Not deployed yet: steps at the end, for Jacob.

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
- Tier is the visible rank (league-v4), never inferred MMR. It is the rank now, not at
  game time; the curves bracket games by the median visible rank of their players
- Not yet: the experienced-players curve (needs champion-mastery per player, more
  calls), recalls (not in match-v5 timelines), flex or other queues (curves are solo
  only)

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
saturated bucket (measured 2026-10-11: 429 on the first call, ~2 min queued). So a
first lookup fits in about one budget window; a few lookups a minute is the most the
personal key allows, which is plenty in preview.

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

## Deploy (not done: for Jacob)

Server: jomove (x86_64, 1 GB RAM, ~540 MB free; 2 curves files in memory at most).

1. Build on the Mac: `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSafe`;
   copy `zig-out/bin/meiolol` to the server as /usr/local/bin/meiolol (root, 755)
2. User and directories:
   ```
   sudo useradd --system --home /var/lib/meiolol-api --shell /usr/sbin/nologin meiolol-api
   sudo install -d -o meiolol-api -m 750 /var/lib/meiolol-api
   # Exchange with the box (rrsync user meiolol writes, the service reads and writes)
   sudo install -d -o meiolol -g meiolol-api -m 2770 /var/lib/meiolol-api/exchange
   sudo install -d -o meiolol -g meiolol-api -m 2770 /var/lib/meiolol-api/exchange/curves
   ```
3. Key, without printing it: from the Mac
   `grep '^RIOT_API_KEY=' .env | ssh jomove 'sudo install -m 600 /dev/stdin /etc/meiolol-api.env'`
4. /etc/systemd/system/meiolol-api.service:
   ```
   [Unit]
   Description=meiolol Your games API
   After=network-online.target
   Wants=network-online.target

   [Service]
   User=meiolol-api
   EnvironmentFile=/etc/meiolol-api.env
   ExecStart=/usr/local/bin/meiolol api --data /var/lib/meiolol-api --exchange /var/lib/meiolol-api/exchange
   UMask=0007
   Restart=on-failure
   RestartSec=10
   # 3: Riot rejected the key; restarting would not help
   RestartPreventExitStatus=3
   MemoryMax=400M
   NoNewPrivileges=yes
   ProtectSystem=strict
   ProtectHome=yes
   PrivateTmp=yes
   ReadWritePaths=/var/lib/meiolol-api

   [Install]
   WantedBy=multi-user.target
   ```
   Curves are read at start, so restart on a new file:
   /etc/systemd/system/meiolol-api-reload.path
   ```
   [Path]
   PathChanged=/var/lib/meiolol-api/exchange/curves

   [Install]
   WantedBy=multi-user.target
   ```
   /etc/systemd/system/meiolol-api-reload.service
   ```
   [Service]
   Type=oneshot
   ExecStart=/bin/systemctl restart meiolol-api.service
   ```
   then `sudo systemctl daemon-reload && sudo systemctl enable --now meiolol-api
   meiolol-api-reload.path`
5. nginx, in /etc/nginx/conf.d/meiolol.conf only (jomove's config untouched). At the
   top of the file (http context):
   ```
   limit_req_zone $binary_remote_addr zone=meiolol_api:1m rate=60r/m;
   ```
   inside the `listen 443` server block:
   ```
   location /api/ {
       limit_req zone=meiolol_api burst=30 nodelay;
       access_log off;
       proxy_pass http://127.0.0.1:8090;
       proxy_set_header Host $host;
       proxy_read_timeout 30s;
       client_max_body_size 1k;
   }
   ```
   `sudo nginx -t && sudo systemctl reload nginx`
6. Preview: a personal key may not serve the public (docs/production-key.md). Until the
   production key, either put `auth_basic` on /api/ (htpasswd for Jacob and testers) or
   leave the page unlinked; the site's index already says "coming". Decide before step 5
7. Exchange with the box: a second key on the box with
   `command="rrsync /var/lib/meiolol-api/exchange",restrict` in
   ~meiolol/.ssh/authorized_keys (the existing key stays limited to /var/www/meiolol)
   and an ssh alias `meiolol-exchange`. In deploy/web-loop.sh after `meiolol curves`
   succeeds: `rsync -a --delete $(ls -t data/export/curves-*.bin | head -2)
   meiolol-exchange:curves/` (not public: tens of MB at full crawl). In the box's daily
   backup loop (data-safety-af): `rsync meiolol-exchange:forgotten.txt data/` then
   `meiolol forget --list data/forgotten.txt` before the backup, and push the box's own
   list: `rsync <box list> meiolol-exchange:box-forgotten.txt`
8. Restart the crawler with `--reserve 20` (meiolol-de) so lookups do not queue behind it
9. Check: `curl -s https://meiolol.jomify.lol/api/health`, then the page with your own
   Riot ID, then the objection flow on a test account
10. In the branch that goes live: the index card's "coming" becomes a link to
    your.html (writeIndex in src/site/root.zig; meiolol-b5 agreed)

## Testing locally

`zig build && RIOT_API_KEY=... zig-out/bin/meiolol api --data /tmp/x --cors '*'` and
`zig-out/bin/meiolol serve --out <site dir>`; your.js talks to 127.0.0.1:8090 when the
page is on localhost. Live run 2026-10-11 (one Challenger EUW account, ~40 calls): 10
games cached in ~2.5 min (queued behind the crawler), objection issue, mismatch, success
(icon forced in the scratch DB), opted_out after.
