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

## Ruled out (do not revisit without new facts)

- Multiple keys or friends' keys to multiply limits: against Riot's terms, risks the
  production application
- A second "decoy" app to get a key for meiolol's data: one product per key
- lolalytics/op.gg/u.gg scraping, old datasets, pro play data: docs/data.md
- Replay-file analysis: Riot locked replays from 26.20 (research)
- Python: Jacob wants Zig for everything, including training if feasible
