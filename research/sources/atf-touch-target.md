---
title: 'Google Accessibility Test Framework: TouchTargetSizeCheck'
url: https://github.com/google/Accessibility-Test-Framework-for-Android
kind: project
commit: c65cab02b2a845c29c3da100d6adefd345a144e3
for: [ui-guardrails]
looked: 2026-10-22
depth: code (src/main/java/com/google/android/apps/common/testing/accessibility/framework/checks/TouchTargetSizeCheck.java)
relevance: medium
grade: A/strong
description: Google's automated accessibility checks (behind Espresso and Accessibility Scanner): touch targets under 48x48 dp are errors, 32 dp at screen edges; demoted to warnings where the real hit area cannot be known
---
# Google Accessibility Test Framework: TouchTargetSizeCheck

Why: how a mature team checks target size automatically, and where it stops trusting
the check.

## Assessment

- Evidence: A. Google's framework behind Accessibility Scanner and Espresso
  accessibility checks; repo since 2015 (524 stars, last push Apr 2024).
- Reasoning: strong. Comments explain each exception and why it demotes to a warning.
- Interests: none.
- Weigh: Android views, but the false-positive handling transfers to DOM checks.

## Findings

- [web/qa] Default threshold 48x48 dp, 32 dp at the screen edge.
  `TouchTargetSizeCheck.java` ^f1
  > private static final int TOUCH_TARGET_MIN_HEIGHT = 48;
  > private static final int TOUCH_TARGET_MIN_HEIGHT_ON_EDGE = 32;
- [web/qa] A larger hit area (touch delegate) counts: no result when it meets the size.
  ^f2
  > // Emit no result if a delegate's hit-Rect is above the required size
- [web/qa] Where the true hit area cannot be measured (clickable parent, clipping,
  web content) the error is demoted to a warning to avoid false positives; web content
  gets a call for manual testing. ^f3
  > we cannot determine how exactly click actions are being handled by the underlying application, so to avoid false positives, we will demote ERROR to WARNING.
  > We reduce severity and append a message recommending manual testing when encountering WebView.
- [web/qa] (inferred) For meio.lol a Playwright test can measure every a, button and
  role=button box at 390 px and fail under 44 px unless an ancestor's padded hit area covers
  it; inline links in prose are the WCAG exception. ^f4

## Read

- TouchTargetSizeCheck.java

## Not read

- Other checks (contrast, labels), AccessibilityCheckPreset
