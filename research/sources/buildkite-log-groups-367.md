---
title: 'Buildkite changelog: Improvements to log groups for running builds (2026-06-17)'
url: https://buildkite.com/resources/changelog/367-improvements-to-log-groups-for-running-builds/
kind: article
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: listed
relevance: high
grade: B/fair
description: Running log group shows a ticking duration and growing bar instead of a spinner; auto-expands, folds back when done; sticky headers
---
# Buildkite changelog: Improvements to log groups for running builds (2026-06-17)

Why: how a running section of a step is shown live.

## Assessment

- Evidence: B. Vendor changelog.
- Reasoning: fair (contrasts with the spinner it replaces).
- Interests: vendor announcement.
- Weigh: trust.

## Findings

- [ux/progress] The running section shows a ticking duration and a growing bar, replacing a spinner. ^f1
  > The running log group now shows a ticking duration and a bar that grows in real time, instead of a spinner you stare at until the group finishes.
- [ux/progress] The running section auto-expands, folds back when done, and the next one opens. ^f2
  > The group that's currently running expands automatically so its output stays visible. When the job moves on, it folds back to how the step defined it and the next group opens.
- [ux/progress] Sticky section headers in long logs. ^f3
  > Scroll deep into a long expanded group and its header sticks just below the toolbar, then hands off to the next group as you pass it.
- [ux/progress] (inferred) The bar grows with elapsed time; nothing says it is scaled to an expected duration. ^f4
