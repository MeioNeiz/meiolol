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
- Off-host backups: mirrored to the Mac and the gpu-box since 2026-10-17 (Backups)
- The gpu-box (before the move) keeps its data and the 2026-10-11 backup in
  /mnt/d/meiolol-backups (restore-tested) as the restore point. Its WSL disk image lives
  on C: (~252 GB free); its 2 TB NVMe has 673 GB unallocated, if it becomes the bulk store

## Backups

`meiolol backup` (src/backup.zig), daily at ~04:00 UTC from the `meiolol-backup` service
(deploy/backup-loop.sh), into $MEIOLOL_BACKUPS (host.env). It never runs migrations:
under the write lock they starve the crawler on a slow host.

- `state/state-YYYY-MM-DD.db`: match_queue, timeline_queue, champions, forgotten. 7
  daily + the newest of 4 weeks. Not players or ladder_pages (2026-10-11):
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
  crawl.rebuildGold rewrite rows, so `--full` after them. Before 18 Oct (segments up to
  000009) a restore lost the gold of timelines that came after their match's segment;
  the first segment with the table carries every timeline's. Segments are append-only
  and never rotated. 24 months on, `sweepAged` (each backup, each mirror tend) blanks the
  PUUIDs of matches over 730 days old and deletes the rank history of players whose
  newest row is, across every segment, as the crawler does live. `draft_backfill`
  is not backed up: a restore from backups taken before `meiolol draft-backfill`
  finished lacks the draft rows of matches it had not reached
