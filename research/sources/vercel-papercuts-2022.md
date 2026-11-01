---
title: 'Vercel changelog: Improvements and Fixes (September 2022)'
url: https://vercel.com/changelog/september-2022-papercuts.md
kind: article
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: listed
relevance: low
grade: A/weak
description: Deployment total now sums all 3 steps; step timestamps no longer rounded; npm ERR! lines highlighted red
---
# Vercel changelog: Improvements and Fixes (September 2022)

Why: Vercel's step durations.

## Assessment

- Evidence: A. Vendor changelog.
- Reasoning: weak (bullets).
- Interests: vendor.
- Weigh: trust.

## Findings

- [ux/progress] Total covers all 3 steps; each step has a time next to it, now unrounded. ^f1
  > The [total duration time](https://vercel.com/docs/concepts/deployments/troubleshoot-a-build#build-duration) shown in the deployment tab on the Vercel dashboard now includes all 3 steps (building, checking, and assigning domains) and the time stamp next to each step is no longer rounded up.
- [ux/progress] Error lines highlighted red in the log. ^f2
  > Logs that start with `npm ERR!` are now highlighted in red in deployment logs.
