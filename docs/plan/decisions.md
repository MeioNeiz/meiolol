# Plan: decisions

What Jacob decided, what is still his to decide, and what is ruled out.

## Decided

J1-J9, Q and G: questions with a recommendation, all approved (18 Oct: "follow your
recommendations"). A later decision that overrides an earlier one says so.

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
- J8 Ops: gzip for /admin/training/ JSON in jomify's nginx; browser-tool's first commit
  is Jacob's; "429 (server)" is Riot's side, count it apart from our key's limit, no
  action. Password rotation skipped (your call)
- J9 Admin is for you only: jargon stays low priority
- J10 (20 Oct) Public games are public data: drop self-imposed privacy rules (Daily
  Draft week delay, no per-player stats or ranks, "no names" style anonymising) across
  the codebase and docs; keep only what law (GDPR: erasure, privacy page true) or Riot
  policy actually requires. Numbers may come back where they help (with counts)
- J11 (20 Oct) Small leads: coordinator's call (one rule site-wide, the matchup page's:
  under 200 gold at 14 reads as even, plus the 2 SE and games test)
- J12 (20 Oct) Win rates: always show the number, even when close ("about even" hiding
  is more confusing); colour every champion win rate, no grey "quiet" cells. Overrides
  J11's "reads as even" text (keep the games and range test for emphasis only)
- J13 (20 Oct) Runes and build options: show pick rate and win rate together; highlight
  the highest win rate among options with enough games (not raw highest wr), alongside
  most played; others stay easy to read. Keep the in-game rune view and its highlight.
  No mark on boots and finished items, whose win rates mostly say how the game was
  going when bought (loltheory-item-recs ^f3)
- J14 (20 Oct) Clickable things are the whole box (matchup rows, champion tiles,
  cards), not just the name: site-wide
- J15 (20 Oct) Admin Overview tile shows the shipped model; experiments stay visible
  and testable beside it, labelled. One rule everywhere
- J16 (20 Oct) Crawler target 99-100% of the key's limit
- J17 (20 Oct) CI much lighter: lighter heavy tests and lab tests out of the push check
- J18 (20 Oct) Other players' names on public pages: yes, rewrite lia.md balancing;
  hide streamer-mode players if op.gg and other big sites do
