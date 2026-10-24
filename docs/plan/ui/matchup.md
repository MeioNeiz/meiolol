# Matchup page (matchup/<role>/<a>-vs-<b>.html)

Plan only (team run 2026-10-24-ui). Mock: data/team/2026-10-24-ui/mocks/matchup.html.
Same page type as the champion page (champion.md): same header, pickers and build
panel; read that first.

## Identity

One lane pair from one side: who wins, how the lane goes minute by minute, and how to
build into it. Nobody else has this page (docs/champion-matchup.md): their "matchup" is
the build page filtered to an opponent.

## Who comes and why

- Champ select or loading screen: "I'm Darius into Garen, what do I build, how does the
  lane go". Arrive from the champion page's matchup tiles, search ("darius garen"), the
  matchups finder, the desktop app
- After a game (Your games links its lane here): was my lane normal?

## What Jacob said (24 Oct)

"the specific matchup page actually is way better than the champion specific page,
much better use of space and can share alot with the champion specifc page, these pages
should compliment each other, im way happier with it and its much more in the direction
i wanna go but could still do with a lot of work, too many words, sometimes too cramped
but in general we wanna keep going this direction but still a lot of what i said on the
champion specifc page applys".

## Decisions

- Keep the dashboard layout; take the champion page's header, RolePicker and BuildPanel
  so the two pages look like one place. The champion page with an opponent picked IS
  this page: ChampHeader's "vs" slot filled
- One game count on screen (the pair's, in the StatStrip); blocks with another scope say
  so in a Chip only when it differs (ui-audit "four counts")
- "Cramped": the gold/XP/CS trio becomes one LaneChart with a metric switch (Gold | XP |
  CS) at a readable size, beside Versus. Three 260 px charts with 6 px text were
  the cramped part
- No sentence headline. The StatStrip says it in numbers: "49.9% Darius wins", "+1.2 vs
  usual", "+382 gold at 14", "61% ahead at 14"

## First screen (1280x800)

```
ChampHeader  [Darius 56] ⇄ [Garen 56]  Darius vs Garen   RolePicker (Top only: one chip)
MatchupGrid strip  Darius's lane opponents by games: icon + Darius's win rate, Garen lit,
               search at the end; scrolls sideways
StatStrip   49.9% Darius wins | +1.2 vs usual (48.2% usually) | +382 gold at 14 |
            61% ahead at 14 | 1,788 games
BuildPanel  "Build against Garen": same panel, refiltered to the pair; a cell that
            matches Darius's usual build is dimmed with "as usual" (2 words)
```

Lane row (LaneChart + Versus) starts at ~y 640 at 1280x800, fully on screen at
1920x1080.
Phone: header icons 40 px with the swap between, MatchupGrid strip, StatStrip 2x3, the
BuildPanel folded (runes as keystone + secondary), then LaneChart full width.

Words (desktop first screen, without names and numbers): "vs", "wins", "vs usual",
"usually", "gold at 14", "ahead at 14", "games", "Build against", slot titles,
"as usual": about 30. Today: ~110 (headline sentence, scope sentence, buttons, captions).

## The rest

1. Lane row: `LaneChart` (Gold | XP | CS switch, average line, middle-half band, 15
   min mark; axis fits the band to 20 min as MU3) beside `Versus` (mirrored bars:
   wins, ahead at 14, wins when ahead, first blood, kills by phase; timings as one row
   each: level 2, level 6, first item). Drag on the LaneChart to select a range: the
   Versus's kill rows switch to that range (shared with Your games' TimelineChart
   range select; needs kills by minute, see Data)
2. Outcome row, three Chart cards: Win rate by gold at 10 (`OutcomeCurve`, the pair
   against all lanes of the role dashed), By game length for the pair (TrendChart,
   3 buckets, MU5), By rank and mastery (DataTable, compact: Darius wins, gold at 14,
   games)
3. Bot and support only: `DuoPair`, both sides' lane partners (ally pairs), each with
   games and vs usual (MU4)
4. Runes against Garen: the same RuneTree as the champion page, numbers for the pair,
   with "taken more / less than usual" as a small ▲▼ beside the pick share (no third
   colour)
5. Links: Darius, Garen, From Garen's side (the swap does this too)

## References (research refs/matchups/notes.md)

- Keep ours (no other site has the page). Take lolalytics' VS slot behaviours: the
  ChampHeader's opponent shows as "vs Garen ⊗"; ⊗ clears it and returns to the champion
  page in the same role, the swap arrows flip sides. Champion page and matchup page are
  then visibly one page with the slot empty or filled
- Switching opponent: op.gg's list sorted by games with a search, as the MatchupGrid
  strip already does; the order by games, not by win rate

## Components used

ChampHeader (pair variant), RolePicker, MatchupGrid strip, ChampSearch, StatStrip,
StatCell, Toggletip, BuildPanel (refiltered variant, "as usual" dimming), RuneTree,
DataTable compact, SkillGrid, LaneChart (the Chart preset Your games uses, with a metric
switch and band), RangeSelect, Versus (mirrored), Chart (card, frame, tip),
OutcomeCurve, TrendChart, DataTable, DuoPair, Chip.

## Interactions

- Swap (⇄): the other side's page
- MatchupGrid strip: tap → that matchup, same role; search filters the strip
- LaneChart: metric switch; tap a minute → Chart tip (average, middle half, games still
  going); drag → range for Versus's kill rows
- Build cells and runes: as on the champion page (tap to expand to every option)

## Data

| Need | Status |
| --- | --- |
| Everything shown today | exists |
| Pair build: spells, items 4-6, skill path | exists (MU1, 24 Oct); options under 100 games left out |
| Win rate by game length for the pair | exists (Trend.lane, MU5 wiring left) |
| Supports on bot matchups | exists (statsfile ally pairs), MU4 not built |
| Kills by minute range for Versus | new: curves file has kills by phase (0-6, 6-14, 14+); per-minute kill counts per pair would be a curves format change (v7), medium. Without it the range select only moves the chart's Chart tip, not the kill rows |
| Runes taken more/less | exists (builds.runeShifts) |

## Cut

- The headline sentence ("Darius wins 49.9% against Garen, 49.3% in all Top games...")
- The scope sentence after the title; "Change champion 129" button (MatchupGrid strip and
  ChampSearch do it)
- Separate XP and CS charts; the chart caption line (legend words go into the chart:
  "average" label at the line end, band explained in the Toggletip)
- Head to head's footer sentence; tile captions ("Darius against Garen", "about +240 of
  it from CS": into the gold cell's Toggletip)

## Desktop reuse

The whole page is the desktop's in-game "your lane" view: StatStrip, LaneChart,
Versus, the pair's BuildPanel. MatchupGrid strip is the desktop's enemy picker.

## Open questions for Jacob

1. One LaneChart with a Gold | XP | CS switch, or keep three charts but larger (two
   rows)? Plan: one with a switch
2. Range select on the lane chart worth a curves format change (per-minute kills)?
