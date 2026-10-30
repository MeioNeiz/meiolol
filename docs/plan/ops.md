# Plan: ops

Crawler, traffic, storage and hosts. How things run: docs/hosting.md, docs/compute.md,
docs/data-safety.md.

## Crawler at 99%+ of the key (J16)

Steady hours use ~97-100% of the key per region on C01 as on the Oracle box (crawl.log
report lines: region requests vs 100 per 120 s; a report's totals run from the
crawler's start, so a dip drags them for a day: measure per hour). In place: rate
windows saved and reloaded across restarts with a paced catch-up of up to 16 slots, so
a deploy restart costs seconds, not 2-3 minutes; MemoryHigh=6G on the web loop and box
jobs; idle IO priority for export, pack, ack and prune, with rests between catch-up
passes; WAL checkpoints in their own thread, never the writer's; ack prunes keep 8 GB
of raw.db's free pages instead of moving pages back to the disk.
- The big loss was the gpu-box's archive catch-up on C01's disk (29-30 Oct: 70-90% for
  11 hours after a day offline): each ack's prune moved ~500 MB of raw.db pages and
  left a GB of WAL, and the writer's own checkpoint copied it while blocking commits:
  0-2 commits a minute for minutes at a time, the queue full, every region idle. Fixed
  30 Oct as above. A restart-free hour after it (10:30-11:32): americas 99.8%, asia
  99.5%, europe 99.3%, sea 98.0%, ~163k matches a day; writer waits 0-1% of each
  region's minute, WALs 2-60 MB. Still to see: the next gpu-box catch-up (it was off).
  The "time %" report line shows where each region's minute goes (slot wait is
  budget-bound, the rest is lost key use)
- Dips left: daily jobs and runs of deploys (90-95% for an hour while a job reads
  meiolol.db hard). If they stay: pipelined steps instead of Bucket.flush after each,
  or BFQ (mq-deadline honours ionice -c 3 only partly)
- Sea runs ~98% (93-95% on C01 before the fix): one request at a time, ~0.7 s of each
  1.2 s slot in Riot's answer (time %: 36-40 slot wait, 56-61 Riot). Two in flight
  would not help: every minute sea still waits 25%+ on the limiter, whose catch-up
  (16 slots) makes up short stalls; the gap to 99.4% is within the per-step counters'
  noise (+-1.5% an hour). Its few "due" players mean more id lookups per new match: a
  yield question, not key use

## Crawler speed

~165k matches a day, ~196 match requests a minute (the key's limit). The gpu-box
waking to a long raw backlog runs back-to-back exports that cost the crawler 10-15% for
about half an hour; the export rests keep it there. Recheck only if the admin chart
drops.
- If it drops: requests per match, 429s ours vs Riot's (J8), time per request, SQLite
  write and fsync time, the rolling window and VACUUM work below; then whether the
  key's rate is the ceiling (production key)
- Things that look like a drop and aren't: game days keep filling for weeks (old days
  gain 5-11% a day, the newest far more; part of it is the 1M-row window dropping their
  earliest rows), so no day's count is final; platform calls fall as fewer new players
  need mastery; timelines are a sparse sample by design
- Open lead, not chased: fewer recent games stored. The share of a day's stored drafts
  played that day or the day before fell from 55-69% to ~46%; total stored is flat, so
  the budget goes to older games from players' histories (match id lists, queue order)

## Traffic

deploy/traffic.sh counts a browser-agent page view as a person only when the same agent
fetched /print.css within 60 s (every page links it no-cache, so browsers revalidate it
on each load; pages link with no-referrer, so the match is by agent); most of the old
count was bots. Scanners (.env, .php, wp-) are 404s, never page views. The admin traffic
tab shows people, unconfirmed and bots. Next, only if needed:
- Headless bots that load CSS still count. A JS beacon (nginx location, Jacob installs)
  would add little over the CSS match: proposal in data/team/2026-10-19-night/traffic.md
- Cloudflare analytics comparison if the zone gets proxied

## Storage and hosts

- Box disk: raw.db runs auto_vacuum=INCREMENTAL; prunes return free pages past 8 GB
  (docs/data-safety.md "Raw archive"). The databases grow ~3.6 GB a day (meiolol.db and timeline.db ~8 KB a
  match each); box backups prune once both mirrors hold them (backup-loop.sh re-execs
  the deployed script each day). The admin's "full in ~N days" counts the databases only
- Off-site: Megatron (J31); no rolling window on the box. The admin's "full in ~N days"
  is the deadline for anything more
- gpu-box C: at 90% (the archive is on the P3, safe). Left: docs/compute.md "gpu-box storage", Open
  "gpu-box storage", compacting the WSL disk (~120 GB back, C: to ~77%); it stops WSL,
  so when the gpu-box is idle, after warning its sessions
- jomify logs: /etc/logrotate.d/nginx (daily, 14 kept, delaycompress); traffic.sh
  skips a just-rotated empty log
