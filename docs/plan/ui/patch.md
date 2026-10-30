# Patch changes (patch.html, patch/patch.html)

Plan only (team run 2026-10-24-ui). Mock: data/team/2026-10-24-ui/mocks/patch.html.

## Identity

What the patch did: what Riot changed, next to what it did to win rates and lanes. The
one page that ties the patch notes to the numbers; champion and matchup pages carry
their own slice of it.

## Who comes and why

- Patch day and the days after: "what's stronger now", "did the nerf to X work"
- From a champion page's StatStrip patch cell ("16.21 +2.6"): why it moved
- From the champions table's Delta arrow column

## What Jacob said (24 Oct)

"patch changes is alright, not enough colour on the change, if i hover over the
uncertainty i probably want a tool tip explaining it a little, this probably applys to
over parts of ui that arent clear too, too many words, awful use of space on this page
too with the very generic table, and its not a real table too, like no sorting?, also we
can prob show more info on this page too like they should be able to use the same page to
see more changes, idk though actaully if they want specific patch to patch, maybe they
see that more on champion detail + matchup page idk good overview. Also showing context
to this page, like the model should be able to have some idea of what has changed that
affected this, like even better if it could actually show patch notes too and then even
matchup changes in wr to the change itself, or what is impacting it, in general i like
this page but again too generic, could be so much better".

## Decisions

- An overview of one patch against the one before, with a Select to step back
  (16.20 vs 16.19 ...) as far as the db holds both patches whole. Specific
  champion-by-patch history stays on the champion page (TrendChart By patch)
- Every champion role with 300+ games on both patches is in one sortable table, not only
  the clear moves; clear moves are what is coloured. Filter chips: [Moved clearly |
  Changed by Riot | All], default Moved clearly + Changed by Riot (union)
- The change is drawn: `Delta bar`, a diverging bar from 0 with its ±95% whisker,
  coloured on the scale when clear (heat fill at steps 2+), grey and thin when not.
  The number beside it ("+2.6"); the ± in a Toggletip on tap or hover: "95% range: the
  real change is likely between +1.2 and +4.0 points. 6,678 games on 16.21 so far."
- Riot's changes on the row: a `Badge patch` ("changed" with a count, e.g. "Q, W,
  stats") when Data Dragon shows a change for the champion; tap the row → `RowDetail`
  opens under it: the change lines (old → new: "Q cooldown 9 → 8 s", "base AD 64 →
  62"), the champion's 3 biggest matchup moves this patch (Delta bar each), its items
  or runes that changed, link to the champion page on the patch view
- A champion Riot changed whose numbers haven't moved clearly is listed too (filter
  "Changed by Riot"): "too early" when its games on the new patch are thin (± shows it)
- Matchups that moved: a second DataTable, each pair with Delta bar on the win rate,
  the gold change as a small signed number, and the Badge patch on whichever side
  Riot changed (so "tied to the change" is visible, not inferred in prose)
- Items and runes changed: a compact list (icon, what changed, the champions that build
  it most, with their change); from item.json and runesReforged diffs
