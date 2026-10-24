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
29 px table rows (champions table 29 px since CH8, 24 Oct). Build order 4 done (CH4,
24 Oct: 76 px opponent tiles, Darius's 40 in 3 rows); 5's patch change under the rate
done (CH8). Next (CH7 below): 5's heat cells and pick/ban bars, 6
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
- Done 23 Oct (J26): the reveal reviews the draft (Puzzle.review, refreshed while the
  patch is current): "Who should have won, on paper" (blue's draft win chance as a bar
  with its 95% range, the result against it, the edge by kind of term), "Who should have
  been picked" (the model's top five for the hidden slot with each one's team win
  chance, gap to the played champion and fact; the played one at its rank), "Every pick,
  rated" (all ten seats as the last pick: rank among champions with minGames, the
  model's pick, the gap, coloured when clear of score.pickSe's range). Option cards
  show the team's win chance, a star on the model's pick of the four; lanes say which
  champion should win them (both ratings and the matchup). Pick shares from 1 player
- Next: a hint before the guess; share text with the facts
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
- Done 20 Oct evening (learn, 2a4a9cb): Puzzles tab first (src/site/puzzles.zig). Jacob 20
  Oct: "learn is boring ... too easy, its gotta make someone think ... the best question
  was wr or switching to counter vs playing what you know". Eleven puzzles, one a screen:
  a committed guess (slider scored spot on / close / off, or one of two to four), then the
  real number with its games, bars of the table behind it, one line why, a takeaway; a
  score and all takeaways at the end. Ten hand-written from finished checks (mastery
  bands, Rengar vs Vayne newcomers, fed laner with the other four behind, fed top vs bot,
  5k behind at 15, bounty gold, first dragon vs herald/grub/tower, kills at 3:00-3:30,
  split pushers, luck), one from this patch's curves (a matchup whose lane leader, 60%+ of
  games ahead at 14, wins 5+ points and 2 SE under even, 300+ games; live: Viego vs Zac
  jungle, 74% ahead, Zac wins 57% of 367). Lessons renamed Basics; Practice unchanged
- Next for puzzles: refresh the hand-written numbers when the checks are rerun (each
  names its source in puzzles.zig); more generated puzzles from live data (champion
  lean: early or late; counter or just strong, from vs usual); a daily five; drop or
  keep Basics and Practice (Jacob)
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

Goal (Jacob 19 Oct, 22 Oct): match LoLalytics and the other leaders on content and
density, then beat them with what only we have (lane curves, vs usual, early/late lean,
pick-up difficulty, the player's own record). Gap list, measurements and target layout:
docs/champion-matchup.md (research champion-matchup-gap C1-C18). Darius at 1920x1080
today: first lane opponent at y 1,203, 72 numbers on the first screen, 4,074 px tall
with Top and Jungle stacked; LoLalytics shows the whole build in one 330 px panel there.
If the front end rework (frontend-rework.md Option A) goes ahead, the build panel and
opponent grid are its first components.

### Steps

- CH0 Jacob's choices: (a) one role on screen at a time, as tabs with the role's share
  (every leader does; recommended) or stacked as now; (b) the build panel's default:
  most played, with highest win rate as the toggle (recommended; LoLalytics defaults to
  highest win); (c) a tier letter per champion or not (LoLalytics, U.GG, OP.GG all show
  one; ours would come from the pulled win rate); (d) trends by patch or by day;
  (e) left from 20 Oct (Coach Rogue research): a blind-safe score, rune rows split by
  melee or ranged opponent, purchases split by gold lead
- CH1 First screen. Hero line with role tabs and share, one stat strip (win rate, rank
  in role, pick, ban, games, patch change, early lean as a word with the gold), then
  the build panel from today's kinds; the histogram and both prose paragraphs move
  below the opponents. Done when Darius at 1920x1080 shows strip and build panel above
  y 700 and opponent tiles start on the first screen; on the phone the strip and the
  panel's first row are inside 844 px. Start: src/site/champion.zig, src/site/builds.zig
  (strip), style.css. Design build order 7. Blocks: CH0 (a)
- CH2 Builds data. New kinds: items 4, 5 and 6 (nth finished item, any path), the full
  skill order 1-18 (packed key, 2 bits a level), median purchase minute per item;
  spells and the new kinds in the matchup builder's kinds too. Done when the box's
  builds run writes them (file size and run time noted here) and the build page lists
  them. Start: src/builds.zig (Kind, Builder.vs), src/site/builds.zig. Blocks: a builds
  run on the box. Done 24 Oct: kinds item4-6, skill_path (levels a game didn't reach
  filled by the player's order; architecture.md Builds), File.Build.minutes (median
  minute per boots and nth item, role-wide); matchups add spells and the new kinds. Box
  test, 16.21 all regions with matchups (348k games): 83 s CPU (76 before), 877 MB RSS,
  15.0 MB file (11.4); --max-keys now 1 << 20 (1 << 19 pruned in the patch's first
  week), matchup keys still 1 << 22 (floor 1 after a week: watch at patch end, MU1).
  Build page: Fourth to Sixth finished item tables, Minute column, Levels 1 to 18
- CH3 Build panel, full. Items 4, 5 and 6 as the top 3 options each (games, % won from
  100 games), the 4x18 skill grid, start, core 3, boots, both rune trees lit, and the
  most played | highest win rate toggle. One component used by the champion page, the
  build page's top and the matchup page (MU1). Done when Darius and Kai'Sa show it at
  1920 and 390 px; pipeline_test checks its sections. Needs CH2
- CH4 Opponents. Compact tiles (76 px, unit words once in a legend row; design build
  order 4), all 40 on screen; tabs over the same grid: Lane, vs Jungle, vs Mid, vs Bot,
  vs Support, Duos, from statsfile enemy and ally pairs (vs usual from both champions'
  role rates on the log-odds scale, pulled by k as usualK; thin data fades). Done when
  Darius shows six tabs with games on each tile; no data work needed. Wording "duo",
  never "best duo". Start: src/site/champion.zig, src/core/statsfile.zig. Done 24 Oct
  (7b0ef88): tiles 77x134 px (118 off lane, no gold), 19 a row at 1920, 4 at 390;
  unit words in one key line; Duos by ally role behind their own tabs, opening on the
  lane partner (bot, support) or jungle (mid for jungle), highest win rate first; tabs
  other than Lane are the root view's (chips marked under other picks; the filter data
  has lane opponents only). Vs usual's k per tab (champion.Pairs): off-lane pairs pull
  harder, so their numbers sit near 0 until thousands of games. Left: the grid starts
  at y 1,271 on Darius (CH1 moves it up)
