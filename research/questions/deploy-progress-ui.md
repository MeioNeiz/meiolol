---
status: answered
priority: soon
area: ui
tags: [ux/progress]
description: How do CI/CD and hosting products show a single run's steps and its progress while it runs and after?
---
# How do CI/CD and hosting products show a single run's steps and its progress while it runs and after?

Feeds: the admin page's Deploys tab (one deploy's steps, live and after).

## Answer

Every product lists a run's steps top to bottom in run order, each with a status icon,
name and its own duration, plus a total (C1). Graphs are an extra view, not the default:
GitHub's run graph shows jobs, not steps (C2), and Buildkite's users often found the
graph and table unhelpful and asked to stay on their preferred view (C9). Buildkite's
waterfall splits each bar into queue wait, start-up and run time, but only for finished
steps (C3).

While running: logs stream live and open with the recent backlog (C4); the running
section expands by itself and shows a ticking duration and growing bar instead of a
spinner (C5). Only Jenkins draws progress against an expected duration: the mean of the
last 3 good builds, capped at 99%, with "N/A" once overdue and "likely stuck" at 10x
(C6). Users ask for this elsewhere and the overdue gap is a known complaint (C7). No
product found shows "usual duration" or a sparkline per step on the run page (C8).

On failure: the failed step expands and the log scrolls to it (C10); Buildkite groups by
state so failures go first, tints them red and has a next-failure key (C11). Hosts add a
summary above the log: Netlify counts outcomes (files, functions, rules) and compares
with the previous deploy (C12); Vercel and Render put an error summary or Notices panel
up top (C13). Hosts show a few coarse phases (Railway: Initializing, Building,
Deploying, Active; Vercel: building, checking, assigning domains) with "live" as the
end state, and Render badges the deploy actually serving traffic, not the newest (C14).

## Claims

- C1: Step pages are a vertical list in run order: status icon, name, own duration, and a total. for: [[github-run-logs#^f3]], [[vercel-troubleshoot-build#^f2]], [[vercel-papercuts-2022#^f1]], [[circleci-step-duration-support#^f1]], [[buildkite-build-page-docs#^f1]]
- C2: GitHub's live run graph shows jobs with status icons and dependency lines, not steps. for: [[github-visualization-graph#^f1]], [[github-visualization-graph#^f2]]
- C3: Buildkite's waterfall splits each step's bar into waiting, agent start-up and running (green or red), finished steps only, durations on hover. for: [[buildkite-waterfall-docs#^f2]], [[buildkite-waterfall-docs#^f3]], [[buildkite-waterfall-docs#^f4]], [[buildkite-waterfall-191#^f1]]
- C4: Logs stream live and open on a running job with recent history, not blank. for: [[github-actions-ui-improvements-2024#^f2]], [[netlify-deploy-summaries-2018#^f1]]
- C5: The running section auto-expands and shows a ticking duration and growing bar instead of a spinner. for: [[buildkite-log-groups-367#^f1]], [[buildkite-log-groups-367#^f2]]
- C6: Jenkins shows progress as elapsed over the mean of the last 3 good builds, capped at 99%, ETA N/A once overdue, stuck at 10x. for: [[jenkins-estimated-duration#^f1]], [[jenkins-estimated-duration#^f2]], [[jenkins-estimated-duration#^f3]], [[jenkins-estimated-duration#^f4]], [[jenkins-estimated-duration#^f5]]
- C7: Users want expected-duration progress per step, and an overdue figure once past it. for: [[buildkite-forum-estimated-duration#^f1]], [[buildkite-forum-estimated-duration#^f2]], [[jenkins-29252-overdue#^f1]], [[jenkins-29252-overdue#^f2]]
- C8: GitHub, Vercel and Buildkite's run pages show no expected duration or comparison with past runs per step. for: [[github-run-logs#^f8]], [[vercel-troubleshoot-build#^f5]], [[buildkite-log-groups-367#^f4]], [[buildkite-forum-estimated-duration#^f4]]
- C9: The list (sidebar) is the default; graph and table views are optional and often unhelpful. for: [[buildkite-new-build-page-271#^f1]], [[buildkite-new-build-page-271#^f2]], [[buildkite-build-page-docs#^f8]]
- C10: A failed step is expanded and scrolled to by itself. for: [[github-run-logs#^f4]], [[github-actions-log-improvements-2020#^f1]], [[vercel-troubleshoot-build#^f1]]
- C11: Buildkite puts failures first: group by state, collapse Passed, red tint, next-failure key, failed job shown and passed siblings hidden. for: [[buildkite-build-page-docs#^f2]], [[buildkite-build-page-docs#^f3]], [[buildkite-new-build-page-271#^f3]], [[buildkite-new-build-page-271#^f4]], [[buildkite-new-build-page-271#^f5]]
- C12: Netlify puts an outcome summary above the log (files uploaded, rules, functions) that links into the log and compares with earlier deploys. for: [[netlify-deploy-overview#^f1]], [[netlify-deploy-overview#^f2]], [[netlify-deploy-overview#^f3]], [[netlify-deploy-summaries-2018#^f2]]
- C13: Hosts surface the failure reason in a panel above the log. for: [[vercel-troubleshoot-build#^f1]], [[render-deploys-page#^f3]], [[netlify-deploy-overview#^f5]]
- C14: Hosts show a few coarse phases ending in live, and mark which deploy is serving traffic. for: [[railway-deployments-ref#^f1]], [[railway-deployments-ref#^f2]], [[railway-deployments-ref#^f3]], [[vercel-troubleshoot-build#^f2]], [[render-deploys-page#^f2]]
- C15 (inferred): For meiolol's Deploys tab: a step list with icon, name, own duration and start offset; a ticking timer on the running step with a bar against the usual time from recent deploys (Jenkins' method, but "overdue by" past it); failed step first and expanded; a headline of total and time to live. from: C1, C5, C6, C7, C10, C14

## Disagreements

None found: products differ in emphasis, not in conflicting claims.

## Open

- GitLab pipeline graph (stage and needs views) and Fly.io deploy output not read; GitLab
  issue 62603 (progress in status icons) was not public.
- Whether any product shows per-step duration history (sparkline) on a run page: none
  found in 4 searches; Buildkite said in 2023 it would look at step metrics.
- Azure DevOps and TeamCity (TeamCity also estimates from history) not checked.
