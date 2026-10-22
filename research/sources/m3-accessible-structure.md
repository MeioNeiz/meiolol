---
title: 'Material Design 3: Accessible design, structure (target sizes)'
url: https://m3.material.io/foundations/designing/structure
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (target sizes, target spacing)
relevance: high
grade: A/fair
description: Material 3 accessible layout page: touch targets at least 48x48 dp (about 9 mm), pointer targets 44 dp, 8 dp between targets; icon may be 24 dp inside a 48 dp target
---
# Material Design 3: Accessible design, structure

Why: Material's touch target number and spacing.

## Assessment

- Evidence: A. Google's design system, used across Android and many web apps.
- Reasoning: fair. Gives the physical size behind the number.
- Interests: platform owner.
- Weigh: dp equals CSS px at 1x (inferred), so 48 dp reads as 48 CSS px.

## Findings

- [ux/layout] Touch targets at least 48x48 dp, about 9 mm; recommended 7 to 10 mm. Touch and pointer target sizes ^f1
  > For most platforms, consider making touch targets at least 48 x 48dp. A touch target this size results in a physical size of about 9mm, regardless of screen size. The recommended target size for touchscreen elements is 7-10mm.
- [ux/layout] The target can exceed the visible element: a 24 dp icon inside a 48 dp padded target. ^f2
  > For example, an icon may appear to be 24 x 24dp, but the padding surrounding it comprises the full 48 x 48dp touch target.
- [ux/layout] Pointer (mouse) targets at least 44x44 dp. Pointer targets ^f3
  > Consider making pointer targets minimums 44 x 44dp.
- [ux/layout] [ux/density] Targets 8 dp apart or more balance density and usability. Target spacing ^f4
  > In most cases, targets separated by 8dp of space or more promote balanced information density and usability.
- [ux/layout] Material notes the iOS figure next to its own. ^f5
  > Note: iOS recommends 44 x 44dp targets.

## Read

- Target sizes section

## Not read

- Flow, hierarchy and colour parts of the page
