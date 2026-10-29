# Champion page (champion/<name>.html)

Plan only (team run 2026-10-24-ui). Mock: data/team/2026-10-24-ui/mocks/champion.html.
Components by register name (data/team/2026-10-24-ui/components.md, foundation names
and specs them). Family: this page, the matchup page (matchup.md) and the build view
(builds.md) are one page type with one header; read this one first.

## Identity

One champion in one role: how it does, how to build it, who it beats and loses to.
The champion family's home: lolalytics' basic page, plus what only we have (lane curves,
vs usual, early lean, pick-up).

## Who comes and why

- A player about to play (or already in) the champion: the build, then the hard lanes.
  Most visits; arrive from search, the champions table or a matchup page
- A player deciding whether to learn it: how it does by rank, how hard to pick up,
  trend over patches
- The desktop app links here from champ select suggestions ("why this pick")

## What Jacob said (24 Oct)

"needs to be more like the basic lolalytics page, the players win rate thing is too
generic, not precise, or clear enough to what it menas, WAAAAAY too many words, awful use
of space, like having nothing beside the player winrates histogram thing, the builds is
quite cool, but runes, i need to be able to easily see the lolaytics like version where i
can actually see all the pick rates, games and win rates of choices ... some cells are
showing information and look just like the other buttons, the most played, highest wr i
dont want a toggle i want to show that all at once somehow. I need a way at the top to
select between different roles ... slecting vs different roles is cool but I think we can
make this ui element much easier, intutive, clear with a more specfic design. We never
need a key of colours ... I love the patch by patch and game time graphs, but again we
can do this way better and clearer still, they dont really fit the style and look messy
and TOO MANY WORDS"; "how hard champ is to pickup, why does it take up so much space";
"if i pick on champion with its role on the champions list page, i want that role";
"So many things on this page just dont have the ui componenets to do it well".

## Decisions

- One page per champion, one role on screen. The role lives in the URL
  (`darius.html#jungle`, later `darius/jungle.html`); every link that knows a role
  carries it (champions table, matchup page, search "darius jungle", desktop)
- Every role with any games is in the RolePicker (Jacob 26 Oct); the most played opens.
  One under the champions table's share (10%) opens with its figures faded and "A rare
  role for {champion}: {n} games." Build pages keep the 10% cut
- The build page folds into this page (builds.md): every build slot opens in place to
  its full option table. Nothing to go back from
