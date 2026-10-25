# Champion pool

Identity: your champions, the lanes they leave open, and what to learn next, with how
hard each one is to pick up. Plan 24 Oct 2026, team run 2026-10-24-ui (session play).
Mock: data/team/2026-10-24-ui/mocks/pool.html.

## Who comes and why

- A one-trick or two-trick looking for a second champion: what covers my main's bad
  lanes, what to play when it is banned, what my main's players also play
- Anyone curious which champions are hard to start on (the pick-up gap): Jacob's
  favourite part, today a 172-row table under a paragraph
- Players arriving from Your games: their own pool already known

## What Jacob said (24 Oct)

- "champion pool i really like my fav thing here is the gap of how hard a champ is to
  learn, but this page doesnt really have a good identity rn, WAYYY TO MANY WORDS again"
- "if we know what person they analysed recently it could show the pool for that player
  but also great if they have a way of selecting a specific pool"
- "The search here is way worse than other pages for champs and the drop downs look shit,
  not like they are meant to be there"
- "In general the page has no flow, shows too much info, just not actually very helpful
  or useful and the ui sucks. The really long tables are just too much as well, too much
  to scroll though, we need to find a better way of showing all this"

## What is wrong today (live, 24 Oct)

- 180 words before the first number (intro 52, method paragraph 98, pick-up intro 30)
- Three equal plain inputs (Main, Also, Also); typing a name that misses does nothing
- Scope shown as odd chips ("EUW · All time, not by period · Plat+", "All regions, not
  EUW alone") that look like dropdowns
- Pick-up: 172-row table, New coloured against 50% (all orange) and Practised (all blue):
  colour says which column, not which champion (ui-audit.md)
- With a main: four blocks of free text in flex rows ("+1.2 vs Dr. Mundo (566 games;
  Darius there: -2.3)"), ragged columns, "0% of Darius players play it" listed as an
  option, phone scrolls sideways

## Flow: three steps down one page

1. **Your pool** (top band). Up to three champions as large ChampIcons with role, each
   removable; "+" opens ChampRolePicker. Prefilled when the browser has a Your games
   report: the player's most played champions in it, with a source Chip ("from
   MeioNeiz#EUW", x clears). Empty: ChampSearch plus a row of the eight most common
   mains as one-tap icons
2. **Where your pool is weak** (with a pool). `HeatGrid`: rows are your main's hard
   lanes (its five worst matchups by points vs usual, icons), columns your pool
   champions then the suggested additions (dashed heads); each cell the champion's
   points into that enemy, on the fill scale, "·" when thin. The gap reads at a glance:
   the Mundo row is orange across your pool and blue under Mordekaiser
3. **What to add** (with a pool): `CandidateList`, 3-5 options (product rule), each one
   row: ChampIcon, name, lanes covered as Chips ("+1.2 Mundo", "+2.8 Jax"), share of
   your main's players who play it (Bar, "49%"), pick-up as a mini `Versus` dumbbell
   (new 47.5 to practised 52.8) with a Badge only when clearly harder or easier. Tap: the
   lanes with games, and the champion's link. A Segmented above switches the reason:
   "Hard lanes" (cover), "When banned" (fallback), "Also played" (also)
4. **How hard to pick up** (always; the page's star, first when no pool is chosen).
   `Versus` dumbbell chart, one row a champion: a dot for new players' win rate (under
   30k mastery), a dot for practised (100k+), the line between is the gap, the gap as a
   Delta at the end; sorted by gap. Role Segmented (All, Top, Jungle, Mid, Bot, Support),
   ChampSearch highlights and scrolls to a row; your pool's champions pinned on top. 20
   rows, then "All 172" opens the rest in place. Harder/easier Badge only for the
   clearest (today's kind field)

## First screen

1280, no pool chosen (first visit):

```
Champion pool                                          [EUW ▾] [30 days|Patch] [Plat+ ▾]
┌ Your pool ─────────────────────────────────────────────────────────────────────┐
│ [ Champion ⌕ ]   or  (Darius)(Yasuo)(Ahri)(Lee Sin)(Jinx)(Thresh)(Ezreal)(Kai'Sa) │
└────────────────────────────────────────────────────────────────────────────────┘
How hard to pick up      [All|Top|Jungle|Mid|Bot|Support]   [⌕ Champion]
                40%        45%        50%        55%
Rengar   ⓘ       ●───────────────────────●            +11.0  Harder
Udyr               ●──────────────────────●            +9.9
Nunu               ●─────────────────────●             +9.4
... 20 rows ...                                   [All 172]
```

With a pool (Darius, from Your games): the pool band shows Darius and Garen with the
source Chip; the HeatGrid and the CandidateList sit side by side (grid 520 px, list
720 px); the pick-up chart follows below with Darius and Garen pinned.

390: the pool band (icons 48, two rows), the HeatGrid (5 rows x up to 5 columns, 44
px cells, fits 358 px), CandidateList rows two lines each, then the pick-up chart with
a 190 px axis.

Words on the first screen (no pool): "Champion pool", filter labels (3), "Your pool",
"Champion", "or", "How hard to pick up", six role labels, "All 172" = 18. Today: 180
before the first number.

## Components used (register names)

New on this page: none; it is built from shared parts. HeatGrid, CandidateList (Pool
variant: reasons are lanes, plus share Bar and a pick-up dumbbell), Versus (dumbbell),
ChampIcon (removable), ChampRolePicker, ChampSearch, Segmented, Select (region, rank),
FilterBar, Chip (source), Badge (harder/easier), StatCell, Bar, Toggletip, Card,
SectionHead.

## Interactions

- Add a champion: ChampRolePicker (type-ahead, icons, role chosen by its main role);
  remove with x; the pool is kept in localStorage and in the URL (#pool=122,86) so it
  can be shared
- From Your games: on load, if `your-last` exists, offer it as the pool (prefilled,
  source Chip); x clears to an empty pool
- HeatGrid cell tap: Toggletip with games; column head tap: that champion's page
- CandidateList: Segmented switches Hard lanes / When banned / Also played; row tap opens
  its lanes; the champion link inside
- Pick-up chart: role Segmented filters; search highlights and scrolls; sort by gap
  (default), by new, by practised (header taps); All 172 expands

## Data needed

- Mains, also played, hard lanes, cover and fallback: exists (data/pool.json, 119 KB,
  src/pool.zig), per champion, not per role (Ashe support vs bot: not possible yet, said
  in pool.md before; leave)
- Pick-up gap: exists (data/learning.json: new and practised rates, gap, kind), per
  champion, every region (scope Badge "all regions" with a toggletip, J23)
- HeatGrid full matrix: pool.json lists only cover lanes of 1+ point. The grid needs every
  pool champion against each hard-lane enemy (including bad and thin cells). The
  champion pages' opponents tables have it (vs usual, games); new: either a small
  per-champion matchup file the page fetches (data/vs/<id>.json, ~3 KB each) or the
  fragment route (foundation's server fragments). Small-medium
- Prefill from Your games: client side, `your-last` in localStorage (same origin) holds
  the last report; the page counts champions in its games. Exists; check the stored
  shape keeps the games list (your.js lastWrite)
- Filters: region and rank apply to the lane numbers (curves); pool shares come from
  mastery "all time" and pick-up from every region: each block says so with a scope
  Badge and toggletip instead of the odd chips. Exists

## What is cut

- The intro (52 words) and the method paragraph (98); the pick-up intro (30)
- The three equal plain inputs; the scope chips that look like dropdowns
- The 172-row table as the default view (the DataTable stays reachable as "Table" in the
  chart's header for sorting by any column)
- Free-text option rows. Options almost none of the main's players play stay only to
  reach three (product rule: 3-5 options), faded, share shown as "<1%" (Darius: only two
  cover options have players, so Jax stays)
- "Darius players also play" as a 12-row block: folded into the CandidateList's "Also
  played" view

## What the desktop could reuse

The pool is the app's own setting (meiolol-app session knows the player's champions):
PoolSlots as its pool editor, the HeatGrid as "your pool vs their likely picks" before
champ select, CandidateList with the same rows. The pick-up dumbbell: an info view only.

## Questions for Jacob (24 Oct)

1. Prefill from the last Your games lookup automatically, or offer it with one tap?
2. Pick-up chart first when no pool is chosen (as planned), or the pool picker alone?
3. Keep the "Table" view of all 172 for sorting, or the chart only?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Empty by default; offer "your pool from Your games" with one tap, showing what it
   would add
2. The page's purpose must be clearer. The pool is the main part (weak lanes, what to
   add: "just so cool"); how hard a champion is to pick up is often the most
   interesting thing. Both stay; the flow between them gets reworked
3. No Table view; the chart must show all the information well instead

## Jacob's answers (review v6, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v2-*.

1. No full pick-up chart below the pool: like the matchup field it makes the vertical
   seem to matter. Adding champions must be easy: e.g. a side panel for choosing pool
   champions, showing those we know they play and high mastery (mocks round 3)

## Jacob's answers (review v7, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v3-*.

1. Mastery in the picker: yes, add the champion-mastery-v4 call per lookup
2. "Looks a bit funny before you pick pool", otherwise good (mocks round 4: empty state)

## Jacob's answers (review v9, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v4-*. No re-review: refine while building.

1. Round 4 fine. Champion difficulty (pick-up) wanted somewhere general again, as the
   old pool page had: maybe its own page; to be looked into
2. Pick-up difficulty (chat, 25 Oct): not yet, later. The champion page shows its own
   difficulty; for now at most a very lean page of every champion's pick-up, linked from
   champion pages and the pool; design it properly later
