---
status: answered
priority: soon
area: ui
tags: [web, toolchain]
description: Could a Zig library or framework replace meiolol's hand-written w.print HTML and vanilla JS, and what would it give us?
---
# Could a Zig library or framework replace meiolol's hand-written w.print HTML and vanilla JS, and what would it give us?

Feeds: how the site's UI is written (src/site); whether to build our own small Zig HTML
and wasm UI layer

## Answer

Nothing mature fits as a drop-in. The Zig web UI space is young: the candidates are a
template language (Zmpl, C1), a JSX-like framework whose client side is unfinished and
whose current line needs Zig 0.17 (Ziex, C2), a one-author pre-1.0 framework that ships
a server binary rather than a static site (Verve, C3), a comptime DSL on zigmod and 0.15
(Pek, C4), and a DOM bridge that needs a TypeScript host from npm (thi.ng, C5). dvui has
a web backend but draws its own widgets, which suits an app, not a text-heavy stats site
(C6).

Interactivity in Zig is possible without any of them: meiolol already compiles the
recommender to wasm32-freestanding and calls it from learn.js (docs/architecture.md,
Website). The pattern every DOM bridge uses is integer handles for JS-side elements plus
a few exported functions (C5).

Interop libraries are the better fit than frameworks: they only do that bridge and leave
the UI to us. zjb works on Zig 0.16 and generates the JS glue from the wasm with a Zig
tool, so it fits `zig build` with no Node step (C9). zig-js covers only Zig calling JS
and its glue is unpublished TypeScript (C10); Zigar goes the other way, JS apps
importing Zig through a bundler (C11).

So: no framework as a dependency (C7). Write our own small HTML component layer for the
static pages, taking ideas from Ziex (typed components), Zmpl and Pek (comptime-checked
templates) and Verve (static HTML with interactive islands). For the islands, either
write the handle bridge ourselves or use zjb (C12). npm is not ruled out by anything in
the repo; it is just not needed for any of this.

## Claims

- C1: Zmpl compiles HTML templates to Zig with Zig control flow and partials, but feeds them JSON-like dynamic data and declares Zig 0.15.1. for: [[zmpl-repo#^f1]], [[zmpl-repo#^f2]], [[zmpl-repo#^f3]], [[zmpl-repo#^f4]]
- C2: Ziex components are Zig functions in JSX-like syntax with static export; SSR is stable, client rendering is not, and its current release needs Zig 0.17. for: [[ziex-repo#^f1]], [[ziex-repo#^f2]], [[ziex-repo#^f3]], [[ziex-repo#^f4]], [[ziex-repo#^f5]]
- C3: Verve does SSR plus wasm islands with signals on Zig 0.16 but is one author's pre-1.0 project and outputs a server, not static files. for: [[verve-repo#^f1]], [[verve-repo#^f2]], [[verve-repo#^f3]], [[verve-repo#^f4]]
- C4: Pek shows a comptime HTML DSL is feasible but is packaged for zigmod and Zig 0.15. for: [[zig-pek-repo#^f1]], [[zig-pek-repo#^f2]]
- C5: Zig-to-DOM bridges keep DOM objects in JS and pass integer handles, with events bound from Zig; thi.ng's needs its TypeScript host. for: [[thing-wasm-api-dom#^f1]], [[thing-wasm-api-dom#^f2]], [[thing-wasm-api-dom#^f3]], [[thing-wasm-api-dom#^f4]]
- C6 (inferred): dvui's web backend runs a whole drawn app in the page, wrong for a text and table site that should read without JS. from: C8
- C8: dvui ships a web backend served as static files. for: [[dvui-repo#^f15]]
- C7 (inferred): No framework fits meiolol's static, Zig 0.16 site as a dependency; write our own small component layer borrowing their ideas. from: C1, C2, C3, C4, C5
- C9: zjb calls JS from Zig wasm through released handles, exports Zig callbacks, works on Zig 0.16 and generates only the JS glue used, with a Zig tool. for: [[zjb-repo#^f1]], [[zjb-repo#^f2]], [[zjb-repo#^f3]], [[zjb-repo#^f4]], [[zjb-repo#^f5]], [[zjb-repo#^f6]]
- C10: zig-js covers only Zig calling JS, needs deinit per value, and its JS glue is not yet on npm; declares Zig 0.15.1. for: [[zig-js-repo#^f1]], [[zig-js-repo#^f2]], [[zig-js-repo#^f3]], [[zig-js-repo#^f4]]
- C11: Zigar targets JS projects importing Zig, through bundler plugins for wasm. for: [[zigar-repo#^f1]], [[zigar-repo#^f2]], [[zigar-repo#^f3]]
- C13: LoLalytics is not static: Qwik renders each page on a server from a separate data API, and it has no login. for: [[lolalytics-stack#^f1]], [[lolalytics-stack#^f2]], [[lolalytics-stack#^f3]]
- C12 (inferred): For interactive islands, zjb is the one interop library that fits as is; writing the bridge ourselves is the alternative if we want all of it to be ours. from: C5, C9, C10, C11

## Disagreements

None between sources; they target different shapes (server app, static site, canvas app).

## Open

- Zmpl on Zig 0.16: does it build? Its data model (ZmplValue) not read
- Ziex client-side design (wasm + JS bridge?) not documented yet; revisit at its 0.1.0
- Size and speed of a Zig-wasm-rendered table versus plain JS on a phone, not measured
- zjb not built in meiolol yet: glue size, how it sits next to the existing draft.wasm
- 4 searches only (discovery still growing); not searched: GitHub topic zig+html. Zine
  and SuperHTML read for the template layer: [[zig-html-templates]] (need Zig 0.17-dev)
