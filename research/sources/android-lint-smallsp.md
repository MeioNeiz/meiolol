---
title: 'Android lint check SmallSp (text size too small)'
url: https://googlesamples.github.io/android-custom-lint-rules/checks/SmallSp.md.html
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (whole check page)
relevance: medium
grade: A/fair
description: Built-in Android lint warning since 2011 that flags any text size below 11sp in layout resources, with per-element or per-folder suppression
---
# Android lint check SmallSp (text size too small)

Why: evidence that a minimum text size is enforced by a static check in a mature
platform, and at what threshold.

## Assessment

- Evidence: A. Ships in Android lint, run by every Android Studio project since 2011.
- Reasoning: weak. States the rule, not why 11.
- Interests: none.
- Weigh: the threshold matches Material's smallest style (Label Small 11 sp) and Apple's
  11 pt minimum.

## Findings

- [web/qa] Static check: text sizes under 11sp warn, in the editor as you type. Explanation ^f1
  > Avoid using sizes smaller than 11sp.
- [web/qa] Severity is warning, not error; category Usability; runs on the fly in the IDE.
  Summary table ^f2
  > This check runs on the fly in the IDE editor
- [web/qa] Exceptions are explicit and local: a tools:ignore attribute on the element, or
  a lint.xml per folder. Suppressing ^f3
  > Adding the suppression attribute `tools:ignore="SmallSp"` on the problematic XML element
- [web/qa] (inferred) For meio.lol a CSS test can do the same: fail any font-size below
  11 px outside a short allowlist; Jacob's 453 text nodes under 12 px on the Darius page
  would show up per selector. ^f4

## Read

- Whole page

## Not read

- PxUsageDetector source
