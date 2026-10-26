# UI stack: decided per layer, on spikes

Plan (team run 2026-10-24-ui, stack session). Jacob 24 Oct: "ready to build up the
whole front end stack ... if the way we write our templates doesnt scale well we can
start from the bottom. I am thinking extremely long term". Components, guardrails and
pages: README.md in this folder; this file decides what they are built on. Spikes,
harness and raw numbers: data/team/2026-10-24-ui/spikes/ (BRIEF.md, each REPORT.md,
measure.json); desktop sources: research/questions/desktop-toolkit.md.

## In one screen

- Components become a typed node tree in Zig, not HTML strings. One `view` function per
  component gives three outputs: HTML on the server (tpl's escaper inside), keyed DOM
  patches in ui.wasm, and a tree that plain `zig build test` checks with no browser
- Browser runtime: islands, each a component struct with typed messages; every event
  rebuilds the island's tree and a keyed diff patches the DOM. Focus, selection,
  scroll, pointer capture and an open row all survive by construction, with no glue per
  component. Server HTML is adopted, not re-created
- Styles: CSS beside each component (`pub const css`), collected at comptime with tokens
  from one Zig source into one hashed file; layers and the legacy file as README says
- Words: a typed phrase catalogue beside each component; holes formatted by fmt.zig;
  word counts from the test tree, as warnings
- Desktop: the system webview (WebView2 on Windows, WKWebView on the Mac) driven from
  Zig, showing the site's own components. dvui goes
- Mainstream TS + Solid was as fast and correct, but splits logic across two languages
  and needs Node (or a 94 MB Bun binary) wherever HTML is rendered. All Zig wins; the
  price is ~2k lines of runtime we own (growing to ~3.5k), plus the zjb fork
- Changes README's build order: the tree runtime comes before the component set, and
  the desktop shell can start beside it (Order below)

## How it was decided

Four spikes, 24 Oct, each building the same two components (README's DataTable as the
champions list, 862 rows, and the TimelineChart with range select and moment stepping)
on the same fixtures, measured by one Playwright harness (Chromium at 1x and 4x CPU
throttle, WebKit, phone 390, JS off): zig-tpl (today's plan at its best: tpl strings,
ui.wasm through zjb), zig-tree (a typed node tree with HTML, patch and test backends),
ts-solid (TypeScript, Solid, Vite, CSS modules), desktop (toolkits from scratch, a
WebView2 shell on the gpu-box).

| Chromium unless said | vanilla baseline | zig-tpl | zig-tree | ts-solid |
| --- | --- | --- | --- | --- |
| table ready ms (1x / 4x / WebKit) | 26 / 49 / 43 | 71 / 246 / 165 | 77 / 292 / 180 | 74 / 320 / 118 |
| sort ms (1x / 4x / WebKit) | 10 / 33 / 12 | 28 / 124 / 57 | 24 / 109 / 51 | 23 / 103 / 61 |
| our code in a sort | | wasm 2-4 | wasm 1.1, patch 2.3 | script 3-9 |
| chart drag move ms (1x / 4x) | 1.1 / 3.5 | 1.3 / 4.1 | 1.0 / 3.7 | 1.4 / 3.9 |
| focus, open row, rows kept, scroll, capture, selection, URL | no | all | all | all |
| JS off: table rows | 0 | 260 | 259 | 259 |
| code shipped, gz KB | | wasm 27.7, JS 2.1 | wasm 27.1, JS 3.0 | JS 12-13 |
| table.html gz KB | | 16.2 | 15.5 | 36.8 (hydration marks) |
| component lines / glue per component | | 549 / 484 | ~800 incl. CSS / none | 731 incl. CSS / none |
| runtime we own | | 428 | ~1,870 | 59 + 118 Zig to TS types |
| third party | zjb fork 954 | zjb fork 954 | zjb fork 954 | 141 npm packages, 116 MB |
| build | | Zig only, 3.7 s per edit | Zig only, 1.8 s warm | Node, 1.5 s warm |

The baseline renders 3 plain columns by innerHTML and keeps nothing (no focus, no open
row, no URL): it is the floor, not a rival. Between the three real stacks speed is a
tie: most of a sort is the browser's style and layout of 259 rows of 9 rich columns
(an innerHTML rebuild of the same rows costs 28.6 ms). So the decision rests on
correctness by construction, one source of logic, what we own, and how it scales to
~60 components with several sessions editing.

## 1. Component representation: a typed node tree

Decision: components build a tree with a Zig builder; tpl stays for page shells and long
static prose, and its escaping code is the HTML backend's core.

```zig
fn row(t: *Table, h: *H, i: u16, rank: usize) N {
    const x = &t.rows[i];
    return h.tr(.{ .key = i, .class = h.cls("", .{ .thin = x.g < 1000, .off = x.s < 10 }),
        .on_click = h.on(t, .{ .open = i }) }, .{
        h.td(.{ .class = "num rk p-hide" }, .{rank}),
        h.td(.{ .class = h.cls("num", .{ .sorted = t.key == .w }) }, .{heat(h, x.w)}),
        // champion link, role, patch arrow, pick, ban, score, games
    });
}
```

Evidence:
- zig-tpl: the same Zig renders on both sides, but the browser half is hand glue as big
  as the components (484 lines against 549): kept node handles, `closest` chains, state
  synced to the DOM by hand, a URL codec per island, and every handle released by hand
  (a miss leaks silently). It grows with each interactive part: the coordinator's worry,
  confirmed. setHtml was still needed for the inspector (loses selection and focus)
- zig-tree: no glue at all; every keep check passes in both engines; 17 tests in plain
  `zig build test` drive clicks and drags through the same handlers ui.wasm runs and
  check labels, button names and word counts on the tree
- Escaping: no raw HTML node and no script or style element exist, so only two contexts
  remain (text, attribute value), both tpl's escaper. URLs pass tpl's scheme check when
  the node is built, so the browser path is checked too (tpl islands only check server
  side). `on*`, `srcdoc` and string `style` are compile errors; `style` takes numbers
  through `h.vars`. Lost: tpl's tag-balance parse, which the tree has by construction
- Loop-dependent classes (`h.cls("rr", .{ .ks = i == 0 })`) are the easy path, which is
  what builds.zig's 46 raw `writeAll` calls lacked (meiolol-44's audit)

