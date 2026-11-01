---
title: 'CircleCI Help Center: Debugging Slow or Hanging Jobs'
url: https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci
kind: docs
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: skimmed
relevance: low
grade: A/fair
description: CircleCI job page: each step header shows elapsed time; per-test timing across runs via store_test_results
---
# CircleCI Help Center: Debugging Slow or Hanging Jobs

Why: CircleCI's step list.

## Assessment

- Evidence: A. Vendor support docs.
- Reasoning: fair.
- Interests: vendor.
- Weigh: trust.

## Findings

- [ux/progress] Each step header shows its elapsed time. ^f1
  > Each step in the job shows its elapsed time in the step header, which lets you quickly identify which step is the bottleneck without any configuration changes.
- [ux/progress] Timing history across runs exists for tests, not steps. ^f2
  > If your slow step is a test suite, CircleCI can store and analyze per-test timing data across runs.