- NIC offload on the gpu-box if other home ssh dies ("message authentication code
  incorrect")
- Phone alerts: decisions.md "Open decisions" (ntfy topic); the Mac watch job runs
- Crawl floor Gold IV once the key's rate allows (Q4)
- Incremental snapshots ("adding to the data rather than copying it"): daily now, but
  each make still restores the whole mirror, anonymises, splits and packs (~70 min on
  the gpu-box, ~22 GB new on each host) though nearly every game was in the one before.
  Instead keep one anonymised copy on the gpu-box and append each backup segment's new
  rows hashed with the same salt, plus the late-changing columns and the tables backups
  leave out (snapshot-extra); a fixed id per day's state for runs that must not move
  (split by date cut-off, not a new dir); Mac copy by rsync onto the last. Check first:
  anonymise and split assume a full rebuild (row order, split.tsv over all games, pack
  and seat stats rebuilt whole), and erasure must still reach the copy (forget applied
  to it, as to the mirrors)

## Complete form

Jacob (30 Oct): C01 keeps every document we collect in a form the raw JSON is recreated
from, byte for byte; the gpu-box keeps a pseudonymised copy for model tests; raw JSON
ends everywhere once that holds. Why: compact timelines (~10 KB) drop about half the
JSON (per-minute champion stats and damage split, kill damage breakdowns), so today the
raw archive is the only copy of that half, raw piles up on C01 (~9 GB a day) whenever
the gpu-box is off, and catch-ups stalled the crawler.

S1 measured (30 Oct, 1,950 timelines and their summaries from C01, prototype codec):
- Codec: schema-free and structural. Key lists go to a shape dictionary, values to one
  stream per JSON path (integers as zigzag deltas, strings by a per-path dictionary,
  other numbers as their text), then zstd. Every document decodes to its exact bytes
  (3,900 of 3,900; a failed check would keep that document raw)
- Bytes per document, against the archive's zstd -15 stream of plain JSON:

  | | raw JSON | stored on C01 now (gzip) | archive now | complete form |
  |---|---|---|---|---|
  | timeline | 790 KB | 75 KB | 44 KB | 24.5 KB (29 KB doc by doc) |
  | summary | 76 KB | 12 KB | 5 KB | 3.4 KB (4.5 KB doc by doc) |
  | mastery fetch | ~35 KB | not kept (compact 0.9 KB, lossy) | compact | ~1.3 KB |

  "Doc by doc": each document's streams together, zstd over the file; the lower figure
  groups each stream across documents (blocks of documents in S2)
- A timeline's bytes: kill damage breakdowns 38%, per-minute damage split 17%, other
  events 15%, per-minute gold/XP/CS/position 12%, per-minute champion stats 9%,
  structure 6%, PUUIDs 4%. Left for S2: a document-wide string dictionary (each PUUID
  is there twice), type tags inferred from the path (~1 KB), one spell-name dictionary
  per file
- A day at today's rate (91k timelines, 163k summaries, 536k mastery fetches): ~3.5 GB,
  against ~6.6 GB a day into the archive now. C01 then grows ~6 GB a day with the
  databases: 400 GB free lasts ~2 months, so a bigger disk image (Megatron, Ethan's
  call) by about January
- Mastery: no raw JSON has ever been kept (compact drops seasonal and derived fields,
  last play rounded to hours), so its complete form starts when S3 does
- Speed: 7 ms a timeline to encode and check on the Mac, ~10 CPU minutes a day

Steps (S2 on, anything that writes on C01 or changes the crawler, through the
coordinator first):
- S2 codec in src/store: round-trip and fuzz tests, blocks of documents per stream,
  the S1 leftovers above
- S3 the crawler writes the complete form for every summary, timeline and mastery
  fetch: sealed per-day files on the data disk (outside SQLite, so the writer's WAL
  doesn't carry the bytes), raw kept only for a document that fails its check
- S4 forget rewrites the day files it touches (an erased document no longer equals the
  original), the 24-month sweep blanks the same; backups, restore test, health lines
- S5 the gpu-box pulls day files instead of raw exports and pseudonymises them as the
  archive does now; lab readers (summaries, mastery-pre, seat-stats, comp-stats) read
  them. With its salt the copy rejoins meiolol.db backups, so it is also the copy off
  Megatron
- S6 raw ends: no raw docs, raw exports, valve or prune; raw.db goes
- S7 the gpu-box's raw archive (12 Oct on, pseudonymised) converted there, checked byte
  for byte, then its raw files deleted

Open, defaults taken: (a) C01 also gets the converted history (hashed ids) or it stays
on the gpu-box only: gpu-box only until asked. (b) A Mac mirror of the day files
(~3.5 GB a day): no, the gpu-box copy is the one off Megatron.

## Deploys

The renderer swap waits for the deploy's site upload (up to 30 min, old renderer
serving), so new pages never link an old style.css or scripts; the wait is ~66 s
median, ~5 min p90. `deploy/box.sh wait-deployed --live` waits for the swap too.

## Reference

- Hosting: C01 (`ssh essex-vm`, docs/hosting.md), nginx behind Cloudflare Tunnel
  `meiolol-c01` (TLS at Cloudflare; deploy/vm-web.sh installs it):
  /etc/nginx/conf.d/meiolol.conf, root /var/www/meiolol, user `meiolol` with rrsync
  keys from the box's localhost aliases.
  deploy/web-loop.sh on the box builds and uploads (often early in a patch, then hourly
  on new games); riot.txt from ml/meiolol/riot.txt
- Admin page: https://meio.lol/admin/ (/api/ basic auth; src/admin.zig). Crawl rates
  by region from crawl.log report lines, storage growth (data/admin-history.tsv),
  ingest mix, queues, eval, uploads, deploys; rebuilt every 15 min by the web loop
- jodrive: `riot register --agree` handles the General Policies modal; `riot key --app
  ID` reads a registered app's key
- Personal key registration (Jacob's words, approved instantly): learning tool showing
  lane matchups minute by minute, compare your lane with the typical curve, daily draft
  puzzle; match-v5 with timelines, league-exp-v4, champion-mastery-v4; preview site
