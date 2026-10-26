# Front end survey: the code before the rebuild

Read-only survey of src/site, src/site/static, src/tpl, the render server and the desktop
window, line numbers at 553b5fa (21 Oct). The plan that replaced its options:
docs/plan/ui/ (README.md, stack.md); direction: docs/frontend.md.

## 1. How a page is produced

### Writing HTML

- `src/tpl/root.zig` (821 lines, own build module, std only): `tpl.render(w, comptime
  src, args)` parses the template at compile time; holes are named, every hole needs a
  field and every field a hole; escaping by position (text, attribute, URL with scheme
  check, on*/style, script/style); `render` must balance tags, `renderPart` may not
  (layout pieces). Values: strings, numbers with fmt options, optionals, `t()` nested
  templates, `call(fn, args)`, `each(items, ctx, fn)`, `when(cond, v)`, `trusted`,
  `json`, `attr`, `flag`, and any struct with `render(self, w)` (a component).
  compile_errors.zig holds 31 templates that must fail to compile, run by `zig build
  tpl-errors`.
- Moved onto tpl 12-13 Oct, page by page, byte-identical (2b5d291, 203f4f5, d27fe85,
  6c0079c...). Usage now: ~270 render/t/renderPart calls, 98 `tpl.call`, 7 `tpl.each`,
  59 `tpl.when`, 11 `tpl.trusted`.
- Still raw writer calls for markup in places: builds.zig rune pages (47 `writeAll` of
  `<div class="rr">` etc., builds.zig:375-523), html.zig:329 `minGames` (w.print of
  `<select data-key="{s}"`, unescaped, key is program text), root.zig:509 role icon
  symbols, tierlist.zig:106 and 199, pool.zig:93, matchup.zig:154-189. src/admin.zig is
  all `w.print` (private page).
- Page shape: every page function calls `html.head(w, Page)` then writes its body then
  `html.foot` (html.zig:136, 303). `Page` (html.zig:96) carries title, nav, view and
  counterparts for the region/period switches. Pages are functions of (path, Site);
  `root.renderPage` and `renderShared` route (root.zig:385, 420).
