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
- crawl.args: `--reserve 20 --timelines 50 --no-mastery --raw-timeline-days 0
  --raw-match-days 3 --keep-days 60 --ladder-per-hour 40 --player-sample 16 --min-tier
  PLATINUM --cache-mb 512` (raw retention cut for the old 50 GB disk; Platinum IV and up
  only). The 150 GB disk now has room for the plan's "keep more data" retention

## Rendering on request

The static upload leaves out matchup pages under 200 games (`meiolol site
--static-min-games 200`, deploy/web-loop.sh); meiolol-render on the box serves them.
- `meiolol render` (systemd meiolol-render@a or @b) on the box's private address
  10.0.0.3:8091, all views loaded up front (~3.5 min, ~600 MB); deploy/web-loop.sh
  touches data/render.reload after each upload and it loads the new data in the
  background, swapping when done. A deploy runs deploy/render-swap.sh: it starts the idle
  instance beside the running one (both listen, SO_REUSEPORT), and stops the old once the
  new one writes data/render-<a|b>.ready, so there is no gap. Log data/render.log
- Network: jomify (10.0.0.214) and the box share subnet 10.0.0.0/24. Security list rule
  "meiolol-render: jomify nginx to the box" (TCP 8091 from 10.0.0.214/32; the list as it
  was is in .git/oci-ingress-before-render.json on the Mac) and an iptables ACCEPT on the
  box before its REJECT (saved with netfilter-persistent). Jacob's OK 2026-10-12
- jomify nginx (/etc/nginx/conf.d/meiolol.conf; before: meiolol.conf.bak-2026-10-12-render):
  try_files, then `@render`: proxy cache /var/cache/nginx/meiolol (2 GB, key $uri), 200s
  10 min, 404s 1 min, stale copies while the box is down or refreshing, one render per
  page under a burst. Header X-Meiolol-Render: HIT, MISS, STALE, UPDATING

## Known problems on the micro

- Slow: ~11k matches/day vs ~135k on the PC with 19 writing threads (153 lock waits in
  27 min); memory tight. Single writer thread since branch worktree-writer (1.5x matches,
  4x mastery in a 1/8-CPU emulation, docs/architecture.md); the A1 fixes the rest
- `meiolol backup` holds the DB for 10+ minutes here and starves the crawler of writes
  ("database is locked"), so the first run was killed; backups need rework (off-host
  target too: they sit on the same disk). gpu-box keeps its data and the 2026-10-11 D:
  backup as the restore point until Jacob retires it
- Disk: ~1.6 GB/day kept forever at the full all-region rate: weeks on this disk
