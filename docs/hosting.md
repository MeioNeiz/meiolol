# Hosting the backend (the box)

Off Jacob's PC so it and the laptop can be off. The box is C01, a VM Ethan (Burnt Water)
lent: crawler, site build, renderer, backups, health, nginx, the Your games API and
traffic, reached through Cloudflare Tunnel `meiolol-c01`. The move from Oracle Cloud:
docs/plan/vm.md.

## Hosts

| alias | what | shape | disk |
|---|---|---|---|
| essex-vm | the box (C01) | KVM, 16 vCPU (host CPU: Xeon E5-2630 v3, AVX2), 62 GB, Ubuntu 24.04 x86_64 | 60 GB system disk; /srv/meiolol 492 GB on Megatron, 30 GB local cache |
| meiolol-cloud | the old Oracle box, stopped: units masked, data as of the move; kept as is for a benchmark (Jacob decides standby or termination) | A1 2 OCPU / 12 GB (aarch64), uk-london-1, 140.238.101.20 | 150 GB boot |
| jomify | jomove's server (Oracle E2.1.Micro, 193.123.180.81); its old meiolol web units still run, unused. Never touch it | | |

## C01

- ssh alias `essex-vm` (user jacob, key ~/.ssh/essex_vm), Tailscale 100.95.95.44 on
  Jacob's tailnet (MeioNeiz@github), direct from the Mac; LAN 192.168.18.71. Sudo
  password in vault meiolol/essex-vm (SUDO_PASSWORD): `head -1 | sudo -S -p "" -v`
  once per ssh command, then plain sudo (sudo -S per call eats the stdin of what it runs)
