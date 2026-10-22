---
title: 'Playwright docs: Accessibility testing (@axe-core/playwright)'
url: https://playwright.dev/docs/accessibility-testing
kind: docs
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (to test fixtures)
relevance: high
grade: A/fair
description: Official Playwright guide to running axe-core scans in tests: whole page or part, WCAG tag filters, excluding elements, disabling rules, snapshotting violation fingerprints
---
# Playwright docs: Accessibility testing (@axe-core/playwright)

Why: how to run axe in the Playwright the dev Mac already has.

## Assessment

- Evidence: A. Official docs.
- Reasoning: fair. Clear about limits of automation; explains why whole-violation
  snapshots are fragile.
- Interests: none.
- Weigh: trust as how-to.

## Findings

- [web/qa] What axe catches: poor contrast, unlabelled controls, duplicate ids.
  Introduction ^f1
  > Text that would be hard to read for users with vision impairments due to poor color contrast with the background behind it
- [web/qa] One call per page: `new AxeBuilder({ page }).analyze()`, assert no violations.
  Scanning an entire page ^f2
  > Awaits `AxeBuilder.analyze()` to run the accessibility scan against the page
- [web/qa] Many problems need manual testing; Microsoft's own disclaimer. Disclaimer ^f3
  > But many accessibility problems can only be discovered through manual testing.
- [web/qa] Known issues: disable a rule while fixing, or snapshot a fingerprint (rule plus
  selectors) of known violations, never the raw violation array. Handling known issues ^f4
  > Instead, create a _fingerprint_ of the violation(s) in question that contains only enough information to uniquely identify the issue, and use a snapshot of the fingerprint:
- [web/qa] Scans see the page as it is; reveal interactive parts first, then analyse.
  Configuring ^f5
  > `AxeBuilder.analyze()` will scan the page _in its current state_ when you call it.
- [web/qa] (inferred) axe-core is one JS file injected into the page: Primer injects
  axe.min.js itself from Ruby (primer-view-components#^f2), so a qa script can do the
  same without the npm wrapper. ^f6

## Read

- Page to the fixture section

## Not read

- Test fixture example
