---
title: Phoenix.LiveView.ColocatedCSS docs
url: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.ColocatedCSS.md
kind: docs
commit:
for: [css-per-page]
looked: 2026-10-29
depth: docs (whole module doc, v1.2.13)
relevance: high
grade: A/fair
description: LiveView 1.2 colocated CSS: style tags in HEEx components extracted at compile time and imported into the app's one bundled app.css; optional @scope scoping
---
# Phoenix.LiveView.ColocatedCSS docs

Why: Phoenix's newest answer (2026) to per-component CSS in a server-rendered stack; does
it go per page?

## Assessment

- Evidence: A. Official LiveView docs (phoenix_live_view 6.8k stars), released June 2026.
- Reasoning: fair. Setup and contract; reasons are in [[phoenix-liveview-1-2]].
- Interests: none known.
- Weigh: new feature, months old; mechanics are clear.

## Findings

- [web/template] A `:type` style tag inside a HEEx template is extracted at compile time. ^f1
  > Building blocks for a special HEEx `:type` that extracts any CSS styles
  > from a colocated `<style>` tag at compile time.
- [web/template] It is meant to go through the app's bundler (Tailwind or esbuild). ^f2
  > Colocated CSS is meant to be used with a bundler like `:tailwind` or `:esbuild`.
- [web/template] All colocated CSS lands in one generated `colocated.css`, imported into the single `app.css`; with esbuild it becomes a second app-wide sheet. Not per page. ^f3
  > Then, import the `colocated.css` file in your `app.css` file:
  > Importing CSS in your `app.js` file will cause esbuild to generate a separate `app.css` file.
- [web/template] Scoping is a user callback; the documented example wraps the CSS in `@scope` from a hashed component attribute down to the next template root. ^f4
  > One way to scope CSS is to use [CSS `@scope` rules](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@scope).
  > @scope ([phx-css-abc123]) to ([phx-r]) {
- [web/template] Constraint: the style tag must come first in its template. ^f5
  > Note: `ColocatedCSS` **must** be defined at the very beginning of the template in which it is used.
- [web/template] (inferred) This is meiolol's design today (CSS next to the component, collected at compile time into one app sheet), now adopted by a mature server-rendered framework. ^f6
