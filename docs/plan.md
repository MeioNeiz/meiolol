# Plan

Updated 2026-10-18 (Now, after the 17 Oct reviews); the rest from 2026-10-11 on.

## Now (18 Oct): fix before building

Ranked by harm: outages and data risk, then what Riot's reviewers see before Jacob
presses Verify, then what brings players back. Findings: docs/review/
persona-walk-2026-10-17.md (R, J ids), docs/review/next-steps-2026-10-17.md (A/B/C, Q).

1. Done 18 Oct (76d691f, installed on jomove): the Your games API would have died at
   16.21 (two newest curves files, 226 MB each parsed, MemoryMax 400M). Since 176909b
   (installed 18 Oct) the API and renderer map curves files read-only instead of copying
   them: both newest patches load at any size, no 320 MB budget (API RSS 152 to 10 MB,
   start-up 3 to 0.3 s); also shipped R17's "All games" label
2. Done 18 Oct (3f8882f, 47f2764, a490a73): the box no longer holds a backlog copy of raw.
   The 14-17 Oct acks died on ssh corrupted in transit from home ("message
   authentication code incorrect") while the ack's prune held the session open; acks
   now only mark and delete, the prune runs detached, every box command is retried.
   Exports cover at most 2 h (~1 GB) and leave the box once the gpu-box confirms the
   sha256 (they wait on the archive disk until archived). Health's disk line is days
   of raw above the valve; admin's "full in ~N days" uses the database files' growth
   (~26 days on 18 Oct). Left: VACUUM of raw.db's 21 GB of free pages (meiolol-b5,
   after a rehearsal on a copy); NIC offload on the gpu-box if other home ssh dies.
   Lasting answer: Open decisions "Storage and hosting"
3. gpu-box C: at 90% (holds the WSL disk; the archive is on the P3, safe). Done 18 Oct:
   G2 prune (35 GB inside WSL), the lab partition sde6 and the move of snaps and runs
   onto it (docs/compute.md "gpu-box storage" 1-3, 33ef202). Left: step 4, compacting
   the WSL disk (~120 GB back, C: to ~77%); it stops WSL, so when the gpu-box is idle,
   after warning its sessions
4. Done 18 Oct: contact is privacy@meio.lol on terms and privacy (R34). Test mail kept
   by the worker (`deploy/mail.sh list`); sent straight to Cloudflare's MX over IPv4
   from the Mac (its IPv6 has no reverse DNS; both OCI hosts block port 25)
5. Done 18 Oct (231a458): Daily Draft has no win chance or points; "on paper the draft
   leaned blue/red" only when the 95% range excludes even (none of 9 puzzles on 16.20);
   reasons in words from static/reasons.js (shared with Learn); games at least a week
   old, the previous patch's in a patch's first week (R16, A3, A4, J1, Q2)
6. Application text to match the site (A2; Jacob writes, Q1), champ select screenshots,
   video and LCU endpoint list (A1; needs Jacob in a real champ select, steps under
   "Before the production review"). Draft text done 18 Oct (f1ea29c, production-key.md
   "Application text (draft 2026-10-18)"; squads left out): Jacob checks its list and
   pastes. Before going live, so the text is true: the 24-month sweep over backup
   segments and deleting archive files (privacy.md notes; `archive-age` only blanks
   hashed PUUIDs). First rows reach 24 months in Oct 2028
7. Done 18 Oct (656b3da, 107265a): every page but thin matchups (<200 games) has a cached
   copy for outages (warm-up after each version into an unversioned fallback key, ~20
   min a run, 21k pages); one copy per page (Vary ignored); renderer cold start 1.3-16.6
   s from views.bin. Notes: data/team/2026-10-18-cleanup/renderer-done.md. Left: home
   page from the renderer (core build without the DB), a pipeline test for
   /admin/api/pages.txt
8. Done 18 Oct (b966bd7): Your games remembers the last five Riot IDs on the device, "N
   new games since your last visit", per-game links (#id=...&game=<start_ms>), Copy link.
   Next, small: mark the new games in the film strip (CSS)
9. Done 18 Oct (b1ce15b): matchup pages say above the gold chart who is ahead from
   when and by how much (past 2 SE and 200 gold: 2c8e5c1), then how often
   the side ahead at 14 wins; the review opens with the turning minute's sentence (B6,
   R57)
10. Pool first in the picker (B2), then bans from the pool's hard lanes (B3, Q3); public
    form waits on J2. Patch day (B4, z choice below), example review per role (B7)
11. Admin polish (fix3 leftovers R48-R50, R60, R61; plans in docs/review/
    fix3-notes-2026-10-17.md), R58; low while the panel is Jacob's only (J9)

Others own: traffic.sh install and the TW2 mastery retry (meiolol-8f); neural nets vs
today's model; the draft's "Rammus into high AD/AP" check.

