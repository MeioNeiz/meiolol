# Champions table (champions.html, role/<role>.html)

Plan only (team run 2026-10-24-ui). Mock: data/team/2026-10-24-ui/mocks/champions.html.

## Identity

Every champion in every role on one screen-dense board: how each is doing now and
which way it moved this patch. The way into the champion family (champion.md).

## Who comes and why

- "What's strong in my role right now": scan a role, top and bottom
- "What changed this patch": the movers, then the patch page for why
- Finding a champion in a role to open its page (search, then click)

## What Jacob said (24 Oct)

"champions screen, the number showing from patch to patch, i think is a great one, but
also just doesnt make sense where it is, this whole table is too generic as well, could
be much more specialised and show the information way clearer."; "if i pick on
champion with its role on the champions list page, i want that role not some other";
"minimums doesnt need to be hidden behind a dropdown"; on the champion page: "the
players win rate thing is too generic, not precise, or clear enough".

## Decisions

- A role at a time, RolePicker at the top (same component as the champion page), plus
  "All". Default: the visitor's main role when known (Your games, pool), else All.
  Under a role the Role column goes; under All it is a role icon, not a word
- The patch change gets its own visual, `Delta arrow`, in its own column: last patch's
  rate as a hollow dot, this patch's as a filled dot, an arrow between on a shared
  45-56% track, the signed change beside it ("+2.6"), coloured only when clear, ± in
  the Toggletip. The 30-day rate stays the main column. Moves you can see as distance,
  not a 9 px number under another number
- The win rate cell is the answer (design-ideas principle 5): larger, scale ink, a heat
  fill behind it at steps 2+ (the --f-* fills). Sorted by the pulled rate as today; the
  header's Toggletip says so; thin rows fade instead of a "Minimums" knob
- Pick and ban: one `Bar` each (neutral ink, never blue/orange), number beside
- The players' spread violin leaves the table (it is the champion page's
  Histogram); the table had no room to make it precise
- Influence: kept, renamed "Ban value" with a Toggletip ("games its team wins above the
  role's average per 10,000 games it isn't banned"); open question 2
- Minimums: no dropdown. A visible segmented control in the toolbar, "Games 500+ |
  1.5k+ | 5k+", default 1.5k+ (today's 1,419 rounded); off-role picks (under 10% of a
  champion's games) behind a "+ off-role" chip at the table end, like the matchup grid's
  "+127 rare"
- Rows link to champion/<name>.html#<role>: the role clicked is the role opened
- Real table: DataTable, every column sortable (click header, again to reverse, the
  sorted column banded), sticky header, keyboard, `aria-sort`

## First screen (1280x800)

```
subbar: region | period | rank (as every Champions page)
h1 Champions   RolePicker [All | Top | Jungle | Mid | Bot | Support]   ChampSearch
toolbar: Games [500+ | 1.5k+ | 5k+]                       403,364 games · 16.21 vs 16.20
DataTable  # | champion | Win rate (heat cell) | 16.21 vs 16.20 (Delta arrow +2.6) |
           Pick (Bar) | Ban (Bar) | Ban value | Games
```

29 px rows: 22 rows on a 1280x800 screen, 30 at 1920x1080. Phone: # dropped, champion
icon + name, Win rate, Delta arrow (dots only, the number in the tip), Pick; Ban,
Ban value and Games behind a column chooser (DataTable's phone variant).

Words on the first screen (without names, numbers): "Champions", role names, "Games",
column heads (Win rate, 16.21 vs 16.20, Pick, Ban, Ban value, Games), "games": ~16.
Today: ~70 (two sentences above the table and the run-on build link).

## The rest

Only the table. The method paragraph (11,000 px down today) becomes the Toggletips on
the column heads. The build index link goes (builds.md).

## References (research refs/tier-list/notes.md)

| Element | Model on | Take | Leave |
| --- | --- | --- | --- |
| Sorting | lolalytics, dpm | every header sorts; dpm's rank shown apart from the sort order | |
| Minimums | lolalytics | visible, never in a dropdown (ours a Segmented of three floors, not free number inputs) | lolalytics' 600 px of chrome above the table |
| Role links | lolalytics, u.gg, op.gg, dpm | the role in every link: every other site does it, ours is the only one that drops it | |
| Change in a row | dpm (signed change under the value, grey near zero) | the colour rule: grey when unclear, coloured when clear | its place under the value: Jacob says that is where it doesn't make sense, hence the Delta arrow column |
| Phone | dpm | drop columns, keep a table, keep the rate | cards |
| Tier letters | u.gg, op.gg | | opaque and disagree with their own numbers |

## Components used

RolePicker, ChampSearch (filter mode: narrows the table, aliases and typos as the
header search), Segmented, DataTable, StatCell fill, Delta arrow, Bar, Toggletip,
RoleIcon, Chip ("+ off-role").

## Interactions

- RolePicker: filters rows in place, updates the URL (`champions.html#top`), keeps sort
- Header click: sort; again: reverse. Sort key in the URL
- Search: filters rows as you type (one champion: its roles, all shown)
- Games segmented: filters; counts update
- Row click: champion page in that role. Delta arrow tap (phone): its Toggletip
  (16.20 48.7% of 23,166 → 16.21 51.3% of 6,678, +2.6 ±1.4)

## Data

| Need | Status |
| --- | --- |
| Win, pick, ban, games, ban value per champion role | exists |
| Previous patch rate and games per champion role, clear flag | exists (CH8) |
| ±95% per change | exists (patchday, ff7836e) |
| Visitor's main role | exists client side when Your games or pool has a player |

## Cut

Two intro sentences, the run-on build link, the "Minimums" dropdown, the spread violin
column, the footer method paragraph, the Role column under a role tab, the number under
the win rate.

## Desktop reuse

DataTable, RolePicker, Delta arrow, StatCell fill; a champ select "your pool" list is the
same table filtered to the pool.

## Questions for Jacob (24 Oct)

1. Delta arrow in its own column (plan), or the arrow inside the win rate cell?
2. Keep Ban value (Influence) at all? It needs a Toggletip to mean anything
3. Default role: the visitor's main when known, or always All?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Patch change as a simple delta (signed number, coloured when clear), not the long
   dot-to-dot track. The players' spread violin stays in the table ("i really liked
   something that shows the distribution like we had before"), tidied to fit the rows
2. Ban value: "Riot dont like ban value, but maybe could be more intuitive, maybe just a
   toggletip". Keep only if it reads without explanation; check production-key.md
   product rules before it ships
3. Default role always All: consistent, never the visitor's main

## Jacob's answers (review v6, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v2-*.

1. "Moved in <patch>" band: mock showed no icons; needs less space; maybe a link to
   the patch page; "sort is kinda enough. I do like it, uncertain on whether we will keep
   it". Mocks round 3: compact form, decide at build

## Jacob's answers (review v7, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v3-*.

1. Win rate colours in the r3 mock "feel weird, having the box around just looks
   funky"; he suspects the sort is a bit broken; preferred the live site's colours ("not
   saying we need to go back"). Mocks round 4: closer to live, no boxed cells
