# Plan: the website

By page: Jacob's asks first in each section (his words in quotes), then status and
what is next. The rebuild of every page from the ground up is planned in docs/plan/ui/
(docs/frontend.md); this file is today's site, which gets fixes and data meanwhile.
Policy limits on what pages may show: docs/production-key.md "Product rules" (no public
draft win chance, no "+X% win rate", picks as several options with reasons). Running
theme: fewer words, clearer facts, denser layouts, more engaging.

## Site-wide

URLs: docs/plan/urls.md (J32) is the scheme; no new page path or href shape outside it.
Colour and density ("more colour", "space inefficient"): docs/design-ideas.md (measured
layout, colour by impact, build order).
- Win rates: continuous colour (tierlist.wrColour mixes the stops in oklab, grey only at
  50.0%, few games fade by opacity; tierlist.wrText for text); matchup rates on
  matchup_span (0.24, twice the table's). Every win rate shows its number, even when
  close (J12); colour only where clear. Win rate columns sort by the rate pulled toward
  an average (role's, champion's own, usual), shown raw. No highest win rate mark on
  boots and finished items (purchase timing)
- Whole-box links (J14): a .bx row or tile with its main a.box covering it (::after),
  other links and controls raised above, hover and focus ring; opacity on the row, never
  a cell (a cell with opacity traps the link)
- Scale tokens in style.css; wrap 1,560, header 48, 29 px table rows; --faint #7a7f88
  (4.6:1), fade floor 0.6
- Next: design build order 5's heat cells and pick/ban bars, 6 (header row, phone
  filters button); Your games' game scale (2.5, 5, 10, 15 points) not wired; whole-box
  links on Your games lists, the home record book and Learn lesson cards
- Not now: players behind a matchup's games (curves format)

## Your games (home)

Jacob's asks:
- Load more games and more history (paging past what loads today)
- "the top": the top of the page needs work (what exactly: ask Jacob)
- Game review needs a lot more: moments relevant to you (your deaths, your lane, your
  fights and objectives, not every team event), better analysis, and show what each
  moment meant (gold, objective, win chance it moved, in plain words or a mark on the
  chart rather than paragraphs)
- Pick a time frame (lane phase, mid game, whole game; charts and stats follow it)
- More specifics in the analysis (what happened, who, where, what it cost)

Status: the review's moments are yours (fights you were in with who fell, whom you took
down, who killed you, gold swung, where, objectives within a minute, win chance moved;
objectives you took part in, towers in your lane, every Baron, Elder and Atakhan), named
by size (small under 5 points, medium, big 10+, huge 20+), small ones folded when over
two, dots on the chart with the biggest five labelled. The win chance chart is filled
in team colours (cyan past 80%, hot pink below 20%); records under it (biggest rise,
high, low, minutes ahead, your best minute, the game's firsts as chips). The lane's gold
at 14 says where it sits among the matchup's games. Views are kept in this browser (URL
picks always win): no Riot ID in the URL opens this tab's last place, else the last
player looked up, from the report as last shown; "Not you?" by the name.

Next:
- Check firsts on a real report once the API serves them and the example file is
  regenerated; more records (biggest fight, longest time ahead)
- A minute's win chance change is the whole minute, not the fight alone; map areas are
  rough, check a few against real positions; level 6 and first item have only a median
  (spread needs curvesfile percentiles)
- A champion page opened mid-browse with ?period=patch takes the kept rank (a shared
  link only stays exact in a fresh tab)
- Example review per role (B7); "what your draft was up against" from comp leans
  (data-and-model.md step 4)

## Daily Draft

Jacob's asks: more engaging, more interesting things, fewer words, clearer facts. J26:
"much more info in a nice view of what champ should have got picked and what champ
should have won".

