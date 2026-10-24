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
- After, 20 Oct (americas/asia/europe/sea, mean): 09h 99.3/99.8/98.3/98.6, 99.0; 10h
  98.1/98.6/97.6/98.5, 98.2 (deploys and web rounds 10:07, 10:33, no crawler restart);
  no 429s 08-11h; 11h 98.9/99.9/100.8/98.6, 99.6. Europe's 10h dip: the deploys' web
  rounds; 11:50-12:30 its 120 s window held 100 of 100 every minute. Sea up from ~97 to
  ~98.6, the one region short (96-99 of 100 in its window: long round trips, one
  request at a time)
- Hourly key use 21-24 Oct (region requests vs 50/min, crawl.log): ~97-100% most
  hours. Dips: 21 Oct 16h 52% (a 29 min gap), 20-21h 78-91%; 22 Oct 20-21h 50-78%
  (20:44-20:50 the writer got only busy: another process held the lock, nothing
  written; fa27b53's export IO priority landed 21:04), 22-23h ~94%; 23 Oct 17-18h
  85-92%, 21h ~93%; 24 Oct 00h ~85% (a run of deploys). If job dips stay:
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
- Rechecked 20 Oct 22:30 (Jacob: "down quite a lot", "americas sub 95%"): no drop.
  Stored ~166k/day, match routes ~196 req/min (key limit), every 15-min window 96-100%
  except 21:20-21:50 BST (americas, asia, sea 83-89%; europe 97%): the gpu-box back
  after ~16 h away, eight 2 h exports 20:31-22:13, writer queue 72 vs ~20. 10-15% for
  30 min against ~45% on 19 Oct, so the export rests stay. What looked down: "Games by
  game day" (days keep filling; the chart now shows each bar's last 24 h), platform
  calls ~610 to ~400/min (mastery, fewer new players), timelines 5.5k to 4k/h (9afcdc9's
  sparse sample, by design)
- Open lead, not chased: fewer recent games stored. Of the drafts stored in a 24 h
  window, the share played that day or the day before fell from 55-69% (15-18 Oct) to
  46% (20 Oct); 19 Oct had 74k a day after it, 17-18 Oct 83-85k. Total stored is flat,
  so the budget goes to older games from players' histories (match id lists, queue
  order)
- Old game days never stop filling (admin data.json, 20 Oct 21:55 UTC): in the last
  24 h, 7-16 Oct each gained 4.2-9.5k games (5-11% of what the window holds of them),
  17 Oct 12k, 18 Oct 18k, 19 Oct 40k (53%). So no day's count is final, and only the
  newest few are far from it. Part of the old days' share is the 1M-row window dropping
  their earliest-stored rows

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

- raw.db VACUUM done 21 Oct: 40.5 GB to 10.3 GB, now auto_vacuum=INCREMENTAL so
  prunes return pages; box disk 62% to 42% (85 GB free). docs/data-safety.md "Raw
  archive". Prunes return 150-640 MB each (archive-prune.log, 23-24 Oct)
- Growth, 24 Oct (admin-history.tsv): disk +6 GB in the last day (45%, 81 GB free):
  meiolol.db +1.8 GB, timeline.db +1.35 GB, raw.db +0.5 GB, ~165k matches (~8 KB a
  match in each of the first two), the rest box backups. Those were never pruned:
  meiolol-backup's bash loop ran from 11 Oct and bash keeps the loop it parsed, so the
  17 Oct prune (files both mirrors hold) never ran; backups/ 16 GB, all acked. Now
  backup-loop.sh re-execs the deployed script each day; the running loop needs one
  restart after a 04:00 backup (frees ~14 GB). The admin's "full in ~N days" counts
  only the databases (~3.6 GB a day: ~22 days)
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
- Incremental snapshots (Jacob 23 Oct: "adding to the data rather than copying it"):
  daily since 23 Oct, but each make still restores the whole mirror, anonymises,
  splits and packs (~70 min on the gpu-box, ~22 GB new on each host) though nearly every
  game was in the one before. Instead keep one anonymised copy on the gpu-box and append
  each backup segment's new rows hashed with the same salt, plus the late-changing
  columns and the tables backups leave out (snapshot-extra); a fixed id per day's state
  for runs that must not move (split by date cut-off, not a new dir); Mac copy by
  rsync onto the last. Check first: anonymise and split assume a full rebuild (row
  order, split.tsv over all games, pack and seat stats rebuilt whole), and erasure must
  still reach the copy (forget applied to it, as to the mirrors)

## Deploys

- From cf8a06b (20 Oct): the renderer swap waits for the deploy's site upload (up to
  30 min, old renderer serving), so new pages never link old style.css or scripts (that
  day the swap came 4 s after the deploy, the upload 140 s later). Wait over 183 past
  deploys: 66 s median, 305 s p90. wait-deployed --live waits for the swap too

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
