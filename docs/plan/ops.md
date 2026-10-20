# Plan: ops

Crawler, traffic, storage and hosts. How things run: docs/hosting.md, docs/compute.md,
docs/data-safety.md.

## Crawler at 99%+ of the key (J16)

Measured 16-20 Oct from crawl.log (region requests / 100 per 120 s): steady hours
~99% (sea ~97%), losses from deploy restarts (2-3 min of nothing each: Riot's counts
padded our windows full) and daily jobs (19 Oct 20:00 draft-model 77%, 23:00-01:00
builds 94-96%: sar shows the job reading meiolol.db at up to 44 MB/s, the crawler's
active pages 4.5 -> 1.4 GB, commits stall, and every thread waits for its commit).
- Done 20 Oct: rate windows saved and reloaded across restarts, paced catch-up of up to
  16 slots (040c41e); MemoryHigh=6G on the web loop and box jobs (8a4e366). Restart
  test 20 Oct 08:21: platform requests 508, 1187, 1744 in the first 3 min (before: 25,
  95, 213), regions ~120-147 in 3 min (full pace 150), no 429s
- Next: hourly rates after, tonight's draft-model and builds rounds. If job dips stay:
  pipelined steps instead of Bucket.flush after each, or BFQ (mq-deadline honours
  ionice -c 3 only partly)
- Sea: few "due" players (sea scans them fast, then falls back to never-scanned ones),
  so more id lookups per new match; a yield question, not key use

## Crawler speed (Jacob 19 Oct: "seems like it could be a bit faster, it's got slower")

Known cause, 19 Oct: the gpu-box woke to a ~30 h raw backlog and its back-to-back 2 h
exports with their prunes took the crawler from ~1,180 to ~650 matches per 10 min and
its requests from ~2,000 to ~1,170 (box io pressure full avg300 60%). Fixed in 1037318
(idle IO priority for export, pack, ack and prune; rests between catch-up passes).
- Checked 19 Oct 23:55 from crawl.log: recovered. 10-min rate 1,100-1,200 through 19
  Oct (one dip to ~1,040 at 21:00), 24 h rate ~165k matches/day, up from ~136k on 16-17
  Oct, so no slide before 19 Oct either. Recheck only if the admin chart drops again
- If it drops: requests per match, 429s ours vs
  Riot's (J8), time per request, SQLite write and fsync time, the rolling-window and
  VACUUM work below; then whether the key's rate is the ceiling (production key)

## Traffic looks inflated (Jacob 19 Oct: "def mostly bots, it's not proper")

Done 20 Oct (traffic agent): deploy/traffic.sh counts a browser-agent page view as a
person only when the same agent fetched /style.css within 60 s (pages revalidate it on
every load; they link with no-referrer, so the match is by agent, one fetch per view).
12-19 Oct: 20,832 "people" by the old count, 506 by the new; 12.5k of 18 Oct's 13.2k were one
crawler with a 2015 Edge 12 agent in one hour, 5.5k on 12 Oct likewise. Scanners
(.env, .php, wp-) were already out: all 404s, never page views. Admin traffic tab shows
people, unconfirmed and bots. Next, only if needed:
- Headless bots that load CSS still count. A JS beacon (nginx location, Jacob installs)
  would add little over the CSS match: proposal in data/team/2026-10-19-night/traffic.md
- Cloudflare analytics comparison if the zone gets proxied

## Storage and hosts

- raw.db: VACUUM its 21 GB of free pages (meiolol-b5, after a rehearsal on a copy)
- Off-site and rolling window: Hetzner BX11 plus ~30-day window on the box
  (decisions.md "Storage and hosting", data-and-model.md step 7). Jacob orders; needed
  within ~a week of 18 Oct (admin's "full in ~N days": ~26 days on 18 Oct)
- gpu-box C: at 90% (the archive is on the P3, safe). Left: step 4 of docs/compute.md
  "gpu-box storage", compacting the WSL disk (~120 GB back, C: to ~77%); it stops WSL,
  so when the gpu-box is idle, after warning its sessions
- jomify logs rotate since 20 Oct: logrotate was not installed (Jacob approved the
  install), so /etc/logrotate.d/nginx (daily, 14 kept, delaycompress) never ran; first
  forced rotation 20 Oct 00:05. traffic.sh skips a just-rotated empty log (eb5aac1)
- NIC offload on the gpu-box if other home ssh dies ("message authentication code
  incorrect", 14-17 Oct)
- Alerts and backups: decisions.md "Open decisions" (ntfy topic, Mac watch job)
- Crawl floor Gold IV once the key's rate allows (Q4)

## Reference

- Hosting: jomify server (Oracle uk-london-1, `ssh jomify`: alias in the Mac's
  ~/.ssh/config for ubuntu@193.123.180.81; jomove.conf is an unrelated house-moving
  app's nginx config: leave alone).
  /etc/nginx/conf.d/meiolol.conf, root /var/www/meiolol, user `meiolol` with an rrsync
  key from the box; Let's Encrypt via webroot. The box: docs/hosting.md (Oracle Cloud,
  `meiolol-cloud`). deploy/web-loop.sh on the box builds and
  uploads (often early in a patch, then hourly on new games); riot.txt from
  ml/meiolol/riot.txt
- Admin page: https://meio.lol/admin/ (/api/ basic auth; src/admin.zig).
  Crawl rates by region from crawl.log report lines, storage growth
  (data/admin-history.tsv), ingest mix, queues, eval, uploads, deploys; rebuilt every
  15 min by the web loop
- jodrive: `riot register --agree` handles the General Policies modal; `riot key --app
  ID` reads a registered app's key
- Personal key registration (Jacob's words, approved instantly): learning tool showing
  lane matchups minute by minute, compare your lane with the typical curve, daily draft
  puzzle; match-v5 with timelines, league-exp-v4, champion-mastery-v4; preview site
