# Key switch (rekey)

Part of data safety (docs/data-safety.md): erasure lists, backups and the raw archive
under a new Riot key.

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

## Wrong-key windows

Twice a key from another Riot app went into .env: 2026-10-11 23:25:50-23:28:45Z and
2026-10-13 20:54-22:35Z. Every PUUID that key returned gives 400 "Exception decrypting"
under ours. The games stored then are kept with their participant PUUIDs blanked, and
the players first seen in the windows deleted, on the box and in every backup segment
on both mirrors. Left: rank rows keyed by those PUUIDs (orphans), and the raw archive's
copies of those games with hashed wrong-app PUUIDs that no erasure can reach: blank
them as runbook step 6 does (open). Guard: crawl start calls mastery for the player most
recently given one and exits 3 (as a rejected key) on a 400, before writing anything
(Crawler.checkKey).

A hand edit of stored rows needs the same edit in every mirror's segments: `backup
--full` makes a restore right (newest copy wins) but leaves the old segments holding the
old rows.
