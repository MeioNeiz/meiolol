---
title: 'GitHub Docs: Managing a merge queue'
url: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole page)
relevance: high
grade: A/fair
description: GitHub merge queue: cumulative merge groups tested in parallel, build concurrency 1-100, merge limits, a failing PR is removed and later groups rebuilt
---
# GitHub Docs: Managing a merge queue

Why: settings and failure behaviour of the most used merge queue today.

## Assessment

- Evidence: A. Vendor docs for a feature used across GitHub; bors-ng defers to it.
- Reasoning: fair. Describes behaviour and knobs, no guidance on values.
- Interests: vendor.
- Weigh: trust the behaviour; the page does not say how groups are split when a
  multi-PR group fails beyond removing the failing PR.

## Findings

- [devflow/queue] Each queued PR is tested on top of the latest base plus every PR
  ahead of it in the queue. ^f1
  > The merge queue will ensure the pull request's changes pass all required status checks when applied to the latest version of the target branch and any pull requests already in the queue.
- [devflow/queue] Build concurrency caps concurrent CI builds (1 to 100) and so the
  merge rate. ^f2
  > **Build concurrency:** The maximum number of `merge_group` webhooks to dispatch (between `1` and `100`), throttling the total amount of concurrent CI builds. This affects the velocity of merges that a merge queue can complete.
- [devflow/queue] Merge limits: minimum and maximum PRs merged at once (1 to 100), plus
  a timeout after which it merges with fewer than the minimum: a size-or-time batch
  trigger. ^f3
  > **Merge limits:** Select the minimum and maximum number of pull requests to merge into the base branch at the same time (between `1` and `100`), and a timeout after which the queue should stop waiting for more entries and merge with fewer than the minimum number.
- [devflow/queue] Groups are cumulative (main/pr-2 holds #1 and #2); when both pass,
  the later branch merges and carries both. ^f4
  > When the GitHub API receives successful CI responses for `merge_group` branches `main/pr-1` and `main/pr-2`, the temporary branch `main/pr-2` will be merged in to the target branch.
- [devflow/queue] A failing PR is removed from the queue and the groups behind it are
  rebuilt without it; the PRs after it are not dropped. ^f5
  > When the GitHub API receives a failing status for `main/pr-1`, the merge queue automatically removes pull request #1 from the merge queue.
  > The merge queue recreates the temporary branch with the prefix of `main/pr-2` to only contain changes from the target branch and pull request #2.
- [devflow/queue] A CI timeout counts as failure and removes the PR. ^f6
  > Timed out awaiting a successful CI result based off the configured timeout setting
- [devflow/queue] Jumping the queue forces a full rebuild of all in-progress groups. ^f7
  > Be aware that jumping to the top of a merge queue will cause a full rebuild of all in-progress pull requests, as the reordering of the queue introduces a break in the commit graph.
- [devflow/queue] Checked, not there: no bisection of a failed multi-PR group is
  described, and "Only merge non-failing pull requests" is named without saying how it
  forms groups. ^f8

## Read

- Whole page.

## Not read

- "Merging a pull request with a merge queue" how-to; `merge_group` event reference.
