---
title: 'Railway docs: Deployments reference'
url: https://docs.railway.com/deployments/reference
kind: docs
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: docs (states, menu)
relevance: high
grade: B/fair
description: Railway deployment states (Initializing, Building, Deploying, Active, Failed, Crashed, Removed); View logs opens build or deploy logs by phase
---
# Railway docs: Deployments reference

Why: Railway's deploy status phases.

## Assessment

- Evidence: B. Official docs; younger, smaller host.
- Reasoning: fair.
- Interests: vendor docs.
- Weigh: trust.

## Findings

- [ux/progress] One status per deployment moving through fixed phases: Initializing, then Building. ^f1
  > Every Deployment in Railway begins as `Initializing` - once it has been accepted into Railway's build queue, the status will change to `Building`.
- [ux/progress] Deploying waits on the healthcheck before Active. ^f2
  > Once the build succeeds, Railway will attempt to deploy your image and the Deployment's status becomes `Deploying`. If a [healthcheck](https://docs.railway.com/deployments/healthchecks) is configured, Railway will wait for it to succeed before proceeding to the next step.
- [ux/progress] Active means healthcheck passed, or container started if none. ^f3
  > If the deployment **has** a [healthcheck](https://docs.railway.com/deployments/healthchecks) configured, Railway will mark the deployment as `Active` when the healthcheck succeeds.
- [ux/progress] Any error ends in Failed. ^f4
  > If an error occurs during the build or deploy process, the Deployment will stop and the status will become `Failed`.
- [ux/progress] View logs opens the log for the current phase. ^f5
  > during build the build logs will be shown, during deploy the deploy logs will be shown.
- [ux/progress] Old deploys move to history via Removing and Removed after a new one goes live. ^f6
  > older deploys in a `Active`, `Completed`, or a `Crashed` state are eventually removed - first having their status updated to `Removing` before they are finally `Removed`.
