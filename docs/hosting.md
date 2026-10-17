# Hosting the backend (the box)

Moved off the gpu-box PC on 2026-10-11 so Jacob's PC and laptop can be off. Everything
runs on Oracle Cloud Always Free, home region uk-london-1 (tenancy `jacobmaschler`; free
accounts may use Always Free only in the home region).

## Hosts

| alias | what | shape | disk |
|---|---|---|---|
| meiolol-cloud | the box: crawler, site build + upload, backups, health | A1 `meiolol`, VM.Standard.A1.Flex 2 OCPU / 12 GB (aarch64), AD-1, 140.238.101.20 | 150 GB boot |
| (jomify) | nginx: site, Your games service, jomove | E2.1.Micro, 193.123.180.81 | 47 GB boot |

- Box on the A1 since 2026-10-11 ~15:55Z (launched 12:29Z by the retry loop; free up
  to 1500 OCPU-h + 9000 GB-h a month = 2/12). Move: data rsynced micro -> A1 over the
  private network (10.0.0.152 -> 10.0.0.3, temporary key ~/.ssh/move_a1 on the micro,
  removed from the A1 with the micro), ~6 MB/s (micro network); crawler down
  15:51-15:55Z. 2026-10-11 ~21:05Z (Jacob's OK): micro terminated with its boot volume
  (all its data and backups were on the A1), A1 boot grown 50 -> 150 GB online
  (rescan, growpart, resize2fs; balanced volumes scale throughput with size, 50 GB was
  ~24 MB/s). The free tier caps A1 at 2 OCPU / 12 GB in total, so the micro's slot was
  worth less than its 50 GB of disk
- The Ubuntu image's /etc/fstab mounts / with online `discard`: every delete queued a
  trim that took ~75 s on this volume, and after the copy the backlog held the disk at
  ~90% pressure and starved the crawler's commits. Dropped from fstab and remounted
  `nodiscard` (16:20Z); fstrim.timer trims weekly instead. Do the same on any new host
- Account on Pay As You Go since 2026-10-11 (Jacob's card; limits jumped to 250 A1
  OCPUs). Guards: quota policy `free-tier-guard` (other compute shapes zero, A1 2/12,
  E2 micro 2, block storage per AD summing to 200 GB: AD-1 153, AD-2 47, AD-3 0, 5
  backups, 20 GB object storage) and
  budget `free-tier-guard` (1 a month, email at 1% actual and 100% forecast).
  Why: research/questions/oci-payg-upgrade.md
- Block storage: 200 GB free in total. In use: A1 boot 150, jomify boot 47. The
  unattached April "Jomify (Boot Volume)" (47 GB, a terminated instance's) was deleted
  2026-10-11 after a full backup, "jomify-boot-2026-04 (kept before delete)" (1 of 5
  free backups; restore it as a volume to look inside)
- Ssh: `meiolol-cloud` in ~/.ssh/config (user ubuntu, key oci_instance-20260714-1317).
  On the box, ~/.ssh/config has meiolol-web and meiolol-exchange (rrsync users on jomify)
- OCI CLI on the Mac: ~/.oci/config, API key ~/.oci/oci_api_key.pem (Jacob's user). The
  console login is in jodrive (`jodrive oracle login`, .env.oracle incl. the TOTP key)

## On the box

- ~/ml/meiolol: bin/ (deployed by deploy/box.sh, built for the host's CPU), data/,
  backups/, .env (copied from the Mac), contact, riot.txt, crawl.args, host.env
  (MEIOLOL_BACKUPS, MEIOLOL_NO_EVAL=1 on the micro)
- systemd --user services, lingering: meiolol-crawl, meiolol-web, meiolol-backup,
  meiolol-health (deploy/systemd). `systemctl --user status meiolol-crawl`; logs in data/
- Disk scheduler: mq-deadline on trial since 15 Oct 11:35 UTC, set at runtime only
  (`echo none | sudo tee /sys/block/sda/queue/scheduler` reverts; a reboot does too).
  Under the image's `none`, ionice does nothing. Why and numbers:
  research/questions/box-io-priority.md
- crawl.args (2026-10-17): `--proxy 10.0.0.3:8092 --timelines 100 --raw-timeline-days 3650
  --raw-match-days 0 --raw-valve-free-gb 10 --keep-days 0 --ladder-per-hour 500
  --ladder-refresh-hours 12 --player-sample 16 --min-tier PLATINUM --cache-mb 512
  --patch-only --flex-calls-per-day 500` (keep everything;
  raw leaves the box only through the archive: an export drops the raw timelines it
  holds, `raw-export --ack` prunes acked raw older than 2 days; under 10 GB free the
  valve drops unarchived raw, docs/data-safety.md "Raw archive"; Platinum IV and up
  only). Previous copy crawl.args.bak-20261017 (no valve)

## Rendering on request

The static upload is only what nginx must serve itself (`meiolol site --static core`,
deploy/web-loop.sh; the list is core_static in src/site/root.zig): the home page,
robots.txt, riot.txt, the root sitemap, CSS, JS, wasm, font and icon, ~30 files with
their .gz twins, all at the site root; the build loads only two views' stats.
meiolol-render on the box serves every other page and file (champion, role, matchup,
build, Daily Draft, Learn, legal and method pages, the patch/ and all/ views, data/
files, the views' sitemaps, data/your-example.json).
The home page stays static because the root directory always exists, and nginx's
try_files answers an existing directory's URL with its index.html or 403, never
@render; for the same reason nothing is uploaded into a subdirectory. Before 14 Oct
everything but thin matchups was static (13.5k files, 408 MB, a 4-13 min site pass
on the box). The renderer gzips what it sends when the client accepts it (nginx
compresses only HTML itself; stats.bin is ~12 MB raw), with Vary: Accept-Encoding so
nginx caches each encoding apart, and answers a directory URL without its slash with a
301, as nginx did for uploaded directories.
- `meiolol render` (systemd meiolol-render@a or @b) on the box's private address
  10.0.0.3:8091, every view loaded up front from data/views.bin. The database work
  happens once per data refresh, in the web loop: after each upload `meiolol site
  --views data/views.bin` (same flags as the core build) loads every view (what a
  renderer load did: 2-13 min, longer on a busy disk) and writes them to one file, then
  touches data/render.reload; the renderer reads the file in seconds and swaps it in. A
  views file written by a binary with other part keys (types or data code: docs/
  architecture.md "Views file") or a missing one makes the renderer load from the
  database instead, as before 15 Oct. Render code changes show at the swap, in seconds.
  A deploy that changes a part waits for the forced round's `--reuse` write, which keeps
  the parts still current and loads only the changed ones (16 Oct's spread change would
  have loaded the people part, 511 s of a 1,085 s write); a write running at the deploy finishes first and the
  deploy's write reuses its unchanged parts (from 17 Oct; stopping it instead cost a
  10 and a 72 min write that day, the swap waiting 1 h 43). Kept parts refresh at the
  next upload's full write.
  The heavy loads read in parallel (16 Oct): filters in 4 runs of games, learning in 4
  puuid ranges, each on its own read-only connection (schema.openSibling), and filters
  beside the people tallies; the box waits on cold pages, one read in flight each.
  docs/plan.md "Parallel reads". views.log gives each phase's CPU time beside its time
  First deploy (15 Oct, disk at ~80% pressure): views.bin 148 MB, written in 72 min,
  read in 14 s; the swap took 16 s; the renderer holds ~2.0 GB (curves files ~940 MB
  of it)
  Why (15 Oct): every swap from 21:04 on 14 Oct timed out; each load read the 8.4 GB
  DB at random beside the crawler, a second renderer and the batch jobs, 10 to 105 min,
  and a renderer kept 2.3-2.6 GB (the pool tallies of 1.9M players). Research:
  research/questions/fast-deploy-data-servers.md. A deploy runs
  deploy/render-swap.sh: it starts the idle
  instance beside the running one (both listen, SO_REUSEPORT), and stops the old once the
  new one writes data/render-<a|b>.ready, so there is no gap. Connections queued on the
  stopping one move to the new one (sysctl net.ipv4.tcp_migrate_req=1,
  /etc/sysctl.d/60-meiolol-render.conf) and nginx retries a dropped one once. Alone (a
  boot) it listens at once and serves each view as it loads (the root view after ~40 s,
  all ~3 min, longer while the disk is busy); until then 503, so nginx serves its
  cached copy where it has one, and pages not in its cache are down. Log data/render.log
- Network: jomify (10.0.0.214) and the box share subnet 10.0.0.0/24. Security list rule
  "meiolol-render: jomify nginx to the box" (TCP 8091 from 10.0.0.214/32; the list as it
  was is in .git/oci-ingress-before-render.json on the Mac) and an iptables ACCEPT on the
  box before its REJECT (saved with netfilter-persistent). Jacob's OK 2026-10-12. The
  same for the crawler's Your games proxy: "meiolol-proxy: Your games service to the
  crawler", TCP 8092 from 10.0.0.214/32 (Jacob's OK 2026-10-13)
- jomify nginx (/etc/nginx/conf.d/meiolol.conf; before: meiolol.conf.bak-2026-10-12-render):
  try_files, then `@render` (upstream meiolol_render: the box twice, for the retry): proxy cache /var/cache/nginx/meiolol (2 GB, key `$uri|$meiolol_version`), 200s
  10 min, 404s 1 min, stale copies while the box is down or refreshing, one render per
  page under a burst. Header X-Meiolol-Render: HIT, MISS, STALE, UPDATING
- Cache version (16 Oct, Jacob's OK; nginx before: /etc/nginx/meiolol.conf.bak-2026-10-16-version):
  each renderer load (start or reload) gets a version, its load time in ns as 16 hex
  digits, written to its --ready file. meiolol-cache-version.path on the box runs
  deploy/cache-version.sh when a ready file changes, and render-swap.sh runs it once the
  old renderer has stopped. With exactly one renderer serving, it sends that version over
  ssh alias meiolol-cache (box key ~/.ssh/meiolol_cache, in jomify user meiolol's
  authorized_keys with forced command `sudo -n /usr/local/bin/meiolol-cache-version`,
  one line in /etc/sudoers.d/meiolol-cache-version). That script
  (deploy/cache-version-receive.sh; reinstall by hand when it changes) checks the version
  is 16 hex digits, writes /etc/nginx/meiolol-version.conf (a `map` setting
  $meiolol_version), then runs `nginx -t` and reloads. So new data or code shows at once.
  Copies under older versions are never read again and expire (inactive=30d); each
  reload starts the cache cold, so after one, a page not yet requested again has no
  stale copy if the box goes down. Last sent version: data/cache-version; log lines
  `cache-version:` in data/render.log
- Outages (the renderer is the main path since `--static core`): any page nginx cached
  in the last 30 days (inactive=30d) is served stale on error, timeout or 503; a page
  not in its cache is 503 until the renderer is back. @render asks the box for gzip
  (`proxy_set_header Accept-Encoding gzip;`, `gunzip on;` for clients without it), so
  one cached copy per page. Applied 2026-10-14 (Jacob's OK; before:
  /etc/nginx/meiolol.conf.bak-2026-10-14-cache). Not built: a warm-up from the box
  after each reload (every sitemap URL through nginx, a few per second) so every page
  has a copy to fall back on
- Training view (/admin/training/, same basic auth as /admin/; data for the admin Models
  tab): lab runs of the Mac and the gpu-box (staged over ssh, home network only), learned.md,
  model.md, campaigns, uploaded by deploy/lab-push.sh (launchd, every 30 s when changed). Served from
  /var/www/meiolol-training/current (symlink; outside /var/www/meiolol, whose uploads
  --delete). Mac key ~/.ssh/meiolol-training, in user meiolol's authorized_keys with forced
  command /usr/local/bin/meiolol-training-receive (deploy/training-receive.sh, reinstall
  by hand when it changes: tar on stdin, swapped in atomically). Not rrsync: macOS's
  openrsync is refused by it. nginx before: /home/ubuntu/meiolol.conf.bak-training
- Site traffic (/admin/ops/traffic.json, same basic auth): meiolol has its own nginx access
  log, /var/log/nginx/meiolol.access.log, format meiolol_noip (JSON lines: time, status,
  method, uri without query, bytes, request time, render cache, referer, user agent; no
  IP addresses, so none are kept or derived; /api/ stays unlogged). deploy/traffic.sh
  aggregates it every 5 min (meiolol-traffic.timer, system unit, user meiolol-traffic,
  sandboxed: sees only /var/log/nginx, no network) into /var/www/meiolol-ops. State in
  /var/lib/meiolol-traffic: per log file summaries cached by inode with the offset read
  (files/), hourly totals kept 90 days (hourly.tsv). Update by hand: scp the script and
  units, `sudo install -m 755 traffic.sh /usr/local/bin/meiolol-traffic`, units into
  /etc/systemd/system, `daemon-reload`. nginx before: /home/ubuntu/meiolol.conf.bak-dashboard
- Admin API (/admin/api/, src/admin_api.zig): `meiolol render` on the box answers
  live.json (crawler's last 3 h by minute, queues, services, health; cached 30 s),
  log?file=&lines= (crawl, web, eval, render, health, backup, builds; ids and Riot IDs
  redacted) and POST action/NAME (crawl-start|stop|restart, site-build, eval-run,
  health-check: fixed commands, one at a time across both instances via
  data/admin-action.lock, each logged to data/admin-actions.log; eval-run shares
  data/eval.lock with web-loop.sh's daily eval and is refused under MEIOLOL_NO_EVAL).
  Layers: basic auth at nginx; nginx adds X-Meiolol-Admin from
  /etc/nginx/meiolol-admin-token.conf (root only) and clears it on public @render
  requests; the box compares it in constant time with ml/meiolol/admin.token (64 hex,
  read per request, so rotate by rewriting both and reloading nginx); without a match
  the routes do not exist (same 404/405 as any path). Actions also need the request
  header X-Meiolol-Action: 1, which a cross-site form cannot send. 8091 takes only the
  web server

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
| deploy | on-push.sh | start, skipped (docs only), ok or failed with box.sh's last line |
| build | on-push.sh | start; ok at box.sh's "deployed SHA" (binary and scripts copied) |
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
- History before 17 Oct 14:55 BST was rebuilt once from .git/meiolol-deploy.log, the
  origin/main reflog, DEPLOYED, render.log and web.log (no ci lines, views parts not
  recorded)

## Known problems on the micro

- Slow: ~11k matches/day vs ~135k on the PC with 19 writing threads (153 lock waits in
  27 min); memory tight. Single writer thread since branch worktree-writer (1.5x matches,
  4x mastery in a 1/8-CPU emulation, docs/architecture.md); the A1 fixes the rest
- `meiolol backup` holds the DB for 10+ minutes here and starves the crawler of writes
  ("database is locked"), so the first run was killed; backups need rework (off-host
  target too: they sit on the same disk). gpu-box keeps its data and the 2026-10-11 D:
  backup as the restore point until Jacob retires it
- Disk: ~1.6 GB/day kept forever at the full all-region rate: weeks on this disk
