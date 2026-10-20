# Design ideas: colour and density

Jacob 20 Oct: "more colour" and "so space inefficient", across the whole site;
lolalytics shows more but is "not easy to read"; what gets coloured should follow what
is "actually impactful". This file: principles, the site-wide layout and colour system
(measured before and after), what to colour from our own data, then per page, then a
build order. Evidence: research/questions/dense-stat-layout.md (claims C1-C15, 33
new source notes). Screenshots and the prototype script: data/team/2026-10-19-night/
design-shots/ and design-proto.mjs (gitignored, Jacob's Mac). Policy limits:
docs/production-key.md "Product rules" (no public draft win chance, no "+X% win rate"
wording, several options with reasons).

## Principles

1. Colour means "this moves the result and is far from usual". Numbers that barely
   matter stay in plain ink, however unusual (table below). lolalytics spends colour on
   which metric a row is, so it carries nothing (C8)
2. One diverging scale everywhere: blue above, orange below, a grey middle that
   recedes, vivid only at the clamped ends (C3, C4, finviz). Four steps a side; the
   fourth electric aqua or hot pink text, rare by design (a filled chip at first,
   dropped 20 Oct: Jacob, "they just look weird")
3. Always a second cue beside colour: the sign, a bar, bold (C2: FBref, Basketball
   Reference, Dotabuff). Colour-blind readers and the policy both need the number
4. Thin data loses colour first: shrink, then fade toward grey; never sorted to the top
   (C6, C7: the most common League-site failure)
5. One number per row is the answer and is larger; the rest are small and grey (u.gg,
   op.gg colour one column only, C1). lolalytics gives everything equal weight
6. Density from cutting chrome, not shrinking type: units once in a header or legend,
   not in every cell (dpm writes row labels once); 13.5 px tabular figures stay
7. Answer first: top 5 strips and a pinned average before the full grid (C9:
   Dotabuff, League of Graphs, Mobalytics); method text and filters folded
8. Context inside the cell: last patch's value or the change under the number (C10:
   League of Items, dpm, op.gg), the game count in one fixed grey spot (C5)

## Site-wide: layout

Measured with Playwright on the live site (Chrome, 20 Oct 00:40), then the same pages
with one injected stylesheet (CSS only, no HTML change): wider wrap, tighter padding,
tile labels and unit words hidden, histogram floated right, opponent tiles 76 px.

| Page and screen | Now | CSS-only prototype |
| --- | --- | --- |
| Darius, 1920x1080: first lane opponent at | 1,056 px, 0 of 41 on screen | 671 px, 41 of 41 |
| Darius, 1920x1080: numbers on screen | 57 | 217 |
| Darius, 1440x900 laptop | 0 of 41 opponents, 44 numbers | 17 of 41, 153 numbers |
| Darius, phone 390x844: first opponent at | 1,923 px (2.3 screens), 14 numbers | 688 px, 5 on screen, 44 numbers (filters, histogram, build strip, banner folded) |
| Champions index, 1920x1080 | 17 rows (42 px) | 25 rows (31 px) |
| Champions index, phone | 10 rows (36 px) | 12 rows (30 px) |
| Fixed chrome (header, subbar, preview) | 134 px desktop, 190 px phone (22% of the screen) | target 48 + 22, phone 48 |

Where the space goes today:
- Page width capped at 1,200 px (style.css .wrap): on 1920 wide, 720 px of every page
  is empty; on Darius the histogram card (420 px) leaves 740 px blank beside it
- Three stacked bars before content: header 53, subbar 45, preview banner 36 px
- Stat tiles: 130x98 px boxes for one number each, with a label above and a caption
  under ("of games won")
- Opponent tiles 104x152 px: five lines, three of them unit words ("vs usual", "gold",
  "games") repeated 41 times
- Phone: Region, Rank, Period and Opponents selects stack to 158 px, the histogram
  another 225, before the first stat at 764 px
