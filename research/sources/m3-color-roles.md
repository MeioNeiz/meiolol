---
title: 'Material Design 3: Color roles'
url: https://m3.material.io/styles/color/roles
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (roles overview, accent roles, error)
relevance: high
grade: A/fair
description: Material 3 colour roles: 26 roles in six groups, three accents ranked by emphasis (primary for the most important), one error colour that stays static, colours only in their intended pairs (3:1 minimum)
---
# Material Design 3: Color roles

Why: how a mature system limits which colours carry meaning.

## Assessment

- Evidence: A. Google's design system.
- Reasoning: fair. Explains pairing for contrast; no evidence on how many accents read best.
- Interests: platform owner.
- Weigh: roles are by job and emphasis, not by hue; the only meaning-carrying hue is error.

## Findings

- [ux/colour] [web/qa] 26 roles in six groups; colours are named by role, not hue. ^f1
  > There are 26 standard color roles organized into six groups: primary, secondary, tertiary, error, surface, and outline
- [ux/colour] Accents are ranked by emphasis: primary for the most important, secondary for no emphasis, tertiary for small special elements. Accent color roles ^f2
  > Primary roles are for important actions and elements needing the most emphasis
  > Secondary roles are for elements that don’t need immediate attention and don’t need emphasis
- [ux/colour] Don't change roles for visual effect. ^f3
  > Use caution when changing color roles for visual effect.
- [ux/colour] One semantic hue only: error, static even when the rest of the scheme changes. Error ^f4
  > Error is an example of a static color (it doesn't change even in dynamic color schemes).
- [ux/colour] [web/qa] Use colours only in their intended pairs; pairs guarantee at least 3:1 contrast. ^f5
  > These color pairs provide an accessible minimum 3:1 contrast.
  > To ensure accessible visual contrast in your app, apply colors only in the intended pairs or layering orders described in the following sections.
- [ux/colour] Surfaces are for large, low-emphasis areas: most of the screen is neutral. ^f6
  > Surface – A role used for backgrounds and large, low-emphasis areas of the screen.
- [ux/colour] Checked, not there: no success or warning roles in the standard set; status colours beyond error are left to products. ^f7

## Read

- Overview, general concepts, accent roles, primary, tertiary, error

## Not read

- Surface detail, fixed accent add-ons
