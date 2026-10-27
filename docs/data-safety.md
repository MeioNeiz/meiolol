# Data safety

Disk headroom, backups, health alerts and GDPR erasure for the data on the box. Jacob's
rules: back up tables and compact timelines, not raw JSON (raw goes to the raw archive);
erasure blanks identity and keeps match rows; alerts by `wz notify` on the Mac plus ntfy
pushes from the box.

## Disk

- Box: one 150 GB boot volume (docs/hosting.md), backups on the same disk until mirrored
  (`MEIOLOL_BACKUPS` in host.env). Kept data grows ~1.6 GB/day at the full rate; raw
  JSON leaves through the raw archive, and under 10 GB free the valve drops unarchived
  raw (Raw archive). More storage: docs/plan/ops.md "Storage and hosts"
- Off-host: backups mirrored to Megatron outside C01's disk image, the Mac and the
  gpu-box (Backups); raw on the gpu-box's archive partition
- The gpu-box keeps its pre-cloud data and backup in /mnt/d/meiolol-backups
  (restore-tested) as an old restore point. Its disks: docs/compute.md

## Backups

`meiolol backup` (src/backup.zig), daily at ~04:00 UTC from the `meiolol-backup` service
(deploy/backup-loop.sh), into $MEIOLOL_BACKUPS (host.env). It never runs migrations:
under the write lock they starve the crawler on a slow host.

- `state/state-YYYY-MM-DD.db`: match_queue, timeline_queue, champions, forgotten. 7
  daily + the newest of 4 weeks. Not players or ladder_pages:
  crawl state, ~3 GB at ~9M players, re-seeded from the ladders within a day of a
  restore, which then rescans everyone's match ids