What we own: tree and builder (~470 lines), HTML backend (~35, plus three tpl functions
made `pub`), check backend (~80), compile-error tests for the attribute guards.

Watch: wasm size. A generic `el(attrs: anytype, ...)` instantiated per call site cost
~450 B gz per element (45 KB for two components); a thin typed front over one
`noinline make` brought it to ~270 B. tpl islands have the same trap (~1 KB gz per
template-heavy component). A per-component size line in ci, from day one.

## 2. Client runtime: islands with keyed patching

Decision: islands, not a client-side app. A page is server HTML with zero or more
islands; each island is a component struct:

```zig
pub const Table = struct {
    pub const Msg = union(enum) { sort: Key, role: i8, min: u32, search, open: u16 };
    pub fn update(t: *Table, m: Msg, ev: *tree.Event) void { ... }
    pub fn view(t: *Table, h: *H) N { ... }
};
```

- State lives in the struct, never in the tree or the DOM; each event rebuilds the
  island's tree (1.1 ms for 10,409 nodes) and a keyed diff (prefix, suffix, key map,
  longest increasing run) patches the DOM. A sort moved 224 of 259 rows and created none
- Events: one listener per event kind at the island root; `h.on(component, msg)` stores
  a typed message; Zig bubbles to the first handler. No closures, no handle juggling
- Hydration: the first tree is built from the server's default state and adopts the
  existing nodes in pre-order (one call); URL state is patched in after
