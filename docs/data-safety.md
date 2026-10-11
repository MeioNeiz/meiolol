# Data safety

Disk headroom, backups, health alerts and GDPR erasure for the data on the box. Written
2026-10-11. Decisions by Jacob that day: backups to D: with a Mac mirror; back up tables
and compact timelines, not raw JSON; erasure blanks identity and keeps match rows; alerts
by `wz notify` on the Mac plus ntfy pushes from the box.

## Disk

The box moved to Oracle Cloud on 2026-10-11 (docs/hosting.md): one 50 GB boot volume,
~40 GB free, backups on the same disk for now (`MEIOLOL_BACKUPS` in host.env).

- Full rate needs ~1.6 GB/day kept forever plus rolling raw JSON: ~1.7 GB/day of
  summaries for `--raw-match-days` (30) and ~8.6 GB/day of raw timelines for
  `--raw-timeline-days` (7), ~110 GB at the defaults. On 40 GB that is days, not weeks:
  run with small raw windows (eg 3 and 1) until there is more disk
- Open (Jacob): the free tier has ~106 GB more block storage, still only ~2 months of
  kept data; ~570 GB/year needs paid storage, less crawling, or the PC as bulk store
- Off-host backups still to set up: the gpu-box pulling into D: and/or the Mac mirror
- The gpu-box (before the move) keeps its data and the 2026-10-11 backup in
  /mnt/d/meiolol-backups (restore-tested) as the restore point. Its WSL disk image lives
  on C: (~252 GB free); its 2 TB NVMe has 673 GB unallocated, if it becomes the bulk store

## Backups

`meiolol backup` (src/backup.zig), daily at ~04:00 UTC from the `meiolol-backup` service
(deploy/backup-loop.sh), into $MEIOLOL_BACKUPS (host.env). It never runs migrations:
under the write lock they starve the crawler on a slow host.

- `state/state-YYYY-MM-DD.db`: players, ladder_pages, match_queue, timeline_queue,
  mastery, champions, forgotten. 7 daily + the newest of 4 weeks
- `segments/NNNNNN.db`: matches, participants and bans of matches stored since the last
  segment (by matches rowid), and compact timelines likewise (timelines rowid). Stored
  rows never change, so segments are append-only and never rotated
- Each file is plain SQLite, written as *.tmp inside one read transaction (consistent
  while the crawler writes) and renamed when complete. Not raw JSON: raw.db is a 30-day
  buffer and the tables hold what it gives
- After `meiolol rebuild` or `rekey` (they rewrite stored rows) run `meiolol backup
  --full`: one segment with everything, replacing the others
- The Mac mirrors the directory daily to `~/Backups/meiolol` (deploy/mac-watch.sh,
  `rsync --delete`, so rotation and erasure scrubs follow)

Covers: a corrupt WSL image, a WSL reinstall, C: failing, a bad migration or DELETE (state
up to 4 weeks back). Not covered: losing the PC and the Mac together (nothing off-site).
D: holds ~85 days of full-rate growth; before then move backups to the 2 TB NVMe or paid
object storage (~$6/TB/month). The health check warns at 90% on D:.

Measured 2026-10-11 (8,117 matches, 1.13M players): state 146 MB, segment 23 MB, backup
1 s, restore 2.6 s.

### Restore

1. `bin/meiolol restore --from /mnt/d/meiolol-backups --data data.restored` (refuses a
   directory that already holds a database; `--state FILE` for an older snapshot)
2. `bin/meiolol status --data data.restored`: compare with what you expect
3. Stop the crawler and loops, `mv data data.broken && mv data.restored data`, copy back
   anything outside the databases (daily/, export/, site/), start again

Raw tables come back empty; the crawler refills them. Restore re-applies `forgotten`.

Restore test, 2026-10-11 on the box: backup of the live data into backups/test, restore
into backups/restore-test, `meiolol status` on both: every count equal (players
1,134,448, matches 8,117, participants 81,170, bans 78,553, timelines 728, queues,
mastery, champions) except raw.raw_docs and raw.timeline_docs (0, by design). Repeat on
the first D: backup, then quarterly.

