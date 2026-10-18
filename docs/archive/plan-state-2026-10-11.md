# State on 2026-10-11 (moved out of docs/plan.md, 18 Oct)

Stale: the box, crawl rates, disk and site have all moved on (docs/hosting.md,
docs/architecture.md). Kept for the record.

- Keys: personal app MEIOLOL (890240), key in .env (`jodrive riot key --app 890240
  --env-file .env`), no expiry. New key = new PUUIDs (players re-seeded). Dev key, if
  ever needed: standing ok to regenerate (`jodrive riot key --regenerate --submit
  --env-file .env`, captcha in a window, old key dies at once, new one live in ~2 min)
- Box moved off the gpu-box PC to Oracle Cloud (2026-10-11 ~05:30 BST, docs/hosting.md):
  stopgap 1 GB micro `meiolol-cloud` until A1 capacity (retry loop running); crawl.args
  is plain `--reserve 20` (default raw windows, 30 d / 7 d); first backup there 04:00Z 2026-10-12, on its own
  disk only (no migrations, f90a5ad; no second run on restart); off-host target: Jacob;
  gpu-box data + D: backup kept as the restore point. Crawler stable since 7320adf
  (migrate once per process) but slow: ~11k matches/day (gpu-box ~135k), 153 lock
  waits in 27 min, europe 0 timelines in that run; the 1/8-OCPU micro (~20% steal, slow
  disk) with 19 writer threads is the bottleneck. A1 launch retry now runs on the box
  (systemd user service meiolol-a1-launch, instance principal, ntfy on success)
- Crawler (box, deployed 6f6b65b): all 15 platforms, 4 regional buckets at their caps,
  ~33k matches + timelines/day per region (europe EUW-first), compact timelines
  (timeline.db, ~8.5 KB/match), raw summaries kept 30 days, raw timelines 7, compact
  mastery, participants with items/runes/rank snapshot/gold10/14/15. Privacy in the
  crawler: 30-day unseen expiry, players Riot 404s deleted, PUUIDs blanked after 24
  months, plain-PUUID `forgotten` honoured. Per-match errors non-fatal
- Site (https://meio.lol, preview mode, riot.txt served): "Learn your lane"
  landing, matchup curve pages (empty until timelines accumulate), Daily Draft, Learn
  (lessons + practice drafts), Pool, learning curves, comeback odds, method page. Win-rate
  edges gated by game counts (draft-model thresholds)
- Your games live on jomify in preview (`meiolol api`, /api/ open without login since 17 Oct for Riot's reviewers, 30-day
  retention; docs/your-games.md). Built, not wired: Patch day core (src/patchday.zig); data safety (`meiolol backup|restore|forget`,
  deploy/health.sh) running on the box (meiolol-backup, meiolol-health)
- Draft model (docs/model.md): at ~8k games nothing beats champion base rates beyond
  noise; daily eval on the box appends data/eval-history.tsv
- Legal drafts: docs/legal/ (privacy, terms, LIA, objection form), waiting on Jacob
- Desktop app: lane card window built (meiolol-desktop.exe, dvui dx11, 2026-10-12),
  checked only as PNGs from the raster backend; never run on Windows or against a real
  champ select
- Disk: the micro has ~40 GB free; ~1.6 GB/day kept forever at the full all-region rate:
  weeks. A1 (up to ~150 GB free), EUW-only or paid disk (PAYG): Jacob's call