- `timeline.digests` (18 Oct) is not backed up: a restore leaves it empty and `meiolol
  digest` (the web loop's, each round) remakes it from the timelines; until then readers
  take the full timelines, with the same outputs
- `mastery/NNNNNN.db` (18 Oct): mastery rows fetched since the last one, by fetched_at
  up to 300 s before the backup (table mastery_range: after_s, to_s, full, base_at), and
  weekly (and on `--full`) a base: the whole table, after_s 0. Restore loads the newest
  base and the files after it, so each player's newest fetch wins. Before, every state
  snapshot held the whole table (3.4 GB of 3.6 at 3.1M rows on 17 Oct, ~0.8M fetched a
  day): 11 copies a mirror, ~40 GB and growing with the table
- Mastery retention (Jacob, 18 Oct: keep the deltas as history). Only files before a
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
- Mirrors (2026-10-17), deploy/backup-mirror.sh: the Mac into `~/Backups/meiolol` (from
  deploy/mac-watch.sh, every ~20 h while it is awake; meiolol for the mirror in
  ~/.cache/meiolol-watch/bin, built by `deploy/box.sh watch install`) and the gpu-box
  into /mnt/wsl/archive/meiolol-backups (systemd user timer meiolol-backup-mirror,
  hourly, only while the archive partition is mounted; installed by `deploy/gpu-box.sh
  install`; key ~/.ssh/meiolol_backup, alias meiolol-backup, forced command
  deploy/backup-serve.sh on the box). Both 700: tables hold real PUUIDs. Never in git.
  The partition's root is root's: once, on the gpu-box, `sudo install -d -o jmu -g jmu
  -m 700 /mnt/wsl/archive/meiolol-backups` (until then each hourly run fails at mkdir)
- First mirror 2026-10-17: the Mac fetched 15 files (19.5 GB) in ~9 min; restore from
  it (12 min on the Mac) gave 9 files, 784,396 matches, 695,481 timelines, 3,136,005
  mastery, match_queue 1,417, timeline_queue 57, the sums of the files; the box's prune
  then freed 14.5 GB (kept state-2026-10-17 and segment 000008, 4.9 GB)
- A mirror fetches each file the box lists that is new or changed there (a scrub),
  checks size and SHA-256 and acks it (backups/acks/MIRROR.tsv on the box: file, sum,
  time). After each backup the box deletes files some mirror acked at their current sum,
  except its newest state snapshot, segment and mastery file (the next ones start where
  they end); mastery files only once both mirrors acked them. So the box holds ~3 files
  plus whatever the mirrors have not fetched yet
- Mirrors keep every segment (the box may hold only the newest) and rotate state (7
  daily + 4 weekly) and mastery files themselves (`meiolol backup --mirror DIR
  --forgotten FILE`). A `--full` segment on the box leaves older ones on the mirrors:
  restore starts at the newest segment that copies from the beginning, so they are
  ignored
- Not compressed (measured 18 Oct, zstd -3 on the Mac): a segment 1.57 GB to 1.29 (18%),
  a state snapshot 3.65 to 2.69 (26%; -19 29%). Compressed mirror files would need
  unpacking for every scrub and restore; open, for when segments (~1.6 GB a day, kept)
  outgrow a mirror

Covers: the box's disk or VM lost, a bad migration or DELETE (state up to 4 weeks back).
Not covered: losing the box, the PC and the Mac together (nothing off-site yet;
Hetzner Storage Box proposed, Jacob's call). The archive partition holds years of
backups at today's rate (~1.7 GB/day of segments).

Measured 2026-10-11 (8,117 matches, 1.13M players): state 146 MB, segment 23 MB, backup
1 s, restore 2.6 s.

### Restore

1. `bin/meiolol restore --from backups --data data.restored` (refuses a
   directory that already holds a database; `--state FILE` for an older snapshot)
2. `bin/meiolol status --exact --data data.restored`: compare with what you expect
   (without --exact some counts are estimates)
3. Stop the crawler and loops, `mv data data.broken && mv data.restored data`, copy back
   anything outside the databases (daily/, export/, site/; not partials/, which the next
   views write rebuilds from the restored tables), start again

Raw tables, players and ladder_pages come back empty; the crawler refills them. Restore re-applies `forgotten`.

Restore test, 2026-10-11 on the box: backup of the live data into backups/test, restore
into backups/restore-test, `meiolol status` on both: every count equal (players
1,134,448, matches 8,117, participants 81,170, bans 78,553, timelines 728, queues,
mastery, champions) except raw.raw_docs and raw.timeline_docs (0, by design). Repeat on
the first D: backup, then quarterly.

Row-by-row rehearsal, 18 Oct (after participant_gold, e9092a5): a backup on the box
(segment 000010: matches to rowid 976,546, timelines to 844,042, drafts to 885,378,
rank days to 20743, mastery to 1792318023), the live tables digested at that point
straight after (sha3 of every column per key: data/team/2026-10-18-waste/
restore-digest.sh, restore-compare.sh), the Mac mirror restored (1,003 s) and digested
alike. Every row the same in matches (960,568), bans, timelines (844,042), drafts
(885,378), rank_history (6,319,758 players' histories) and mastery (3,841,620);
participants differed in 49 matches whose timeline came after the backup point (as
expected) and in 98 more: the 11 Oct wrong-key window, blanked by hand on 14 Oct after
segment 000002 had copied it (Key switch, below). 000002 on both mirrors blanked the
same way on 18 Oct (980 PUUIDs); a second restore then had no unexplained difference in
any of the seven tables (participants: 49 exempt, the rest the same).

## Desktop signing keys

The desktop app trusts two Ed25519 public keys built into it (src/desktop/sign.zig).
Secrets: vault meiolol/desktop (DESKTOP_RELEASE_KEY, DESKTOP_DATA_KEY; source file
~/.config/meiolol/desktop-keys.env, mode 600), and the data key also on the box as
ml/meiolol/desktop-data.key (mode 600, not in the backups: restore it from vault onto a
new box). The release key never goes to a server. Lost or leaked: make a new pair, put
its public half in sign.zig, release, and every installed app needs the zip once more
(it rejects the new key). Made 21 Oct by a one-off generator; `meiolol desktop-sign`
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
| analysis snapshots (Mac, gpu-box) | re-erased when made, hashed, deleted when replaced (Analysis snapshots, below) |

- Suppression: the crawler skips PUUIDs in `forgotten` on ladder and mastery and stores
  their participant rows with a blank PUUID (meiolol-de, crawl.zig, via
  `forget.isForgotten`). Plain PUUIDs, not hashes: a key switch must translate the
  list (Key switch, below)
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
  knew. Game length in whole minutes (Jacob, 2026-10-11) adds no real risk: picks, bans
  and day already single out a game almost always, and the length is one more thing
  that game's own players can already see. With nothing to look a person up by, forget does not touch them; the transient
  `draft_backfill` list holds match ids and goes once the backfill has run
- Retention sweeps (players not seen for 30 days, PUUIDs blanked after 24 months) live in
  the crawler's hourly prune (meiolol-de). Public wording: docs/legal/privacy.md

### Analysis snapshots

Modelling copies of the box data (meiolol-lab; docs/model.md "Shared protocol"):

- Made on the gpu-box (18 Oct; deploy/snapshot.sh, weekly from launchd on the Mac,
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
  players through the API. The real-id copy is deleted on any exit; the result is
  checked (row counts against the source, fewer only in puuidKey tables, whose keys
  without a PUUID are left out; every PUUID hashed; a real match id absent), then
  split, legendaries, seat stats, pack and mastery-pre, in ~/ml/snaps/STAMP. The Mac
  then rsyncs it over the LAN (data/snap-STAMP) for Mac lab runs. Before 18 Oct the box
  made a ~23 GB VACUUM INTO, streamed it to the Mac, which anonymised it and rsynced
  ~21 GB to the gpu-box. Tables come from the mirror as of its last daily backup and
  the rest from the box at build time: hours apart. First run, snap-20261018T1007Z (78
  min), against snap-20261017T1320Z built the old way: same schemas bar tables added
  since, every row the same in 5,000 sampled matches (matches, bans, 50,000
  participants with the late gold, timelines) and in drafts, mastery and raw_docs
  samples; rank_history differs only on the old one's last day (updated after it)
- The salt is ~/.config/meiolol/snap-salt on the Mac and the gpu-box: never in git,
  never on the box.
  Without it a hash can't be linked back to a PUUID; with it only by hashing candidates
- Disposable: a snapshot is deleted from the Mac and the gpu-box when a newer one
  replaces it, so an erasure reaches analysis copies within one snapshot cycle. Not in
  git, not published
- mastery_pre.tsv and mastery_pre_pool.tsv (`meiolol-lab mastery-pre SNAP ARCHIVE`):
  pre-game mastery joined from the raw archive, keyed by hashed match id and slot only, written inside the
  snapshot dir, so it stays within the snapshot's rules and goes when the snapshot does
- seat_stats.tsv (`meiolol-lab seat-stats SNAP`): per-seat end-of-game numbers from the
  snapshot's own raw.db, keyed by hashed match id and slot, no player ids; same rules

### Raw archive

Every raw document (match summaries, timelines, mastery snapshots) kept on the gpu-box,
pseudonymised (Jacob, 2026-10-12: keep raw until we understand it, and until player ids
would be blanked anyway). Box side src/archive.zig (`meiolol raw-export`); gpu-box side
src/lab/archive.zig, deploy/archive-pull.sh, systemd user timer meiolol-archive-pull
(hourly, skipped while League is open).

- Box: an export writes what was fetched since the last one, at most 2 hours of it
  from its first document (~1 GB), to data/archive-out/raw-FROM-TO.db, as stored (real
  ids: the salt never comes to the box). The gpu-box's key in ~/.ssh/authorized_keys
  may only run deploy/archive-serve.sh (export, list, send, got, ack, forgotten,
  status)
- Packed for the trip (18 Oct): right after each export, archive-serve.sh runs `raw-export
  --pack NAME --level 9` (nice): NAME.zst, a rawpack stream (src/store/rawpack.zig: the
  same rows, bodies gunzipped, counts and a hash at the end) through zstd -9 -T1. It is
  read back whole (zstd's checksum, rawpack's hash, counts against the export) and
  synced before NAME goes. list, send and got then use NAME.zst: the sha256 checked is
  of the bytes sent. A failed pack leaves NAME to go as before (data/archive-pack.err);
  the gpu-box tells the forms apart by magic bytes. Measured on a real 1 h export (398
  MB, 18 Oct): zstd -3/-6/-9 on the stream 15/30/39% under the gzip bodies, for
  12/40/60 s of one core per hour of exports; a trained dictionary gains nothing on a
  stream (per document: summaries -33%, timelines -5%); crawler calls unchanged. The
  real pack of that export: 240 MB, 83 s CPU; its archive on the gpu-box matched the
  live archive of the same export byte for byte (summaries, timelines, mastery).
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
- Before 18 Oct an export held everything since the last ack and stayed on the box until
  that ack, after the archive: a gpu-box back after a day wrote one file of the whole
  backlog (33 GB on 17 Oct). zstd on an export's SQLite file saves 3% (bodies are gzip
  already), hence the pack
- The salt is on the gpu-box too (~/.config/meiolol/snap-salt, 600), never on the box
  or in git
- The box drops raw documents only once acked and 2 days old (`--prune --keep-days 2`,
  which archive-serve.sh starts detached after each `--ack NAME`); unacked ones stay
  whatever their age: once an export exists, the crawler's own raw prune
  (`--raw-timeline-days`, `--raw-match-days`) also stops at the start of the oldest
  unacked export. A stopped pull shows in Health alerts: gpu-box (no ack for 12h) and
  raw held (days of raw above the valve)
- raw.db is auto_vacuum=INCREMENTAL since 21 Oct (VACUUM with the crawler stopped, 25.5
  min, peak +10 GB temp and a 10 GB WAL: 40.5 GB to 10.3 GB), so each prune's
  archive.returnFree hands freed pages back to the disk. A new box's raw.db needs the
  same once: `PRAGMA auto_vacuum=INCREMENTAL; VACUUM` (needs ~2x live size free). Stop
  the crawler first (its 60 s busy timeout) and hold data/.archive-prune.lock; Your
  games lookups fail meanwhile (they go through the crawler's proxy)
- Acks failed 14-17 Oct ("Connection ... closed by remote host" in the pull log): the
  box's sshd logged "message authentication code incorrect" on each, a packet from home
  corrupted in transit, on ssh sessions kept open minutes by the ack's prune. Now the
  ack only marks and deletes (seconds) and the prune runs detached, one at a time
  (data/archive-prune.log); every box command the pull makes is retried 3 times, and
  is safe to repeat. A failed ack is retried next round: the export stays listed, and
  is in index.tsv, so it is acked without a new fetch or archive
- Raw timelines (most of the bytes) are the exception since 17 Oct: once an export file
  holds them (file and directory fsynced first) they leave raw.db at once, matched on
  id and fetch time, failed parses kept; the export file is their only box copy until
  the gpu-box has it. Before, a pull that ran but failed held every timeline twice
  (raw.db and archive-out, ~12 GB a day). Raw summaries stay until acked and 2 days old
  (`learn`'s damage split and `meiolol rebuild` read them)
- Valve (`crawl --raw-valve-free-gb N`, 0 off): every 5 min the crawler's writer reads
  the data disk's free space (`df`); under N GB it drops the oldest unacked export not
  yet received (file deleted, row marked acked so pruning moves past it), or with no
  export file left the oldest 2,000 raw timelines in raw.db (~180 MB of pages for new
  raw to reuse; raw.db never shrinks). That raw is never archived: uptime of the crawler, site
  builds and backups over a complete archive (Jacob, 17 Oct). Each drop: a warning in
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
  the riot client errors on a body shorter than its Content-Length (17 Oct: ~1 in 150k
  bodies had come back cut short as a 200)
- A document that is not a match (empty, unparseable) is left out and counted
  ("unreadable left out" in the pull log). Before 17 Oct one empty timeline the crawler
  kept (OC1, 15 Oct) failed the whole archive step every hour and held 5 exports (~26
  GB) unacked on the box for 40 h
- 24 months: `meiolol-lab archive-age` (every pull) blanks every hashed PUUID in days
  older than 730 and deletes their mastery files, as the crawler blanks participants
- ~6.6 GB/day at today's rate (first pull, 2026-10-12: summaries 4.3 KB, timelines
  45 KB each at -15). ARCHIVE is /mnt/wsl/archive/meiolol-raw, on the 1 TB
  partition (948 GB free, 2026-10-12): ~5 months at this rate

### Key switch (rekey)

PUUIDs are encrypted per app, so moving to the production key changes every one, and
the erasure lists (`forgotten` on the box, `blocked` in the Your games cache, and the
exchange files made from them) would stop matching: erased players could be crawled
again. Unless Riot links the production app's encryption to the personal app (asked
for in the application, docs/production-key.md), `meiolol rekey` carries each entry
over before clearing crawl state (src/rekey.zig):

- Old PUUID to Riot ID with the old key (account-v1 by-puuid), then Riot ID to new PUUID
  with the new key (by-riot-id). The Riot ID exists only between those two requests:
  never written or logged. The entry keeps its original date
- No account under the old key (404: deleted): the entry is dropped, since no new PUUID
  can ever exist for it
- Everything is translated before anything is written, then the list and the crawl
  state change in one transaction: any failure leaves the old state whole, and running
  again starts afresh. The old key cannot read a new PUUID, so a second run after a
  successful one stops with an error and writes nothing
- If both keys give the same PUUID, encryption is linked: rekey reports it and changes
  nothing. With empty lists it asks about a player instead. So `meiolol rekey --dry-run`
  with both keys answers "did Riot link the apps?" as soon as the production key exists
- Ruled out: keeping a match id and slot per erased player (the new key's match-v5 would
  name the slot's new PUUID) holds more personal data and stops working once Riot drops
  the match; there is no PUUID-to-PUUID endpoint
- Raw documents: rekey deletes every raw summary and raw timeline on the box. They hold
  old PUUIDs and Riot IDs, and once participants are blanked an erasure by new PUUID
  can't find them. With the raw archive in use it first checks that every raw document
  and mastery snapshot is in an acked export, and stops (RawNotArchived, nothing
  written) otherwise, so the archive loses nothing
- Raw archive: the gpu-box's pre-switch days hold hashed old PUUIDs. archive-forget
  hashes the new PUUIDs it is given, so a later erasure can't reach them. Runbook step
  6 blanks them, as archive-age does at 24 months: the matches stay but have no player
  links (Jacob's call: the alternative is keeping links that no erasure can reach)
- Rehearse on a copy with `--fake-api` (no keys; fake account-v1 in src/riot/fake.zig
  maps any crawled PUUID to a made-up Riot ID and back under a second fake app)

Runbook, with RIOT_API_KEY the new key and RIOT_API_KEY_OLD the old one (env or .env on
each host; the old key must still work, so switch before revoking it):

1. Box: stop the crawler and every loop (`deploy/box.sh stop`, then `backup`, `health`
   and `web` with `stop`): no forgotten exchange may run between the two sides' rekeys.
   Then wait 5 minutes (an export leaves the newest 300 s to the next one), and run one
   pull on the gpu-box with League closed (`systemctl --user start
   meiolol-archive-pull`; log ~/ml/archive-pull.log). `deploy/box.sh run raw-export
   --status` should show `unacked 0`
2. Box, each via `deploy/box.sh run`: `backup` (as backup-loop.sh runs it); `rekey
   --dry-run` (expect "N erased players carried over, M accounts gone", or "encryption
   linked": then stop here, nothing to rekey); `rebuild`; `rekey` (if it stops with
   RawNotArchived, repeat the pull in step 1); `backup --full`
3. Web server: stop the Your games service; `meiolol rekey --data /var/lib/meiolol-api`;
   delete the exchange dir's forgotten.txt and box-forgotten.txt (old PUUIDs: the
   service would import the box's stale list); start the service
4. Box: delete data/exchange-forgotten.txt and data/box-forgotten.txt; remove
   RIOT_API_KEY_OLD from .env; start everything. The first exchange swaps the new lists
5. Backups from before the switch hold old-key PUUIDs that a later erasure (by new PUUID)
   cannot find: the pre-switch state snapshots (rotate out within 4 weeks; the new full
   segment replaces the old segments), the Mac mirror (follows) and the gpu-box restore
   point. Deleting them once the first new-key backup is restore-tested is Jacob's call
6. gpu-box, the next UTC day: `~/ml/bin/meiolol-lab archive-age
   /mnt/wsl/archive/meiolol-raw 0` once. It blanks the hashed PUUIDs and deletes the
   mastery files of every archived day before today: all pre-switch days, and the
   switch day's few post-switch hours with them. The first pull after the switch also
   runs archive-forget over the whole archive (the new forgotten list looks all new
   next to forgotten-applied.txt): slow, harmless


Incident 2026-10-13, a key from another app (not a switch): 20:54Z a key from a
different Riot app went into .env and the box; every stored PUUID then gave 400
"Exception decrypting", match discovery stopped (139k to 28k matches/day) and the
crawler stored what that key returned. Fixed 22:35Z by restoring the MEIOLOL app's key
(here, box, vault meiolol/local). Box cleanup (one transaction, crawler stopped): the
1,938 matches fetched 1791924840-1791930898 (unix s) kept, their 19,380 participant
PUUIDs set NULL; 21,817 players (seen_at in the window) and 2,361 mastery rows
(fetched_at in it) deleted; spot check 4/4 window players 400, 4/4 earlier 200. Left:
rank rows keyed by those PUUIDs (orphans); the window's raw summaries and timelines
(wrong-app PUUIDs and Riot IDs) go at ack + 2 days as usual; the raw archive holds them
with hashed wrong-app PUUIDs that an erasure by real PUUID can't reach, so blank those
games' PUUIDs there as runbook step 6 does (open). Guard: crawl start calls mastery for
the player most recently given one and exits 3 (as a rejected key) on a 400, before
writing anything (Crawler.checkKey)

Earlier window, found 14 Oct: 2026-10-11 23:25:50-23:28:45Z, same cause (the 22
match-id 400s at 23:25-23:28). It stored matches rowid 92269-92366 (98, games 3-11 Oct,
all platforms): every one of their 980 participant PUUIDs (833 distinct, in no other
match) gives 400 "Exception decrypting"; 81 players rows (36 ladder, 45 participant)
were first seen then. Matches outside the block give 200, and the block's edges follow
players' seen_at. Effect: the participant mastery pass's ladder-gap batches never
finished, so kr mastery stalled from 13 Oct 19Z (fixed in the crawler, e5aabc2).
Cleanup as above (participant PUUIDs NULL, those players deleted): done 14 Oct 19:57Z,
980 participant PUUIDs, 81 players; the backup segment holding them (000002) only on
18 Oct, on both mirrors, found by the restore rehearsal (Restore). A hand edit of
stored rows needs the same edit in every mirror's segments: `backup --full` would make
a restore right (newest copy wins) but leave the old segments holding the old rows.
Until then the ladder mastery pass, its euw1 list
down to such players, went round them back to back (~60k 400s a day, fixed in the
crawler: the list wraps after the step's nap)
