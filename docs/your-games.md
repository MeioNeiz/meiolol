# Your games: the service

The dynamic part of the site (docs/concept.md, product 1): enter a Riot ID, see each
recent Summoner's Rift game's lane laid over the typical curve for that matchup at your
rank, then a weekly roll-up and per-matchup trend. `meiolol api` (src/api) serves JSON
at /api/ behind nginx on the jomify server; site/your.html + your.js (src/site/your.zig,
static/your.js) is the page. Live, /api/ open without login: Deploy below.

## How it works

- Lookups never call Riot in the request. GET /api/games?id=Name%23TAG answers from
  api.db at once and queues a job; one fetcher task (src/api/fetch.zig) is the only Riot
  caller, through the crawler's proxy (Rate limits), and works the queue oldest first;
  the page polls every 3 s and shows progress
- Per new Riot ID: account-v1 by Riot ID and active region (europe route), league-v4
  by PUUID (visible rank), match-v5 ids (last 60 days, one list per queue: solo 420,
  flex 440, draft 400, Swiftplay 480; up to 3 pages of 100 each), then match + timeline
  for up to 10 games not yet cached, newest first across the lists. ~26 regional calls
  plus 1 platform call for a first lookup; a refresh costs 5 plus 2 per new game.
- The rest of the 60 days goes in api.db `backlog`: a `history:<puuid>` job fetches 25
  of them a step (match only, one call each, for Friends), then queues itself again
  behind any lookup that arrived meanwhile, so a heavy player's history never holds up
  another's lookup. It does not count toward the 30-job cap. A refresh's spare timeline
  slots (10 less its new games) fill cached games still without one, newest first;
  `matches.timeline` is NULL until fetched, empty when Riot has none or a remake
  Not the unfiltered list: it holds private ARAM Mayhem ids (403) that would take the 10
  new-game slots on every refresh. ARAM and Arena have no lanes to show
- When to refresh (src/api/root.zig): a visit refreshes when the last refresh is over 5
  min old. "Check for new games" (&refresh=1) does when it is over 1 min old (the reply's
  check_at says when). Riot lists a game a few minutes after it ends, so a check that
  finds nothing new repeats every minute for 10 min while the tab is open, then stops:
  at most ~50 calls per press, only on a press
- Cache by match id (api.db `matches`): a summary of the match (champions, positions,
  results, K/D/A; no names) and the compact timeline (riot/timeline.zig, ~8 KB gz). A
  match shared by two looked-up players is fetched once
- Analysis on read (src/api/game.zig), reusing src/curves.zig `lane()` so a player's
  numbers are computed exactly as the curves are: per minute gold/XP/CS difference to
  the lane opponent (same teamPosition, other team), deaths and kills before 14 min,
  CS at 10, level 6 and first legendary item times (yours and theirs)
- Binary answers (/api/list, /api/game) name champions, items, spells and runes from
  Data Dragon, fetched at start for the newest curves patch with the legendary items
  (src/api/pagedata.zig converts, as the site build does for the example); Data Dragon
  down at start: blank names and icons until the next restart
- Typical curve: `Curves.get(role, bracket, me, them)` from the curves file covering
  the game's patch (else the newest), bracket from the player's visible solo tier at the
  last refresh; all ranks when that bracket is too thin (the page says so). Curves are
  from solo games only, for flex, draft and Swiftplay games too (their captions say
  "solo/duo games"). Every chart caption names bracket, patch and n; under 200 games it
  is grey ("more data needed"), minutes with n < 10 are not drawn
- Facts, never verdicts: gold difference at 14 against the typical middle half;
  biggest 3-minute fall and rise against the typical median (against an even lane when
  there is no curve) with deaths and kills in those minutes, shown only when 200+ gold;
  weekly games, wins, mean gold difference at 14 and mean against typical; per matchup
  the gold difference at 10 oldest to newest and the older vs newer half's mean
- Whole game (any role, lane opponent or not): the team's win chance per minute
  (src/statemodel.zig, docs/model.md "Rich state and champions (richc)": every player's
  gold, XP, level, CS, items, death timer and deaths by role, objectives, buffs and
  vision, the draft logit and each champion's value by minute, fitted on ranked solo
  games by py/state/stateship.py into src/state_model.bin; games without each side's
  five roles fall back to src/winchance.zig, team gold and objectives only, 50 at 0:00).
  With the model, 0:00 is the champions alone (start from the draft), so every later
  move is the game; the turning minute (biggest one-minute change, with that minute's
  kills, deaths and objectives) and death cost per death (bounty and shutdown gold to
  the enemy, objectives the enemy took in the next minute, win chance before and after).
  Plate events after 14:00 are ignored (Riot sends them, worth nothing then)
