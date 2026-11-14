# Health

What can go wrong on the box unseen, how it is checked and where it reaches Jacob.
NTFY_TOPIC (phone pushes) is unset by Jacob's choice (docs/plan/decisions.md), so the
checks surface where he already looks. Backups, disk and erasure: docs/data-safety.md.

## Where it shows

deploy/health.sh, on the box, prints one line per problem (exit 1 when any):

- Box: user unit meiolol-health (deploy/health-loop.sh) every 15 min, log data/health.log;
  with NTFY_TOPIC in .env it pushes to that private ntfy.sh topic when the problems
  change, every 12h while they last, and once when resolved
- Mac: launchd `net.jacob.meiolol-watch` (deploy/mac-watch.sh) every 30 min (and on
  wake): the same check over ssh as `wz notify` toasts, plus "unreachable", "data disk
  not mounted" and the Mac mirror; its last result in ~/.cache/meiolol-watch/last
- Claude Code: each session in this repo opens with that last result
  (deploy/hooks/claude-box-health.sh, SessionStart; silent while all is well). A result
  over 45 min old kicks the watch in the background; it never waits on ssh
- Admin page: the overview and controls tabs open with the problems (first line, "+N
  more", the log), from the live API's own health.sh run (2 min cache)
- `deploy/box.sh status`: a health headline, run live, above the crawler's numbers
- Manage: `deploy/box.sh backup|health start|stop|status`, `health check`, `watch
  install|uninstall`

## Checks

| Check | Problem when |
|---|---|
| crawler | unit `meiolol-crawl` not active; "Riot rejected the key" if crawl.log ends in KEY REJECTED |
| crawler silent | last per-minute report older than 15 min |
| no new matches | report's per-region match counters unchanged for 2h (STALL_H) |
| crawler key use | any region's requests over the last 30 min of this crawler run under 90% of the key's 100 per 120 s (KEYUSE_MIN, KEYUSE_PCT; the report lines' `req` counters: the time % lines show 10-15% lost in hours that used 97-100%); 4-10 Nov it would have fired 1-6 times a day. Its line carries when it began (data/health.episodes), so it pushes once (the next row's too) |
| crawler writer stalling | crawl.log `stall:` or `no checkpoint for` lines in the last 15 min (riot/stall.zig) |
| complete form off | the last report line says `complete off`: a packer or sealer error, the form restarts from its spool after 60 s, doubled for each other restart in the last 6 h, at most 1 h (riot/complete.zig); the line's `complete` part counts docs, raw, frames, MB, queued, dropped (queue full at 200,000, or a spool write failed) and restarts in the last hour; also a problem: 3+ restarts in an hour, or any dropped |
| complete form still | the newest `.part` in data/complete not written for 30 min while the crawler runs (mastery blocks seal about every minute) |
| complete form scrub | data/complete-scrub.status, the last scrub by any `forget` or `backup`, is not `ok`: day files failed (`failed N`) or the scrub stopped (`error NAME`); the next run retries. The forgotten list is exported before the scrub, so mirrors and the archive still get it |
| Megatron mirror | unit `meiolol-megatron-mirror` failed: the line carries the cause (backup-mirror.sh's dated `FAILED (exit N) at STEP` line in data/backup-mirror.log and the output before it), e.g. its day files rsync |
| complete form quarantine | files in data/complete/spool/quarantine (below) |
| WAL not checkpointed | a data/*.db-wal over 4 GB (crawler's checkpointer stuck, or a reader holding it); names the processes holding a WAL read mark (/proc/locks on the -shm, bytes 124-127) other than the crawler: unit, command, pid, minutes up |
| crawler auto restart | deploy/crawl-revive.sh (below) restarted the crawler in the last 24 h (the line says why), or gave up on it |
| site | unit `meiolol-web` not active, or last upload in web.log older than 26h |
| site loop step | a step's latest outcome in data/web-steps.tsv failed (web-loop.sh: digest, curves, curves-push, lockrows and meio (pass or refit), site, upload, views, desktop, admin; daily builds, prev-curves, eval, example, lean, truth, tester, storage); clears when the step next succeeds |
| site end to end | from C01 through https://meio.lol (Cloudflare tunnel, nginx): the home, a lock answer (data/lock/meio/darius/top/plat/none.bin) or /api/health not 200, or served from nginx's copy (X-Meiolol-Render STALE or ANY-*: the renderer did not answer); MEIOLOL_SITE in host.env, empty for none |
| disk | / at 80% not counting C01's fixed 30 GB disk cache file (the rest grows slowly: snaps, nginx's 2 GB cache, /var/www), or the data's disk at 80%; or the data disk under 30 days from full at its weekly growth plus the newest whole day of day files (Disk) |
| mounts | a path in host.env's MEIOLOL_MOUNTS not mounted (C01: /srv/meiolol, /srv/megatron, /srv/megatron-backups); with the data disk itself down health.sh can't run: mac-watch.sh says "data disk not mounted" (ssh's exit 127) |
| deploy | the newest finished deploy in data/deploys.tsv failed (the Mac's on-push.sh queues events until the box answers) |
| box behind origin | origin main's head (`git ls-remote`, MEIOLOL_ORIGIN in host.env, empty for none) has no row in data/deploys.tsv for 2 h (BEHIND_H): the push never reached the Mac's on-push.sh (asleep). Every head it handles leaves a row, skipped docs pushes too |
| backup | unit `meiolol-backup` not active, or newest state snapshot older than 26h |
| gpu-box | no raw archive ack for 12h (ACK_H) while exports wait or no pull reported for 12h (data/gpu-box.pull; nothing exported, e.g. the crawler stored nothing, stops acks too): PC off, asleep or WSL down; first export never acked; one export unacked for 12h while others are acked (see archive-pull.log on the gpu-box) |
| gpu-box disks | C: (holds the WSL disk) or the WSL disk or the archive partition at 85%, or the partition not attached; reported by each archive pull |
| gpu-box logins backup | the last accounts pull failed, its timer is not running, or the newest copy is over 3 days old; reported by each archive pull |
| raw held | free disk above the raw valve under 3 days of raw (bytes sent to the gpu-box over the last 24 h, data/archive-sent.log): what an outage of the gpu-box can last before the valve drops unarchived raw; exports waiting on the box shown apart |
| gpu-box archive | last pull reported a failure (data/gpu-box.pull, written by archive-serve.sh report): cause and since when, pushed once per failure |
| raw valve | the disk valve dropped raw the archive never got in the last 24 h (raw-export --status drops_24h, data/raw-dropped.log) |
| backup mirrors | backups not mirrored for 26 h, or a mirror silent for 48 h (backup-serve.sh status) |

## Crawler auto restart

deploy/crawl-revive.sh, first in each health-loop.sh round: a crawler up 3 h (REVIVE_H)
whose report counters (stored matches, answered requests by region, platform req,
ladder pages) have not moved for 3 h, or with no report line for 3 h, is restarted
(10-13 Nov: 74 h of failed TLS handshakes in one process; a restart fixed it). Not
04-07 UTC, not while `meiolol curves` runs, at most one per 24 h (REVIVE_GAP_H), and
never again on a crawler its last restart started that has had no answer since: that
needs a person, and health says so until someone restarts it. Outcomes in
data/crawl-revive.log (restarts, and each held reason once: why, since when, the
commonest recent warning), a line in crawl.log before the restart, and why-stopped.sh
names the caller (`systemctl --user restart meiolol-crawl < bash bin/crawl-revive.sh <
bash bin/health-loop.sh`). health-loop.sh re-execs itself when a deploy replaces it.

## Logs for afterwards

- A crawler stop: `meiolol-crawl.service stopped: RESULT, CODE STATUS; by ...` in
  crawl.log and the user journal (deploy/why-stopped.sh, its ExecStopPost). "by" is the
  systemctl caller with its parents and ssh client (admin page, box.sh, a deploy), or
  "no systemctl caller" for a signal from outside systemd (kill, OOM: `journalctl -k`)
- A backup mirror run that fails: a dated `backup mirror: FAILED (exit N) at STEP` line
  after the failing command's output (data/backup-mirror.log on the box, mirror.log in
  ~/.cache/meiolol-watch on the Mac). The forgotten list is tried 3 times a minute
  apart: the box's `forget --export` meets SQLite busy beside a writer

### Complete form quarantine

After 3 unclean crawler runs in a row (crash, kill, OOM; none closed or up 30 min) a
start moves the whole spool to data/complete/spool/quarantine/<kind>.<n>.<unix time>
(riot/complete.zig): documents not yet in a day file, kept for a look. To replay them:
stop the crawler, `mv` each back to data/complete/spool/<kind>.<n> (the time suffix
off), start it. If the crawler crashes again within minutes, one of them is poison:
move them back to quarantine and open an issue with crawl.log. Delete the files once
replayed or given up. Erasure reaches them meanwhile (the daily scrub drops records
naming a forgotten player, below).

### Complete form damaged file

An open day file whose frame fails its crc with whole frames after it (a disk error; a
crash only tears the tail) is renamed data/complete/<day>.<kind>.cfd.damaged-<unix time>
(riot/complete.zig) and its day goes on in a fresh `.part`. It holds documents the day's
sealed file lacks, is neither mirrored to Megatron nor scrubbed. `meiolol complete
FILE` reads its frames before the damage. Look within the month (erasure): keep
what you need elsewhere, then delete it.

### Complete form mirror gap

The Megatron run (deploy/backup-mirror.sh) refuses to mirror day files while C01 holds
none and the copy some, or over 12 fewer than the copy (a fresh disk, a restore from
elsewhere), and deletes at most 12 a run: the unit fails and health says so. It never
clears by itself. If C01's set is right (files lost there on purpose, or restored from
the copy): list what the copy holds beyond it (`comm -13` of the two `ls` lists in
data/complete and /srv/megatron-backups/meiolol/backups/complete), delete those from the
copy by hand, then `systemctl --user start meiolol-megatron-mirror`. If C01 lost them by
mistake, copy them back from the mirror (`meiolol restore` does on a rebuild).
