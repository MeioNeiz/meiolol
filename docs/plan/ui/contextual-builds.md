# Contextual builds (design note, not built)

Jacob (builds.md answers 2): choosing a rune or one or more items filters the rest of
the BuildPanel to games with that choice ("with Conqueror, what do people buy"), as
LoLalytics. This note: conditions, data shape, sizes measured on the box (26 Oct), how
the panel asks, cost per web round. Builds pipeline as it is: docs/arch-stats.md
"Builds".

## Measured (box, 26 Oct, read-only)

- Last 30 days, Platinum+ player rows (one per player and game; builds files'
  totals): EUW 4.17M, every region 18.3M; 862 champion-roles. Crawl rate now: 251k EUW
  rows a day (3-day sample), so a full 30 days is ~7.5M EUW, ~33M every region
- Rows per champion-role, EUW 30 days at today's rate: median 670, p75 6.6k, p90 32k,
  p99 78k, max 132k (Jhin bottom). Every region ~4.4x
- Conditions with 400+ games (solid_games) per champion-role with 400+, EUW 30 days:
  keystone 1.7 on average (737 in all), first item 1.7+ (703+, from core2's top 10, so
  a floor), first two items 2.9 (1,216), boots 2.2, spells 1.7. Every region: keystone
  2.5, core2 3.7
- Row encoding (3-day EUW sample, 754k rows, 871 files): one file per champion-role,
  columns of dictionary indices (most common value 0), gzip 9: rune page, shards,
  spells, six items, win, rank bracket, day = 5.4 B a row. Start, boots, skill order and
  skill path add ~1.0 B (from the builds file's distributions, drawn independently, so
  an upper bound). Purchase minutes of 7 items add ~4.3 B: left out (below). So ~6.4 B
  a row gzipped
- Today's champion build island: darius-build.bin 41.8 KB, 5.5 KB gz; jinx 3.7 KB gz

## Conditions

Every option in every cell can be a condition: keystone, any rune or shard, spells,
start, boots, item 1 to 6 by order, "built X" (any slot), skill order. Several at once
are ANDed; one per slot (a second tap in a slot replaces). Rows make all of these the
same cost, so no list to choose. The panel says the context's games; under rate_games
(100) it shows "too few games with these choices" and keeps the chips.

## Options

| | A: precomputed single conditions | B: rows per champion-role to the browser | C: query service on jomify | D: E7 day cubes with a condition key |
|---|---|---|---|---|
| What | box writes a panel per champion-role and condition with 400+ games | box writes each champion-role's game rows; wasm counts in the browser | rows on jomify, an endpoint answers a filtered panel | A's counts per day, so periods and ranks sum |
| Joint choices | no | yes | yes | no |
| Rank, patch in window | x4 files per rank floor | free (columns) | free | free |
| Site files | ~3k panels x ~3 KB gz = ~9 MB a view, x4 views; x4 again for ranks: ~150 MB | EUW 48 MB gz uncapped (max 800 KB a file); capped at the newest 30k rows: 36 MB, max 192 KB; every region capped 59 MB | none new; answers 2-5 KB | as A, per day |
| First tap | one ~3 KB fetch | one fetch, median 4 KB, p90 ~190 KB; later taps instant (<5 ms in wasm) | a round trip per tap | as A |
| Box | builder keys x4 (per-matchup builds cost ~1.1 GB a builder) | rows written in the pass that reads the games anyway; no hash map | as B, plus a daily upload of ~15 MB | heavy: counts x conditions x days |
| New moving parts | none | a rows file and a counting module shared by box and wasm | a service on the micro (1 GB RAM beside nginx, Your games, jomove), cache, abuse limits | the cube format |

## Recommendation: B, rows, on E7's footing

- Box: the builds pass writes one rows file per finished day (data/rows/builds-<day>.bin:
  per player and game the build fields, rank bracket, platform, patch, win; sorted by
  champion, role, platform; no match id, no PUUID). ~80 B a row raw, ~15 MB a day gz
  every region at today's rate; 60 days rolling ~0.9 GB (80 GB free). This is E7's builds
  layer: builds --site then sums rows (seconds) instead of rereading 30 days of timelines
  (266 s wall today), and the matchup and rank builds come from the same rows
- Site: per region scope (root = EUW, all/) a file per champion-role,
  data/champion/rows/<slug>-<role>.bin: the newest 30k rows of the last 30 days, columns
  as measured, the dictionaries (ids only; names and icons are already on the page), the
  shrink k per kind (E6). Default panel unchanged (-build.bin, first paint as today)
- Minutes stay role-wide: the Minute column in a filtered panel shows the unfiltered
  median, said in the column's Toggletip (+4.3 B a row otherwise, x1.7 the file)
- Counting: one module (core, e.g. src/core/buildrows.zig) both the box and the wasm
  use, so a filtered panel with no conditions equals the default panel on the same rows
  (pipeline_test checks it). Aggregation over 30k rows in wasm: well under 5 ms
- Cap: a context over the newest 30k rows is a slice of the default panel's games;
  the scope chip says "newest 30k games" on the champion-roles it touches (~100 of 862
  in EUW, most of the big ones in every region)

## BuildPanel

- Each option row gets a filter tap (the row's icon; "all" still opens the cell). On
  the first, ui-champbuild fetches the rows file through the Loader (as the other
  views' files), and a small island module (its own wasm if it passes 40 KB gz with
  the panel) builds the same BuildPanel data from the rows
- The chosen options show as Chips above the cells ("Conqueror x", "Black Cleaver 1st
  x"), the context's games beside them; Esc or each chip's x removes it. The chosen
  cell keeps its rows with the choice marked
- The region, period (30 days or the newest patch inside them) and rank picks filter
  the rows too, so a filtered panel follows every pick (E8 for builds)
- Hash: `#top/f=ks8010,i1-3071` so a link keeps the context

## Cost per web round

- Daily (as builds --site): read 30 day files (~450 MB gz every region), write ~1,700
  rows files: ~1-2 min CPU niced, estimate; upload ~95 MB (36 EUW + 59 every region),
  so only in the daily round, not hourly. Memory: a k-way merge over day files sorted by
  champion-role, one champion-role in memory at a time
- jomify: ~95 MB more site per day, served static and gzipped

## Not done here

- Measured: participant columns on real rows. Estimated: timeline columns (independent
  draws), the box's write and read times, every-region sizes (EUW x4.4)
- Not checked: production-key.md on shipping per-game rows (no ids, but finer than
  aggregates); forget (data-safety.md "Erasure") would need rows rebuilt or the forgotten
  player's rows dropped at write

## Questions for Jacob

1. Rows to the browser (B, recommended) or a query service on jomify (C, exact and
   uncapped, a new service on the micro)?
2. Cap at the newest 30k games per champion-role, or the whole 30 days (EUW up to 800
   KB, every region up to 4.2 MB on a first tap)?
3. Filtered tables without a filtered Minute column: fine?
