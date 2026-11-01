---
title: 'GitHub Changelog: GitHub Actions UI Improvements (2024-04-30)'
url: https://github.blog/changelog/2024-04-30-github-actions-ui-improvements/
kind: article
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: listed
relevance: medium
grade: A/fair
description: Streaming logs with backscroll: opening a running job shows the previous 1,000 lines at once
---
# GitHub Changelog: GitHub Actions UI Improvements (2024-04-30)

Why: live log behaviour for a run already in progress.

## Assessment

- Evidence: A. Vendor changelog.
- Reasoning: fair (states the problem it fixes).
- Interests: vendor announcement.
- Weigh: trust.

## Findings

- [ux/progress] Before 2024, opening a running job showed only lines emitted after page load. ^f1
  > Previously, an Actions job that was actively running would only stream the logs generated after the page was loaded. Logs emitted prior to the page loading would only be available after the job completed.
- [ux/progress] Now a running job's log opens with the last 1,000 lines, then streams. ^f2
  > Customers will now be able to visit the logs of a running job and immediately get the previous 1,000 log lines emitted.
- [ux/progress] Stated reason: following long jobs as they run. ^f3
  > This made it challenging to monitor the progress of jobs as they were running, particularly those that could take a long time to complete.
