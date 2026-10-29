---
title: 'vitejs/vite issue #3924: CSS injected in wrong order with dynamic import and CSS modules'
url: https://github.com/vitejs/vite/issues/3924
kind: thread
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: listed (opening, first 15 and last items; 62 middle items collapsed in the snapshot)
relevance: high
grade: B/fair
description: Open since June 2021 with 100+ reactions; split CSS loads in an order that lets a shared component's styles beat a page's overrides, and dev order differs from build
---
# vitejs/vite issue #3924: CSS injected in wrong order with dynamic import and CSS modules

Why: the standing order bug of automatic CSS splitting in Vite.

## Assessment

- Evidence: B. Many users over five years; reproductions from 2021; open as of the snapshot
  with a linked PR (#21588).
- Reasoning: fair. Clear repro, workarounds, no maintainer design answer in the captured part.
- Interests: none.
- Weigh: user reports; 62 middle comments not captured.

## Findings

- [web] The failure: a page overrides a shared Button by passing a class, but split CSS
  loads the Button's sheet later and it wins. ^f1
  > You exepect page styles will override button styles, but they are not (as vite injects styles in wrong order)
- [web] Happens with code splitting on or off. ^f2
  > P.S. You can reproduce this but with cssCodeSplit: true or false.
- [web] Workaround seen: import the global sheet again in every component before its own, a
  maintenance cost on every file. ^f3
  > My new solution is to import our global style sheet before the per-component style sheet in every React component.
  > has the downside of needing to import our CSS styles on every single component. Bit of a pain, but it seems to work at least.
- [web] Dev and build order differ, even without CSS modules or code splitting. ^f4
  > When running `vite build` the styles are bundlded in the correct order, source code of `library/button.css` concatenated before `localbutton.css`, but when running `vite dev` the order is reversed
- [web] Hard to reproduce small: a contributor could not reproduce on current Vite and asked
  for a minimal case. ^f5
  > Can anyone provide a minimal reproduction of the bug on StackBlitz using the latest Vite?

## Read

- description, first 15 timeline items, last items (2024-2025)

## Not read

- 62 collapsed middle comments; PR #21588
