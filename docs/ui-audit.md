# meio.lol UI audit, 22 Oct 2026

Live site, Chrome via Playwright at 1280x800 and 390x844 (isMobile, touch), UA tagged
`meiolol-agent`. Screenshots were taken in a session scratchpad and not kept; retake
with deploy/qa.sh once it exists. Read against docs/design-ideas.md
and docs/frontend-rework.md section 2; things those docs already list (wrap width, 98 px
tiles, 104x152 opponent tiles, stacked chrome, CSS drift, U+2212 vs "-") are not
repeated unless the live page shows a new consequence.

Pages: home, champions.html, champion/darius.html, matchup/top/darius-vs-garen.html,
your.html (empty and #example), daily.html (before and after both guesses), learn.html
(puzzle, reveal, Basics), pool.html (empty and with Darius as main), patch/patch.html.

## Home

First impression: the best looking page; the live example review sells the product.

- The brand is said twice in the first screen: header logo, then a 36 px logo lockup above
  the h1, which itself sits ~130 px down on desktop. Drop the hero lockup; h1 at the top
- Record book cards colour by category, not size: "6 objectives" red, "38% → 68%"
  yellow, "-852" green. The same cards on Your games repeat it ("+713" red because it was
  a loss). This is the lolalytics mistake design-ideas names
- "Your lane against typical" card: "+289 +643" side by side with no label for which is
  which; "+43s" red and "-59s" green use green/red, the rest of the site blue/orange
- "New patch: what changed" line sits flush under the Between games cards (no gap),
  reads like a stray caption. Phone: the example review starts at ~750 px, below the fold

## Champions index

First impression: clean table, but the order looks wrong and the width is wasted.

- "Win rate ▾" sorted, yet 53.2, 53.8, 52.9, 53.2, 52.9, 52.4, 52.7 down the column. The
  reason (sorted by the shrunk rate) is in a paragraph after 210 rows, 11,000 px down.
  A player reads it as a bug (shots/champions-desk-fold.png)
- 1280 wide: ~190 px of nothing between Role and the win rate bar; the violin bar has no
  label on screen and "Influence" is unexplained until the footer paragraph
- Defaults "Min games 1419" and "Min lane % 10" are internal knobs at hero level
- Phone keeps Influence (the least understood column) and drops Pick and Ban; role tabs
  wrap "Support" onto a second line; 205 px of chrome before the h1

## Champion page (Darius)

First impression: thorough, but a long report rather than an answer.

- First screen: a 420 px histogram of player win rates comes before the champion's own
  win rate; then two dense prose paragraphs ("+160 gold (±20) ... (±1)") before builds
- Colour contradicts the copy: Jungle "Patch 16.21 against 16.20: no clear change,
  54.6% of 549 games" with 54.6% in vivid aqua (step 4 on 549 games, principle 4)
- Two "Win rate colour" legends on the site with different stops: index 44.5 to 55.5,
  opponent grid 39 to 61. 53.3% is pale blue here, near-vivid on the index
- "Lane opponents 40, hardest first": Mundo 43.9% / -2.3 above Riven 42.4% / -2.4; again
  neither visible number is the sort key. "Players who main Darius also play": 44, 22,
  45, 49% in that order, name and number 1,100 px apart in a full-width box
- Mixed number formats on one page: "27,050" in tiles, "5558 players", "1444" games

## Matchup page

First impression: the strongest data page; dashboard layout works on desktop.

- Four game counts for one matchup: 1,540 (tile), 1,514 (ahead at 14), 1,529 (timelines,
  By rank "All games"), 1,111 (build, patch 16.20). Headline "Darius's usual 48.0%" while
  the champion page says Darius Top 49.1%: two "usual" numbers a click apart
- Phone: the gold chart, the page's main chart, is the scaled-down SVG with ~6 px axis
  text, while XP and CS below it render full size (shots/crop/matchup-phone-charts.png)
- Build row: six equal 240 px cards, four of them hold one icon and two lines; Runes
  against Garen leaves the right 40% empty with one floating caption
- Gold line in accent violet (design-ideas: violet never data); head to head uses team
  blue/red right beside a blue "good" 50.2%

## Your games

First impression: rich review, but the empty state and the example fight each other.

- Loading flash: your.html#example first paints the empty-state hero ("Review your
  games", 30 px h1, Your data block), then JS replaces the whole page with the example
  (shots/your-example-desk-early.png vs your-example-desk-full.png)
- Empty state: one input in the left 45%, the right 700 px blank; no preview of what a
  review looks like (home has the live example; this page should reuse it)
- Lane panel: "No typical game yet" then a table whose Typical and vs typical columns are
  all dots; labels wrap ("Deaths before / 14") in a 360 px column with an empty column
- Phone: Over time table clipped at the right ("Gold dif", "-127,") with no scroll cue;
  the role word "mid" wraps under the icon on some rows and not others, and every row is
  mid because the Mid tab is already selected
- Moments use green/red ("+21% huge", "-13% big"), "Spot on"-style green; the win chance
  fill turns hot pink (step 4 colour) as a team colour

## Daily Draft

First impression: fun format, but the puzzle starts below two tall roster cards.

- Phone: the actual question ("Who did they lock in?") is at ~920 px, under two full
  roster cards. Desktop: Blue side card has a violet top border, Red side orange, while
  the winner button and scoreboard use red: three colours for "red side" on one page
- Loading: a "Loading..." bar, then the page grows 900 px and the footer jumps
- After the guess, option cards lead with "Few games" in bold for the two thin options;
  "+400 gold at 14" in blue (gold should be neutral). Result chips "✓ Pick" blue and
  "✗ Winner" orange, the archive row for the same result uses ✅❌ emoji
- Archive: twelve identical "not played" rows; Lanes at 14 minutes table is 650 px wide
  under a full-width scoreboard (shots/daily-guess2-desk.png)

## Learn

First impression: the calmest page; one card, one question.

- The slider starts at 52.5%, shown at 32 px as if it were an answer. Pressing Lock in
  without moving it scored "Spot on." (real 51.7%): the default gives the answer away
- Real value in accent violet and a violet bar; "Spot on" green; progress bar green.
  Answer colours should match Daily Draft's reveal (design-ideas Learn 2)
- Tabs are white-filled pills here, segmented controls everywhere else; Basics' early
  data notice is full width (1,232 px) above a 760 px lesson card
- Mastery bands differ from Pool: under 10k / 300k+ here and on the champion page, under
  30k / 100k+ on Pool; "4 points from new to main" here, "3.1 on average" on Pool

## Champion pool

First impression: a useful tool hidden under a 172-row table and a paragraph of method.

- Before a main is picked, the page is mostly the pick-up table; the three inputs are
  equal weight, the main input not visually primary. Typing "Dari" + Enter does nothing
  (no match, no message)
- Pick-up table: New column almost all pink/orange, Practised almost all blue, because
  both are coloured against 50%. Colour says which column, not which champion; colour
  the Gap only. "Gap ▾": Rengar +11.1 above Nunu +11.5; Akshan +7.8 "Usual", Aatrox
  +5.9 "Harder", with no visible reason
- With Darius picked: "Options into Darius's hard lanes" rows are free text in
  space-between flex, columns differ per row; phone squeezes them to 3 words a line and
  the page scrolls sideways (scrollWidth 406 on 390) (shots/crop/pool-darius-phone.png).
  "Yone: 0% of Darius players play it" is listed as an option
- Hard lanes disagree with the champion page: Mundo -1.8 / Riven -1.5 here, -2.3 / -2.4
  vs usual there; Akali (third hardest there) is missing here

## Patch page

First impression: honest and readable, but three tables that do not line up.

- Colour on the absolute rates, not on the change: Zilean 51.2% blue → 56.1% aqua, the
  gap column plain. Shen 56.4% of 337 games in vivid aqua
- The subbar period switch shows "Patch 16.21" selected, the copy says "whichever period
  is picked above" and nothing changes: a control that does nothing
- Each table sizes its own columns (16.20 at x 414, 474, 422); 52 px rows for one line;
  intro promises "lane matchups", none listed. Phone: rows 4 lines tall ("of / 2,956")

## Between pages: same thing, different look

- Good/bad: blue/orange (stats), green/red (review, home cards, Learn), blue/red teams;
  red side drawn violet/orange/red on Daily
- Win rate scale: two legends with different stops; pool and patch colour vs 50%
- Thousands separators: "27,050" (hero, patch) vs "9207", "51116" (index), "6123" (pool),
  "1444" (champion), "30736" (Learn Basics), "5558 players"
- Sorted lists whose visible numbers are out of order: index, opponents, also play, pool
- Footer scope: home and Champions "last 30 days, 361,081 / 354,551 games"; Your games,
  Daily, Learn, Patch "patch 16.21, 30,736 games", whatever the page shows
- Tabs: segmented (roles, Common/All), pills (Learn), sort chips (opponents), circles
  (Basics); four looks for "pick one"
- Phone header on every page: nav truncates to "Champio", the search icon squeezed;
  Champions subbar truncates "Champion pool" with no fade or scroll hint

## Top 10 by player impact

1. Phone header (every page). The nav clips "Champio" and the section subbar clips
   "Champion pool". Fix: phone header = logo, current section name, search icon, menu
   button; section tabs as one scrolling row with a right-edge fade
2. One win rate scale everywhere (index, champion, pool, patch, Daily). Live breaks: two
   legends, pool New/Practised coloured vs 50%, patch colours rates not change, aqua on
   337-549 games. Fix: colour only the difference that is the answer (vs usual, gap,
   patch change), fade under 200 games, one legend component
3. Sorted lists that look unsorted (index, opponents, also play, pool). Fix: show the
   sort key; a small "adjusted" value under the rate, or header text "Win rate, sorted
   adjusted ⓘ" with the tooltip there, not 11,000 px down; fade thin rows
4. Same fact, different numbers (champion vs matchup "usual", champion vs pool hard
   lanes, mastery bands, footer counts, four counts on a matchup). Fix: one definition per
   word; where scopes differ say so in the cell ("EUW only", "opponent-weighted"); one
   game count per page in the scope line
5. Pool results on phone (sideways scroll, 3-word columns) and desktop (ragged rows).
   Fix: each option as a card: icon and name, then one line per hard lane ("+1.2 vs
   Mundo, 491 games"), share of mains and pick-up as two chips; drop 0% options
6. Three good/bad palettes. Fix: review deltas and record cards on the game scale
   (blue/orange) with sign; Daily cards bordered --us/--them; result marks as the same
   chips in archive and summary; Learn reveal on the same chips
7. Matchup gold chart on phone at 6 px text. Fix: render it like XP/CS (container width,
   fixed pixel height, 11 px labels); first after the tiles
8. Loading flashes (Your games #example, Daily, Pool). Fix: set a class on <html> from
   the hash in an inline head script so the empty hero never paints; Daily and Pool
   skeletons at final card heights so the footer stays put
9. Learn slider default scores "Spot on". Fix: no value until touched (hidden thumb or
   "drag to guess"), Lock in disabled until moved, value shown in muted ink until then
10. Empty and dead UI: Typical/vs typical dot columns, patch period switch, four one-icon
    build cards, "Few games" as a headline, role column under a role tab, twelve "not
    played" rows. Fix: hide what has no data, disable switches that do not apply, fold
    the archive to a strip of 12 day squares

Also: one number formatter (thousands separators everywhere, minus sign one way); Your
games empty state should reuse the home example; patch tables share one column grid.
