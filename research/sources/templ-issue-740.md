---
title: 'templ #740: proposal to deprecate CSS components'
url: https://api.github.com/repos/a-h/templ/issues/740
kind: thread
commit:
for: [css-per-page]
looked: 2026-10-29
depth: listed (issue body and all comments, 2024-05 to 2026-09)
relevance: high
grade: B/strong
description: templ maintainer's open proposal (May 2024) to drop `templ css` components for pre-processors; thread on scoped CSS, once-per-request and global sheets
---
# templ #740: proposal to deprecate CSS components

Why: the maintainers' own view of templ's per-request CSS: what it cost them and what users
want instead.

## Assessment

- Evidence: B. The owner (a-h) and a collaborator (joerdav) argue it, 46 comments over two
  years, still open; templ has 30+ contributors and 10.5k stars.
- Reasoning: strong. States limits of the current design, alternatives, user pushback and
  maintenance cost.
- Interests: none known.
- Weigh: a proposal, not a decision; still open in 2026-10. Raw is the GitHub API text of
  the issue and comments (`gh issue view` plus comments), as the page is a JS app. Human URL: https://github.com/a-h/templ/issues/740 (the store keys github.com URLs by repo, so the API URL keeps it apart from [[templ-repo]]).

## Findings

- [web/template] The owner calls templ's CSS components very basic (no media queries, minimal interpolation) and proposes dropping them for existing pre-processors. ^f1
  > `templ css` CSS components are very basic. They don't support a range of use cases #262 including media queries, and the interpolation features are minimal.
- [web/template] Their design aim was per-component CSS rendered only when needed, with generated names for scoping; the owner says the design has severe limits. ^f2
  > `templ css` was designed so that it was possible to include classes for specific templ components, and only render the CSS if required. It dynamically generates class names to provide basic scoping. But... its design has severe limits.
- [web/template] Proposed instead: a normal build step (templ generate, esbuild, postcss) whose CSS output the Go server hosts as files. ^f3
  > `postcss` (or whatever CSS pre-processor you want to use) to get output CSS, and get the Go web server to host the outputs at `dist`/`public`.
- [web/template] Users pushed back: many chose templ to avoid the JS toolchain and prefer a built-in solution with fewer features. ^f4
  > The main reason I picked Templ over Svelte for my new app was to avoid the JS ecosystem. I'd prefer a built-in solution, even if it had less features
- [web/template] The owner's sketch for keeping per-component CSS: a style component wrapped in `templ.Once`, so a component's CSS is emitted only if the component is on the page. ^f5
  > But, in this case the CSS would only be loaded into the page as a `<style>` element if required by the component.
- [web/template] A contributor's alternative: one sheet built by walking all `.templ` files for scoped style blocks, deduped, bundled and cached; elements get a hash class. ^f6
  > Then upon request, it traverses the `.templ` files, looking for styles, gathers them, dedupes them and bundle them all together. In production, you'd cache this sheet
- [web/template] Critic's point against per-component scoped CSS: the sheet cannot shrink by sharing declarations, a problem with many components. ^f7
  > you can't optimize the size of the final css code - it will be problem in large projects(large number of components);
- [web/template] The contributor agrees: hashing dedupes whole blocks, not declarations, so the same declaration repeats per component. ^f8
  > Since you're hashing the CSS contents, you can dedupe <style> tags that have the same contents, but not the declarations
- [web/template] The same critic lists serving only used CSS as a challenge in its own right, and repeated style elements in lists of components as a cost. ^f9
  > if you put styles in files you need to serve only what you use;
- [web/template] 2026: a commenter suggests inline `<style>` with `@scope` (now Baseline) for scoping, at the cost of sending the style element with each render. ^f10
  > You'll have to wrap your whole component in a `<div>` or similar but otherwise it'll work ok at the expense of the style tag being sent with each render.
- [web/template] Checked, not there: no numbers in the thread (sheet sizes, request counts or cache hit rates). ^f11

## Read

- Issue body and all comments, via the GitHub API

## Not read

- templ #262 (media queries in css components), PR #750 (templ.Once)
- a-h/templ-css PoC
