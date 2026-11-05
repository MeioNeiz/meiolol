# Components register

Written by `zig build uilint -- --write` from src/site/ui (ui.all, then ui.pages):
don't edit by hand; a test fails when it is stale. Search here before building
anything, and extend a component rather than copy it. Hand notes (rules that span
components): docs/plan/ui/README.md. Each entry: file, scope classes, "site" when
its CSS ships to the site, the gallery's states, and the components importing it.

## Contents

**Controls**
- Button: the pressable shape
- Chip: a small pill that toggles a filter (pressed or not), removes a choice, or...
- ScopeChip: what a block's numbers cover, in the subbar's words, "EUW · 30 days ·...
- Segmented: one control for views, sorts and filters
- Tabs: a card's or page's sections, on the panel's edge
- Select: a button showing its value and a chevron, Segmented's height, that opens a...
- Toggletip: a dotted term that opens a short note on tap (popovertarget: no script...
- Tip: a short line about what it wraps (a range's ends, a full count, a place's...
- ActionButton: a Button that runs something on the server (restart the crawler, build...
- SiteSearch: the header's search
- RolePicker: the role a page shows, in Segmented's well: each role's icon with its...
- FilterBar: the page's filters in one row, usually a Card's toolbar band
- ChampSearch: a box that finds a champion as you type, the way the header search does...
- LockBar: the champion page's locks (docs/plan/ui/champion-locks.md), one Chip with...
- GuessSlider: a guess on a number line
- ChampRolePicker: a champion and the role it plays
- IdLookup: a Riot ID box and Review as one control, the newest Riot IDs this device...

**Labels and icons**
- Badge: a flat label (role, result, "few games", a patch note)
- AlertBand: a service's state in one line at the top of a page: ok, warn or down, a...
- ModelBadge: which model a number comes from
- RoleIcon: Riot's position icon as a CSS-masked span in currentColor, the lane solid...
- ChampIcon: a champion's square portrait, 20 to 48 px, with the states a seat or a...
- GameArt: an item, rune, rune tree, stat shard or summoner spell icon
- ObjectiveIcon: a tower, inhibitor or epic monster as a small glyph (a CSS mask, like...

**Figures**
- StatCell: one figure, formatted by its kind through fmt.zig and coloured by how far...
- Rate: a win rate, the one way one is shown
- Delta: a signed change in points, on the scale's colour with its sign (or an arrow)...
- Bar: a magnitude without good or bad (pick, ban, games), a neutral ink bar beside...
- Kda: kills / deaths / assists in tabular figures, the slashes faint; optionally the...
- StatStrip: a page's headline figures in one row, plain (no box per figure): a small...
- WinSplit: a game's win chance as one bar, blue's share from the left in blue and...
- PatchSpark: a win rate over the last few patches in a fixed-size cell (a table's...
- Versus: your team against theirs, one figure at a time
- ResultStrip: recent form as a tick per game, oldest on the left; a win full height...

**Charts**
- Chart: The one chart system (docs/plan/ui/README.md "Charts: one system")
- DotPlot: one axis centred on a reference (the champion's own rate in the role, 0 for...
- TrendChart: a win rate over a few ordered points (patches, game length buckets...
- TimeChart: ops series over clock time (matches stored per hour, requests per minute...
- Histogram: how players' win rates on a champion spread (10+ games each), bars per...
- AucChart: the method page's "Model accuracy vs data", AUC on held-out games for a...
- LaneChart: you minus your lane opponent by minute (gold, XP or CS), against the...
- TimelineChart: a game by minute, win chance (or your team's gold lead) as an area...
- Minimap: Summoner's Rift as a square, lanes and river drawn faintly, with where...
- RankStrip: every champion one seat could have played as a dot on one axis, its...
- DraftFlow: a draft's 20 turns in order, as the four phases (6 bans, 6 picks, 4 bans...
- ReasonBreakdown: why one pick lands where it does, as a waterfall from the role's...
- HeatGrid: champions against champions as a grid of points vs usual
- MatchupGrid: a champion's matchups in one role as a dot plot, against or with each...
- Violin: how a champion's players' own win rates spread, as a mirrored shape on a 25%...

**Cards, tables and text**
- Card: Card, its bands and SectionHead
- Prose: a markdown doc (learned.md, model.md, the eval report) as nodes
- DataTable: a real table where the data is a table, as an island
- TodayCard: a Card with a one-line title, real content and one action (home's Today...

**Champions and builds**
- ChampHeader: a champion page's first row: the portrait, the name as the page's h1...
- MatchupBrief: under the champion page's matchup chart, the chosen opponent (or ally)...
- MatchupStrip: a champion's lane opponents in one row that scrolls sideways, most...
- ChampList: a short list of champions, one line each: portrait, name (a badge after...
- SkillGrid: a skill order as the 4 x 18 grid of levels (Q, W, E, R rows, the level's...
- ItemPath: the first finished items in the order bought, as icons with arrows, then...
- RuneTree: every rune players took, laid out as in game (trees side by side...
- BuildPanel: the champion's whole build in one panel, as an island
- CandidateList: ranked champions for one seat, the core of "select an option to see why"
- PoolSlots: a player's champion pool as a band of slots, main first (marked), each...
- ChangeLine: what Riot changed, one line each: the slot's key (Q, P; · for stats and...
- PatchHead: the patch page's title, the pair it compares, with ‹ › to the older...

**Games and drafts**
- DraftBoard: a draft as lane rows, our seat on the left, theirs mirrored on the...
- TeamRows: a game's five lanes as mirrored rows, our player left, theirs right, the...
- GameStrip: your games as one scrolling row of small cards (champion, duration, a...
- RangeInspector: what the game graph's selection holds (game-detail.md)
- GameHeader: one game at a glance, no sentence (game-detail.md "First screen")
- GameRow: one of your games in the Your games list (your-games.md "Games"), tinted by...
- Scoreboard: a game's players as five lane rows, your team left and theirs right...
- LaneDuel: your lane against your opponent's (game-detail.md "Lane")
- ItemRow: one player's purchases by shop visit, each visit its items over the minute...
- PuzzleCard: one puzzle a screen
- ChoiceCards: a puzzle's 2 to 6 answers as cards, each with its key number (the page...
- DailySeat: Daily Draft's review after the reveal (docs/plan/ui/daily.md): the...
- DailyDays: Daily Draft's head (title, badges) with the days strip and streak, the...
- DayHead: a day group's head in the Your games list (your-games.md "Games"): "Today"...
- PlayerBar: the Your games page's head card (your-games.md "Structure"): rank badge...
- ProfileSummary: beside the Your games list (your-games.md "Structure"), what the...
- RecordTile: one record from a player's games (your-games.md "Highlights"): the...
- Highlights: the records in a player's games (your-games.md "Highlights"), from the...
- GameTrend: GameTrend (your-games.md "Over time"): a player's games in order on...

**App screens**
- ChampSelect: the desktop app's champ select screen
- CompView: the desktop app's comp view once all ten champions are locked (docs/plan/...
- LobbyForm: the desktop app's panel before champ select (home, lobby, queue, match...
- AppHome: the desktop app's tiles before champ select (docs/plan/ui/app-whole.md...
- GameBuild: the desktop app's in-game panel under the island (private edition): my...
- LoadScreen: the desktop app while the game loads
- GameScreen: the desktop app's in-game panel, private edition only (the public one...
- PostGame: the desktop app after a game, static HTML after the island (nothing to tap)
- SignIn: the app's sign-in to meio.lol (the poller's device.zig does the request)
- Practice: Practice (private edition): a champ select set up by hand in the app...
- Picks: the app's Options panel in champ select (docs/plan/ui/app-options.md), its...
- App: The desktop app's page as one island (ui-app.wasm)
- AppBar: the desktop app's top bar, the site's header (site.zig) with the app's...

**Pages and their sections**
- TextPage: A page of running text: method, download, privacy, terms, the 404
- SiteHeader: every page's top bar: the logo, the page links, the search
- GamePage: the game page's first screen as one island (game-detail.md): GameStrip...
- Finder: The matchup finder (matchup/index.html, docs/plan/ui/matchups.md): a way to...
- StatRanking: StatRanking (docs/plan/ui/rankings.md): every champion in a role ranked...
- LearnPage: The Learn page (docs/plan/ui/learn.md): one puzzle a screen
- DailyPage: Daily Draft's page (docs/plan/ui/daily.md, mock round 4): the board with...
- PatchPage: Patch changes (/patch; docs/plan/ui/patch.md): what Riot changed this...
- PoolPage: The pool page's own island (pool.html, docs/plan/ui/pool.md): the pool, up...
- PoolGrid: the pool page's sections, one per role in the pool (docs/plan/ui/pool.md...
- YourList: The Your games list (your.html, docs/plan/ui/your-games.md "Games"), under...
- YourViews: The Your games page's head (your.html, docs/plan/ui/your-games.md...
- YourTime: The Your games page's Over time view (your-games.md "Over time"): each...
- YourLookup: The Your games lookup (your.html#id=Name%23TAG): the status line above...
- YourFriends: The Your games page's Friends view (your-games.md "Friends"): who a...
- Forget: Remove my data (docs/legal/lia.md "Objection"): anyone, for any Riot ID...
- Apply: Apply to test the desktop app, at /download#apply: Riot ID, a contact, role...
- Squad: Squads (/squad, your-games.md "Squads"): friends who each joined by the...
- HomePage: The home page (index.html, docs/plan/ui/home.md): a game on the first...
- Account: The account pages (docs/plan/accounts.md): log in, make an account...
- TesterPage: The Draft tester page (docs/plan/ui/draft-tester.md, /private/tester)...
- TesterCand: The Draft tester's candidate panel (docs/plan/ui/draft-tester.md "First...
- ChampPage: The champion page (/champions/<slug>, /champions/<slug>/<role>): one...
- MatchPage: The matchup page (/matchups/<role>/<x>-vs-<y>): one lane pair from x's...
- Champions: Champions (champions.html, role/<slug>.html; docs/plan/ui/champions.md)...

**Admin and ops**
- LogView: the tail of one of the box's logs on an ops page
- StepTimeline: one deploy (a push to main) as a folding row
- Meionotes: meionotes: Jacob's notes on the live site, an island ui-meionotes.wasm...
- MeionotesList: /admin/meionotes, every note on the site grouped by page or by...
- Pv: the private numbers on public champion and matchup pages (app.md "Private...
- AdminPage: /admin/ (private) as one island
- AdminCharts: the admin page's chart tabs, Crawler and Riot API, an island of their...
- AdminTraffic: the admin page's Traffic tab, an island of its own below AdminCharts...
- AdminOps: the admin page's Deploys and Logs tabs, an island of its own below...
- AdminModels: the admin page's Models tab, an island of its own below AdminOps...
- AdminLab: the Models tab's Neural nets and Lab campaigns, an island of its own...
- AdminRuns: the Models tab's training runs, an island of its own below AdminLab...

### Button
`button.zig` `.c-btn` site
Button: the pressable shape. Primary is a view's one action, quiet sits in a band, icon is
square and named by its label; s fits a row or a chart head. With `href` it is a link that
looks like a button
States: primary; default; quiet; disabled; icon; link; small, in a row
Used by: champhead, matchbrief, signin, practice, runetree, buildpanel, lockbar, puzzle,
heatgrid, finder, learnpage, dailypage, dailydays, patchhead, poolpage, poolgrid,
yourpage, yourlookup, yourfriends, forget, apply, squad, idlookup, today, homepage,
account, testerpage, meionotes, meionoteslist, adminpage

### Chip
`chip.zig` `.c-chip` site
Chip: a small pill that toggles a filter (pressed or not), removes a choice, or opens the
rest of a list (expand). Scope and reason chips are labels, not controls: flat, no hover
(Badge's family)
States: toggle; pressed; disabled; removable; expand; link; scope; scope, hover tip at its
end; reason; reason, hover tip; a filter row
Used by: scopechip, card, matchbrief, champselect, practice, table, buildpanel, lockbar,
inspector, gamepage, candlist, patchpage, idlookup, admincharts, champpage, tiers

### ScopeChip
`scopechip.zig` `.c-scope` site
ScopeChip: what a block's numbers cover, in the subbar's words, "EUW · 30 days · Plat+",
as a scope Chip. A dimension the block doesn't follow is marked against the page's picks
("All regions, not EUW alone"). Server side only
States: follows the picks; every region on an EUW page; a patch, all regions, Emerald+
picked

### Badge
`badge.zig` `.c-badge` site
Badge: a flat label (role, result, "few games", a patch note). Never looks pressable: no
fill or border, no hover. A patch note (`riot`) is ringed in its tone, buff or nerf with
an arrow as the second cue. `turn` is the attention pill: a moment ("your turn", a swing)
or a caution about the thing it sits on
States: neutral; accent; us; them; few; patch note; patch buff; patch nerf; moment;
caution
Used by: modelbadge, matchbrief, champlist, draftboard, champselect, compview, appbar,
versus, inspector, gamehead, gamerow, scoreboard, puzzle, candlist, learnpage, dailypage,
dailyseat, dailydays, patchpage, homepage, pv, adminpage, adminlab, adminruns, champpage,
matchpage, tiers

### Segmented
`segmented.zig` `.c-seg` site
Segmented: one control for views, sorts and filters. A well darker than the card holding
filled segments; the chosen one is a solid tinted fill. s fits a row or a chart head, fill
splits a phone pane's width. Buttons with aria-pressed in a group: choosing one changes
what shows here, it doesn't switch tab panels (Tabs does). With `href` a segment is a link
to another page (a view's), the chosen one aria-current; with `on` too, an island takes
the link's click (the page without it still follows). In the app, `shell` is the message
bridge.js sends the shell on a click. `radios`: for static HTML with no island to switch
views (the app's champ select): radios whose checked one the page's CSS reads
(:has([value=..]:checked))
States: view; sort, disabled; small, in a chart head; fill, phone panes; links to views,
one greyed; radios, static HTML; counts
Used by: tabs, card, site, filterbar, practice, picks, app, table, lane, timeline,
buildpanel, scoreboard, matchgrid, ranking, poolgrid, yourviews, yourtime, homepage,
testerpage, testercand, meionotes, meionoteslist, adminpage, admincharts, admintraffic,
adminmodels, champpage, matchpage, tiers

### Tabs
`tabs.zig` `.c-tabs` site
Tabs: a card's or page's sections, on the panel's edge. Full-height items, the chosen one
carries an accent bar on the edge; inside a Card it runs edge to edge as a band. Links
(aria-current) when each tab is its own URL, else buttons with role tab. Anything after
the tabs (a Segmented, a count) sits at the band's end
States: counts; links, with a control at the end
Used by: card, site, yourviews, adminpage, champpage

### Card
`card.zig` `.c-card` `.c-head` `.c-toolbar` `.c-sechead` `.c-cards` site
Card, its bands and SectionHead. A card's head (title, count, its own controls), Tabs and
toolbar (the page's filters) run edge to edge as bands built into the card, not floating
above it. SectionHead titles a run of content outside a card
States: plain; head with a control; a row stretched taller: the chart grows into it; tabs
and toolbar bands; flush; SectionHead
Used by: strip, filterbar, champselect, table, lane, timeline, gamepage, puzzle,
matchgrid, finder, ranking, learnpage, dailypage, dailyseat, patchpage, poolpage,
poolgrid, yourtime, today, homepage, adminpage, admincharts, admintraffic, adminops,
adminmodels, adminlab, adminruns, champpage, matchpage, tiers

### Select
`select.zig` `.c-select` `.c-menu`
Select: a button showing its value and a chevron, Segmented's height, that opens a popover
menu of choices (popovertarget: opens and closes with no script). For more choices than a
Segmented holds (regions, patches). The island hides the menu after a choice (ev.after
.hide on the menu's ref)
States: closed: tap to open; with a label, small; open; open, 4 columns
Used by: modelbadge, filterbar, testerpage

### Toggletip
`toggletip.zig` `.c-tt` `.c-tip` site
Toggletip: a dotted term that opens a short note on tap (popovertarget: no script, one
open at a time, Escape and a tap outside close it). Sparingly: a term or an uncertainty
that needs a line, never words an unclear component couldn't carry. Placed under its term
by CSS anchor positioning where supported, else centred
States: closed: tap; a column head's term; open
Used by: strip, draftboard, compview, table, laneduel, puzzle, reasons, learnpage,
dailyseat, champpage

### Tip
`tip.zig` `.c-hint` `.c-hintb`
Tip: a short line about what it wraps (a range's ends, a full count, a place's name),
shown at once on hover, on keyboard focus and on a tap, so phones see it too (a title
never shows there). The line is in the page, after the wrapped content: screen readers
read it inline, with no attr() or id. A note with a heading, or long enough to want a tap
to open, is a Toggletip. The native title and attr(data-tip) are uilint debt that moves
here
States: closed: hover, focus or tap; open, above; open, end; open, below; open, wraps

### StatCell
`stat.zig` `.c-stat` site
StatCell: one figure, formatted by its kind through fmt.zig and coloured by how far it
sits from its scale's middle. An aggregate rate is a Rate (rate.zig): its colour, games,
hover and fade are the rate view's. Other kinds: ink stepped (fmt.Step), or fill for heat
cells; a range's ends on hover, faded when wide or thin, never hidden (J35). A missing
figure says so
States: rate: its games after it, ends and games on hover; rate, low; points; points, a
range (on hover); count; time; gold, one game; plain; few games: a wide range, faded;
missing; with context; a sorted column: the ink mixes, no steps; the same colour however
sure: 53.0, 52.6, 50.0 of 20,000, 54.0 of 400, 54.2 of 120, 65.0 of 40 (faded); fill, heat
cells
Used by: table, heatgrid, ranking, homepage, champpage, matchpage, tiers

### Rate
`rate.zig` `.c-rate` site
Rate: a win rate, the one way one is shown. Its colour is the rate itself on the site's
diverging scale (fmt.WrColour), read against 50 unless the caller names its own ref
(BuildPanel: the slot's rate over its options; a ranking: the stat's usual). How sure it
is: its games, small and faint after it in a fixed slot, so a column's figures stay
aligned; its 80% range's ends and the full count on hover, never a ± figure; faded
(var(--fade)) past fmt.wide_range, never hidden (J35); whole once the range is 10 or
wider, its tenths saying nothing. A model's estimate has none of these. Screen readers get
words ("win rate 52.3%, 33,108 games"): phones never read a title. `delta`: a difference
of rates in points, same colour and fade
States: counted: its games after it, ends and games on hover; low; few games: a wide
range, faded; very few: whole, faded; no unit, for a build table's narrow column; no
count: a column holds the games (still on hover); a model's estimate: no count, range or
fade; its own ref (BuildPanel: against the slot's 47.2%); no games; a sorted column: the
colour mixes, no steps; the same colour however sure: 53.0, 52.6, 50.0 of 20,000, 54.0 of
400, 54.2 of 120, 65 of 40 (faded); delta: +2.6, −1.4, +0.3; +4.8 with a wide range,
faded
Used by: stat, strip, matchbrief, buildpanel, lockbar, candlist, matchgrid, champpage,
matchpage

### Delta
`delta.zig` `.c-delta` `.c-dbar` site
Delta: a signed change in points, on the scale's colour with its sign (or an arrow) as the
second cue; faint when its 95% range spans zero (it could be luck) or the caller says it
may be (`faint`). DeltaBar draws it from a centre line with the range as a whisker; dot
for a forest of them
States: inline; arrow; spans 0; faint, may be luck; one game; bars, ±95%, one span; dots,
a forest
Used by: champlist, table, finder, ranking, patchpage, yourtime, yourfriends, today,
adminmodels, tiers

### Bar
`bar.zig` `.c-bar` `.c-track` site
Bar: a magnitude without good or bad (pick, ban, games), a neutral ink bar beside its
figure. Bars in one column share a scale: `of` is the column's largest. `wide`: the bar
alone across its container, where the row puts the figure elsewhere. `track`: a position
along a full-width line (a place among champions, a rate on 0-100), a mark at it and an
optional reference tick, no good or bad colour
States: share; games, the column's most; ban; wide: the bar alone, its figure elsewhere in
the row; track: a place, portrait at 1st, the middle ticked; track: the middle; track:
last; scale: the ends named once; track: a rate, a dot, the average ticked
Used by: strip, champlist, table, yourfriends, homepage, admincharts, champpage, tiers

### Kda
`kda.zig` `.c-kda` site
Kda: kills / deaths / assists in tabular figures, the slashes faint; optionally the ratio
under it. l is a game header's
States: plain; ratio; no deaths; a game's header
Used by: draftboard, teamrows, lobby, gamehead, gamerow, scoreboard, profilesum, squad

### StatStrip
`strip.zig` `.c-strip` site
StatStrip: a page's headline figures in one row, plain (no box per figure): a small label
over each value, the answer larger, a value on the scale's colour where it has one,
context after it small ("4th of 53"). A rate is a Rate: its count, range on hover and fade
are the rate view's. Three to a row in a narrow container. A label can open a Toggletip; a
figure can link to where it comes from, or be pressed (the game page's cells select their
span; the selected one shows pressed)
States: with an answer; six, one links; pressable, one pressed; rows: places on tracks,
the ends named once; grown by a taller card
Used by: champhead, matchbrief, gamehead, gamepage, matchgrid, playerbar, adminpage,
admincharts, admintraffic, champpage, matchpage

### WinSplit
`split.zig` `.c-split` site
WinSplit: a game's win chance as one bar, blue's share from the left in blue and red's the
rest, the figures at the ends in their side's colour. The 95% range is a whisker around
the split. l is a page's answer (draft tester, Daily's on paper): there the bar takes its
own row in a narrow container
States: plain; range; on paper, red won; the page's answer
Used by: dailyseat, testerpage

### AlertBand
`alertband.zig` `.c-alert`
AlertBand: a service's state in one line at the top of a page: ok, warn or down, a glyph
as the second cue beside the colour, the first problem as the text, "+n more" when there
are others, and a link to where it shows (a tab, a log)
States: ok; warn, more, link; down; long text
Used by: adminpage

### ActionButton
`actionbutton.zig` `.c-action`
ActionButton: a Button that runs something on the server (restart the crawler, build the
site). A confirm popover first when the action costs something (no script: the popover
API), busy while it runs, then a result line under it: ok or failed, when, and the output
folded in a <details>
States: idle, confirm first; idle, runs at once; busy; held by another; ok, output;
failed, long output
Used by: adminpage

### LogView
`logview.zig` `.c-log`
LogView: the tail of one of the box's logs on an ops page. A row of files, each with its
error and warning counts; a filter (case-insensitive, matches marked); "n of m lines";
Follow and Reload; then the lines in a box that opens at its bottom (column- reverse, no
script), error and warning lines coloured. The page fetches the text, counts with `level`
and keeps the filter
States: tail; filtered, following; no match; loading; could not load; empty
Used by: adminops

### StepTimeline
`steptimeline.zig` `.c-steps`
StepTimeline: one deploy (a push to main) as a folding row. Folded: its state, short sha,
subject, a strip of its steps as long as its time against the longest row's, and that
time. Open: while running, a bar of the time so far against the usual; then a waterfall,
one row per step in the order they ran on the deploy's time axis (glyph and colour for the
state, its bar from its start, its time), a running step's usual time as a ghost behind
its bar, a step's detail under its row; the commits it carried. The page derives the steps
from deploys.tsv and writes the times (UK clock) into `when`
States: running, past one step's usual; running, over the usual; failed; live, open; live,
folded; skipped, no subject; superseded; push refused
Used by: adminops

### Prose
`prose.zig` `.c-prose` site
Prose: a markdown doc (learned.md, model.md, the eval report) as nodes. parse() runs
server side and gives a Doc that data.zig encodes, so ui.wasm carries the view and no
parser. The subset the docs use: # headings, paragraphs, bullets (one nested level), pipe
tables, ``` fences, inline `code`, **bold** and [links](/path); anything else stays
literal text. The root carries data-prose: check.zig holds quoted docs to no label or word
budget
States: learned.md: bullets, nested, code, bold; eval report table; fenced code; model.md
folded, a section open from the hash; a section opened, its body loading; its body
arrived; an empty section open; the fetch failed; two docs, one page, each its own id
prefix; empty
Used by: textpage, adminmodels, adminlab

### TextPage
`textpage.zig` `.c-textpage` site
A page of running text: method, download, privacy, terms, the 404. Server side only, no
island; the body is a prose Doc parsed from the page's markdown. Its words are the site's
own policy and help text: held to no label or word budget, as Prose
States: terms: date line, bullets, links; 404: lead and links; title only; wide: tables
past the text's measure

### ModelBadge
`modelbadge.zig` `.c-model`
ModelBadge: which model a number comes from. Its name says what the model is; accent
Badges say where it is used (Daily, App), a plain one where and when it was made (Box 24
Oct, Lab 18 Oct). As a menu option it adds one facts line (games, patches, held-out
accuracy). Draft tester's model Select first; Daily's "the model's pick" note and the
app's About next (draft-tester.md)
States: used and from; lab only; as a Select; its menu
Used by: testerpage

### RoleIcon
`role.zig` `.c-role` site
RoleIcon: Riot's position icon as a CSS-masked span in currentColor, the lane solid and
the rest of the map faint. A mask, not `<svg><use>`: WebKit resets the page's scroll when
rows holding a sprite `use` move inside a container query (stack.md gotchas). Muted by
default, `on` for the role in force; named for screen readers unless the control around it
names it
States: muted, the one in force; 16, 20, 24; beside its name
Used by: champ, sitesearch, rolepicker, champsearch, champlist, draftboard, champselect,
teamrows, apphome, loadscreen, practice, picks, gamehead, gamerow, scoreboard, candlist,
champrolepicker, poolslots, matchgrid, finder, ranking, learnpage, dailypage, dailyseat,
dailydays, patchpage, poolpage, poolgrid, profilesum, yourpage, yourviews, yourtime,
yourfriends, squad, today, homepage, testerpage, testercand, pv, champpage, matchpage,
tiers

### ChampIcon
`champ.zig` `.c-champ` site
ChampIcon: a champion's square portrait, 20 to 48 px, with the states a seat or a row
needs: thin data faded, banned struck, dead greyed with a cross, an empty seat dashed, a
suggestion not yet yours (dashed accent ring), a side's ring, the player's own ring with a
dot on its corner (seen under a turn's outline), a level, and a role badge in the corner
States: 56, 48, 40, 32, 24, 20; role, sides, you and level; thin, banned, dead; empty
seat, a suggestion; beside its name
Used by: bar, sitesearch, champsearch, champhead, matchbrief, matchstrip, champlist,
draftboard, champselect, teamrows, compview, lobby, apphome, loadscreen, gamescreen,
postgame, practice, picks, dotplot, timeline, versus, gamestrip, inspector, gamehead,
gamerow, scoreboard, laneduel, choice, rankstrip, draftflow, candlist, poolslots,
heatgrid, matchgrid, finder, ranking, learnpage, dailypage, dailyseat, patchpage,
poolpage, poolgrid, resultstrip, playerbar, profilesum, recordtile, yourpage, yourtime,
yourfriends, squad, today, homepage, testerpage, testercand, champpage, matchpage, tiers

### SiteHeader
`site.zig` `.c-site` `.c-sitemenu` `.c-sitefoot` `.c-preview` `.c-subbar` `.c-sitemain`
`.c-sitenote` site
SiteHeader: every page's top bar: the logo, the page links, the search. Under 860 px of
header the links give way to a menu button whose popover lists them and the pages of each
section (groups), the current one selected (popovertarget: no script). The account slot
sits beside the search: Log in and Sign up, or once signed in a chip with the username
whose popover holds Your games, Account and Log out (the page's script fills and wires it:
site/shell.zig account_js). On a phone Sign up moves into the menu. From 861 to 1160 px,
with a login's private links in the bar, the search folds to its icon and opens over the
links on focus. Also every page's foot (`foot`), the preview strip under the header
(`preview`), on the Champions pages the bar under it (`subbar`: the section's tabs and the
view picks; `mainbar`: one an island draws with its own tabs), the page's main column
(`main_class`) and a one-line notice in it (`note`)
States: the bar: Log in and Sign up; a menu button under 860 px, Sign up then in the menu;
signed in: the account chip, named by the page's script; menu open, the current page
selected; the chip's menu open; the preview strip; the subbar: Champions tabs and the view
picks; they wrap under the tabs when narrow; the subbar, tabs only; an island's own
subbar, a control at its end; the main column, a notice in it; the foot
Used by: appbar, adminpage

### SiteSearch
`sitesearch.zig` `.c-sitesearch` site
SiteSearch: the header's search. Finds a champion (ChampSearch's matching), a matchup
("Ahri vs Zed", "ahri zed", "ahri/zed") or a Riot ID (Name#TAG, and the ones looked up on
this device); every option is a link. An ARIA combobox as ChampSearch: arrows move, Enter
takes the active option, Escape closes. Before the island runs, and before its index is in
for a Riot ID, the form is a plain lookup (GET /your?id=). Its file loads on the form's
first focus or pointerdown, or "/" (html.zig's inline script)
States: a champion; a matchup; every opponent; a Riot ID; the empty box: Riot IDs looked
up here; nothing found

### RolePicker
`rolepicker.zig` `.c-roles` site
RolePicker: the role a page shows, in Segmented's well: each role's icon with its share of
the champion's games under it, the chosen one filled. Links (aria-current) when each role
is its own URL (a link's click is always the browser's), else buttons (aria-pressed) whose
handler switches in place. "All" for lists across roles; a role with no games is shown but
not choosable. Compact: icons only, a row's height
States: a champion's roles, links; every role and All; compact
Used by: champhead, champrolepicker, matchgrid, finder, patchpage, poolpage, yourviews,
homepage, champpage, tiers

### FilterBar
`filterbar.zig` `.c-filters` `.c-find` site
FilterBar: the page's filters in one row, usually a Card's toolbar band. In a container
under 520 px one Filters button stands in for them, with the choices in force beside it
("EUW · Plat+"); it opens them under it (island state: `open`). The controls sit in one
wrapper, so hiding them never sets display on a Select's popover. Also the table's Find
box (`find`), which sits in the page's head beside them
States: in a toolbar band; one button when narrow; narrow, opened; Find, with text: its ×
Used by: patchpage, champpage, matchpage, tiers

### ChampSearch
`champsearch.zig` `.c-search` `.c-chosen` site
ChampSearch: a box that finds a champion as you type, the way the header search does
(SiteSearch): whole name or alias (mf, j4), a prefix of the name or one of its words, part
of it, then a typo (one, two from 7 letters); case and punctuation ignored. The list under
it is an ARIA combobox: arrows move, Enter takes, Escape closes then clears, focus leaving
the box closes it. Modes: link (each option is a link: the champion page's "matchup
with..."), pick (the choice stays as a chip with a clear button: the draft tester) and
filter (no list: a host reads `q`, e.g. a table)
States: empty; typed: prefixes, shortest first; a word of the name; a typo; nothing found;
pick mode: the chosen one
Used by: sitesearch, champhead, matchstrip, champrolepicker, finder, poolpage, testerpage,
champpage

### ChampHeader
`champhead.zig` `.c-champhead` site
ChampHeader: a champion page's first row: the portrait, the name as the page's h1 and a
line under it (role, patch), the role picker, the opponent search and the headline
figures. Wraps in its container: on a phone each part takes a row, the strip last. With
`pair` filled it heads the matchup page: both portraits, the swap between them (the other
side's page) and ⊗ on the opponent back to the champion page (lolalytics' VS slot: the
two pages are one with the slot empty or filled). A champion's P Q W E R icons sit under
its name, each keyed by its letter
States: a champion page's head; name only; with its abilities; a matchup page's head: the
opponent's slot filled
Used by: champpage, matchpage

### MatchupBrief
`matchbrief.zig` `.c-mpick` site
MatchupBrief: under the champion page's matchup chart, the chosen opponent (or ally) in
brief: portrait, name, relation, the figures, a button into the matchup page; beside it
the most met as chips to jump between (Jacob v9: one tap shows the brief, an obvious way
into the matchup). The page's island owns the choice: chips carry its handlers, as
DotPlot's dots do
States: an opponent chosen, the most met beside; few games, no chips
Used by: matchgrid, champpage

### MatchupStrip
`matchstrip.zig` `.c-mstrip` site
MatchupStrip: a champion's lane opponents in one row that scrolls sideways, most games
first (op.gg's order, not by win rate): each a link with the portrait and the champion's
win rate against it, coloured on the scale; the page's opponent lit. The search at the end
hides the others (ChampSearch's filter mode, same matching). matchup.md "MatchupGrid
strip"
States: the page's opponent lit, a thin one faded; searched; nothing found
Used by: matchpage

### ChampList
`champlist.zig` `.c-clist` site
ChampList: a short list of champions, one line each: portrait, name (a badge after it),
the figure the list is ordered by, a faint note last (share, games). A row can link to the
champion's page. Two columns in a wide card (`cols`). A pair (`vs`): a duel, the portraits
at both ends, the names over the lane's bar (the first's win rate a tick against the
middle's, the bar solid to its 95% range's low end and fading to the high one, a ring
where a patch move started) or a Bar of a figure that isn't a win rate (`fill`), the
figure and its note last. `tiles`: one tile per champion filling the card's width, the
portrait large, the figure under the name, the note small under it
States: mains also play: links, a badge; tiles: the share, how much more often, a harder
mark; two columns; matchups: duels, the lane's bar and range; a role; where a move
started; duels with a Bar: a gold lead, the list's biggest full; with roles, no links
Used by: finder, champpage, matchpage

### DraftBoard
`draftboard.zig` `.c-draft` site
DraftBoard: a draft as lane rows, our seat on the left, theirs mirrored on the right, the
role between; both teams' bans under. A seat: portrait, name, a line for its state
(hovering, picking) and an optional short fact coloured by its lean; an ally still to pick
can carry ideas for the role; an enemy's guessed role is dashed with a grip (the app's
seats swap roles by drag). The desktop's champ select first, then the draft tester and
Daily Draft (draft-tester.md). Champions and roles only: no player names or ranks (product
rules). The full variant (Daily, the tester): 48 px seats with their pick number, the
hidden seat asked about, a chosen answer previewed dashed, seats selectable, the game's
line grown under each name after a reveal, each lane's middle its win chance from the
matchup and who led it at 14, and each side's damage mix. Learn's `question`: the full
variant with none of the game's parts
States: mid draft; planning, nothing shown; full: hidden pick asked; full: an answer
chosen; full: after the reveal, a seat selected; full: after the reveal, seats as buttons
Used by: champselect, learnpage, dailypage, dailyseat, dailydays, testerpage

### ChampSelect
`champselect.zig` `.c-cs`
ChampSelect: the desktop app's champ select screen. The board (DraftBoard) beside the lane
panel: you against your lane opponent, a sentence on the matchup, then options from your
pool, each with its lane fact and reasons as chips; ban options under while bans are open.
The shell writes every word for its edition (src/shell/screens.zig): the public one gets
no win chances (`win` and `draft` stay null, product rules). The options list is the seed
of CandidateList (draft-tester.md)
States: counter, public; counter, private; an ally's lane; an enemy's lane; an enemy's
lane, ours empty; your ban, blind
Used by: app

### TeamRows
`teamrows.zig` `.c-rows`
TeamRows: a game's five lanes as mirrored rows, our player left, theirs right, the role
and the lane's gold gap between. A seat: portrait (greyed while dead), name, the KDA and a
line of figures, the respawn while dead. The app's in-game panel and post game screen
(src/shell/screens.zig). Champions only: no player names (product rules)
States: in game, one dead; a seat unknown
Used by: compview, gamescreen, postgame

### CompView
`compview.zig` `.c-comp`
CompView: the desktop app's comp view once all ten champions are locked (docs/plan/ app.md
APP6), under the board. Each team's damage split as a bar, a tag when teams this one-sided
win less often, its champions with a clear early or late lean; win chance by game length
as a TrendChart; then the five lanes as TeamRows. Static HTML in the shell, so the chart
has no hover tip. Champion facts only, never players. The public edition gets words: every
number here is null there (src/shell/screens.zig, docs/production-key.md)
States: all locked, public; all locked, private; private, length tilts but not sure: the
band says so; a split unknown
Used by: app

### LobbyForm
`lobby.zig` `.c-lobby`
LobbyForm: the desktop app's panel before champ select (home, lobby, queue, match found;
docs/plan/ui/app-phases.md): your last games as a win/loss strip with the record and
average KDA, a line on the run you are on, the champions going well lately, then your
mastery top. The player's own games only, from the League client; static HTML under the
island (src/shell/lobby.zig builds it)
States: ten games, best and mastery; mastery only (no games yet)
Used by: app

### AppHome
`apphome.zig` `.c-apphome`
AppHome: the desktop app's tiles before champ select (docs/plan/ui/app-whole.md slice 4),
each a TodayCard into one of the site's features with a line of data from the app's own
stats: your mastery top's best role now (Champion pool), each role's best now (Rankings);
then Patch changes and the Draft tester (private edition). Static HTML beside the lobby's
form panel (src/shell/home.zig builds it)
States: private, mastery top; public, no mastery yet
Used by: app

### GameBuild
`gamebuild.zig` `.c-gamebuild`
GameBuild: the desktop app's in-game panel under the island (private edition): my
champion-role's usual boots and core items with those I own ticked and the next one
marked, the ability for my next point and the usual max order, then the usual levelling
path as a skill grid, a tip or two from the comp, and the power spike sheet: level 6,
first item and the stronger half of the game against my lane opponent, in a <details> only
the player opens (never pushed: docs/plan/app.md "Policy line"). Static HTML
(src/shell/screens.zig builds it from ingame.InGame): a buy or a level reloads the page,
and the shell's bridge.js keeps the sheet as the player left it
States: two items owned, a point to spend; core done, next level's ability; no levelling
path known; no usual build: a tip, leans only

### LoadScreen
`loadscreen.zig` `.c-load`
LoadScreen: the desktop app while the game loads. Our five cards over theirs, one fixed
order per card: portrait, name, role (? when guessed), how the champion does in the role
(private edition only), then pills coloured by meaning. Narrow windows get one compact row
per seat. Champion facts only: no player names or ranks
(research/questions/desktop-app-layout.md C1-C3)
States: public; private

### GameScreen
`gamescreen.zig` `.c-game`
GameScreen: the desktop app's in-game panel, private edition only (the public one gets a
note). The score and both teams' item gold, the five lanes (TeamRows), your lane against
the matchup's games at this minute with its gold chart, objective respawns, and the team
gold through the game. Only what the scoreboard shows anyway: a panel to look at, never an
alert (docs/plan/app.md "In-game companion"). Wide: lanes left, your lane right; narrow:
one column, your lane after the score
States: minute 14; early, no opponent; no lane
Used by: app

### PostGame
`postgame.zig` `.c-post`
PostGame: the desktop app after a game, static HTML after the island (nothing to tap). The
verdict and kills over award cards (a champion's best figures, one card each); then both
teams lane by lane (TeamRows) beside damage to champions, each team with its total. Facts,
no advice, no sentences (research/questions/desktop-app-layout.md C20)
States: victory; defeat; result coming

### SignIn
`signin.zig` `.c-signin`
SignIn: the app's sign-in to meio.lol (the poller's device.zig does the request). The form
is the screen on a first start with no data yet, else a line under it that opens the form.
Both editions. What's typed stays in Form until sent; the password input is a new node
after each try, so the DOM keeps no password either
States: line under the content; first start, no data; signing in; refused
Used by: app

### Practice
`practice.zig` `.c-practice`
Practice (private edition): a champ select set up by hand in the app (role, pick place,
stage, screen, a random draft) and a champion picker for any seat or ban. Its own island
and file (ui-practice.wasm), loaded only while practice is on: the shell renders it above
the app's page and keeps its Data at practice.bin. The poller builds what the app's page
shows from the setup (src/practice.zig). The board is ui-app.wasm's: while practice shows,
the shell writes an Act on each seat, lane option, ally idea and ban option as data-act,
and ui-practice.wasm takes the clicks. A seat opens the picker, a lane option hovers it as
my pick (a second click locks it), an idea fills its ally's seat, a ban option is my ban
States: champ select; in game; waiting for the client; picker for mid

### Picks
`picks.zig` `.c-picks`
Picks: the app's Options panel in champ select (docs/plan/ui/app-options.md), its own
island (ui-picks.wasm, picks.bin): ui-app.wasm has no room. The champions played in the
lane panel's role as a CandidateList, each with its effects (the role, an ally pair, an
enemy matchup) as the other champion's icon and its points, a click opens the
ReasonBreakdown. The private edition: 20 rows with numbers; the public one: 5 more past
the lane panel's own, words mode (product rules: 3 to 5, no numbers). The shell renders it
after the app's island and keeps its Data at picks.bin (src/shell/screens.zig)
States: private, one open; public, words
Used by: app

### App
`app.zig` `.c-app` `.c-page` `.c-live`
The desktop app's page as one island (ui-app.wasm). The shell (src/shell/screens.zig)
renders it from the poller's state and keeps the same Data encoded (data.zig) at app.bin;
on a change it sends `{"app": seq}` and the island fetches the file and patches. A screen
per client state: a note while there is nothing to show, champ select's board and options,
the in-game panel; the sign-in under it, or in its place before there is data. The loading
screen and the post game have nothing to tap, so the shell renders them as static HTML
after the island (ui/loadscreen.zig, ui/postgame.zig). The charts' own state (a tapped
minute, a dragged range) and what's typed live in App, past patches
States: waiting; champ select, private; all locked, comp under; all locked, comp under,
private; lobby, form and tiles; in game; first start, sign in; first start, downloading;
first start, download failed; League closed; waiting, sign in and restart lines; waiting,
update address gone

### AppBar
`appbar.zig` `.c-appbar` `.c-appset`
AppBar: the desktop app's top bar, the site's header (site.zig) with the app's links: the
live screen first, named for the phase, then the site's pages (on meio.lol, opened in the
app's window), Practice (private edition) and the settings popover. Static HTML before the
app's island (no ui-app.wasm bytes): the shell renders it with the page and reloads the
page when it changes. Clicks that ask the shell for something carry their message as JSON
in data-shell, which bridge.js sends
States: public, lobby; private, champ select, practice off; settings open, signed out

### DataTable
`table.zig` `.c-table-wrap` `.c-table` site
DataTable: a real table where the data is a table, as an island. A page declares its
columns once (cell, sort value, priority, the one answer column) and the compiler checks
the guardrails; the same struct renders on the server (the default state) and in ui.wasm
(sorted, searched, cut by a minimum, a row's detail open), so server and client order
can't disagree. Rendered as a flush Card: a head band with the title, the count shown,
search and MinGames, then the table. Columns of priority 2 and 3 give way in narrow
containers (420 and 560 px). A column head can open a note (its label is then a Toggletip
term; the rest of the head and a small arrow button sort). A cell can open a line on its
row (one shared popover); in a narrow container `pick` columns show one at a time, chosen
in a "Show" band; rare rows (off-role picks) wait behind a "+N" chip const Opp =
ui.table.DataTable(Row, .{ .title = plain("Lane opponents"), .columns = &.{ .{ .label =
plain("Champion"), .cell = who, .name = name, .num = false }, .{ .label = plain("Win
rate"), .cell = rate, .sort = wr, .answer = true }, }, .search = name, .games = games,
.min_games = &.{ 0, 300, 1000 }, });
States: default: win rate, wide ranges faded; by games, fewest first; searched; min 300
games, a row open; numbered, off-role behind a chip, Show band when narrow; off-role
shown, Games picked
Used by: buildpanel, ranking, patchpage, yourtime, yourfriends, matchpage, tiers

### Chart
`chart.zig` `.c-chart` site
The one chart system (docs/plan/ui/README.md "Charts: one system"). A chart is HTML around
one SVG that draws only lines and fills, in a 100 x 100 viewBox stretched over the plot
(preserveAspectRatio none, strokes non-scaling): the server's markup fits any width and
nothing is measured. Text, dots, icons and controls are HTML placed by percent over it, so
they never stretch. Here: scales, the frame, marks (line, area split at a base, band,
bars, dots) and the parts presets share (ChartTip, the crosshair, RangeSelect and its
pointer handling). Presets: timeline.zig, lane.zig, trend.zig, spark.zig, dotplot.zig
States: area split at 50%, a line; band, typical and your line; tip, cursor, range; dots,
bars, a reference, an end label
Used by: trend, timechart, aucchart, lane, timeline, spark, laneduel, gametrend, yourtime,
adminruns

### DotPlot
`dotplot.zig` `.c-dots` site
DotPlot: one axis centred on a reference (the champion's own rate in the role, 0 for vs
usual and gold), each dot a champion's icon in its bin, a bin's icons stacked so height is
only a count, the most played nearest the axis (champion.md, Jacob v7: matchups option C).
The centre line carries no label; "harder" and "easier" sit at the ends. Pure CSS layout:
bins are grid columns, icons wrap upward, their size follows the container, so nothing is
measured. A tap or ← → chooses a dot; the page shows its figures (`chosen`). A mouse
hover shows name, rate and games (Jacob v9: no more)
States: win rate against, the most met chosen; a hard one chosen; few dots
Used by: matchgrid, champpage

### TrendChart
`trend.zig` `.c-trend` site
TrendChart: a win rate over a few ordered points (patches, game length buckets, mastery
bands), a line with its ±95% band, each point a dot coloured on the scale against a
reference (dashed), the point's name under it with a second line (rank in role, games),
the last figure at the end. No per-point text: a tap or hover shows a point's numbers
(ChartTip). A base line, faint dashed, compares each point with a wider group (the matchup
page's all lanes) and takes the reference's place. OutcomeCurve (Pick-up) is the same
preset over mastery bands
States: by patch, rank in role under each; by game length, games under each; a point
tapped; against a base, faint dashed (all lanes); OutcomeCurve: by mastery, against his
own rate
Used by: card, compview, champpage, matchpage

### TimeChart
`timechart.zig` `.c-time`
TimeChart: ops series over clock time (matches stored per hour, requests per minute, queue
depth) on chart.zig's frame. Several series as lines, stacked areas or stacked bars, one
bucket each from `start`; a null breaks a line. Each series named at its end, not in a
legend; reference levels dashed with their name; events (crawler restarts) as thin marks.
Hover or tap shows the bucket's figures (ChartTip), a drag zooms to its buckets, "Show
all" goes back. By keyboard the plot is a slider: arrows step the tip, + zooms round it, -
shows all; a hidden summary states what it draws
States: lines by region, a restart, NA's gaps; stacked area, a bucket tipped; stacked
bars, zoomed, against a limit; one series fitted to its range, 6-hourly; nothing recorded
Used by: adminpage, admincharts, admintraffic, adminops, adminmodels

### Histogram
`histogram.zig` `.c-hist` site
Histogram: how players' win rates on a champion spread (10+ games each), bars per bin with
the middle half shaded, a marker at 50% and, on Your games, one at your own rate. The
caption ("388 players, middle half 46-63%") is the card head's; the luck sentence its
Toggletip. Plain HTML bars placed by percent, nothing measured
States: players on a champion, the middle half shaded; your rate marked, short
Used by: champpage

### AucChart
`aucchart.zig` `.c-auc` site
AucChart: the method page's "Model accuracy vs data", AUC on held-out games for a few
models, one point per daily eval run (src/site/evalchart.zig reads them). A key names the
lines by their dash; the model in use carries its latest figure at the end. The y axis
keeps 0.5 (a coin flip) in view: how close to it draft prediction still is
States: six runs, three models

### LaneChart
`lane.zig` `.c-lane` site
LaneChart: you minus your lane opponent by minute (gold, XP or CS), against the typical
middle half as a band and its median dashed; a previous patch's median fainter. Each side
gets its own top, so a one-sided lane uses the room. A Gold | XP | CS switch for the chart
head, a tap shows the minute's figures (ChartTip), a drag selects minutes (the matchup
page's Versus reads `range`). lanechart.zig's successor: the matchup pages and Your games
move here when they are rebuilt
States: gold, a minute tapped; CS, minutes dragged; typical only (the matchup page); marks
(the matchup page)
Used by: champselect, gamescreen, app, laneduel, champpage, matchpage

### TimelineChart
`timeline.zig` `.c-tl` site
TimelineChart: a game by minute, win chance (or your team's gold lead) as an area split at
even, with what happened kept off the line (game-detail.md): FightStrip above the plot (a
mark per moment, coloured by who came out ahead; objectives off its line, yours above),
EdgeMarks (deaths as portraits on the plot's edges, the enemy's on top, yours under, one
stack a minute) and TurnBand (the turning minute). Drag selects a range (RangeSelect), a
tap near a moment or a mark picks it, ← → step through the moments, Escape clears. The
page's inspector reads `range` and `cur`; both live in the URL. Under 480 px of container:
epic objectives only, deaths as ticks
States: the turning moment picked; gold, a range dragged, the tip; compact, a big fight
picked
Used by: inspector, gamepage, homepage

### PatchSpark
`spark.zig` `.c-spark` site
PatchSpark: a win rate over the last few patches in a fixed-size cell (a table's trend
column), the end dot coloured by the change. With `y`, `mid` and `star` it is the
TimelineSpark of a Your games row: the win chance, the even line and the turning minute.
Built as the chart system: lines in a stretched SVG, the dot and the star HTML placed by
percent; the figures are the row's, so the label is optional
States: patches: flat, up, down (the change's colour); a game's win chance, even and the
turning minute
Used by: gamerow, yourtime

### GameArt
`art.zig` `.c-art` site
GameArt: an item, rune, rune tree, stat shard or summoner spell icon. Items and spells are
rounded squares, runes and shards round; dim greys an option not taken (a rune page's
other runes). The name is its alt unless written beside it
States: item 36, 28, 22, 20, 16; rune, tree, spell; dim, no icon
Used by: champhead, gamebuild, picks, itempath, runetree, buildpanel, lockbar, gamehead,
gamerow, scoreboard, itemrow, gamepage, patchpage, champpage

### SkillGrid
`skillgrid.zig` `.c-skills` site
SkillGrid: a skill order as the 4 x 18 grid of levels (Q, W, E, R rows, the level's number
lit in the row of the ability taken), with the order's pick share, win rate and games
under it. All 18 levels at any width: cells shrink to 13 px, never cut to 8
States: most played order; few games: a wide range, faded; one game's order; game ended
before 18
Used by: gamebuild, buildpanel, gamepage

### ItemPath
`itempath.zig` `.c-path` site
ItemPath: the first finished items in the order bought, as icons with arrows, then the
median minute of each. In a list of paths, items a path shares with the most played one in
the same place are dimmed, so the eye goes to where it branches
States: most played, minutes; a branch: shared items dim; no minutes
Used by: buildpanel

### RuneTree
`runetree.zig` `.c-runes` site
RuneTree: every rune players took, laid out as in game (trees side by side, keystones on
top, then the stat shards), each with its pick share (bar and %), win rate and games; the
figures' names said once. Win rates are coloured against their row's (a row is one
choice), each with its range, faded when wide (bp.win). The top rune pages sit above as
cards; the chosen one lights its runes. In a narrow container the trees fold to the chosen
page's (Every tree opens the rest). A page whose keystone the host has builds for (locks)
locks on tap, and the host shows the rest of the build for that keystone; a second tap
unlocks. With the champion page's lock set (`set`) a page card locks its keystone and a
rune tap locks the rune (shard) too. Tap a rune: its name and figures in the readout line.
On a matchup's, ▲▼ after a share the matchup moved from the champion's usual. An
island part: a host embeds it and re-renders on its events
States: first page lit; folds to its trees when narrow; second page chosen, a rune tapped;
no page chosen: every tree; a matchup's: keystones moved from the usual, one tapped
Used by: buildpanel

### BuildPanel
`buildpanel.zig` `.c-build` site
BuildPanel: the champion's whole build in one panel, as an island. RuneTree on the left,
the level path's SkillGrid under it; on the right the slot cells (Spells, Start, Boots /
Core / Item 4, 5, 6 / Max order) in a 3-column grid, pairs in a narrow container. Each
cell lists its top 3 options as compact DataTable rows, most played first: pick share, win
rate coloured against the slot's own (which choice is better here, Jacob 25 Oct), games;
the quieter reading (the rate minus the champion's) only in an open cell. The slot's
highest win rate on solid_games is marked "best", a 4th row when not in the top 3. Most
picked | Highest WR (lolalytics' build toggle, Jacob 26 Oct) re-sorts every cell by win
rate, options under solid_games after. A matchup's marks the champion's usual choice "as
usual" and dims a cell led by it. Tap a cell's "N more" to open it across the panel: every
option, named, sortable. One open at a time; it and the order in the URL. Each cell's head
names its columns over fixed widths, so they line up (one legend for the panel read as a
toggle, Jacob 27 Oct). A rune page card whose keystone has its own build (Data.keystones)
locks on tap: every cell then counts that keystone's players, a chip with × says so and
unlocks, the keystone in the URL (`k`). With a lock set (the champion page's,
ui/lockbar.zig) every option and rune page locks on tap instead: the host fetches the
build under the set and shows it here
States: Darius top: whole build, most played first; Item 4 open: every option, named,
sortable; Skills open: every order and level path; runes by lane opponent (none vs ranged
here), items 500+ gold ahead (none behind); Conqueror's page locked: its players' spells
and boots, the chip unlocks; champion page: every option and page locks on tap (lock glyph
on hover), Conqueror locked; a matchup's: spells and skills as usual (dimmed), boots'
usual second
Used by: skillgrid, runetree, champpage

### LockBar
`lockbar.zig` `.c-lockbar` site
LockBar: the champion page's locks (docs/plan/ui/champion-locks.md), one Chip with × per
lock, then the games under all of them with their win rate and range, then Clear. Hidden
with no lock. The lock set (`Set`) is the `lk` query as text: per kind its code and the
values dot-joined, as lockanswer.Locks.format writes them (kinds in one order, so one lock
set is one URL and one cached answer); no number is parsed
States: Conqueror and a core path locked: 1,284 games under both; thin: the range is wide,
so the rate fades
Used by: runetree, buildpanel, champpage

### Versus
`versus.zig` `.c-vs` site
Versus: your team against theirs, one figure at a time. `split`: per item the two counts
and a bar split by share, yours left in --us and theirs right in --them; the side that got
it first carries a "1st" mark with its time on hover and for screen readers
(game-detail.md "Objectives and firsts"). `race`: when you and your opponent got
somewhere, the typical time a tick, the gap to typical a signed figure (later is worse).
`band`: one figure on a track, the typical middle half shaded and its median a tick
(game-detail.md "Lane"); `cell` the same at a list row's size, the figure under the track
and the label only for screen readers (GameRow's lane at 14). `rows`: one side against the
other, a row per figure: both rates as dots on one 0-100% track, each number beside its
dot, the larger bold; a timing as both times and the gap (matchup.md "Versus"); `bars`:
the same rows, each side's rate its own bar on a 0-100 track, so the share with neither
shows (champion.md "Lane kills"); `key` names the sides, for the card head. `dumbbell`: a
row per item, two rates on a shared axis as dots, the line between them the gap, the gap a
figure (pool.md "How hard to pick up": new against practised players)
States: objectives and firsts; two; plain ink: rates, not sides; races: level 6 later than
typical, first item earlier; key: the sides' names; rows: a matchup's head to head; bars:
lane kills, each rate on its own 0-100 track; dumbbell: new against practised players, a
gap each; a thin row; bands: below typical, above, no typical; cells: below typical,
above, no typical
Used by: gamerow, laneduel, gamepage, champpage, matchpage

### ObjectiveIcon
`objicon.zig` `.c-obj` site
ObjectiveIcon: a tower, inhibitor or epic monster as a small glyph (a CSS mask, like
RoleIcon), in the taking team's colour. Named for screen readers unless the row around it
says what it is
States: each kind; by side, sizes
Used by: versus, inspector, scoreboard, gamepage, champpage

### Minimap
`minimap.zig` `.c-map` site
Minimap: Summoner's Rift as a square, lanes and river drawn faintly, with where kills
happened: an enemy down as a dot in --us, one of yours as a cross in --them, yours ringed.
s is a moment row's 16 px dot (no lanes); l the moment card's map
States: a fight mid, you died in it; red side, no kills; side unknown; a moment row's dot
Used by: inspector

### GameStrip
`gamestrip.zig` `.c-gstrip` site
GameStrip: your games as one scrolling row of small cards (champion, duration, a bottom
edge in --us for a win and --them for a loss), the open one raised; "All games" first.
Each card is a button the page binds to its game
States: the open game first; no list link
Used by: gamepage

### RangeInspector
`inspector.zig` `.c-insp` site
RangeInspector: what the game graph's selection holds (game-detail.md). The picked moment,
else the dragged range, else the whole game: where the kills were, win chance and gold
lead before → after, kills and objectives, each seat's part (FightTable); then the
range's moments as rows (MomentList: who died either side of the score), filtered by
chips. Shares the page's Timeline, so a row pressed here is the graph's moment too
States: the turning minute; a moment picked in 25-33; the whole game; your deaths, none in
the range
Used by: gamepage

### GameHeader
`gamehead.zig` `.c-ghead` site
GameHeader: one game at a glance, no sentence (game-detail.md "First screen"). Who: your
champion with its level, "vs" your lane opponent. Result and score: WIN or LOSS, K/D/A
large, KDA and kill share under it. How: CS, gold, damage and lane gold at 14 and vision
as figures, then your final items, spells and runes; the game's meta beside the names; the
two teams as icon rows, you ringed
States: a win; a loss
Used by: gamepage, homepage

### GameRow
`gamerow.zig` `.c-grow` site
GameRow: one of your games in the Your games list (your-games.md "Games"), tinted by
result. Your champion with its level, "vs" your lane opponent; K/D/A and the meta line
(matchup, role, queue, length, how long ago); final items; CS; lane gold at 14 against the
typical middle half; the win chance with the turn starred. Slots a game lacks (older
history has no timeline) stay empty at the same width. The whole row links to the game
when it has a page. Two lines in a narrow list
States: a win, new; a loss; a remake; no timeline: no items, CS or win chance; lane
without a typical
Used by: yourpage, yourviews, yourfriends, squad

### Scoreboard
`scoreboard.zig` `.c-board` site
Scoreboard: a game's players as five lane rows, your team left and theirs right facing
each other, so each row compares a lane (game-detail.md "Players"). A seat: portrait with
level, name over Riot ID, K/D/A over KDA, CS over per minute, items, then a bar growing
towards the middle (damage to champions, taken or gold: the switch is the card head's).
Between them the role and that lane's gold lead at 14. A team band on top: result, K/D/A,
gold, objectives. Narrow: names and CS go, items move under the seat. Under a lookup
another named seat links to the game from there
States: damage, a win; gold, a loss, named seats linked
Used by: gamepage

### LaneDuel
`laneduel.zig` `.c-duel` `.c-duelwho` `.c-dueltyp` site
LaneDuel: your lane against your opponent's (game-detail.md "Lane"). LaneChart of you
minus them by minute over the matchup's typical band; your biggest fall and rise against
typical as brackets under the time axis, pressed to select those minutes on the game
graph. Beside it the races to level 6 and the first item, gold lead at 14 and CS lead at
10 on typical bands, your CS at 10 and kills and deaths before 14. Under 200 typical games
the band and its chip are dashed: that is the whole "few games" message
States: first game; second game
Used by: gamepage

### ItemRow
`itemrow.zig` `.c-itemrow` site
ItemRow: one player's purchases by shop visit, each visit its items over the minute,
arrows between (dpm.lol and deeplol builds; game-detail.md "Build"). Wraps
States: three backs
Used by: gamepage

### GamePage
`gamepage.zig` `.c-gpage` site
GamePage: the game page's first screen as one island (game-detail.md): GameStrip,
GameHeader, the game graph with its control row beside RangeInspector, the stat cells and
the objectives row. A game picked in the strip is prepared once (its moments and graph)
and kept. Opens on the turning minute; the URL keeps the game and the selection
States: a win, on its turn; the whole game's moments
Used by: homepage

### GuessSlider
`guess.zig` `.c-guess` site
GuessSlider: a guess on a number line. No value until touched (a dashed track and a
pulsing ring where the fill starts say to drag), so the owner's Lock in stays off until
the first move; a press or drag, arrows, Page keys, Home and End set it, Enter commits.
Once revealed the real value joins it as a second marker with the gap between, and it
takes no input. The owner keeps a Guess and forwards its events (`event`), as chart.Press.
`row`: the asked row of PuzzleCard's RateRows, on the rows' axis: the fill grows from
`from` and the figures sit in the row's value cell, not over the marks
States: untouched; moved; revealed, 3.3 off; revealed, guess at the end; gold; gold, guess
at the top; row: untouched; row: moved
Used by: puzzle, learnpage

### PuzzleCard
`puzzle.zig` `.c-puzzle` `.c-rates` `.c-stars` `.c-take` site
PuzzleCard: one puzzle a screen. The setup as a picture on a stage band across the card's
top (RateRows, champion icons, tiles), one short question, the answer (a GuessSlider in
the stage, or ChoiceCards under the question), then in place the closeness Badge and
stars, one line why and the takeaway; the foot holds the games (a Toggletip with the
source) and the one action, Lock in or Next. RateRows: a few win rates as rows on one axis
centred on 50%, each a bar from the middle to its rate in the rate's colour; the asked row
is the GuessSlider itself (row variant), so the setup, the guess and the answer share one
axis
States: guess in the stage: untouched; moved; revealed: all bands, the asked one lit;
guess under the question (gold); stars; takeaway
Used by: learnpage, dailypage

### ChoiceCards
`choice.zig` `.c-choices` `.c-choice` site
ChoiceCards: a puzzle's 2 to 6 answers as cards, each with its key number (the page binds
keys 1-6 and Enter); a champion card is a row like a DraftBoard seat. Choosing marks a
card (the others dim) and the page commits with its own button; once done, the cards stop
being buttons and the answer is marked right, a wrong choice wrong. Champion cards (icon,
name) or side cards (label in the side's colour, the side's five icons): Daily's pick and
"Who won?", Learn's drills. Phone: six champions fit one row of icons, names kept for
readers
States: six champions; one chosen, not locked in; done: chose wrong; three, done: one per
row when narrow; who won: sides; three, text: labels wrap, never cut; four, text
Used by: learnpage, dailypage

### RankStrip
`rankstrip.zig` `.c-rank`
RankStrip: every champion one seat could have played as a dot on one axis, its team's win
chance with it; the played (or locked) one ringed, the model's pick starred, the chosen
one lit. A tap chooses a dot (the owner opens it in its CandidateList). The ends carry the
lowest and highest chance, nothing else: the list beside it names them. Daily's seat
panel, the draft tester's candidate panel
States: seat, read only; one chosen
Used by: testercand

### DraftFlow
`draftflow.zig` `.c-flow` site
DraftFlow: a draft's 20 turns in order, as the four phases (6 bans, 6 picks, 4 bans, 4
picks), each turn its champion with its side's bar under it, picks numbered 1-10. The open
turn (the puzzle's) pulses, or shows a chosen answer dashed. Sits at the foot of Daily's
DraftBoard: the board says who faces whom, this says when
States: last pick open; an answer chosen; whole draft
Used by: dailypage

### ReasonBreakdown
`reasons.zig` `.c-wf` site
ReasonBreakdown: why one pick lands where it does, as a waterfall from the role's average:
one cumulative step per term (strength, into X, with Y, rest), its points and games, then
the total with its 95% range. Opens under a CandidateList row (Daily's seat panel, the
draft tester, the desktop's "why"). Words mode (the public app, no numbers: production-key
product rules; docs/plan/ui/why.md) keeps the terms as words with a direction only
States: points, range, rest; below the average, no range; words, public app
Used by: picks, candlist, dailyseat, testerpage, testercand

### CandidateList
`candlist.zig` `.c-cand` site
CandidateList: ranked champions for one seat, the core of "select an option to see why". A
row: rank, icon, name, the model's star, the played (or locked) one marked, the team's win
chance with it and the gap to the reference row, up to three reason chips; pressing a row
opens its ReasonBreakdown under it (the owner keeps which, two at most). Chips sit under
the name in a narrow panel (Daily's seat panel), inline in a wide one (draft tester), a
Pick button after them when the owner fills the seat from the list. Words mode (the public
app: product rules, why.md): no numbers, reasons as words with a direction
States: seat panel, played row open; tester: Gold column, one row without, lane line;
tester: a second model's column, then Gold; average pinned, played far down, a mark by a
name, Pick; words, public app
Used by: picks, dailyseat, poolgrid, testercand

### ChampRolePicker
`champrolepicker.zig` `.c-crp` `.c-crp-pair` site
ChampRolePicker: a champion and the role it plays. ChampSearch in pick mode, then the five
roles as a compact RolePicker once a champion is taken, its main role (the entry's first)
preselected and roles it has no games in disabled. The host reads `pick` when `on_pick`
fires (a champion taken, a role changed or the champion cleared). `Pair`: two of them with
a swap between (the matchup finder)
States: empty; taken: its main role chosen, roles without games off; another of its roles;
pair, empty; pair: a matchup
Used by: finder

### PoolSlots
`poolslots.zig` `.c-slots` site
PoolSlots: a player's champion pool as a band of slots, main first (marked), each
removable, then an empty Add slot while there's room that opens the host's picker. The
pool page's head; the desktop's pool editor next
States: a main; three, room for more; full: no Add slot
Used by: poolpage

### HeatGrid
`heatgrid.zig` `.c-heat` site
HeatGrid: champions against champions as a grid of points vs usual. Rows and columns are
champions (icons, a name when there's room); a cell is the column's champion into the
row's, on the fill scale, faded when its 80% range is wide (J35) and "·" with no games. A
gap can split the columns (a pool, then suggestions), a row can be flagged (a lane nothing
covers), a column head can carry a control (Add). Cells can be pressed: both heads light
and the host gives one readout line. Pool's weak lanes first; the draft tester's pair
square (docs/plan/ui/draft-tester.md) is rows = columns = seats, a gap between teams
States: a pool's weak lanes, three to add; pressable, a cell pressed
Used by: poolgrid

### MatchupGrid
`matchgrid.zig` `.c-mgrid` site
MatchupGrid: a champion's matchups in one role as a dot plot, against or with each role
(RelationPicker), placed by win rate, vs usual or gold at 14, and the chosen opponent's
brief under it. The champion page's matchups card; the matchup finder shows it for the
first champion picked. The owner's Msg carries `rel`, `ally`, `rel_role` and `measure` and
hands them to `update`
States: lane opponents by win rate; one chosen: its brief under the plot; by gold at 14;
with the jungler
Used by: finder, champpage

### Finder
`finder.zig` `.c-finder` `.c-fgrid` site
The matchup finder (matchup/index.html, docs/plan/ui/matchups.md): a way to a matchup
page, not a list of them. Two islands. Finder: two ChampRolePickers, one lane for both;
nothing picked, a role (All first) beside them and three short lists of its lane pairs
(the hardest lanes, the lane bullies, then this patch's movers: noisy, so last), each a
link to its page. Grid (its own, lazily loaded file): the first pick's MatchupGrid,
Against its lane, from the champion page's data/champion/<slug>-more.bin; the second pick
is that opponent's dot, and its page when there is one. Finder writes the picks to the
URL, Grid reads them (same keys). Pages are rendered on request, so Finder's data rides in
its data-bin, as the matchup page's do: ui-finder.wasm adopts it
States: nothing picked: every lane's movers, hardest lanes and bullies, each row's role;
Top's; a role with no pairs yet; one picked, its matchups on the way; one picked: its lane
opponents; both picked: the opponent's brief and the way to their page; both picked, too
few games for a page; Hardest lanes longer than 8: the button for the rest; Hardest lanes
opened past 8

### Violin
`violin.zig` `.c-violin` `.c-violin-defs` site
Violin: how a champion's players' own win rates spread, as a mirrored shape on a 25% to
75% track (50% marked), thicker where more players are, the middle half brighter, the
champion's rate as a dot. Fits a table row. The shape takes its colour from one gradient
across the track (`defs`, once per page): orange low, grey middle, blue high
States: gradient (once a page); wide spread, above 50%; narrow, below 50%; off the track's
end; too few players: dot only
Used by: tiers

### StatRanking
`ranking.zig` `.c-rank` `.c-rankhead` `.c-rankidx` site
StatRanking (docs/plan/ui/rankings.md): every champion in a role ranked by one stat, a
DataTable island (ui-rankings.wasm) from its data-bin. A stat is a spec (`spec`, by
urls.Stat): its name and what its figure counts; the server picks the rows. Sorted by the
figure's edge over the role pulled toward 0 when its games are few, shown raw, so a thin
row can't top the list; rows under the floor wait behind a chip, faded
States: All: role icons, a thin row behind the chip; a role, the thin row shown and faded;
no rows; a gap: long minus short games, the lean beside it; gold: lane lead at 14; head;
index: a card per stat, its top three
Used by: champpage

### LearnPage
`learnpage.zig` `.c-learn` site
The Learn page (docs/plan/ui/learn.md): one puzzle a screen. ChapterStrip on top (title,
the chapter's question, n/N, stars), the PuzzleCard, and beside it (under it on a phone)
ChapterPath: this chapter's puzzles, the tips earned, every chapter with its progress. A
chapter's end lists its takeaways with their stars. Over it all, today's five: a puzzle of
each chapter from `start` on, the same for everyone that day, a slot open once its chapter
is finished. One island (ui-learn.wasm); progress in localStorage through the page's code
(`progress`)
States: first visit: chapter 1, the mastery guess; mastery guess locked in: every band,
3.3 off; counter duel; counter, a wrong pick revealed: each into Yone and against
everyone; chapter 0: role tiles; chapter 0: counter tiles, one phrase each; facts setup
with a slider; facts setup revealed: the bands; chips setup: a champion and its figure;
chapter end draft: the team lacks magic; chapter end draft, a wrong pick revealed: reasons
in words; today's five: chapter 1 finished, its slot played; chapter end

### DailyPage
`dailypage.zig` `.c-dailyw` `.c-daily` site
Daily Draft's page (docs/plan/ui/daily.md, mock round 4): the board with the last pick
hidden and the pick panel (six ChoiceCards, Lock in), then "Who won?", then the reveal:
the result line and the board grown, its seats selectable. ui-daily.wasm; answers in
localStorage "meiolol.daily.v1" through the page's code (`saved`, `restore`). The selected
seat's review and On paper are ui.dailyseat, an island of their own beside this one
(`layout`)
States: first visit: red's last pick asked; pro draft, one chosen, the range hint used;
locked in: who won?; revealed: wrong pick, wrong winner, the played pick's reasons open
Used by: dailyseat, dailydays, homepage

### DailySeat
`dailyseat.zig` `.c-dseat` site
Daily Draft's review after the reveal (docs/plan/ui/daily.md): the selected seat's
CandidateList (rows open their ReasonBreakdown, two at most) and On paper. Its own island
(ui-dailyseat.wasm), loaded by ui-daily.wasm once the puzzle is answered; the answers and
the board's selected seat from that island's root (`read`). Empty until then;
dailypage.layout places its cards beside and under the board
States: wrong pick: yours tagged in the list, On paper; more picks opened; wrong pick off
the list: named in a line; another seat, one the model can't rate; the played pick's
reasons open
Used by: dailypage

### DailyDays
`dailydays.zig` `.c-dhead` `.c-days` site
DailyDays: Daily Draft's head (title, badges) with the days strip and streak, the strip
its own island (ui-dailydays.wasm) so ui-daily.wasm stays the puzzle's. Each day links its
puzzle's page (/daily/<n>); answers come from localStorage meiolol.daily.v1
(dailypage.read), so the server renders none. Once the page's puzzle is finished, how
everyone did (/api/daily: the browser's answers sent once) and Share
States: first visit: today ringed, nothing played; both, one and none right; #15 missed
and forgiven; today started; an archive puzzle's page (#12, dashed), finished: how
everyone did, Share

### ChangeLine
`changeline.zig` `.c-chg` site
ChangeLine: what Riot changed, one line each: the slot's key (Q, P; · for stats and
items), what it is, the old value struck, then the new one in the tone's colour with an
arrow as the second cue. A text hunk keeps a few words either side. Lines with no number
to show say so instead
States: champion; item
Used by: patchpage

### PatchHead
`patchhead.zig` `.c-phead` site
PatchHead: the patch page's title, the pair it compares, with ‹ › to the older and
newer pair (disabled at either end), and a small line under it: how many games (so far, on
the newest pair) and a link to Riot's own notes
States: newest pair; oldest pair
Used by: patchpage

### PatchPage
`patchpage.zig` `.c-patch` site
Patch changes (/patch; docs/plan/ui/patch.md): what Riot changed this patch, next to what
moved. PatchHead, filter chips with their counts and the role in place, then every
champion role with enough games on both patches in one DataTable: Riot's badge, both
rates, the change drawn with its range, the lane lead, its matchups that moved. A row
opens what Riot changed and its matchup moves. The items and runes Riot changed sit over
the table as chips, one open at a time. The server renders the default state from the same
Data the view's data file (data/patch.bin) carries; ui-patch.wasm decodes that file and
adopts the page
States: moved clearly and changed by Riot, Darius open; Bastionbreaker open over the
table, Miss Fortune open; bot, Riot changed only, Jinx open: no matchup moved; without
Riot's data; support: nothing listed

### PoolPage
`poolpage.zig` `.c-poolpage` `.c-poolwrap` site
The pool page's own island (pool.html, docs/plan/ui/pool.md): the pool, up to ten
champion-role pairs grouped by role, and the picker. Empty by default: the picker is the
page. The sections per role are ui.poolgrid's island beside it, which ui-pool.wasm tells
the pool; the pool rides in the URL (#pool=86t-122j) and localStorage
States: empty: the picker is the page; Darius, Garen top and Vi jungle: the slots by role,
the grid, the picker beside
Used by: poolgrid

### PoolGrid
`poolgrid.zig` `.c-poolgrid` site
PoolGrid: the pool page's sections, one per role in the pool (docs/plan/ui/pool.md v2):
the role's lane opponents against your champions there (HeatGrid), worst first or most
met, and what to add from the role's main file (CandidateList). Its own island,
ui-poolgrid.wasm: ui-pool.wasm tells it the pool and adds what it asks for. Lanes files
(data/pool/lanes/<slug>.bin) and mains' files (data/pool/<slug>.bin) are fetched as the
pool needs them
States: Darius and Garen top, Vi jungle: lanes worst first, what to add for top; jungle
has no main's file; Darius alone top: weak spots, no answer to Fiora and Yone, a role on
one champion
Used by: poolpage

### DayHead
`dayhead.zig` `.c-dayhead` site
DayHead: a day group's head in the Your games list (your-games.md "Games"): "Today",
"Yesterday" or "Thu 22 Oct", the day's W-L in result colours and the time played
(deeplol's session line)
States: yesterday: 3-0, 1h 36m; an older day: 2-3
Used by: yourpage

### ResultStrip
`resultstrip.zig` `.c-form` site
ResultStrip: recent form as a tick per game, oldest on the left; a win full height in
--us, a loss shorter in --them (your-games.md, the player bar's "Last 20"). Remakes count
in no record, so they get no tick
States: last 20, a remake skipped; the player bar's; a teaser's 8; three games
Used by: lobby, playerbar

### PlayerBar
`playerbar.zig` `.c-player` site
PlayerBar: the Your games page's head card (your-games.md "Structure"): rank badge, Riot
ID, rank line, the shown games' record, KDA and streak, the last 20 as a ResultStrip; the
page's buttons at the end and its bands (tabs, filter row) under it. The badge is the
tier's letters until rank emblems ship (plan "Data needed")
States: ranked, 5 wins in a row; unranked, a long name, 3 games; master, no games yet
Used by: yourviews

### ProfileSummary
`profilesum.zig` `.c-psum` site
ProfileSummary: beside the Your games list (your-games.md "Structure"), what the filtered
games add up to: a win ring with the record and KDA, the top champions with W-L and a win
bar, a column per role sized by games. Pressing a champion or a role sets the list's
filter (pressed again: All); the rows ignore their own part of the filter so the choices
stay. Phones: the ring and the top 3 champions in one line
States: 13 games, nothing chosen; jungle chosen; no games
Used by: yourpage

### RecordTile
`recordtile.zig` `.c-rtile` site
RecordTile: one record from a player's games (your-games.md "Highlights"): the figure
large, a label of 1-3 words, and the game it came from as a chip (your champion and
theirs, W or L, the date), a link to that game at the record's moment. Colour only where
the figure is good or bad for you (a lead, a swing); counts and times plain
States: a lead; a time, no opponent; no game
Used by: highlights

### Highlights
`highlights.zig` `.c-hl` site
Highlights: the records in a player's games (your-games.md "Highlights"), from the List
alone, as RecordTiles in labelled groups: Streaks, Lane, Fights, Games. Each only when
there is something to say, so a short history shows fewer rather than empty ones. `top` is
the Games view's row of three. A game under 5 minutes (an early surrender) counts for the
record and streaks, never for a length, KDA or lane record
States: every group; the Games view's three
Used by: yourviews

### GameTrend
`gametrend.zig` `.c-gtrend` site
GameTrend (your-games.md "Over time"): a player's games in order on chart.zig's frame,
each a dot at its figure, filled for a win and hollow for a loss, the rolling mean of 5
filled against a base (50%, zero or the average), patch changes as dashed dividers named
by the new patch, each week's first game dated under the axis. Games are evenly spaced,
not by date, so a busy evening doesn't pile up. A dot links to its game. The pointer
anywhere on the plot (or a tap, which stays) picks the nearest game: its dot ringed, its
figure and the mean in a tip (the caller's state, `at`); keyboard focus on a dot shows its
label. A key under the plot names the dots and the line
States: win chance at 15, 20 games over three patches; a game picked: its dot ringed, the
tip
Used by: yourtime

### YourList
`yourpage.zig` `.c-your` site
The Your games list (your.html, docs/plan/ui/your-games.md "Games"), under YourViews'
PlayerBar: ProfileSummary beside the games as day groups of GameRow, "Show older" at the
foot. Island YourList (ui-your.wasm); the filter is in the URL, which YourViews' filter
row writes too. The server renders without a clock (dates, no "Today" or "2h ago": the
page stays the same all day); the island adds them in the visitor's zone
States: 10 games over 4 days; Flex only; a filter with no games; 2 of 4 days shown
Used by: highlights, yourviews, yourtime

### YourViews
`yourviews.zig` `.c-yviews` site
The Your games page's head (your.html, docs/plan/ui/your-games.md "Structure"): PlayerBar
with the views' tabs and the filter row as its bands, then the chosen view. The Games view
is YourList, Over time YourTime and Friends YourFriends, the next islands on the page,
each hidden in the other views (CSS: the DOM order is the reading order). Island YourViews
(ui-yourviews.wasm). It and YourList both hold the filter, each writing q/role/champ and
reading the other's presses from the URL
States: Games, all queues; Flex only; every view, Highlights; Highlights, a filter without
games

### YourTime
`yourtime.zig` `.c-ytime` `.c-tcard` site
The Your games page's Over time view (your-games.md "Over time"): each game on a GameTrend
of the chosen measure, Patterns (win rate by game length against your own), and a sortable
table of the games by champion, matchup or week. From the List alone, on the filtered
games. Island YourTime (ui-yourtime.wasm), between YourViews and YourList on the page,
shown by YourViews' Over time tab; its file loads when it shows. The filter is read from
the URL, written by the other two
States: the Games view's card; win at 15, by champion; vs typical, by matchup; KDA, by
week; no timelines: KDA, one length so no Patterns; a filter without games
Used by: yourviews

### YourLookup
`yourlookup.zig` `.c-ylook` site
The Your games lookup (your.html#id=Name%23TAG): the status line above the list, its Check
for new games and Not you?, and when to ask /api/list again. Island YourLookup
(ui-yourlookup.wasm, which ui-your loads once the URL has an id). A list goes to YourList
as its root's data-bin (a List's file, base64; removed for the example again), then
`event` on the window
States: looking up; queued behind others; fetching; ready after a failed refresh; queued;
not found; opted out; busy; still working at the cap; ready: check and Not you?; checking,
nothing new yet; checked, new games; the API down: the example below

### YourFriends
`yourfriends.zig` `.c-yfriends` site
The Your games page's Friends view (your-games.md "Friends"): who a looked-up player
queues with, from /api/friends.bin (api friends.zig): the record with friends and alone,
then a DataTable of friends, a row opening the champion and role pairs. Facts with a
range, never verdicts. Lookups only: the example has no friends. Island YourFriends
(ui-yourfriends.wasm), after YourTime on the page, shown by YourViews' Friends tab; its
file loads when it shows. The filter row doesn't apply to it
States: three friends; a row open; older games coming, one friend fetching; nobody yet;
loading; failed; opted out

### Forget
`forget.zig` `.c-forget` site
Remove my data (docs/legal/lia.md "Objection"): anyone, for any Riot ID, proves it is
theirs by setting a profile icon, then the API removes it and never collects it again.
Island Forget (ui-forget.wasm, lazy at the Your games page's foot); /api/forget does the
Riot calls (api/root.zig forget) and answers a small JSON object, read by `answer`
States: closed; open; contacting Riot; icon issued; icon not set yet; done; not found;
expired; service down
Used by: squad

### Apply
`apply.zig` `.c-apply` site
Apply to test the desktop app, at /download#apply: Riot ID, a contact, role and rank if
they like, one line why. Island Apply (ui-apply.wasm) POSTs a ui.applydata.New to
/api/apply (api/applications.zig). As ui.account, the wasm reads the form once it is sent:
typed text stays in the inputs, the browser's checks (required, pattern) first
States: empty; sending; sent; refused; busy; down

### Squad
`squad.zig` `.c-squad` site
Squads (/squad, your-games.md "Squads"): friends who each joined by the profile icon
check, and the games they played together. #s=TOKEN is a squad (the invite link): its
name, members, record together and those games, each opening a member's review; Join,
Leave and the link to share. Without a token: start one. Island Squad (ui-squad.wasm);
/api/squad answers Data in ui.data's binary, /api/squad/check the check's small JSON
(api/squads.zig)
States: start; start, icon issued; loading; no squad; new, no games; squad; joining;
leave, icon not set yet; joined; full

### IdLookup
`idlookup.zig` `.c-lookup` site
IdLookup: a Riot ID box and Review as one control, the newest Riot IDs this device looked
up as a row of equal chips under it, edge to edge with the box (three; two when narrow),
the tag muted. Goes to the Your games page with the ID in the fragment, so it never
reaches a server log; before the island runs Review submits the form, which sends it as
?id= instead (the page moves it to the fragment)
States: empty; typed, recent IDs
Used by: sitesearch, yourlookup, forget, squad, homepage

### TodayCard
`today.zig` `.c-today` site
TodayCard: a Card with a one-line title, real content and one action (home's Today; the
desktop's between games panel). Bodies: `draft` (Daily Draft's teams lane by lane, blue
over red, the hidden seat a dashed ?, your marks once played) and `changes` (a patch's
biggest win rate moves, biggest rise to biggest fall, a rule where the sign turns:
champion and role, before and after, DeltaBar on one axis down the list, Delta)
States: draft; draft, played; changes
Used by: apphome, homepage

### HomePage
`homepage.zig` `.c-home` `.c-hrev` `.c-hch` site
The home page (index.html, docs/plan/ui/home.md): a game on the first screen with the
lookup and today's things beside it, each role's most played under them. Islands
(ui-home.wasm): HomeReview (the example's game, its role switch, the stat cells select on
the graph; a returning visitor's newest game in its place), IdLookup (recent Riot IDs on
this device), HomeChamps (one role at a time in a narrow card), HomeDaily (this device's
Daily Draft marks). The patch card is static
States: first visit; Daily Draft played; returning visitor; champions by win rate, a role
with none
Used by: yourlookup, yourfriends, squad

### Account
`account.zig` `.c-account` site
The account pages (docs/plan/accounts.md): log in, make an account (/signup: open, a
username and password; /signup#LINK: a sign-up link's email form), set up a login from an
invite or reset link (/join#INVITE) and the signed-in account (/account: who, a new
password, its desktop apps, log out, delete). Island Account (ui-account.wasm) against
/auth/NAME.bin (api/accounts.zig). A link's token stays in the fragment, which browsers
never send. What is typed stays in the inputs: the wasm reads the form once it is sent, so
autofill before the island counts and no password sits in the state
States: log in; log in: sending; log in: refused; log in: too many tries; log in: server
down; sign up; sign up: name taken; sign-up link; invite without its link; account:
loading; account: down; account: no apps; account: public; account: delete refused;
account: password changed

### TesterPage
`testerpage.zig` `.c-tester`
The Draft tester page (docs/plan/ui/draft-tester.md, /private/tester): build a draft, see
blue's win chance under a named model, each seat's term and the model's checks. A model
from a Select of ModelBadges, "vs" a second one to compare (a tick on the split, a column
in the candidate panel); the board is DraftBoard's full variant, a click choosing the seat
the candidate panel (testercand.zig, its own island and wasm) fills; Random game and Fill
empty draw seats by play share, Undo takes the last draw back. Board | Terms | Files under
it. The models, board, seat and tab are the URL fragment's (Url), which the panel shares.
Models are draft-model.bin files the page's code fetches (testerdata.zig); champion keys
and names come inline (data-bin)
States: loading; a draft; a seat chosen; terms; files; a ban; every seat picked: why
blue's chance; Comp model compared: two splits, the gap
Used by: testercand

### TesterCand
`testercand.zig` `.c-tcand`
The Draft tester's candidate panel (docs/plan/ui/draft-tester.md "First screen"): every
champion the shown seat could take under the page's model, as a RankStrip and a
CandidateList in points mode, sorted by Win (the low end of its 95% range) or Fit (the
change less the champion's own strength). A row's chips and, opened, its ReasonBreakdown
are draftscore's Scorer.why parts; Pick fills the seat. The search keeps the rows whose
name holds it, Enter picks the first. With a model compared, a column of its chance and
points over its own average pick: the two models' baselines can sit points apart, so a raw
gap would mostly repeat that Its own island and wasm (ui-testercand.wasm, which
ui-tester.wasm loads) with no model of its own, so it fits its budget: the two share the
board through the URL fragment (testerpage.Page.Url), and ui-tester.wasm, which holds the
model, hands it the seat's options (Feed)
States: loading; red top, a row open; searched, nothing

### Meionotes
`meionotes.zig` `.c-meionotes`
meionotes: Jacob's notes on the live site, an island ui-meionotes.wasm adds to a page for
the admin login only (nothing in the page itself). The meionote button, picking an element
(the glue outlines what is under the pointer and blocks the page's own handlers), the
form, and pins for the page's open notes. Every child of the root is keyed: pins and the
outline come and go while the form is open, and its textarea must stay the same node.
Positions are the document's, CSS px, measured by the glue; the root spans the page's
width at its top, clipping sideways so a pin at the edge never widens the page
States: no meionotes; pins and count; a pin open; picking; form, a component; form, whole
page; form, not saved; saving; a slur refused

### MeionotesList
`meionoteslist.zig` `.c-meionoteslist`
MeionotesList: /admin/meionotes, every note on the site grouped by page or by component,
by status; Done, Reopen, a reply and Delete (asked twice; the owner's, delete_meionotes)
per note, Looks good or Not yet on one a session fixed, and the tool on or off in this
browser. ui-meionotes.wasm's list mode fetches (again every 20 s while shown) and saves;
the reply's input is uncontrolled and keyed, read by the glue at Save
States: loading; by page, open; by component, all, replying; to check, not yet; delete
asked; delete refused; none, failed

### Pv
`pv.zig` `.c-pv`
Pv: the private numbers on public champion and matchup pages (app.md "Private site"), the
shipped draft model's win chances, which the public pages never show (production-key.md
"Product rules"). ui-pv.wasm draws it for admin logins only, from ui.pvdata files under
/private/: one row of figures under the head, the model's chance beside the games' win
rate the head shows, then the matchup brief's champion; on a matchup page, the pair
States: Meio under an opponent lock: the stack, then each choice with it; Meio at Master+:
raw only; champion page, with the brief's opponent; champion page, no brief, no head rate;
matchup page

### AdminPage
`adminpage.zig` `.c-admin`
AdminPage: /admin/ (private) as one island. The server renders it empty ("Loading");
wasm/admin.zig fetches admin.bin (the box's snapshot each web round), api/live.bin (the
last 3 h, polled) and /auth/me.bin, sets `now` from the clock before each draw, and does
what `want` asks after an update (an action, an account change). Tabs in the URL
(#tab=ops); the chart, traffic, ops and models tabs are islands of their own
States: loading; overview: two problems; controls: a failed build; controls: live API
down; controls: an admin refused; accounts: a role asked, a link made; applications;
applications: approved, its invite link; snapshot failed
Used by: admincharts, admintraffic, adminops, adminmodels, adminlab, adminruns

### AdminCharts
`admincharts.zig` `.c-adcharts`
AdminCharts: the admin page's chart tabs, Crawler and Riot API, an island of their own
below AdminPage's tabs (ui-admincharts.wasm, which fetches only once one shows). The tab
comes with the URL (#tab=crawler). Crawl charts read live.bin's last 3 h by minute for the
3-hour range, else the snapshot's 10-minute buckets; readings and the backlog read the
snapshot's history. Each chart's zoom and tip stay in `times`, so a re-fetch keeps them
States: crawler: a day, all regions; crawler: 3 hours live, europe and asia; Riot API: a
key problem, one chart tipped; loading; another tab: hidden; storage; ingest: no sea
Used by: adminpage, admintraffic, adminops

### AdminTraffic
`admintraffic.zig` `.c-adtraffic`
AdminTraffic: the admin page's Traffic tab, an island of its own below AdminCharts
(ui-admintraffic.wasm, which fetches api/traffic.bin only once the tab shows). The site's
nginx log as deploy/traffic.sh counts it: views by people, unconfirmed and bots, server
errors, page time, top pages, referrers, agents, status codes, render cache and not found.
A day or more draws a bar per UK day, else per hour
States: 7 days, one chart tipped; 24 hours, top pages of the day; 30 days; loading;
failed; no traffic yet; another tab: hidden

### AdminOps
`adminops.zig` `.c-adops`
AdminOps: the admin page's Deploys and Logs tabs, an island of its own below AdminTraffic
(ui-adminops.wasm, which fetches only once one of them shows). Deploys: every push from
its check until the site serves it (ui.admindeploys over live.bin's deploy events,
admin.bin's when the live API is down), one StepTimeline each. Logs: the tail of each of
the box's logs (api/log, text) in a LogView, stamps in UK time, errors and warnings of the
last 24 h per file
States: deploys: one running, untimed; deploys: from the snapshot, none yet; deploys:
loading; deploys: failed; logs: filtered; logs: a file failed; logs: loading; another tab:
hidden

### AdminModels
`adminmodels.zig` `.c-admodels`
AdminModels: the admin page's Models tab, an island of its own below AdminOps
(ui-adminmodels.wasm, which fetches models.bin and training/training.bin once the tab
shows; ui.modelsdata). Views: All, a card per learned.md category; Win, the daily eval
read into sentences, run by run, each model against the shipped one and the report; Early,
the team effects per outcome; the other categories, learned.md and run findings; Draft, a
link to the tester
States: all; win; early: lane gold; items: a running run; draft; loading; lab view failed;
another tab: hidden
Used by: adminlab, adminruns

### AdminLab
`adminlab.zig` `.c-adlab`
AdminLab: the Models tab's Neural nets and Lab campaigns, an island of its own between
AdminModels and AdminRuns (ui-adminlab.wasm: with them ui-adminruns.wasm was 13 KB over
its budget). It fetches training/training.bin once it shows. All: the Neural nets and Lab
campaigns cards. Neural nets: docs/nn-results per question. Lab campaigns: each campaign's
ideas and digest (AdminRuns lists the lab's runs below)
States: all: the nets and lab cards; neural nets; lab campaigns; training.bin failed; an
outcome: hidden
Used by: adminruns

### AdminRuns
`adminruns.zig` `.c-adruns`
AdminRuns: the Models tab's training runs, an island of its own below AdminLab
(ui-adminruns.wasm: ui-adminmodels.wasm is near its budget). It fetches
training/training.bin as AdminModels does and, for the run whose health shows, its
runs/<run>/metrics.bin and log.txt. A category: its runs as cards, the picked one's
effects, curves and log. All: the runs live now. Lab campaigns: the lab's runs. Win, Draft
and Neural nets show nothing here
States: all: a live run; early: runs, one picked with curves; lab runs, the gpu-box out of
reach; a run's files loading; the lab view failed; neural nets: hidden
Used by: adminlab

## Pages (no gallery)

### ChampPage
`champpage.zig` `.c-cpage` site
The champion page (/champions/<slug>, /champions/<slug>/<role>): one champion in one role
(docs/plan/ui/champion.md), as five islands. Top: the head with the role picker, the
opponent search and the headline figures. Build: the build panel. More: the matchups as a
dot plot with the chosen opponent's brief. Trends: by patch, by game length, the players'
spread, by rank, first item done. Charts: lane, comeback odds, pick-up, also play, lane
kills, objectives. The server renders the path's role (bare: the main role) from the same
data the page's data files carry (data/champion/<slug>.bin, -build, -more, -trends,
-charts: `split`). ui-champion.wasm adopts Top and fetches the other islands' wasm as they
near the screen (one file would be over the 40 KB gz budget: stack.md). Role tabs are
links to the role's page; the islands see one fragment (role=, region=, ...), which
dom.zig's url_map spreads over the path, query and fragment. Top's toolbar picks the
region, period and rank, kept beside the role: each island then fetches its own file for
the pick (`Files`: another view's base file, or the view's rank file, ui.champrank) and
shows the old figures faded until it's in
Used by: matchgrid, finder, matchpage, tiers

### MatchPage
`matchpage.zig` `.c-mpage` site
The matchup page (/matchups/<role>/<x>-vs-<y>): one lane pair from x's side
(docs/plan/ui/matchup.md), the champion page with its opponent slot filled, as three
islands, lane first. Head: ChampHeader's pair with the headline figures, x's other lane
opponents and the view links. More's lane part: head to head beside the lane by minute.
Build: the champion page's Build island on the pair's build (its usual one when the pair
is thin). More's outcome part: won by gold at 10, by game length, by rank and mastery, and
bot lane partners. Pages are rendered on request, so each island's data rides in its
root's data-bin (base64 of ui.data) rather than a file: ui-matchup.wasm adopts Head and
loads ui-champbuild.wasm and ui-matchmore.wasm for the others. More's two parts share the
lane part's data-bin and file

### Champions
`tiers.zig` `.c-tiers` site
Champions (champions.html, role/<slug>.html; docs/plan/ui/champions.md): every champion in
every role on one board, a role at a time, and which way each moved this patch. A head
card (role picked in place, search, the view's toolbar, the Games floor), then the movers
band and a DataTable sorted by the rate shown. The server renders the default state from
the same Data the view's data file (data/tiers.bin) carries; ui-stats.wasm decodes that
file and adopts the page. A view (region, period; in the query) has its own page, but the
toolbar picks it in place: its data file is fetched and the board shown faded until it is
in. A rank above Platinum+ the same way: the view's rank file (rank_paths)
Used by: patchpage, champpage

