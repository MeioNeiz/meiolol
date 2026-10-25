# Home (index.html)

Identity: the front door that is already the product: your last game (or a real example)
on the first screen, the lookup beside it, and today's things to do. No selling. Plan 24
Oct 2026, team run 2026-10-24-ui (session games). Mock:
data/team/2026-10-24-ui/mocks/home.html.

## Who comes and why

- New visitor: what is this? Answered by a real game review, not a description of one
- Returning player: their newest game, today's Daily Draft, what the patch changed
- Riot's reviewer: must reach a working review and the method without logging in
  (research/questions/site-design.md C1, C17)

## What Jacob said (24 Oct)

"First page is almost too much selling, looks like an ad i just think it could use space
more efficiently, be more clear and way less words."

Live today (1280): a 36 px logo lockup above the h1 (the brand twice), a 58-word
paragraph, three numbered steps, three links, a scope note, then "In every review"
(three explainer cards), "Your record book" (four cards and a sentence), "Between
games" (three link cards) and a stray "New patch" line. About 330 words before the
footer; the example review sits on the right of the first screen and is the best part.

## First screen

Desktop 1280, a 12-column grid under the site header:

- Left (4/12), stacked:
  - h1 "Review your games" (no lockup, no paragraph)
  - `id-lookup`: Riot ID input and "Review" button in one control, region inferred
    from the tag; recent Riot IDs on this device as chips under it (exists in
    localStorage, `your-recent`)
  - Today (component `today-card`, three of them, 1 line title each, real content):
    - Daily Draft #N: the two teams as two rows of five 24 px icons, "Guess" button;
      done today: your result as the same chip as Daily's summary
    - Patch 16.21: the three biggest win rate changes as champion icon, role icon,
      "+2.6" on the diverging scale (the patch page's rows, `change-chip` from stats)
    - Learn: today's lesson title and a progress ring of the five
- Right (8/12): the review (`game-header`, `timeline-graph` in its compact form: the
  fight strip above and deaths as ticks on the plot's edges, game-detail.md; the
  `stat-cell` row; the game-detail kit, read-only, no inspector) of:
  - the visitor's newest game when this device has looked a Riot ID up (their player
    bar compact above it: Riot ID, record, form strip), with "Open" to the game
  - otherwise the example, with the role switch (exists) as `segmented`, and its
    "Example" chip

Below (still the first screen at 1280x800 in part, the rest one scroll):

- Champions: role row (`role-picker`, the stats session's) and the `champion-search`;
  under them each role's three most picked this patch as icons. Pressing goes to the
  champion page in that role (Jacob: "if i pick on champion with its role ... i want
  that role")
- Footer as today, with Method and Desktop app in it

Cut: the lockup, the paragraph, the three steps, "See an example review" and "How the
numbers are made" links (the example is on screen; Method is in the footer), "Coming: a
champ select helper" (footer's Desktop app link), the scope note, "In every review",
"Your record book" (the same tiles live in Your games Highlights), the "New patch" line
(now the Patch card).

Phone 390: h1 and lookup (~150 px), then the review (header with the K/D/A on its own
line under the names, graph at 170 px, stat cells 3 by 2), then the three Today cards, then Champions. The example must start above 844
px (today it starts at ~750 px after the paragraph and steps: the cut fixes it).

Words on the first screen (labels, no data): Review your games, Review, Today, Daily
Draft, Guess, Patch, Learn, Example, Top, Jungle, Mid, Bot, Support, plus the
stat-cell labels (Turn, Best minute, Biggest rise, Peak, Low, Ahead): ~25. Today: ~330
on the page, ~150 in the first screen.

## Interactions

- Lookup: Enter or the button goes to your.html#id=... (exists). Typing a champion name
  instead offers the champion (the header search's logic, shared `search` component)
- Review on home: the stat cells are live (press a cell, the graph shows it), no
  range drag (that is the game page's); "Open" goes to the full game
- Example role switch (exists)

## Components used (register names)

IdLookup, Chip, TodayCard, ChampIcon, Delta (patch changes, as stats uses it),
GameHeader, TimelineChart (compact: FightStrip, edge ticks; read-only), StatStrip, Segmented, RolePicker,
ChampSearch, PlayerBar (compact), ResultStrip (form).

## Data needed

| What | Status |
| --- | --- |
| Example games per role | exists (data/your-example.json) |
| The visitor's newest game | exists via /api/games, but that call refreshes from Riot when the last refresh is over 5 min old. New: a `cached=1` read that never queues a job (small), so a home visit costs no Riot calls |
| Today's Daily Draft teams and the visitor's result | exists (daily data, localStorage) |
| Patch top 3 changes | exists (the patch page's data); new: written as a small JSON for home in the site build (small) |
| Learn lesson and progress | exists (learn.js state in localStorage) |
| Top 3 champions per role this patch | exists (champions index data) |

## Desktop reuse

Only id-lookup (the desktop's account link) and today-card's Daily Draft (a desktop
"between games" panel). The rest is site only.

## Questions for Jacob (24 Oct)

1. A returning visitor sees their own newest game instead of the example: yes? It makes
   the home page personal, which design-ideas.md asks for, at the cost of everyone's
   home looking different
2. Keep Learn on home, or only Daily Draft and the patch?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Personal home: a returning visitor sees their own newest game
2. Daily Draft and patch only, no Learn card. The page now looks plain and less
   inviting than before, though better: give it life in the visual pass
