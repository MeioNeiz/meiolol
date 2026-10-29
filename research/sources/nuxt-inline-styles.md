---
title: 'Nuxt source: features.inlineStyles, per-request inlining of rendered components'' CSS'
url: https://github.com/nuxt/nuxt
kind: project
commit: 744179aa30d29cf99bc3cca2e6da12cdc02fda87
for: [css-per-page]
looked: 2026-10-29
depth: code (runtime/server/renderer/inline-styles.ts, inlined-css.ts, index.ts styles part; schema experimental.ts)
relevance: high
grade: A/strong
description: Nuxt inlines, per request, the styles of the Vue components that actually rendered in SSR (ssrContext.modules), on by default in production, and keeps the link unless all of a file's CSS was inlined
---
# Nuxt source: features.inlineStyles, per-request inlining of rendered components' CSS

Why: Nuxt picks CSS by what rendered, not by what was imported: the nearest JS analogue
of a server that knows which components it emitted.

## Assessment

- Evidence: A. Main Vue meta-framework; read current code.
- Reasoning: strong in code comments (ClientOnly case, link dropping rule).
- Interests: none.
- Weigh: needs a style map per module built at build time; we would know rendered
  components directly.

## Findings

- [web] On by default for production SSR, for `.vue` components; off in dev or without SSR;
  formerly `experimental.inlineSSRStyles`. `schema/src/config/experimental.ts` ^f1
  > // Enabled by default for prod with ssr (for vue components)
  > return val ?? ((id?: string) => !!id && id.includes('.vue'))
- [web] [render] Per request, the styles inlined are those of modules used in this render
  (`ssrContext.modules`), looked up in a build-time style map. `renderer/inline-styles.ts` ^f2
  > for (const mod of usedModules) {
  > if (mod in styleMap && styleMap[mod]) {
- [web] Entry (app-wide) styles go first and are not repeated in component styles. ^f3
  > const restStyles = new Set(results.flatMap(([isEntry, styles]) => isEntry ? [] : styles.filter(style => !entryStyles.has(style))))
- [web] [web/wasm] A link is dropped only when every CSS source in the file was inlined for
  a rendered module; client-only components never reach the set, so their CSS still
  comes by link. `renderer/inlined-css.ts` ^f4
  > a component inside `<ClientOnly>` never
  > reaches `ssrContext.modules`, so its styles are only ever delivered by the
- [web] Rendered output: entry inline styles, then links not covered by inlining, then
  component inline styles. `renderer/index.ts` ^f5
  > if (isCSSInlined?.(resource.file)) {
  > link.push({ rel: 'stylesheet', href: renderer.rendererContext.buildAssetsURL(resource.file), crossorigin: '' })
- [web] Developer declares nothing per page; the only knob is a boolean or a predicate on
  component path (see [[nuxt-features-docs#^f1]]). `schema/src/config/experimental.ts` ^f6
  > const val = typeof _val === 'boolean' || typeof _val === 'function'
- [web] Checked, not there: no size threshold; every rendered component's CSS is inlined
  whatever its size. `renderer/inline-styles.ts` ^f7

## Read

- inline-styles.ts, inlined-css.ts, styles part of renderer/index.ts, inlineStyles schema

## Not read

- vite/src/css.ts (how the style map and inlined-CSS table are built); issue #36058
