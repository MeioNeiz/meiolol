# Plan: the website

By page. Jacob's list of 19 Oct first in each section (his words in quotes), then what
was already planned. Policy limits on what pages may show: docs/production-key.md
"Product rules" (no public draft win chance, no "+X% win rate", picks as several options
with reasons). Running theme across the list: fewer words, clearer facts, denser
layouts, more engaging.
Site-wide colour and density (Jacob 20 Oct: "more colour", "space inefficient"):
docs/design-ideas.md, measured layout, colour by impact, build order.

## Your games (home)

Jacob 19 Oct:
- Load more games and more history (paging past what loads today)
- "the top": the top of the page needs work (what exactly: ask Jacob)
- Game review needs a lot more: moments relevant to you (your deaths, your lane, your
  fights and objectives, not every team event), better analysis, and show what each
  moment meant (gold, objective, win chance it moved, in plain words or a mark on the
  chart rather than paragraphs)
- Pick a time frame (lane phase, mid game, whole game; charts and stats follow it)
- More specifics in the analysis (what happened, who, where, what it cost)

Done 20 Oct (night run): lane panel heading gives the minutes drawn (71c3eae); win
chance in team colours, yours blue and the enemy red, area and eval bar (cc02525; site
is dark only); New badge in the film strip (9b634e8); first records under the win
chance counts: biggest rise, high, low, minutes ahead (d15755e). After Jacob's 00:27
("blue/red is fine ... too much of it isnt coloured ... more funky colours for really
crazy win rates"): the chart filled as the eval bar over time, cyan past 80% and hot
pink below 20% (2ebb732); records gain your best minute by your own gold and the
game's firsts as team-coloured chips (3a84be0, f82221f; fields from review's API).
Next: check firsts on a real report once the API serves them and the example file is
regenerated; more records (biggest fight, longest time ahead)

Done 20 Oct (night run, review): the review's moments are yours (a985fc8, 7733ac4; API
installed on jomify): fights you were in (who fell on each side, whom you took down,
who killed you, kill gold swung, where on the map, objectives each team took within a
minute, win chance moved), objectives you took part in, towers in your lane and every
Baron, Elder and Atakhan; team swings without you are gone (old reports keep them).
Dots on the chart by kind, the biggest five labelled with what they moved ("+12%
kill", "-13% died"). Next: 15 to 30 moments a game is long (fold the small ones or a
biggest-only view? ask Jacob); a minute's win chance change is the whole minute, not
the fight alone; map areas are rough, check a few against real positions

Done 20 Oct (night run, persist; Jacob 00:42 "go to Learn then back to Your games it
should still show me ... maintain filters"): views kept in this browser, URL picks
always win (721f3aa). Your games with no Riot ID in the URL opens this tab's last place,
else the last player looked up, from the report as last shown (shows with the service
down), then looks up as usual; "Not you?" by the name, tab kept. Champion page rank and
opponents picks, table sorts, matchup curve tabs kept. Privacy page says so. Next: Daily
Draft and Learn keep their own state already; the pool page's mains are not kept (ask
Jacob); a champion page opened mid-browse with ?period=patch takes the kept rank (a
shared link only stays exact in a fresh tab)

Already planned: example review per role (B7); "what your draft was up against" from
comp leans (data-and-model.md step 4).

## Daily Draft

