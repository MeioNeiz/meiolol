---
title: 'Playwright docs: Visual comparisons (toHaveScreenshot)'
url: https://playwright.dev/docs/test-snapshots
kind: docs
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (whole page)
relevance: high
grade: A/fair
description: Official Playwright page on screenshot assertions: golden PNGs per browser and platform, pixelmatch threshold, stylePath, update flag
---
# Playwright docs: Visual comparisons (toHaveScreenshot)

Why: what the built-in visual regression in Playwright (already on the dev Mac) does and
where it is fragile.

## Assessment

- Evidence: A. Official docs of the dominant browser test tool (Microsoft).
- Reasoning: fair. Says what and how; little on maintenance cost.
- Interests: none beyond promoting Playwright.
- Weigh: trust the mechanics; flakiness advice is thin, see argos-flaky-visual-tests.

## Findings

- [web/qa] Golden screenshots: first run writes references, later runs compare against
  them; retakes until two consecutive shots match. Introduction, Generating ^f1
  > This method took a bunch of screenshots until two consecutive screenshots matched, and saved the last screenshot to file system.
- [web/qa] Rendering differs by host OS, version, hardware, even power source, so
  baselines only hold in the environment that made them. warning box ^f2
  > For consistent screenshots, run tests in the same environment where the baseline screenshots were generated.
- [web/qa] Baselines are per browser and platform (`-chromium-darwin` in the name),
  committed to git and reviewed. Generating ^f3
  > Screenshots differ between browsers and platforms due to different rendering, fonts and more, so you will need different snapshots for them.
- [web/qa] Comparison is pixelmatch with a per-pixel colour threshold (default 0.2) and
  an optional maxDiffPixels budget. Options ^f4
  > Defaults to `0.2`.
- [web/qa] stylePath injects a stylesheet at capture time to hide volatile elements.
  stylePath ^f5
  > This allows filtering out dynamic or volatile elements, hence improving the screenshot determinism.
- [web/qa] Text snapshots (toMatchSnapshot) compare non-image values, e.g. extracted text.
  Non-image snapshots ^f6
  > you can use `expect(value).toMatchSnapshot(snapshotName)` to compare text or arbitrary binary data.
- [web/qa] (inferred) For meiolol, Mac-only baselines are workable if only the dev Mac
  ever runs them; any move to CI on Linux means regenerating every baseline. ^f7

## Read

- Whole page

## Not read

- API reference for toHaveScreenshot options (animations, caret, mask, fullPage)
