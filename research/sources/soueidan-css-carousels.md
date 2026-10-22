---
title: 'Sara Soueidan: Are CSS Carousels accessible?'
url: https://sarasoueidan.com/blog/css-carousels-accessibility
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: skimmed (intro, scroll marker semantics, tabs requirements, first two examples)
relevance: medium
grade: A/strong
description: Accessibility engineer's long audit (May 2025, updated Aug 2025) of Chrome's CSS carousels: scroll markers are exposed as tab and tablist with no tabpanels, broken focus order; verdict not ready for production
---
# Sara Soueidan: Are CSS Carousels accessible?

Why: CSS scroll markers are the one CSS feature pitched for script-free tabs and
carousels (champion build tabs, matchup sections). Do they work for AT users?

## Assessment

- Evidence: A. Recognised accessibility specialist; tested Chrome's own gallery with
  DevTools accessibility tree, keyboard and VoiceOver; cites ARIA spec and APG.
- Reasoning: strong. Benchmarks against spec requirements, example by example.
- Interests: sells an accessibility course (mentioned in the post).
- Weigh: tested Chrome Canary in 2025; Chrome may have changed roles since; still
  Chromium only ([[web-features-3-44#^f17]]).

## Findings

- [web] Verdict: CSS carousels are experimental and not production ready, for both
  browser support and accessibility. ^f1
  > CSS Carousels are highly experimental and they are not yet ready for production; not only because of the current lack of browser adoption for the new CSS features they use, but also because they have some major accessibility issues.
- [web] Chrome exposes the scroll marker group as a tablist and each marker as a tab,
  which the spec does not say. ^f2
  > The `::scroll-marker-group` element is exposed as a `tablist` in the accessibility tree.
- [web] Marker names come from CSS `content`; the author must supply them. ^f3
  > The accessible name for the scroll marker is provided in CSS via the `content` property.
- [web] The tabs have no tabpanels, breaking the ARIA tab contract. ^f4
  > However, there are no corresponding `tabpanel`s for these `tabs`.
- [web] Focus order is wrong: Tab from the markers does not reach the selected panel,
  and Shift+Tab walks through hidden cards instead of returning to the tab. ^f5
  > focus does not necessarily move to the currently selected card (the “tabpanel”).
- [web] The marker group is one tab stop navigated with arrow keys, like a radio
  group. ^f6
  > **the group takes up only one tab stop on the page.**

## Read

- Intro, how scroll markers work, accessibility tree, tabs requirements, first examples

## Not read

- Remaining gallery examples and the August 2025 update details