Jacob 19 Oct: more engaging, more interesting things, fewer words, clearer facts.
Ideas: one short fact per option with the games behind it instead of sentences, a
visual answer reveal, streaks. J1 (decisions.md) dropped win chance and points; lane
facts with counts are not that, but check the line with Jacob before numbers come back.
- Done 20 Oct (night run, daily): the four options flip after the guess, each to one
  fact and its games ("Good into Zed" when a detected reason clears chance, else "Ahead
  / Behind at 14 min, gold vs X", "No clear lane lead", "Few games"), played one
  marked; side buttons colour, winner marked; a score card (both right / one of two,
  days in a row, best, played); tiles (winner, kills, gold); lanes as rows with "Blue
  ahead at 14" chips and games. Copy cut to one line, method in a closed details. Gold
  sides from the lane curves (src/daily.zig LaneGold: 2 SE, 200+ games, own >= 0.5);
  the puzzle JSON also carries the gold amount and lane lead counts, unshown (J1)
- Jacob: may numbers come back, e.g. "ahead at 14 in 58% of 1,220 games" or "+300
  gold at 14"? Learn and matchup pages already show both
- Done 20 Oct: framed as the last pick (match data has no pick order: "treat it as"),
  EUW in the context line, bans as icons per side (no seat in match-v5)
- Jacob 20 Oct 00:36-00:41 asked for pick verdicts (J2 form), per-player ranks, a
  scoreboard and no week delay: plan and the privacy questions in
  data/team/2026-10-19-night/daily.md (Q2 and the privacy page set the week delay)
- Next: a hint before the guess (e.g. reveal one lane fact for a smaller streak?);
  share text with the facts; small leads (+100 gold) read "ahead" when clear: maybe a
  floor (200 gold) so "ahead" means something to a player
Later: puzzles from clear comp leans (data-and-model.md step 5).

## Learn

Jacob 19 Oct: harder and easier at once (an easy start, harder levels later), more
engaging, much fewer words, less overwhelming (one thing per screen). Later: lessons
from comp leans and lane matchups (data-and-model.md step 5).
- Done 20 Oct (night run, learn): Lessons and Practice as tabs, a lesson a screen (text,
  then each question alone, "2 of 3 right" at the end), practice in three levels of
  five drills from the generator's Difficulty (clear-cut: one option brings the damage
  type the team lacks; two fit; close call: balanced team), next level offered when one
  is done; role and own champions folded into a closed "Role and your champions"; copy
  cut about in half (lessons, hints, reveal: summary as the heading, one line a fact, two
  reasons an option at most); after the pick each option button says "adds magic" or
  "more of the same". Progress in localStorage only. No win chance or points: Learn
  never showed them (raw win rates with games only), checked in learn.js and the reveal
- Next: levels inside a Difficulty by clarity (easy drills whose one bringer also leads
  its lane before ones whose doesn't; hard ones sorted by how close the four sit);
  lesson examples as tiles, not sentences; a lesson from lane curves (who is ahead at 14)
  as Level 2's primer

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
- Done 20 Oct (night run, champion): lane opponents as one grid of tiles, all on
  screen (desktop 11 a row, phone 4), sortable by name, win rate, vs usual, gold at 14
  and games; win rates on the champions table's track and colours; "+2.1 vs usual":
  the matchup's rate against usual, where usual is the champion's role rate moved by
  the opponent's on the log-odds scale, pulled toward 0 by k games a role (champion.zig
  usualK; learned.md 2026-10-20), its 8-in-10 range on hover. Left: under a filter
  other than the root view, filters.js reuses the root view's opponent strengths (the
  filter data has only this champion's games); the matchup page's delta (below)
- Done 20 Oct (night run, builds, 3d2d7e6): builds on the first screen. Each role
  section's "Build:" link line is now a strip of the most played choice per kind from
  the patch view's builds file (no per-seat table needed): rune page, shards, spells,
  start, boots, first 3 items, levels 1-3, skill priority; each with games, share and,
  from 100 games, "% won" (past-games fact, most played not ranked, no pick wording);
  greyed under 400 games; says its scope and that the page's filters don't change it;
  links the full build page. New builds kind skill_start (first three skill-ups), on
  the build page too. Next: grey or hide the strip when a filter moves away from the
  patch view's region (filters.js); full 1-18 skill sequence (a packed u32 key, 2 bits
  a level, would fit the builds Key); shard icons (ddragon has none; CommunityDragon
  StatMods); per-matchup builds for the matchup page need builds counted by lane
  opponent, a new builds file key
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
Done 20 Oct: first screen is tiles (win rate, vs usual as the champion page's, games,
gold at 14, share ahead), a Gold/XP/CS table at 5/10/14/20 min and "Where the lead comes
from" facts (gold at 14 split into CS at ~20 gold each and the rest, when half the gap
is there, early kills, level 6 and first item timing, win share ahead/behind) beside one
chart with Gold/Experience/CS tabs. Next: level 2 timing (curves format: a header field
and a box rebuild of the curves), builds and runes that do well here (the patch view's
builds file), the leans and kit kinds that apply, the champion pool block, then maybe
fold the Lane and game table, which now repeats the facts.
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
