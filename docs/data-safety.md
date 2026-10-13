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

- `state/state-YYYY-MM-DD.db`: match_queue, timeline_queue, mastery, champions,
  forgotten. 7 daily + the newest of 4 weeks. Not players or ladder_pages (2026-10-11):
  crawl state, ~3 GB at ~9M players, re-seeded from the ladders within a day of a
  restore, which then rescans everyone's match ids
- `segments/NNNNNN.db`: matches, participants and bans of matches stored since the last
  segment (by matches rowid), and compact timelines likewise (timelines rowid), and
  draft rows (drafts id; the first segment after an older one copies them all), and
  rank_history rows by day (whole days up to yesterday: a day's rows change until it
  ends; the first segment after an older one copies them all). Stored
  rows never change, so segments are append-only and never rotated. `draft_backfill`
  is not backed up: a restore from backups taken before `meiolol draft-backfill`
  finished lacks the draft rows of matches it had not reached
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
2. `bin/meiolol status --exact --data data.restored`: compare with what you expect
   (without --exact some counts are estimates)
3. Stop the crawler and loops, `mv data data.broken && mv data.restored data`, copy back
   anything outside the databases (daily/, export/, site/), start again

Raw tables, players and ladder_pages come back empty; the crawler refills them. Restore re-applies `forgotten`.

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
| gpu-box | no raw archive ack for 12h (ACK_H): PC off, asleep or WSL down; first export never acked; one export unacked for 12h while others are acked (see archive-pull.log on the gpu-box) |
| gpu-box disks | C: (holds the WSL disk) or the WSL disk or the archive partition at 85%, or the partition not attached; reported by each archive pull |
| raw held | free disk under twice raw.db + timeline.db + archive-out (raw stays until acked) |

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
| drafts | nothing: no PUUID, Riot ID or match id, only platform, patch, day, median rank, result, length in minutes, champions, roles and bans, so no row can be found by player (see below) |
| forgotten | PUUID and date added: the suppression list |
| Daily Draft (daily/used.txt, puzzles) | nothing: match ids and anonymous puzzles only |
| backup files | `--backups /mnt/d/meiolol-backups` scrubs every state and segment file at once |
| raw archive (gpu-box) | ingest leaves out documents naming a forgotten PUUID; each pull runs `meiolol-lab archive-forget` for PUUIDs new on the box's list, which drops every archived summary, timeline and mastery line naming them (hashed with the salt) |
| raw exports (box, data/archive-out) | short-lived: deleted on ack; an export holds what raw.db held when it was made |
| Mac mirror | follows on its next daily sync (rsync replaces the scrubbed files) |
| Your games (api.db on the web server) | `forget --data /var/lib/meiolol-api` there: `api.cache.forget` deletes and adds to `blocked` |
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
  `deploy/box.sh run forget --list FILE --backups /mnt/d/meiolol-backups`. A Riot ID
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

- Made by deploy/snapshot.sh (weekly, launchd on the Mac): `VACUUM INTO` on the box,
  streamed to the Mac (data/snap-STAMP/, gitignored) and the box copy deleted at once. Before anyone models on it, `meiolol-lab anonymise
  SRC DST` (src/lab/anonymise.zig) on the Mac writes a fresh copy: PUUIDs and match ids
  replaced by salted hashes (HMAC-SHA256), Riot IDs, summoner ids and names blanked,
  profile icons zeroed, raw timelines and the forgotten list left out (it refuses a
  snapshot still holding a forgotten player's rows). Then SRC is deleted. Match ids are
  hashed too: a real one gives back the ten players through the API. Only the hashed
  copy goes to the gpu-box (~/ml/snaps/STAMP/). The script deletes both real-id copies
  on any exit and checks the result: row counts against the source (fewer only in
  puuidKey tables, whose keys without a PUUID are left out), every PUUID hashed, a real
  match id absent
- The salt is ~/.config/meiolol/snap-salt on the Mac: never in git, never on the box.
  Without it a hash can't be linked back to a PUUID; with it only by hashing candidates
- Disposable: a snapshot is deleted from the Mac and the gpu-box when a newer one
  replaces it, so an erasure reaches analysis copies within one snapshot cycle. Not in
  git, not published
- mastery_pre.tsv (`meiolol-lab mastery-pre SNAP ARCHIVE`): pre-game mastery joined
  from the raw archive, keyed by hashed match id and slot only, written inside the
  snapshot dir, so it stays within the snapshot's rules and goes when the snapshot does
- seat_stats.tsv (`meiolol-lab seat-stats SNAP`): per-seat end-of-game numbers from the
  snapshot's own raw.db, keyed by hashed match id and slot, no player ids; same rules

### Raw archive

Every raw document (match summaries, timelines, mastery snapshots) kept on the gpu-box,
pseudonymised (Jacob, 2026-10-12: keep raw until we understand it, and until player ids
would be blanked anyway). Box side src/archive.zig (`meiolol raw-export`); gpu-box side
src/lab/archive.zig, deploy/archive-pull.sh, systemd user timer meiolol-archive-pull
(hourly, skipped while League is open).

- Box: an export writes everything fetched since the last one to
  data/archive-out/raw-FROM-TO.db, as stored (real ids: the salt never comes to the
  box). The gpu-box's key in ~/.ssh/authorized_keys may only run
  deploy/archive-serve.sh (export, list, send, ack, forgotten, status)
- gpu-box: fetch, check the size, `meiolol-lab archive` (anonymise.rewriteMatch: PUUIDs
  and match ids salted-hashed as in snapshots, so the ids match; Riot IDs, summoner ids
  and names blanked; profile icons 0), zstd -15 --long, test, then ack. Layout:
  ARCHIVE/YYYY-MM-DD/{summaries,timelines}-NAME.jsonl.zst, mastery-NAME.tsv.zst (hashed
  PUUID, platform, fetched_at, champions, compact blob in hex), ARCHIVE/index.tsv
- The salt is on the gpu-box too (~/.config/meiolol/snap-salt, 600), never on the box
  or in git
- The box drops raw documents only once acked and 2 days old (`--ack NAME --keep-days
  2`); unacked ones stay whatever their age: once an export exists, the crawler's own
  raw prune (`--raw-timeline-days`, `--raw-match-days`) also stops at the start of the
  oldest unacked export. A stopped pull shows in Health alerts: gpu-box (no ack for
  12h) and raw held (free disk under twice the raw held)
- An export holds no lock the crawler waits on: each table is copied in one statement
  that reads its own snapshot. Windows go by fetched_at, which the crawler's writer sets
  when it begins the transaction that stores the document, and an export stops 300 s
  short of now, so a document still being written goes in the next one
- Crash safety: an export is written as raw-FROM-TO.db.tmp, recorded in
  raw.archive_exports, then renamed. The next export deletes leftover .tmp files and
  the newest record whose file never got its name (that window is exported again). An
  ack of a name with no record deletes the file and prunes nothing; a failed ack is
  logged and the pull carries on with the rest
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

