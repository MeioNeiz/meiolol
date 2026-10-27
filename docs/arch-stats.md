# Architecture: derived stats

What the backend derives from games for the stats pages. Layout, storage, crawler, model
file and packed rows: docs/architecture.md.

## Lane curves (src/curves.zig, src/core/curvesfile.zig, curvefit.zig, src/site/matchup.zig)

`meiolol curves` (--platform as stats, --min-games default 10) reads every ranked
solo game with a timeline: by default every patch of the last --days (30) to
data/export/recent-curves.bin (label "last 30 days"); with --patch, those patches to
data/export/curves-<patch>.bin (the Your games service reads these per patch). `--site`
(the web loop) writes the four files the site reads, EUW and every platform by last 30
days and --patch, in one pass: each timeline is decoded once. Per lane
matchup (role, champion pair), bracket (all, Iron-Silver, Gold-Emerald, Diamond+;
median visible tier of the game's players, never MMR) and experience (all games, or a
or b with 100k+ mastery): per minute 1..25 the raw p25/p50/p75 of gold, XP and CS (lane
+ jungle) difference with n still playing, and the estimated mean with its standard
error (below); who leads in gold at 14 min and how often each side then wins; comeback
odds (games and wins by lane gold lead at 10 and 15 min in five buckets); games where
each takes part in killing the other before 6, 6-14 and after 14 min, and in the game's
first kill (v6); median level 2 (v6), level 6 and first finished item times; `own`, the share of the 14-min gold estimate from the
matchup's own games. A role baseline record a = b = 0 per bracket counts every lane from
both sides: comeback counts, and per minute n and the role's spread (quartiles,
median 0). Pairs are stored once (lower champion id first, a mirror from blue's side);
`Curves.get(role, bracket, me, them)` returns a View from `me`'s side that negates and
swaps percentiles (p10, p25, p50, p75, p90) and estimates. The file also holds the fit
(per role, bracket, level, metric and minute: sigma^2 and tau^2; smoothing per role and
metric) for the method page. Format at the top of curvesfile.zig; bump the version on
any change. Since v6 readers take the previous version too (v5: no Extra, read as
zeros), so the Your games binary can go first; the desktop bundle gets the file as v5
(`meiolol desktop-curves`, web-loop.sh), which every released app reads. Rolling a bump
out: stop meiolol-web on the box before the push, so the
deploy restarts the loop, which rebuilds curves before the site (a running loop is only
signalled and would build the site on old-format curves, dropping the lane pages); then
the Your games binary (docs/your-games.md, Deploy)

Curves under --min-games are left out of the file, not the fit: every lane still goes
into the champion effects and tau^2, so the written estimates do not change. On 16.20
(190k EUW games) 71% of 166.5k curves had under 10 games: 226 MB, about 65 MB at 10.
Without a pair's curve, readers do as for an unseen pair: Your games and the lane card
fall back from the player's bracket to all ranks, then to no curve (Your games compares
with an even lane); filters.js shows the plain average of the games picked; no matchup
page. The matchup index's 1 and 5 floors then show the same as 10

Estimation (src/core/curvefit.zig, research/questions/curve-statistics-method.md), per
role, metric and minute, closed form: champion effects by ridge least squares on the
pairs' means (baseline A vs B = e_A - e_B; ridge by method of moments); tau^2 = unweighted
mean over pairs with 2+ games of (r^2 - s^2/n), r = mean - baseline, s^2 the pair's own
variance (rare pairs vary more than the pooled sigma^2), floored at sigma^2/100, so k =
sigma^2/tau^2 <= 100; estimate = baseline + n/(n+k) r. Brackets shrink toward the
all-ranks curve and experienced curves toward their bracket's, tau^2 from each unit
against the rest of its parent's games (the parent holds the unit's games). Then a
Whittaker smoother (second differences) across minutes, its strength per role and
metric picked by a split-half test (fit on half the games by game hash, score against
the other half's raw means; leave-one-minute-out would pick too little, as a curve's
minutes share their games). The command logs per role and metric sd/tau/k at 5, 10, 14
and 20 min, nested k, lambda and the split-half error of zero, baseline, raw, shrunk and
smoothed predictors. Not yet: patch decay weights, same-player clustering (n_eff), tau^2
smoothed across minutes.

