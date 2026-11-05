---
title: 'Keeping Master Green at Scale (Ananthanarayanan et al., EuroSys 2019)'
url: https://dl.acm.org/doi/10.1145/3302424.3303970
kind: paper
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: skimmed (sections 1-2, 8, 10)
relevance: high
grade: A/strong
description: Uber's SubmitQueue: probabilistic speculation plus conflict analysis keeps master green; compares single queue, batching, optimistic (Zuul) and speculate-all
---
# Keeping Master Green at Scale (Ananthanarayanan et al., EuroSys 2019)

Why: measured comparison of queue strategies and why plain batching fails at high
failure rates. PDF is CC BY (ACM open access); snapshot via the Wayback copy.

## Assessment

- Evidence: A. Peer-reviewed (EuroSys), in production over a year at Uber on
  thousands of daily commits; simulation on real data with an Oracle baseline.
- Reasoning: strong. Compares four alternatives, states limits and future work.
- Interests: authors built the system they evaluate.
- Weigh: scale (hundreds of changes per hour, hundreds of workers) is far above ours;
  the failure-mode arguments transfer, the speedup numbers do not.

## Findings

- [devflow/queue] Requirements: always green master, high throughput, low commit
  turnaround time. ^f1
  > three uncompromisable key requirements — always green master, high throughput, and low commit turnaround time
- [devflow/queue] Changes that pass alone can break together: with 2 concurrent
  potentially conflicting changes there is a 5% chance of a real conflict, 40% with
  16. ^f2
  > Observe that with even two concurrent and potentially conflicting changes, there is a 5% chance of a real conflict. This number grows to 40% with only 16 concurrent and potentially conflicting changes.
- [devflow/queue] Even changes 1 to 10 hours stale have a 10% to 20% chance of making
  the mainline red. ^f3
  > even changes with one to ten hour staleness have between 10% to 20% chance of making the mainline red
- [devflow/queue] A single queue (bors style) does not scale: 1,000 changes a day at
  30 min each puts the last one over 20 days out. ^f4
  > with a thousand changes per day, where each change takes 30 minutes to pass all build steps, the turnaround time of the last enqueued change will be over 20 days.
- [devflow/queue] Batching: a failed batch is divided and retried; as batches grow the
  failure probability rises, batches split often, and SLAs cannot be guaranteed. ^f5
  > Otherwise, the batch needs to get divided into smaller batches, and get retried.
  > This leads to batches getting divided and retried frequently. Therefore, SLAs cannot be guaranteed
- [devflow/queue] Chromium's Commit Queue rejects the whole batch on failure (suite
  about four hours, batches picked every few hours); sheriffs find culprits by hand and
  innocent changes must be re-batched. ^f6
  > If the build breaks at this stage, the entire batch gets rejected.
  > Non-faulty changes, though, need to undergo another round of batching, and can only get accepted if no faulty change exists in a round.
- [devflow/queue] Batching yields shippable batches, not shippable commits: a fix must
  land in the same batch as the change it fixes. ^f7
  > observe that this approach leads to shippable batches, and not shippable commits.
- [devflow/queue] Optimistic speculation (Zuul): a failure aborts every build that
  assumed it would pass; abort rate rises with conflict probability. ^f8
  > this approach does not scale and results in high turnaround time since failure of a change can abort many optimistically executing builds.
- [devflow/queue] SubmitQueue: a speculation tree of possible outcomes, a logistic
  regression model picks builds most likely to succeed and runs them in parallel; a
  conflict graph prunes it and lets independent changes commit in parallel. ^f9
  > The speculation graph allows SubmitQueue to select builds that are most likely to succeed, and speculatively execute them in parallel.
- [devflow/queue] Results vs a perfect Oracle: SubmitQueue P50 at most 2.98x slower;
  with 500 workers for 500 changes an hour, P50/P95/P99 about 1.2x Oracle. ^f10
  > leads to maximum of 2.98x slower 50-percentile turnaround time, compared to the optimal Oracle solution.
  > turnaround time gets reduced to 1.2x of the Oracle’s.
- [devflow/queue] Single-Queue is worst: at 500 changes an hour P50, P95, P99 are 80x,
  129x and 132x Oracle; Speculate-all up to 15x (P50) and 24x (P99); Optimistic beats
  Speculate-all on turnaround because most changes pass (deep beats wide). ^f11
  > With 500 changes per hour, P50, P95, P99 turnaround times grow 80x, 129x and 132x respectively compared to the turnaround times of the Oracle.
  > Thus, speculating deep instead of going wide helps.
- [devflow/queue] The model predicts with 97% accuracy; features include change size,
  affected targets, developer and pre-submit results. ^f12
  > Our current logistic regression model has an accuracy of 97%
- [devflow/queue] Before SubmitQueue the iOS mainline was green only 52% of a week;
  since launch it has stayed green. ^f13
  > only 52% of the time affecting both development and rollouts.
  > Since its launch, our mainlines have remained green at all times.
- [devflow/queue] Open: batching independent changes expected to pass would use
  hardware better but mispredictions raise turnaround; balance unexplored. ^f14
  > While this approach can lead to better hardware utilization and lower cost, false prediction can result in higher turnaround time.

## Read

- Abstract, sections 1-2, 8.2, 8.5 (green rate), 10.

## Not read

- Sections 4-6 in detail (value of a build, conflict analyzer maths, build controller);
  8.3 throughput figures.