- CH5 Over time and by game length. Win rate and pick rate over the last 6 patches with
  rank in role, and win rate by game length (5 buckets with games), as two small charts
  side by side; the early lean and patch paragraphs shrink to one line each. Done when
  Darius shows both and the length chart agrees with the early lean (learned.md).
  Start: a new tally by duration_s bucket per champion role (src/stats.zig rows carry
  it), src/site/champion.zig
- CH6 Build page compact. Tables at content width (numbers beside the name, not 1,000
  px away), the method paragraph a one-line link, items by slot and skill order tables
  from CH2. Done when no Darius Top build table is wider than ~900 px at 1920 and the
  runes start under y 300
- CH7 Phone. Subbar's three rows into one (a filters button; design build order 6),
  histogram folded. Done when Darius at 390x844 has its stat strip and build panel on
  the first screen
- CH8 Champions index. Rows at 29 px (said done 20 Oct, but live rows are 41 px, 19 on a
  1080p screen), patch change under the win rate (design build order 5), and
  ui-audit.md's index items (sort key, Min games knobs folded). Done 24 Oct: 29 px
  rows (24 px icons), the change since the previous patch under each rate (coloured
  when clear at 300+ games a patch, else faint; hover for both rates), the sort key in
  a line above the table and the Win rate header's title, Min games and Min lane %
  folded behind "Minimums", games with separators. Left: heat cells and pick/ban bars
  (build order 5), the empty band between Role and Win rate at 1280, phone role tabs
  wrapping Support
- CH9 Clarity: docs/ui-audit.md "Champion page" items (colour against copy, one win
  rate legend, the sort key on opponents and "also play", one number format). Done 24 Oct
  (9df944c): patch line in plain ink unless clear, the opponent key says it is the
  matchup scale, the order named on opponents, "also play" shows its lift and sits in
  narrow columns, separators on players and games (gold still without)

### Status

- Filters: one row in the subbar on every Champions page (region grid, 30 days | patch,
  Plat+ to Master+), greyed where a page lacks them; footer follows them (22 Oct)
- Opponent grid with vs usual (champion.zig usualK; learned.md 2026-10-20) and the
  builds strip from the patch view's builds file (greyed under 400 games; the page's
  filters don't change it); under a filter other than the root view, filters.js reuses
  the root view's opponent strengths
- Build page: rune pages drawn as in game, per-rune pick and win rate, "highest win
  rate" marks (pulled by k per kind, File.shrink, builds.zig Spread; learned.md Items),
  never "best"
- Influence column on champions and role tables (core/banimpact.zig;
  research/questions/ban-impact-score.md)

### Later

