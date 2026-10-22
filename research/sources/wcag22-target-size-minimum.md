---
title: W3C Understanding SC 2.5.8 Target Size (Minimum), WCAG 2.2
url: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
kind: spec
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (SC text, intent, spacing)
relevance: high
grade: A/strong
description: WCAG 2.2 AA target size: 24 by 24 CSS px, or 24 px circles not touching; five exceptions (spacing, equivalent, inline, user agent, essential); best practice is size regardless of spacing
---
# W3C Understanding SC 2.5.8 Target Size (Minimum), WCAG 2.2

Why: exact AA wording for tap targets, and whether meio.lol's 40x26 px region chips fail.

## Assessment

- Evidence: A. W3C Recommendation and its official Understanding document.
- Reasoning: strong. Explains intent, each exception and worked pass/fail figures.
- Interests: none known.
- Weigh: 24 px is a floor for AA conformance, not a comfortable phone size; W3C itself
  points important controls at 2.5.5 (44 px).

## Findings

- [ux/layout] [web/qa] AA rule: pointer targets at least 24 by 24 CSS px, with listed exceptions. Success Criterion ^f1
  > The size of the target for pointer inputs is at least 24 by 24 CSS pixels, except when:
- [ux/layout] [web/qa] Spacing exception: an undersized target passes if a 24 px circle on its centre touches no other target or circle. ^f2
  > Undersized targets (those less than 24 by 24 CSS pixels) are positioned so that if a 24 CSS pixel diameter circle is centered on the bounding box of each, the circles do not intersect another target or the circle for another undersized target;
- [ux/layout] Inline exception: links in sentences, or targets held to the line-height of text, are exempt. ^f3
  > The success criterion does not apply to inline targets in sentences, or where the size of the target is constrained by the line-height of non-target text.
- [ux/layout] Best practice: meet the size regardless of spacing, and aim for 44 px (2.5.5) on important controls. Intent ^f4
  > As a best practice it is recommended to at least meet the minimum size requirement of the Success Criterion, regardless of spacing. For important links/controls, consider aiming for the stricter 2.5.5 Target Size (Enhanced).
- [web/qa] The test is geometric: a 24 by 24 px axis-aligned square must fit inside the target, so rounded corners can make it undersized. ^f5
  > For a target to be "at least 24 by 24 CSS pixels", it must be conceptually possible to draw a solid 24 by 24 CSS pixel square, aligned to the horizontal and vertical axis such that the square is completely within the target
- [ux/layout] Zoom does not count: the size is measured in CSS px at the page's own scale. ^f6
  > authors cannot meet it by claiming that the target will have enough spacing or sufficient size if the user zooms into the page.
- [ux/layout] Dense interactive data visualisations fall under the Essential exception. ^f7
  > A similar example is an interactive data visualization where targets are necessarily dense.
- [ux/layout] Worked example: 16 px tall button rows 1 px apart fail; menu items 18 px high fail, 24 px pass. ^f8
  > the same menu is expanded, but the menu items only achieve 18 CSS pixels in height, and so fail.
- [ux/layout] (inferred) meio.lol's 40x26 px region options pass AA 2.5.8 on size alone (both sides over 24) but are well under the 44 px W3C recommends for frequent controls. ^f9

## Read

- SC text, Intent, size and spacing sections with figures

## Not read

- Examples, test procedures, related techniques
