---
title: 'Material Design 3: Tooltips guidelines'
url: https://m3.material.io/components/tooltips/guidelines
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (usage, anatomy, behaviour)
relevance: medium
grade: A/fair
description: Material 3 tooltips: plain tooltips label icon-only controls in one line, rich tooltips hold definitions and up to two buttons, never critical info, one tooltip at a time, tap and hold on mobile
---
# Material Design 3: Tooltips guidelines

Why: Material's limits on tooltip text and how it splits brief labels from explanations.

## Assessment

- Evidence: A. Google's design system across Android and web.
- Reasoning: fair. Do, don't and caution rules; no reasons beyond "easy to miss".
- Interests: none.
- Weigh: the limits are lines and counts, not characters.

## Findings

- [ux] Plain tooltips label elements with no text, like icon-only buttons. Usage ^f1
  > Plain tooltips briefly describe a UI element. They're best used for labelling UI elements with no text, like icon-only buttons and fields.
- [ux] No tooltip when the element already has a label. Usage ^f2
  > Plain tooltips aren't needed when the UI element already has label text
- [ux/layout] Longer definitions or explanations go in rich tooltips. Usage ^f3
  > Rich tooltips are best used for longer text like definitions or explanations.
- [ux/layout] Critical information never in a tooltip: easy to miss. Usage ^f4
  > Don't hide critical information within tooltips as it’s easy to miss.
- [ux] Plain tooltip text stays on one line with one piece of information. Supporting text ^f5
  > Avoid wrapping text to multiple lines or including many pieces of information
- [ux] Rich tooltip subheads: a few words, one line; at most two short text buttons. Subhead, Text buttons ^f6
  > Keep subheads brief, ideally to one line.
  > Rich tooltips can have up to two text buttons.
- [ux/layout] Mobile: tap and hold shows a tooltip; persistent rich tooltips open on click
  or tap. Behavior ^f7
  > hover on the parent element on desktop, or tap and hold the element on mobile. Persistent rich tooltips only appear when clicked or tapped.
- [ux/layout] Only one tooltip at a time. Behavior ^f8
  > Triggering a new tooltip immediately closes any other open tooltip.

## Read

- Guidelines page

## Not read

- Specs (sizes) and accessibility tabs; Material content design pages