- Influence per opponent (bans into your pool's hard lanes, B3) and per rank filter
- Grey the builds strip when a filter leaves the patch view's region (filters.js)
- Objectives secured and won, end-of-game stats ranked in the role (LoLalytics only)
- Build variants (Kai'Sa AP, U.GG's tabs) as clusters of item paths

## Matchup page

Goal (Jacob 19-20 Oct, 22 Oct): a stat screen like LoLalytics' matchup view, laid out
as the champion page, without folds. No leader has a real matchup page: theirs is the
build page filtered to an opponent with no lane stats (docs/champion-matchup.md), so our
curves and head to head are ahead. Gaps: the pair's build in full, a visible way to
switch opponent, a first screen spent on one big chart of a nearly flat line.

### Steps

- MU1 The pair's build in full: CH3's panel refiltered to the pair (spells, items 4 to
  6, skill order from CH2's matchup kinds), cells matching the role-wide most played
  marked small ("as usual") instead of whole cards; options under 100 games hidden,
  under 400 grey, never a win rate on fewer than 100 (LoLalytics and OP.GG print 100%
  on 2 to 4 games). Done when Kai'Sa vs Jinx shows spells and items 4 to 6 for the
  pair. Needs CH2, CH3. Watch the matchup builder (key budget 1 << 22: 1.1 GB, 6.5 min
  on the box) and the file (12.5 MB every region)
- MU2 Opponent strip under the header: x's lane opponents sorted by games, icon and x's
  win rate, the current one lit, a search; replaces "Change opponent" (the swap stays).
  Done when another opponent is one click from the first screen; the strip scrolls on
  the phone. Start: src/site/matchup.zig
- MU3 First screen. Header one line, the five tiles as one strip, then the build panel,
  then gold, XP and CS as three ~240 px charts beside head to head; the gold axis fits
  the average and middle half to 20 minutes, not ±3,000. Done when at 1920x1080 the
  strip, the panel and the charts' tops are on the first screen; phone gold chart at
  container width (ui-audit 7). Design build order 8
- MU4 Bot lane supports: on bot matchups x's and y's supports (ally pairs), each with
  games and vs usual; support matchups show their ADCs. Nobody else shows this. Done
  when Kai'Sa vs Jinx lists both. Data exists (statsfile ally)
- MU5 Win rate by game length for the pair (300+ games, 3 buckets) beside win rate by
  gold at 10. Shares CH5's tally
- MU6 Level 2 time and first blood for the pair in head to head (curves format: header
  fields and a box rebuild of the curves)
- MU7 Clarity: docs/ui-audit.md "Matchup page" items (one game count on screen, one
  "usual" with the champion page, gold line not in accent violet); runes section
  without the empty right 40%
- MU8 Matchups index: J11 (under 200 gold at 14 reads even, now coloured by sign);
  leaner rows (short icon paths, or rows from JSON) to list thinner matchups; a search
  for one champion flips its pairs to its side; phone drops icons to keep Games

### Status

- Dashboard since 20 Oct: headline, five tiles, gold curve beside head to head
  (mirrored bars, x #3f97ee, y #f0596b), XP and CS curves, win rate by gold at 10, by
  rank and mastery, the build, every rune with Taken more / less (builds.runeShifts; win
  rate left out: shrunk by k ~6,245, no rune moves 2 points)
- Per-matchup builds: Builder.vs counts runes, shards, start, boots, core 2 and 3,
  skills per lane opponent; File.matchups for pairs with 300+ games (EUW 1,902 pairs,
  5.6 MB); a strip folds to one line when every cell is as usual
- Matchups index: role tabs, one sortable table per role, rows from the lowest Min
  games floor keeping 5,000 or fewer (50 now: 4.4 MB, 315 KB gzip)

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

Jacob 20 Oct: champion pool and learning "so unintuitive ... not clear at all that these
stats mean anything"; likes "how hard champs are to learn"; also play "needs to be way
more helpful to actual players". Done 20 Oct (learning session): "How hard to pick up"
from mastery points at the time (games after the player's mastery fetch; learned.md
Player) replaces the 16-day history curves (93 of 173 "from the start", top rows noise):
pool.html table of every champion (new under 30k vs practised 100k+, gap, harder or
easier only for the clearest), a champion page line and table by points (under 10k to
300k+, gold at 14), each pool option's line. Also play as plain shares ("59% (28%)")
with harder/easier to pick up; lanes, options and ban fallbacks only from 1 point either
way, so most mains now say "none stands out" instead of +0.2s. Every region's games for
difficulty, whatever the view. Next: how a main's players do on their first games of
each also-played champion (skills that carry over), once enough games; per champion and
role (Ashe support vs bot) when the games allow; keep the pool page's mains in the
browser (ask Jacob).

## Patch changes

patch.html (src/site/patch.zig, src/patchday.zig) lists the champions and matchups that
moved clearly from the previous patch, with games and ranges, but not why. J27: each
move says what the patch changed.

### Steps

- PC1 Why, from Data Dragon. Under each champion row what changed for it: base stats,
  spell cooldowns, costs, ranges, effect numbers, spell and passive text, from the
  championFull.json diff of the two versions (lab's changedList in patchdays.zig, moved
  to the backend and extended to say which field and old -> new); items and runes the
  champion builds often (its builds share) whose item.json or runes diff changed. A
  matchup row shows either side's changes. A move with nothing listed says so: "no
  change to this champion in Data Dragon" (knock-on from items or other champions, or a
  change Data Dragon doesn't carry). Changed champions with no clear move yet listed
  apart, with their games. Done when 16.20 -> 16.21 shows them and pipeline_test covers
  a fixture diff. Start: src/ddragon.zig, src/site/patch.zig
- PC2 Ability numbers: Data Dragon lacks most ability damage changes
  (research/questions/patch-transfer.md "Open"); CommunityDragon's data or Riot's patch
  notes page would complete PC1. Read docs/data.md before adding the source. Done when
  16.21's notes' champion changes all appear

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
