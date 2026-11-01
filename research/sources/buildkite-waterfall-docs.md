---
title: 'Buildkite docs: Waterfall view'
url: https://buildkite.com/docs/pipelines/waterfall
kind: docs
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: docs
relevance: high
grade: B/fair
description: Buildkite waterfall chart: one row per step, bar split into waiting for agent, agent starting, running (green/red)
---
# Buildkite docs: Waterfall view

Why: the most detailed published description of a step waterfall.

## Assessment

- Evidence: B. Official docs of a mature CI product.
- Reasoning: fair (explains each colour and the limits).
- Interests: vendor docs.
- Weigh: trust.

## Findings

- [ux/progress] Waterfall chart of jobs: durations and dependencies at a glance. ^f1
  > Waterfall view allows you to see build data as a waterfall chart, providing enhanced visibility into your build's job processes, durations and dependencies.
- [ux/progress] Finished steps only: not a live view. ^f2
  > Waterfall view only displays data for finished steps.
- [ux/progress] Each bar splits into queue wait (grey), agent start-up (yellow) and run time (green pass, red fail). ^f3
  > Gray: time the job spent waiting for an agent to be assigned.
  > Yellow: time elapsed since the agent was assigned, up until the time the agent started running the job.
  > Green or Red: time the agent spent running the job. Displayed as green for a **passed** job or red for a **failed** job.
- [ux/progress] Durations on hover, to the second. ^f4
  > You can hover over a bar to view these durations. Time is rounded to the nearest second.
- [ux/progress] Groups get a parent row with a solid bar for the children's total, red if any child failed. ^f5
  > A parent row displays a solid bar representing the total duration of its child rows. The bar is green if all child rows passed, and red if any of them failed.
- [ux/progress] Size cap: 3,000 jobs and 1,800 steps. ^f6
  > Waterfall view is available for builds with up to 3,000 jobs and up to 1,800 steps.
