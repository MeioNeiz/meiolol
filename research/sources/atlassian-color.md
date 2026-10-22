---
title: 'Atlassian Design System: Color foundations'
url: https://atlassian.design/foundations/color
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (whole page)
relevance: high
grade: A/fair
description: Atlassian colour foundations: neutrals for most UI, saturated colours carry meaning, tokens named color.<property>.<role>.<emphasis>.<state>, fixed semantic roles, accents must carry no meaning, selection needs a non-colour cue
---
# Atlassian Design System: Color foundations

Why: how a large multi-team design system stops colours meaning different things in
different places.

## Assessment

- Evidence: A. Atlassian's system across Jira, Confluence and others, hundreds of teams.
- Reasoning: fair. Rules with short reasons.
- Interests: none beyond their products.
- Weigh: the role list fits a work app; the principle (neutral by default, saturated means
  something, accents interchangeable) transfers.

## Findings

- [ux/colour] Neutrals cover most of the UI and carry no meaning. Neutral colors ^f1
  > Neutral colors apply to most backgrounds, text, and shapes in our experiences. They don’t typically have a meaning associated with them
- [ux/colour] Saturated colours are the ones that carry meaning or highlight. ^f2
  > Saturated colors can infuse meaning to an experience, highlight UI, or create associations with similar colored UI.
- [ux/colour] [web/qa] Colour is applied by token, not by picking a shade; every token has a description. Applying color with design tokens ^f3
  > This means rather than choosing a certain shade or value, you’ll choose a design token to apply colors.
- [ux/colour] [web/qa] Token names encode property, then role, emphasis and state. ^f4
  > All color design tokens start with the word “color”, followed by the property that it's applied to, such as a background, border, or icon.
  > the token may have one or more modifiers that represent the different parts of our color system: color role, emphasis level, and interaction state.
- [ux/colour] Fixed semantic roles: neutral, brand, information, success, warning, danger, discovery; roles describe intention. Color roles ^f5
  > Color roles describe the intention behind the color.
- [ux/colour] Accents must be swappable without changing the experience, and never used where colour means something. ^f6
  > Use for colors that don't have any specific meaning tied to them. You should be able to exchange one accent color for another, and the experience would remain unchanged.
  > Don’t use an accent when the color has semantic meaning.
- [ux/colour] Emphasis is contrast against the surface; bolder draws more attention. Emphasis levels ^f7
  > Bolder colors have more contrast against the default surface, which adds more attention than subtle colors.
- [ux/colour] Selection pairs colour with a checkmark, underline, border or shape. ^f8
  > Pair selected colors with another visual cue, such as a checkmark, underline, border, or change in shape.
- [ux/colour] [web/qa] Contrast floor: 4.5:1 for text under 24 px, 3:1 for essential UI and text 24 px and up. ^f9
  > Must pass 4.5:1: Text smaller than 24px

## Read

- Whole page

## Not read

- Accents and data visualisation colour subpages; token list; their ESLint token rule
