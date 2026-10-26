# Plan: ops

Crawler, traffic, storage and hosts. How things run: docs/hosting.md, docs/compute.md,
docs/data-safety.md.

## Crawler at 99%+ of the key (J16)

Steady hours use ~97-100% of the key per region (crawl.log report lines: region
requests vs 100 per 120 s). In place: rate windows saved and reloaded across restarts
with a paced catch-up of up to 16 slots, so a deploy restart costs seconds, not 2-3
minutes; MemoryHigh=6G on the web loop and box jobs; idle IO priority for export, pack,
ack and prune, with rests between catch-up passes.
- Dips left: daily jobs and runs of deploys (50-94% for an hour while a job reads
  meiolol.db hard and the writer's commits stall). If they stay: pipelined steps
  instead of Bucket.flush after each, or BFQ (mq-deadline honours ionice -c 3 only
  partly)
- Sea runs ~98.6% (long round trips, one request at a time) and has few "due" players,
  so more id lookups per new match: a yield question, not key use

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
fetched /style.css within 60 s (pages revalidate it on every load and link with
no-referrer, so the match is by agent); most of the old count was bots. Scanners (.env,
.php, wp-) are 404s, never page views. The admin traffic tab shows people, unconfirmed
and bots. Next, only if needed:
- Headless bots that load CSS still count. A JS beacon (nginx location, Jacob installs)
  would add little over the CSS match: proposal in data/team/2026-10-19-night/traffic.md
- Cloudflare analytics comparison if the zone gets proxied

## Storage and hosts

- Box disk: raw.db runs auto_vacuum=INCREMENTAL, so prunes return pages
  (docs/data-safety.md "Raw archive"). The databases grow ~3.6 GB a day (meiolol.db and timeline.db ~8 KB a
  match each); box backups prune once both mirrors hold them (backup-loop.sh re-execs
  the deployed script each day). The admin's "full in ~N days" counts the databases only
- Off-site and rolling window: Hetzner BX11 plus a ~30-day window on the box
  (decisions.md "Storage and hosting", data-and-model.md step 7). Jacob orders; the
  admin's "full in ~N days" is the deadline
- gpu-box C: at 90% (the archive is on the P3, safe). Left: step 4 of docs/compute.md
  "gpu-box storage", compacting the WSL disk (~120 GB back, C: to ~77%); it stops WSL,
  so when the gpu-box is idle, after warning its sessions
- jomify logs: /etc/logrotate.d/nginx (daily, 14 kept, delaycompress); traffic.sh
  skips a just-rotated empty log
- NIC offload on the gpu-box if other home ssh dies ("message authentication code
  incorrect")
- Alerts and backups: decisions.md "Open decisions" (ntfy topic, Mac watch job)
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

## Deploys

The renderer swap waits for the deploy's site upload (up to 30 min, old renderer
serving), so new pages never link an old style.css or scripts; the wait is ~66 s
median, ~5 min p90. `deploy/box.sh wait-deployed --live` waits for the swap too.

## Reference

- Hosting: jomify server (Oracle uk-london-1, `ssh jomify`: alias in the Mac's
  ~/.ssh/config for ubuntu@193.123.180.81; jomove.conf is an unrelated house-moving
  app's nginx config: leave alone). /etc/nginx/conf.d/meiolol.conf, root
  /var/www/meiolol, user `meiolol` with an rrsync key from the box; Let's Encrypt via
  webroot. The box: docs/hosting.md (Oracle Cloud, `meiolol-cloud`).
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