Status: framed as the last pick (match data has no pick order), recent games, EUW in
the context line, bans as icons per side, each player's rank. Options flip after the
guess, each to one fact with its numbers and games, the team's win chance and a star on
the model's pick; a score card with days in a row (one missed puzzle forgiven) and best.
After the reveal: a scoreboard per team, lanes at 14 with this game's gold difference
beside the patch's usual and which champion should win them, and the draft review
(Puzzle.review, refreshed while the patch is current): "Who should have won, on paper"
(blue's draft win chance with its 95% range), "Who should have been picked" (the model's
top five for the hidden slot), "Every pick, rated" (all ten seats as the last pick).
Pick shares: answers go once per browser to POST /api/daily, counted in api.db
daily_answers with nothing about the sender. Share is hidden in preview mode (keyed on
html.zig's preview banner; production-key.md "do not advertise"). Hint before the
guess: Range (the hidden champion melee or ranged, Data Dragon attackrange; none for
champions whose range changes, dailydata.no_range), costing the clean tick.

Next: share text with the facts. Later: puzzles from clear
comp leans (data-and-model.md step 5).

## Learn

Jacob's asks: harder and easier at once (an easy start, harder levels later), more
engaging, much fewer words, one thing per screen; "learn is boring ... too easy, its
gotta make someone think". Redesign as a discovery puzzle game: docs/learn-proposal.md.

Status: tabs Puzzles (first), Basics, Practice; progress in localStorage only. Puzzles
(src/site/puzzles.zig): one a screen, a committed guess (slider or one of two to four),
then the real number with its games, the table behind it, one line why and a takeaway.
Ten hand-written from finished checks (each names its source), one from this patch's
curves (a lane leader that loses), and generated ones from live data: early or late
(`meiolol lean`), counter or just strong (lane curves, every region, 30 days); 18 in one
line. Basics: a lesson a screen, questions only where the answer clears chance (5+
points and 2 SE). Practice: three levels of five drills by the generator's Difficulty.
No win chance or points anywhere in Learn.

Next:
- The chapter map (proposal "Home"): chapters as tiles with their question, progress
  and tips earned; a champion icon on generated questions; refresh the hand-written
  numbers when their checks are rerun; myth or measured cards (chapter 5); a daily five;
  drop or keep Basics and Practice (Jacob)
- Levels inside a Difficulty by clarity (easy drills whose one bringer also leads its
  lane first; hard ones sorted by how close the four sit); lesson examples as tiles,
  not sentences; a lesson from lane curves (who is ahead at 14) as Level 2's primer
- Undecided, for Jacob (research/questions/coach-draft-advice.md,
  coach-stat-claims.md): a "popular advice, tested" page or lesson set, each common
  coaching claim with what our games say (jungler-support and mid-ADC synergy not
  detected; damage mix matters; split pushers no better than other top laners; bounties
  pay the team behind more per kill)

## Search

One header search on every page: champion, "Ahri vs Zed" ("ahri zed", "ahri v zed") or
Name#TAG, aliases and typos, keyboard and phone (static/search.js, data/search.json
from src/site/search.zig). Next: the same matching in table.js filters (champions index,
opponents) and a filter on build/index.html; "Ahri build", "Ahri top" queries;
pipeline_test checks for the header script and search.json.

## Champion page

