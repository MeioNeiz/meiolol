---
title: 'Buildkite forum: Allow an "estimated duration" for jobs and show a progress indicator'
url: https://forum.buildkite.community/t/allow-an-estimated-duration-for-jobs-and-show-a-progress-indicator/2878
kind: thread
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: skimmed
relevance: medium
grade: C/fair
description: 2023 feature request for elapsed-vs-estimate progress per step, citing Jenkins; Buildkite product asks what users would do with it
---
# Buildkite forum: Allow an "estimated duration" for jobs and show a progress indicator

Why: user need for expected-duration progress, and a CI vendor's response.

## Assessment

- Evidence: C. One user's request plus staff replies.
- Reasoning: fair (states the need plainly).
- Interests: none.
- Weigh: shows the need; not proof it is common.

## Findings

- [ux/progress] Request: a progress indicator of elapsed time against an estimate, from history or set by hand. ^f1
  > The build/job UI could then display some sort of progress indicator comparing elapsed wall-clock time to estimated duration.
  > It could be left to whoever builds the pipeline to provide an estimate or BK could track historical data and do it automatically.
- [ux/progress] The need: how long is left, at a glance, per step. ^f2
  > I’d just like to get a feel, at a glance, for how long to expect to wait for the build to complete. Do we have a couple of seconds remaining? A couple of minutes? An hour? Displaying this information at the step level would be most useful.
- [ux/progress] Jenkins is cited as doing this from about the last 3 builds. ^f3
  > Jenkins does something like this by calculating an estimate based on the last 3 builds or so and then drawing a progress bar comparing the estimate with the elapsed time.
- [ux/progress] Buildkite staff had not heard the idea before (2023). ^f4
  > I don’t believe this sort of idea has been brought up before
