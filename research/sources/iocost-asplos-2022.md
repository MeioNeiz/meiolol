---
title: 'IOCost: Block IO Control for Containers in Datacenters (Heo et al., ASPLOS 2022)'
url: https://par.nsf.gov/servlets/purl/10332478
kind: paper
commit: 
for: [box-io-priority]
looked: 2026-10-15
depth: skimmed (sections 1, 2.2, 3.4, 4 overhead, 5 experience)
relevance: medium
grade: A/strong
description: Meta's paper on iocost, comparing Linux IO control mechanisms (none, mq-deadline, kyber, blk-throttle, BFQ, io.latency, iocost) on overhead, work conservation and memory awareness, from fleet deployment.
---
# IOCost: Block IO Control for Containers in Datacenters (Heo et al., ASPLOS 2022)

Why: a first-hand comparison of every Linux IO control option by the people who wrote
io.latency and iocost, with production experience.

## Assessment

- Evidence: A. Peer-reviewed (ASPLOS 2022), authors are the cgroup and block maintainers
  (Heo, Bacik, Mason), two years on Meta's fleet.
- Reasoning: strong. Compares alternatives with experiments and states limitations of
  their own earlier controller (io.latency).
- Interests: one side of a comparison (authors of iocost and io.latency); BFQ results are
  from their tuning attempts on fast datacenter SSDs at very high IOPS.
- Weigh: overhead verdicts are at 750K IOPS, irrelevant at our ~1,900; the qualitative
  points (memory interaction, configuration difficulty) carry over.

## Findings

- [ops/io] none, mq-deadline and kyber give no per-container guarantees, only system-wide
  properties such as keeping async writes from swamping sync reads. Section 2.2 ^f1
  > There are three main options for IO
  > scheduling without cgroup control: no scheduler, mq-deadline, and
  > kyber. They do not guarantee IO resources to containers
- [ops/io] blk-throttle (io.max) limits are not work-conserving and hard to configure.
  Section 2.2 ^f2
  > These limits, however, are not workconserving and difficult to configure for heterogeneous devices and
  > diverse applications in datacenters.
- [ops/io] BFQ ignores memory-management IO (reclaim, swap) and had high per-request
  overhead and wide latency swings in their tests. Section 2.2 ^f3
  > BFQ [41] provides a work-conserving interface for proportional
  > control of IO, but ignores interactions with memory management,
  > which could lead to isolation failures.
- [ops/io] io.latency suits strict prioritisation (protect high from low) but its targets
  were hard to set: a target tuned for one scenario often failed in others. Sections 2.2, 5 ^f4
  > the latency-based interface is suitable
  > only for strict prioritization
  > A configuration tuned for one
  > scenario was often ineffective for others.
- [ops/io] iocost needs a per-device model (from fio) and QoS parameters tuned with a
  benchmark; Meta trades throughput for latency under contention. Section 3.4 ^f5
  > The QoS parameters determine the overall throttling of the device,
  > which is an important trade-off of device utilization for consistent latency.
- [ops/io] Page faults, dirty writeback and swap reach the block layer outside the
  application's own reads, so IO control that ignores memory management can invert
  priorities. Section 1 ^f6
  > interactions with memory management operations such as page
  > reclaim and swap. IO control must be aware of these interactions
  > to avoid priority inversions and other isolation failures.
- [ops/io] (inferred) For a 2-OCPU box with one volume and three workloads, iocost's
  per-device modelling and QoS tuning is Meta-scale effort; io.latency or plain ionice
  with mq-deadline are the proportionate tools, and memory protection matters as much as
  queue order. ^f7

## Read

- Abstract, introduction, section 2.2 and Table 1, QoS tuning (3.4), overhead experiment,
  experience section.

## Not read

- Section 3 model details and the remaining experiments (work conservation, memory
  leak isolation figures).
