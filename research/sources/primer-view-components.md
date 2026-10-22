---
title: 'GitHub Primer ViewComponents: previews, Playwright snapshots and axe checks'
url: https://github.com/primer/view_components/tree/9ae0fbeef95f4394fb6a8d3c31efc46db0f63650
kind: project
commit: 9ae0fbeef95f4394fb6a8d3c31efc46db0f63650
for: [ui-tooling]
looked: 2026-10-22
depth: code (playwright config, snapshots test, accessibility test, visual workflow, one preview; PR 3771)
relevance: high
grade: A/strong
description: GitHub's server-rendered Rails component library: every Lookbook preview is screenshotted in 7 themes, ARIA-snapshotted and axe-checked; the visual job is switched off since Nov 2025
---
# GitHub Primer ViewComponents

Why: how a mature server-rendered component library checks its UI.

## Assessment

- Evidence: A. GitHub's production component library, since Aug 2020, 583 stars, 30
  contributors, pushed today; used across github.com.
- Reasoning: strong in code (each check wired to the preview list), little prose.
- Interests: none.
- Weigh: the preview-list-drives-every-check pattern is the lesson; the disabled visual
  job is a maintenance cost signal (^f8, ^f10).

## Findings

- [web/qa] Previews are plain Ruby methods per component state, with params for the
  playground. `previews/primer/beta/button_preview.rb` ^f1
  > class ButtonPreview < ViewComponent::Preview
- [web/qa] The accessibility test loops over every Lookbook preview scenario, visits it
  and runs axe, with a per-component skip list. `test/accessibility_test.rb` ^f2
  > Lookbook.previews.each do |preview|
  > assert_accessible(excludes: excludes)
- [web/qa] Visual test screenshots every preview's `#component-preview` element, then
  again after Tab for the focus state. `test/playwright/snapshots.test.ts` ^f3
  > const defaultScreenshot = await page.locator('#component-preview').screenshot({animations: 'disabled'})
  > expect(focusedScreenshot).toMatchSnapshot([example.preview_path, 'focused.png'])
- [web/qa] Interactive previews are shot in seven themes (light, dark, colour-blind,
  high contrast). `test/playwright/snapshots.test.ts` ^f4
  > 'dark_colorblind',
- [web/qa] Besides pixels, every preview gets an ARIA snapshot (accessibility tree as
  YAML) compared as text. `test/playwright/snapshots.test.ts` ^f5
  > const defaultScreenshot = await page.locator('#component-preview').ariaSnapshot()
- [web/qa] Baselines are made in CI only: locally they advise a codespace so rendering
  matches CI; CI commits regenerated PNGs and YAML and the PR's file diff is the review.
  `docs/contributors/playwright-testing.md`, `.github/workflows/test-visual.yml` ^f6
  > To run Playwright locally, it is recommended to open the repo in a codespace. This is to ensure that the browser
  > commit_message: Generating component snapshots
- [web/qa] Chromium only, animations disabled, 10 s per test, 2 retries on CI.
  `playwright.config.ts` ^f7
  > animations: 'disabled',
  > retries: process.env.CI ? 2 : 0,
- [web/qa] The visual job is currently switched off on pull requests ("Temp skip").
  `.github/workflows/test-visual.yml` ^f8
  > # Temp skip this run
  > if: ${{ github.event_name == 'pull_request' && false }}
- [web/qa] The skip came from PR #3771 (Nov 2025), merged three minutes after opening:
  the tests caused friction; "temp", still off eleven months later. `pr-3771.md` (PR
  text saved from GitHub, not repo code) ^f10
  > The VRT tests have been causing friction, temp disabling while we can diagnose what's happening
- [web/qa] (inferred) For meiolol: one list of component states (a gallery page) can
  drive screenshots, ARIA snapshots, axe and layout checks at once; ARIA snapshots are
  text, so they diff stably across machines where PNGs don't. ^f9

## Read

- The six snapped files

## Not read

- Lookbook config, test_helpers, performance tests, selector tests
