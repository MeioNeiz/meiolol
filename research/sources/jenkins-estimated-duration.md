---
title: 'Jenkins core: estimated duration and executor progress (Job.java, Executor.java)'
url: https://github.com/jenkinsci/jenkins
kind: project
commit: 868e11ad4e4708f2dbe0797423a525fb1e07dc78
for: [deploy-progress-ui]
looked: 2026-11-01
depth: code (Job.getEstimatedDuration, Executor progress and ETA)
relevance: high
grade: A/fair
description: Jenkins' build progress bar: mean of the last 3 good builds, percent capped at 99, ETA shown N/A once overdue, stuck at 10x the estimate
---
# Jenkins core: estimated duration and executor progress

Why: the classic expected-duration progress bar, as code.

## Assessment

- Evidence: A. Jenkins core, decades of use.
- Reasoning: fair (doc comments explain the candidate choice).
- Interests: none.
- Weigh: trust for the method.

## Findings

- [ux/progress] Estimate source: the last 3 successful (or unstable) builds, else failed ones, looking back at most 6. `core/src/main/java/hudson/model/Job.java` ^f1
  > Returns the 3 last successful (stable or unstable) builds, if there are any.
  > Failing to find 3 of those, it will return up to 3 last unsuccessful builds.
  > In any case it will not go more than 6 builds into the past to avoid costly build loading.
- [ux/progress] The estimate is the plain mean of those durations. `Job.java` ^f2
  > return Math.round((double) totalDuration / builds.size());
- [ux/progress] Progress percent is elapsed over estimate, capped at 99 so it never shows done early. `core/src/main/java/hudson/model/Executor.java` ^f3
  > int num = (int) (getElapsedTime() * 100 / d);
  > if (num >= 100) {
- [ux/progress] Remaining time shows N/A once past the estimate (no "overdue by"). `Executor.java` ^f4
  > long eta = d - getElapsedTime();
  > if (eta <= 0) {
  > return Messages.Executor_NotAvailable();
- [ux/progress] A build is flagged likely stuck at 10x its estimate, or after a day with no estimate. `Executor.java` ^f5
  > // if it's taking 10 times longer than ETA, consider it stuck
  > // if no ETA is available, a build taking longer than a day is considered stuck