- Templates are long single lines: 59 lines over 200 chars in src/site/*.zig, two over
  1,000 (champion.zig:91, tierlist.zig). Example, champion.zig:91 (cut):

      <div class="tiles"><div data-tile="wr"><span>Win rate</span><b class="wrc"
      style="--c:{colour};opacity:{fade:.2}">{wr}</b><small data-rank>{rank}{won}</small>
      </div><div data-tile="pick"><span>Pick rate</span>...

### Escaping

- Inside tpl: by context, compile-time checked, URL scheme checked at run time.
- Outside tpl: whatever the writer call does (nothing). Safe today because those calls
  write program constants and numbers, but nothing enforces it.
- JS side: `textContent` almost everywhere (good). innerHTML in filters.js (10 uses:
  snapshot/restore of server markup, and template strings of numbers in trackCell,
  filters.js:356-367) and review.js:188; chart.wasm SVG goes in as markup, trusted
  because tpl escaped the names in Zig (review.js:467-470).

### Data to JS

Four channels, chosen per page:

1. data- attributes on server markup: filters.js (22 `dataset.` reads), table.js (16),
   min-games.js (9), learn.js (16); `data-site`, `data-view`, `data-root` on script tags
   (html.zig:176, home.zig:76).
2. Inline JSON: only learn.zig:229-235, `<script type="application/json">` via `tpl.json`.
3. Fetched JSON: data/champions.json (fetched separately by review.js:50, pool.js:34,
   your.js:697, learn.js), data/pool.json, data/learning.json, data/search.json,
   data/filters/<slug>.json, daily/<n>.json, learn/practice.json, the Your games API.
   JSON is hand-written in Zig with writeAll (champs.zig:106-122, filters.zig:451-557).
4. Binary plus wasm: meiolol.wasm and patch/data/stats.bin for Learn's scorer
   (learn.js:529-531); chart.wasm renders lanechart.zig's SVG in the browser for Your
   games (chart_wasm.zig, a hand-packed little-endian input, no JSON).

Point 4 matters: the repo already runs a tpl component (lanechart.zig) in the browser
through wasm. That is the cheapest route to removing JS copies of Zig markup.

### Static assets

- Embedded with `@embedFile` (root.zig:280-298): style.css, favicon, inter.woff2 and 11
  JS files at the site root, pool.js and min-games.js again in every view directory.
- No fingerprinting: pages link `style.css`, `../table.js` by fixed name. nginx serves
  them `Cache-Control: no-cache` (docs/backlog.md:403); the renderer serves its own
  files no-cache too (serve.zig:268), rendered pages `max-age=3600` (serve.zig:373).
- No build step: no minify, no bundling, no transpile. Script tags are hand-written in
  each page module with hand-made relative paths: champion.zig:130 `"../table.js"`,
  tierlist.zig:340 `{table_js}`, learning.zig:169 `{up}table.js`, daily.zig:55, your.zig:71.
- Inline scripts in html.zig: localStorage view memory (head), `admin_link`
  (html.zig:198) and `meio_view` (html.zig:206) as JS in Zig strings.
- Sizes are fine: style.css 77 KB (16 KB gzip), largest page script review.js 41 KB
  (14 KB gzip), font 48 KB. Weight is not a problem to solve.

## 2. Duplication and inconsistency

### Markup patterns written per page

- Stat tiles: champion.zig:91 and matchup.zig:592 write near-identical win rate tiles
  inline; daily.js:419 builds its own `tile()` in JS; filters.js redraws the champion
  tiles by `data-tile`. CSS then re-tunes them per page for phones: `.mu-tiles` at
  style.css:881-884 and `.dd-tiles` at 985-987 are the same four rules.
- Boxes: four surfaces with drifting values: `.card` (radius 8, padding 10/12,
  style.css:163), `.tiles > div` (10, 10/14, :431), `.mu-card` (12, 12/14, :806),
  `.panel` (14, gradient and shadow, :500). Pages pick one by habit: Daily and Learn use
  .card, home and Your games .panel, matchup and builds .mu-card.
- Section headers: `.sec-h` (your.zig), `h2` in `.mu-card`, `.panel-h` (home, review.js),
  `.pool-h`, `.opp-h`, `.lesson-head`.
- Tabs and toggles: `nav.switch` (html.zig:277), `nav.tabs` (your.zig, matchup index),
  `.learn-tabs`, `.rv-seg` buttons built in review.js:581, the rank/mastery toggle in
  matchup.zig:693, Daily's side buttons.
- Tables: tierlist.tierTable, champion.opponentTable (a table drawn as a grid),
  matchup index, learning.zig, patch.zig, builds; each writes its own `<table>` and
  decides itself whether to add `data-sortable` and a `<script src=table.js>`.
- Colour legend: `tierlist.legend` reused (good), but the early-data note repeats the
  colour words in prose (root.zig:470).

### JS repeated across files (top-level definitions, admin files left out)

| helper | copies |
| --- | --- |
| `el(tag, ...)` DOM builder | 5, two signatures: (tag, cls, text) in daily.js:60, learn.js:46, review.js:29; (tag, attrs, ...kids) in pool.js:19, admin.js:135 |
| `$` = getElementById | daily, learn, your |
| `getJson` / fetch wrapper | daily.js:84, learn.js:517, admin.js:598, filters.js:23 inline |
| role table | daily.js:10, learn.js:7, your.js:13, pool.js:7, search.js:17 |
| `pct` | filters.js:506, learn.js:52, review.js:44, pool.js:58, admin.js:54: five meanings |
| `signed` | daily.js:49 and review.js:43 use U+2212, admin.js:524 too; filters.js `points` and all Zig use "-" |
| `norm` for search | min-games.js:16, pool.js:15, search.js:23 (only search.js strips accents) |
| `titleCase` | filters.js:33, your.js:22 |
| champion icon URL | 7 places build `https://ddragon.../img/champion/${key}.png` |

Visible result: Your games shows "−120" and the champion page "-120"; a percentage is
"12.3%", "12%" or "+12%" depending on the file.

### JS copies of Zig logic (the worst kind)

filters.js redraws the champion page's opponent table and tiles when the filters change,
so it re-implements the Zig cells and maths by hand, each marked "As <file>.zig ...":
trackCell (filters.js:356, tierlist.zig:139), usualCell (:370, champion.zig:411),
goldCell (:396, champion.zig:466), `usual` (:474, champion.zig:281), `points` (:483,
champion.zig:429), `wrColour` and its stops (:490, tierlist.zig:214), `fade` (as
curvesfile.fade), the colour spans. Some pointers are already stale: filters.js:14 and
:336 and table.js:1 cite `root.zig opponentTable` / `opponentLink`, which now live in
champion.zig. No test compares the two renderings. docs/design-ideas.md build order step
2 already plans to change wrColour, which means changing it twice.

The desktop draws the lane chart a third time (dvui plot, src/desktop/ui.zig:160-202)
beside lanechart.zig's SVG.

### CSS

- Tokens: colours only, and good ones (`:root` style.css:5-60: surfaces, text, the
  diverging scale `--lo4..--hi4`, fills, review colours). A few literals escape them:
  `--mu-x: #3f97ee; --mu-y: #f0596b` (:802), 23 `rgba()` (20 distinct), the brand
  purple as `rgba(139,124,246,...)`, SVG icon colours as hex in home.zig:70-72.
- No spacing, type or radius scale: font sizes 7, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13,
  13.5, 14, 15, 15.5, 16, 17, 18, 20, 21, 22, 24, 26, 28, 30, 32, 36 px (25 values);
  radii 1-14 px and 999 (13 values).
- Breakpoints: 380, 480, 600, 640, 760, 980, 1000, 1100 max/min (9 distinct, 25 @media
  blocks), each added where a page overflowed.
- Naming: 386 classes. Page prefixes for about a third (dd- 33, pz- 19, mu- 18, rv- 8,
  h2h- 6, lesson- 5...). 95 classes of 1-3 letters (`d`, `g`, `l`, `x`, `bk`, `rr`,
  `rt`, `rx`, `og`...), meaning set by the parent: `.ci .d` is a dot (:413), `.moments
  .d` a delta (:596); `table.tl .l` is left-aligned (:391), `.film .l` is a loss (:648).
- Specificity: mostly flat, 12 `:has()`, 2 `!important`, 6 id selectors. One fight on
  record: `main.wrap` exists because `.wrap`'s padding shorthand beat a `main` rule
  (comment at :135, fixed in 38b940f after a reviewer saw headings on the preview bar).
- Classes JS builds from data: `badge c-${kind}` (review.js:165) ties CSS to an enum in
  review.js; a rough grep can't see them, a rename breaks silently.
- Dead rules: small. Of 386 class names only `matchup-list`, `lesson-done`/`todo` and
  `reveal-summary` appeared nowhere in Zig or JS; removed 23 Oct with the unused
  `--f-*` and `--bar-hi` tokens. Not a structural problem.
- Dark mode: dark only (`color-scheme: dark`), no light theme; fine, but tokens make a
  later light theme cheap.
- One global file: every page loads all 1,213 lines; 235 lines over 90 chars (one-line
  rules). admin.css (380 lines) is a separate world with its own values.

## 3. Bug classes the setup invites (from git log, 250 site commits since 11 Oct)

60 of the 250 commits touch a page .zig and a static .js together, 54 a page .zig and
style.css: most UI changes span two or three languages with no check between them.

| class | examples |
| --- | --- |
| Script not loaded or loaded in the wrong place | 553b5fa: pool page's learning table had `data-sortable` but the page never loaded table.js |
| JS finds DOM by structure, markup moves | 0406809: table.js found the table by sibling order; a gradient `<svg>` between search bar and table gave a TypeError on every keystroke on Champions, role and champion pages |
| Page lifecycle | 9f5fe61: Back restores search text after the script ran, so the matchup index showed all 4,029 links; c7f4003 (admin): a 30 s re-render closed the open row and cleared the search because state lived in render locals; 7b4e07e (admin): every render started a 4.6 MB model load |
| Phone overflow found by hand | fa80f13 (Your games lane table 380 px in a 358 px panel), 7ef3a20 (champion tables 382/366/373 px at 390), 1911314 (Daily lanes), 79b97a1 (every table at 360-480), c7336a2 (Learn) |
| CSS cascade surprises | 38b940f: `.wrap` shorthand beat `main`; td.wrap lost its padding; SVG text 22 px on desktop, 7 px on phones |
| Layout shift from conditional markup | 268aa10: unranked seat's champion slid right because the rank span was missing |
| Formatting drift | 2137f1d and the night run: thousands separators added page by page ("QA"); the minus sign differs by file |
| Deploy ordering of pages and assets | render-swap.sh:9-12: a new renderer served new pages with old CSS/JS for 25-110 s (20 Oct), so the swap now waits up to 30 min for the upload |
| Stale cross-references | JS comments pointing at moved Zig functions (section 2) |

The common root: markup, the scripts that read it, the CSS that styles it and the logic
that colours it are four separate files with no declared contract.

## 4. JS coupling to the Zig DOM, build steps, checks

- Skeleton pages are id-driven: your.js 48 id lookups, learn.js 38, daily.js 24 against
  the skeletons in your.zig, learn.zig, daily.zig. All ids they read exist today (checked
  by script: the three not in the skeletons, `recent`, `example-roles`, `back`, are made
  by the JS itself), but nothing checks it.
- Enhancement scripts are selector-driven: filters.js 32 querySelector calls (section
  ids, `.tiles`, `[data-tile]`, `.tl-more`, `[data-show-all]`, `[data-reset]`), table.js
  and min-games.js by data- attributes.
- Shared code is by globals and order: review.js defines `Review` (review.js:7) for
  your.js and home.js; reasons.js defines `detectedReason`/`reasonWords` for daily.js and
  learn.js. Order is the order of the `<script>` lines in your.zig:71, home.zig:75,
  daily.zig:55, learn.zig:232. Classic scripts with "use strict", no ES modules.
- Build: none. `@embedFile` and serve. CI: `node --check` per file (build.zig:159), a
  syntax check only. No lint, no type check, no run.
- Dev loop is good: `meiolol dev` serves CSS/JS from disk and reloads on edit; a Zig
  template edit is ~20 s (architecture.md "Website").

## 5. Tests

What pipeline_test and the site tests check (src/pipeline_test.zig, 26 tests in
src/site/*.zig):

- Golden hashes of every generated non-asset file (expectSiteFiles, pipeline_test:910,
  src/testdata/site-files.txt, 151 files). commit.sh rewrites it on every commit, so it
  says "these pages changed", never what changed. It is what made the tpl migration
  provably byte-identical; it will do the same for a component refactor.
- Substring contracts: ~40 exact markup fragments per page type (pipeline_test:186-242),
  e.g. `<div class="tiles mu-tiles">`, `<tr class="bx thin" data-id=`. Brittle by design:
  any class rename means editing these.
- DOM contracts, two only: every `data-filter`/`data-for`/... target id exists
  (pipeline_test:271-300, after 0406809), and no `data-sortable` page without table.js
  (:314, after 553b5fa). Both added after the bug.
- Static build equals rendered-on-request bytes for every file (:303-320), views file
  round trips, `--static core` lists.
- write.zig:190-214: view links, switches, script tags.

Impossible now:

- Running any page's JS (no DOM in tests): Your games, Daily, Learn, Pool, filters.js
  redraw, search, review are untested apart from `node --check`.
- Checking that filters.js's redraw equals the Zig rendering.
- Layout: overflow at 390 px, text size, overlap; QA is manual through `browse`
  (docs/plan/site.md:35, :294, :305). The night run already had a Playwright script for
  design measurement (data/team/2026-10-19-night/design-proto.mjs, using
  ~/personal/browser-tool), so the tool exists on the Mac.
- Console errors and missing assets on load.
- Desktop: `desktop-shot` renders PNGs (good), no assertions on them.

## 6. Constraints any rework must keep

- Zig-only native code; JS and CSS are already shipped, so "Zig-only" constrains tools,
  not the browser. No Node build step in the shipped path (CI's `node --check` is the
  only Node use).
- Static nginx core plus `meiolol render` with byte-identical output between the two
  (pipeline_test). The home page must stay static (hosting.md "Rendering on request").
- No external scripts or fonts: confirmed. The only third-party host is Data Dragon for
  champion and profile icons (10 references), with `referrer: no-referrer` (html.zig:136).
- Traffic counting depends on `/style.css` being fetched on every page load
  (traffic.sh:8-12, no-cache). Hashed immutable CSS breaks it unless a tiny no-cache
  beacon replaces it.
- Deploys: the renderer swap waits for the upload because asset names don't change
  (render-swap.sh:9-12). Hashed names plus the renderer serving its own assets as
  nginx's fallback removes the wait.
- Product rules (production-key.md): no "+X% win rate", several options with reasons.
  Content, not structure, but components with fixed wording help keep it.
- Preview mode, noindex, the banner, privacy (no names in champ select views).
- Pages must work without JS where they do today (stats pages, lookup form fallback).
- Many sessions edit the tree at once: a big-bang rewrite would conflict with every
  in-flight page change. Migration must be page by page, each commit small.

## Desktop app (meiolol-app, meiolol-desktop)

- `meiolol-app` is a CLI (suggest, watch, session, get, cards); the window is
  meiolol-desktop: dvui (immediate-mode Zig GUI, pinned PR #1012), dx11 on Windows, SDL3
  for the Mac dev window, raster backend for `desktop-shot` (architecture.md "Desktop
  window").
- UI code: src/desktop/ui.zig (278 lines) draws src/lanecard.zig's data. Theme
  `adwaita_dark` (ui.zig:52); its own ahead/behind colours `#4fb37a`/`#d0605e`
  (ui.zig:48-49), green/red, while the site's principle is blue/orange, colour-blind
  safe (design-ideas.md principle 2); its own lane chart (ui.zig:160-202).
- Shares with the site: data and maths only (lanecard.zig, core.score, curves files),
  and Riot boilerplate text. No HTML, CSS, JS, tokens or chart code.
- Jacob's 19 Oct list (docs/plan/app.md) wants every role, hovers, bans, pool, comp
  notes, champion icons (not done: app.md APP8).
  That is a dashboard-sized UI; in dvui each layout, icon and table is hand-placed Zig.
- So: the site's CSS/JS/templates are not what slows app work today. If Jacob's "app
  development" means the desktop, the pain there is dvui, a separate decision. If it
  means the site as a web app, it is the rest of this document. Worth asking him.

## Pain that is not structural

- Design decisions (density, what colour means, what hides on a phone) are design work;
  docs/design-ideas.md already has the rules. Components make them stick, they don't
  make them.
- Velocity: 250 site commits in 10 days from many sessions. Drift follows from that in
  any stack; components and lints only lower its cost.
- Copy and policy wording (no win chance numbers, "few games") is content.
- tpl itself is good and the dev loop is fast for CSS and JS; Zig template edits are
  ~20 s, which no option here changes much.
- Phone overflow on dense tables is partly inherent: a rule per table of which columns
  fold at 480 px is needed whatever renders them.
- Dead CSS is negligible (about three rule groups).
