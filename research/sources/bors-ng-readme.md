---
title: 'bors-ng README: merge queue with batching and bisection'
url: https://raw.githubusercontent.com/bors-ng/bors-ng/master/README.md
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (README, how it works)
relevance: high
grade: A/fair
description: bors-ng's batching merge queue: one batch running, one accumulating; on failure split in half and requeue; O(E log N)
---
# bors-ng README: merge queue with batching and bisection

Why: how a batching queue handles a failed batch, compared with our drop-the-tail rule.

## Assessment

- Evidence: A. Ran Rust-adjacent and many other projects for years (repo created
  2016-12, 1,527 stars, 187 forks, 92 contributors; archived 2024-04).
- Reasoning: fair. Explains the batch and bisect strategy with a worked example and a
  complexity bound; no measured numbers.
- Interests: none. Deprecated in favour of GitHub merge queue.
- Weigh: the bisect behaviour is the useful bit; O(E log N) is a count of CI runs, not
  wall time.

## Findings

- [devflow/queue] Deprecated: the author points users to GitHub's built-in merge queue
  for this workflow. ^f1
  > If you want to implement a workflow like this, use [GitHub's built-in merge queue][ghmq].
- [devflow/queue] Batches on the assumption that reviewed PRs usually pass, and
  bisects a failed batch. ^f2
  > Based on the assumption that the tests usually pass once they're r+-ed,
  > bors actually tests them in batches (and bisects if a batch fails).
- [devflow/queue] When all passes there are only two batches: one running, one
  waiting and accumulating PRs until it can run. Batch size is set by arrivals during
  one CI run, not by a timer. ^f3
  > If everything passes, there will just be two batches; the one that's running, and the one that's waiting to be run (and is accumulating more and more pull requests until it gets a chance to run).
- [devflow/queue] A batch is one merge commit (main plus all its PRs) pushed to
  `staging`; main fast-forwards to it on pass, so main holds exactly what was tested. ^f4
  > If the build passes, the main branch gets fast-forwarded to meet the staging branch. Since the main branch contains the exact contents that were just tested, bit-for-bit, it's not broken.
- [devflow/queue] On failure it splits the batch into two and requeues both; the
  passing half lands, the failing half splits again. ^f5
  > If the build fails, bors will follow a strategy called "bisecting". Namely, it splits the batch into two batches, and pushes those to the queue.
- [devflow/queue] Bisection also untangles an interaction failure: two PRs that only
  fail together end up in separate batches and both land. ^f6
  > This one will pass, since the PR it conflicts with (#7) is sitting behind it in the queue.
- [devflow/queue] A single-PR batch that fails goes back to its author. ^f7
  > When a batch cannot be bisected (because it only contains one PR), it gets kicked back to the creator so they can fix it.
- [devflow/queue] Cost: one at a time is O(N) CI runs; batching is O(E log N), E the
  number of failing PRs. ^f8
  > The one-at-a-time strategy is O(N), where N is the total number of pull requests.
  > The batching strategy is O(E log N), where N is again the total number of pull requests and E is the number of pull requests that fail.

## Read

- README: intro, How it works.

## Not read

- `lib/worker/batcher.ex`: exact split rule, timeouts, priority handling.
