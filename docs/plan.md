# Plan

Updated 2026-10-11.

## Goal now: production key

**Product direction adopted (2026-10-11): docs/concept.md.** "Learn
your lane": your own games laid over minute-by-minute matchup curves (core), public
matchup curve pages, a Daily Draft puzzle, friend/coach Squads, champion Pool; the pick
ranker demoted to a multi-option "from your pool" list. Research (4 answered questions)
and six persona runs behind it. Jacob decided: crawl all regions (meiolol-de is adding
timelines + all regions to the crawler). The sections below describe the current build,
which carries over (crawler, store, model file, site generator, wasm, LCU client).

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
     Jacob's standing ok (2026-10-11): agents may regenerate the dev key when needed.
     `jodrive riot key --regenerate --submit --env-file .env` (captcha in a window; the
     old key dies at once), wait for the new one to answer 200 (~2 min), copy .env to
     the box and restart. `deploy/box.sh start` rebuilds from the working tree, so with
     uncommitted crawler work restart the existing binary instead. Last: 03:00 BST 11 Oct
   - Personal key registration ON HOLD until the text and "I Agree" are approved (the
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
   `deploy/box.sh web start EMAIL` builds + uploads on each 20% growth in patch games,
   at least daily (deploy/web-loop.sh).
   Live 2026-10-11 at https://meiolol.jomify.lol (Let's Encrypt via webroot, renews with
   certbot.timer). Left: real contact email (placeholder now; restart `deploy/box.sh web
   start EMAIL`). Keep preview mode until the production key is granted
3. Site polish before applying: screenshots/GIF of the app in champ select, a demo
   video, rank brackets (statsfile v2), smaller stats.bin (sparse), patch history
4. Desktop app: pick a Zig GUI (candidates: dvui, sokol + imgui, raylib; check Zig 0.16
   support) or keep a terminal UI for v1. Test against the real client on the PC
5. Apply (docs/production-key.md checklist): site up for the whole wait, rate limit
   request with a calculation, link PUUID encryption to the personal app
6. Meanwhile: training in Zig (CPU first, later CUDA on the 3080 via WSL). All regions:
   decided, in progress (limits are per region: ~4x match volume)

## Open decisions (Jacob)

- Dynamic service (Your games, Squads): on the jomove server beside the static site
- Personal key registration text (revised draft below) and the "I Agree" click
- Name/domain: live on meiolol.jomify.lol (subdomain of Jacob's jomify.lol, Namecheap).
  "lol" in name and TLD is a mild Riot-trademark risk; revisit if the concept renames
- GUI library

## Personal key registration draft

Rewritten 2026-10-11 for docs/concept.md. Not approved.

- Product name: meiolol. Product URL: https://meiolol.jomify.lol
- Description: Personal development key for meiolol, a League of Legends learning tool
  in development. It shows how lane matchups unfold minute by minute (gold, XP and CS
  curves per matchup and rank tier, from aggregate ranked match timelines), lets players
  compare their own lane with the typical curve after a game, and includes a daily draft
  puzzle built from anonymised past games. On this key I collect ranked solo queue match
  data (match-v5 with timelines, league-exp-v4, champion-mastery-v4) across regions within
  the personal rate limits, to build and test the prototype. An unadvertised preview
  website (meiolol.jomify.lol) shows aggregate champion statistics only and will be
  submitted for a production key before it is made public. Data is stored privately,
  keyed by match ID, and deletion requests will be honoured. Champion and aggregate data
  only: never other players' names or stats in champ select, no auto-locking or dodging.

## Ruled out (do not revisit without new facts)

- Multiple keys or friends' keys to multiply limits: against Riot's terms, risks the
  production application
- A second "decoy" app to get a key for meiolol's data: one product per key
- lolalytics/op.gg/u.gg scraping, old datasets, pro play data: docs/data.md
- Python: Jacob wants Zig for everything, including training if feasible