Goal: match LoLalytics and the other leaders on content and density, then beat them
with what only we have (lane curves, vs usual, early/late lean, pick-up difficulty, the
player's own record). Gap list, measurements and target layout: docs/champion-matchup.md
(research champion-matchup-gap C1-C18).

### Steps

- CH0 Jacob's choices still open: (d) trends by patch or by day; (e) a blind-safe score,
  rune rows split by melee or ranged opponent, purchases split by gold lead. (a)-(c)
  answered: docs/plan/ui/champion.md (one role on screen, most played and highest win
  rate at once, no tier letters)

### Status

- First screen (CH1, CH7): head card (RolePicker with shares, stat strip), section tabs
  and filters on one row (phone: a Filters button), then the build panel with the level
  grid under the runes. Darius 1920x1080: panel y 266-953, first opponent y 1059;
  390x844: strip and the rune-page row by y 700
- Filters: one row in the subbar on every Champions page (region grid, 30 days | patch,
  Plat+ to Master+), greyed where a page lacks them; footer follows them
- Build panel (builds.panel) on the champion page and the build page's top: runes as
  the in-game page, skill priority over a 4x18 grid, spells, start, first 3 items, boots,
  items 4-6 top 3 each; games, share and % won per cell; most played by default, a
  highest win rate toggle only where marked() allows. Builds data has items 4-6,
  skill_path and median minutes (arch-stats.md "Builds"). --max-keys is 1 << 20;
  matchup keys 1 << 22 (floor 1 after a week: watch at patch end)
- Opponents: 77x134 px tiles with unit words in one key line; tabs Lane, vs Jungle,
  vs Mid, vs Bot, vs Support, Duos (by ally role), vs usual with k per tab
  (champion.Pairs; off-lane pairs pull harder). Under a filter other than the root
  view, filters.js reuses the root view's opponent strengths
- By patch (win line, pick bars, rank in role) and by game length (5 buckets) cards
  after the opponents, from stats.Trend per view
- Build page: tables in a grid of ~490 px cells, rune pages drawn as in game with
  per-rune pick and win rate, "highest win rate" marks pulled by k per kind (File.shrink,
  builds.zig Spread; learned.md Items), never "best"
- Champions index (ui.tiers): role in place (RolePicker, All first), Games floor
  500 | 1.5k | 5k, movers band, DataTable with win rate as StatCell ink (no heat box:
  Jacob v7, v9), patch delta, players' violin, pick and ban Bars, games; Champion column
  210 px, the role icon at its end under All. Role tabs are icons, one row at 360 px

### Later

- Influence per opponent (bans into your pool's hard lanes, B3) and per rank filter
- Grey the builds strip when a filter leaves the patch view's region (filters.js)
- Objectives secured and won, end-of-game stats ranked in the role (LoLalytics only)
- Build variants (Kai'Sa AP, U.GG's tabs) as clusters of item paths

## Matchup page

Goal: a stat screen like LoLalytics' matchup view, laid out as the champion page,
without folds. No leader has a real matchup page: theirs is the build page filtered to
an opponent with no lane stats (docs/champion-matchup.md), so our curves and head to
head are ahead.

### Steps

None open: the Later list below.

### Status

- First screen: header one line, the five tiles and the headline in one strip, the
  pair's build panel ("Build against Jinx": options under 100 games left out, "· as
  usual" on cells matching the role-wide most played), gold, XP and CS in one card beside
  head to head. Chart axes: the band's first 20 min set them, each side its own nice top
  (the smaller at least a third of the larger)
- Head to head includes "First blood, kill or assist" and "Level 2" (curves v6,
  curvesfile.Extra; hidden on v5 files; the desktop copy is v5)
- Win rate by gold at 10, by rank and mastery; every rune with Taken more / less
  (builds.runeShifts; win rate left out: shrunk by k ~6,245, no rune moves 2 points)
- Per-matchup builds: Builder.vs per lane opponent; File.matchups for pairs with 300+
  games; a strip folds to one line when every cell is as usual
- Opponent strip under the header (x's lane opponents by games, x's win rate, the
  current one lit, an Opponent search); By game length beside Won by gold at 10 (the
  pair's 3 buckets, x against everyone dashed); Lane partners on bot and support pages,
  each side's 5 most played partners with vs usual and games
- Matchups index: the finder (docs/plan/ui/matchups.md): Your champion ⇄ Opponent in
  one row, Most played and Moved this patch, one picked champion's matchup grid
- MU7 audit items: gold line grey, runes without the empty band; the header's "usually"
  is x's expected rate against an opponent this strong (its tip says so), not the
  champion page's overall rate

### Later

- Two or three generated lines on how the lane goes, from the facts we have (where the
  lead comes from, item and level 6 timing), always with numbers; no leader has free
  matchup tips (Mobalytics charges)
- The leans and kit kinds that apply (data-and-model.md step 2); the champion pool block
- A link from the champion page's opponent tiles to the pair's build; its own builds
  file if the site build's parse time grows
- Pool first in the picker (B2), bans from the pool's hard lanes (B3, Q3); public form
  waits on J2 (decisions.md); patch day (B4, z 2.58)

## Pool page

Jacob's asks: champion pool and learning "so unintuitive ... not clear at all that
these stats mean anything"; likes "how hard champs are to learn"; also play "needs to be
way more helpful to actual players".

Status: "How hard to pick up" from mastery points at the time (learned.md Player):
pool.html table of every champion (new under 30k vs practised 100k+, gap, harder or
easier only for the clearest), a champion page line and table by points, each pool
option's line. Also play as plain shares with harder/easier to pick up; lanes, options
and ban fallbacks only from 1 point either way. Every region's games for difficulty,
whatever the view.

Next: how a main's players do on their first games of each also-played champion
(skills that carry over), once enough games; per champion and role (Ashe support vs
bot) when the games allow; keep the pool page's mains in the browser (ask Jacob).

## Patch changes

patch.html (docs/arch-site.md "Patch changes") shows what Riot changed (Data Dragon)
beside each champion's and matchup's move; J27 asked for the why.

- PC1 Why, from Data Dragon: champion, item and rune changes on the page, each item
  and rune with who uses it most (done). Left: older patch pairs behind PatchHead's ‹ ›
  (patch/<cur>-<prev>.html while the db holds both patches whole)
- PC2 Ability numbers from CommunityDragon (done; docs/data.md says what is still
  missing: behaviour changes, a few numbers in neither source)

## Draft tester

Jacob's asks: fewer words, more information, much clearer what affects what; "get more
creative". Ideas: each pick linked to the terms it moves (lane matchup, duo, comp lean)
drawn as a grid or arrows sized by effect, words only on hover. J3: name the three
detected cross-role kinds. Admin and /p/ only; the public draft tool follows J2.

## Before the production review

- Privacy/terms into src/site/prose.zig from docs/legal once Jacob fills the
  placeholders; objection by email (`meiolol forget`) until the form is live
- Privacy rules (J10): docs/privacy-rules.md (each rule Riot, law or self-imposed, with
  quotes); Jacob's list at its end
- Names (J18): Your games' Players panel lists all ten with champion, K/D/A and Riot ID
  as at the game, from api.db `match_names` (erased with the player, none for blocked
  PUUIDs; live API serves them); streamer mode only hides names live, so finished games
  show everyone. Daily Draft stays nameless unless Jacob says otherwise
- Reviewer walk (screenshots docs/review-shots/), left: GIFs and a short demo video
- Admin polish, low while the panel is Jacob's only (J9): fix3 leftovers R48-R50, R58,
  R60, R61 (plans in docs/archive/review-2026-10-17/fix3-notes-2026-10-17.md)