- Champions index: 42 px rows (7 px padding, 1.55 line height, 32 px icons)
- Matchup page on phone: the chart starts at 1,340 px under two rows of tiles, radio
  buttons and the table

Global changes (tokens in style.css :root, then used everywhere):
- `.wrap` max-width 1,560 px, side padding 24 (16 on phone)
- One header row of 48 px: brand, nav, section tabs, region and period switch, search;
  the preview notice as a 22 px strip (policy keeps a banner) or a header badge
- Type: body 14 px / 1.45; tables 13.5 px / 1.3 tabular; h1 22, h2 16 with 16 px above
  (now 32); captions 12 px
- Cards: padding 10x12 (now 14x16), gap 8, radius 8; tiles as one strip of figures
  (label 11 px over a 17 px value), no caption line
- Tables: 30 px rows (padding 2x8, 24 px icons); sorted column with a faint band (u.gg)
- Phone: filters behind one "Filters" button, histograms and method in details, the
  subbar as one scrolling chip row

## Site-wide: colour system

Validated with the dataviz skill's validator against the panel #111214 (contrast, and
colour-blind separation between matching steps of the two arms: protan 12-40, deutan
14-29, normal 14-46 OKLab dE; adjacent steps at least 6 deutan, so the sign or a bar
stays as the second cue). The current scale (tierlist.zig wrColour) is the same idea but
muted: fixed lightness, chroma at most 0.15, full at 4.8 points, so 53% and 59% look
alike and nothing ever pops.

Coloured numbers (text on the dark page; all at least 5.3:1):

| Step | Below | Above | Use |
| --- | --- | --- | --- |
| 4, extreme | `#fb2b9a` hot pink | `#0bfaf4` electric aqua | as text (a filled chip with dark text until 20 Oct) |
| 3 | `#fe6652` | `#25d1ff` | |
| 2 | `#f79c40` | `#59aaf8` | today's --bad / --good |
| 1 | `#caac83` | `#89afd6` | |
| 0, neutral | `#a1a5ab` | | recedes |

Cell fills for heat-map tables (number in --text on top; the design reader's scale,
5.0-11:1): below `#ae4200` `#7d3400` `#512a0f`, neutral `#202225`, above `#153758`
`#104e89` `#1a68bf`; step 4 is the vivid colour above.

Other tokens:
- Team: --us `#5aaeff`, --them `#f0596b`, sides only (review, Daily Draft), always with
  a label or side; blue is also "good", which fits the review (your team ahead) and is
  acceptable on Daily Draft because sides are labelled. Step 3 below (`#fe6652`) is
  near --them: never colour a red-side number with the scale
