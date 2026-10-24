# Game detail (one game, Your games)

Identity: one game as a screen you read in ten seconds and explore for two minutes: what
happened, when it turned, how your lane went, who did what. Plan 24 Oct 2026, team run
2026-10-24-ui (session games). Mock: data/team/2026-10-24-ui/mocks/your-games-detail.html.

Its pieces are the game stats kit: Daily Draft's game stats (play) and the desktop's
post-game reuse them, so they are designed here once.

## Who comes and why

- Just finished a game (most visits): what went wrong or right, where it turned
- Scrolling back through their games: compare this one to the usual
- Someone looked up from a scoreboard or a friend's page: who played what, how it went
- Riot's reviewer: the flagship of the product, must work and look finished

## What Jacob said (24 Oct)

- "bad use of space on first screen, i quite like the your games bit but perhaps could
  show a little more info about the game like Aurelion Sol vs Aurora 14/8/14 Draft mid
  41:38 23 Oct patch 16.21 ... this is too wordy, needs to be more ui based"
- Turning sentence: "WAAAAY too wordy, again needs to be ui elements, good use of space,
  clear"
- Graph: "the things showing the moments aren't clear, dont fit style of graph, i want to
  be able to highlght a range and see the moments in that range, more indepth of that
  part of game, and click though momenets by click on there"; "the + and - on the graph
  doesnt fit the style"; "a way to filter moment perhaps"
- Stat line (best minute, biggest rise, highest, lowest, minutes ahead): "too many words,
  i like the cells of like first tower but could be better too"
- Lane panel: "too many words ... Is just not interesting/enganging/thoughtful enough"
- Fights: "the words here arent so bad but again i think could be more clear without
  words, more thought put into some ui work"
- Players: "Checkout how other lol sites show game stats ... pick the one we like best
  ... make our own ... re use a lot of these elements"

## First screen

One rule: no sentence on the first screen. Every fact is a figure with a one or two word
label, an icon, or a position on the graph.

Desktop 1280 (content 1232), top to bottom:

1. Game strip, 56 px: the player's games as small cards (champion, W/L edge, duration),
   this one raised; arrows and "All games" at the left. Jacob likes this bit; it shrinks
   from two rows of 120 px cards to one scrolling row
2. Game header, ~104 px, a card in three zones:
   - Who: your champion at 56 px with level badge and role icon, the opponent's at 36 px
     behind a "vs"; names under them
   - Result and score: WIN/LOSS chip, K/D/A at --fs-xl ("14 / 8 / 14"), under it "3.5
     KDA · 53% KP"
   - How: four figure cells, CS 313 (7.5/min), Gold 19.7k, Damage 60.8k, Vision 19,
     then the build: 6 items and trinket at 28 px, spells and keystone at 20 px
   - Meta as chips on the right: Draft, 41:38, 23 Oct, 16.21. Teams as two rows of five
     24 px icons under the chips (you ringed)
3. Graph and inspector, ~420 px, side by side (8 and 4 of 12 columns):
   - Left, the game graph (component `timeline-graph`): win chance 0-100 by minute, the
     area to 50% filled --us above and --them below. Under the x axis, two event rails
     (14 px each): your team's kills and objectives on the top rail, the enemy's on the
     bottom, as small glyphs in the team colour (dot kill, tower, dragon, Baron, grubs,
     Herald); a ring where you took part, a cross where you died. No text on the
     plot. The turning minute is a --turn band with a star on the top edge
   - Above the graph, one control row: [Win chance | Gold] segmented; range chips
     (Game, 0-14, 14-25, 25+, Turn); a moment stepper (‹ 12 of 26 ›)
   - Right, the inspector (component `range-inspector`): what the selection holds.
     Opens on the turning minute (answer first). Shows the range as "35:00-36:00",
     win chance 52 → 90 as a delta bar, kills per side as champion icons (crossed when
     they died), your K/D/A in the range, gold earned, objectives as icons, and below,
     the moments in the range as rows (component `moment-row`), scrolling
4. Under the graph, the stat cells (component `stat-cell`, one row of 6 at desktop):
   Turn +38% (52→90), Biggest drop −25%, Best minute +1,402, Peak 98%, Low 20%, Ahead
   17/41. The turn is the biggest one-minute change, so the second cell is the biggest
   move the other way (drop after a rising turn, rise after a falling one), never a
   repeat of the turn.
   Each cell's sub line is its time ("35-36"). Pressing a cell selects its range or
   minute on the graph; the cell stays pressed while it is the selection