- Tier is the visible rank (league-v4), never inferred MMR. It is the rank now, not at
  game time; the curves bracket games by the median visible rank of their players
- Not yet: the experienced-players curve (needs champion-mastery per player, more
  calls), recalls (not in match-v5 timelines), curves for flex or normal games (the
  crawler is solo only), ARAM and Arena

## Example

your.html offers "See an example" (and `your.html#example`, `#example=jungle`) when
data/your-example.json exists, so a visitor or Riot reviewer sees the page without a Riot
ID (/api/ sits behind basic auth in preview). `meiolol your-example` (src/api/example.zig,
read-only, under a minute on the box) keeps one EUW player per role (top, jungle, mid,
bot, support): of the 10 with the most games of that role with timelines in the last 7
days, Gold to Emerald first, never a `forgotten` one nor another role's pick, the first
whose games include one with a turning minute and a lane curve. It writes their 10 newest
ranked solo games of that role through the same report() as the API, as
`{default, top, jungle, mid, bot, support}` (default mid; a role missing when nobody
qualifies). The page and the home page's featured review switch role; a bare #example
opens the default, and an older one-player file still shows, without the switch. No name,
PUUID or match id; game starts cut to the day (UTC). The web loop runs it daily and
copies the file into each site build; a failed run deletes it, so no stale example ships
(the page then offers none).

## API

| Call | Answer |
| --- | --- |
| GET /api/games?id=Name%23TAG | state (queued, fetching, ready, not_found, opted_out), progress (ahead, pending, total), player, report; `api: 2` where /api/list and /api/game exist (pages built for both APIs check it) |
| GET /api/list?id=Name%23TAG | the same lookup as ui.yourlist.Lookup in ui.data's binary (games.html's wasm reads no JSON): state, progress, check_at, the report's games as ui.yourlist.List; always 200 (busy a state) but 400. &n=1..100: the newest n games. &cached=1: a glance, not a visit (Home's player bar): the cache only, nothing queued, looked_up kept; state none, opted_out or ready |
| GET /api/game?id=Name%23TAG&start=MS | one game of the report (its start_ms) with its detail as ui.gamedata.Data in ui.data's binary, for game.html#id=Name%23TAG&game=MS; 404 JSON (state none or opted_out) when not cached or no timeline. Cache only, no Riot call, no refresh |
| POST /api/forget?id=... | starts an objection: state pending, then issued with an icon |
| POST /api/forget?id=...&check=1 | checks the icon: checking, then done or mismatch |
| GET /api/friends?id=Name%23TAG | state (none, opted_out, ready), friends (src/api/friends.zig): games, waiting (backlog), with_friends and alone, and per friend (3+ games on the same team, top 20): riot_id, together, against, last_ms, you and them (with, apart, apart_rate, diff, lo, hi), their_games, top 3 champion and role pairs. Fetches nothing |
| GET /api/forget?id=... | the objection's state (none, pending, issued, checking, mismatch, done, not_found, failed, expired) |
| GET /api/health | {ok, jobs} |
| POST /api/daily?n=N&pick=0-5&side=0-1 | Daily Draft: one finished puzzle's answers counted (option index in the puzzle's order, side 0 blue); replies as GET |
| GET /api/daily?n=N | {n, players, picks[6], sides[2]}: counts only, daily_answers in api.db |

Queue capped at 30 jobs (503 "busy" beyond); objection checks jump the queue.

## Friends

Under Highlights on Your games: everyone on the player's team in 3 or more of their
cached games (two random teammates in 60 days happen; three rarely do), most games
together first.

- You with them: the player's win rate in games with the friend against their rate
  apart in the same queues, each queue's rate apart weighted by the games together in it
  (friends play flex and normals together and solo/duo alone, so a plain "without"
  compares queues). Queues with no games apart drop out; none left shows "no games
  apart". Range: 95%, normal approximation on rates with one win and one loss added;
  coloured only when it leaves out 0
- Them with you: the same from the friend's own cached games, found by their Riot ID in
  `accounts` when its PUUID still hashes to the friend's seat (names change hands).
  Until then "Fetch their games" looks them up exactly as typing their Riot ID would
  (a press only: it costs Riot calls); the friend's name links to their page
- Against them, the champion pair and role pair played most together, with the record
- The page polls /api/friends every 15 s while the backlog or an asked friend's games
  are still coming
