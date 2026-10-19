# Plan: ops

Crawler, traffic, storage and hosts. How things run: docs/hosting.md, docs/compute.md,
docs/data-safety.md.

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

deploy/traffic.sh counts a page view as human unless the user agent is empty or names a
bot (bot, crawl, spider, curl, python, headless, preview, ...); bots with a browser's
user agent count as people. No IPs are logged (privacy), so per-IP rate checks are out.
Ideas, cheapest first: count as human only pages whose CSS or JS was also fetched
within a minute with the same referer; a tiny beacon from the page's JS (a fetch with
no identifiers; bots that do not run JS never send it); look at the top user agents and
paths in "human" views for scanners (wp-admin, .env, .php); compare with Cloudflare's
analytics if the zone is proxied. Owner of traffic.sh install: meiolol-8f.

## Storage and hosts

- raw.db: VACUUM its 21 GB of free pages (meiolol-b5, after a rehearsal on a copy)
- Off-site and rolling window: Hetzner BX11 plus ~30-day window on the box
  (decisions.md "Storage and hosting", data-and-model.md step 7). Jacob orders; needed
  within ~a week of 18 Oct (admin's "full in ~N days": ~26 days on 18 Oct)
- gpu-box C: at 90% (the archive is on the P3, safe). Left: step 4 of docs/compute.md
  "gpu-box storage", compacting the WSL disk (~120 GB back, C: to ~77%); it stops WSL,
  so when the gpu-box is idle, after warning its sessions
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
