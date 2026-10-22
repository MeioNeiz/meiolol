---
title: 'Primer Primitives: Token names'
url: https://primer.style/product/primitives/token-names/
kind: docs
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (categories, convention, colour modifiers)
relevance: medium
grade: A/fair
description: GitHub Primer's design token tiers: base (raw values), functional (global UI roles like bgColor-inset), component/pattern (only in component CSS), with a fixed name grammar
---
# Primer Primitives: Token names

Why: how a mature design system tiers and names tokens, to shape meiolol's tokens.css.

## Assessment

- Evidence: A. GitHub's design system, used across github.com.
- Reasoning: fair. Rules and examples, little on why.
- Interests: none.
- Weigh: three tiers are more than a one-person site needs; base plus functional fits.

## Findings

- [web/qa] Three tiers: base, functional, component/pattern. Categories ^f1
  > This naming convention is broken down into three categories: **base, component/pattern, functional**.
- [web/qa] Base tokens map straight to raw values and are referenced by functional tokens,
  not used directly. Base, Namespace ^f2
  > `base` tokens are the lowest level and are generally used as a reference for functional tokens
- [web/qa] Functional tokens name a global UI role: bgColor-inset, borderColor-default.
  Functional ^f3
  > Functional tokens represent global UI patterns.
- [web/qa] Component tokens are allowed only in component CSS. Component/pattern ^f4
  > Component/pattern tokens should only be used in component CSS.
- [web/qa] [ux/colour] Colour variants are default, muted, emphasis. Color modifiers ^f5
  > `muted` - The secondary color variant for a given token.
- [web/qa] (inferred) A Zig CSS lint can enforce the tiers mechanically: base tokens
  appear only in tokens.css, page CSS uses functional ones. ^f6

## Read

- Categories, convention breakdown, colour modifiers

## Not read

- Size modifiers, Primer Primitives repo build
