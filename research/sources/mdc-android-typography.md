---
title: 'Material Components for Android: Typography theming (baseline scale sizes)'
url: https://github.com/material-components/material-components-android/blob/master/docs/theming/Typography.md
kind: docs
commit: 66b0eeb53afeb6025ffbbd37734b08e5bce197ed
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (baseline scale table)
relevance: medium
grade: A/fair
description: Material 3 baseline type sizes in Google's Android library: body 16/14/12 sp, label 14/12/11 sp, smallest style Label Small 11 sp
---
# Material Components for Android: Typography theming

Why: the M3 sizes the m3.material.io token table hides behind JS.

## Assessment

- Evidence: A. Google's own component library (17k stars, since 2016, pushed Oct 2026).
- Reasoning: weak (a table).
- Interests: none beyond Material.
- Weigh: same numbers as [[m3-type-scale]] describes.

## Findings

- [ux/layout] Body sizes 16, 14 and 12 sp; label sizes 14, 12 and 11 sp; nothing in the scale under 11. `docs/theming/Typography.md` ^f1
  > `textAppearanceBodyMedium`     | Regular 14sp
  > `textAppearanceBodySmall`      | Regular 12sp
  > `textAppearanceLabelSmall`     | Medium 11sp
- [ux/layout] (inferred) Apple (11 pt minimum) and Material (11 sp smallest style) agree on 11 px as the floor for any text, with body at 14 to 17. ^f2

## Read

- Baseline and emphasized scale tables
