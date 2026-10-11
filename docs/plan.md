# Plan

Updated 2026-10-11.

## Goal now: production key

**Product direction under review (2026-10-11):** Jacob asked for a more interesting,
Riot-friendly idea that still needs lots of data, because a pick recommender sits near
Riot's unapproved "apps that dictate player decisions". Starting idea: matchup power
curves from match timelines (core), a daily draft puzzle (hook), champion discovery from
mastery data; the pick helper demoted to several options with reasons. Research and
persona review in progress (research/questions/ league-tools-landscape,
riot-appreciated-tools, player-tool-needs, riot-api-data-depth); result goes in
docs/concept.md. The sections below describe the current build, which carries over
(crawler, store, model file, site generator, wasm, LCU client).

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
  box writes it, `meiolol-app suggest` on the Mac reads it), `meiolol site` (static
  website incl. wasm draft helper, preview mode), `meiolol serve` (local preview),
  hosting live at https://meiolol.jomify.lol (step 2), repo github.com/MeioNeiz/meiolol
  (private; push works via the MeioNeiz gh account, not the work one)
- Data on the box: ~3k matches (patch 16.19 and 16.20), 500k players

## Next steps, in order

1. Keep data flowing. The crawler uses a 24h development key created 2026-10-11
   ~00:45 BST; when it expires the crawler exits 3 and stays stopped. Fix: personal key
   (no expiry), or meanwhile a fresh dev key:
   - Portal session works (`jodrive riot apps` lists app MEIONEIZ, development key).
     `jodrive riot key --regenerate --env-file .env` (Jacob's ok) then `deploy/box.sh start`
   - Personal key registration ON HOLD until the product direction is chosen (the
     description must match). Blocker found: on /app-type, `button[app_type=personal]`
     opens a "General Policies" modal (#general) that needs "I Agree"
     (`a.policy_agreement`) before the form appears; jodrive does not handle it
     (~/personal/jodrive/projects/riot/register.js). Clicking I Agree accepts Riot's
     policies for Jacob: ask him first. Then `--inspect`, show values, `--submit` on ok
2. Hosting at meiolol.jomify.lol on the jomove server (Oracle Cloud,
   `ssh -i ~/.ssh/oci_instance-20260714-1317 ubuntu@193.123.180.81`; nginx + certbot
   also serve jomove there, leave its config alone). Done 2026-10-11: nginx
   /etc/nginx/conf.d/meiolol.conf (root /var/www/meiolol, gzip_static, acme webroot
   /var/www/letsencrypt), user `meiolol` with only an rrsync key from the box,
   `deploy/box.sh web start EMAIL` builds + uploads daily (deploy/web-loop.sh).
   Live 2026-10-11 at https://meiolol.jomify.lol (Let's Encrypt via webroot, renews with
   certbot.timer). Left: real contact email (placeholder now; restart `deploy/box.sh web
   start EMAIL`). Keep preview mode until the production key is granted
3. Site polish before applying: screenshots/GIF of the app in champ select, a demo
   video, rank brackets (statsfile v2), smaller stats.bin (sparse), patch history
4. Desktop app: pick a Zig GUI (candidates: dvui, sokol + imgui, raylib; check Zig 0.16
   support) or keep a terminal UI for v1. Test against the real client on the PC
5. Apply (docs/production-key.md checklist): site up for the whole wait, rate limit
   request with a calculation, link PUUID encryption to the personal app
6. Meanwhile: training in Zig (CPU first, later CUDA on the 3080 via WSL), and
   optionally more regions on the same key (limits are per region: ~4x volume)

## Open decisions (Jacob)

- Product direction (research under way, docs/concept.md)
- Personal key registration text (revised draft below) and the "I Agree" click
- Name/domain: live on meiolol.jomify.lol (subdomain of Jacob's jomify.lol, Namecheap).
  "lol" in name and TLD is a mild Riot-trademark risk; revisit if the concept renames
- GUI library; whether to crawl NA/KR/SEA now

## Personal key registration draft

Revised 2026-10-11 (the old text said "nothing is public", untrue once the preview site
exists). Not approved; rewrite to match the chosen concept.

- Product name: meiolol. Product URL: https://meiolol.jomify.lol
- Description: Personal research project. I'm building a champion select assistant for
  League of Legends that suggests a short ranked list of champion picks, with reasons,
  based on the champions already picked and banned. To train it I collect EUW ranked
  solo queue match data (match-v5, league-exp-v4, champion-mastery-v4) within the
  personal key rate limits. The desktop tool is for my own use only. An unadvertised
  preview website (meiolol.jomify.lol) shows aggregate champion statistics only, never
  player names, and will be submitted separately for a production key before it is made
  public. Data is stored privately, keyed by match ID, and deletion requests will be
  honoured. The tool follows Riot's policies: no auto-locking or dodging, and no
  revealing hidden player names.

## Ruled out (do not revisit without new facts)

- Multiple keys or friends' keys to multiply limits: against Riot's terms, risks the
  production application
- A second "decoy" app to get a key for meiolol's data: one product per key
- lolalytics/op.gg/u.gg scraping, old datasets, pro play data: docs/data.md
- Python: Jacob wants Zig for everything, including training if feasible
