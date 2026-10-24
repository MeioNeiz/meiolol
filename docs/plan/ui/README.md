# UI foundation: one component system for the site and the desktop app

Plan (team run 2026-10-24-ui, foundation session). Source: Jacob's review
(docs/review/page-review-2026-10-24.md). Background and options: docs/frontend-rework.md
(Option A, 22 and 23 Oct updates). Page plans: the other files in this folder. Register of
every component: data/team/2026-10-24-ui/components.md (moves to docs/plan/ui/
components.md when building starts). Gallery mock: data/team/2026-10-24-ui/mocks/
components.html (tokens.css and components.css beside it are the prototype CSS).

Jacob: "developing our frontend tools libraries and such so we can actually make good
ui ... thinking extremely long term ... making the ui from the groundup not just solving
each problem in isolation".

## In one screen

- One component per need, ~60 of them, named once in the register; every page plan in
  this folder is written in those names. The register merged 3 planners' ~80 requests
  into one list (e.g. 6 chart ideas became one Chart with presets; tabs, toggles, sort
  chips and view switches became one Segmented)
- A component is a Zig struct in `src/site/ui/` that renders with tpl. The same code
  renders on the server (pages, no-JS, Riot's reviewers) and in `ui.wasm` in the browser
  (sorting, ranges, toggles), so no logic exists twice
- CSS: tokens (5 type sizes, one colour scale, spacing, control sizes), then `@layer`
  base, components, pages. Components size to their container, not the screen, so one
  component works in a phone column, a desktop page and an app panel
- Words and the other review points are direction, not rules yet (Jacob 24 Oct): the
  measured checks below (word budgets, label length, tap targets, text size) are drafts,
  warnings only, tested on the first rebuilt page. Product rules are the binding
  exception
- Desktop: recommend the 1-2 day WebView2 spike now, in parallel with the site
  foundation and before any desktop-facing component is built. If it passes, the app
  shows the same components; if not, ~15 components need dvui twins. The toolkit is now
  open from scratch and decided by the stack session's spikes (docs/plan/ui/stack.md)
- Build order: foundation ~11-13 days (tokens and layers, ui.zig core, gallery and QA,
  ui.wasm, one chart system), then pages, champion page first

## Principles: direction, with draft checks

Jacob (24 Oct): the review's rules are direction, not exact rules yet; an exact rule
applied everywhere becomes its own design trap, so use judgement per case (the hub,
docs/frontend.md, says the same). Each line has a draft check: "qa.sh" is the Playwright
sweep, "lint" a ui.zig or CSS check. All are warnings until the first rebuilt page shows
which ones help; a check that fights a good design gets changed, not obeyed. Product
rules are the exception: they bind every screen.

| Direction (Jacob's words where he said it) | In practice | Draft check |
| --- | --- | --- |
| Words: "WAAAAY too many words" | the UI mostly explains itself; each page plan names and counts its first-screen words; short labels (about 2 words); no "how to read this" text | qa.sh: visible words vs the plan's count; lint: label length |
| "never have something that long" | Toggletips sparingly: for a term or an uncertainty that needs a line, not a place to park words an unclear component couldn't carry | lint: Toggletip text over ~30 words |
| "We never need a key of colours" | no key where the number describes itself (a win rate's colour is read from the win rate); a key earns its place where colour encodes something the reader can't see otherwise, drawn in place, kept to a line | lint: no colour outside tokens |
| Colour means "far from usual" | one diverging scale, steps from one Zig function (aggregate stops 1, 2, 3.5, 5.5 points; one game 2.5, 5, 10, 15), always with a sign, bar or weight; thin data fades | by construction: StatCell and Delta pick the step and the cue, pages pass numbers |
| "the UI should explain itself" | each component's states are visible (selected, disabled with reason, empty, thin) | gallery shows every state; rubric review |
| "awful use of space" | answer first: the page's answer on the first screen at 390 x 844 and 1280 x 800; little chrome on phones | qa.sh: first answer's position |
| "real table" | a sortable DataTable where it is a table; purpose-built components where the data has its own shape (tiles, trees, charts) | qa.sh: no horizontal overflow 320-1280 |
| "some cells ... look just like the other buttons" | Badge has no border or hover; only Button, Chip, Segmented look pressable | CSS in one place (components layer) |
| Tap, not hover | Toggletip, ChartTip and RowDetail open on tap; nothing hover-only | qa.sh: tap targets (44 px phone, 24 px floor) |
| Numbers read the same everywhere | one formatter per kind (rate 51.2%, delta +2.6, points +2.6 ±1.8, count 12.3k, time 11:54, gold +1,402), U+2212 minus | unit test; wasm uses the same Zig |
| Product rules (production-key.md), binding | no "best pick", no "+X% win rate"; 3-5 options with reasons; no other players' names or stats in champ select | CandidateList and ReasonBreakdown have a public mode with tiers and words; DraftBoard's champ select mode has no name or rank fields (compile) |

## Decided while drawing the gallery (24 Oct)

Planners drew some components differently; foundation picked one (gallery-notes.md has
the detail). Say if any should go the other way.

- StatStrip: plain figures, no box per figure (champion, matchup and patch mocks boxed)
- ReasonBreakdown: the waterfall from the tester, not plain bars per term (Daily)
- Versus mirrored: matchup.html's head to head (label over two bars, values at the
  ends, the better side bold, no gap column)
- ChampHeader pair: icons ringed by side, so no colour key is needed
- MatchupTile strip: icon, rate and tick only; the grid keeps name and games
- Badge: flat, no border (the patch mock's pill read like a Chip)
- Game events: FightStrip above the plot and death portraits on its edges (reconcile,
  from OpenDota and Dotabuff), replacing the rails under the axis the games mock had
- Scoreboard: lane rows by default (Mobalytics), Lanes | Table
- MinGames: one cut-off per table (Any shows thin rows faded, other options hide them)
- Build slots: runes, spells, start and skills coloured on the scale; items, boots and
  core paths plain (late items mostly say how the game went)

## Architecture

### A component exists once

```
src/site/ui/            components: pub structs with render(self, w), tpl inside
src/site/ui/fmt.zig     the formatters and the colour step (StatCell, Delta, charts)
src/site/ui/chart.zig   one chart system (lanechart.zig grows into it)
src/site/ui/wasm.zig    ui.wasm entry: exports per interactive component, via zjb
src/site/static/css/    tokens.css, base.css, components.css, pages/*.css, joined at
                        comptime into one hashed style.<hash>.css
```

- Server: page modules compose components; `meiolol render` and the static build emit
  the same bytes (pipeline_test keeps that).
- Browser: `ui.wasm` is built from the same `src/site/ui/` files with zjb (fork,
  branch `meiolol`, research/raw/zjb-tpl-island-spike.md) and a thin `dom.zig` (byId,
  setHtml, on, fetchBytes, storage) so components never touch handles. The only
  hand-written JS is zjb's 5-line loader. One `ui.wasm` for the whole site (budget 40 KB
  gzip), hashed name.
- Big data (Pool's tallies, a full matchup list): server fragments, fetched and swapped
  by dom.zig; never shipped as JSON to be re-summed.
- Which data an island reads: what the server already rendered comes from the DOM
  (`data-v` on cells: sorting reorders existing rows, no re-render); what it did not
  render comes as a small binary file (chart_wasm.zig's pattern, already live), never
  JSON (std.json was most of chart.wasm's size).
- Escape hatch: a page may still write tpl directly with tokens and `pages` layer CSS
  for a one-off block; it goes in the register if a second page wants it.

### The API shape (StatCell and DataTable)

```zig
// src/site/ui/stat.zig
pub const Kind = enum { rate, delta, points, count, time, secs, gold };
pub const Scale = enum { none, aggregate, game }; // which stops colour it

pub const StatCell = struct {
    value: f64,
    kind: Kind,
    scale: Scale = .none,
    ref: f64 = 0, // the scale's middle: the role's average, 50%, the typical game
    ci: ?f64 = null, // 95% half-width: "±1.8", opens a Toggletip
    games: ?u32 = null, // fades under fmt.thin_games
    context: ?Context = null, // a second line: last patch, typical
    variant: enum { ink, fill } = .ink,

    pub fn render(self: StatCell, w: *Writer) !void {
        const s = fmt.step(self.value - self.ref, self.scale, self.games, self.ci);
        try tpl.render(w,
            \\<span class="c-stat" data-v="{v}" data-state="{state}" style="--c:{c}">
            \\<span class="v">{value}{ci}</span>{ctx}</span>
        , .{
            .v = @tagName(self.variant),
            .state = s.state, // plain, scaled, thin, missing
            .c = s.colour, // var(--hi2) ...; the cue (sign, weight) comes with it
            .value = fmt.Value{ .x = self.value, .kind = self.kind },
            .ci = tpl.when(self.ci != null, Ci{ .half = self.ci orelse 0 }),
            .ctx = self.context,
        });
    }
};
```

```zig
// A page declares its table once; the compiler checks the guardrails
const Champions = ui.DataTable(ChampRow, .{
    .columns = &.{
        .{ .key = "champ", .label = "Champion", .cell = .who, .priority = 1 },
        .{ .key = "wr", .label = "Win rate", .cell = .{ .stat = .rate }, .answer = true,
            .sort = .desc, .tip = "Share of games won, last 30 days" },
        .{ .key = "change", .label = "Patch", .cell = .{ .delta = .arrow }, .priority = 2,
            .tip = "16.21 minus 16.20, in points; faint when it could be luck" },
        .{ .key = "pick", .label = "Pick", .cell = .{ .bar = .neutral }, .priority = 2 },
        .{ .key = "games", .label = "Games", .cell = .{ .stat = .count }, .priority = 3 },
    },
    .search = true,
    .min_games = &.{ 100, 300, 1000 },
});
// comptime: exactly one .answer column; labels <= 16 chars and 2 words; tips <= 30
// words; every key is a field of ChampRow; sortable cells carry data-v
try Champions.render(w, rows);
```

In ui.wasm, `Champions.sort(key, dir)` reorders the rendered rows by their `data-v`;
`Champions.filter(text, min)` sets `hidden` and the thin fade. Same struct, same
column list, so server order and client order cannot disagree (the filters.js twin bug
class goes by construction).

### State

- In the URL: anything worth sharing or restoring with Back: role, region, rank,
  period, sort, a game and its moment (`&t=`), a chart range. Back restores from the
  URL, never from leftover DOM (the 9f5fe61 bug class)
- localStorage: per-viewer conveniences only (a view choice, the last Riot ID),
  wrapped so a refusal changes nothing
- In wasm: transient things (an open row, a hovered minute); a component's state lives
  in a struct outside render (the c7f4003 class)

### Toggletips, popovers, dialogs

HTML first: `popover` + `popovertarget` opens and closes with no script (all core
browsers, iOS since Dec 2025); `<dialog>` for dialogs; one open Toggletip at a time.
Placement next to the trigger by CSS anchor positioning where supported, else a
20-line ui.wasm fallback. No hover-only content; no radio or `:has()` state hacks.

### Charts: one system

lanechart.zig (server SVG and chart.wasm in Your games) becomes `ui/chart.zig`: scales
(minute, patch, value, date), a frame (ticks, grid, end labels instead of a legend), marks
(line, area split at zero, ±95% band, bars, dots), parts (ChartTip, RangeSelect,
FightStrip, EdgeMarks, TurnBand) and presets (TimelineChart, LaneChart, TrendChart,
OutcomeCurve, PatchSpark, RankStrip, TimelineSpark, GameTrend). SVG from tpl on the
server; the same code in ui.wasm redraws on a metric switch or range. Game events stay
off the line (dense games overlap it): fights on a strip above the plot, deaths on its
edges. The desktop's third lane chart (dvui plot, src/desktop/ui.zig) goes if WebView2
passes.

### CSS

- `@layer tokens, base, legacy, components, pages`. The current style.css moves whole
  into `legacy` on day one: unlayered rules beat every layer, so it has to be layered
  for new components to win, and each migrated page deletes its legacy rules
- Tokens (mocks/tokens.css): surfaces, ink, the diverging scale lo4..hi4 and its fills,
  neutral bar, us/them, moment kinds, 5 type sizes (11, 12, 13.5, 16, 22), spacing 2-32,
  radii 4/8/12, control sizes that grow to 44 px tap areas on touch screens
- Components use `@container` queries; pages use three breakpoints (480, 760, 1000) for
  layout only. Class names `c-<component>`, parts by child class, states as attributes
  (`aria-selected`, `data-state`); no page prefixes
- Zig test lints the CSS: no hex outside tokens, no font-size outside the five, no
  `@media` width outside the three, no `!important`

## Desktop carry-over

The desktop review comes after this, so no screens here; what the app can reuse:

| App need (docs/plan/app.md) | Components |
| --- | --- |
| Champ select: options for your seat | DraftBoard (champ select mode: no names, no ranks), CandidateList (tiers mode for the public app), ReasonBreakdown, ChampIcon, RoleIcon, Chip, Badge, Toggletip |
| Lane card | Versus (dumbbell, band), LaneChart, StatCell, Delta |
| Comp view (APP6) | Bar, WinSplit only in the private app (no public draft win chance), Badge |
| Pool and settings | ChampSearch, ChampRolePicker, Segmented, DataTable |
| After a game | GameHeader, Scoreboard, TimelineChart, MomentList, RangeInspector |
| Testers | ModelBadge, HeatGrid |

What the toolkit choice means:

- WebView2: the window hosts the same HTML, CSS and ui.wasm. Every component above is
  free and stays identical to the site; `desktop-shot` becomes the qa.sh screenshot of
  the same pages; the app's own Zig (LCU polling, scoring, updates) stays native and
  feeds the page through a local endpoint or postMessage. Costs: a Windows runtime
  dependency (on Windows 11 by default, on most Windows 10 through Edge updates;
  bootstrapper otherwise), ~100 MB more memory, COM from Zig
- dvui (today, 3,787 lines in src/desktop): every component above drawn a second time
  in immediate mode, its own theme and colours (green/red today, not the site's
  colour-blind-safe scale), a third chart system. About 15 components twice, then kept
  in step forever

Recommendation: run the WebView2 spike now (1-2 days, in parallel with foundation step
1), because its answer decides whether desktop-facing components (DraftBoard,
CandidateList, ReasonBreakdown, Versus) need dvui twins, and those come early in the
build order. Site components don't wait for it. Spike pass criteria: builds for Windows
from the Mac with zig (webview/webview C library or direct WebView2 COM); renders the
gallery's DraftBoard and CandidateList from embedded assets; idle CPU under 1%, memory
under 200 MB, first paint under 1 s on the gpu-box; LCU data reaches the page; same
code opens a WKWebView window on the Mac for development.

## Tooling

- Gallery page: `meiolol dev` serves `/gallery`, every ui.zig component in each state
  from fixture data, phone and desktop widths side by side. The fixtures are the ones
  the tests use. mocks/components.html is its spec
- deploy/qa.sh (Playwright on the Mac, not in ci): every page type and the gallery,
  widths swept 320-1280: overflow (viewport and parent), overlap, text under 11 px, tap
  targets, visible words against the page plan's budget, console errors, failed
  requests, axe with target-size on, ARIA snapshot as text. Warnings first
- Screenshots: main against the working tree in one run, shown in review, never stored
  baselines or a gate
- ci (Zig tests): CSS lint and guardrail checks (warnings while they are drafts),
  formatter tests, server and wasm render the same component from the same data byte
  for byte, ui.wasm size budget
- Review: a session that did not write the page scores qa.sh screenshots against a short
  rubric (answer first, said twice, colour meaning, words)
- Adding a component: register entry (name, states, data, words) → struct in
  `src/site/ui/` with a fixture → gallery shows its states → qa.sh clean → then pages
  use it. A page never grows its own copy

## Build order and sizes

Foundation (~11-13 days; WebView2 spike in parallel):

1. Layers and tokens (1-1.5 d): style.css into `legacy`, tokens.css, base.css, the
   joined hashed file and the traffic beacon (`/style.css` kept as a no-cache stub for
   traffic.sh). CSS lint as warnings
2. ui.zig core (2-3 d): fmt.zig (formatters, step), Card, SectionHead, ChampIcon,
   RoleIcon, game art icons, Badge, Chip, Button, Toggletip, StatCell, Delta, Bar, Kda,
   StatStrip, Segmented, Select. Label checks as warnings
3. Gallery and qa.sh (2 d): the baseline numbers for every page today
4. ui.wasm (2-3 d): Safari/iOS check of the zjb island first (half a day; if it fails,
   server fragments take the interactions), dom.zig, Toggletip placement, Segmented,
   DataTable sort/filter/RowDetail, ChampSearch
5. Chart system (2-3 d): chart.zig from lanechart.zig; TimelineChart with FightStrip,
   EdgeMarks and RangeSelect, LaneChart, TrendChart, PatchSpark; chart.wasm folds into
   ui.wasm
6. Desktop-facing set if WebView2 passes (1-2 d): DraftBoard, CandidateList,
   ReasonBreakdown on the gallery

Pages (each: new module from components, its legacy CSS deleted, qa.sh words checked
against the plan, one commit for the move; 1-3 days each, sizes in each page plan):

1. Champion page with RolePicker, BuildPanel, RuneTree, MatchupGrid (exercises most of
   the system; deletes filters.js and its twins), then matchup and builds (same family)
2. Your games detail and list (charts, Scoreboard, MomentList)
3. Champions list, patch changes (DataTable at scale)
4. Daily Draft, Draft tester (DraftBoard, CandidateList), then Learn, Pool, home
5. Admin last (private)

New features from day one: built from register components; a missing one is added to
the register and the gallery first, in its own commit. No feature work on the old UI
unless the coordinator says so.

## Questions for Jacob

1. WebView2 spike now, before the desktop review (recommended), or after? (The stack
   session now runs the desktop toolkit spikes; this may be answered there)
2. Type: body and tables at 13.5 px (one size for both; today body is 14). Five sizes
   total: 11, 12, 13.5, 16, 22. OK?
3. Table headers as small caps-style uppercase 11 px (u.gg-like) or sentence case?
   Both in the gallery
4. Game events as a fight strip above the chart and death portraits on its edges
   (from the refs; game-detail.md and its mock): agree?
5. First page to rebuild: champion page (recommended: the most shared parts, deletes
   the filters.js twins) or Your games detail (the most visible change)?
6. The public app may not show numbers for picks (product rules), so CandidateList's
   tiers mode leaves ReasonBreakdown as direction-only chips ("into Yuumi ▲"), which
   says little. What should the public "why" show: words per reason, a ranked list of
   reasons, or the bars without numbers?
