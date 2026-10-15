---
title: Deadline IO scheduler tunables, Linux kernel docs
url: https://docs.kernel.org/block/deadline-iosched.html
kind: docs
commit: 
for: [box-io-priority]
looked: 2026-10-15
depth: docs (whole)
relevance: low
grade: A/fair
description: Kernel docs for the deadline scheduler's tunables (read_expire, write_expire, fifo_batch, writes_starved, front_merges); written in 2002 and not updated for priorities.
---
# Deadline IO scheduler tunables, Linux kernel docs

Why: what mq-deadline's tunables are, especially prio_aging_expire.

## Assessment

- Evidence: A. In-tree kernel docs, but dated (Axboe, Nov 2002).
- Reasoning: fair.
- Interests: none.
- Weigh: incomplete for current mq-deadline; priority handling is only in the code
  ([[linux-block-src]]).

## Findings

- [ops/io] Deadline prefers reads over writes when dispatching, bounded by writes_starved.
  writes_starved ^f1
  > we always give a preference to reads. However, we don’t want to starve writes indefinitely either.
- [ops/io] fifo_batch trades per-request latency against throughput; 1 is first come,
  first served. fifo_batch ^f2
  > When low latency is the primary concern, smaller is better (where a value of 1 yields first-come first-served behaviour).
- [ops/io] Checked, not there: no mention of IO priority classes or prio_aging_expire;
  the page predates mq-deadline's priority support. ^f3

## Read

- Whole page.

## Not read

- Nothing left.
