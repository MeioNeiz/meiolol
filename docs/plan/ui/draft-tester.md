# Draft tester (/private/tester)

Identity: the model's workbench: build any draft, see the win chance, every term behind
it and every candidate for a seat, under a named model. Private (view_private logins);
the proving ground for the draft components the public site and the desktop reuse.
Plan 24 Oct 2026, team run 2026-10-24-ui (session play). Mock:
data/team/2026-10-24-ui/mocks/draft-tester.html.

## Who comes and why

- Jacob: try drafts, check the shipped model against a lab experiment, see what a
  champion changes and why
- Friends with private logins (J21): the "op" draft tool
- Builders: every draft component in all its states on one page, with real model maths

## What Jacob said

- 24 Oct: "in draft tester there is so much work to do as I think doing work here to make
  this more intersting and easy to use will help us implement this stuff on other pages.
  Its still too wordy, shipped model vs lab experiment is still not very clear about what
  models we are actually showing, i think name the model and then tag it with where its
  shipped/used and where its from like lab or whatever"
- 19 Oct (site.md): "fewer words, more information, much clearer what affects what; get
  more creative"; ideas: picks linked to the terms they move, a grid or arrows sized by
  effect, words only on hover. J3: name the three detected cross-role kinds

## What is wrong today (local copy of /private, 24 Oct)

- 170 words before the board: a sub header, a model description sentence, a 60-word
  facts line, a fills sentence, the bans heading sentence
- "Shipped model | Lab experiment" names where a file came from, not what the model is;
  the lane model, the set nets and their sources are invisible (under Debug)
- The board is two columns of text inputs; nothing on it shows what a seat contributes
- The picker (good: Win, Gold, Fit, reason chips, a breakdown per row) opens below the
  fold with a 70-word explanation; sort options are worded ("Surest win") without a cue
- What affects what (pairs, matchups) is only in the Debug logit table

## Models, named and tagged

Each model gets a short name and two kinds of tag: where it is used, and where it is from.
From the files on /private today:

