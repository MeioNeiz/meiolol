---
title: 'GitHub Docs: Using workflow run logs'
url: https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/using-workflow-run-logs
kind: docs
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: docs (viewing, searching logs)
relevance: high
grade: A/fair
description: GitHub Actions run page: job and step list, per-step time, failed steps auto-expanded, line permalinks, log search
---
# GitHub Docs: Using workflow run logs

Why: how GitHub Actions shows one run's steps and failures.

## Assessment

- Evidence: A. Official docs for the most used CI.
- Reasoning: fair (how-to, no rationale).
- Interests: vendor docs.
- Weigh: trust for what the UI does.

## Findings

- [ux/progress] The run page shows in progress or complete, then the result. ^f1
  > You can see whether a workflow run is in progress or complete from the workflow run page.
  > If the run is complete, you can see whether the result was a success, failure, canceled, or neutral.
- [ux/progress] Run, then jobs, then steps: a three-level hierarchy (check suite, check run per job, steps). ^f2
  > The check suite contains a check run for each job in the workflow, and each job includes steps.
- [ux/progress] Each step shows its duration; the failing step is identified. ^f3
  > If your workflow run fails, you can see which step caused the failure and review the failed step's build logs to troubleshoot. You can see the time it took for each step to run.
- [ux/progress] Failed steps open by themselves. ^f4
  > Any failed steps are automatically expanded to display the results.
- [ux/progress] Platform overhead is shown as its own steps, framing the user's steps. ^f5
  > GitHub adds two additional steps to each job to set up and complete the job's execution. These steps are logged in the workflow run with the names "Set up job" and "Complete job".
- [ux/progress] Line permalinks: click a step's line number to link to it. ^f6
  > to get a link to a specific line in the logs, click on the step's line number.
- [ux/progress] Log search covers only expanded steps. ^f7
  > When you search logs, only expanded steps are included in the results.
- [ux/progress] Checked, not there: no expected duration, no comparison with earlier runs on the run page. ^f8
