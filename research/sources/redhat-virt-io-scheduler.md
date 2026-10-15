---
title: What is the suggested I/O scheduler for RHEL with virtualization? (Red Hat solution 5427)
url: https://access.redhat.com/solutions/5427
kind: docs
commit: 
for: [box-io-priority]
looked: 2026-10-15
depth: docs (whole solution and footnotes)
relevance: medium
grade: B/fair
description: Red Hat's support article recommending IO schedulers for virtual guests by RHEL version, with a small none vs mq-deadline measurement on NVMe-backed virtual disks.
---
# What is the suggested I/O scheduler for RHEL with virtualization? (Red Hat solution 5427)

Why: first-hand vendor guidance on whether the scheduler matters on a virtual disk backed
by fast storage, at low queue depth.

## Assessment

- Evidence: B. Red Hat support's recommendation for a large installed base, with one
  measurement described in prose (no setup, no numbers table).
- Reasoning: fair. Explains why (hypervisor schedules too, code path length) and admits
  results depend on load.
- Interests: none beyond keeping RHEL defaults.
- Weigh: the measurement is throughput only; it says nothing about prioritising one
  process over another, which is our question.

## Findings

- [ops/io] Red Hat's advice for RHEL 8/9 virtual guests is to keep mq-deadline, and test
  any change against the real workload. RHEL 8,9 ^f1
  > Virtual disks: keep current io scheduler setting (`mq-deadline`)
  > There is no single one "best" I/O scheduler recommendation which applies to all situations or for any given generic environment.
- [ops/io] On NVMe-backed virtual disks at IO depth 1, none vs mq-deadline differed by
  about 2% at 32 KB or larger and under 1% at 512 KB; in real loads within noise. FN.1 ^f2
  > Testing with NVMe backed virtual disks between `none` and `mq-deadline` with simple single io depth test showed ~2% difference with block I/O sizes 32kb or larger, and less than 1% difference at 512kb io size.
- [ops/io] `none` only gains at very high IOPS with small IO, from mq-deadline's longer
  code path. FN.1 ^f3
  > switching to the `none` scheduler can provide a slight overall improvement in iops and therefore throughput. This is due to the slightly longer execution code path of `mq-deadline` vs `none` schedulers.
- [ops/io] Deadline helps database loads mixing synchronous reads with asynchronous
  writes by dispatching reads first; hypervisors usually schedule IO themselves. FN.2 ^f4
  > a database i/O load of synchronous reads and asynchronous writes can benefit from `deadline` by biasing dispatch of reads first
  > most hypervisors also perform their own I/O scheduling for the physical resouces behind the virtual disks.
- [ops/io] (inferred) At our ~1,900 IOPS, switching none to mq-deadline costs nothing
  measurable in throughput; the question is only whether its priority queues help. ^f5
- [ops/io] Checked, not there: nothing on BFQ in guests beyond lumping it with cfq for old
  RHEL, nothing on ionice or cgroups. ^f6

## Read

- Whole article and footnotes FN.1-FN.3.

## Not read

- Linked RHEL tuning guides and udev rule articles (how-to only).
