---
title: 'Buildkite docs: Build page'
url: https://buildkite.com/docs/pipelines/build-page
kind: docs
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: docs
relevance: high
grade: B/fair
description: Buildkite's redesigned build page: sidebar of steps (by pipeline order or by state), Summary/Steps views, step panel with logs, follow mode, next-failure key
---
# Buildkite docs: Build page

Why: how Buildkite lays out one build's steps, running and failed.

## Assessment

- Evidence: B. Official docs of a mature CI product.
- Reasoning: fair (some tips explain why).
- Interests: vendor docs.
- Weigh: trust.

## Findings

- [ux/progress] Three parts: step sidebar, main view (Summary, Steps, Annotations), step panel with logs. ^f1
  > A collapsible _sidebar_ to allow for quick navigation between steps in your build.
  > The main _content area_ showing your selected view (**Summary**, **Steps**, or **Annotations**).
- [ux/progress] Sidebar can group by state so failed and waiting-for-input steps go first; remembered. ^f2
  > By default, steps are displayed in pipeline order. Switch to grouping by state instead to see important steps (such as those waiting for input or failed) at the top. Buildkite Pipelines remembers your choice for future builds.
- [ux/progress] A key (`f`) or button cycles through failures. ^f3
  > Use the action button (with the curved arrow) or press the `f` key to cycle through failures.
- [ux/progress] Skipped steps show why, in a tooltip, without opening a log. ^f4
  > Skipped steps show their reason without you needing to open a log.
- [ux/progress] Live updates; follow mode keeps focus on the active steps. ^f5
  > The build page updates in real time when you follow a build. When you follow a build, you'll focus on active steps as they complete.
- [ux/progress] Optional elevator music that stops when the build ends. ^f6
  > Turn on the elevator music for some calming build vibes. Hear your build finish as the music stops.
- [ux/progress] Retries: an indicator in the sidebar and a selector between attempts. ^f7
  > Use the retry selector to switch between attempts.
- [ux/progress] On phones the Canvas, Table and Waterfall views are hidden; the sidebar list stays. ^f8
  > On mobile devices, only the **Canvas**, **Table**, and **Waterfall** views are hidden.