- No intro paragraph. The scope lives in the subbar and the ChampHeader patch ("16.21 vs
  16.20 · day 5 · 79,549 games so far"); the listing rule goes into the filter chip's
  Toggletip. The period switch that did nothing (ui-audit) is disabled with a reason on
  this page

## First screen (1280x800)

```
ChampHeader patch  ‹ Patch 16.21 vs 16.20 ›  day 5 · 79,549 games · official notes ↗
FilterBar [Moved clearly ▲3 ▼4 +9 | Riot changed 22 | All 160]   RolePicker [All | ...]
DataTable   champion | role | Riot | 16.20 | 16.21 | Change (Delta bar) | Ahead at 14
            (Delta bar, small) | games 16.21
```

Rows 30 px; about 15 on the first screen. Phone: champion, Change (bar + number), the
Riot badge; rates and lane in RowDetail.

Words on the first screen (without names, numbers): "Patch", "vs", "day", "games",
"official notes", chip labels, column heads: ~20. No summary strip (Jacob, note 37:
too many words): the counts sit in the chips they filter by, the role's rows: ▲▼ clear
win rate moves in the Change column's colours, +N rows only their lane or matchups
moved (the Lane lead and Matchups columns' sorts).

## References (research refs/patch/notes.md)

| Element | Model on | Take | Leave |
| --- | --- | --- | --- |
| Change table | Dotabuff hero trends | start, now, change, sorted by change; a per-row patch sparkline once the db holds 4+ patches | |
| Change colour | lolalytics, dpm | every change signed and coloured, scaled by how clear it is, grey when unclear | lolalytics' green/red |
| Change text | DeepLoL, Riot's notes | old value struck through ⇒ new, ability icon; a Badge patch variant buff, nerf or adjusted, inferred per field (cooldown, cost down = buff; base stat, damage down = nerf; mixed = adjusted) | AI advice lines (op.gg) |
| Text beside the stat move | metabot.gg (archived, 25.22) | the only one seen; nobody ties matchup moves to a change: open ground, ours | |
| Champion history | DeepLoL Patch History | on the champion page's By patch chart: each patch point's Badge and change lines in its tip | |

## Components used

ChampHeader patch, Select, FilterBar, RolePicker,
DataTable, Delta bar, Toggletip, Badge patch, RowDetail, ChampList.

## Interactions

- Select: previous or next patch pair (static pages per pair)
- Filter chips and RolePicker: filter rows in place; sort by any column
- Row tap: RowDetail (one open at a time); champion name: champion page on the patch view
- ± and Delta bar: Toggletip with the range in words and the games

## Data

| Need | Status | Effort |
| --- | --- | --- |
| Every champion role's rate on both patches, ±, clear flag | exists (patchday; only clear ones listed today) | site only |
| Ahead at 14 by patch | exists (curves, prev patch) | site only |
| Matchup moves with ± | exists for listed pairs; all pairs with 400+ games on both is a longer list from the same files | site only |
| What changed per champion: base stats, cooldowns, costs, ranges, effect numbers, spell text | partly: lab's patchdays.changedList says which champions changed; PC1 moves it to the backend with field-level old → new. Checked 24 Oct (16.20.1 vs 16.21.1): 12 champions changed; Darius Q cooldown 9/8/7/6/5 → 9/7.75/6.5/5.25/4 s (his +2.6), Viktor move speed 335 → 330 (−3.2), Jinx base health 630 → 610; Varus Q, Orianna Q, Xin Zhao E have blanked numbers in Data Dragon (say "numbers not in Data Dragon"); items Bastionbreaker, Dawncore, Hubris text only | ~1 day |
| Ability damage numbers (Data Dragon lacks most) | new source: CommunityDragon game data (PC2). Already used for rune shard icons; docs/data.md needs a line before it is added | 2-3 days (bin JSON per champion, map spell keys to names, a diff that ignores reordering) |
| Riot's patch notes text | the official notes page: a link per patch is cheap; parsing its HTML for every line is fragile and Riot's page, not the API: plan links only | link: hours |
| Item and rune changes | item.json and runesReforged diffs (Data Dragon), plus who builds them (builds files) | ~0.5 day with PC1 |
| Older patch pairs | db holds 16.19 (part) to 16.21; a page per pair from the same patchday code | ~0.5 day; 16.20 vs 16.19 now, more as patches come |

## Cut

Intro and listing-rule paragraphs, the footnote under the matchups table, four separate
tables with their own column widths (one champion table, one matchup table), "X then Y
at N min" gold prose (a signed change and the minute in the Toggletip).

## Desktop reuse

Delta bar and Badge patch in the desktop's suggestion reasons ("buffed this patch,
+2.6"), subject to production-key.md wording rules (no "+X% win rate" claims about a
pick: the patch change is the champion's measured change, not a promise).

## Questions for Jacob (24 Oct)

1. Default filter: clear moves plus Riot's changes (plan), or every champion?
2. Ability numbers from CommunityDragon worth 2-3 days now, or Data Dragon's diff and a
   link to the notes first?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Default filter: clear moves plus Riot's changes
2. Both sources long term (CommunityDragon ability numbers with Data Dragon); plan for
   the most useful page, not the cheapest first step. Order of building left to the plan
