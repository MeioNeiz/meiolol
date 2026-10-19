# Plan: the website

By page. Jacob's list of 19 Oct first in each section (his words in quotes), then what
was already planned. Policy limits on what pages may show: docs/production-key.md
"Product rules" (no public draft win chance, no "+X% win rate", picks as several options
with reasons). Running theme across the list: fewer words, clearer facts, denser
layouts, more engaging.

## Your games (home)

Jacob 19 Oct:
- Load more games and more history (paging past what loads today)
- "the top": the top of the page needs work (what exactly: ask Jacob)
- Game review needs a lot more: moments relevant to you (your deaths, your lane, your
  fights and objectives, not every team event), better analysis, and show what each
  moment meant (gold, objective, win chance it moved, in plain words or a mark on the
  chart rather than paragraphs)
- Pick a time frame (lane phase, mid game, whole game; charts and stats follow it)
- Bug, quick: the gold curve runs past 14 minutes but its label still says 14 min
- More interesting stats of the game (record-book style: firsts, biggest swing, your
  best minute)
- More specifics in the analysis (what happened, who, where, what it cost)
- Win chance chart colours: the grey and light blue are not clear; stronger contrast
  between the two teams, ahead/behind readable at a glance

Already planned: mark the new games in the film strip (CSS, small); example review per
role (B7); "what your draft was up against" from comp leans (data-and-model.md step 4).

## Daily Draft

Jacob 19 Oct: more engaging, more interesting things, fewer words, clearer facts.
Ideas: one short fact per option with the games behind it instead of sentences, a
visual answer reveal, streaks. J1 (decisions.md) dropped win chance and points; lane
facts with counts are not that, but check the line with Jacob before numbers come back.
Later: puzzles from clear comp leans (data-and-model.md step 5).

## Learn

Jacob 19 Oct: harder and easier at once (an easy start, harder levels later), more
engaging, much fewer words, less overwhelming (one thing per screen). Later: lessons
from comp leans and lane matchups (data-and-model.md step 5).

## Search

Jacob 19 Oct: the champions index search is good; the same search on more of the site
(matchups index, builds, opponent lists; maybe one box in the header that takes a
champion, "Ahri vs Zed" or a Riot ID).
- Done 20 Oct (ba2f07e): one header search on every page, champion, "Ahri vs Zed" ("ahri
  zed", "ahri v zed") or Name#TAG, aliases and typos, keyboard and phone
  (static/search.js, data/search.json from src/site/search.zig). The matchups index
  already had its filter (min-games.js)
- Next: the same matching (aliases, typos) in table.js filters (champions index,
  opponents) and a filter on build/index.html; "Ahri build", "Ahri top" queries;
  pipeline_test checks for the header script and search.json

## Champion page

Jacob 19 Oct: more like lolalytics, better use of space; lane opponents are too hard to
see all at once; builds, skill order and runes on the first screen. Then more useful
than lolalytics: our own edge is the lane curves, early/late lean, "Into which teams"
(data-and-model.md step 2) and the player's own record when looked up.
- Data check first: builds exist (src/builds.zig, skill events in src/riot/timeline.zig);
  runes and skill order on the page may need the per-seat table (data-and-model.md
  step 1 blocker)
- Opponents: one dense grid (icon, win rate, games, gold at 14) all visible, sortable
- Matchup win rates shown like the champions index shows win rates (same style)
- Normalised matchup win rate (Jacob 19 Oct): side by side, the champion's own win rate,
  the matchup's, and the delta, so a matchup reads as better or worse than this
  champion usually does, adjusted for the opponent's own strength. lolalytics has
  Delta 1 and Delta 2 for this, but Jacob finds them unclear: show it more
  intuitively (e.g. a bar from the champion's average, or "+2.1 vs usual" coloured,
  with a range so thin matchups don't shout)
- Pick and ban rate like lolalytics (Jacob wrote "pbr": confirm whether he means PR
  and BR, or lolalytics' PBI, pick/ban influence)

## Matchup page

Jacob 19 Oct: a stat screen like lolalytics' matchup view, laid out as the champion
page but matchup focused (win rate, games, leads at set minutes, builds and runes that
do well here); the curves take far too much space (one compact chart, the rest folded);
the champion pool block much more useful. More specifics on why a champion does well
here (where the lead comes from: level 2/6 spikes, kills vs cs, first item timing, the
leans and kit kinds that apply), not only that it does; the same normalised delta as
the champion page.
Already planned: pool first in the picker (B2), then bans from the pool's hard lanes
(B3, Q3); public form waits on J2 (decisions.md). Patch day (B4, z 2.58).

## Draft tester

Jacob 19 Oct: fewer words, more information, much clearer what affects what; "get more
creative". Ideas: each pick linked to the terms it moves (lane matchup, duo, comp lean)
drawn as a grid or arrows sized by effect, words only on hover. J3: name the three
detected cross-role kinds. Admin only today; the public draft tool follows J2.

## Before the production review

- Privacy/terms into src/site/prose.zig from docs/legal once Jacob fills the
  placeholders; objection by email (`meiolol forget`) until the form is live
- Reviewer walk 2026-10-14 (desktop and phone, every section) fixed in 38b940f,
  145a898, bbda65c, b37dd02, 74d6cdb, ab7d4cc; screenshots docs/review-shots/. Left:
  unknown URLs get a plain-text "not found" from meiolol-render (a site 404 page needs
  nginx error_page). GIFs and a short demo video still to do
- Outage copies (18 Oct) left: home page from the renderer (core build without the DB),
  a pipeline test for /admin/api/pages.txt
- Admin polish, low while the panel is Jacob's only (J9): fix3 leftovers R48-R50, R60,
  R61 (plans in docs/review/fix3-notes-2026-10-17.md), R58