Below the fold at 1280 (~730 px fold, the header bar included): the objectives row,
lane, scoreboard.

Phone 390: strip (scrolls), header in two rows (portraits, KDA and result; then the
four figure cells as a 4-up grid, build on a third row), graph full width at 200 px with
the control row as one scrolling chip row, stat cells as a 3 by 2 grid, inspector below
the graph (not beside), its moment list capped at 5 rows with "All 26".

Words on the first screen, labels only (data, champion names and times not counted):
All games, WIN, KDA, KP, CS, Gold, Damage, Vision, Win chance, Gold, Game, Turn,
Turn, Best minute, Biggest rise, Peak, Low, Ahead, Kills, Gold, plus the inspector's
row labels (none: rows are icons and figures). About 22 words. Today's first screen has
~95 (the turning sentence, the chart caption, the stat line, the moments header).

## Interactions

All in ui.wasm (README architecture); without wasm the page shows the default
selection (turning minute) and the full moment list, nothing hidden.

- Select a range: drag across the plot or the rails (pointer events; touch drags too,
  with a 6 px dead zone so vertical page scroll still works); handles at both ends to
  adjust; Esc or "Game" clears. Range chips are the keyboard and phone route
- Select a moment: press its marker on the rail, its row in the inspector, or the
  stepper; ←/→ step through moments in time order inside the current range. The plot
  draws a cursor line at the moment and the inspector shows the moment card
- Filter moments: chips in the inspector's header, All, Yours (you took part or died),
  Fights, Objectives, Deaths. The rails dim filtered-out glyphs to 30%
- Hover (desktop) or tap (phone) on the plot: a crosshair with "21:00 · 63%" in a
  readout at the top edge, not a floating tooltip over the line
- Gold toggle: the same plot draws your team's gold lead (timeline team gold sums);
  rails and selection stay
- URL: #id=..&game=..&t=2100-2160 or &m=17 keeps the selection, so a link points at a
  moment (Copy link exists today)

## The rest of the page

### Objectives and firsts (component `team-compare`)

One row under the stat cells, two-sided: your team left in --us, the enemy right in
--them, each objective an icon with the two counts and a split bar: Kills 53-46,
Towers 9-7, Dragons 4-2, Grubs 3-0, Herald 0-1, Baron 1-1, Gold 90.9k-84.9k. Firsts
fold into it: the icon of an objective whose first was yours carries a small "1st" tick
with its time in a toggletip (First blood 3:15, First dragon 6:57 ours; First tower
14:13, First Baron 25:31 theirs). This replaces today's coloured firsts pills.

### Lane (component `lane-duel`)

Today: a chart, a caption and a seven-row table with empty columns. The data is a duel
against one opponent with a "typical" range, so the UI is a duel:

- Top bar: your portrait left, theirs right, "First 25 min" title, [Gold | XP | CS]
  segmented, and one scope chip "Typical: 11 games, all ranks" (toggletip says what
  typical is; under 200 games the chip and the band are dashed: that is the whole
  "more data needed" message)
- Chart (left 7/12): you minus them by minute, the typical middle half as a band and
  its median as a thin line, your line bold. Your biggest gain and drop against the
  typical game are brackets on the time axis ("8-11 +281", "5-8 −543") that select
  that range on the game graph above when pressed. The same chart as the matchup page
  (stats session), with your line added: the matchup page link sits on the scope chip
- Right (5/12), three race tracks (component `race-track`), each a 0 to N min line with
  three markers, you (--us), them (--them), typical (tick), and the gap to typical as a
  signed chip (+52s is later, so the bad end of the scale):
  - Level 6: 6:31, 5:15, typical 5:39, +52s
  - First item: 11:54, 10:16, typical 11:21, +33s
  - CS at 10: 64 vs 69 (a count, drawn as a track 0-100 CS)
- Under the races, one bullet (component `bullet-range`): gold lead at 14, −768, on a
  track with the typical middle half shaded (−1,677 to +511) and the median tick at
  −63. "Below half the games" goes: the marker outside
  the band says it
- Deaths and kills before 14 as two icon counts (✕✕ and ⚔⚔), no table

Phone: chart full width 180 px, races stacked, bullet under them.

### Scoreboard (component `scoreboard`)

