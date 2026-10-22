# Champion and matchup pages against the leaders

Jacob 22 Oct: champion and matchup pages "need to match" LoLalytics and the other big
sites. This doc covers what they show that we don't, where our pages waste space or
are unclear, and the target layout. Steps: docs/plan/site.md "Champion page" (CH) and
"Matchup page" (MU). Evidence: research/questions/champion-matchup-gap.md (claims
C1-C18; LoLalytics, U.GG, OP.GG, Mobalytics, Blitz, METAsrc, League of Graphs, dpm,
DeepLoL read 22 Oct, patch 16.21). Colour and density rules stay in
docs/design-ideas.md. Consistency bugs (sort keys, several game counts, two "usual"s,
number formats) are in docs/ui-audit.md and not repeated here. Policy limits:
docs/production-key.md "Product rules".

## The short version

- Champion page: LoLalytics fits a complete build into one 330 px panel on the first
  screen: skill priority, spells, a 4x18 skill order grid, both rune trees, start, core,
  and 2 or 3 options each for items 4, 5 and 6, all with win rate and games. Ours spends
  the first screen on a player histogram, four big tiles and two paragraphs, then a
  build strip of 8 big cards with fewer choices. Lane opponents start at y 1,203, so
  none are on the first screen
- Sections the leaders share that we lack: items by slot after the core, the full skill
  order, duos by ally role, counters against every enemy role, win rate over patches and
  by game length, and build variants. Duos and counters by role need no new data: the
  stats file holds ally and enemy pairs for every role pair
  (src/core/statsfile.zig)
- Matchup page: nobody else has one. Their "matchup" is the build page filtered to an
  opponent, with no lane stats (C5); the second tier has only snapshots at 15 minutes.
  Our curves, head to head and by rank are ahead. We trail on build depth for the pair
  (no spells, no items after the third, no skill order), on switching opponent (a
  button rather than a visible list), and the first screen goes to one big chart of a
  nearly flat line

## Ours, measured (22 Oct, Chrome 1920x1080 and 390x844, live site)

| Page | Height | Numbers on the first screen | Notes |
| --- | --- | --- | --- |
| Darius (champion) | 4,074 px desktop, 8,218 phone | 72 desktop, 20 phone | first lane opponent at y 1,203; Top and Jungle stacked as two full sections |
| Kai'Sa (champion) | 2,608 / 4,637 | 68 / 20 | first opponent at about y 1,050 |
| Darius Top build | 3,670 / 5,372 | 139 / 21 | separate page; method paragraph first |
| Kai'Sa vs Jinx (matchup) | 2,183 / 4,857 | 131 / 50 | denser than LoLalytics' 68 |
| Champions index | 11,263 / 9,368 | 121 / 34 | 41 px rows, 19 on a 1080p screen |
| LoLalytics Darius build | 5,682 / 13,597 | about 70 / 21 | counters at y 1,374; phone scrolls sideways |
| LoLalytics Darius vs Garen | 5,240 / 10,846 | about 68 / 25 | no lane stats |
| U.GG Darius build | 2,408 | about 10 | build column 1,014 of 1,920 px |
| OP.GG Darius build | 4,220 | about 40 (most in the sidebar) | build starts at y 815 |

Where our space goes, champion page (Darius, 1920x1080):
- Player win rate histogram: a 420x220 px card with about 1,100 px of nothing beside it,
  before the champion's own win rate
- Four 130x90 px tiles (win rate, pick, ban, games) in the left 550 px; the rest of the
  row is empty
- "Early lean" and "Patch 16.21 against 16.20" are two full-width paragraphs
  of numbers with ± ranges, about 90 px
- Build strip: 8 cards in two rows, about 350 px. The Spells card is 400x180 px for two
  icons, Boots holds one icon, Runes are tiny full trees. It has no items after the
  third, and "First 3 items" (16% share, 234 games) is greyed
- Opponent tiles 103x152 px, five lines each, three of them unit words; 13 a row
- Roles stacked: Jungle repeats the whole block under Top (1,764 to 2,964 px). Every
  other site switches role with a tab showing the role's share of games
- Bottom: "Players who main Darius also play" puts name and number 1,100 px apart; two
  long method paragraphs in plain view
- Phone: 207 px of chrome (header, three subbar rows, preview banner); the first
  screen is the name, histogram and 4 tiles; first opponent at 1,832 px

Build page (Darius Top): every table spans 1,560 px with three number columns pushed
to the right edge, so the eye travels 1,000 px from icon to win rate. A 5-line method
paragraph sits above the runes. Items stop at "first three finished items" and
skills at "priority after 13 skill-ups" and levels 1 to 3.