- Magnitude without a good or bad (pick rate, ban rate, games, a matchup's gold lean):
  a neutral ink bar `#5d6169` to `#b4b7bd`, never blue or orange
- Roles: no colours; Riot's position icons (game art is allowed, logos not)
- Accent violet (--accent, --brand): links, selection, brand only, never data
- Moments in the review (--turn, --gain, --drop, --cost): keep; they are classes, not
  magnitudes

Steps, in points of win chance the value implies:
- Aggregate numbers (a champion's or matchup's rate over many games): 1, 2, 3.5, 5.5.
  On the champions index (356 champion roles with 500+ games, 20 Oct) that is 39%
  neutral, 33% step 1, 16% step 2, 8% step 3 and 4% (14) vivid
- One game's numbers (Your games): 2.5, 5, 10, 15, from the slopes below
- Under 200 games, or when the shrunk value's interval spans 0: one step less a 100
  games short, grey at the floor

## What to colour (measured)

From docs/learned.md and docs/model.md, plus new raw associations on 877,814 games
(snap-20261018T1007Z pack, every platform, Platinum+; learned.md "Early game" 20 Oct).
"Matchup level" compares matchups with 300+ games; "game level" compares players in
single games; raw, the team's state not held unless stated.

| Number | Where | Effect on the result | Typical spread | Colour |
| --- | --- | --- | --- | --- |
| Champion win rate | index, champion | it is the result; true spread between champions 1.3-2.8 points by role | binomial noise 1.6 points at 1,000 games | aggregate scale from 50% (or the role's average) |
| Matchup win rate | grid, matchup | 2.3-2.7 points between matchups, 40-90% of it the opponent's own strength | noise 2.9 points at 300 games | plain ink; colour goes on vs usual |
| Vs usual | grid, matchup | the matchup's own effect: about 2 points top and mid, 1.2 bot, 1.0 support, 0.7 jungle | shrunk already | aggregate scale; few reach step 2, which is the honest answer |
| Gold at 14, matchup average | grid, matchup tiles | -2.6 to +2.3 points of matchup win rate per 1,000 gold, about 1 point per typical spread | 300-480 gold between matchups | none: neutral bar or plain sign (today blue or orange: Kayle +998 in blue at 48.5%) |
| Ahead at 14 share, CS at 10, first item time, deaths before 15 (matchup averages) | matchup facts | 1.4 points or less per typical difference (deaths most: -1.3 to -2.5 points per death of difference) | ahead share 9-14 points, CS 2-9, items 0.9-1.6 min | none |
| Level 6 time, kills before 6 (matchup) | matchup facts | not measured (not in the pack); a kill is worth 2.6-3.8 points through its gold and about nothing beyond it (model.md event values, Whose seat) | | none until measured |
| Early lean (champion's average gold at 14) | champion | -4.2 to 0 points of champion win rate per 1,000 gold | 230-300 gold between champions | none; ahead or behind in words |
| Lane gold lead in one game | review | team state held, 1 sd at 15 min is worth 8.1 top, 9.5 jungle, 9.1 mid, 14.9 bot, about 0 support (model.md Whose seat); raw +1 sd against -1 sd 37-51 points | 850-1,700 gold at 14 | game scale via the role's slope; support's own gold grey |
| Deaths before 15, CS at 10, first item time in one game | review | raw: 0 deaths 65-71% won, 4+ 31-39%; CS and item time +1 sd against -1 sd 20-32 points (support CS reversed); beyond gold almost nothing | | through gold: colour the gold, show these plain or faint |
| Win chance and its swings | review | the outcome itself | | game scale, as today |
| Pick rate, ban rate | index, champion | no link: pick share and win rate correlate -0.37 to +0.43 by role, the sign flipping | | neutral bar |
| Games | everywhere | sample size | | none; drives the fade |
| Patch change | champion, index | win rate change; already tested for "clear change" | | aggregate scale when clear, else grey |

## Per page (ranked; source in brackets, slugs in research/sources/)

Champions index
1. Win rate as a heat cell (fills above), vivid colour at 5.5+ points; sorted column band
   (finviz-map, ugg-darius-matchups)
2. 30 px rows, 24 px icons, role as an icon: 25 rows a 1080p screen (bbref-jokic 23 px
   rows)
3. Patch change small under the win rate, or an arrow in the rank cell (dpm-tier-list,
   leagueofitems-darius, opgg-tier-list)
4. Pick and ban as neutral bars in the cell, not diverging (measured: no link)
5. Optional: top 5 a role as leader cards above the table, "Show 6-10" (fbref-pl-stats)

Champion page
1. First screen: one strip of figures (win rate, pick, ban, games, patch change, early
   lean in words) in place of the 98 px tiles and three prose lines; histogram in the
   right column (dpm-tier-list role share under the role icon)
2. Opponent tiles 76 px: vs usual carries the colour (as a fill or the tile's edge),
   raw win rate in ink, gold at 14 neutral, unit words once in a legend row (dpm-darius
   labels once): 41 of 41 on a 1080p screen
3. A pinned "average opponent" tile first (mobalytics-darius-counters); hardest and
   easiest five as strips above the grid, facts with games, never "best pick"
   (dotabuff-am-counters, leagueofgraphs-darius-counters)
4. Builds: skill order as a 4x18 grid of squares (lolalytics-darius-build ^f7) or
   letter squares (opgg-darius-build); rare options faded (opgg, dpm)
5. The champion's lane numbers against its role as FBref percentile bars, neutral ink
   (fbref-salah-scout): shows style without implying wins

Matchup page
1. Tiles into one strip; colour only vs usual; the Gold/XP/CS table with neutral bars
   sized by the lead (measured: lane leads don't pick the winner of a matchup)
2. Gold, XP and CS as three small charts side by side, not tabs (dpm small multiples,
   tufte-sparklines)
3. Word labels with games, "Even lane, 1,177 games", for lane and for game separately
   (dpm-darius chips, itero-home Safe/Bully): the policy-safe form of "+X%"
4. Facts as rows: bold number, short bar, one line of words
5. Phone: the chart right after the strip (now at 1,340 px)

Your games review
1. Top: Riot ID box, example notice and role tabs (330 px before the player) into one
   48 px row
2. Lane and team numbers of the game on the game scale: gold leads vivid when large
   (bot most, support grey), deaths and CS faint
3. Win chance chart as ESPN: each side owns one end, icons at the ends, moments listed
   under (espn-nfl-gamecast); swings named by size bands finer near zero
   (chesscom-move-classification), in plain words, not "blunder"
4. Lane verdict in one word (Won, Even, Lost) with the gold, and item minutes under
   item icons (dotabuff-match)
5. Keep the film strip: sparklines in cells already (Tufte)

Daily Draft
1. Teams face each other as lane rows (blue left, role in the middle, red right), not
   two 290 px cards with 750 px between role and name
2. After the guess, fact chips on the aggregate scale with games (dpm-darius)
3. Option cards 130 px for one icon: half height, facts under them after the guess

Learn
1. Lesson examples as champion tiles, not sentences (plan already)
2. Drill reveals in the same scale and chips as Daily Draft, so colours mean the same
   on every page

## What lolalytics gets wrong (lolalytics-darius-build)

- Colour for metric identity: Win Rate green, Delta yellow, Pick Rate purple, so a
  reader learns a key that says nothing about size
- Every number the same weight; two-decimal win rates (49.81); condensed 11-12 px
  figures centred, so decimals don't line up
- Delta 1 and Delta 2 behind ? icons, side by side
- A stock sunset image and ads around the summary; on the tier list the first row sits
  at 710 px of 1,000; many full-width panels empty until scrolled to
- What to keep: the 4x18 skill grid, role share under the role icons, the transposed
  counter strip (one column per opponent, 13 in 730 px)

## Build order (low risk first)

1. Tokens only: the step colours, fills, chips and neutral bar in style.css :root; no
   visual change. One commit
2. One colour function: tierlist.zig wrColour (and filters.js wrColour, its JS copy)
   returns a step class (`c-hi2`, `f-lo1`, `chip-hi`) from points and a scale (aggregate
   or game), with the thin-data fade; champion.zig and matchup.zig callers pass points.
   Site hashes move (deploy/site-hashes.sh)
3. Global density CSS (wrap, type, cards, tables, h2 margins); check 1920, 1440 and 390
   on every page; prototype values in data/team/2026-10-19-night/design-proto.mjs
4. Opponent grid: compact tiles, gold neutral, legend row (champion.zig, style.css .og)
5. Champions index: heat cells, neutral pick/ban bars, patch change under the rate
   (tierlist.zig)
6. Header: subbar into the header row, slim preview strip, phone filters button
   (html.zig, write.zig)
7. Champion first screen strip and side histogram (champion.zig)
8. Matchup strip, neutral bars, small multiples (matchup.zig, lanechart.zig)
9. Review: top row, game scale (your.zig, review.js)
10. Daily Draft and Learn (daily.zig, daily.js, learn.js)

Open: level 6 and kills before 6 against the result need the timelines (a lab export
like the pack's first_item); a hallway test of the scale with a colour-blind player.