### Decisions (Jacob 18 Oct: "follow your recommendations")

Each line was a question with a recommendation; Jacob approved them all. Storage and
hosting still needs him to order. Done: J8 gzip (477a1ff, jomove nginx), G2.

- J1 Daily Draft: drop the numbers; "on paper the draft leaned red" only when clear,
  option reasons in words and only detected kinds (as Learn, R20)
- J2 Public picker signal: tiers "strong fit / also fine / weaker here" with worded
  reasons, "no clear difference" when ranges overlap; safe blind = best low end of win
  against an average pick, lane gold as a reason, not the sort
- J3 Name the three detected cross-role kinds in the tester; publicly the kind ("into
  their bot laner"), never a single pair's number
- J4 Unknown-role shelf: wait until B2's pool block exists
- J5 Drop "116% of the way there"; the admin line cites our honest time-split ceiling
  (53-54%, model.md), the 55-57% only with "random split"; nothing on the public site
- J6 Public "my pool into their pick": a "yours vs theirs" jump on the Matchups index
  now (cheap, aggregate); the pool block after J2
- J7 Desktop app: no date, "after Riot's production review"; no notify list (it would
  keep emails)
- J8 Ops: gzip for /admin/training/ JSON in jomove's nginx (done 18 Oct);
  browser-tool's first commit is Jacob's; "429 (server)" is Riot's side, count it
  apart from our key's limit, no action. Password rotation skipped (your call)
- J9 Admin is for you only: jargon stays low priority
- Q1 Rewrite the application around game review of your own games, lane curves as the
  benchmark; squads worded as planned, or out until built
- Q2 Daily games at least 7 days old; the previous patch's in a patch's first week
- Q3 Ban suggestions in scope: yes, several with games and range, never auto-ban
- Q4 Crawl floor: Gold IV once the key's rate allows (the identity is Silver to Emerald),
  Silver after
- G1 gpu-box lab data: a new ext4 partition in the 673 GB unallocated (keeps your
  Pop!_OS install untouched; you format it and add it to wsl-mount.ps1), not a
  directory on the Pop!_OS partition
- G2 Prune snapshots 2351Z, 1954Z, 2137Z (~36 GB; only cited in learned.md and
  model.md): yes. meiolol-2a, who owned them, is gone, so this is yours
- Patch day movers bar: z 2.58 (fewer, surer movers on a public page)
- Storage and hosting (Open decisions): Hetzner BX11 for backups and old segments plus
  a rolling window on the box; needed within ~a week (item 2)

## Goal now: production key

Product: "scout your own games" (docs/concept.md "Identity draft four", Jacob
2026-10-12; replaces "learn your lane"): the player's own games first, as stats nobody
else shows (game rewind, highlights and on-request record book, scouting report, matchup
notebook, pre-game brief, squads), with the minute-by-minute matchup curves as the
benchmark; Daily Draft, Learn, Pool kept; picks only as several options with reasons.
Crawl is Platinum IV+ only, so "typical" means Platinum+. Research behind it in
research/questions/ (josearch). Production application started by Jacob 2026-10-11 (text
in docs/production-key.md); review takes 3-9 months, Riot looks at the site at review
time, so keep building and keep the site up. Don't edit the application while it queues.

## Where the app goes next, with ~800k games (Jacob, 2026-10-17)

The product stays "scout your own games", with picks as several options with reasons
(docs/production-key.md: no other players' stats in ranked champ select, no "+X% win
rate" wording, no public draft win chance). What the data now supports, and where it goes:

What we know (docs/learned.md "Win"): lane matchups matter most (top and mid ~2 points of
win chance), ally pairs only bot with support; champions lean into team comps beyond
their matchups: 22 clear leans on the shipped model, all about magic damage and
tankiness (Malphite into AP-heavy teams about 1.1 points worse per step, Galio and
Kassadin better; Lillia, Brand, Senna better into tanky teams, Nautilus worse; AD carries
better beside AP allies); champions lean early or late; the draft model still gains with
every doubling of games (54.8% on 17 Oct, no plateau).

In order:
1. Measure the comp leans like the draft model: champcomp's terms as a row in the box's
   daily `meiolol eval` (ported out of the lab into src/, offset the shipped model), then
   one pre-declared held-out look on a snapshot of games after 17 Oct 13:20Z (~24 Oct).
   The same look also takes champgroups' six detected kit groups and Rammus jungle into
   auto-attackers (docs/model.md "Kit groups and a property scan", 18 Oct: their dev
   numbers are the predictions; rerun `meiolol-lab champgroups` on the new snapshot).
   Nothing public before that look passes. Admin Draft tester has them now (17 Oct); its
   draft and lane models refit daily on the box (`meiolol draft-model`, `lane-model`, 17
   Oct); the comp terms still come from the lab (`champcomp --export`, `lab-push.sh use`).
   Blocker for porting them (and for step 2's nightly refit): their champion profiles
   are means of per-player seat stats (damage split, CC, engage, dive, tank, sustain,
   early power) from raw match summaries, which the box keeps ~2 days before the archive
   moves them to the gpu-box; participants holds only the basic columns. Options (for
   Jacob): a per-seat stats table in meiolol.db written at crawl time plus a one-off
   backfill from the archive (recommended: steps 2 and 6 need it too), or profiles from
   the weekly snapshot pushed to the box with the fit daily there (the Mac stays in the
   loop)
2. Champion pages: an "Into which teams" block beside early/late lean: only clear leans,
   plain lines with a range ("about 1 point worse per step towards a magic-damage enemy
   team"), refitted nightly on the box like `meiolol lean`
3. Suggest reasons (app and site draft tool): a comp lean as one reason among an
   option's matchup and duo reasons, only when clear and only champion and aggregate
   statistics, worded as context ("weaker into magic-heavy teams like this one"), never
   as a pick order or a percentage
4. Your games (post-game, own games): "what your draft was up against": the comp leans
   of your own champion in that game, beside the win-chance-by-minute review
5. Daily Draft and Learn: lessons and puzzles built from clear leans and lane matchups
   ("which top laner into this AP-heavy team?")
6. Model work, measured in eval first: separate duo, lane and matchup priors (term
   weights near 1, so shown numbers stay near the data); more traits (range and poke,
   waveclear, scaling) and leans by rank bracket and patch; rerun as games grow (each
   doubling ~-0.0008 log loss)
7. Data and ops (proposal 17 Oct, decisions under Open decisions "Storage and
   hosting"): the box keeps a ~30-day window of games plus per-patch aggregates; the PC
   holds everything, raw pseudonymised (~6 GB a day) and the backups; a Hetzner Storage
   Box (BX11, EUR 3.20 a month) is the off-site copy; raw timelines (88% of the archive)
   reviewed ~mid January against what the compact timelines lack. The production key
   multiplies all of it

Open for Jacob: the storage decisions; whether comp-lean reasons may appear in the
desktop app in champ select once the held-out look passes (policy allows options with
reasons; the app shows champion and aggregate stats only)

## How we work

Several Claude sessions in parallel, all on main in the one checkout (Jacob,
2026-10-11: no more branches or worktrees). Commit, push and deploy rules: CLAUDE.md
"Git and deploys".

Until the site goes public (Jacob, 2026-10-11): sessions merge, push and redeploy the
preview site and box binary without asking. Still ask first: anything irreversible
(deleting data, key or registration changes, Riot applications), nginx/systemd changes on
the jomove server, changes to Jacob's Mac. Live DB migrations: backup and rehearsal on a
copy first.

Jacob's standing asks: the coordinator reviews regularly for gaps nobody owns (risks,
safety nets, doc requirements with no work behind them) and hands out work. Close a
session once it passes ~30% context: it commits, reports done/next/questions, and its
next steps land here.

Team size (lesson of the 13-14 Oct night, ~60 sessions, 396 commits): 4-5 agents at
once. Beyond that, coordination ate the gain: name clashes, a whole snapshot's runs
voided by a mid-night re-cut, the gpu-box at load 41-58 on 20 threads (jobs 5-10x
slow), by-path commits sweeping in other sessions' hunks. Fix the split and pin before
starting runs on a snapshot, not during.
Unattended runs (17 Oct night): the Mac slept at 22:33 and killed the fix agent
mid-turn, and a usage limit stopped two agents at 21:44. Start the coordinator under
`caffeinate -i`, keep team notes in data/team/ (CLAUDE.md), and long box jobs in
systemd units, not a foreground ssh.

Neural nets paused (14 Oct): big, small, set and embedding nets only draw level with
ratings at 2253Z, and research (draft-predictor-methods, gnn-match-outcome) puts the
lever in data volume. Next net run: one rerun of the reference nets on the next re-pin
(due when the crawl passes +50% of 2253Z's 363k played games, ~545k on the box, about
15 Oct), against additive v2 as well as ratings. Big net's test look: not yet. Work
goes to shipping what won (additive v2 in the Draft tester since 14 Oct 21:08, the
in-game state model) and to the production review list.

## Before the production review

- Privacy/terms into src/site/prose.zig from docs/legal once Jacob fills the placeholders;
  objection by email (`meiolol forget`) until the form is live
- Site polish: reviewer walk 2026-10-14 (desktop and phone, every section): fixed
  38b940f, 145a898, bbda65c (padding under the preview bar, chart text size, matchup
  index default 50+ games, build index 404, thousands, lookup note instead of the
  browser's sign-in prompt); b37dd02 (Daily Draft numbers follow the stats while the
  puzzle's patch is current, answers never change), 74d6cdb (no "Costly death" when the
  team's chance rose; the live example refreshes with the pushed binary's daily
  your-example run), ab7d4cc (Learn: "Not started" on a first visit). Screenshots:
  docs/review-shots/. Left: unknown URLs get a plain-text "not found" from
  meiolol-render (a site 404 page needs nginx error_page); docs/your-games.md "The
  browser asks once" is now a note with a sign-in button (145a898). GIFs and a short
  demo video still to do
- Desktop: lane card built (docs/architecture.md "Desktop window"; `zig build
  desktop-shot` for PNGs). First Windows run 2026-10-14 on the gpu-box (Windows 11 Pro,
  two 1080p screens at 100%; docs/review-shots/windows-desktop-window.png): opens, per
  monitor DPI aware, fonts crisp, resizes and closes cleanly; D3DCOMPILER_47.dll is in
  System32 on Windows 10/11, nothing to ship. Fixed (2911db5): idle 9.6% of a core and
  6% GPU (dvui's dx11 main drew every vsync) to 0.3% and 0, and a PowerShell process
  list (~1.5 s CPU each) every ~2 s while the client was closed. Memory: ~470 MB private
  with EUW recent-curves (158 MB; whole files held, the all-region one is 288 MB).
  Not checked: 150% (set a display to 150% and open the exe) and the card itself.
  Jacob, in a real champ select, from C:\Users\jacob\meiolol-desktop-test (exe,
  meiolol-app.exe, stats-all.bin, v5 recent-curves.bin): open meiolol-desktop.exe and
  run `meiolol-app.exe session --save session-real.json`, then copy that file to
  testdata/lcu/session-real.json (check mastery and ranked replies parse). Not yet:
  your own record in the matchup (concept part 6; LCU match history, needs a real reply
  to fix the schema), champion icons, window icon (title bar shows dvui's), the download
  page shipping the exe with stats and curves. DPI manifest not needed: the window
  already reports per-monitor awareness
- Zig 0.17 move: done 2026-10-12 (docs/zig-0.17.md). dvui: pin PR #1012 (0.17.x
  branch) until it merges; ZLS built from its main until a 0.17 release


Older next steps by area (ops and data, Your games, curves, builds, Learn, draft model,
compute, site build and deploy, ideas), written 11-17 Oct before the Now ranking:
docs/backlog.md. Some are done; check before acting, and move what you pick up into Now.

## Open decisions (Jacob)

- Legal: retention periods (docs/legal/privacy.md top). Decided 14
  Oct: controller "Jacob Maschler, trading as meiolol", contact privacy@meio.lol
  (Namecheap forward to add)
- Alerts and backups: an ntfy topic for phone alerts (NTFY_TOPIC in .env; the health loop
  only logs until then); install the Mac job (`deploy/box.sh watch install`: notifications
  + backup mirror); ok to delete de's pre-deploy copies in ml/meiolol/backup (1.8 GB)
  after a second nightly backup
- Squads as private invite-link pages with Riot IDs shown to members only
- Budget for EUNE/TR/RU/ME in the europe bucket (EUW takes it all while it has players due)
- Patch day movers bar: z 1.96 or 2.58
- Indexing (which pages and view search sees): open, decided on evidence of clicks
- Name/domain: "lol" in name and TLD is a mild Riot-trademark risk
- Storage and hosting (research/questions/free-hosting-storage.md): (1) Hetzner Storage
  Box BX11, 1 TB for EUR 3.20/month, for off-host backups and old segments (~1.5 years
  at full rate; B2 $6.95/TB second; no free option holds this); (2) keep a rolling
  window of match data on the box instead of everything (recommended, also less
  personal data kept); (3) Oracle Pay As You Go: still free within limits, A1 capacity
  sooner, paid disk possible; (4) ok to delete the unattached April 47 GB "Jomify (Boot
  Volume)" to free block storage. GitHub/Hugging Face ruled out: size limits, "not a
  backup tool", erasure from git history impractical

## Reference

- Hosting: jomove server (Oracle uk-london-1, `ssh jomove`: alias in the Mac's
  ~/.ssh/config for ubuntu@193.123.180.81; jomove's own nginx config: leave alone).
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

## Ruled out (do not revisit without new facts)

- Multiple keys or friends' keys to multiply limits: against Riot's terms, risks the
  production application
- A second "decoy" app to get a key for meiolol's data: one product per key
- lolalytics/op.gg/u.gg scraping, old datasets, pro play data: docs/data.md
- Replay-file analysis: Riot locked replays from 26.20 (research)
- Python: Jacob wants Zig for everything, including training if feasible
