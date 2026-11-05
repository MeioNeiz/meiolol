---
title: 'Zuul docs: Project Gating (dependent pipeline, speculative execution, window)'
url: https://zuul-ci.org/docs/zuul/latest/gating.html
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole page)
relevance: high
grade: A/strong
description: Zuul's dependent pipeline tests each queued change on top of those ahead in parallel; a failure re-tests those behind without it; TCP-like window
---
# Zuul docs: Project Gating (dependent pipeline, speculative execution, window)

Why: speculative parallel gating and how it sizes its parallelism on failures.

## Assessment

- Evidence: A. Zuul gates OpenStack and others since 2012.
- Reasoning: strong. Explains best and worst cases and why the window adapts.
- Interests: project docs.
- Weigh: assumes enough executors to run the window in parallel; with one build pool
  the speculative builds compete for the same slots.

## Findings

- [devflow/queue] A gate should test each change on the branch tip exactly as it will
  merge; one at a time works but waits grow when changes arrive faster than they
  test. ^f1
  > A gating system should always test each change applied to the tip of the branch exactly as it is going to be merged.
- [devflow/queue] The dependent pipeline speculates that all ahead will pass and tests
  in parallel; if one fails, those behind it are re-tested without it. ^f2
  > It does this by performing speculative execution of test jobs; it assumes that all jobs will succeed and tests them in parallel accordingly. If they do succeed, they can all be merged. However, if one fails, then changes that were expecting it to succeed are re-tested without the failed change.
- [devflow/queue] Best case merges as many changes as execution contexts at once;
  worst case is one at a time. ^f3
  > In the best case, as many changes as execution contexts are available may be tested in parallel and merged at once. In the worst case, changes are tested one at a time (as each subsequent change fails, changes behind it start again).
- [devflow/queue] On failure only the failing change is reported and dropped; changes
  behind it stay queued and restart against the new tip. ^f4
  > Since _C_ failed, Zuul will report its failure and drop _C_ from the queue, keeping D and E:
- [devflow/queue] The window limits how many head-of-queue changes run jobs: large when
  builds mostly pass (throughput), small when they often fail (less waste). ^f5
  > Ideally if builds frequently succeed, the window should be large in order to maximize throughput, and if they frequently fail, it should be small in order to minimize waste.
- [devflow/queue] Default window: start at 20, +1 per merge, halved per failure (TCP
  style), with a floor and optional ceiling. ^f6
  > It starts with the window set to a certain value (twenty changes by default). Each time a change successfully merges, the window is increased by one. Each time a change fails, the window is halved.
- [devflow/queue] Serial pipelines have a fixed window of 1. ^f7
  > serial pipelines have a fixed window size of 1

## Read

- Whole page.

## Not read

- `pipeline.window` config reference (floor, ceiling defaults).