- Most played and highest win rate at once (Jacob 26 Oct): every slot lists its top 3
  by games, each row with pick share, win rate and games. The slot's highest win rate on
  400+ games is marked "best", a 4th row when not in the top 3. A panel-wide Most picked
  | Highest WR (lolalytics' build toggle) re-sorts every cell by win rate, options under
  400 games after; `order=win` in the URL. Under 150 px of cell, pick gives way to games
- No colour key anywhere. Scale colour carries a second cue (sign, bold); thin data
  fades. A number whose meaning isn't obvious gets a Toggletip on its label, not a key
- Buttons look like buttons, data cells never do: data cells have no border, no
  background on hover unless they are links (then the whole cell is a link with a
  chevron on hover)

## First screen (1280x800)

```
header 48 | subbar 36 (filters: region, period, rank) | preview strip 22
ChampHeader  [icon 56] Darius            RolePicker [Top 86% | Jungle 14%]
                                          vs [Pick opponent ▾]
StatStrip    49.3% won  44th of 59 | pick 7.7% | ban 16.5% | 31,257 games |
             16.21 +2.6 ±1.4 | early lean +160 gold
BuildPanel   RuneTree (both trees, every rune: pick %, win %)  | Spells | Skills
                                                                | Start | Core path
                                                                | Boots | Item 4 5 6
```

Desktop: the panel fills the rest of the first screen (~520 px at 1280; RuneTree left
430 px, slot cells right in a 3-column grid). Matchups start just under the fold at
1280x800, on screen at 1920x1080.
Phone (390): header, RolePicker (full width segmented), StatStrip as 2 rows of 3, then
the RuneTree folded to the chosen page (keystone row + secondary tree icons with the
page's pick and win); tap to open every rune's numbers.

Words on the first screen (desktop, not counting champion, item and rune names,
numbers): "won", "of", "pick", "ban", "games", "early lean", "gold", "vs", "Pick
opponent", slot titles (Runes, Spells, Skills, Start, Core, Boots, Item 4, Item 5,
Item 6), column heads "pick", "won", "games" once per cell: about 35. Today: ~300 on
the first screen, 1,154 on the page (frontend-rework.md).

## The rest, top to bottom

1. Matchups. `MatchupGrid` with a `RelationPicker`: [Against | With] then the five
   role icons, the champion's own lane preselected ("Against Top" = lane opponents;
   "With Jungle" = duos). Replaces six text tabs; the two axes say what the tabs meant.
   Tiles: icon, the champion's win rate (scale ink), a vs usual tick bar under it, games
   faint. Gold at 14 and the exact vs usual in the tile's Toggletip and on the matchup
   page. Sort: Segmented (Hardest, Easiest, Most played, Gold at 14); thin rows fade
   and sort by the pulled rate (shown as raw, ui-audit 3: the header says "sorted by
   pulled rate" in its Toggletip). Tap a tile: the matchup page. View switch
   [Tiles | Table]: the same rows as DataTable (sortable, every number)
2. Trends row, three Chart cards of one height in one chart style (Chart frame):
   - By patch: TrendChart, win rate line with ±95% band, pick rate as thin bars on a
     second axis, rank in role as the x-axis label under each patch. No per-point text
     labels; tap a patch for its numbers (Chart tip)
   - By game length: the same TrendChart over 5 buckets, games under each; the early
     lean as one line under the card: "Early lean: +160 gold at 14, wins 2 less from
     even at 20" with a Toggletip for how
   - Players: `Histogram`, players' win rates on the champion (10+ games),
     marker at 50% and the middle half shaded; caption one line: "388 players, middle
     half 46-63%". The luck sentence goes into its Toggletip
3. Learning row, two cards:
   - Pick-up: `OutcomeCurve`, 5 mastery bands as a small line (win rate) with games;
     headline "New 47.6% → practised 52.6%, gap 5.0 (usual 3.2)" with a harder/easier
     Badge only when clear. Card ~200 px tall, was ~700 px with two paragraphs
   - Also play: `ChampList` rows: icon, name, ×3.5 (the order) and share; harder to
     pick up as a Badge. Link to the pool page
4. Footer: one "Method" link. The two method paragraphs move to method.html

## More charts (Jacob 27 Oct, site note 28)

"So many more graphs i wanna see": the Pick-up card is liked, the page wants more of
its kind. Candidates, data we have first (arch-stats.md):
- Pick-up across all five mastery bins: done (bins under 200 games left out)
- Lane curve: done (Charts island, Lane card): gold, XP and CS lead by minute against
  the average lane opponent (its pairs' estimates weighted by lanes), the role's middle
  half around it; all ranks
- Comeback odds: done ("Won by lane gold", 10 | 15 min, the pairs' buckets summed
  against all lanes dashed; all ranks)
- Early kills: who takes part in killing the lane opponent before 6, 6-14, after 14
- By rank bracket: Iron-Silver, Gold-Emerald, Diamond+ (curves brackets; stats by rank)
- Item timing: first core item minute against win rate (builds' minutes per game:
  new counting)
- Side (blue, red) and games played on it in the last 30 days: new counting
One chart style for all (Chart frame), two per row as Pick-up and Also play. The
Charts island (ui-champcharts.wasm) holds Lane, comeback odds, Pick-up and Also play;
ui-champmore.wasm the matchups and trends.

## References (research refs/champion/notes.md, 27 shots)

| Element | Model on | Take | Leave |
| --- | --- | --- | --- |
| RolePicker | dpm, lolalytics | share under each role icon; op.gg's hide roles under 10% | lolalytics' sticky filter bar wider than the phone |
| StatStrip | dpm | six figures in one row, no prose, rank of N | lolalytics' WR delta and game avg WR (nobody reads them) |
| BuildPanel | lolalytics | whole build in one ~350 px panel, win and games under every choice, 2-3 options in late slots, reflow into pairs on the phone | the toggle that hides the other build |
| Common and winning at once | op.gg core rows, Blitz variant list | options as ranked rows (pick, games, win), sort only reorders | Blitz's signed "+X" WRI form |
| RuneTree | lolalytics grid | every rune with pick, win, games; labels once | colour as metric identity, no fading (0.0 on 1 game looks like 52.8 on 25k): we fade under 400 as op.gg and dpm |
| SkillGrid | lolalytics | 4x18 numbered grid, win and games under it; all 18 levels on the phone | Mobalytics' letters on lines; u.gg's phone cut to 8 levels |
| MatchupGrid, RelationPicker | lolalytics per-role strips | all five enemy roles and allies | strips sorted by raw pick with hover-only deltas; deeplol's raw WR sort |
| By patch, by length | dpm | equal small charts, patch starts as labelled lines | lolalytics' 7 unlabelled rank lines per chart, no games per bucket |

Later, not in this plan: named build variants (Blitz, dpm, deeplol: "Bruiser 23,521 games
51%"), site.md Champion page "Later" (clusters of item paths).

## Components used

ChampHeader, RolePicker, ChampSearch, StatStrip, StatCell, Toggletip, Chip (only where a
block's scope differs from the subbar), BuildPanel, RuneTree, DataTable compact (slot
options), SkillGrid, ItemPath, MatchupGrid, RelationPicker, Segmented (sort, Tiles |
Table), DataTable, Chart (card, frame, tip), TrendChart, Histogram, OutcomeCurve
(mastery bands), ChampList, Badge.

## Interactions

- RolePicker: switches role in place (no reload: both roles' data in the page or a
  fragment), updates the hash
- ChampSearch: type or pick a champion → that matchup page in the current role
- Build slot: tap → expands in place to its full option table (DataTable compact)
  with the build page's extra columns (minute bought); Esc or tap again closes. One open
  at a time
- Rune: tap → Toggletip with the rune's name, pick share, win rate, games
- MatchupGrid: RelationPicker changes the set; Segmented sort; tile tap → matchup page;
  Segmented remembers Tiles or Table (localStorage)
- Charts: tap or hover a point → Chart tip; no permanent labels
- Filters (subbar) re-render every block, as filters.js does today, but from the same
  components in ui.wasm (frontend-rework.md Option A)

## Data

| Need | Status |
| --- | --- |
| Role share | exists (role games; computed) |
| Rune pick, win, games per rune | exists (builds file, build page) |
| Items 4-6, skill path 1-18, minute bought | exists since CH2 (24 Oct) |
| Matchups against every role, duos | exists (statsfile enemy/ally pairs) |
| By patch, by length | exists (CH5 Trend); 3 patches in the db until more come |
| Win rate ±95% per patch point | small: binomial from counts already there |
| Players' spread, mastery bands, also play | exists |
| Both roles' build in one page | exists (two views today); size check: Darius page today ~400 KB with both |

Nothing new from the box; all of it is site work.

## Cut

- The histogram as the first thing on the page; the luck sentence (Toggletip)
- "Most played | Highest win rate" toggle; "Highest win rate" marks and their legend
- The opponent tile key line, the matchup colour key, "127 rarer opponents hidden"
  sentence (a "+127 rare" chip at the end of the grid instead)
- Both method paragraphs at the bottom, the pick-up paragraph, the early lean paragraph
- Roles stacked (Jungle repeated under Top)
- The separate build page and build index (builds.md)

## Desktop reuse

ChampHeader (smaller), BuildPanel and RuneTree (the in-game rune page import view),
MatchupGrid tiles (champ select: the enemy laner's tile), TrendChart, Toggletip. The
desktop's "why this pick" links open this page in its role.

## Questions for Jacob (24 Oct)

1. Highest win rate shown by colour alone (the number is the key) or also a small marker
   on the top option of each slot? Plan: colour alone
2. Matchup tiles: win rate plus a vs usual bar (gold in the tip), or keep all four
   numbers on the tile? Plan: two, Table view has all
3. Tier letter (CH0 c): still no?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Highest win rate by colour alone
2. Matchups: neither as drawn. "Dont really like the toggle between table or not, but
   also not a massive massive fan of tiles although its close to good". Redesign in the
   visual pass: one view, no Tiles | Table toggle
3. No tier letters

## Jacob's answers (review v6, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v2-*.

1. Matchups: neither the v6 MatchupField (games on y) nor the 24 Oct tiles. Field
   "still so packed", "so uncentered on wr it looks funny"; tiles "looked lazy". Try
   other options (mocks round 3)
2. Build slots: colour against the slot's average. How a choice moves the champion's own
   rate is interesting but "much more secondary": a quieter second reading, not the colour

## Jacob's answers (review v7, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v3-*.

1. Matchups: option C (one axis, dot plot centred on his rate). A unclear ("what are
   the bars"); B "could get funky" with uneven columns. The 5 hardest / 5 easiest list
   under C is "not very good use of space": rework it (mocks round 4)
2. Centre on the champion's own rate, but no label for his rate in the middle

## Jacob's answers (review v9, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v4-*. No re-review: refine while building.

1. Matchups under the chart: the selected panel (mocks/champion.html `#under=sel`).
   One click or tap on an opponent shows its brief in the panel; an obvious way into the
   matchup page from there (button; double click as a shortcut is fine)
2. Hover tooltip on the chart is too wordy again: icon, name, rate, games at most