- Builds for x86_64_v3 (box.sh's host_target). Lingering, unattended upgrades, UTC,
  journald 1 GB, ufw (everything on tailscale0; ssh from 192.168.18.0/24 for Ethan)
- Ethan has admin on C01 and the shares; his VM host and Megatron reboot when they like
- Network shares, CIFS: Ethan's /mnt/storage (Essex Storage, 192.168.18.12, 14.5 TB
  free) and /mnt/jacob (Megatron, `soft`); ours on Megatron (192.168.18.54, 3.1 TB
  free): /srv/megatron (`hard,nosharesock`:
  without nosharesock the kernel reuses Ethan's soft session and its options) and
  /srv/megatron-backups (the same plus nobrl, for the backup mirror's SQLite),
  credentials /etc/meiolol/megatron.cred
- Web side, set up by deploy/vm-web.sh (repeatable): nginx (deploy/nginx/meiolol.conf)
  on 127.0.0.1:8080, cloudflared as a system service (tunnel meiolol-c01, token vault
  meiolol/essex-vm TUNNEL_TOKEN), meiolol-api, the traffic timer. User meiolol keeps
  jomify's rrsync and forced-command keys; the box's aliases meiolol-web,
  meiolol-exchange and meiolol-cache reach it at 127.0.0.1, so no script changed in the
  move. Pieces outside the push deploy: `deploy/jomify.sh drift|install`
- Oracle account (stopped box, jomify): Pay As You Go on Jacob's card behind quota
  policy and budget `free-tier-guard` (Always Free shapes only, 200 GB block storage, 1
  a month, email at 1%); research/questions/oci-payg-upgrade.md. OCI CLI on the Mac
  (~/.oci/config), console login `jodrive oracle login`. Ssh `meiolol-cloud`, `jomify`
  (user ubuntu, key oci_instance-20260714-1317)

### Data disk

/srv/meiolol (ext4, `noatime,nodiscard`) is LVM volume meiolol/data: a 500 GB image on
Megatron (/srv/megatron/meiolol/disk.img) with a 30 GB writethrough cache file on C01's
disk (/var/lib/meiolol/cache.img), loops with direct IO; ~/ml links to /srv/meiolol/ml.
SQLite in WAL can't live on a share itself (every process maps its -shm). Writeback
cache was refused by LVM (a damaged cachevol can't be repaired). With the cache: commits
11-12/s (p50 ~62 ms), lookups beside the writer 243-260/s, cold scan 147-171 MB/s, cold
row reads 1,450-1,640/s: scans near local disk, row reads ~2x the bare image, writes at
Megatron's pace. Without the cache, measured 26 Oct (Python, O_DIRECT, 2 GB file; SQLite test 2.8 GB WAL db, writer of
20-game commits with 2 readers, then cold scans):

| | 4 KB random read | seq read | commits/s, p50 | lookups/s beside writer | cold scan |
|---|---|---|---|---|---|
| local disk | 0.2 ms | 766 MB/s | 359, 1.3 ms | 5,528 | 176 MB/s |
| Megatron share | 1.0 ms | 347 MB/s | | | |
| ext4 image on Megatron | 1.15 ms | 270 MB/s | 13-15, 43-54 ms | 170-221 | 61-71 MB/s |
| Essex Storage share | 6.6 ms | 52 MB/s | | | |
| the Oracle box (research) | ~0.7 ms | cap 72 MB/s | | | |

- deploy/c01 holds it all; `deploy/c01/install.sh` (from the Mac) installs
  /usr/local/sbin/meiolol-disk, meiolol-disk.service and the fstab lines, makes the
  empty mount points immutable on / (nothing can write there while one is down), and
  sets host.env's MEIOLOL_MOUNTS for health.sh. It never restarts the disk unit (its
  stop unmounts the data)
- Boot: the shares mount from fstab (nofail); meiolol-disk.service mounts any that
  failed, then loops, LVM and /srv/meiolol, and on failure runs again every 30 s until
  Megatron answers (journal: "Megatron (192.168.18.54) not answering"). Each user unit
  on ~/ml/meiolol fails its pre-start check ("waiting for the data disk") and restarts
  until data/ is there; the Megatron mirror timer skips. Megatron pausing while up:
  `hard` stalls IO until it is back
- Alerts: health.sh lines for a share or the disk not mounted; with the disk down
  health.sh itself is missing, which mac-watch.sh reports (docs/data-safety.md "Health
  alerts")
- Left: fstrim.timer

## On the box

- ~/ml/meiolol: bin/ (deployed by deploy/box.sh, built for the host's CPU), data/,
  backups/, .env (copied from the Mac), contact, riot.txt, crawl.args, host.env
  (MEIOLOL_BACKUPS, MEIOLOL_NO_EVAL; tuning per host, default when unset:
  MEIOLOL_FILTER_RUNS, the views write's parallel filter tally, 4, 1 to 64;
  MEIOLOL_VIEW_LOADS, views the views write loads at once, 1, 1 to 4)
- systemd --user services, lingering: meiolol-crawl, meiolol-web, meiolol-backup,
  meiolol-health (deploy/systemd). `systemctl --user status meiolol-crawl`; logs in data/
- Disk scheduler: C01 runs the image's `none`, under which ionice does nothing (the
  Oracle box trialled mq-deadline: research/questions/box-io-priority.md). Under
  mq-deadline an idle-class read waits up to 10 s behind the crawler's, so nothing
  holding a database write lock runs idle class; those use `ionice -c 2 -n 7`
- crawl.args: `--proxy 127.0.0.1:8092 --timelines 50 --timelines-priority 100
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
deploy/web-loop.sh; the list is core_static in src/site/root.zig): robots.txt,
riot.txt, CSS, JS, wasm, font and icon, ~30 files with their .gz twins, all at the site
root, from the options alone (no view loaded, seconds). The web loop builds only in a
round that uploads; the others read the patch and game count with `meiolol site --patch-games`
(1-8 s). meiolol-render on the box serves every page and data file (the home, champion,
champions board, matchup, Daily Draft, Learn, legal and method pages, the views' _v/
trees, data/ files, the sitemap, data/your-example.json).
URLs are clean (docs/plan/urls.md; arch-site.md "Website"): nginx's
`try_files $meiolol_view$uri.html $uri $uri.html @render`, $meiolol_view mapped from
?region= and ?period= to the internal view tree (also in both proxy_cache_keys; other
query keys such as the pool's ?champs= are state and stay out). `location = /` goes
straight to @render (deploy/cache-warm.sh warms it first). Old .html URLs: a
server-level `return 301` from the $meiolol_old map (mirrors urls.legacy, the old view
dirs turned into the query; deploy/url-smoke.sh curls deploy/nginx/redirect-samples.tsv
on C01); a trailing slash 301s off. The renderer does the same (serve.zig) and gzips
what it sends when the client accepts it (nginx compresses only HTML itself; stats.bin
is ~12 MB raw), with Vary: Accept-Encoding; on a miss whose lowercase is a page, a 301
to it.
- `meiolol render` (systemd meiolol-render@a or @b) on C01's LAN address
  (192.168.18.71:8091, `hostname -I`'s first; ufw keeps it to the host), every view loaded up front from data/views.bin. Loading views from the
  database beside the crawler takes 10-105 min and ~2.5 GB, so that work happens once
  per data refresh, in the web loop (research/questions/fast-deploy-data-servers.md):
  after each upload `meiolol site --views data/views.bin` (same flags as the core build)
  loads every view and writes them to one file, then touches data/render.reload; the
  renderer reads the file in seconds and swaps it in. A views file written by a binary
  with other part keys (types or data code: docs/arch-site.md "Views file") or a
  missing one makes the renderer load from the database instead. Render code changes
  show at the swap, in seconds
- A deploy that changes a part waits for the forced round's `--reuse` write, which keeps
  the parts still current and loads only the changed ones; a write running at the deploy
  finishes first and the deploy's write reuses its unchanged parts (stopping it costs
  far more). Kept parts refresh at the next upload's full write
- A full write reads only new, REPLACEd or newly timelined games from data/partials
  (docs/arch-site.md "Views partials"); above ~150k games to read it reads whole
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
  ships (swapping first would show new pages unstyled until it does).
  Connections queued on the stopping one move to the new one (sysctl
  net.ipv4.tcp_migrate_req=1, /etc/sysctl.d/60-meiolol-render.conf) and nginx retries a
  dropped one once. Alone (a boot) it listens at once and serves each view as it loads
  (the root view after ~40 s, all ~3 min, longer while the disk is busy); until then
  503, so nginx serves its cached copy where it has one, and pages not in its cache are
  down. Log data/render.log
- The crawler's Your games proxy listens on 127.0.0.1:8092 for meiolol-api
- nginx (deploy/nginx/meiolol.conf, installed by deploy/vm-web.sh as
  /etc/nginx/conf.d/meiolol.conf; the token and key includes stay on C01 only):
  every request comes from cloudflared on 127.0.0.1, so real_ip takes the visitor from
  CF-Connecting-IP (limit_req keys on it). try_files, then `@render` (upstream
  meiolol_render: the renderer twice, for the retry): proxy cache /var/cache/nginx/meiolol (2
  GB, key `$uri|$meiolol_version`), 200s 10 min, 404s 1 min (the site's own 404 page,
  status kept: only 5xx are intercepted), stale copies while the box
  is down or refreshing, one render per page under a burst. Header X-Meiolol-Render:
  HIT, MISS, STALE, UPDATING
- Cache version: each renderer load (start or reload) gets a version, its load time in
  ns as 16 hex digits, written to its --ready file. meiolol-cache-version.path on the
  box runs deploy/cache-version.sh when a ready file changes, and render-swap.sh runs it
  once the old renderer has stopped. With exactly one renderer serving, it sends that
  version over ssh alias meiolol-cache (box key ~/.ssh/meiolol_cache, in C01 user
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
  through nginx at 127.0.0.1:8080 with X-Meiolol-Warm: 1, which nginx honours only from
  127.0.0.1 (geo $meiolol_from_box): always fetched anew
  (proxy_cache_bypass) and stored under `<uri>|any`. One at a time at 20/s: the site's
  7-day top 30 first (the receive script answers with them from traffic.json), then the
  renderer's list (/admin/api/pages.txt, admin token: every page of the loaded views,
  matchups only from 200 games, as thinner ones are ~54k pages a view; thin matchups
  stay render only). Pages render from memory, so no disk for the crawler to wait on.
  Log `cache-warm:` in data/render.log. @render asks the box for gzip (`proxy_set_header
  Accept-Encoding gzip;`, `gunzip on;` for clients without it) and ignores Vary, so one
  copy per page serves everyone; it intercepts the box's 503 (proxy_intercept_errors) to
  reach @render_any. nginx's access log skips user agent meiolol-cache-warm (map
  $meiolol_logged), so traffic.json counts visits only. STALE in that log is the
  background refresh of an expired copy, not an outage. A renderer start reads views.bin
  and serves in 1.3 s (file in page cache) to 16.6 s (evicted, as after a boot); swaps
  take as long; with the renderer stopped a warmed page is ANY-HIT, an unwarmed one 503
- Cache-Control: `map $uri $meiolol_cache_control` gives hashed assets
  (src/site/assets.zig: `style.1a2b3c4d.css`, the font, search.js, the islands' .js and
  .wasm; `name.<8 hex>.ext` at the root) and champion portraits (src/icons.zig:
  `/icon/<Data Dragon version>/<Key>.jpg`) `public, max-age=31536000, immutable`,
  everything else `no-cache`, in `/`, @render and @render_any (which hide the renderer's
  own no-cache). A page after the first asks for none of them. A replaced hashed file
  stays 3 days after its replacement came, as does an older portrait folder, and a
  hashed name no longer built 30 days (`meiolol site --prune-assets`, from
  deploy/web-loop.sh); one missing from the upload falls through to the renderer, which
  serves its own
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
  Top pages count an old path as its new one (`meiolol urls`, the API binary). The new
  admin page reads it as /admin/api/traffic.bin: `meiolol render` converts the file on
  each request (src/admin.zig trafficBin, last 30 days)
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
  /login?next=, a lower role gets 403 (meiolol-api.htpasswd is unused).
  /account: own password, log out everywhere. The admin page's Accounts tab
  (manage_accounts) lists logins, makes invite and reset links, changes roles and
  disables, below the signed-in role only. Accounts by hand: `sudo -u meiolol-api
  meiolol account ... --data /var/lib/meiolol-api` on C01 (list, reset, link,
  revoke-links, delete; the owner only here).
- Private site (/p/, docs/plan/accounts.md "private"): static, uploaded by the web loop to
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
