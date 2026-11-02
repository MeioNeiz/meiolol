# Bot lane as a pair (duo pages)

No rival shows how a support and ADC pair's lane goes (data/team/2026-11-01-live-notes/
walk-rivals.md S2, item 5); u.gg, LoLalytics and op.gg have pair win rates only. We have
every bot game's minute by minute gold, so a pair lane curve is ours alone.

## Stats

Unit: a pair, one side's ADC and support (Role.bottom + Role.utility of one game). From
the day cubes' lanes (cubes.Store.read, no cube format change): a game's bottom and
utility Lane, blue's as a. Pair minus the enemy pair, per minute 1..25: gold, XP and CS
of both lanes summed. Per cell:
- games, wins; games reaching minute 14, pair ahead in gold then, wins when ahead
- per minute: n still going, mean, p25, p50, p75 of each metric (full curves only)
- first blood: games where either of the pair took part in the game's first kill
- gold at 14: mean and sd (for the 95% range)

Cells, all from the pair's side:
- pair against everyone (full curves)
- pair against one enemy ADC, against one enemy support, against one enemy pair (summary
  only: games, wins, ahead at 14, gold at 14 mean and sd)
- each champion against everyone, with any partner ("Jinx with anyone"): the pair beside
  both solo numbers, as u.gg's pair row; the gap is the pair's own part

Raw means with a 95% range, no shrinkage in v1; under 200 games faded as on matchup pages
(matchup.thin_games). The curvefit-style shrinkage (pair = ADC + support + own part) is a
lab step once pages exist.

### Games per cell (measured 2 Nov)

data/snap, 16.19 + 16.20 all regions, 85.6k games (participants.gold14 for the sd):

| Cell | distinct | from 7 games (lanes covered) | from 25 games |
| --- | --- | --- | --- |
| pair | 6,372 | 2,124 (95%) | 1,085 (87%) |
| pair vs enemy ADC | | 5,475 (56%) | 936 (25%) |
| pair vs enemy support | | 5,299 (46%) | 608 (15%) |
| pair vs enemy pair | 136,596 | 650 (4%) | 22 (0.4%) |

sd of the pair's gold at 14: 2,230 (one ADC alone: 1,670), so 200 games give +-310 at 95%.
The box's 30-day all-regions view has ~24x the snap's games (2.1M timelines), EUW ~6x.
At 200 games: all regions about 2,000 pairs, 5,000 pair-vs-ADC and pair-vs-support cells
and ~600 pair-vs-pair cells; EUW about 900 pairs and 600 pair-vs-ADC. So pair and pair
against one champion carry the page; pair against pair is a short list of common lanes.

## Build

- src/core/pairfile.zig: format (magic MEIOPAIR, version), Builder, reader; cells sorted
  by key, full curves only for pairs from min_games (10, as curves). Size estimate: 2k
  pairs x 25 min x 3 metrics x 4 values x 2 B = 1.2 MB, summaries ~30 B a cell
- src/pairlane.zig: `meiolol pairlane` (--site: EUW and all regions, 30 days; --patch),
  one pass over the day cubes like cubes.curvesFrom, writes
  data/export/{,all-}recent-pairlane.bin
- src/pipeline_test.zig: fixture games through the builder, the file and both pages
- Web loop: a daily job beside lean (deploy/web-loop.sh, shared: ask first)

## Pages

/duos/<adc>-<sup> rendered on request like matchup pages (data in data-bin), each view;
/duos index. Words "duo" (what players and rivals call the pair).

First screen:
```
ChampHeader pair   [Jinx][Thresh]  Jinx + Thresh         region | period
StatStrip          51.8% wins | +310 gold at 14 | 56% ahead at 14 | 1,204 games
                   | +180 vs apart (Jinx +90, Thresh +40 with anyone)
LaneChart          duo minus enemy duo, Gold | XP | CS, band = middle half
```
Then:
- Against: three lists by games (never by win rate), each row an opponent icon (two for
  a duo), games, gold at 14, ahead at 14, wins; Enemy ADCs | Enemy supports | Enemy duos
- Partners strip (MatchStrip): Jinx's other supports, Thresh's other ADCs, by games: the
  way to switch duo
- Index: DataTable of duos by games: duo, games, wins, gold at 14, ahead at 14, vs apart

Components: ChampHeader, StatStrip, LaneChart, MatchStrip, DataTable, Segmented; a new
DuoRow only if the Against lists need two icons in one cell. One new island family,
under 40 KB gz.

Links in: champion page With card and bot/support matchup pages' lane partners
(champpage lane), header search ("jinx thresh"): asked of their lanes when the page lands.

Product rules: plain numbers, no "best duo", no tiers, order by games.
