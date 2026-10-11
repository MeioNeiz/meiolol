# Plan

Updated 2026-10-11.

## Goal now: production key

A personal key gives ~60k EUW matches/day (35-40% of EUW's ~170k ranked solo games).
More needs a production key, which needs a public product worth the volume. That
product is meiolol itself, two faces of one application (docs/production-key.md):

1. Public stats website: tier lists, champion pages with matchups and synergies, a web
   draft tool. Genuinely needs millions of matches, and is the site Riot requires
2. Desktop draft assistant (`meiolol-app`), same data

## State

- Done: Zig crawler live on the gpu-box PC (replaced the Python one, same database);
  rate limiter, match parser, storage, tests. Player app: LCU client, champ select
  parsing, DraftGap-style recommender, `suggest` (offline) and `watch` (live), all
  compiling for macOS and Windows; 34 tests
- Not verified live: LCU handshake and a real champ select session (League was not
  running on the PC). Capture a real fixture: `meiolol-app session --save
  testdata/lcu/session-real.json` during a ranked champ select
- Done 2026-10-11 (second agent): `meiolol stats` (model file; tested end to end:
  box writes it, `meiolol-app suggest` on the Mac reads it) and `meiolol site` (static
  website incl. wasm draft helper, preview mode). Not hosted: needs domain + host
- Data on the box: ~2.4k matches (patch 16.19 and 16.20), 500k players

## Next steps, in order

1. Keep data flowing. The crawler uses a 24h development key created 2026-10-11
   ~00:45 BST; when it expires the crawler exits 3 and stays stopped. Fix: personal key
   (no expiry):
   - Riot portal session: `jodrive riot signin` (opens plain Chrome; Jacob logs in, then
     Cmd+Q). Then `jodrive riot key --env-file .env` grabs a dev key meanwhile
   - `jodrive riot register --type personal --inspect`, fill with the text below, show
     Jacob the exact values, `--submit` only after he approves
   - After any key change: `deploy/box.sh start` (copies .env to the box)
2. Host the site on the jomove server (Oracle Cloud, `ssh -i ~/.ssh/oci_instance-20260714-1317
   ubuntu@193.123.180.81`; Ubuntu 24.04 x86_64, 1 GB RAM, nginx + certbot already serve
   jomove.jomify.lol there). Plan, pending Jacob's go-ahead and domain choice:
   - nginx server block for the domain, root /var/www/meiolol, `gzip_static on` (site
     writes .gz siblings), certbot TLS; must not block `python-requests/2.11.1` (riot.txt)
   - Dedicated `meiolol` user on the server owning /var/www/meiolol; the box gets its
     own key for that user only (not ubuntu, which has sudo)
   - Box: daily `meiolol site` then rsync to the server (`deploy/box.sh web` currently
     builds daily and serves on box localhost:8080 only; switch it to push)
   - Domain: subdomain of jomify.lol (Namecheap DNS, A record to 193.123.180.81) or a new
     one. Keep preview mode until the production key is granted
3. Site polish before applying: screenshots/GIF of the app in champ select, a demo
   video, rank brackets (statsfile v2), smaller stats.bin (sparse), patch history
4. Desktop app: pick a Zig GUI (candidates: dvui, sokol + imgui, raylib; check Zig 0.16
   support) or keep a terminal UI for v1. Test against the real client on the PC
5. Apply (docs/production-key.md checklist): site up for the whole wait, rate limit
   request with a calculation, link PUUID encryption to the personal app
6. Meanwhile: training in Zig (CPU first, later CUDA on the 3080 via WSL), and
   optionally more regions on the same key (limits are per region: ~4x volume)

## Open decisions (Jacob)

- Personal key registration text (draft below) not yet approved
- Domain name (note: "meiolol" contains "lol"; Riot bans its trademarks in domains,
  though lolalytics/leagueofgraphs hold keys); host; contact email for privacy/terms;
  GUI library; whether to crawl NA/KR/SEA now
- Personal key text says "nothing is public" while the site runs in preview at a URL
  for the production review: fine as long as it stays unadvertised and noindex?

## Personal key registration draft

- Product name: meiolol
- Description: Personal research project. I'm building a champion select assistant for
  League of Legends that suggests a short ranked list of champion picks, with reasons,
  based on the champions already picked and banned. To train it I collect EUW ranked
  solo queue match data (match-v5, league-exp-v4, champion-mastery-v4) within the
  personal key rate limits. For my own use only; nothing is public. Data is stored
  privately, keyed by match ID, and deletion requests will be honoured. The tool will
  follow Riot's policies: no auto-locking or dodging, and no revealing hidden player
  names.

## Ruled out (do not revisit without new facts)

- Multiple keys or friends' keys to multiply limits: against Riot's terms, risks the
  production application
- A second "decoy" app to get a key for meiolol's data: one product per key
- lolalytics/op.gg/u.gg scraping, old datasets, pro play data: docs/data.md
- Python: Jacob wants Zig for everything, including training if feasible
