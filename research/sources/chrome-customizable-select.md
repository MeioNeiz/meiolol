---
title: 'Chrome for Developers: The select element can now be customized with CSS'
url: https://developer.chrome.com/blog/a-customizable-select
kind: docs
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: skimmed (intro, what base-select changes, rich content)
relevance: medium
grade: A/fair
description: Chrome 135 launch post (Mar 2025) for appearance base-select: options in the top layer, anchor positioned, no mobile OS picker, rich HTML in options, falls back in older browsers
---
# Chrome for Developers: The select element can now be customized with CSS

Why: could our region, rank and period dropdowns become styled native selects, and
what changes on phones?

## Assessment

- Evidence: A. The shipping vendor's launch post.
- Reasoning: fair. Lists the behavioural changes plainly.
- Interests: Google.
- Weigh: the mobile trade-off is the key fact; Safari 27 has it, Firefox does not
  ([[web-features-3-44#^f7]]).

## Findings

- [web] Chrome pitches it as accessible and standard, and safe in older browsers. ^f1
  > the result is an incredibly rich and powerful component that won't break in older browsers.
- [web] With base-select the picker is a top-layer popover positioned with anchor(),
  not the phone's OS picker; the select no longer sizes to its longest option. ^f2
  > It doesn't trigger built-in mobile operating system components.
  > Shown [options](https://developer.mozilla.org/docs/Web/HTML/Element/option) are in the top-layer, like a popover.
- [web] Options can hold rich HTML (images, SVG); browsers without support parse and
  drop it, so the text must stand alone. ^f3
  > If the browser supports `appearance: base-select` then the SVG will appear in the option, otherwise it won't.
- [web] (inferred) For phone users the native wheel or sheet picker is usually the
  better control; base-select is worth it only where options need icons (champion
  portraits), and can be limited to fine pointers with a media query. ^f4

## Read

- Intro, base-select behaviour list, rich content section

## Not read

- Styling recipes, selectedcontent details