| Name | What it is | Used in | From |
| --- | --- | --- | --- |
| Ratings + pairs | champion rating per role plus ally and enemy pair terms (draft-model v4, kind draft) | Daily Draft review and app suggest (through the stats file's fit, src/fitted.zig: confirm it is the same fit), this page | box, daily refit 03:30 (1.7M games, 16.19-16.21; 55.4% on 173k held out) |
| Additive v2 | strength, ally pairs, matchups, damage mix (kind additive, comp terms) | this page only | lab run `draft`, snapshot 18 Oct (649k games, 16.19-16.20) |
| Set net x6 | six seeds of the win-additive set net (12 profile features) | this page only | lab, 18 Oct, every region |
| Lane 3c-team2 | gold at 14, lane gold, CS at 10, deaths before 15 by matchup | this page only (Gold column, breakdown lane line) | box, daily refit 03:46 (`meiolol lane-model`) |

The "Used in" list comes from the code, not from memory (Data needed). The tags render
as a `ModelBadge`: name, then Badges "Daily", "App" (used in) and "Box 24 Oct" / "Lab
18 Oct" (from); its Toggletip gives games, patches and the held-out accuracy line.

## First screen

1280:

```
Draft tester   Model [Ratings + pairs · Daily · App · Box 24 Oct ▾]  vs [none ▾]   ↻
Blue 48.8% ━━━━━━━━━━━━━━━━━━━━━━|┃|━━━━━━━━━━━━━━━━━━ 51.2% Red      (WinSplit, range)
┌ board ───────────────────────────────────────┐ ┌ what affects what (HeatGrid 10x10) ┐
│ Sett    +0.6  ⌂top  +0.9 −0.3  Volibear  🔒 │ │      S  Sh  V  C  L │ Vo K  Vi T  X │
│ Shyvana −0.4  ⌂jg   ...        Kha'Zix      │ │ S    ·  .3  .  .  . │ .2 .  .  .  . │
│ Vladimir      ⌂mid             Viktor       │ │ ...                                 │
│ Caitlyn       ⌂bot             [ ? ]        │ │ cells: points for blue; tap = the   │
│ Lulu          ⌂sup             Xerath       │ │ two seats light up on the board     │
│ bans [⌕ ban]  ▣ ▣ ▣                         │ └─────────────────────────────────────┘
│ [⚄ Random] [Fill empty] [Clear] [↶]         │
└──────────────────────────────────────────────┘
┌ Red bot · 126 picks  [⌕]  sort [Win|Fit|Gold vs Caitlyn]                            ┐
│ RankStrip: ···•·•··|•·★···                                                          │
│ Yasuo   ━━━━━━|━ +5.3  +274g  fit +3.6  [strong bot +1.7][into Yuumi +1.3] ▸ [Pick] │
│   ReasonBreakdown: avg bot 70.5% → strength +1.7 → into Yuumi +1.3 → into Jhin +1.1  │
│                    → with Leona ±0 → rest +1.2 = 75.8% (75.0-76.5)                   │
│ Kai'Sa  ...                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

- Model row: a Select of ModelBadges (each option shows name and tags), and "vs" a second
  model to compare (none by default). With a second model: the WinSplit shows its split
  as a tick, each candidate row gets the B number and the difference
- Board: `DraftBoard`; each seat shows its own part of the win chance (the rating term,
  signed points, coloured, a small Bar); the middle column the lane pair's term; a lock
  icon replaces the "keep" button; empty seat = ChampIcon empty. Tap a seat: the
  candidate panel below switches to it (it opens on the first empty seat)
- What affects what: `HeatGrid` 10x10 of pair terms (ally pairs in the two team blocks,
  enemy pairs across), cells in points for blue on the fill scale, "·" under 0.2. Tap a
  cell: the two seats ring on the board and the Toggletip gives the pair's games and
  kind (J3 kinds: "into their bot laner", "with your support", "rest"). Phone: a list of
  the six largest pairs instead of the grid
- Candidate panel: `CandidateList` in points mode with the `RankStrip` above it, search,
  sort Segmented (Win: low end of the range first; Fit: win minus the champion's own
  strength; Gold: lane model into the seat's opponent); row tap opens
  `ReasonBreakdown`; "Pick" puts it in the seat
- Terms and files: a Segmented under the board, Board | Terms | Files. Terms is today's
  logit table; Files the model checks as ✓ lines with the reference counts. Debug text
  goes there, out of the default view
- 390: model Select full width; WinSplit; board as lane rows (two lines each); the
  candidate panel as a sheet when a seat is tapped; HeatGrid as the top-6 pair list

Words on the first screen: "Draft tester", model name and tags (~8), "vs", "none",
"Blue", "Red", seat panel head 3, sort labels 4 ("Win", "Fit", "Gold vs Caitlyn"),
buttons 4 ("Random", "Fill empty", "Clear") = ~27. Today: ~170 before the board.

## What Draft tester work proves for the rest of the site

The tester uses every draft component in every state, on real model maths, for one
private user: the cheapest place to get them right.

1. `DraftBoard`: empty, partly filled, locked, selected, banned, with per-seat and middle
   slots. Daily Draft (hidden seat, grown scoreboard), Learn drills, the desktop's champ
   select all take it as is
2. `CandidateList` + `ReasonBreakdown` in points mode: Daily's selected seat uses them
   unchanged; the public desktop app uses the tiers mode (J2, product rules) of the same
   components, so the words for each reason kind are written once
3. `WinSplit` and `RankStrip`: Daily's on paper and every seat rated
4. ChampSearch and ChampRolePicker under real load (126 bot picks, bans, keyboard)
5. `ModelBadge` and the model registry: the same badge names the model in Daily's "the
   model's pick" toggletip and in admin
6. `HeatGrid`: Pool's coverage grid
7. The interaction layer: the tester recomputes everything in the browser (draftModel in
   admin-draft.js, 864 lines, a JS copy of core/score.zig). On the new stack the same
   Zig scoring compiles into ui.wasm: the first proof that model maths runs once, in
   Zig, on server and client (frontend-rework.md "JS copies of Zig logic"), before the
   desktop needs it in champ select

Recommended order: the tester is the first page moved after the gallery (private, no
public risk), then Daily Draft (80% the same parts), then the desktop's champ select.

## Interactions

- Seat tap: select; type in the seat to search; Enter picks the top match; x clears;
  lock toggles keep
- Random game / Fill empty / Undo / Clear: a draw by play share in the role on the share
  patch, from the candidates with 1%+ of it, never a ban; Random empties the board
  first, Fill empty only the empty seats; Undo takes back the last draw, any other board
  change drops it. Not yet: keep toggles (Fill empty after picking covers most of it),
  the "Fill..." presets (top 15, swap sides, AD/AP, mirror)
- Bans: one list of 10 for both teams under the board (as the old tester); the box bans,
  a chip tap lifts it; a banned champion leaves the board and the candidates; in the
  link's fragment (`n`)
- Pair cell tap: highlight seats, Toggletip
- Candidate: row opens ReasonBreakdown, "Pick" fills the seat, sort Segmented, search
- Model Select and "vs": reload model files (13 MB and 10 MB, cached after first load)

## Data needed

- Model files: exist (/private/models/: draft-model.json, lane-model.json and refs from the box;
  /private/lab/: draft-model.json, lane-model.json, draft-setnet.json, refs from the lab)
- Names: exist partly (meta.name: "shipped model (site and app)", "additive v2: champion
  strength, ally pairs, matchups, damage mix", lane "3c-team2"; set nets have candidate
  "win-additive"). New: a short `label` per model kind in meta, and a registry the web
  loop writes (`models/index.json`: file, label, kind, from, date, games, patches,
  held-out accuracy, used_in). used_in from a Zig table next to each loader (daily.zig,
  the app's suggest, the tester exports), so it cannot drift. Finding while planning:
  the tester's "shipped model" file and the stats file's fit are written by two commands;
  the registry should say whether they are the same fit. Small
- Per-seat terms, pair terms, rank strips: computed from the model file in the page
  (exists in JS; moves to Zig wasm with the rework)
- Compare: both models' files at once: exists (two fetches)

## What is cut

- The sub header, the model description sentence, the 60-word facts line (into the
  ModelBadge toggletip), the fills sentence, the bans sentence
- "Shipped model | Lab experiment" segmented (replaced by named models)
- The 70-word picker explanation (Toggletips on Win, Fit, Gold heads)
- "keep" text buttons (lock icon); Debug as a fold (Terms and Files views)

## What the desktop could reuse

DraftBoard, CandidateList, ReasonBreakdown, ChampSearch are the champ select screen;
ModelBadge in the app's About (which model the app runs, from where). WinSplit and the
HeatGrid stay in the private app (no draft win chance in public champ select).

## Questions for Jacob (24 Oct)

1. Model names: "Ratings + pairs", "Additive v2", "Set net x6", "Lane 3c-team2": fine,
   or names of your own?
2. Compare two models on one board (the "vs" Select): wanted now, or one model at a time?
3. The pair grid (what affects what) on the first screen, or behind a Terms view?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Names must say what each model is; ours to choose. Proposed: "Live draft model"
   (Ratings + pairs), "Comp model, lab" (Additive v2), "Neural set model, lab" (Set net
   x6), "Lane model" (Lane 3c-team2); used-in and from tags as planned
2. One model by default; a compare option to put a second beside it
3. Pair grid on the first screen. The page is "much better than it was" but clunky with
   too much wasted space: tighten in the visual pass

## Jacob's answers (review v6, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v2-*.

1. Drop ", lab" from model names (the Lab tag says where from)
2. Pair grid: a finer colour scale for pair terms (most sit at 0.2-0.9)

## Jacob's answers (review v7, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v3-*.

1. Round 3 "looks much better"; not fully convinced by its functionality, good
   enough for now
