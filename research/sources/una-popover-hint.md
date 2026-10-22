---
title: 'Una Kravets: What is popover=hint?'
url: https://www.una.im/popover-hint
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: listed
relevance: low
grade: B/fair
description: Chrome DevRel's July 2025 explainer of popover="hint" (Chrome 133): stacking with auto popovers, table of the three popover types, and the JS still needed for hover until interest invokers
---
# Una Kravets: What is popover=hint?

Why: what does popover="hint" add over auto, and does it remove script for tooltips?

## Assessment

- Evidence: B. Chrome developer relations lead; demo on CodePen.
- Reasoning: fair. Clear comparison table; admits the gap.
- Interests: Google, promoting a Chrome feature.
- Weigh: written before interest invokers shipped (Chrome 142).

## Findings

- [web] A hint popover opens without closing open auto popovers, for tooltips and
  previews over menus. ^f1
  > `popover="hint"` allows you to open an unrelated `hint` popover without closing other popovers in the stack.
- [web] Hint and auto both light-dismiss (click away or Esc); manual does not. ^f2
  > | Light dismiss (via click-away or `esc` key) | Yes | No | Yes |
- [web] On its own, hint does not give hover behaviour; hover and focus needed JS
  listeners until interest invokers. ^f3
  > The truth is, `popover="hint"` only gets us part of the way there.
  > For the rest, you’ll need to write some JavaScript event listeners (for now…).

## Read

- Whole post

## Not read

- CodePen demo
