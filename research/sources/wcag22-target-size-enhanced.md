---
title: W3C Understanding SC 2.5.5 Target Size (Enhanced), WCAG 2.2
url: https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html
kind: spec
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (SC text, intent)
relevance: high
grade: A/strong
description: WCAG 2.2 AAA target size: 44 by 44 CSS px, exceptions equivalent, inline, user agent, essential; larger still for frequent, irreversible, edge-of-screen controls
---
# W3C Understanding SC 2.5.5 Target Size (Enhanced), WCAG 2.2

Why: exact AAA wording; the 44 px figure Apple also uses.

## Assessment

- Evidence: A. W3C Recommendation, official Understanding document.
- Reasoning: fair. Intent explained; less worked detail than 2.5.8.
- Interests: none known.
- Weigh: AAA is not a conformance target for most sites, but the number matches Apple's
  44 pt and is what W3C recommends for important controls.

## Findings

- [ux/layout] [web/qa] AAA rule: pointer targets at least 44 by 44 CSS px, with exceptions. Success Criterion ^f1
  > The size of the target for pointer inputs is at least 44 by 44 CSS pixels except when:
- [ux/layout] Equivalent exception: a small target is fine if a 44 px control on the page does the same thing. ^f2
  > The target is available through an equivalent link or control on the same page that is at least 44 by 44 CSS pixels;
- [ux/layout] Inline exception covers targets in a sentence or block of text. ^f3
  > The target is in a sentence or block of text;
- [ux/layout] Touch is the reason: a finger is coarse and hides what it touches. Intent ^f4
  > Touch is particularly problematic as it is an input mechanism with coarse precision.
- [ux/layout] Go larger than 44 when the control is frequent, hard to undo, near an edge or part of a sequence. Intent ^f5
  > While this criterion defines a minimum target size, it is recommended that larger sizes are used to reduce the possibility of unintentional actions. This is particularly relevant if any of the following are true:
  > the control is used frequently;

## Read

- SC text and Intent

## Not read

- Examples and techniques