- J19 (20 Oct) Desktop download on the site for Jacob (admin login until the key, per
  Product rules); data in it kept fresh: "it should update its own data without
  needing to be redownloaded, even update itself ideally with changes": the app fetches
  stats and curves from the site itself and replaces its exe (version file, download,
  swap on next start), behind the admin gate (the zip's own key) until the key
- J20 (20 Oct) "pbr" on the champions pages means a PBI-style ban impact, "the most
  optimal ban in terms of pick rate and win rate": lolalytics' PBI with small samples
  pulled toward the average; the column is "Influence" (Jacob: a word without "ban";
  Product rules: no "best ban"); scale: games won above the role's average per 10,000
  games it was not banned, whole numbers (Jacob: "a different scale to lolalytics but
  just something smart"; per 1,000 most rows read 0.0 to 0.4)
- J21 (22 Oct) Two apps and accounts: a public app in line with Riot's rules and a
  private, fuller one ("op" app and site) for Jacob and friends. Proper logins: Jacob's
  own account; friends a tier below admin who can't break anything. Roles: public,
  paid, private, admin, owner (Jacob). Plans:
  docs/plan/accounts.md, docs/plan/app.md; open points in accounts.md AC0
- J22 (22 Oct) Private tool: everything Riot allows; no ads in game, no auto accept,
  pick or ban (not wanted). Not built in any tier: names or stats of others in ranked
  solo/duo champ select, streamer-mode players, live enemy cooldowns, live alerts and
  prompts (unfair advantage over other players, Vanguard risk to friends' accounts, the
  key at stake). In game means an info panel through the game (app.md "In-game
  companion")
- J23 (22 Oct) Every block respects the filters it sits under or says clearly that it
  doesn't. Three data modes: last 30 days, newest patch, and an estimate from every game
  (old patch moved by the changes, every rank adjusted to the one picked), name to pick;
  trust first, so how it is made must be plain. Rank picks use all data plus how ranks
  differ, not only that rank's games. Per region later. docs/plan/estimates.md
- J24 (22 Oct) Understanding the data is the product's edge over every other stat site:
  patch by patch, season by season, rank by rank. Show every view (30 days and newest
  patch were only the start), each honest about its scope, plus our estimate from every
  game; build the models on the same understanding so they beat anyone's. A lens for
  every plan step: docs/plan.md "Our edge", docs/plan/estimates.md
- J25 (23 Oct) Mostly analyse the latest patch, kept simple: models are evaluated on
  latest-patch games only; old patches only adjust the model while the latest patch has
  too few games to train and evaluate. No backfill of older patches: crawling more
  recent games does more for accuracy (docs/plan/patch-transfer.md)
- J26 (23 Oct) Daily Draft shows "much more info in a nice view of what champ should
  have got picked and what champ should have won", and pick shares with no 10-player
  minimum. Overrides J1 for the Daily Draft: win chances with their 95% range, the
  model's picks and every pick rated, words "the model's pick", never "best pick"
- J27 (23 Oct) "Models need to be optimised per region, probably EUW, and patch diff
  needs to show why". Models are tuned and scored for one target region, EUW first,
  still fitted on every region's games (patch-transfer.md PT6). The Patch changes page
  says why each champion moved: what the patch changed for it (site.md PC1-PC2)
- J28 (24 Oct) "I always want to use older patch games as well with some good
  techniques for correcting between each patch". Overrides J25's switch to latest patch
  only once it fills: the model always pools old patches plus a patch correction; still
  scored on latest-patch games (patch-transfer.md)
- J29 (24 Oct) Front end from the ground up, long term: one UI for the site and the
  desktop app; components and the stack under them decided on evidence, nothing kept
  because it exists ("dvui was a very early decision"); a plan per page and Jacob's
  review before building; new features built the new way. Review:
  docs/review/page-review-2026-10-24.md; direction: docs/frontend.md
- J30 (25 Oct) UI plans reviewed (42 answers, each plan's "Jacob's answers" section):
  one UI for site and desktop, the webview's extra 200-290 MB accepted; efficiency and
  page speed over dev ease; whole-pixel type; contextual builds (filter the build by
  chosen runes and items) are a planned feature with their own data design. Mocks read
  plain or clunky in places: a visual pass on the gallery before pages are built
- J31 (26 Oct) meiolol leaves Oracle for Ethan's VM C01, all of it, benchmarked on the
  real data before the switch so it is no downgrade; jomify stays for jomove only.
  Storage: C01's 60 GB disk plus Megatron, not a new local disk (docs/plan/vm.md)
- J32 (28 Oct) Professional URLs: Jacob's hierarchy (/champions/<c>/<role>,
  /matchups/<role>/<a>-vs-<b>, no .html, 301 from every old URL) plus the five
  additions in docs/plan/urls.md; built after the notes run
- nn on the GPU: planned, not now
- J33 (30 Oct) Squads: yes, a minimal public form (invite-link pages, noindex, Riot IDs
  shown to members only, games together, weekly recap), built later, once a lane frees
- Q1 Rewrite the application around game review of your own games, lane curves as the
  benchmark; squads worded as planned, or out until built
- Q3 Ban suggestions in scope: yes, several with games and range, never auto-ban
- Q4 Crawl floor: Gold IV once the key's rate allows (the identity is Silver to Emerald),
  Silver after
- G1 gpu-box lab data: a new ext4 partition in the 673 GB unallocated (keeps your
  Pop!_OS install untouched; you format it and add it to wsl-mount.ps1), not a
  directory on the Pop!_OS partition
- Patch day movers bar: z 2.58 (fewer, surer movers on a public page)
- Storage and hosting: C01's disk, Megatron the off-site copy (J31, vm.md VM8); no
  BX11, no rolling window on the box

## Open decisions (Jacob)

The one list: each with the recommended answer. Plan files point here.

Unblocking work:
- Phone alerts: a private ntfy.sh topic as NTFY_TOPIC in .env (health-loop.sh pushes
  once it is set). Recommended yes; Jacob 30 Oct: not now
- gpu-box: Windows Tailscale login (jmw) and WSL's sudo for Tailscale there, so its
  backup mirror and archive pull run again (stale since 28 Oct). Recommended: when the PC
  is on
- Revised application text (production-key.md): don't paste while queued (editing
  reportedly resets the queue); keep it for Riot's reply
- 16.21 frozen test look (patch-transfer.md, code frozen f58587b6): go when the gpu-box
  is on
- Comp leans' blocker (data-and-model.md step 1): a per-seat stats table in meiolol.db
  written at crawl time plus a one-off backfill from the archive. Recommended yes
- Old /private tester: an index first, the old tester at /private/old/ until
  /private/tester has its features (coordinator's pick; stands unless Jacob says)
- W9 note 39 (Daily streak pips): look at its shots (on the PC), then merge
  wip/pc-2026-10-30/w9-note39
- Portraits as one 120 px AVIF: avifenc in the art pipeline and libavif-bin on C01, no
  fallback for non-AVIF browsers. Recommended yes to both
- BS3: ci, pre-push ci and deploy builds on the gpu-box when free (build-speed.md).
  Recommended yes once the PC is on reliably
- ~50 stale worktrees (all on wip/mac-2026-10-29-wt/*): prune. Recommended yes

Product:
- Champion page CH0: (d) trends by patch, by day only inside the newest patch; (e) no
  blind-safe score (J2 measured no win), rune rows by melee or ranged opponent yes,
  purchases by gold lead later
- Estimates E0: name "Meio"; default stays 30 days until E2 holds two patches; EUW and
  every region now
- Lab P3 test-look rule (lab-frontier.md): accept as written (2004Z's test, the ladder
  as listed, comp leans on win-draft as declared)
- Comp-lean reasons in the desktop app's champ select once the held-out look passes:
  yes, as context words, never a percentage or an order
- Pick-up difficulty somewhere general again: a column on the champions index
- Pool page keeps the chosen mains in the browser: yes, like Your games' last player
- Your games "the top": what exactly? A note on the live page with the notes tool
- Desktop lane gold colour: only 2 SE from even (as arch-app.md and the app's pills)
- Later pages, not blocking: ui/contextual-builds.md Q1-3 (an aggregates service first,
  rows to the browser only after the key), ui/rankings.md Q1-2, ui/why.md Q1-3: the
  plans' leans

Hosts, legal, ops:
- Oracle box (stopped, kept for a benchmark): terminate once the benchmark is recorded;
  delete the unattached 47 GB "Jomify (Boot Volume)" now
- AC4 desktop sign-in cut-over: release an exe with sign in now (step 1), testers sign
  in, then the key line goes from C01's nginx; AC0: who gets the first private accounts
- Privacy: retention periods as docs/legal/privacy.md drafts them; ICO registration
  before the production review; an EEA representative only once EU users are targeted
- Old-box leftovers: de's 1.8 GB pre-deploy copies in ml/meiolol/backup: delete
- EUNE/TR/RU/ME budget in the europe bucket: EUW first until the production key
- Name and domain: keep meio.lol (the application quotes it); indexing stays open,
  decided on evidence of clicks
- The night run's page questions (19 Oct): closed, the rebuilt pages answered most;
  re-ask any still live through the notes tool. "Tešter#EUW", looked up by a test:
  `meiolol forget` it now

## Ruled out (do not revisit without new facts)

- Multiple keys or friends' keys to multiply limits: against Riot's terms, risks the
  production application
- A second "decoy" app to get a key for meiolol's data: one product per key
- lolalytics/op.gg/u.gg scraping, old datasets, pro play data: docs/data.md
- Replay-file analysis: Riot locked replays from 26.20 (research)
- Python: Jacob wants Zig for everything, including training if feasible
- Champions table "Hard lanes" column (3 hardest opponents' icons a row): Jacob "dont
  like that"
