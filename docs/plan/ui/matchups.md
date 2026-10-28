# Matchups (matchup/index.html)

Plan only (team run 2026-10-24-ui). No separate mock: the finder is the champion
mock's MatchupGrid under a two-slot picker; the picker's look is in mocks/matchup.html's
header.

## Identity

A matchup finder, not a list: pick two champions (or one, then its opponents) and land
on the matchup page.

## What Jacob said (24 Oct)

"matchups list, just showing a list of all matchups is just ridiulous, theres just no
reason for it, its so over the top, unclear, unhelpful, overwhleming, unsuable to
actually find a matchup too".

## Who comes and why

"How does my champion do into X": they know both champions. Or "who is hard for my
champion": they know one. Nobody comes to read 5,000 rows.

## Decisions

- Cut the 5,000-row tables (4.4 MB). The page is a `ChampRolePicker pair`:
  `[Your champion ▾] vs [Opponent ▾]` (two ChampSearch slots, the role picked with the
  first: "Darius" offers Top | Jungle as chips), Enter or the second pick → matchup page
- With one champion picked: its MatchupGrid (the champion page's component, same
  RelationPicker, Against preselected) under the slots, so the second pick can be a tile
  tap
- Nothing picked: a RolePicker, then three short `ChampList`s for that role side by side
  (8 rows each, every row a matchup page): Moved this patch (clearest win rate moves,
  from the side that gained, Delta with range, link to the patch page), Hardest lanes
  (lowest win rates from the losing side, ranked by the upper end of the 95% range),
  Lane bullies (biggest median gold lead at 14). Hardest and bullies need 500 games a
  pair. Most played is gone (Jacob 27 Oct: "almost feels silly except the moved this
  patch")
- Header search keeps doing "ahri zed" from any page; this page is its slower twin

## First screen

```
h1 Matchups
ChampRolePicker pair  [ Your champion ▾ ] ⇄ [ Opponent ▾ ]   RolePicker (after 1st pick)
(nothing picked)  RolePicker
                  Moved this patch | Hardest lanes | Lane bullies   (8 rows each)
(one picked)      MatchupGrid of that champion, Against its lane
```

Words: "Matchups", "Your champion", "Opponent", "Moved this patch", "Hardest lanes",
"Lane bullies": ~11.

## References (research refs/matchups/notes.md)

dpm's /matchups two-slot picker (champion, then opponent, over an icon grid and search)
is the model for the finder; after the first pick, its opponents ranked by games
(op.gg's list) rather than dpm's plain grid. Leave verdict words ("Best picks vs
Darius", "Counter rating").

## Components used

ChampRolePicker pair (two ChampSearch slots, swap), ChampSearch, RolePicker, MatchupGrid,
RelationPicker, ChampList, MatchupTile.

## Interactions

Type-ahead in each slot (aliases, typos: the header search's matcher); picking the first
fills the grid; tile or second pick → matchup page; swap flips sides; the URL keeps the
first champion (`matchup/index.html#darius-top`) so back returns to the grid.

## Data

Exists: the champion pages' matchup data. The grid for any champion needs its opponents
without loading 5,000 rows: one small JSON per champion role (already written per view
for filters.js) or a fragment. The three lists: from the stats, curves and patchday
files, in the island's data-bin.

## Cut

All five role tables, the intro sentence, Min games floors, the index's 4.4 MB.

## Desktop reuse

ChampRolePicker pair is the desktop's "look up a lane" box.

## Questions for Jacob (24 Oct)

1. Keep any full list at all (e.g. a role's 50 most played pairs as a table)? Plan: no

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. No list
