---
title: 'Accelerating Continuous Integration with Parallel Batch Testing (Fallahzadeh, Bavand, Rigby, FSE 2023)'
url: https://arxiv.org/pdf/2308.13129
kind: paper
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: skimmed (abstract, sections 1-4, threats, related work)
relevance: high
grade: B/fair
description: Simulated batch testing on Ericsson and Chrome with varying machines; batch of 4, BatchAll (batch the whole queue), culprit finding costs and the 40% failure threshold
---
# Accelerating Continuous Integration with Parallel Batch Testing (Fallahzadeh, Bavand, Rigby, FSE 2023)

Why: batch size against failure rate and machine count, with culprit-finding cost.
Stands in for Najafi et al. FSE 2019 (paywalled, not archived) and Beheshtian et al.
TSE 2021, both summarised in its related work.

## Assessment

- Evidence: B. Peer-reviewed (FSE 2023); historical simulation on 11,000 Ericsson
  changes and 276 million Chrome test results; no live deployment.
- Reasoning: fair. States threats (failure rate, ignored compile time, no merge
  conflicts assumed).
- Interests: same group as the prior batching papers it builds on.
- Weigh: it batches test runs, not merges to main, and ignores compile time and
  interaction failures; the shape (batch the queue when machines are scarce, stop
  bisecting at 4) transfers, the percentages do not.

## Findings

- [devflow/queue] Batch testing groups builds and bisects on failure; if 4 builds
  sharing tests pass together, 3 executions are saved. ^f1
  > For example, if we are testing four builds in a batch that request the same tests, and the batch passes, we will save three build test executions.
- [devflow/queue] Batching and bisection cut overall feedback time when fewer than 40%
  of builds fail. ^f2
  > Bisection can slow individual builds, but when fewer than 40% of builds fail, batching and bisection effectively reduce overall feedback time [9].
- [devflow/queue] Prior results: constant batch sizes saved up to 42% at Ericsson
  (Najafi et al.); BatchStop4 cut build test executions by 50% on average (Beheshtian
  et al.); dynamic batch size from historical failure rate about 47% (Bavand et
  al.). ^f3
  > found that constant batch sizes can reduce the resource usage, i.e. execution time, necessary to run all the required tests by up to 42%.
  > proposed BatchStop4, which can reduce build test executions on average by 50%.
- [devflow/queue] Culprit-finding cost: git bisect needs about log(n) runs but finds
  only the first culprit; Najafi's divide and conquer finds all, 2log(n) up to 2n + 1
  runs. ^f4
  > The total executions range from 2𝑙𝑜𝑔(𝑛) to 2𝑛 + 1 when all batch changes are culprits.
- [devflow/queue] For batches of 4 or fewer, bisection costs more runs than testing
  each change alone; BatchStop4 tests them individually and beats bisection. ^f5
  > that for batches of 4 or fewer, bisection increases executions. They propose BatchStop4, testing each change individually in batches of 4 or fewer.
- [devflow/queue] After a failure only the failing tests need re-running in the
  culprit search, not the whole suite. ^f6
  > This is inefficient because we know which tests failed on a batch, and we do not need to bisect and re-run the passing tests.
- [devflow/queue] Batch of 4 saves 37% of executions at Ericsson and 75% at Chrome
  (batch of 2: 23% and 50%); Chrome's build failure rate is about 8.5%. ^f7
  > Similarly, Batch4 achieves a ExecutionReduction of 37% for Ericsson and 75% for Chrome.
  > The rate of failures for the builds in this project is about 8.5%.
- [devflow/queue] Larger batches help more the scarcer the machines; with spare
  machines a large constant batch hurts feedback because changes wait for the batch to
  fill. ^f8
  > Moreover, the more resourceconstrained the environment is, the more effective larger batch sizes would be. However, in a highly resource-available situation, using a larger constant batch size will deteriorate the feedback time.
- [devflow/queue] BatchAll (batch everything queued each time) adapts: large batches
  when machines are scarce, down to 1 when plentiful; keeps feedback time with up to
  91% fewer machines. ^f9
  > BatchAll maintains the actual average feedback time with up to 91% fewer machines and exhibits variable execution reduction of up to 99%.
- [devflow/queue] Queue delay compounds: with too few machines wait time exceeds
  processing time, and the effect of machines on feedback time is non-linear. ^f10
  > For instance, with just one machine, the queue grows substantially, causing wait times to surpass processing times.
- [devflow/queue] A higher failure rate raises culprit-finding cost and can make
  batching ineffective. ^f11
  > the higher the failure rate is, the higher the cost of culprit finding would become which in turn, can make the batching algorithms ineffective.

## Read

- Abstract, sections 1, 2, 3.2, 4.2-4.4 skimmed, threats, related work.

## Not read

- Najafi et al. FSE 2019 and Beheshtian et al. TSE 2021 themselves (the maths of
  optimal batch size vs failure rate).