- Facts, not causes: the page says games with friends differ in other ways too

Next (docs/backlog.md "Your games and Squads"): opt-in Squads pages built on this.

## Rate limits

The service and the crawler share one key, so one set of per-route app limits (100 per
2 min on a personal key). The service makes no Riot call itself: it asks the crawler's
proxy (src/riot/proxy.zig, `meiolol crawl --proxy 10.0.0.3:8092`, the box's private
address; service `--riot-proxy http://10.0.0.3:8092`), which makes the call through the
crawler's own limiter for that route at priority. The crawler paces its calls evenly
(one per 1.2 s per route on a personal key), so a priority call waits at most about one
pace for the next free slot, unpaced, and the crawler holds back while one waits. So a
first lookup (~26 calls) takes ~30 s, and the crawler has the whole key the rest of
the time (a fixed reserve would idle 20% of the key and still leave a lookup 20 calls
per 2 min).

The proxy answers as Riot would (200, 404), 401 when Riot rejects the box's key, 503
when the crawler's tries ran out, 400 for an unknown route. The service retries an
unreachable proxy (a crawler restart, every push) for ~2 min, then the job fails; it
never stops on a rejected key, since the key is the box's to renew. Only jomify may
connect: security list rule and iptables on the box (Deploy). Without `--riot-proxy`
the service calls Riot itself with RIOT_API_KEY (local testing).

## Privacy: what is stored and shown, and why

From research/questions/identity-and-privacy.md:

- Any Riot ID may be looked up, on legitimate interests: League policy has no consent
  rule for ranked history (C1), and that is how lookup sites work (C8). The review is
  the looked-up player's own lane and game; a Players panel lists all ten with champion,
  K/D/A and Riot ID as at that game, each linking to their own lookup (J18; balancing
  in docs/legal/lia.md). Streamer mode: match-v5 neither blanks nor marks
  players who had it on, and Riot says it hides names only during the match
  (research/questions/streamer-mode-names.md), so finished games show everyone, as on
  lookup sites. The example (below) has no names
- Stored per looked-up player: PUUID, Riot ID as Riot spells it, platform, visible rank,
  times of last refresh and lookup, and which slot they had in each game. Per match: the
  summary above without names or Riot IDs; the ten PUUIDs only as truncated SHA-256
  hashes (so a later lookup can find its slot in a cached match without refetching; a
  hash is pseudonymous, not anonymous: anyone with the PUUID can recompute it); the
  compact timeline (per-minute stats per slot, no identities); and `match_names`, each
  slot's Riot ID as at the game with its PUUID hash, none for a blocked PUUID. A cached
  game without names gets them on the player's next refresh (one match-v5 call each, up
  to 10 per refresh)
- Retention: a player nobody has looked up for 30 days is deleted (hourly prune), with
  matches no remaining player uses: Riot's advice to refresh stored players at least
  every 30 days (C7) and the privacy policy's promise. Each visit refreshes from Riot (at
  most every 5 min) and restarts the 30 days, so a player who comes back keeps their
  history for the per-matchup trend
- Objection and removal, open to anyone who owns the Riot ID: the page issues a random
  starter profile icon (ids 0-28, never the current one), the player sets it in the
  client within 15 min and presses check; the service re-reads it via summoner-v4 and on
  a match deletes everything about the player (their Riot ID in other players' cached
  games too) and blocks the PUUID (blocked table: PUUID and time, the minimum to honour
  the objection). Later lookups of that Riot ID answer
  "opted_out" without fetching. A random guess passes 1 time in 28. Squads will use the
  same check for consent. RSO replaces it once the production key allows (C6, C13)
- Riot's erasure lists and emailed requests: `api.cache.forget(db, puuid, now)` deletes
  and blocks; data-safety-af's `meiolol forget` calls it for api.db
- The box holds the same players (crawler DBs, backups). Forgotten PUUIDs sync both ways
  through the exchange directory: the service writes forgotten.txt (every blocked PUUID,
  one per line, no Riot IDs) hourly and on each honoured objection, and imports
  box-forgotten.txt then; the box swaps lists once a day at ~04:00 UTC
  (deploy/backup-loop.sh): it pulls forgotten.txt, runs `meiolol forget --list` and pushes
  its own list as box-forgotten.txt. So an objection reaches the box's data within a day.
  Both files are complete lists, so either side can rerun
- Logs: no Riot IDs. The service never logs them, and the Riot client shows account
  lookups by endpoint name instead of path. nginx does not log /api/ (`access_log off`
  below), since the query string holds the Riot ID
