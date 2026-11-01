---
title: "JENKINS-29252: 'Estimated remaining time' should become 'Overdue by' when the ETA is negative"
url: https://issues.jenkins.io/browse/JENKINS-29252
kind: thread
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: listed
relevance: medium
grade: C/fair
description: 2015 Jenkins issue: once a build passes its estimate the tooltip says N/A; proposes Overdue by instead (unresolved)
---
# JENKINS-29252: 'Estimated remaining time' should become 'Overdue by'

Why: the gap in Jenkins' progress bar when a run runs long.

## Assessment

- Evidence: C. One user's issue, unresolved, one vote.
- Reasoning: fair (clear argument).
- Interests: none.
- Weigh: the argument stands on its own; matches [[jenkins-estimated-duration#^f4]].

## Findings

- [ux/progress] Overrun means different things for short and long jobs; the bar does not say. ^f1
  > A build that's expected to take thirty-eight minutes running for forty minutes means something very different to one that's expected to take thirty seconds. The progress bar tooltips offer no indication of this.
- [ux/progress] Proposal: replace N/A with an overdue amount. ^f2
  > I would suggest subbing out 'Estimated remaining time: N/A' with 'Overdue by: \[timedelta\]'