- `segments/NNNNNN.db`: matches, participants and bans of matches stored since the last
  segment (by matches rowid), and compact timelines likewise (timelines rowid), and
  draft rows (drafts id; the first segment after an older one copies them all), and
  rank_history rows by day (whole days up to yesterday: a day's rows change until it
  ends; the first segment after an older one copies them all), and participant_gold:
  gold10/14/15 of the participants of its timelines' matches. Those columns are the only
  late update of a backed-up row (writer.storeTimeline sets them when the timeline comes,
  minutes to days after the match's segment, in the same transaction as the timeline);
  restore applies each file's after its participants. Tier and division are set when the
  match is stored; a re-stored match or re-extracted timeline takes a new rowid and goes
  in the next segment; forget is re-applied on restore; `rebuild`, `rekey` and
  crawl.rebuildGold rewrite rows, so `--full` after them. Segments are append-only
  and never rotated. 24 months on, `sweepAged` (each backup, each mirror tend) blanks the
  PUUIDs of matches over 730 days old and deletes the rank history of players whose
  newest row is, across every segment, as the crawler does live. `draft_backfill`
  is not backed up: a restore from backups taken before `meiolol draft-backfill`
  finished lacks the draft rows of matches it had not reached
- `timeline.digests` is not backed up: a restore leaves it empty and `meiolol
  digest` (the web loop's, each round) remakes it from the timelines; until then readers
  take the full timelines, with the same outputs
- `mastery/NNNNNN.db`: mastery rows fetched since the last one, by fetched_at
  up to 300 s before the backup (table mastery_range: after_s, to_s, full, base_at), and
  weekly (and on `--full`) a base: the whole table, after_s 0. Restore loads the newest
  base and the files after it, so each player's newest fetch wins. Not in the state
  snapshots: the table (~3.4 GB at 3M rows, ~0.8M fetched a day) would be 11 copies a
  mirror
- Mastery retention (Jacob: keep the deltas as history). Only files before a
  mirror's newest base go, so no file holding a player's newest row ever does (that row
  is in the base or after it). Before it, bases written beside the deltas go at once
  (their rows are in the deltas) and the rest by their window's age: the gpu-box after
  730 days (privacy.md's cap for mastery), the Mac after 32 (backup-mirror.sh writes
  DIR/mastery-keep-days). The box deletes none by age: a mastery file leaves it once
  both mirrors acked it, never its newest. `forget` scrubs every kept file on all three.
  The admin Disk tile shows the gpu-box's mastery history size (backups/acks/NAME.mastery,
  sent after each mirror round). Restoring an older `--state` still takes the newest
  mastery (crawl data, refetched monthly anyway)
- Each file is plain SQLite, written as *.tmp inside one read transaction (consistent
  while the crawler writes) and renamed when complete. Not raw JSON: raw.db is a 30-day
  buffer and the tables hold what it gives
- After `meiolol rebuild` or `rekey` (they rewrite stored rows) run `meiolol backup
  --full`: one segment with everything, replacing the others
- Mirrors, deploy/backup-mirror.sh: the Mac into `~/Backups/meiolol` (from
  deploy/mac-watch.sh, every ~20 h while it is awake; meiolol for the mirror in
  ~/.cache/meiolol-watch/bin, built by `deploy/box.sh watch install`) and the gpu-box
  into /mnt/wsl/archive/meiolol-backups (systemd user timer meiolol-backup-mirror,
  hourly, only while the archive partition is mounted; installed by `deploy/gpu-box.sh
  install`; key ~/.ssh/meiolol_backup, alias meiolol-backup, forced command
  deploy/backup-serve.sh on the box). Both 700: tables hold real PUUIDs. Never in git.
  The partition's root is root's: once, on the gpu-box, `sudo install -d -o jmu -g jmu
  -m 700 /mnt/wsl/archive/meiolol-backups` (until then each hourly run fails at mkdir).
  Megatron, from C01 itself: /srv/megatron-backups/meiolol/backups (timer
  meiolol-megatron-mirror, hourly, enabled by `deploy/box.sh backup start`; HOST local,
  no ssh; log data/backup-mirror.log). Its own fstab mount of the share with `nobrl`:
  on /srv/megatron SQLite's locks fail ("database is locked"), and the disk image's
  mount stays as it is. Same NAS as the live data: it covers a damaged image or a
  mistake, the Mac covers losing the house
- A mirror fetches each file the box lists that is new or changed there (a scrub),
  checks size and SHA-256 and acks it (backups/acks/<mirror>.tsv on the box: file, sum,
  time). After each backup the box deletes files some mirror acked at their current sum,
  except its newest state snapshot, segment and mastery file (the next ones start where
  they end); mastery files only once both mirrors acked them. So the box holds ~3 files
  plus whatever the mirrors have not fetched yet
- backup-loop.sh re-execs the deployed script after each day's sleep: bash keeps the
  loop it parsed, and deploys don't restart it. Each day's backup.log has a `backup
  prune:` line; none means the prune didn't run
- Mirrors keep every segment (the box may hold only the newest) and rotate state (7
  daily + 4 weekly) and mastery files themselves (`meiolol backup --mirror DIR
  --forgotten FILE`). A `--full` segment on the box leaves older ones on the mirrors:
  restore starts at the newest segment that copies from the beginning, so they are
  ignored
- Not compressed (zstd -3 would take a segment 1.57 GB to 1.29 (18%),
  a state snapshot 3.65 to 2.69 (26%; -19 29%)). Compressed mirror files would need
  unpacking for every scrub and restore; open, for when segments (~1.6 GB a day, kept)
  outgrow a mirror

Covers: the box's disk or VM lost, a bad migration or DELETE (state up to 4 weeks back).
Not covered: losing the box, the PC and the Mac together (nothing off-site yet;
Hetzner Storage Box proposed, Jacob's call). The archive partition holds years of
backups at today's rate (~1.7 GB/day of segments).

A restore from the Mac mirror takes ~12-17 min.

### Restore

1. `bin/meiolol restore --from backups --data data.restored` (refuses a
   directory that already holds a database; `--state FILE` for an older snapshot)
2. `bin/meiolol status --exact --data data.restored`: compare with what you expect
   (without --exact some counts are estimates)
3. Stop the crawler and loops, `mv data data.broken && mv data.restored data`, copy back
   anything outside the databases (daily/, export/, site/; not partials/, which the next
   views write rebuilds from the restored tables), start again

Raw tables, players and ladder_pages come back empty; the crawler refills them. Restore
re-applies `forgotten`.

Restore test, quarterly (last row by row 18 Oct 2026): back up the live data, restore
it into another directory, then compare. Counts: `meiolol status --exact` on both,
every count equal except raw.raw_docs and raw.timeline_docs (empty by design). Rows:
digest every column per key of each table on both at the backup point
(data/team/2026-10-18-waste/restore-digest.sh, restore-compare.sh); participants differ
only in matches whose timeline came after the backup point.

### Logins backup

The web server's accounts.db (logins: emails or usernames, argon2id password hashes,
roles, session, desktop app and invite hashes; docs/plan/accounts.md) to the gpu-box
every 6 h: meiolol-accounts-pull.timer runs deploy/accounts-pull.sh, which asks host
meiolol-accounts (gpu-box key ~/.ssh/meiolol_accounts; on jomify user meiolol's
authorized_keys, forced command `sudo -n /usr/local/bin/meiolol-accounts-send`, one line
in /etc/sudoers.d/meiolol-accounts-send). That script (deploy/accounts-send.sh,
installed by `deploy/jomify.sh install accounts-send`) runs `meiolol account backup` as
meiolol-api: VACUUM INTO, so the copy is consistent while the API runs. The pull checks
the SQLite header and opens a copy (an empty one fails: the owner always exists), then
keeps /mnt/wsl/archive/meiolol-accounts/accounts-DATE.db (mode 600; the directory made
once as root, since the partition's top is root's: `wsl.exe -u root -e install -d -m 700
-o jmu -g jmu /mnt/wsl/archive/meiolol-accounts`), the newest 14 dates (privacy page: a
deleted login leaves the backups within 14 days). Log ~/ml/accounts-pull.log on the
gpu-box; each archive pull reports its state to the box for Health alerts. api.db (Your
games' cache, refetchable) is not backed up.

Restore: `ssh gpu-box`, pick a file; on jomify `sudo systemctl stop meiolol-api`, copy
it to /var/lib/meiolol-api/accounts.db (owner meiolol-api, mode 600), delete
accounts.db-wal and -shm there, `sudo systemctl start meiolol-api`. Sessions in the
copy still work; logins made since are gone (remake with `meiolol account`).

## Desktop signing keys

The desktop app trusts two Ed25519 public keys built into it (src/desktop/sign.zig).
Secrets: vault meiolol/desktop (DESKTOP_RELEASE_KEY, DESKTOP_DATA_KEY; source file
~/.config/meiolol/desktop-keys.env, mode 600), and the data key also on the box as
ml/meiolol/desktop-data.key (mode 600, not in the backups: restore it from vault onto a
new box). The release key never goes to a server. Lost or leaked: make a new pair, put
its public half in sign.zig, release, and every installed app needs the zip once more
(it rejects the new key). `meiolol desktop-sign`
refuses any key whose public half the app doesn't ship.

## Health alerts

deploy/health.sh runs on the box and prints one line per problem:

| Check | Problem when |
|---|---|
| crawler | unit `meiolol-crawl` not active; "Riot rejected the key" if crawl.log ends in KEY REJECTED |
| crawler silent | last per-minute report older than 15 min |
| no new matches | report's per-region match counters unchanged for 2h (STALL_H) |
| site | unit `meiolol-web` not active, or last upload in web.log older than 26h |
| disk | / at 80% |
| backup | unit `meiolol-backup` not active, or newest state snapshot older than 26h |
| gpu-box | no raw archive ack for 12h (ACK_H): PC off, asleep or WSL down; first export never acked; one export unacked for 12h while others are acked (see archive-pull.log on the gpu-box) |
| gpu-box disks | C: (holds the WSL disk) or the WSL disk or the archive partition at 85%, or the partition not attached; reported by each archive pull |
| gpu-box logins backup | the last accounts pull failed, its timer is not running, or the newest copy is over 3 days old; reported by each archive pull |
| raw held | free disk above the raw valve under 3 days of raw (bytes sent to the gpu-box over the last 24 h, data/archive-sent.log): what an outage of the gpu-box can last before the valve drops unarchived raw; exports waiting on the box shown apart |
| gpu-box archive | last pull reported a failure (data/gpu-box.pull, written by archive-serve.sh report): cause and since when, pushed once per failure |
| raw valve | the disk valve dropped raw the archive never got in the last 24 h (raw-export --status drops_24h, data/raw-dropped.log) |
| backup mirrors | backups not mirrored for 26 h, or a mirror silent for 48 h (backup-serve.sh status) |

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
| timeline.digests | nothing: cut from the compact timelines, slots 1-10 only (test in src/digests.zig) |
| drafts | nothing: no PUUID, Riot ID or match id, only platform, patch, day, median rank, result, length in minutes, champions, roles and bans, so no row can be found by player (see below) |
| forgotten | PUUID and date added: the suppression list |
| Daily Draft (daily/used.txt, puzzles) | nothing: match ids and anonymous puzzles only |
| views partials (data/partials on the box) | their PUUID hash (Wyhash, 128 bits) blanked in every day file and their mastery entry dropped, at once under the directory's lock (a views write running finishes first); each views write also blanks every hash on `forgotten`, and drops keys from days past 24 months. Never backed up |
| backup files | `--backups DIR` scrubs every state and segment file on the box at once (deploy/backup-loop.sh) |
| backup mirrors (Mac, gpu-box) | each mirror run fetches the box's forgotten list and `meiolol backup --mirror` scrubs the PUUIDs new to it from every file it holds, including segments the box has pruned (applied list: forgotten-applied.txt in the mirror) |
| raw archive (gpu-box) | ingest leaves out documents naming a forgotten PUUID; each pull runs `meiolol-lab archive-forget` for PUUIDs new on the box's list, which drops every archived summary, timeline and mastery line naming them (hashed with the salt) |
| raw exports (box, data/archive-out) | short-lived: deleted on ack; an export holds what raw.db held when it was made |
| Your games (api.db on the web server) | `forget --data /var/lib/meiolol-api` there: `api.cache.forget` deletes the player, their Riot ID in every cached match (`match_names` by PUUID hash) and adds them to `blocked` |
| Logins (accounts.db on the web server) | `sudo -u meiolol-api meiolol account delete NAME --data /var/lib/meiolol-api` there: the account, its sessions, desktop app sign-ins and reset invites (privacy page "Accounts") |
| analysis snapshots (Mac, gpu-box) | re-erased when made, hashed, deleted when replaced (Analysis snapshots, below) |

- Suppression: the crawler skips PUUIDs in `forgotten` on ladder and mastery and stores
  their participant rows with a blank PUUID (meiolol-de, crawl.zig, via
  `forget.isForgotten`). Plain PUUIDs, not hashes: a key switch must translate the
  list (docs/key-switch.md)
- Restores re-apply `forgotten` from the newest state snapshot, so an older segment
  cannot bring a player back
- Box and Your games service swap complete lists daily (deploy/backup-loop.sh, before
  the backup): the box pulls the service's forgotten.txt and runs `forget --list ...
  --backups ...`, then pushes its own list (`forget --export`) as box-forgotten.txt,
  which the service blocks. So an objection honoured on the site reaches the box and its
  backups within a day. PUUIDs already in `forgotten` are skipped, so reruns stay cheap.
  `forget` opens whichever of meiolol.db and api.db the data directory holds
- Riot erasure lists: copy the list (PUUIDs or Riot IDs, one per line) to the box, then
  `deploy/box.sh run forget --list FILE --backups backups`. A Riot ID
  that no longer resolves (renamed or deleted) is counted and exits 1: get its PUUID
- Not wiped: freed ext4 blocks inside the WSL image and on D: (accepted; files are
  rewritten, not just unlinked)
- Draft rows (`drafts`, kept forever, docs/architecture.md Storage) hold no identifier:
  not the match id either, since the Riot API turns one back into the ten players, and
  the game's day rather than its start time. Someone who already knows a game (its
  champions and day) could pick out its row, but it tells them nothing beyond what they
  knew. Game length in whole minutes adds no real risk: picks, bans and day already
  single out a game almost always, and the length is one more thing that game's own
  players can already see. With nothing to look a person up by, forget does not touch
  them; the transient `draft_backfill` list holds match ids and goes once the backfill
  has run
- Retention sweeps (players not seen for 30 days, PUUIDs blanked after 24 months) live in
  the crawler's hourly prune (meiolol-de). Public wording: docs/legal/privacy.md

### Analysis snapshots

Modelling copies of the box data (meiolol-lab; docs/model.md "Shared protocol"):

- Made on the gpu-box (deploy/snapshot.sh, daily from launchd on the Mac,
  runs deploy/snapshot-gpu.sh there): `meiolol restore` from its backup mirror (the
  mirror's lock held), plus what backups leave out, from the box over the gpu-box's
  backup key (backup-serve.sh snapshot-extra, nice + ionice, ~5 GB of temp files and
  4.2 GB sent): every database's schema and row counts, players, ladder_pages, ranks,
  draft_backfill, raw summaries and the small raw tables, rank_history after the
  mirror's last day, and participants' columns updated after a backup copies them
  (gold10/14/15, tier, division, a blanked PUUID). Put together in the box's schema in
  a 700 directory on /mnt/wsl/lab, checked against the box's counts, then `meiolol-lab
  anonymise SRC DST` (src/lab/anonymise.zig): PUUIDs and match ids replaced by salted
  hashes (HMAC-SHA256), Riot IDs, summoner ids and names blanked, profile icons zeroed,
  raw timelines and the forgotten list left out (it refuses a snapshot still holding a
  forgotten player's rows). Match ids are hashed too: a real one gives back the ten
  players through the API. The real-id copy is deleted once the anonymised copy passes
  its checks, or on a failed check; a build that dies otherwise keeps it so the next
  build resumes from its last done stage (a disk reset can hang the PC mid-build:
  docs/compute.md "Disk resets"), at most a day from the build's start: the
  next build, or backup-mirror.sh hourly, deletes it after. The result is
  checked (row counts against the source, fewer only in puuidKey tables, whose keys
  without a PUUID are left out; every PUUID hashed; a real match id absent), then
  split, legendaries, seat stats, pack and mastery-pre, in ~/ml/snaps/STAMP. The Mac
  then rsyncs it over the LAN (data/snap-STAMP) for Mac lab runs. Tables come from the
  mirror as of its last daily backup and the rest from the box at build time: hours
  apart. A build takes ~80 min
- The salt is ~/.config/meiolol/snap-salt on the Mac and the gpu-box: never in git,
  never on the box.
  Without it a hash can't be linked back to a PUUID; with it only by hashing candidates
- Disposable: a snapshot is deleted from the Mac and the gpu-box when a newer one
  replaces it (snapshot.sh prune, after each fetch), so an erasure reaches analysis
  copies within a day, two when a resumed build used a day-old restore. Open: prune
  keeps docs/golden.tsv's snapshot (snap-20261012T2055Z) for golden.sh, which this rule
  doesn't allow for long. Not in git, not published
- mastery_pre.tsv and mastery_pre_pool.tsv (`meiolol-lab mastery-pre SNAP ARCHIVE`):
  pre-game mastery joined from the raw archive, keyed by hashed match id and slot only,
  written inside the snapshot dir, so it stays within the snapshot's rules and goes when
  the snapshot does
- seat_stats.tsv, comp_stats.tsv (`meiolol-lab seat-stats`, `comp-stats`): per-seat
  end-of-game numbers from the snapshot's raw.db and the raw archive's summaries, keyed by
  hashed match id and slot, no player ids; same rules

### Raw archive

Every raw document (match summaries, timelines, mastery snapshots) kept on the gpu-box,
pseudonymised (Jacob: keep raw until we understand it, and until player ids would be
blanked anyway). Box side src/archive.zig (`meiolol raw-export`); gpu-box side
src/lab/archive.zig, deploy/archive-pull.sh, systemd user timer meiolol-archive-pull
(hourly, skipped while League is open).

- Box: an export writes what was fetched since the last one, at most 2 hours of it
  from its first document (~1 GB), to data/archive-out/raw-FROM-TO.db, as stored (real
  ids: the salt never comes to the box). The gpu-box's key in ~/.ssh/authorized_keys
  may only run deploy/archive-serve.sh (export, list, send, got, ack, forgotten,
  status). Exports and their packs run one at a time (data/.archive-export.lock): an
  ssh dropped on the home link leaves its export running on the box, and a retry waits
  for it, then exports the next window
- Packed for the trip: right after each export, archive-serve.sh runs `raw-export
  --pack NAME --level 9` (nice): NAME.zst, a rawpack stream (src/store/rawpack.zig: the
  same rows, bodies gunzipped, counts and a hash at the end) through zstd -9 -T1. It is
  read back whole (zstd's checksum, rawpack's hash, counts against the export) and
  synced before NAME goes. list, send and got then use NAME.zst: the sha256 checked is
  of the bytes sent. A failed pack leaves NAME to go as before (data/archive-pack.err);
  the gpu-box tells the forms apart by magic bytes. Why a stream: zstd on an export's
  SQLite file saves 3% (bodies are gzip already); on the stream -3/-6/-9 save 15/30/39%
  for 12/40/60 s of one core per hour of exports, and a trained dictionary gains
  nothing.
  data/archive-sent.log: time, name, export bytes (raw held, for health.sh), bytes sent
- gpu-box, per export until caught up (stopping when League opens): fetch to the archive
  partition (ARCHIVE/incoming), check the size, sha256 and fsync it, then `got NAME
  SHA256`: the box deletes its file only if the sha256 matches its own, and records the
  export as received (raw.archive_received; the next export won't redo its window).
  From then the gpu-box's copy is the only one of its timelines. Then `meiolol-lab
  archive` (anonymise.rewriteMatch: PUUIDs
  and match ids salted-hashed as in snapshots, so the ids match; Riot IDs, summoner ids
  and names blanked; profile icons 0), zstd -15 --long, test, then ack. Layout:
  ARCHIVE/YYYY-MM-DD/{summaries,timelines}-NAME.jsonl.zst, mastery-NAME.tsv.zst (hashed
  PUUID, platform, fetched_at, champions, compact blob in hex), ARCHIVE/index.tsv.
  An export whose archive fails stays in incoming and no new one is asked for until it
  is archived: the rest waits in raw.db, never as a second copy
- The box drops raw documents only once acked and 2 days old (`--prune --keep-days 2`,
  which archive-serve.sh starts detached after each `--ack NAME`); unacked ones stay
  whatever their age: once an export exists, the crawler's own raw prune
  (`--raw-timeline-days`, `--raw-match-days`) also stops at the start of the oldest
  unacked export. A stopped pull shows in Health alerts: gpu-box (no ack for 12h) and
  raw held (days of raw above the valve)
- raw.db is auto_vacuum=INCREMENTAL, so each prune's archive.returnFree hands freed
  pages back to the disk. A new box's raw.db needs the same once: `PRAGMA
  auto_vacuum=INCREMENTAL; VACUUM` (~2x live size free; ~25 min at 40 GB, a 10 GB WAL).
  Stop the crawler first (its 60 s busy timeout) and hold data/.archive-prune.lock; Your
  games lookups fail meanwhile (they go through the crawler's proxy)
- ssh sessions from home kept open for minutes get corrupted packets (sshd: "message
  authentication code incorrect"), so the ack only marks and deletes (seconds) and the
  prune runs detached, one at a time (data/archive-prune.log); every box command the
  pull makes is retried 3 times and is safe to repeat. A failed ack is retried next
  round: the export stays listed, and is in index.tsv, so it is acked without a new
  fetch or archive
- Raw timelines (most of the bytes) are the exception: once an export file
  holds them (file and directory fsynced first) they leave raw.db at once, matched on
  id and fetch time, failed parses kept; the export file is their only box copy until
  the gpu-box has it. Raw summaries stay until acked and 2 days old
  (`learn`'s damage split and `meiolol rebuild` read them)
- Valve (`crawl --raw-valve-free-gb N`, 0 off): every 5 min the crawler's writer reads
  the data disk's free space (`df`); under N GB it drops the oldest unacked export not
  yet received (file deleted, row marked acked so pruning moves past it), or with no
  export file left the oldest 2,000 raw timelines in raw.db (~180 MB of pages for new
  raw to reuse). That raw is never archived: uptime of the crawler, site builds and
  backups over a complete archive (Jacob). Each drop: a warning in
  crawl.log, a row in raw.archive_dropped, a line in data/raw-dropped.log (unix time,
  kind export|raw, name, from_s, to_s, documents, bytes, free MB; tab-separated), and
  `raw-export --status` adds `since_drop_s` (null: never) and `drops_24h`; its
  `since_ack_s` counts only the gpu-box's acks
- An export holds no lock the crawler waits on: each table is copied in one statement
  that reads its own snapshot. Windows go by fetched_at, which the crawler's writer sets
  when it begins the transaction that stores the document, and an export stops 300 s
  short of now, so a document still being written goes in the next one
- Crash safety: an export is written as raw-FROM-TO.db.tmp, recorded in
  raw.archive_exports, then renamed. The next export deletes leftover .tmp files and
  the newest record whose file never got its name and was never received (that window
  is exported again). An ack of a name with no record deletes the file; a failed ack
  is logged and the pull carries on with the rest
- The crawler treats a body that is not a whole document (empty, cut short, not a
  match) as a failed fetch, tried again later, never kept raw (crawl.zig wholeDoc), and
  the riot client errors on a body shorter than its Content-Length (~1 in 150k bodies
  comes back cut short as a 200)
- A document that is not a match (empty, unparseable) is left out and counted
  ("unreadable left out" in the pull log), so one bad document can't hold up the
  archive step
- 24 months: `meiolol-lab archive-age` (every pull) blanks every hashed PUUID in days
  older than 730 and deletes their mastery files, as the crawler blanks participants
- ~6.6 GB/day (summaries 4.3 KB, timelines 45 KB each at -15). ARCHIVE is
  /mnt/wsl/archive/meiolol-raw, on the 1 TB partition: full around March 2027 at this
  rate

### Key switch

Moving to the production key changes every PUUID: what `meiolol rekey` does, its
runbook, and the two wrong-key windows in the data: docs/key-switch.md.