Matchup page (Kai'Sa vs Jinx):
- The gold chart takes about 900x440 px, half the first screen, for an average line at
  +141 gold. The axis runs ±3,000 to fit the middle-half band, so the line looks flat
- Header text, three buttons, a sentence and five 98 px tiles take y 130 to 410
- "Most played build in this matchup": six cards, each "same as usual", holding one to
  three icons. No spells, no items after the third, no skill order
- "Runes against Jinx" is 380 px tall with the right 40% empty
- Changing opponent opens a list behind "Change opponent 81"; the opponents themselves
  are never visible on the page
- Phone: header 5 lines, tiles 3 rows, the gold chart's text about 6 px (ui-audit 7)

## What the leaders have, by section

Y: shown; f: as a filter of the build page; -: not there. "Us" is the live site.

| Section | LoLalytics | U.GG | OP.GG | Others | Us |
| --- | --- | --- | --- | --- | --- |
| Role tabs with role share | Y | Y | Y | Blitz, LoG | roles stacked, share in prose |
| Stat strip: win, pick, ban, games, rank in role | Y (8 figures) | Y (6) | Y (3, trend arrows) | all | 4 big tiles, rank under win rate |
| Tier letter | Y | Y | Y | all | - (Jacob's call, CH0) |
| Build on the first screen | Y, one panel | runes, spells only | n (y 815) | Blitz Y | strip, partly |
| Most played vs highest win rate build toggle | Y | - | - | - | per cell "Highest win rate" |
| Build variants (AP, lethality, ...) | - | Y | - | Blitz | - |
| Full skill order, levels 1-18 | Y (4x18 grid) | Y (grid) | Y (15 squares) | LoG | - (priority, levels 1-3) |
| Items 4, 5, 6 options by slot | Y (2-3 each) | Y (5-7 columns) | Y (5 rows each) | Blitz | - (core 2, core 3 only) |
| Item purchase minute | Y | - | - | - | - |
| Item win rate before buying (WRI) | - | - | - | Blitz | - |
| Every rune with win rate and pick | Y | - | Y | | Y (build page) |
| Lane opponents, all on screen | strips by role | 8-card strip, counters tab | 5+5 sidebar icons | | grid, below the fold |
| Counters against every enemy role | Y (5 strips) | - | - | | - (data in stats file) |
| Lane result per opponent (gold at 15) | - | Y (GD@15 list, table) | - | Blitz lane WR | Y (gold at 14 on tiles) |
| Duos by ally role | Y (synergy tabs) | - | Y (4 tables) | DeepLoL | - (data in stats file) |
| Win rate, pick, ban over time | Y (by day, per rank) | - | Y (by patch, with rank) | | patch line in prose |
| Win rate by game length | Y | - | Y (5 buckets) | LoG graphs | - (early lean prose) |
| Objectives secured and won | Y | - | - | | - |
| End-of-game stats ranked in role | Y | - | - | | - |
| Players' win rate spread | - | - | - | | Y (histogram) |
| Lane curves, early/late lean, vs usual, pick-up difficulty | - | - | - | | Y, ours alone |

Matchup (one opponent):

| Section | LoLalytics | U.GG | OP.GG | Others | Us |
| --- | --- | --- | --- | --- | --- |
| Own page or a filter | f (VS block in filter bar) | f (?opp=) | f (?target_champion=) | Mobalytics page; Blitz, LoG filter | own page |
| Matchup win rate and games | Y | Y | Y | all | Y |
| Delta against the average opponent | Y (prose) | - | - | Mobalytics "than expected" | Y (vs usual) |
| Whole build refiltered to the pair | Y | Y (items 4-6 not refiltered) | Y | Blitz builds card, LoG | part: runes, start, boots, core, skills |
| Spells, items 4-6, skill order for the pair | Y | partly | Y | | - |
| Lane stats at 15 (gold, XP, CS) | - | table only | - | Mobalytics, METAsrc, LoG | Y, over time |
| Level 2, first blood | - | - | - | METAsrc, Mobalytics | - (kills by phase) |
| Opponent list on the page to switch | VS block | search chip | sidebar list | METAsrc master-detail | behind a button |
| Win rate by game length for the pair | Y | - | - | | - |
| Supports in a bot lane matchup | - | - | - | - | - (data in stats file) |
| Matchup tips | - | - | user tips, empty | Mobalytics paid | - |

## What not to copy

- Thin matchup builds shown like solid ones: 100% on 2 to 4 games (LoLalytics, OP.GG),
  or late items silently unfiltered (U.GG) (C8). Ours: hide under 100 games, grey under
  400, as the build page already does
- Whose win rate it is, unlabelled: U.GG's Counters and Matchups give the same pair
  46% and 54%; Mobalytics and Blitz flip within one panel (C9). Ours: always "X wins"
- Raw win-rate sorting, so 120-game rows lead (U.GG, DeepLoL) (C15); METAsrc and
  OP.GG sort by games. Ours: pulled rate as today, with the key shown (ui-audit 3)
- Colour by metric, two-decimal 11 px centred figures, splash cards, no phone layout
  (LoLalytics; design-ideas.md "What lolalytics gets wrong")
- Champion-wide numbers inside a matchup panel (OP.GG's lane win rate and ban rate
  rows, LoLalytics' stats block) (opgg-darius-vs-garen ^f3)
- Ads, app banners and AI chips before the data (U.GG, OP.GG, METAsrc) (C14)

## Target: champion page

1920x1080, top to bottom (heights approximate):

```
header 48 | subbar 36 (preview strip 22)
[icon 48] Darius   [Top 84% | Jungle 16%]  49.1% won  46th of 59  pick 7.6%  ban 16.3%
  27,050 games  16.21 +3.4 on 16.20  ahead at 14 (+160)                          ~64 px
+-- Build (most played | highest win rate) ---------------------------- ~330 px --+
| runes: both trees lit | spells | skill priority + 4x18 grid | start | core 3  |
| item 4 (3 options) | item 5 (3) | item 6 (3) | boots   each: icon, % won, games |
+-------------------------------------------------------------------------------+
Lane opponents 40  [sort chips]  76 px tiles, 18 a row: 40 of 40 by about y 800
[Lane | vs Jungle | vs Mid | vs Bot | vs Support | Duos]   tabs over the same grid
Side by side: win rate over patches | by game length | players' spread (histogram)
Also play | pick-up difficulty | method (folded)
```

- One role on screen at a time; the role tab shows its share, like every other site.
  The URL keeps the role (#jungle) so shared links stay exact
- The build panel is one component used by the champion page, the matchup page and the
  top of the build page; the build page keeps every option as compact tables
- Opponent tabs for other roles and duos draw the same grid from the stats file's enemy
  and ally pairs, with vs usual from both champions' own rates and the thin-data fade
- Phone: role tabs and the stat strip in two rows, then the build panel (runes folded
  to the keystone and secondary tree icons), opponents 4 a row

## Target: matchup page

```
header | subbar
[Kai'Sa] ⇄ [Jinx]  Kai'Sa vs Jinx, Bot, EUW, 30 days, Platinum+        one line
opponents strip: Kai'Sa's lane opponents by games, icon + win rate, Jinx lit, search
47.2% Kai'Sa wins | -0.4 vs usual | ahead at 14 in 54% | +141 gold at 14 | 4,969 games
+-- Build in this matchup (same panel, refiltered; cells as usual marked, not boxed) --+
+---------------------------------------------------------------------------------+
Gold | XP | CS, three small charts, ~240 px  ||  Head to head
Win rate by gold at 10 | by game length | by rank and mastery | supports (bot only)
Runes against Jinx (compact, no empty right side)
```

- The build for the pair comes before the charts: it is what most players open a
  matchup page for (every leader's matchup view is a build), and the curves stay the
  first thing nobody else has
- Gold chart axis fits the average line and the middle half up to 20 minutes rather
  than ±3,000; the dashed 15-minute line stays
- Bot lane: Kai'Sa's supports and Jinx's supports (ally pairs), each with games and vs
  usual. No site shows supports on a matchup page (C11)
- Opponents strip sorted by games, so the lanes players meet come first (C15)

## Data: what exists and what is new

| Section | Data |
| --- | --- |
| Counters by every role, duos | exists: statsfile enemy and ally [5][5][n][n] counts |
| Bot lane supports | exists: ally pairs bot with utility |
| Items 4, 5, 6 by slot | new builds kinds (nth finished item, any path), role-wide and in matchup_kinds |
| Skill order 1-18 | new kind: packed key, 2 bits a level (site.md has the idea) |
| Spells per matchup | add spells to the matchup builder's kinds (src/builds.zig Builder.vs) |
| Win rate by game length | new tally by duration bucket per champion role, and per pair with 300+ games |
| Win rate and pick over patches | per-patch tallies exist (patch page); a series per champion role |
| Level 2 time, first blood | curves format header fields (site.md matchup "Next") |
| Item purchase minute | median minute per item in the builds file |
