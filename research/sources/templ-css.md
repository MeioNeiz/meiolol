---
title: 'templ CSS components: once-per-request style elements and CSS middleware'
url: https://templ.guide/syntax-and-usage/css-style-management
kind: docs
commit: f6492f22bef32521a9d90400ec44de5ed3b7546b
for: [css-per-page]
looked: 2026-10-29
depth: docs (css-style-management) and code (runtime.go: RenderCSSItems, CSSMiddleware, contextValue)
relevance: high
grade: A/fair
description: Go templ's `css` components: CSS emitted as a style element the first time a class is used in a request, or served as one global sheet by middleware
---
# templ CSS components: once-per-request style elements and CSS middleware

Why: templ is the closest stack to ours (server-rendered typed components compiled to host
code). How does it get a component's CSS onto only the pages that use it?

## Assessment

- Evidence: A. templ created 2021-04, 10593 stars, latest v0.3.1100 (2026-10-26); docs
  snapped from the repo at the commit above (same text as templ.guide).
- Reasoning: fair. Docs say what it does and the bandwidth reason; the costs are in the
  maintainer thread ([[templ-issue-740]]).
- Interests: none known.
- Weigh: trust the mechanics (code read). Note the maintainer has proposed deprecating
  these components.

## Findings

- [web/template] A `css` component's class gets a generated name and its CSS is written as a `<style>` element the first time it is used, once per HTTP request. `docs/docs/03-syntax-and-usage/12-css-style-management.md` ^f1
  > The CSS class is given a unique name the first time it is used, and only rendered once per HTTP request to save bandwidth.
- [web/template] The dedupe is a per-request set in the context: `RenderCSSItems` writes only classes not yet marked, so the CSS lands inline mid-body, next to the first element that uses it. `runtime.go` ^f2
  > // RenderCSSItems renders the CSS to the writer, if the items haven't already been rendered.
  > ss          map[string]struct{} // Deduplication for scripts and CSS classes
- [web/template] The class name is the component name plus 8 hex chars of a SHA-256 of the CSS text, so a parameterised component emits one class and one style element per distinct value. `runtime.go` ^f3
  > hs := hex.EncodeToString(sum[:])[0:8] // NOTE: See issue #978. Minimum recommended hs length is 6.
- [web/template] Motivation is correctness, not size: library users should not have to remember to include a component's stylesheet. `docs/docs/03-syntax-and-usage/12-css-style-management.md` ^f4
  > There may be CSS class name clashes, or developers may forget to include the required CSS.
- [web/template] The inline approach resends the CSS on every request (no cache across pages), so templ also offers the opposite: middleware that serves registered classes as one global sheet and marks them rendered so pages skip the style elements. `docs/docs/03-syntax-and-usage/12-css-style-management.md` ^f5
  > The use of CSS templates means that `<style>` elements containing the CSS are rendered on each HTTP request.
  > To save bandwidth, templ can provide a global stylesheet that includes the output of CSS templates instead of including `<style>` tags in each HTTP request.
- [web/template] The global sheet is a hand-registered list at startup (`NewCSSMiddleware(next, classes...)`), served at `/styles/templ.css`; a class left off the list falls back to inline. `runtime.go` ^f6
  > use templ.Components skip rendering <style> elements for classes that are included in the global
  > Path:       "/styles/templ.css",
- [web/template] (inferred) So templ's two modes are exactly our two options: per-request inline CSS of what rendered (exact, no cache) or one global sheet (cached, everything). There is no per-page linked sheet in between. ^f7
- [web/template] Checked, not there: nothing for CSS of components rendered later in the browser; templ is server-only, so client-side additions (htmx swaps) bring their own style element in the fragment. ^f8

## Read

- `docs/docs/03-syntax-and-usage/12-css-style-management.md`: all
- `runtime.go`: CSS class types, CSSID, CSSMiddleware, RenderCSSItems, contextValue

## Not read

- `generator/`: where the generated code calls RenderCSSItems
- `once.go`: `templ.Once`, the general once-per-request handle proposed for stylesheet links
