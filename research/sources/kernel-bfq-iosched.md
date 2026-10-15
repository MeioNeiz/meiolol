---
title: BFQ (Budget Fair Queueing), Linux kernel docs
url: https://docs.kernel.org/block/bfq-iosched.html
kind: docs
commit: 
for: [box-io-priority]
looked: 2026-10-15
depth: docs (intro, sections 1-4)
relevance: high
grade: A/fair
description: The kernel's own documentation of the BFQ scheduler: what it guarantees, how ioprio and weights map, idling, low_latency, cgroup weights, overhead.
---
# BFQ (Budget Fair Queueing), Linux kernel docs

Why: is BFQ the scheduler that makes `ionice -c 3` and per-service weights work on the box,
and what does it cost on a fast networked volume?

## Assessment

- Evidence: A. In-tree kernel documentation by the scheduler's authors; BFQ in mainline
  since 4.12 and the default on some desktop distributions.
- Reasoning: fair. Explains its mechanisms and the latency/throughput trade-off; benchmark
  claims (throughput vs CFQ/DEADLINE) are from the authors' own suite and mostly HDD and
  laptop SSDs, not virtualised network volumes.
- Interests: authors of BFQ describing BFQ.
- Weigh: trust the mechanism descriptions (ioprio classes, weights, idling); treat
  responsiveness and throughput claims as the authors' and verify on our device.

## Findings

- [ops/io] BFQ is the scheduler that turns ionice classes into strict priority: an Idle
  class queue is served only when no higher class has queued IO, with a thin anti-starvation
  allowance. Section 2 ^f1
  > ioprio classes are served in strict priority order, i.e., lower-priority queues are not served as long as there are higher-priority queues.
  > A very thin extra bandwidth is however guaranteed to the Idle class, to prevent it from starving.
- [ops/io] Within the best-effort class, the ionice level becomes a weight; low_latency
  (on by default) can override weights by weight-raising queues it judges interactive.
  Section 3 ^f2
  > weight = (IOPRIO\_BE\_NR - ioprio) \* 10
  > if low-latency is set, then BFQ automatically raises the weight of the queues associated with interactive and soft real-time applications
- [ops/io] cgroup v2 weights under BFQ are `io.bfq.weight` (1..1000, default 100), not the
  generic io.weight, and need BFQ_GROUP_IOSCHED. Section 4 ^f3
  > For cgroup v2, it is set by writing the value to io.bfq.weight.
- [ops/io] Overhead per request is about 2.7 times mq-deadline's (1.9 us vs 0.7 us on an
  old laptop CPU), with a ceiling in the hundreds of thousands of IOPS per CPU; far above
  our ~1,900 reads/s. Intro ^f4
  > per-request processing time of BFQ [...] is, e.g., 1.9 us
  > the lightest I/O scheduler available in blk-mq, mq-deadline, is 0.7 us
  > ARM CortexTM-A53 Octa-core: 80 KIOPS
- [ops/io] BFQ may idle the device waiting for the in-service sync queue's next request
  (slice_idle, non-zero by default); this helps rotational disks but can hurt throughput
  on devices with internal queueing and on random workloads. Section 2, slice_idle ^f5
  > Device idling typically boosts the throughput on rotational devices and on non-queueing flash-based devices, if processes do synchronous and sequential I/O.
  > There is an important flip side to idling: apart from the above cases where it is beneficial also for throughput, idling can severely impact throughput. One important case is random workload.
  > with flash-based fast storage, setting slice\_idle=0 might end up in better throughput and acceptable latencies.
- [ops/io] Idling is also what enforces differentiated weights; turning slice_idle off
  trades away the fairness guarantees. slice_idle ^f6
  > Idling is however necessary to have service guarantees enforced in case of differentiated weights or differentiated I/O-request lengths.
- [ops/io] The authors claim interactive tasks stay responsive under heavy background IO,
  where deadline and noop do not, "also on SSDs". Section 1-1 (claim) ^f7
  > As a comparison, with CFQ, NOOP or DEADLINE, and in the same conditions, applications experience high latencies, or even become unresponsive until the background workload terminates (also on SSDs).
- [ops/io] (inferred) Our volume reports rotational=1 although it is NVMe-backed network
  storage, so BFQ would likely idle as for a disk; with slice_idle at its default, the
  crawler's and renderer's random reads could lose throughput. Try `slice_idle=0` only if
  priority still holds without it. ^f8
- [ops/io] Checked, not there: nothing on virtualised or network block devices, or on
  behaviour when the device queue is near-empty (queue depth ~1). ^f9

## Read

- Intro, sections 1-4 (interface list skimmed).

## Not read

- Section 4-2 stats files (debug only); the papers cited as [1], [2].