A real table, two teams of five, one header row per team with result, team K/D/A,
gold and objective icons. Columns: champion (32 px icon, level badge) with the Riot ID
under it (link to their games), K/D/A with the KDA ratio under it, KP, damage to
champions (figure and a bar against the game's highest), gold, CS with per minute under
it, vision, items (7 at 22 px), spells and keystone. Your row on --panel-2 with a left
edge in --us. Sortable by any figure column (shared `data-table` sort), default by role.
Phone: champion, K/D/A, damage bar; items on a second line inside the row; the rest
behind a row press (expands).

Model site: decided when research's game-detail refs land (refs/README.md). Working
choice: the op.gg expanded match for the scoreboard grid (dense, items inline, damage
bars) without its tab maze; League of Graphs for the kill map; none of them has our
graph, inspector or lane duel, which are the identity of the page.

### Moments, the list

There is no separate moments section any more: the inspector is the list, filtered by
the selection. "Game" selected shows all 26. Today's "9 smaller moments" fold stays as
a last row ("9 under 5%") inside the list.

`moment-row`, one line, 40 px:
time | delta bar (win chance moved, signed, bar length to 40 points, --gain or --drop) |
our champions in it (icons 20 px, crossed if they died, you ringed) "3-2" their
champions | objective icons after it, team-bordered | kill gold "+381". Where it was
("bot", "enemy jungle") is a 16 px minimap dot, not a word. No size words ("big",
"huge"): the bar is the size.

`moment-card` (selected): the row's content larger, a 160 px minimap with the kill
positions (blue and red dots, crosses for deaths, from timeline kill x/y), win chance
before → after, and the gold and objectives in the next minute.

## Components used (register names, data/team/2026-10-24-ui/components.md)

GameStrip, GameHeader (header variant), ChampIcon (level badge, "you" ring, "dead"
state), ItemIcon, SpellIcon, RuneIcon, ObjectiveIcon, Kda, Chip, Segmented,
TimelineChart (EventRail, TurnBand, RangeSelect, Gold mode), StatStrip (items as
buttons), RangeInspector, MomentList, MomentCard (with KillFeed), Minimap, Versus
(split for the objectives row; dumbbell for the races; band for gold and CS lead),
LaneChart, Scoreboard (DataTable), Toggletip, Delta. Kebab names above in this plan map
to these (team-compare = Versus split, race-track = Versus dumbbell, bullet-range =
Versus band, timeline-graph = TimelineChart, game-strip = GameStrip).

## Data needed

| What | Status |
| --- | --- |
| Win chance by minute, moments, turning, best minute, firsts, death costs, lane | exists (api report) |
| Kills per fight with victims and killers on both sides | new, from timeline kill events (game.zig, small) |
| Kill positions (x, y) per moment | new, in the timeline already (small) |
| Objective totals per team (towers, dragons, grubs, Herald, Baron, inhibitors) | new, timeline building and elite monster events (small) |
| Team gold by minute (Gold toggle) | new, timeline frames (small) |
| Per player end CS, gold, level, damage dealt and taken | new, timeline last frame (small) |
| Final items, summoner spells, keystone and trees, vision score | new Summary fields from match-v5 (medium): free for new games; cached ones get them on the next refresh, one match call each, as match_names does |
| Peak, low, minutes ahead | exists (computed in your.js today; moves to Zig) |
| Rank of the other nine | not stored; a league-v4 call each, no (cost, and not needed) |

## Cut

- The turning sentence, the chart caption, the stat line sentences, the lane caption,
  "You minus your lane opponent", "below half the games", the Typical/vs typical table,
  size words on moments, "Riot IDs as at the game; pick one to see their games"
- Coloured text labels on the plot ("+38% 4 for 2")
- The separate Your moments section (now the inspector)
- The vertical win chance bar beside the plot (the line's end says it)

## Desktop reuse

The whole kit is the desktop's post-game screen: game-header, timeline-graph with
inspector, team-compare, lane-duel, scoreboard. The desktop's own lane chart (dvui) goes
if WebView2 wins the spike; if dvui stays, timeline-graph and lane-duel are the two
components that would need a dvui twin. Daily Draft's game stats (play) reuse
game-header (without "you"), team-compare, scoreboard and timeline-graph read-only.

## Open questions for Jacob

1. The inspector opens on the turning minute. Or on the whole game, with the turn only
   marked? (Recommended: turning minute; it is the answer.)
2. Gold toggle on the game graph: worth the second series, or win chance only?
3. Scoreboard sorting: useful, or fixed role order only?
