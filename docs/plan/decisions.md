# Plan: decisions

What Jacob decided, what is still his to decide, and what is ruled out.

## Decided (Jacob 18 Oct: "follow your recommendations")

Each line was a question with a recommendation; Jacob approved them all. Storage and
hosting still needs him to order. Done: J8 gzip (477a1ff, jomify nginx), G2.

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
- J8 Ops: gzip for /admin/training/ JSON in jomify's nginx (done 18 Oct);
  browser-tool's first commit is Jacob's; "429 (server)" is Riot's side, count it
  apart from our key's limit, no action. Password rotation skipped (your call)
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
  most played; others stay easy to read. Keep the in-game rune view and its highlight
- J14 (20 Oct) Clickable things are the whole box (matchup rows, champion tiles,
  cards), not just the name: site-wide
- J15 (20 Oct) Admin Overview tile shows the shipped model; experiments stay visible
  and testable beside it, labelled. One rule everywhere
- J16 (20 Oct) Crawler target 99-100% of the key's limit (now ~97%)
- J17 (20 Oct) CI much lighter: lighter heavy tests and lab tests out of the push check
- J18 (20 Oct) Other players' names on public pages: yes, rewrite lia.md balancing;
  hide streamer-mode players if op.gg and other big sites do
- J19 (20 Oct) Desktop download on the site for Jacob (admin login until the key, per
  Product rules); data in it kept fresh. 09:05: "it should update its own data without
  needing to be redownloaded, even update itself ideally with changes": the app fetches
  stats and curves from the site itself and replaces its exe (version file, download,
  swap on next start), behind the admin gate (the zip's own key) until the key
- J20 (20 Oct) "pbr" on the champions pages means a PBI-style ban impact, "the most
  optimal ban in terms of pick rate and win rate": lolalytics' PBI with small samples
  pulled toward the average, worded "ban impact" (Product rules: no "best ban")
- nn on the GPU: planned, not now
- Q1 Rewrite the application around game review of your own games, lane curves as the
  benchmark; squads worded as planned, or out until built
- Q2 (dropped 20 Oct by J10) Daily games at least 7 days old; the previous patch's in a
  patch's first week
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

- Night run 19-20 Oct questions (team notes data/team/2026-10-19-night/<agent>.md):
  - Champion/matchup: "vs usual" quiet for most matchups (-3 to +2 on big ones): fine,
    or a wider range shown? Opponent grid mostly grey now that only vs usual is
    coloured: wanted? Matchup CS split "about 20 gold a CS" clear, or raw CS and gold?
    Matchups index lists 50+ game pairs only (page weight): fine? "% won" on build
    options: ok, or games and share only?
  - Your games: moments list, keep all or only those that moved win chance? "(lane)"
    after the lane opponent's name clear? Last player reopens on every visit, or only
    within a day?
  - Daily Draft: items and summoner spells on the scoreboard too? Keep the "Blue wins it
    more" lane chip (draft model's lane edge, words only)?
  - Learn: keep the old lessons as "Basics"? Daily streak on Learn or Daily Draft?
    Levels lock or stay pickable? (docs/learn-proposal.md is the redesign)
  - Site: preview banner as a slim strip or a header badge? Blue means both "good" and
    "your side" in review and Daily Draft: ok?
  - Privacy (docs/privacy-rules.md "For Jacob"): other players' names on public pages
    (Daily Draft, Your games teammates): lia.md balancing needs rewriting and streamer
    mode players must stay hidden; retention lengths; ICO fee and EEA representative
  - Desktop: lane card gold coloured by sign alone or only 2 SE from even? Refresh or
    drop data/desktop (v4 curves)?
  - jomify: "Tešter#EUW" was looked up by a test and is stored (ages out in 30 days);
    `meiolol forget` it now?

## Ruled out (do not revisit without new facts)

- Multiple keys or friends' keys to multiply limits: against Riot's terms, risks the
  production application
- A second "decoy" app to get a key for meiolol's data: one product per key
- lolalytics/op.gg/u.gg scraping, old datasets, pro play data: docs/data.md
- Replay-file analysis: Riot locked replays from 26.20 (research)
- Python: Jacob wants Zig for everything, including training if feasible
