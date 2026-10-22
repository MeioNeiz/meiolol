---
status: answered
priority: now
area: ui
tags: [web, web/wasm]
parent: zig-web-ui
description: Can meiolol's browser code be all Zig (wasm) plus HTML and CSS, with no hand-written JS, and what would remain, cost and break?
---
# Can meiolol's browser code be all Zig (wasm) plus HTML and CSS, with no hand-written JS, and what would remain, cost and break?

Feeds: docs/frontend-rework.md (Option A keeps a JS core; Jacob 22 Oct asks to drop JS
entirely); docs/plan.md "Now" item 3

## Answer

Zero JS is not possible: no browser lets wasm call the DOM, no proposal at any phase
would change that, and the smallest wasm page needs a JS loader (C1, C2). Reference
types and string builtins cut glue but suit JS-string languages, not Zig's UTF-8 (C3);
Zig 0.17's externref is half-working and removed in 0.18 (C4). Every Zig wasm UI found
keeps hand-written JS for the DOM (C7).

But all feature code in Zig is reachable, two ways, and they combine:

1. Zig islands through a bridge. zjb was broken on 0.17, but the fix is two @typeInfo
   call sites (C19). A spike ran meiolol's own tpl in the browser: render, re-sum on
   click, localStorage, fetch, escaping intact, 6.9 KB gzip, only a 5-line loader
   hand-written (C20). The same tpl component then renders on the server (no-JS, search
   engines, Riot reviewers) and in wasm (instant filters), which removes the Zig/JS twin
   logic by construction. Costs: we own a ~1,000-line MIT fork with a quiet upstream;
   handles need release, async is callbacks, strings cross by copy (C6, C21), so a thin
   dom.zig layer should hide them; release builds trap without a trace (C17).
