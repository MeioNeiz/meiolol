---
title: 'Apple Human Interface Guidelines: Typography'
url: https://developer.apple.com/design/human-interface-guidelines/typography
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (best practices, specifications tables, xSmall tab only)
relevance: high
grade: A/fair
description: Apple HIG typography: default and minimum text sizes per platform (iOS 17 pt default, 11 pt minimum; macOS 13 and 10), avoid light weights, use size, weight and colour for hierarchy
---
# Apple Human Interface Guidelines: Typography

Why: minimum body and label text size on phones.

## Assessment

- Evidence: A. Apple's platform guidelines.
- Reasoning: fair. Rules, not studies.
- Interests: platform owner.
- Weigh: the snapshot holds only the xSmall Dynamic Type tab, not Large (default); the
  default and minimum table is the part to cite.

## Findings

- [ux/layout] Follow each platform's default and minimum text sizes, custom fonts included. Best practices ^f1
  > Follow the recommended default and minimum text sizes for each platform — for both custom and system fonts — to ensure your text is legible on all devices.
- [ux/layout] Text sizes: iOS and iPadOS default 17 pt, minimum 11 pt; macOS 13 pt and 10 pt. Best practices table ^f2
  > iOS, iPadOS | 17 pt | 11 pt
  > macOS | 13 pt | 10 pt
- [ux/layout] Avoid light weights (Ultralight, Thin, Light), hard to see when small. ^f3
  > In general, avoid light font weights.
- [ux/layout] Hierarchy comes from weight, size and colour, and must survive text resizing. ^f4
  > Adjust font weight, size, and color as needed to emphasize important information and help people visualize hierarchy.
- [ux/layout] Even the smallest iOS styles at the smallest Dynamic Type setting stay at 11 pt (Caption 1 and 2 in the xSmall table). iOS, iPadOS Dynamic Type sizes ^f5
  > Caption 2 | Regular | 11 | 13 | Semibold
- [ux/layout] (inferred) meio.lol's 453 text nodes under 12 px on a phone sit at or below Apple's 11 pt floor only if under 11 px; 12 px is above the floor but far below the 17 pt body default. ^f6

## Read

- Best practices, Specifications (iOS xSmall tab, AX1 heading), contrast note

## Not read

- Large (default) Dynamic Type tab (not in the snapshot), tracking tables
