---
title: 'Material Design 3: Typography, type scale and tokens'
url: https://m3.material.io/styles/typography/type-scale-tokens
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (type scale, emphasized styles, customising)
relevance: medium
grade: A/fair
description: Material 3 type scale: 15 baseline plus 15 emphasized styles, Major Second (1.125) from a 14 base for body, avoid small size differences, most products need a reduced set (five shown)
---
# Material Design 3: Typography, type scale and tokens

Why: how a mature system limits type sizes; the sizes themselves are in
[[mdc-android-typography]] (the page's token table is not in the snapshot).

## Assessment

- Evidence: A. Google's design system.
- Reasoning: fair.
- Interests: platform owner.
- Weigh: sizes in sp equal CSS px at the default 16 px root (the page's own conversion).

## Findings

- [ux/layout] One scale of 15 styles, Display Large down to Label Small, each a single token. ^f1
  > Material 3 has one type scale containing two sets of type styles: 15 baseline and 15 emphasized. Both of these style sets follow the same scale from Display Large to Label Small.
- [ux/layout] Body text anchors the scale at 14, steps of 1.125. ^f2
  > type scale with 14 as its key base size. This anchors to the most essential style used most often for typesetting body text.
- [ux/layout] Sizes should differ clearly, not by small steps. ^f3
  > Sizes on the rendered type scale should aim to provide impactful contrast between sizes by avoiding small differences.
- [ux/layout] Most products need fewer styles; the example keeps five. ^f4
  > Your product likely will not need all 15 default styles from the Material Design type scale. In this example, five sizes are chosen for a reduced set while the rest are removed.
- [ux/layout] Emphasis comes from the emphasized (heavier) variant of the same size, for selection and key elements. ^f5
  > Use emphasized styles to draw attention to specifics aspects of components, such as selected states, unread messages, or key interactions.
- [web/qa] sp converts to rem at size/16, so 12sp is 0.75rem. Font size units ^f6
  > The default for modern web browsers is 16px, so the conversion is SP_SIZE/16 = rem.

## Read

- Whole page text

## Not read

- Token table (images or JS, not in the snapshot)