## Health alerts

deploy/health.sh runs on the box and prints one line per problem:

| Check | Problem when |
|---|---|
| crawler | tmux `meiolol-crawl` gone; "Riot rejected the key" if crawl.log ends in KEY REJECTED |
| crawler silent | last per-minute report older than 15 min |
| no new matches | report's per-region match counters unchanged for 2h (STALL_H) |
| site | tmux `meiolol-web` gone, or last upload in web.log older than 26h |
| disk | /mnt/c or / at 80%, /mnt/d at 90% (it was 86% before backups) |
| backup | tmux `meiolol-backup` gone, or newest state snapshot older than 26h |

- Box: tmux `meiolol-health` (deploy/health-loop.sh) every 15 min; pushes to the private
  ntfy.sh topic NTFY_TOPIC from .env when the problems change, every 12h while they last,
  and once when resolved. Subscribe in the ntfy app to that topic (`vault get meiolol
  NTFY_TOPIC` in your own terminal)
- Mac: launchd `net.jacob.meiolol-watch` every 30 min (deploy/mac-watch.sh): the same
  check over ssh, toasted with `wz notify`; adds "gpu-box unreachable" (PC off or asleep)
  and a stale Mac mirror. Log in ~/.cache/meiolol-watch/log
- Manage: `deploy/box.sh backup|health start|stop|status`, `deploy/box.sh health check`,
  `deploy/box.sh watch install|uninstall`

## Erasure (GDPR)

`meiolol forget --puuid P | --riot-id Name#TAG | --list FILE [--backups DIR]`
(src/forget.zig). One transaction per player, `PRAGMA secure_delete` on, so freed pages
are overwritten. Logs counts only, never the PUUID or Riot ID.

| Where | What happens |
|---|---|
| players, mastery | rows deleted |
| participants | puuid set to NULL; the match and its stats stay, linked to no one |
| raw.raw_docs (riot_match) | summaries of their games deleted (they name all ten players) |
| raw.timeline_docs | raw timelines of their games deleted (they hold PUUIDs) |
| timeline.timelines | nothing: compact timelines hold slots 1-10 only |
| forgotten | PUUID and date added: the suppression list |
| Daily Draft (daily/used.txt, puzzles) | nothing: match ids and anonymous puzzles only |
| backup files | `--backups /mnt/d/meiolol-backups` scrubs every state and segment file at once |
| Mac mirror | follows on its next daily sync (rsync replaces the scrubbed files) |
| Your games (api.db on the web server) | `forget --data /var/lib/meiolol-api` there: `api.cache.forget` deletes and adds to `blocked` |

- Suppression: the crawler skips PUUIDs in `forgotten` on ladder and mastery and stores
  their participant rows with a blank PUUID (meiolol-de, crawl.zig, via
  `forget.isForgotten`). Plain PUUIDs, not hashes: a rekey to the production key must
  translate the list (old PUUID to Riot ID with the old key, then the new PUUID)
- Restores re-apply `forgotten` from the newest state snapshot, so an older segment
  cannot bring a player back
- Box and Your games service swap complete lists daily (deploy/backup-loop.sh, before
  the backup): the box pulls the service's forgotten.txt and runs `forget --list ...
  --backups ...`, then pushes its own list (`forget --export`) as box-forgotten.txt,
  which the service blocks. So an objection honoured on the site reaches the box and its
  backups within a day. PUUIDs already in `forgotten` are skipped, so reruns stay cheap.
  `forget` opens whichever of meiolol.db and api.db the data directory holds
- Riot erasure lists: copy the list (PUUIDs or Riot IDs, one per line) to the box, then
  `deploy/box.sh run forget --list FILE --backups /mnt/d/meiolol-backups`. A Riot ID
  that no longer resolves (renamed or deleted) is counted and exits 1: get its PUUID
- Not wiped: freed ext4 blocks inside the WSL image and on D: (accepted; files are
  rewritten, not just unlinked)
- Retention sweeps (players not seen for 30 days, PUUIDs blanked after 24 months) live in
  the crawler's hourly prune (meiolol-de). Public wording: docs/legal/privacy.md
