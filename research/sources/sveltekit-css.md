---
title: 'SvelteKit source: per-node stylesheets, inlineStyleThreshold, bundleStrategy'
url: https://github.com/sveltejs/kit
kind: project
commit: f22e6210a51bc0e43bd52882be12d759eff5a2c6
for: [css-per-page]
looked: 2026-10-29
depth: code (build/utils.js find_deps, build/build_server.js, runtime/server/page/render.js, exports/vite/public.d.ts config docs)
relevance: high
grade: A/strong
description: How SvelteKit picks each route's CSS from the Vite module graph per layout and page node, links only CSS used in SSR eagerly, and inlines sheets under a length threshold
---
# SvelteKit source: per-node stylesheets, inlineStyleThreshold, bundleStrategy

Why: a framework whose components carry their own scoped CSS, like ours.

## Assessment

- Evidence: A. Svelte's official app framework, repo since 2020, 20k+ stars.
- Reasoning: strong in code comments (FOUC, cache trade-off stated in the option docs).
- Interests: none.
- Weigh: we read code, so these are what it does at this commit.

## Findings

- [web] Each route node's CSS comes from walking the bundler manifest from that page or
  layout through its static imports, collecting each chunk's CSS; nothing declared. `build/utils.js` ^f1
  > if (chunk.css) {
  > chunk.css.forEach((file) => stylesheets.add(file));
  > chunk.imports.forEach((file) =>
- [web] A rendered page links the union of stylesheets of its branch (root layout, nested
  layouts, page). `runtime/server/page/render.js` ^f2
  > for (const { node } of branch) {
  > for (const url of node.stylesheets) stylesheets.add(url);
- [web] [web/wasm] Only CSS of modules used during SSR is linked eagerly (avoids FOUC);
  CSS of client-only imports loads lazily with them. `build/build_server.js` ^f3
  > Eagerly load client stylesheets and fonts imported by the SSR-ed page to avoid FOUC.
  > then it can be lazily loaded in the browser.
- [web] `inlineStyleThreshold` (default 0, off): every needed sheet shorter than N UTF-16
  units is merged into one head `<style>`. `exports/vite/public.d.ts` ^f4
  > All CSS files needed for the page that are smaller than this value are merged and inlined in a `<style>` block.
- [web] The docs name the cost: fewer requests and better FCP, but bigger HTML and weaker
  browser caching; off by default. ^f5
  > However, it generates larger HTML output and reduces the effectiveness of browser caches. Use it advisedly.
- [web] Inlining decides per CSS chunk by length, at build time. `build/build_server.js` ^f6
  > if (source.length < kit.inlineStyleThreshold) {
- [web] Inlined sheets are not linked again. `runtime/server/page/render.js` ^f7
  > // don't load stylesheets that are already inlined
- [web] `bundleStrategy`: 'split' (default, lazily per navigation), 'single' (one JS and
  one CSS file for the app), 'inline' (all in HTML). `exports/vite/public.d.ts` ^f8
  > If `'split'`, splits the app up into multiple .js/.css files so that they are loaded lazily as the user navigates around the app. This is the default, and is recommended for most scenarios.
  > If `'single'`, creates just one .js bundle and one .css file containing code for the entire app.
- [web] Shared CSS chunking is left to the bundler (Vite/Rolldown code splitting), tunable
  there, not in SvelteKit. ^f9
  > When using `'split'`, you can also adjust the bundling behaviour by setting

## Read

- find_deps; node stylesheet and inline logic in build_server.js; render.js stylesheet
  assembly; config docs for inlineStyleThreshold and bundleStrategy

## Not read

- client router's CSS loading on navigation; Svelte compiler's scoped CSS (svelte repo)
