---
title: 'GitHub Docs: Using the visualization graph'
url: https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/using-the-visualization-graph
kind: docs
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: listed
relevance: medium
grade: A/weak
description: GitHub Actions run summary graph: a live graph of jobs with status icons and dependency lines
---
# GitHub Docs: Using the visualization graph

Why: GitHub's run summary graph.

## Assessment

- Evidence: A. Official docs.
- Reasoning: weak (a few lines).
- Interests: vendor docs.
- Weigh: trust; short.

## Findings

- [ux/progress] Every run gets a live graph of its progress. ^f1
  > Every workflow run generates a real-time graph that illustrates the run progress.
- [ux/progress] Graph nodes are jobs (not steps): status icon left of the name, lines for dependencies; click opens the job log. ^f2
  > The graph displays each job in the workflow. An icon to the left of the job name indicates the status of the job. Lines between jobs indicate dependencies.
  > To view a job's log, click the job.
