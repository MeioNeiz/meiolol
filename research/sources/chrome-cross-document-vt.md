---
title: 'Chrome for Developers: Cross-document view transitions for multi-page applications'
url: https://developer.chrome.com/docs/web-platform/view-transitions/cross-document
kind: docs
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: skimmed (opt-in, same-origin, timeouts, render blocking)
relevance: medium
grade: A/fair
description: Chrome's reference for @view-transition { navigation: auto }: animated page-to-page navigation for multi-page sites with CSS only, its limits (same origin, both pages opt in, 4 s timeout) and the optional JS events
---
# Chrome for Developers: Cross-document view transitions

Why: can meiolol's static pages get app-like transitions between champion pages
without a client router?

## Assessment

- Evidence: A. Vendor reference docs for a shipped feature.
- Reasoning: fair. Lists limits plainly; cautions on render blocking.
- Interests: Google.
- Weigh: Chrome-specific numbers (4 s timeout); Safari has it from 18.2, Firefox not
  ([[web-features-3-44#^f10]]).

## Findings

- [web] Triggered by an ordinary same-origin link navigation; no
  `startViewTransition` call. ^f1
  > Instead, the trigger for a cross-document view transition is a same-origin navigation from one page to another, an action that is typically performed by the user of your website clicking a link.
- [web] Both pages opt in with CSS: `@view-transition { navigation: auto; }`. ^f2
  > In the `@view-transition` at-rule, set the `navigation` descriptor to `auto` to enable view transitions for cross-document, same-origin navigations.
- [web] Reloads, address bar and bookmarks do not animate; slow navigations (over 4 s
  in Chrome) skip the transition. ^f3
  > If a navigation takes too long–more than four seconds in Chrome's case–then the view transition is skipped
- [web] Customising per navigation (pagereveal) needs a parser-blocking script in the
  head; the CSS-only path is the simple fade or named-element morph. ^f4
  > Therefore you must register the listener in a classic parser-blocking script in the `<head>` _(not a module, not async, not defer)_.
- [web] Render blocking to wait for content costs Core Web Vitals; fast pages or
  prerendering matter more. ^f5
  > By default, avoid using `blocking=render` unless you can actively measure and gauge the impact it has on your users

## Read

- Opt-in, same-origin, events, render blocking, types

## Not read

- Prerender with Speculation Rules (separate page); iframe note