- Patching goes out as an op stream. In the browser the ops are applied by zjb calls
  one by one or by a 72-line generic JS applier reading one buffer: measured the same
  (sort 24.0 against 24.5 ms; a role switch's 24k calls 6.9 against 7.4 ms). Use zjb
  calls: Jacob's "no JS beyond a loader" (22 Oct) holds at no cost; the same op stream
  drives the fake DOM in tests. Revisit only if profiling shows crossings matter
- URL: state worth sharing (role, sort, search, a moment, a range) is a field set
  encoded by one comptime codec from the struct (both spikes hand-wrote ~40 lines per
  island). Search typing replaces the history entry; a sort pushes one
- Multi-page stays: pages are static files (nginx, `meiolol render`); Your games is
  one island with its views in the URL, not a client router
- Data: what the server renders, it renders (the default state only); other states come
  from a small binary file encoded from the same Zig struct (zig-tpl and zig-tree both,
  no JSON in wasm) and rendered by the same component. This replaces today's hidden
  pre-rendered variants (champion.zig `variant()`, 11 of 16 view blocks hidden on
  champion/ahri.html) and fixes page weight: champions.html is 1.73 MB today (850 KB of
  it a spread SVG per row); the spikes' server table is 16 KB gz with every row
  reachable
- One ui.wasm per page family if the 40 KB gz budget is reached (stats, games, play).
  Floor per file: runtime + std ~20 KB gz (decode, tree, island, diff, dom, zjb, url).
  A family over 40 splits into files of its own, ~10 KB gz of runtime repeated in each
  (champion, 27 + 31 + 37 KB gz: ui-champion.wasm the head, ui-champbuild.wasm the build,
  ui-champmore.wasm the matchups and below): the first loads the others when their
  island nears the viewport or after it hydrates. The runtimes share the fragment (each
  keeps the keys it doesn't own)

What we own: diff (~155), ops and fake DOM (~150), island (~135), dom on zjb (~130),
fmt (~105), data codec (~100), URL codec. Still to build (zig-tree report): several
islands per page, ops for focus, scrollIntoView, popover and dialog, resize, fetch steps,
memoised subtrees, a dev hydration check. ~1.9k lines now, ~3.5k for 60 components.

Gotchas found (each goes in the runtime or the CSS lint once):
- WebKit resets page scroll when rows holding `<svg><use href="#sprite">` move inside a
  `container-type: inline-size` ancestor (either alone is fine; zig-tpl repro
  probe/wkscroll2.mjs). README keeps `@container`, so icons become CSS-masked spans
- Moving a row drops focus inside it (Chromium's `moveBefore` keeps it but scrolls the
  row into view): the patcher refocuses without scrolling; move only shown rows
- WebKit dropped a pointerdown when an element patched on every move sat under the
  pointer: `pointer-events: none` on chart children, events on the plot
- A `display` rule on a `[popover]` element keeps it open: display only under
  `:popover-open` (foundation's gallery)

## 3. Styles: beside each component, one hashed file

Decision: each component declares `pub const css` next to its view; tokens come from
`tokens.zig` (one source that writes tokens.css and can give the desktop a native theme
if ever needed); a comptime list of components is bundled with tokens, base and legacy
into `style.<hash>.css`. README's layers stand (`tokens, base, legacy, components,
pages`), as do container queries and the three page breakpoints.

- Why beside the component: several sessions edit at once; a component and its rules
  move, review and get deleted together, and nobody edits one 1,400-line file
- Scoping is a convention a test checks: every selector starts with the component's
  `.c-<name>`. Not hashed class names: the server, wasm and tests all write the same
  names, and readable names keep qa.sh and screenshots legible
- "Unused rules gone" holds per component (only listed components ship). Inside one,
  dead rules show only against renders of every state: the gallery provides them, and
  the test reports classes no state emits
- The CSS lint (README) runs on the bundled text: colours only from tokens, the five
  type sizes, three breakpoints, no `!important`, popover display rule. Warnings first
- Not a utility approach (Tailwind-like): it puts styling words into every one of 862
  rows' markup, needs its own generator, and moves design decisions into call sites
  where several sessions would drift them apart
- ts-solid's CSS modules gave the same co-location but hashed names any non-Solid
  renderer needs a map for

## 4. Words: a typed catalogue, beside the component

Decision: every visible string is a `Phrase` declared beside its component (or page):

```zig
const change = Phrase("16.20 {a:rate} of {an:count} to 16.21 {c:rate} of {cn:count}");
// change.with(h, .{ .a = x.a, .an = x.an, .c = x.c, .cn = x.cn })
```

- Holes are typed by formatter kind and checked against the args at compile time, then
  written by fmt.zig, so "8,068 games" and the minus sign come out one way everywhere
  (meiolol-44: wording and numbers drift apart when phrases are plain strings)
- The test tree counts visible words per page and checks label length: warnings by
  default, a page can raise a check to an error (Jacob 24 Oct: direction, not rules)
- One place to edit a component's words; a generated list of every phrase for review.
  A second EUW language later is a second set of the same shape; nothing built for it now
- Not one global strings file: it would be the most conflicted file in the tree

## 5. Desktop: the system webview, driven from Zig

Decision: the app becomes a native Zig shell around the system webview (WebView2 on
Windows, WKWebView on the Mac for the dev loop) showing the site's own components, CSS
and ui.wasm. dvui goes. Jacob widened this question (24 Oct: "dvui was a very early
decision"); every candidate was judged from scratch (desktop REPORT.md).

Measured on the gpu-box (Windows 11, League closed): a Windows exe built on the Mac
with zig, no C++, no Microsoft loader dll, no Node. First paint 0.27 s warm (1.1 s on
the very first run); idle CPU 0.2 to 0.4% of a core (dvui 0.3%); pushing a champ select
state once a second 1.4%, painted 1 to 4 ms after the push; exe 3.5 MB (code 0.9 MB,
the rest embedded pages and icons). zig-tpl's table ran with its ui.wasm unchanged. A
topmost, no-activate panel for the in-game companion: +20 MB, opens in 15 ms. The same
pages ran in a WKWebView window on the Mac.

The cost is memory: WebView2 brings 7 processes and 200 to 290 MB private on top of
the Zig host's data (Porofessor and iTero, Electron, cost about the same). dvui wins
only on that; it loses one UI (every app component drawn twice, its own theme, a third
chart system), accessibility and text quality. Our own GPU renderer of the tree would
keep memory low but means owning a layout and text engine. CEF, Electron and Tauri add
a runtime or toolchain for what the system webview already gives; Dear ImGui looks like
a dev tool. Riot and Vanguard rules rule no toolkit in or out: the in-game panel as a
separate topmost window is the least exposed route; injected overlays are out for all.

- Survives as is: poller, update, setup, device, install, sign, icons, selftest
  (~1.9k lines), lanecard.zig and core. Rewritten as site components: the 2.2k lines of
  dvui drawing. Gone: raster.zig (CapturePreview or headless Chromium shots instead)
- Self-update and signing unchanged (one signed exe; pages inside it, or later a signed
  data file so UI fixes ship without an exe swap). Add a runtime presence check
- Risk: the spike's loader calls an undocumented entry point in the WebView2 runtime
  (as webview/webview does); fallback is Microsoft's 190 KB loader dll beside the exe
- Not yet measured: League open, 150% scaling. Both go in the shell's first step

What this does to question 1: the app needs only HTML from the same components, so no
native backend for the tree; the op stream could feed one later if memory forces it.

## 6. The mainstream alternative, and why not

TS + Solid + Vite was the quickest to correct, keyed, focus-safe components (a few
hours, every check passing), with mature tooling and HMR. It loses on what Jacob weighs:

- One source of logic: the colour step, pulled win rate and formatters would exist in
  Zig (13.7k matchup pages, the box's renderer) and TS both, unless the server ships
  every derived value; types need a Zig-to-TS generator (118 lines in the spike)
- Server HTML: Zig can't write HTML that Solid hydrates. The routes are to replace Zig's
  HTML on load (markup written twice, typed text and focus lost) or to move page
  rendering to Node or a 94 MB Bun binary on the box. Hydration cost as much as a fresh
  render and doubled HTML gzip
- Upkeep: 141 packages, 116 MB; Solid 2.0 is a reactivity rewrite at rc.18, Vite went 6
  to 8 in two years: a few days a year, forever
- What all-Zig costs instead: ~1.9k lines of runtime now, ~3.5k later, the zjb fork
  (954 lines, each Zig release may break it; the 0.17 fix took 10 lines), size
  discipline in wasm, and no ecosystem components (none would fit ours anyway)

## Order (changes README "Build order")

README built ui.zig components on tpl first and ui.wasm in step 4. With the tree, the
runtime is the base every component stands on, so it moves first; the desktop shell is
independent of components and can run beside it.

1. Tokens and layers (1-1.5 d, as README step 1), with tokens.zig as the source and the
   component CSS bundler
2. Tree core (3-4 d): tree and builder, HTML backend on tpl's escaper (three tpl
   functions `pub`), fmt.zig, Phrase, check backend with warning levels, URL codec,
   binary data codec; port from spikes/zig-tree with tests. Size line in ci
3. Island runtime (2-3 d): diff, op stream, dom on the zjb fork (pinned in
   build.zig.zon), hydration, several islands per page, focus and popover ops, the
   gotchas above; one real island first (champions list: deletes table.js and part of
   filters.js), checked on iPhone Safari
4. Gallery and qa.sh (2 d, README step 3): the gallery renders every state from the same
   view functions; component overflow checked at 320 and 390 px container widths
5. Core components and the chart system (README steps 2 and 5, 4-6 d), on the tree
6. Desktop shell (2-3 d, can start after step 1, beside 2-5): win.zig and mac.zig from
   spikes/desktop to production (window state, single instance, runtime check, loader
   fallback, typed channel, release script, League-open and 150% runs), then the app's
   screens as site components (1-2 weeks, less as the site's land)

Foundation grows from README's 11-13 days to about 13-16; pages follow as README lists.

## Questions for Jacob (24 Oct)

1. Desktop memory: the webview app costs 200 to 290 MB more than today's dvui window
   while League runs (the same as Porofessor or iTero). One UI for site and app at that
   price (recommended), or keep memory low with a second UI?
2. ui.wasm through zjb calls with no JS beyond the loader (recommended, measured the
   same), or allow the 72-line generic op applier as the one other JS file?
3. Several ui.wasm files per page family when the 40 KB budget is reached, or a larger
   budget for one file?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. One UI; the extra 200 to 290 MB is acceptable. Efficiency over dev ease otherwise:
   page load and page speed are not traded away
2. zjb calls, no JS beyond the loader
3. Several ui.wasm files per page family (each page loads only its code)

## Jacob's answers (review v6, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v2-*.

1. CSS cached a year by its hash (nginx rule on jomify, separate traffic beacon): do
   it now, with the island runtime work
   Done 25 Oct: hashed names (src/site/assets.zig) for the CSS, font, search.js and the
   islands' loader and wasm, immutable in nginx; beacon /print.css (media print);
   docs/hosting.md "Cache-Control"

## Jacob's answers (chat, 25 Oct evening)

1. In-game companion: the private edition, certainly. The public edition gets something
   more helpful within policy: in-game contextual builds and helpful info
2. Desktop measurements (in-game CPU, poller against the real client, focus-taking run)
   wait until he plays; they don't block building the app's screens
3. In game "we will need overlay": the spiked topmost no-activate window (borderless
   League only; injected overlays out), within policy (research/areas/policy.md: opt-in,
   clear of minimap, scoreboard, shop and ability bar, own look, no enemy timers). Ask
   Riot in the production key application or a support ticket
4. Private edition in game: item recommendations and the like (live advice the public
   edition can't show). Later, "we can get there when we get there"
5. Long term: our own renderer of the component tree in place of WebView2 ("for fun"
   and for learning; low priority). What it takes: CSS subset (style resolution),
   layout (flex, grid, container queries; Clay or Yoga as a start), text (DirectWrite,
   Core Text), painting (dvui's backends?), input and focus, the island runtime on our
   own DOM, accessibility. Gain: tens of MB instead of 215-300. First step when picked
   up: a week's spike drawing the lane card through Clay and DirectWrite, measured
