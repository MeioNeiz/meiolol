---
title: 'GOV.UK Design System: Spacing'
url: https://design-system.service.gov.uk/styles/spacing
kind: docs
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (scales and helpers)
relevance: medium
grade: A/fair
description: GOV.UK's spacing tokens: a 10-step unit scale (0-9, 5 to 60 px) in a responsive and a static version, used only through helpers, plus override classes for one-offs
---
# GOV.UK Design System: Spacing

Why: how a mature design system structures spacing tokens.

## Assessment

- Evidence: A. The UK government's design system, used across gov.uk services.
- Reasoning: fair. States the scale and usage; little on why these numbers.
- Interests: none.
- Weigh: copyable structure.

## Findings

- [web/qa] Two scales: responsive (bigger above the 640 px tablet breakpoint) and static.
  Intro ^f1
  > The Design System uses two different spacing scales – responsive and static.
- [web/qa] Ten units, 0 to 9, from 5 px to 60 px; small units identical on every screen.
  Responsive spacing ^f2
  > Spacing for the smallest units (0-3) stays the same for all screen sizes.
- [web/qa] Code names a unit, not a pixel value, through a helper. Static helper ^f3
  > padding-top: govuk-spacing(6);
- [web/qa] One-off adjustments use named override classes, not raw values. Overriding ^f4
  > Occasionally, you might need to make minor adjustments like adding or removing spacing to elements of your design. You can use the spacing override classes for this.
- [web/qa] (inferred) Ten steps cover a whole government's services; meiolol's planned
  4/8/12/16/24 scale is similar in size, and a unit-indexed helper (Zig or CSS var) gives
  the lint something to check against. ^f5

## Read

- Spacing page

## Not read

- Typography scale page; Sass API reference