- Privacy page: "Your games" section on the site (src/site/prose.zig) and in
  docs/legal/privacy.md, matching the above
- Preview gating: /api/ is open without a login although a personal key may not serve
  the public: Jacob's call, knowing that policy, so Riot's reviewers can run it
  (research: they rarely use demo credentials). your.js still shows the preview note on
  a 401. /admin/ needs a login (docs/hosting.md "Logins")

## Deploy (jomify server)

Jacob left the deploy and the preview gating to us. Server: jomify (x86_64, 1 GB RAM,
~540 MB free; the service uses ~11 MB plus the curves array, 24 bytes a curve). The
newest two curves files are mapped read-only (curvesfile.Curves.map): pages load as
lookups touch them and count as reclaimable page cache under MemoryMax 400M, so both
patches load whatever their size. Never copy them to the heap: one patch's file passes
200 MB, and raw plus parsed copies OOM-kill the service at start.

- Binary: /usr/local/bin/meiolol (root 755), built on the Mac from a clean commit with
  `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSafe`. Not part of the box's
  push deploy: after a change to src/api or the curves file format (curvesfile.zig
  version), rebuild, `scp` to /tmp, `sudo install`, then `sudo systemctl restart
  meiolol-api` (or `deploy/jomify.sh install api`, which records what is installed for
  `deploy/jomify.sh drift`). Previous binaries are kept as
  /usr/local/bin/meiolol.bak-pre-<sha>. Mapped, it starts in ~0.3 s at ~10 MB RSS,
  ~23 MB after a lookup, plus Data Dragon's fetch at start; a first lookup through the proxy fetches 9 new games in ~5 s
- User `meiolol-api` (system, no shell). /var/lib/meiolol-api (750): api.db. Exchange
  /var/lib/meiolol-api/exchange (meiolol:meiolol-api, 2770; `meiolol` is in the group):
  curves/ from the box, forgotten.txt out, box-forgotten.txt in
- No key on jomify: Riot calls go through the crawler's proxy (Rate limits)
- systemd: meiolol-api.service (`meiolol api --data /var/lib/meiolol-api --exchange
  /var/lib/meiolol-api/exchange --riot-proxy http://10.0.0.3:8092`, UMask 0007,
  Restart=on-failure, not on exit 3,
  MemoryMax 400M, ProtectSystem=strict); meiolol-api-reload.path watches exchange/curves
  and restarts the service through meiolol-api-reload.service. Logs: `sudo journalctl
  -u meiolol-api`
- nginx: /etc/nginx/conf.d/meiolol.conf only (jomove.conf, the house-moving app's,
  untouched; rollback copies: docs/hosting.md). `limit_req_zone meiolol_api 60r/m` at
  the top; `location /api/` in the 443 server: no login, limit_req burst 30, access_log
  off, proxy_pass 127.0.0.1:8090, client_max_body_size 1k. `/admin/` (the ops page,
  src/admin.zig) behind the login check (docs/hosting.md "Logins").
  `location /admin/training/`: gzip on, gzip_vary, gzip_types application/json
  text/plain (draft-model.json 12.1 MB to 5.6 MB on the wire)
- Box: ssh alias `meiolol-exchange` (key ~/.ssh/meiolol_exchange) is the rrsync user
  limited to the exchange dir (`command="/usr/bin/rrsync /var/lib/meiolol-api/exchange",
  restrict` in ~meiolol/.ssh/authorized_keys; the site key stays limited to
  /var/www/meiolol). deploy/web-loop.sh pushes the newest two curves files after each
  `meiolol curves` (push_curves); deploy/backup-loop.sh swaps the forgotten lists daily
  (data-safety-af)
- Crawler: `deploy/box.sh start` defaults to `--proxy 10.0.0.3:8092`; the box's
  crawl.args has it too. Security list rule "meiolol-proxy: Your games service to the
  crawler" (TCP 8092 from 10.0.0.214/32) and an iptables ACCEPT on the box before its
  REJECT (netfilter-persistent), as for render (docs/hosting.md)
- Check: `curl -s https://meio.lol/api/health` answers {"ok":true,"jobs":N}

## Testing locally

`zig build && RIOT_API_KEY=... zig-out/bin/meiolol api --data /tmp/x --cors '*'` and
`zig-out/bin/meiolol serve --out <site dir>`; your.js talks to 127.0.0.1:8090 when the
page is on localhost. A first lookup (~40 calls) caches 10 games in ~2.5 min when
queued behind a crawler on the same key. The objection flow can be tested end to end by
forcing the icon in the scratch DB.
