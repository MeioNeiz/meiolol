# Plan: the website

By page. Jacob's list of 19 Oct first in each section (his words in quotes), then what
was already planned. Policy limits on what pages may show: docs/production-key.md
"Product rules" (no public draft win chance, no "+X% win rate", picks as several options
with reasons). Running theme across the list: fewer words, clearer facts, denser
layouts, more engaging.
Site-wide colour and density (Jacob 20 Oct: "more colour", "space inefficient"):
docs/design-ideas.md, measured layout, colour by impact, build order. Done: build
order 1-3 (9ed5c1f, d0026ff): scale tokens in style.css, tierlist.wrColour steps with
the thin-data cut and step-4 chip (dropped 20 Oct, Jacob: "they just look weird"; step 4 is now plain vivid text) (champions index, matchups index, vs usual, champion
win rate tile), matchup win rate, gold and lead table in ink; wrap 1,560, header 48,
29 px table rows (1080p champions table 17 to 26 rows). Next: build order 4 (opponent
tiles 76 px, 0 of 41 on a 1080p screen still), 5 (heat cells, pick/ban bars), 6
(header row, phone filters button); Your games game scale (2.5, 5, 10, 15 points) not
wired yet. Done 20 Oct (research review, f9's list): colour key under the champions
table, opponent grid and matchups index (tierlist.legend); win rate columns sort by
the rate pulled toward an average (role's, champion's own, usual), shown raw; --faint
#7a7f88 (4.6:1) and fade floor 0.6 (0.35 put grey ink near 1.9:1); champion header
"27th of 60 in Top" (the champions table's order, raw when filtered); no highest win
rate mark on boots and finished items (purchase timing: Mejai's ~80%); stale colour
prose fixed. Not wanted (Jacob 20 Oct): Hard lanes column; players behind a matchup's
games (curves format) left for now.
Done 20 Oct (morning, sitewide, J12 J14; e80df37): win rates continuous, no steps or
thin-data cut (wrColour mixes the stops in oklab, grey only at 50.0%, few games fade by
opacity); matchup rates on matchup_span (0.24, twice the table's) and coloured again on
the opponent grid, matchups index and matchup tile; patch page, champion patch line,
learning curves, Learn length bars and duos coloured too (tierlist.wrText). Matchup
gold verdict and Daily Draft lanes always give the number ("Ahri is 140 gold behind at
14 minutes", "usually level"); colour only where clear. Whole-box links: .bx row/tile
with its main a.box covering it (::after), other links and controls raised above;
hover and focus ring; tr.thin opacity moved to the row (a cell with opacity traps the
link). On champions, role and matchups tables, opponent grid (static and filtered),
pick lists, patch tables, pool lists and suggestions, learning tables, Daily archive;
centre-click checked on 8 pages at 1280 and 390 px. Next: Your games lists, home
record book and Learn lesson cards (not boxed yet); build order 4 to 6 above.

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
kill", "-13% died"). 20 Oct: each moment named by size, small under 5 points, medium,
big 10+, huge 20+ (chess.com's bands, finer near zero); small ones (about half) fold
under "N smaller moments" when over two, fainter dots on the chart; the lane's gold at
14 says where it sits among the matchup's games (above or below 3 in 4, or half).
Next: a minute's win chance change is the whole minute, not the fight alone; map areas
are rough, check a few against real positions; level 6 and first item have only a
median (spread needs curvesfile percentiles)

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
- Done 20 Oct: framed as the last pick (match data has no pick order: "treat it as"),
  EUW in the context line, bans as icons per side (no seat in match-v5)
- Done 20 Oct (J10, J11; f564fc1, d1ba73c): recent games (no week minimum); each
  player's rank by their champion; after the reveal a scoreboard per team (K/D/A, CS,
  gold, damage) and lanes at 14 with this game's gold difference beside the patch's
  usual ("Blue +420 at 14", "usually blue +300"); option facts with numbers ("+300 gold
  at 14", "led 58%", games); under 200 gold at 14 reads as even. Puzzle JSON `players`
  per seat, older puzzles backfilled from their used.txt game
- Done 20 Oct (research review): days in a row forgives one missed puzzle between
  finished ones (not counted; two in a row end it; today unplayed with yesterday missed
  still alive), best too (daily.js streaks(); duolingo-streaks ^f4, teach-draft C13).
  Share hidden in preview mode (its text links the site; production-key.md "do not
  advertise"), keyed on html.zig's preview banner, so it returns with the public build
- Done 20 Oct (Jacob: "sounds great"): pick shares. A finished puzzle's answers go once
  per browser (mine.sent) to POST /api/daily (option index, side), counted in api.db
  daily_answers with nothing about the sender (/api/ unlogged, nginx 60/min per IP);
  "42% picked" on each turned card and "50% chose" on each side from 10 players, with
  the count under the sides. Privacy page says so. Repeats or scripts can inflate it
  within the rate limit: accepted, counts only
- Next: pick verdicts (J2 form, Jacob 20 Oct): plan in
  data/team/2026-10-19-night/daily.md (score.pickSe, measure how many picks clear on
  the live patch first); a hint before the guess; share text with the facts
Later: puzzles from clear comp leans (data-and-model.md step 5).

## Learn

Jacob 19 Oct: harder and easier at once (an easy start, harder levels later), more
engaging, much fewer words, less overwhelming (one thing per screen). Later: lessons
from comp leans and lane matchups (data-and-model.md step 5).
Jacob 20 Oct 01:00: "not a good way to learn", just a quiz. Redesign as a discovery
puzzle game: docs/learn-proposal.md (team run 2026-10-19 night, teach).
- Done 20 Oct (night run, learn): Lessons and Practice as tabs, a lesson a screen (text
  with one question at a time under it, "2 of 3 right" at the end; Jacob 01:00 tapped the
  lesson text's champions as if they were answers, so those and the board's are plain
  names now and the "Check yourself" step is gone). Lesson questions only where the
  answer clears chance: a gap of 5+ points and 2 standard errors (Jacob: "who knows Yasuo
  vs Yone when it's so close"); the mastery-vs-counter question first, its fact a note, practice in three levels of
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

- Undecided, for Jacob (not built; Coach Rogue research 20 Oct,
  research/questions/coach-draft-advice.md, coach-stat-claims.md): a "popular advice,
  tested" page or lesson set, each common coaching claim with what our games say
  (jungler-support and mid-ADC synergy not detected; damage mix matters; split pushers
  no better than other top laners; bounties pay the team behind more per kill)

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
  a level, would fit the builds Key)
- Done 20 Oct (night run, mbuilds, 03361b3): rune pages drawn as the in-game page (every
  rune of both trees, chosen ones lit, shard rows with CommunityDragon icons) in the
  strip (two grid rows beside the other kinds) and on the build page (4 most played pages
  as cards). The builds file carries the rune trees (`trees`). Per-matchup builds done
  (Matchup page below)
- Done 20 Oct (morning run, builds, J13): pick and win rate per rune. New builds kinds
  rune (each of a page's six runes) and shard ([row, id]), role-wide only. Build page:
  every rune players took, laid out as in game, share and win rate under each, most
  played lit and highest win rate ringed per row (trees with a rune on 2%+); replaces
  the keystone and shard tables. Highest win rate everywhere (J13 follow-up, Jacob: "use
  our understanding of data"): the option whose win rate, pulled toward its slot's by k
  games (k per kind from how much options really differ, method of moments over the
  whole builds file at write time: File.shrink, builds.zig Spread; docs/learned.md
  Items) and taken at the low end of its range, is highest, among options with 100+
  games; a strict 2-SE lead test would mark under 1% of slots, so none. Tagged on rune page cards (that
  page shown even outside the top 4), table rows, and under each strip cell ("Highest
  win rate" with its value; for a rune page on the same trees, blue rings on the most
  played page). Unchosen runes less dim. Wording: "most played", "highest win rate",
  never "best". Needs the next builds run on the box (old files: tables as before).
  Per matchup too (Jacob: "game count, wr, pr"): rune and shard in matchup_kinds (runes
  under 1% of the pair's players left out of the file), "Runes in this matchup" under
  the matchup strip; game count (950, 9.5k) under each rune on both pages. Next:
  Jacob's look; watch the matchup builder's pruning floor and file size on the next run
  Every rune row with a win rate rings one (Jacob 20 Oct: "every row should have the win
  rate thing"): a row's only rune with 100+ games is its highest; 59 of 147 rows on 10
  pages had none, 44 of them such rows. Rows with no rune at 100+ games stay unringed
- Ban impact (J20, Jacob 20 Oct: "pbr" means a PBI-style score, "the most optimal ban in
  terms of pick rate and win rate"). Done 20 Oct (morning run, bans): core/banimpact.zig,
  games won above the role's average per 10,000 games the champion was not banned, edge
  x pick rate when not banned, whole numbers (lolalytics' PBI, (win - average) x 100 x
  pick / (100 - ban), is this count unlabelled; Jacob wanted a scale a reader can
  picture; per 1,000 most rows read 0.0 to 0.4), with the win rate pulled
  toward the role's average by k games (method of moments per role, as usualK; 500 to 750 on
  the EUW snapshot), so a thin champion's lucky edge can't count in full
  (research/questions/ban-impact-score.md). An "Influence" column (first "Ban impact",
  renamed 20 Oct: Jacob wanted a word without "ban") on champions.html and the role pages
  beside win rate, pick, ban and games, sortable (table.js); title gives
  its two parts (edge after pulling, pick rate when not banned); below 0 dim; footnote
  explains it. Wording: "influence", never "best ban" or a win rate gain. Reusable:
  Prior.of(stats, role) then score(wins, picked, banned, total), for the picker's ban
  options (B3, Q3: plan/app.md); the app's stats.bin has no ban counts yet (needs a
  per-champion banned count in statsfile, or champions.json). Next: Jacob's look; per
  opponent (bans into your pool's hard lanes, B3) and per rank filter (filters.zig has
  bans by rank)

- Undecided, for Jacob (not built; Coach Rogue research 20 Oct,
  research/questions/coach-draft-advice.md): a blind-safe score per champion (fits any
  ally and holds up into any enemy comp: low spread across comp leans, with J2's low end
  of win); build blocks with rune rows split by melee or ranged lane opponent, the first
  three items as one sequence instead of separate slots, and purchases split by gold
  lead at purchase (wording stays "most played", never "best")

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
Per-matchup builds (Jacob 20 Oct: "Kaisa Jinx, I still can't see runes and items of the
specific matchup"). Done 20 Oct (night run, vsbuilds, dd987a7, 1ea4ce3): builds counted
per lane opponent (Builder.vs: own key budget and pruning floor; runes, shards, start,
boots, first 2 and 3 items, skills), File.matchups for pairs with 300+ games (EUW 1,902
pairs, file 5.6 MB; every region 7,047, 12.5 MB), and a "Most played build in this
matchup" strip on the matchup page under the first screen ("same as usual" on cells
that match the role-wide most played; live on Kai'Sa vs Jinx, 3,341 games). Matchup key
budget 1 << 22 (floor 1, 1.1 GB, 6.5 min on the box; 1 << 20 let the floor reach 12).
Done 20 Oct (morning, builds): when every cell is "same as usual" the strip folds to
one line saying so (details, cells inside); 390 px checked. Next: a link to the
matchup build from the champion page's opponents grid;
maybe its own file if the site build's parse time grows (pages are static, so no page
pays for its size).
Already planned: pool first in the picker (B2), then bans from the pool's hard lanes
(B3, Q3); public form waits on J2 (decisions.md). Patch day (B4, z 2.58).
Matchup index: Jacob 20 Oct "unusable" (10k-item two-column bullet list). Done 20 Oct
(5682adf): role tabs (all roles while searching), one sortable table per role: both
champions with icons linking to each side's page, win rate track, vs usual, gold at 14,
games; each pair from the side that won more; rows only from the lowest Min games floor
keeping 5,000 or fewer (50 now: 4.4 MB, 315 KB gzip). Next: J11 (gold under 200 at 14
reads even, now coloured by sign); leaner rows (short icon paths, or rows drawn by JS
from JSON) to list thinner matchups; a search for one champion could flip its pairs to
its side; phone hides icons (names only) to keep Games on screen.

## Draft tester

Jacob 19 Oct: fewer words, more information, much clearer what affects what; "get more
creative". Ideas: each pick linked to the terms it moves (lane matchup, duo, comp lean)
drawn as a grid or arrows sized by effect, words only on hover. J3: name the three
detected cross-role kinds. Admin only today; the public draft tool follows J2.

## Before the production review

- Privacy/terms into src/site/prose.zig from docs/legal once Jacob fills the
  placeholders; objection by email (`meiolol forget`) until the form is live
- Privacy rules (J10) audited 20 Oct: docs/privacy-rules.md (each rule Riot, law or
  self-imposed, with quotes). Done: method and privacy pages, privacy.md, lia.md say what
  Daily Draft shows. Jacob's list at the end of privacy-rules.md
- Names (J18) done 20 Oct for Your games: a Players panel in the game review (review.js)
  lists all ten with champion, K/D/A and Riot ID as at the game, each linking to their
  lookup; api.db `match_names` (erased with the player, none for blocked PUUIDs; old
  games backfilled on refresh); lia.md rebalanced, privacy page and robots.txt (/api/
  not crawled). Streamer mode only hides names live (research streamer-mode-names), so
  finished games show everyone. Next: `deploy/jomify.sh install api` (live API still
  nameless until then); Daily Draft stays nameless unless Jacob says otherwise
- Reviewer walk 2026-10-14 (desktop and phone, every section) fixed in 38b940f,
  145a898, bbda65c, b37dd02, 74d6cdb, ab7d4cc; screenshots docs/review-shots/. Left:
  unknown URLs get a plain-text "not found" from meiolol-render (a site 404 page needs
  nginx error_page). GIFs and a short demo video still to do
- Outage copies (18 Oct) left: home page from the renderer (core build without the DB),
  a pipeline test for /admin/api/pages.txt
- Admin polish, low while the panel is Jacob's only (J9): fix3 leftovers R48-R50, R60,
  R61 (plans in docs/review/fix3-notes-2026-10-17.md), R58
