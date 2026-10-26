# Hosting the backend (the box)

Off Jacob's PC so it and the laptop can be off: everything runs on Oracle Cloud Always
Free, home region uk-london-1 (tenancy `jacobmaschler`; free
accounts may use Always Free only in the home region).

## Hosts

| alias | what | shape | disk |
|---|---|---|---|
| meiolol-cloud | the box: crawler, site build + upload, backups, health | A1 `meiolol`, VM.Standard.A1.Flex 2 OCPU / 12 GB (aarch64), AD-1, 140.238.101.20 | 150 GB boot |
| jomify | nginx: site, Your games service (also jomove, not meiolol's) | E2.1.Micro, 193.123.180.81 | 47 GB boot |

- Free tier: A1 up to 2 OCPU / 12 GB in total (1500 OCPU-h + 9000 GB-h a month), so the
  box takes all of it. Boot volume grown online (rescan, growpart, resize2fs); balanced
  volumes scale throughput with size (50 GB was ~24 MB/s)
- Mount / `nodiscard` on any new host, with fstrim.timer weekly: the Ubuntu image's
  online `discard` queues a ~75 s trim per delete, and a backlog of them starves the
  crawler's commits
- Account on Pay As You Go (Jacob's card; limits of 250 A1 OCPUs). Guards: quota policy
  `free-tier-guard` (other compute shapes zero, A1 2/12, E2 micro 2, block storage per
  AD summing to 200 GB: AD-1 153, AD-2 47, AD-3 0, 5 backups, 20 GB object storage) and
  budget `free-tier-guard` (1 a month, email at 1% actual and 100% forecast). Why:
  research/questions/oci-payg-upgrade.md
- Block storage: 200 GB free in total. In use: A1 boot 150, jomify boot 47. Backup
  "jomify-boot-2026-04 (kept before delete)", 1 of 5 free, holds an old terminated
  instance's boot volume (restore it as a volume to look inside)
- jomify: the web server, first set up for Jacob's jomify.lol domain (OCI name
  instance-20260714-1317). It serves meio.lol (meiolol.jomify.lol) and also runs jomove
  (jomove.jomify.lol, jomove.service, ~/jomove, conf.d/jomove.conf): Jacob's house-moving
  app for Southampton, nothing to do with meiolol. Leave jomove's files alone
- Ssh: `meiolol-cloud` and `jomify` in ~/.ssh/config (user ubuntu, key
  oci_instance-20260714-1317).
  On the box, ~/.ssh/config has meiolol-web and meiolol-exchange (rrsync users on jomify)
- OCI CLI on the Mac: ~/.oci/config, API key ~/.oci/oci_api_key.pem (Jacob's user). The
  console login is in jodrive (`jodrive oracle login`, .env.oracle incl. the TOTP key)

## On the box

- ~/ml/meiolol: bin/ (deployed by deploy/box.sh, built for the host's CPU), data/,
  backups/, .env (copied from the Mac), contact, riot.txt, crawl.args, host.env
  (MEIOLOL_BACKUPS, MEIOLOL_NO_EVAL)
- systemd --user services, lingering: meiolol-crawl, meiolol-web, meiolol-backup,
  meiolol-health (deploy/systemd). `systemctl --user status meiolol-crawl`; logs in data/
- Disk scheduler: mq-deadline, on trial, set at runtime only (a reboot reverts to the
  image's `none`; so does `echo none | sudo tee /sys/block/sda/queue/scheduler`).
  Under the image's `none`, ionice does nothing. Why and numbers:
  research/questions/box-io-priority.md. Under mq-deadline an idle-class read waits up to
  10 s behind the crawler's, so nothing holding a database write lock runs idle class
  (an idle prune can hold raw.db's lock for many minutes); those use `ionice -c 2 -n 7`
- crawl.args: `--proxy 10.0.0.3:8092 --timelines 50 --timelines-priority 100
  --timeline-min-s 900 --raw-timeline-days 3650
  --raw-match-days 0 --raw-valve-free-gb 10 --keep-days 0 --ladder-per-hour 500
  --ladder-refresh-hours 12 --player-sample 16 --min-tier PLATINUM --cache-mb 512
  --patch-only --flex-calls-per-day 0` (flex sample off: nothing reads queue 440; keep
  everything;
  raw leaves the box only through the archive: an export drops the raw timelines it
  holds, `raw-export --ack` prunes acked raw older than 2 days; under 10 GB free the
  valve drops unarchived raw, docs/data-safety.md "Raw archive"; Platinum IV and up
  only)

## Rendering on request

The static upload is only what nginx must serve itself (`meiolol site --static core`,
deploy/web-loop.sh; the list is core_static in src/site/root.zig): the home page,
robots.txt, riot.txt, the root sitemap, CSS, JS, wasm, font and icon, ~30 files with
their .gz twins, all at the site root. The core build loads only two views' stats
(17-550 s on the box, mostly disk wait), so the web loop builds only in a round that
uploads; the others read the patch and game count with `meiolol site --patch-games`
(1-8 s). meiolol-render on the box serves every other page and file (champion, role,
matchup, build, Daily Draft, Learn, legal and method pages, the patch/ and all/ views,
data/ files, the views' sitemaps, data/your-example.json).
The home page stays static because the root directory always exists, and nginx's
try_files answers an existing directory's URL with its index.html or 403, never
@render; for the same reason nothing is uploaded into a subdirectory. The renderer
gzips what it sends when the client accepts it (nginx compresses only HTML itself;
stats.bin is ~12 MB raw), with Vary: Accept-Encoding, and answers a directory URL
without its slash with a 301.
- `meiolol render` (systemd meiolol-render@a or @b) on the box's private address
  10.0.0.3:8091, every view loaded up front from data/views.bin. Loading views from the
  database beside the crawler takes 10-105 min and ~2.5 GB, so that work happens once
  per data refresh, in the web loop (research/questions/fast-deploy-data-servers.md):
  after each upload `meiolol site --views data/views.bin` (same flags as the core build)
  loads every view and writes them to one file, then touches data/render.reload; the
  renderer reads the file in seconds and swaps it in. A views file written by a binary
  with other part keys (types or data code: docs/architecture.md "Views file") or a
  missing one makes the renderer load from the database instead. Render code changes
  show at the swap, in seconds
- A deploy that changes a part waits for the forced round's `--reuse` write, which keeps
  the parts still current and loads only the changed ones; a write running at the deploy
  finishes first and the deploy's write reuses its unchanged parts (stopping it costs
  far more). Kept parts refresh at the next upload's full write
- A full write reads only new, REPLACEd or newly timelined games from data/partials
  (docs/architecture.md "Views partials"); above ~150k games to read it reads whole
  tables instead. Typical: ~320-470 s, ~1,040 s for a first build over all games. Learn
  reads its tallies and practice ids from the partials too (~10 s); raw JSON and
  practice games stay on the db. The heavy loads read in parallel: filters in 4 runs of
  games, learning in 4 puuid ranges, each on its own read-only connection
  (schema.openSibling), and filters beside the people tallies; the box waits on cold
  pages, one read in flight each. views.log gives each
  phase's CPU time beside its time. views.bin is ~150 MB, read in ~14 s; the renderer
  holds ~2.0 GB (curves files ~940 MB of it)
- A deploy runs deploy/render-swap.sh: it starts the idle instance beside the running
  one (both listen, SO_REUSEPORT), and stops the old once the new one writes
  data/render-<a|b>.ready, so there is no gap. It first waits (up to 30 min) for the
  deploy's round to upload, since the new pages link the front-end files that upload
  ships (swapping first shows new pages unstyled for the core build's 25-110 s).
  Connections queued on the stopping one move to the new one (sysctl
  net.ipv4.tcp_migrate_req=1, /etc/sysctl.d/60-meiolol-render.conf) and nginx retries a
  dropped one once. Alone (a boot) it listens at once and serves each view as it loads
  (the root view after ~40 s, all ~3 min, longer while the disk is busy); until then
  503, so nginx serves its cached copy where it has one, and pages not in its cache are
  down. Log data/render.log
- Network: jomify (10.0.0.214) and the box share subnet 10.0.0.0/24. Security list rule
  "meiolol-render: jomify nginx to the box" (TCP 8091 from 10.0.0.214/32; the list
  before it: .git/oci-ingress-before-render.json on the Mac) and an iptables ACCEPT on
  the box before its REJECT (saved with netfilter-persistent). The same for the
  crawler's Your games proxy: "meiolol-proxy: Your games service to the crawler", TCP
  8092 from 10.0.0.214/32
- nginx config on jomify is installed by hand and not in the repo: before each change a
  copy is kept as /etc/nginx/meiolol.conf.bak-<date>-<what> (a few older ones in
  /home/ubuntu/meiolol.conf.bak-*); `ls` them to roll back
- jomify nginx (/etc/nginx/conf.d/meiolol.conf): try_files, then `@render` (upstream
  meiolol_render: the box twice, for the retry): proxy cache /var/cache/nginx/meiolol (2
  GB, key `$uri|$meiolol_version`), 200s 10 min, 404s 1 min, stale copies while the box
  is down or refreshing, one render per page under a burst. Header X-Meiolol-Render:
  HIT, MISS, STALE, UPDATING
- Cache version: each renderer load (start or reload) gets a version, its load time in
  ns as 16 hex digits, written to its --ready file. meiolol-cache-version.path on the
  box runs deploy/cache-version.sh when a ready file changes, and render-swap.sh runs it
  once the old renderer has stopped. With exactly one renderer serving, it sends that
  version over ssh alias meiolol-cache (box key ~/.ssh/meiolol_cache, in jomify user
  meiolol's authorized_keys with forced command `sudo -n
  /usr/local/bin/meiolol-cache-version`, one line in
  /etc/sudoers.d/meiolol-cache-version). That script (deploy/cache-version-receive.sh;
  `deploy/jomify.sh install cache-version`) checks the version is 16 hex digits, writes
  /etc/nginx/meiolol-version.conf (a `map` setting $meiolol_version), then runs `nginx
  -t` and reloads. So new data or code shows at once. Copies under older versions are
  never read again and expire (inactive=30d); each reload starts the cache cold, which
  deploy/cache-warm.sh then fills (Outages, below). Last sent version:
  data/cache-version; log lines `cache-version:` in data/render.log
- Outages (the renderer is the main path since `--static core`): a page with a copy
  under the current cache version is served stale on error, timeout or 503; else
  @render_any serves its warm-up copy (key `<uri>|any`, header X-Meiolol-Render: ANY-HIT
  or ANY-STALE); with neither, 503 until the renderer is back. Each version starts the
  versioned cache cold, and in a run of deploys versions change every few minutes,
  faster than a warm-up run, so the warm-up fills the unversioned key:
  deploy/cache-warm.sh (meiolol-cache-warm.service, started by cache-version.sh after
  each version; a run under way finishes, then runs again) requests every page and file
  through nginx over the private address (10.0.0.214:443) with X-Meiolol-Warm: 1, which
  nginx honours only from 10.0.0.3 (geo $meiolol_from_box): always fetched anew
  (proxy_cache_bypass) and stored under `<uri>|any`. One at a time at 20/s: the site's
  7-day top 30 first (the receive script answers with them from traffic.json), then the
  renderer's list (/admin/api/pages.txt, admin token: every page of the loaded views,
  matchups only from 200 games, as thinner ones are ~54k pages a view; thin matchups
  stay render only). Pages render from memory, so no disk for the crawler to wait on.
  Log `cache-warm:` in data/render.log. @render asks the box for gzip (`proxy_set_header
  Accept-Encoding gzip;`, `gunzip on;` for clients without it) and ignores Vary, so one
  copy per page serves everyone; it intercepts the box's 503 (proxy_intercept_errors) to
  reach @render_any. jomify's access log skips user agent meiolol-cache-warm (map
  $meiolol_logged), so traffic.json counts visits only. STALE in jomify's log is the
  background refresh of an expired copy, not an outage. A renderer start reads views.bin
  and serves in 1.3 s (file in page cache) to 16.6 s (evicted, as after a boot); swaps
  take as long; with the renderer stopped a warmed page is ANY-HIT, an unwarmed one 503
- Cache-Control: `map $uri $meiolol_cache_control` gives hashed assets
  (src/site/assets.zig: `style.1a2b3c4d.css`, the font, search.js, ui-stats.js and
  .wasm; `name.<8 hex>.ext` at the root) `public, max-age=31536000, immutable`,
  everything else `no-cache`, in `/`, @render and @render_any (which hide the renderer's
  own no-cache). A page after the first asks for none of them. Old hashed files stay 30
  days (deploy/web-loop.sh); one missing from the upload falls through to the renderer,
  which serves its own
- Training view (/admin/training/, same login as /admin/; data for the admin Models
  tab): lab runs of the Mac and the gpu-box (staged over ssh, home network only),
  learned.md, model.md, campaigns, uploaded by deploy/lab-push.sh (launchd, every 30 s
  when changed). Served from /var/www/meiolol-training/current (symlink; outside
  /var/www/meiolol, whose uploads --delete). Mac key ~/.ssh/meiolol-training, in user
  meiolol's authorized_keys with forced command /usr/local/bin/meiolol-training-receive
  (deploy/training-receive.sh, reinstall `deploy/jomify.sh install training-receive`:
  tar on stdin, swapped in atomically). Not rrsync: macOS's openrsync is refused by it
- Site traffic (/admin/ops/traffic.json, same login): meiolol has its own nginx access
  log, /var/log/nginx/meiolol.access.log, format meiolol_noip (JSON lines: time, status,
  method, uri without query, bytes, request time, render cache, referer, user agent; no
  IP addresses, so none are kept or derived; /api/ stays unlogged). deploy/traffic.sh
  aggregates it every 5 min (meiolol-traffic.timer, system unit, user meiolol-traffic,
  sandboxed: sees only /var/log/nginx, no network) into /var/www/meiolol-ops. State in
  /var/lib/meiolol-traffic: per log file summaries cached by inode with the offset read
  (files2/), hourly totals kept 90 days (hourly.tsv). A person is a browser user agent
  whose page view is matched to a /print.css fetch by the same agent within 60 s (every
  page links it for print, so it never holds up rendering, and revalidates it); browser
  agents with no such fetch are "unconfirmed" (hours column 6), nearly all of them.
  Reinstall: `deploy/jomify.sh install traffic`; units by hand into /etc/systemd/system,
  then `daemon-reload` (`deploy/jomify.sh drift` shows what differs)
- Desktop app files (/admin/desktop/: zip, update.signed, update.json (unsigned, for
  older apps), stats.bin, recent-curves.bin, champ-facts.tsv, the exe, .gz copies;
  deploy/web-loop.sh desktop_files from the box's release/ (deploy/desktop-release.sh),
  manifest signed with ml/meiolol/desktop-data.key, mode 600, copy in vault
  meiolol/desktop): an auth_request to internal /_meiolol_desktop_key, which answers 204
  when X-Meiolol-Desktop equals the key in /etc/nginx/meiolol-desktop-key.conf (root
  only), else asks /auth/check/download_private_app (a login with the private tier or
  above); the key opens this directory only. Key: box ml/meiolol/desktop.token (64 hex,
  made by web-loop.sh if missing), shipped in the zip as update.key and after the zip's
  exe (install.zig bundled). Rotate: new token on the box, the same in the conf, `nginx
  -t`, reload; old zips stop updating. The same files under /p/desktop/ (accounts.md
  AC5; the web loop's p/ upload, same gate) for the private edition's channel
- Admin API (/admin/api/, src/admin_api.zig): `meiolol render` on the box answers
  live.json (crawler's last 3 h by minute, queues, services, health; cached 30 s),
  log?file=&lines= (crawl, web, eval, render, health, backup, builds; ids and Riot IDs
  redacted) and POST action/NAME (crawl-start|stop|restart, site-build, eval-run,
  health-check: fixed commands, one at a time across both instances via
  data/admin-action.lock, each logged to data/admin-actions.log; eval-run shares
  data/eval.lock with web-loop.sh's daily eval and is refused under MEIOLOL_NO_EVAL).
  Layers: a login with view_admin (Logins below); nginx adds X-Meiolol-Admin from
  /etc/nginx/meiolol-admin-token.conf (root only) and clears it on public @render
  requests; the box compares it in constant time with ml/meiolol/admin.token (64 hex,
  read per request, so rotate by rewriting both and reloading nginx); without a match
  the routes do not exist (same 404/405 as any path). Actions also need the request
  header X-Meiolol-Action: 1, which a cross-site form cannot send, and X-Meiolol-Role
  (nginx, from the login check) with run_actions: the owner only. 8091 takes only the
  web server
- Logins (docs/plan/accounts.md; src/api/accounts.zig, roles.zig): `meiolol api` answers
  /auth/ (nginx location /auth/, unlogged, 4 KB bodies) from
  /var/lib/meiolol-api/accounts.db; desktop apps sign in with POST /auth/device and send
  their token as Authorization: Bearer, good for /auth/check/download_private_app only
  (accounts.md AC4). nginx auth_request /_meiolol_admin (/auth/check/view_admin) guards
  /admin/, /admin/api/, /admin/ops/ and /admin/training/; no login sends a page to
  /login.html?next=, a lower role gets 403 (meiolol-api.htpasswd is unused).
  /account.html: own password, log out everywhere. The admin page's Accounts tab
  (manage_accounts) lists logins, makes invite and reset links, changes roles and
  disables, below the signed-in role only. Accounts by hand: `sudo -u meiolol-api
  meiolol account ... --data /var/lib/meiolol-api` on jomify (list, reset, link,
  revoke-links, delete; the owner only here).
- Private site (/p/, docs/plan/accounts.md AC3): static, uploaded by the web loop to
  /var/www/meiolol/p (`meiolol admin --private-out`: the Draft tester in private mode, the
  shipped models in models/). nginx location /p/ with auth_request /_meiolol_private
  (/auth/check/view_private), 401 to the login page, X-Robots-Tag noindex. The loop
  uploads p/ only while meio.lol/p/ answers 302 (the gate), so nothing private is public
  without it; the site's rsync leaves p/ alone

### Deploy events

The admin page's Deploys tab shows every push from the check on the Mac until the site
serves it. Its backbone is data/deploys.tsv on the box: one line per step, `time` (unix
s), `sha` (full commit), `step`, `status` (start, ok, failed, skipped, waiting, info),
`detail` (free text; redacted when served). live.json carries the last 3,000 lines as
`deploys`, the 15 min snapshot as `deploy_events`.

| step | written by | when |
| --- | --- | --- |
| ci | deploy/hooks/pre-push | `zig build ci` start and result, per pushed commit |
| commit | deploy/on-push.sh | each commit since the deploy before (at most 30) |
| deploy | on-push.sh | start, skipped (docs only, or box.sh found the binary, scripts and units already on the box: no copy, no round), ok or failed with box.sh's last line; a re-run of a commit is a new attempt, and the admin page shows the latest |
| build | on-push.sh | start; ok at box.sh's "deployed SHA" (binary and scripts copied, or unchanged) |
| web | on-push.sh | meiolol-web signalled or restarted |
| round, site, upload, views, reload | deploy/web-loop.sh | forced rounds only (a deploy's or a start's): views ok names the parts loaded again and kept (views.log's "... kept" marks) |
| swap | deploy/render-swap.sh | waiting (views file in another format), start, ok, failed |
| cache | deploy/cache-version.sh | each new nginx cache key (every swap and reload) |

- Mac steps carry the pushed commit; the box's carry the newest DEPLOYED line when the
  step (or forced round, or swap iteration) began. A deploy is live at the first cache
  line after its swap, the page's "expected live" is the median of the last 12 live
  deploys' start to live (those whose swap waited for a views file, or not, when two
  or more match)
- The Mac queues its lines in .git/meiolol-deploy-events.tsv (deploy/deploy-events.sh
  add|flush) and appends them to the box on each flush that reaches it: on-push.sh
  flushes at its start, at "deployed" and at its end; a refused push flushes in the
  background. A deploy that failed before the box shows after the next flush
- Lines before 17 Oct 2026 14:55 BST were rebuilt from logs: no ci lines, no views
  parts