Measured 2026-10-11 on 18.8k games (all regions, Platinum IV+ crawl, mostly 16.19):
sd of gold difference at 14 min 790 (support) to 1650 (bot); tau 140-240 gold; k at 14
min gold: top 67, jungle 73, mid 29, bot and support at the cap (100). Split-half rms
error at 14 min (top gold, 1611 pairs, noise of the other half 1054): raw means 1445,
role mean 0 1130, baseline 1078, shrunk 1073: thin raw means are far worse than the
baseline, and at this volume the baseline carries almost all of it; too few pairs have
50+ games to see the matchup term pay. Smoothing chosen near zero (lambda 0 to 1) except
support gold (100). Nested k is noisy (few units with games in both parts). On the box
(27k games, 15:29Z): pairs with 50+ games in the fitting half (bot 63, support 32): the
baseline alone did as well as or better than shrunk (bot gold 173 vs 204, noise 182), so
the matchup term does not pay yet; a higher k cap (300, 1000) did not help overall
(tried on the Mac). ReleaseFast on the Mac: 4 s and 163 MB peak for those 18.8k games,
file 37 MB (13.7k matchups, every bracket and experience variant with 1+ game). On the
micro with the crawler running: EUW 7.6k games 2.5 min, all regions 27k games 6.3 min
(~30 s of fitting per role). Memory grows with lanes (~180 B each, 5
per game): ~2.7 GB at 30 days of all regions at ~100k games/day, beyond the micro's 1
GB; the A1 (12 GB) holds it.

