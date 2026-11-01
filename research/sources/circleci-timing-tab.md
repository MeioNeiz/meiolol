---
title: 'CircleCI changelog: Timing tab shows the longest step in a job (2022)'
url: https://circleci.com/changelog/timing-tab-shows-the-longest-step-in-a-job
kind: article
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: listed
relevance: medium
grade: A/weak
description: CircleCI job Timing tab highlights the 3 longest steps
---
# CircleCI changelog: Timing tab shows the longest step in a job (2022)

Why: CircleCI's timing view.

## Assessment

- Evidence: A. Vendor changelog of a major CI.
- Reasoning: weak (one paragraph).
- Interests: vendor.
- Weigh: trust.

## Findings

- [ux/progress] A Timing tab per job calls out the 3 longest steps. ^f1
  > In the timing tab, the 3 longest steps in a job are displayed, with other steps per parallel run.
