---
title: 'WebKit: News from WWDC26, WebKit in Safari 27 beta'
url: https://webkit.org/?p=17967
kind: docs
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: skimmed (select, anchor positioning, :has fixes, scroll anchoring)
relevance: high
grade: A/fair
description: WebKit team's Safari 27 beta feature post (June 2026): customizable select, transform-aware anchor positioning, many :has() invalidation fixes; Safari 27 shipped by mid Sept 2026 per web-features
---
# WebKit: News from WWDC26, WebKit in Safari 27 beta

Why: what does Safari 27 (the iOS browser engine for every phone player on iPhone) add
for script-free UI, and what does it still lack?

## Assessment

- Evidence: A. The engine vendor's own release post, with bug ids per fix.
- Reasoning: fair. Says what and why briefly; no limits section.
- Interests: vendor promoting its release.
- Weigh: trust feature presence; "beta" at writing, shipped by Sept 2026
  ([[web-features-3-44#^f15]]).

## Findings

- [web] Safari 27 adds customizable `<select>` (`appearance: base-select`,
  `::picker-icon`, `::checkmark`, `<selectedcontent>`), pitched as replacing JS
  dropdown libraries without losing accessibility. ^f1
  > Safari 27 beta adds support for customizable `<select>` , which transforms the `<select>` element.
  > Use the new `appearance: base-select` to clear the native styling and start with a clean palette.
- [web] Because it stays a real select, keyboard, screen reader, form submission,
  validation and change events keep working. ^f2
  > everything that comes with a native form control still works: keyboard navigation, screen reader support, form submission, validation, `change` events.
- [web] WebKit recommends progressive enhancement: unsupported browsers fall back to
  their built-in select. ^f3
  > let browsers that don’t fall back to their built-in rendering
- [web] Anchor positioning still being refined: transform-aware anchoring is new in
  27, and position-anchor's default changed to `normal`. ^f4
  > Anchor positioning continues to get refined as the CSS specification settles.
  > `position-anchor: normal` is the new default value, replacing `auto`.
- [web] Many :has() fixes in 27, including stale styles when siblings are added or
  removed and freezes with complex :has() on DOM-heavy pages: :has() state worked
  before but had edge-case bugs in Safari. ^f5
  > Fixed a performance issue where pages with many DOM manipulations and complex `:has()` selectors could freeze.
  > Fixed `:has()` sibling invalidation failing due to an internal bitfield overflow, causing stale styles when siblings are added or removed.
- [web] Checked, not there: no interest invokers (`interestfor`) and no
  `popover="hint"` in the Safari 27 post. ^f6

## Read

- Intro, Customizable Select, anchor positioning sections, CSS bug fixes

## Not read

- WWDC26 session 315 "Rediscover the HTML Select Element" (video): layouts inside
  options, details of the API