2. Server fragments (hypermedia): ~48% of our JS is work Zig should do on the server
   anyway (C12); fragments from `meiolol render` suit our text-and-table pages (C9) and
   are the better fit where the data is too big to ship (Pool's player tallies).

The generic attribute runtime of C13 can itself be Zig through the bridge, so the only
JS left is the loader and generated glue. Wasm-driven DOM updates can match JS; startup
is where wasm frameworks lose (C5), which a 7 KB island mostly avoids; teams that moved
UI-adjacent code to wasm often gained little (C11), but here the gain sought is one
language and one component, not speed.

HTML/CSS takes dialogs, popovers, accordions and form filters with no script (C14), not
tabs, sorting or hover cards, and radio/`:has()` state hacks fail WCAG (C15, C16).

## Claims

- C1: No browser lets wasm call DOM or Web APIs without JS, and no proposal at any phase would change that as of Oct 2026. for: [[ehrenberg-wasm-dom-2025#^f1]], [[ehrenberg-wasm-dom-2025#^f6]], [[wasm-proposals-2026#^f4]], [[state-of-wasm-2026#^f2]]
- C2: The minimum JS is a loader calling `WebAssembly.instantiateStreaming` with an import object; ESM integration is phase 3 and unshipped. for: [[ehrenberg-wasm-dom-2025#^f2]], [[wasm-proposals-2026#^f1]], [[mdn-bcd-wasm#^f5]], [[zjb-017-build#^f3]]
- C3: externref, GC and JS String Builtins are in Chrome, Firefox and Safari 26.2+, but reduce glue rather than remove it; a UTF-8 builtin is phase 1. for: [[mdn-bcd-wasm#^f1]], [[mdn-bcd-wasm#^f2]], [[mdn-bcd-wasm#^f3]], [[ehrenberg-wasm-dom-2025#^f4]], [[wasm-text-encoding-builtins#^f1]]
- C4: Zig 0.17's externref works only in a narrow form and is removed in 0.18; integer handles stay the Zig pattern. for: [[zig-issue-31190#^f5]], [[zig-issue-35901#^f1]], [[zig-issue-35965#^f1]], [[zig-issue-35965#^f2]], [[ziex-repo#^f8]]
- C5: Wasm DOM updates can run within about 10% of vanilla JS, frameworks add 25 to 50%, and startup costs 1.4 to 10 times vanilla's first paint. for: [[jsfb-chrome154#^f2]], [[jsfb-chrome154#^f5]], [[jsfb-chrome154#^f6]], [[jsfb-chrome154#^f7]]
- C6: The boundary cost is string copying and many small crossings; fast designs batch DOM ops into one buffer. for: [[leptos-wasm-perf-truth#^f1]], [[leptos-wasm-perf-truth#^f3]], [[openui-rust-wasm-parser#^f2]], [[ziex-repo#^f6]], [[ziex-repo#^f7]]
- C7: Every Zig wasm UI found keeps hand-written JS for the DOM: Zig's autodoc (1,022 lines), Ziex (about 1,700 lines TS), zjb's loader. for: [[zig-autodoc-017#^f4]], [[ziex-repo#^f9]], [[zjb-017-build#^f3]]
- C9: Server-rendered HTML swaps suit text-and-image UIs with deep links and updates inside well-defined blocks. for: [[htmx-when-hypermedia#^f1]], [[htmx-when-hypermedia#^f3]]
- C10: Offline, frequent-update and highly interdependent parts belong client side as islands inside a hypermedia app. for: [[htmx-when-hypermedia#^f4]], [[htmx-when-hypermedia#^f5]], [[htmx-hypermedia-scripting#^f3]]
- C11: Moving UI-adjacent code to wasm often gains little: OpenUI's parser got 2.2 to 4.6 times faster back in TS, Zaplib's apps gained 5% to 2x. for: [[openui-rust-wasm-parser#^f3]], [[zaplib-post-mortem#^f2]], [[zaplib-post-mortem#^f3]], [[ziggit-zig-frontend-wasm-api#^f1]]
- C12 (inferred): Our public JS is ~48% server work, 13% HTML/CSS, 6% wasm logic, 33% glue (22 Oct inventory, docs/frontend-rework.md "All-Zig route"). from: C9
- C13 (inferred): One generic attribute-driven runtime plus Zig fragments puts every feature in Zig; script that exchanges HTML and keeps client-only state is the sanctioned rest. from: C9, C10, C12, [[htmx-hypermedia-scripting#^f1]], [[htmx-hypermedia-scripting#^f2]]
- C14: Dialogs and popovers open and close with no script in every core browser, iOS included, since Dec 2025. for: [[web-features-3-44#^f4]], [[webkit-safari-26-2#^f2]], [[web-features-3-44#^f1]]
- C15: Exclusive details groups give accordions, not accessible tabs; radio, checkbox and `:has()` state hacks fail WCAG. for: [[openui-exclusive-accordion#^f2]], [[openui-exclusive-accordion#^f3]], [[roselli-css-only-widgets#^f3]], [[roselli-css-only-widgets#^f5]]
- C16: Table sorting needs the DOM reordered or server-sorted pages; hover-only UI is Chromium only. for: [[roselli-css-only-widgets#^f4]], [[roselli-tables-css-display#^f2]], [[web-features-3-44#^f5]], [[webkit-safari-27-beta#^f6]]
- C17: Zig 0.17 Debug wasm has DWARF for Chrome but is far too big to ship; release builds have no symbols and panics trap without a trace. for: [[zig-wasm-dwarf-check#^f1]], [[zig-wasm-dwarf-check#^f3]], [[zig-017-release-notes#^f41]], [[zig-autodoc-017#^f5]]
- C19: zjb builds and runs on Zig 0.17 after changing two @typeInfo call sites. for: [[zjb-tpl-island-spike#^f1]], [[zjb-017-build#^f2]]
- C20: meiolol's tpl runs as a browser island through zjb (render, click, storage, fetch, escaping) at 6.9 KB gzip with a 5-line hand-written loader. for: [[zjb-tpl-island-spike#^f2]], [[zjb-tpl-island-spike#^f3]], [[zjb-tpl-island-spike#^f4]]
- C21 (inferred): zjb's ergonomics (handle release, callback async, string copies) want a thin dom.zig wrapper and a handle-count test. from: C6, [[zjb-tpl-island-spike#^f5]]
- C18: Filters as submitted forms with state in the URL are a proven no-JS pattern. for: [[asp-filter-component#^f1]], [[moj-filter-a-list#^f1]]

## Superseded

- C8 (superseded by C19, we patched it in two call sites): zjb does not compile on Zig 0.17 and upstream has been silent since April.

## Disagreements

- Small-app load time: Johnston (2023) says CSS-bound ([[leptos-wasm-perf-truth#^f6]]);
  the Chrome 154 run has Leptos first paint at 4.5x vanilla ([[jsfb-chrome154#^f6]]).
- htmx's 67% code cut is one team's port ([[htmx-when-hypermedia#^f2]]); our own
  inventory estimate (~82% of public JS gone) is the better guide and unproven.

## Open

- Round-trip latency of a fragment from meiolol-render on a phone (filters, Pool)
- Spike untested on Safari/iOS and phones; island size with float formatting and real
  data; fork upkeep per Zig release
- Zig DWARF stepping in Chrome not tried; Ziex page wasm size not measured
- Leads: vapor (Zig wasm UI), WebKit bug 308136 (string builtins with streaming)