`meiolol site` reads recent-curves.bin when present (curves-<patch>.bin with --patch;
the rest of the site stays on the newest patch): two pages per matchup with an
all-ranks curve, one from each side (matchup/<role>/<a>-vs-<b>.html, a's numbers
first), ui.matchpage's three islands (arch-site.md): the head (ChampHeader's pair, ⇄
swaps sides, × back to a's champion page; StatStrip; MatchupStrip of a's other lane
opponents with a page, by games), the pair's build (builds.forVs: the region's patch
view, the previous patch's while this one's is thin), then one LaneChart with a Gold |
XP | CS switch (line = estimated mean; band = the matchup's middle half of games from
200 games, below that the role's middle half drawn around the line; the axis fits the
band to 20 min; the previous patch's mean dashed in patch views) beside Versus rows
(wins, ahead at 14, wins from ahead, first blood, kills by phase, level 2 and 6 and
first item medians), won by gold at 10 (TrendChart over curvesfile.comeback buckets, the
role's rate in each tip), by rank and mastery (DataTable: brackets, then either side
with 100k+ mastery from 10 such games) and, bot and support, both sides' lane partners.
Champion pages link each lane opponent to its page. Every matchup gets a page, as on
lolalytics; under 200 games or with own < 0.5 ("mostly the champions' baseline") the
lane and head to head are faded, and the chart draws minutes with at least min(10,
games) still going. The method page shows k by role and minute from the view with the
most games. Size: 13.7k pages in the all-regions 30-day view at
18.8k games, 252 MB with .gz; raise --min-games if the upload grows too big. The index
has a min games selector (html.minGames, static/min-games.js; default 50). Not yet:
core-item split, older patches, rank filter. deploy/web-loop.sh rebuilds the four
curves files hourly and on a new patch.

## Builds (src/builds.zig, src/site/builds.zig)

`meiolol builds` (--patch default the newest, --platform as stats, --min-tier default
PLATINUM per player from participants.tier, "any" for everyone) writes
data/export/builds-<patch>.json (all-builds-... with --platform all): per champion and
role the 10 most played options of each kind with games and wins, plus the kind's total
(the share's whole) and names/icons of what they use, so the site needs no network.
Kinds: keystone, rune page (both trees, secondary pair sorted), stat shards, summoner
spells (unordered pair) from participants; from timelines: starting items (bought in the
first 90 s, net of undo and sale, no trinkets), boots (first tier-2, tier 3 counted as
its tier 2; "no boots" once two items are finished without), first two and first three
finished items in purchase order (ddragon legendary rule, as first-item timing; an undone
purchase comes off), the 4th, 5th and 6th finished item each on its own (any path), skill
priority (Q/W/E by points after 13 skill-ups or the game's end from 11, ties by who got
there first; EVOLVE ups skipped), skill path (the slot of each level 1-18, 2 bits a level
in two u32s; from 11 skill-ups, a shorter game filled as the player was going: R when
due, else the basic with most points under 5; kits off those rules, R before 6 or a basic
past 5, only from a full 18). Per build `minutes`: median minute bought (one-minute
histogram, interpolated) of each boots and finished item in its slot (0 boots, 1-6 nth
item), for the items in the file's options; role-wide only. Matchups count every kind but
keystone and skill_start. Needs Data Dragon's item.json,
runesReforged.json and summoner.json for the patch (ddragon.buildData); stat shard names
are a table in ddragon.zig.

Memory: one hash map of distinct options (~50 B each) capped by --max-keys (default
1M, ~60 MB); at the cap options at or under a rising count floor are dropped (logged),
totals never. Per game an arena reset, like curves. Measured on 3.8k EUW 16.20 games
(1.7k timelines): 1 s, 29 MB RSS, 25k options, 1.1 MB JSON; ~0.25 ms per timeline, so
a full EUW patch (~400k) is a couple of minutes on a fast disk; on the micro the
first run took ~7.5 ms a game (docs/backlog.md "Builds"). deploy/web-loop.sh runs
`builds --site` daily and on a new patch: EUW and all regions, the current patch and
the last 30 days (data/export/recent-builds.json, all-recent-builds.json; no matchups),
from one pass over the timelines (builds.buildEach, a stats.Slice per file), in the
background at nice 10 (log data/builds.log); the next site build picks them up. Names
and icons come from the patch's Data Dragon, so an item removed since has none.

`meiolol site` reads the four files, one per view: a page per champion and role in
each view (build/<slug>-<role>.html, patch/build/..., all/...) when the role has 10%+ of
the champion's games in the file; champion pages carry each view's most played choice
per kind in each role section (builds.strip, one variant per view, below) and link to
that view's page. Matchup pages show their region's patch builds.
Rows most played first, never by win rate, no "best" or "recommended": games and share
on every row, a win rate only from 100 games and always with its 95% range (±1.96 SE),
rows under 400 greyed, a "more data needed" note under 400 for the champion-role. Item,
rune and spell icons hotlink Data Dragon like champion icons. Method page section
`#builds`. Levels 1-3: kind skill_start. Not yet: builds by rank. Box, 16.21 all regions
with matchups (348k games, 24 Oct): 83 s CPU, 877 MB RSS, 15.0 MB file (11.4 MB before
items 4-6, skill paths, minutes and the matchups' spells); both key budgets prune at
floor 1 in the patch's first week.

## Early or late (src/lean.zig, src/site/lean.zig)

`meiolol lean` (--platform default every region, --days 30, --patch instead of days)
writes data/lean.tsv: per champion-role its team gold lead at 14 min and its team's win
from an even game at 20 min (state: team gold, XP, held objectives), both additive over
the ten picks of a game and shrunk per role (docs/model.md "Early and late champions").
Played games (900 s+) reaching 15:00 with a compact timeline; one stats.scan and one
pass over the timelines (TimelineGames.initSince). TSV, versioned: a `meiolol-lean`
header line (version, games, oldest and newest start ms, scope text), a column line,
then champion id, role, games at 20, gold, gold sd, win pp, win sd. A format change
bumps `lean.version`; the site's parse rejects other versions and leaves the line out,
so roll out like curves: binary first, then the new file. On 2253Z (287k games, all
regions, 30 days): 34 s on the gpu-box, ~860 rows. deploy/web-loop.sh runs it daily in
the background at nice 10 (log data/lean.log); the next site build reads it.

`meiolol site` (Options.lean, from DATA/lean.tsv) puts one line per role section on the
champion pages, after the tiles: "Early lean" / "Late lean" when both numbers are clear
(|effect| >= 2 posterior sd, 200+ games at 20) and opposite, each clear number alone
otherwise, "no clear early or late lean" when neither, "too few games" under 200. Its
own scope ("every region, last 30 days"), not the filters'. Method page `#lean`.
`meiolol lean --check` is the lab check (folds and dev-val, never the test window).

## Pool (src/pool.zig, src/site/pool.zig, ui/poolpage.zig)

A player's main is their top champion; they play another when it has at least 10% of the
main's weight (games now, mastery points once that table fills; min 10 games). "Players
who main X also play Y" is listed by lift: share of X-mains playing Y over Y's share
among players who don't main Y, shrunk toward 1 by 20 pseudo-players; lists from 30
mains, shown as both shares ("59% (28%)") with how hard Y is to pick up. Lanes (hard,
options' and fallbacks') only from 1 point either way (Options.min_lane_pp). From the
model file's lane pairs (score.matchupPp, 30+ games): X's five worst lane matchups, the
also-played champions in X's role that are positive into them ("options", several, with
reasons), and those positive into X's best lanes (ban fallback). `meiolol site` writes
data/pool/<slug>.bin per main (ui/pooldata.zig), pool.html (an island, ui-pool.wasm: up
to five champions, main first; #pool=ids) and a section on each champion page. Mastery
source (points, champions played in the last year, 50k total and 10k per champion) is
used once it has more players than the games source. Not yet: curves instead of win
rates for hard lanes, your own record per matchup.

## How hard to pick up (src/learning.zig, src/site/learning.zig)

Win rate by the player's mastery points on the champion at the time: bins under 10k,
10-30k, 30-100k, 100-300k, 300k+, with lane gold difference at 14 where a timeline exists.
Points at the time: the player's one mastery row (refetched monthly) for games that start
after its fetch (median 1.6 days after, p90 3.5 on snap-20261018T1007Z), points of the
champion then, 0 when absent. Games between fetch and game are missing from the points.
Ruled out: the row's last game on a champion (its points are that game's), which leans to
losses (docs/learned.md). Per champion, all roles: new (under 30k) against practised
(100k+), 200+ games each; the gap's average over champions, and harder or easier when the
gap is 2 standard errors off it; the table sorts by the gap pulled toward the average by
the between-champion spread over its own noise. `meiolol site` writes pickup.html (and
pickup/<role>.html) and a section on each champion page, both over the view's period
(all regions). Partials:
learning.bin (arch-site.md "Views partials"); the database path joins participants to mastery.
