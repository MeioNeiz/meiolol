---
title: Block io priorities, Linux kernel docs
url: https://docs.kernel.org/block/ioprio.html
kind: docs
commit: 
for: [box-io-priority]
looked: 2026-10-15
depth: docs (whole)
relevance: high
grade: A/fair
description: Kernel documentation of ioprio classes (RT, BE, IDLE), the ionice tool, and which schedulers honour them.
---
# Block io priorities, Linux kernel docs

Why: does `ionice -c 3` do anything on the box's `none` scheduler?

## Assessment

- Evidence: A. In-tree kernel docs (7.3-rc7 render).
- Reasoning: fair. Short and definitional.
- Interests: none.
- Weigh: trust; the code in [[linux-block-src]] confirms the mq-deadline side.

## Findings

- [ops/io] IO priority is implemented by the scheduler, and only bfq and mq-deadline
  implement it; so under `none` (and kyber) ionice classes have no effect on disk
  scheduling. Intro ^f1
  > Support for io priorities is io scheduler dependent and currently supported by bfq and mq-deadline.
- [ops/io] The idle class only gets disk time when nobody else wants it. Scheduling classes ^f2
  > IOPRIO\_CLASS\_IDLE: This is the idle scheduling class, processes running at this level only get io time when no one else needs the disk.
- [ops/io] Without an explicit ionice, the best-effort level follows the CPU nice value,
  so `nice -n 10` alone already means BE level 6 where a scheduler honours it. Scheduling classes ^f3
  > io\_nice = (cpu\_nice + 20) / 5
- [ops/io] RT class can starve everything else. Scheduling classes ^f4
  > one io RT process can starve the entire system.
- [ops/io] Priority is inherited on fork, so setting it on a service's main process
  covers its children. Tools ^f5
  > IO priority settings are inherited on fork
- [ops/io] Checked, not there: nothing on how priorities interact with page cache
  writeback (dirty pages written later by kernel threads lose the writer's priority) or
  with cgroup controllers. ^f6

## Read

- Whole page.

## Not read

- Nothing left.
