# Builds (build/<name>-<role>.html, build/index.html)

Plan only (team run 2026-10-24-ui). No separate mock: the build view is the champion
mock's BuildPanel with one slot opened (mocks/champion.html, "Item 4" and Runes open).

## Identity

Not a page any more: the champion page's build, every slot opening in place to all its
options. The build index goes.

## What Jacob said (24 Oct)

"builds last 30 days screen is just a mess as well, again needs specific design
thought"; "and then i cant go back 403,364 Platinum+ ranked solo/duo games in EUW, last
30 days, patches 16.19 to 16.21. Builds, last 30 days."; "i also dont like the text and
hyperlink text like that, minimums doesnt need to be hidden behind a dropdown"; on the
champion page: "the builds is quite cool, but runes, i need to be able to easily see the
lolaytics like version where i can actually see all the pick rates, games and win rates
of choices".

## Who comes and why

Someone about to play a champion who wants more than the top choice: the second keystone,
the item 4 options, a skill order. Today they click "Full build" and land on a second
page with its own header, a method paragraph and no way back but the browser.

## Decisions

- Build index (build/index.html: every champion by role, games beside the name, no other
  numbers): cut. The champions table, header search ("darius build") and the champion
  page reach every build. The run-on line "403,364 ... Builds, last 30 days" on the
  champions page goes with it
- build/<name>-<role>.html: redirects to champion/<name>.html#<role> (old links keep
  working) and the content moves into the BuildPanel:
  - Runes: RuneTree with every rune's pick share, win rate and games, both trees and the
    shards (lolalytics' version, our colour rules). Under it, the top 4 rune pages as
    small RunePage cards (games, share, win), each tappable to light its runes in the tree
  - Every other slot (Spells, Start, Core path, Boots, Item 4, 5, 6, Skills): the cell
    shows the top 3 options; tap → the cell expands across the panel to a DataTable compact
    table of every option with Minute, Games, Share, Win rate (± in the Toggletip), thin
    rows faded. Same table component and column order in every slot
  - Core path: `ItemPath`, item 1 → 2 → 3 as a small branching path (most played path
    bold, the 2 next most played as branches with their share), replacing three tables
    (first two, first three)
  - Skill order: SkillGrid 4x18 for the most played path; expanded: the levels 1-18
    paths and the priority table
- Filters: the page's subbar filters apply, as on every page; no "Minimums" dropdown:
  options under 100 games are hidden, under 400 faded, said once in the DataTable compact
  header's Toggletip ("fewer than 400 games: faded")
- No method paragraph; "How builds are counted" is one Toggletip on the panel title

## First screen

The champion page's (champion.md). With a slot open, that slot's table replaces the
lower half of the panel; the RuneTree stays left.

## Components used

BuildPanel, RuneTree, RunePage, DataTable (compact and full), ItemPath, SkillGrid,
Toggletip, Chip.

## Interactions

- Slot tap → expand; Esc, tap again or tap another slot → close/switch; the open slot
  in the hash (`#top/item4`) so a link can point at it
- RunePage card tap → its runes lit in the RuneTree, its numbers in the card
- DataTable compact: sortable by every column (DataTable)

## Data

All exists (builds files: kinds item4-6, skill_path, minutes, rune trees; CH2, CH3). The
champion page needs the full option lists, not only top 3: today the panel carries top 3
and the build page the rest. Size: Darius Top's build page HTML is ~150 KB; as data
(JSON or a fragment loaded on first expand) about 15 KB gz. Plan: fetch on first expand.

## Cut

build/index.html; the build page's header, method paragraph, "most played" and "highest
win rate" pills on every row, the 6 rune page cards' captions, "Share of 24,447 players
who finished two items" captions under each table (the share column's Toggletip says
whose share it is).

## Desktop reuse

RuneTree with stats and DataTable compact are the desktop's rune and item import view.

## Questions for Jacob (24 Oct)

1. Expand in place (plan) or a side drawer that keeps the rest of the panel visible?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Expand in place, for now. Later the slot must show far more options than a top 3
   and a table.
2. Contextual builds (Jacob: "def will be doing"): like LoLalytics, choosing a rune or
   one or more items filters the rest of the page to games with that choice, and the
   rest of the build is shown in that context. Needs its own data design (builds per
   combination of choices, not per slot: on-demand queries over game rows, or
   precomputed combinations; ties to E7 day cubes, docs/plan/estimates.md). BuildPanel
   is built to take filters from the start
