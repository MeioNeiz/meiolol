---
title: 'Argos blog: How to fix flaky visual tests (Aug 2026)'
url: https://argos-ci.com/blog/fix-flaky-visual-tests
kind: article
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: listed
relevance: medium
grade: B/fair
description: Visual testing vendor's CEO lists the root causes of flaky screenshot tests (fonts, animations, images, network, dates, OS rendering, viewport) with a fix for each
---
# Argos blog: How to fix flaky visual tests (Aug 2026)

Why: flakiness causes and fixes for screenshot tests, and what a platform adds over
plain Playwright.

## Assessment

- Evidence: B. First-hand report from the co-founder of Argos (open-source visual
  testing platform) across its customers; no numbers.
- Reasoning: fair. Each cause has a mechanism and a fix; admits cross-OS noise can't be
  removed at the page level.
- Interests: vendor; the cross-machine section argues for buying Argos.
- Weigh: the cause list matches Playwright's own warning; discount "a platform earns its
  keep".

## Findings

- [web/qa] Cost of flakiness: false positives train reviewers to approve without looking,
  letting real regressions through. What is a flaky visual test ^f1
  > Each false positive trains reviewers to click "approve" without looking, which is how real regressions slip through.
- [web/qa] Causes are a short list: fonts, animations, images, network, dynamic data,
  rendering environment, viewport. Conclusion ^f2
  > They come from a finite list of causes: fonts, animations, images, network, dynamic data, rendering environments, and viewports, and each has a deterministic fix.
- [web/qa] Fonts are the most common source of whole-page diffs; wait for
  document.fonts.ready and make sure fonts are served. Web fonts ^f3
  > This is the single most common source of full-page diffs.
- [web/qa] Order: make the page deterministic first, then tune tolerance per screenshot,
  never a loose global threshold. What is a flaky visual test, FAQ ^f4
  > **make the page deterministic before capture**, and only then tune tolerance on the comparison side.
  > A global tolerance high enough to absorb a font swap or a mid-animation frame will also absorb real one-line CSS regressions.
- [web/qa] Laptop and CI baselines never match; capture in one canonical environment.
  Machines ^f5
  > baselines generated on your laptop are worthless in CI, and vice versa
- [web/qa] Pin viewport and deviceScaleFactor; macOS overlay scrollbars vs 15 px classic
  ones change content width. Viewport ^f6
  > macOS uses overlay scrollbars (zero width), Linux and Windows use classic scrollbars that consume ~15px of layout.
- [web/qa] Unstable row order from a query flips screenshots; freeze clocks and seed data.
  Dates ^f7
  > A missing sort order is a classic: the database returns rows in a valid but unstable order, and your screenshot flips between two arrangements.
- [web/qa] (inferred) meiolol's site from a fixed fixture (pipeline_test's games) is
  already deterministic data; fonts, the date in the footer and the wasm chart are the
  remaining sources to pin. ^f8

## Read

- Whole post

## Not read

- Linked "limits of Playwright snapshots" and image stabilisation posts
