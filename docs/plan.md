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

## How we work (2026-10-11)

Several Claude sessions in parallel, coordinated by one (meiolol-44 at the time of
writing). Code sessions use git worktrees and merge to main themselves after build and
tests; deploys build from a commit, never the working tree. Jacob's standing ask: the
coordinator reviews regularly for gaps nobody owns (risks, safety nets, doc requirements
with no work behind them) and hands out work, not just the next plan step.

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

1. Keys. Done 2026-10-11: personal app MEIOLOL (890240) approved; its key (no expiry) is
   in .env (`jodrive riot key --app 890240 --env-file .env`) and goes to the box with
   meiolol-de's all-regions deploy (new key = new PUUIDs: players re-seeded from the
   ladders). Production application started by Jacob 2026-10-11; riot.txt served from
   ml/meiolol/riot.txt on the box via deploy/web-loop.sh. Don't edit the application
   while it queues (resets it). Draft production text (Jacob's voice): docs/production-
   key.md. jodrive handles the General Policies modal with `register --agree`.
   Dev key, if ever needed again: Jacob's standing ok to regenerate (`jodrive riot key
   --regenerate --submit --env-file .env`, captcha in a window, old key dies at once,
   new one answers 200 after ~2 min). `deploy/box.sh start` rebuilds from the working
   tree: with uncommitted crawler work restart the existing binary instead
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
- Name/domain: live on meiolol.jomify.lol (subdomain of Jacob's jomify.lol, Namecheap).
  "lol" in name and TLD is a mild Riot-trademark risk; revisit if the concept renames
- GUI library

## Personal key registration

Submitted by Jacob 2026-10-11 in his own words (approved instantly): a learning tool
showing how lane matchups go minute by minute, compare your lane with the typical curve,
daily draft puzzle; match-v5 with timelines, league-exp-v4, champion-mastery-v4; needs
many games across regions for specific matchups and less played champions; preview site
meiolol.jomify.lol.

## Ruled out (do not revisit without new facts)

- Multiple keys or friends' keys to multiply limits: against Riot's terms, risks the
  production application
- A second "decoy" app to get a key for meiolol's data: one product per key
- lolalytics/op.gg/u.gg scraping, old datasets, pro play data: docs/data.md
- Python: Jacob wants Zig for everything, including training if feasible
