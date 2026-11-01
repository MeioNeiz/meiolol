---
title: 'Buildkite changelog: Responding to feedback for the new build page (2025-03-27)'
url: https://buildkite.com/resources/changelog/271-responding-to-feedback-for-the-new-build-page/
kind: article
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: listed
relevance: medium
grade: B/fair
description: New build page changes after user feedback: one Steps tab with Canvas/Table/Waterfall, collapsed Passed group persists, failed steps tinted red
---
# Buildkite changelog: Responding to feedback for the new build page (2025-03-27)

Why: what users of a step page pushed back on.

## Assessment

- Evidence: B. Vendor changelog responding to user feedback.
- Reasoning: fair (gives the reason for each change).
- Interests: vendor announcement.
- Weigh: trust as what changed and why.

## Findings

- [ux/progress] Canvas, Table and Waterfall are views of one Steps tab; the choice persists. ^f1
  > Your personal selection of "Canvas", "Table", or "Waterfall" is remembered as you navigate across builds. These views are now consolidated into a single "Steps" tab where you control which visualization you'd like to use.
- [ux/progress] Users found the graph (canvas) or table often unhelpful. ^f2
  > Many people gave us feedback about situations where the canvas or table weren’t particularly useful and now they’ll be able to stay on their preferred view.
- [ux/progress] Sidebar groups by state (Failed, Running, Passed); collapsing Passed sticks across builds. ^f3
  > we persist collapsed states in the build page sidebar (ie. Failed, Running, Passed). With large builds showing hundreds of passed steps you don't need to see, once you collapse Passed steps they'll stay like that on all consecutive builds.
- [ux/progress] Failed parallel job shown, passed siblings hidden at first. ^f4
  > You’ll see how we present the failed job, but we initially hide the passed jobs.
- [ux/progress] Failed steps get a light red background. ^f5
  > We have also changed the way we display failed steps, by giving them a slight red background.
- [ux/progress] Waterfall used for finding slow jobs; now filterable by job. ^f6
  > debugging some job slowness using the waterfall view? Waterfall now supports job-level filtering.
