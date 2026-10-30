---
status: decided
decision: docs/plan/ui/stack.md#3-styles-beside-each-component-inlined-per-page
priority: soon
area: ui
tags: [web]
description: How do mature frameworks send each page only the CSS it uses, without extra work for developers, and what does it cost in caching and correctness (client-rendered islands)?
---
# How do mature frameworks send each page only the CSS it uses, without extra work for developers, and what does it cost in caching and correctness (client-rendered islands)?

Feeds: docs/plan/ui/stack.md "3. Styles" (one hashed file today); the per-page CSS change for PageSpeed's render-blocking flag (style.css 177 KB raw, 31.5 KB gz on every page)

## Answer

Bundlers (Next, Vite, SvelteKit, Astro) work out a page's CSS from its import graph;
Nuxt and Qwik from what rendered; nobody but Remix asks the developer to list it, and
Remix's maintainers call that boilerplate (C1, C2). Splitting makes tiny shared chunks,
so they merge (Next, under ~20-30 KB) or inline (Astro, under 4 KB) (C3), and it brings
order bugs that run for years (Vite #3924, Next's 'strict' mode) (C5); copying shared CSS
into each page is safe when each page has one sheet and navigation is a full load (C9).
Stacks closest to ours (Phoenix, Leptos) ship one app-wide sheet, as do Tailwind and
StyleX, which keep it small instead (C10, C11).

On speed: fewer, larger compressed files beat many small ones (C12); a 40% per-page cut
gave GOV.UK 7% better LCP (C13). PageSpeed's render-blocking estimate is an upper bound
that treats inlining as free and counts a swap font on the LCP path (fixed in Lighthouse
13.6.0, 27 Oct 2026), and the audit passes only with no blocking sheet at all (C14, C15).
Inlining saves a round trip on the first view, costs bytes on every later one (C16).
Components first drawn on the client need their CSS on the page already (C17).

For meiolol (C18): work the CSS out automatically, no lists: the classes in the page's
own HTML plus those compiled into its islands' wasm (post-link, so only reachable code).
Inline it, or link one sheet per page kind if repeat views weigh more.

Measured 29 Oct (local h2 proxy, applied Slow 4G and CPU 4x, FCP medians of 3, a cold
page then four warm): one sheet 1504 then ~610 ms; inline 768 then ~675 (12-15 KB more
HTML each, break-even ~12 pages a visit); cached common base 1320 then ~620; a sheet per
page kind or per island ~1370 then ~1300 (each new kind misses the cache). Inline alone
clears the render-blocking audit; Lighthouse's simulated FCP rates it a little worse
(1152 vs 1020 mean), its bigger HTML charged in round trips. Computed styles identical
on 11 pages. Chosen: inline (docs/plan/ui/stack.md section 3)

## Claims

- C1: Mature frameworks derive each page's CSS automatically, from the import graph or from what rendered; nothing declared per page. for: [[nextjs-css-chunking#^f1]], [[sveltekit-css#^f1]], [[astro-styling-docs#^f2]], [[vite-css-docs#^f1]], [[nuxt-inline-styles#^f6]]
- C2: Hand-declared per-route links (Remix) work but cost boilerplate per route; Remix's own answer was one shared cached sheet. for: [[remix-v1-styling#^f7]], [[remix-v1-styling#^f6]]
- C3: Per-page splitting makes many tiny shared chunks, so frameworks merge or inline small ones (Next under 30 KB, Turbopack ~20 KB per request, Astro inlines under 4 KB). for: [[nextjs-css-chunking-discussion#^f6]], [[nextjs-css-chunking#^f6]], [[astro-inline-stylesheets-rfc#^f1]], [[astro-styling-docs#^f3]]
- C4: With a client router, shared CSS goes in common chunks, not copies: copies loaded twice reorder the cascade. for: [[nextjs-css-chunking-discussion#^f3]], [[nextjs-css-chunking-discussion#^f7]] against: [[esbuild-css-splitting-608#^f2]]
- C5: Bundler CSS splitting causes long-lived wrong-order bugs and prod/dev differences. for: [[vite-css-order-3924#^f1]], [[vite-css-order-3924#^f4]], [[nextjs-css-chunking#^f3]], [[nextjs-css-chunking-discussion#^f10]], [[nextjs-css-docs#^f4]]
- C6: Scoped class names reduce but don't remove order dependence (two components' rules on one element). for: [[nextjs-css-chunking-discussion#^f4]], [[astro-styling-docs#^f4]]
- C7: Inlining trades cache reuse for a request: SvelteKit off by default, Astro under 4 KB only, Nuxt inlines rendered components' CSS per request. for: [[sveltekit-css#^f5]], [[astro-inline-stylesheets-rfc#^f2]], [[nuxt-inline-styles#^f1]]
- C8: Client-only components' CSS loads eagerly if server-rendered, else with the component's code before it renders. for: [[sveltekit-css#^f3]], [[nuxt-inline-styles#^f4]], [[qwik-styles-docs#^f4]], [[vite-css-docs#^f2]]
- C9 (inferred): With full page loads and one sheet per page, shared CSS copied into each page is order-safe; it costs only cache reuse. from: C4, C6
- C10: Server-rendered stacks close to ours ship one app-wide sheet, even with per-component CSS. for: [[phoenix-colocated-css#^f3]], [[leptos-book-styling#^f5]], [[cargo-leptos#^f5]], [[phoenix-asset-management#^f2]]
- C11: Atomic or used-only CSS keeps one sheet small enough not to split (Tailwind usually under 10 kB compressed; Facebook's redesign under 20% of its old CSS). for: [[fb-redesign-2020#^f3]], [[stylex-docs#^f4]], [[tailwind-v3-production#^f3]], [[fb-stylex-2025#^f5]]
- C12: Under HTTP/2 with compression, fewer larger files beat many small ones. for: [[csswizardry-three-cs#^f1]], [[csswizardry-three-cs#^f4]], [[govuk-css-size#^f5]]
- C13: Per-page CSS gives a real but small LCP gain (GOV.UK: 40% less CSS, 7% better LCP on Mobile 3G); the bigger gain is caching. for: [[govuk-css-size#^f3]], [[govuk-css-size#^f4]]
- C14: PageSpeed's render-blocking saving is an upper bound: blocking requests and their dependents removed, inlining at zero bytes, the FCP saving copied to text LCP. for: [[devtools-renderblocking-insight#^f2]], [[devtools-renderblocking-insight#^f3]], [[devtools-renderblocking-insight#^f4]]
- C15: The audit passes only with no render-blocking request; split sheets in the head are still flagged. for: [[chrome-render-blocking-insight#^f1]], [[devtools-renderblocking-insight#^f1]], [[lighthouse-render-blocking-audit#^f1]]
- C16: Inlining saves a round trip on first view; it delays the HTML, can't be cached, and repeats per page. for: [[webdev-extract-critical-css#^f2]], [[webdev-extract-critical-css#^f3]], [[tunetheweb-inlining-css#^f1]], [[tunetheweb-inlining-css#^f3]]
- C17: A component first rendered on the client avoids a flash only if its CSS is already on the page or ships with its code. for: [[lit-styles#^f3]], [[stylist-rs#^f2]], [[sveltekit-css#^f3]]
- C18 (inferred): For meiolol: derive each page's CSS automatically from its HTML's classes and its islands' compiled class names, and inline it or link one sheet per page kind. from: C1, C2, C9, C15, C17
- C19: With font-display swap, text LCP is the fallback paint; Lighthouse's simulation counted the font until 13.6.0. for: [[webdev-lcp#^f1]], [[webdev-lcp#^f2]], [[lighthouse-lantern-preload-lcp#^f1]], [[lighthouse-lantern-preload-lcp#^f6]]
- C20: @font-face in the HTML head starts the font without waiting for the sheet. for: [[webdev-font-best-practices#^f1]], [[tunetheweb-inlining-css#^f2]]
- C21: Class scans need class names written out in full; names built at runtime are missed. for: [[tailwind-detecting-classes#^f3]], [[tailwind-detecting-classes#^f4]]

## Disagreements

Copy shared CSS into each page (esbuild, B) or share chunks (Next, A): both right for
their case; it turns on whether a client router keeps old sheets loaded (C4, C9).
Split per page (bundlers) or one small sheet (Phoenix, Tailwind, StyleX): one small
sheet needs shared or atomic declarations, which our scoped component rules don't have.

## Options

| Option | For | Against | Would change if |
| --- | --- | --- | --- |
| Inline, derived per request | C1, C15, C17, C20 | C16, C7 | visits are many pages each |
| One sheet per page kind, derived | C1, C9, C12 | C15 | PageSpeed flag must clear |
| Base + page sheet, derived | C13 | C3, C12, C15 | |
| Hand lists per page | | C2 | |
| One sheet, shrunk | C10, C11 | our rules don't share declarations | |

## Open

- Real-user LCP on meio.lol (WebPageTest or devtools applied throttling), as PageSpeed's
  3.3 s may carry the font (C19)
- How many pages a visit sees (traffic logs): settles inline against linked
- React 19 `<link precedence>`, Rspack CssChunkingPlugin, Rails: leads, not read
