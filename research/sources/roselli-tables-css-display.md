---
title: 'Adrian Roselli: Tables, CSS Display Properties, and ARIA'
url: https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: skimmed (2023 update, table with ARIA, advice)
relevance: medium
grade: A/strong
description: Long-running post (2018, updated 2024) on responsive tables: changing table display used to strip table semantics (fixed in Safari 17 by 2023, display contents still risky); never reorder table content with CSS
---
# Adrian Roselli: Tables, CSS Display Properties, and ARIA

Why: can container queries reflow meiolol's dense stat tables (stacked cards on
phones) without breaking screen reader table navigation?

## Assessment

- Evidence: A. Tested with NVDA and screen reader table navigation; tracked browser
  bugs for years.
- Reasoning: strong. Explains the cause (browsers map display to roles) and advice.
- Interests: none.
- Weigh: 2023 update says browsers are now fine except display contents.

## Findings

- [web] [ux/density] As of Oct 2023, tables restyled with display properties keep
  their semantics in Chromium, Gecko and WebKit (Safari 17); `display: contents` is
  the remaining risk. ^f1
  > Tables with display properties are now functional across Chromium, Gecko, and (finally) WebKit browsers.
  > `display: contents` is the only style that may cause issues
- [web] [ux/density] Never reorder table content with CSS; sort by moving DOM nodes. ^f2
  > The re-ordering issue is easy to solve — don’t use CSS to re-order table content. Use client-side script to move the nodes around in the DOM.
- [web] [ux/density] Responsive tables that hide headers need replacement text for
  the hidden headers, and screen reader testing on each browser update. ^f3
  > If you are not able to test with a screen reader, maybe don’t do this.

## Read

- 2023 update, table example, advice

## Not read

- Mid-2022 post on Safari display bugs; his responsive accessible table (2017)
