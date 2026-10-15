---
title: 'Linux block layer source: mq-deadline, kyber, blk-iocost, Kconfig.iosched'
url: https://github.com/torvalds/linux/tree/0fcb05b72344f40806cbe810de8872f1698bf053/block
kind: project
commit: 0fcb05b72344f40806cbe810de8872f1698bf053
for: [box-io-priority]
looked: 2026-10-15
depth: code (mq-deadline.c dispatch and prio, kyber-iosched.c targets, blk-iocost.c header and autop)
relevance: high
grade: A/strong
description: Mainline kernel source for the mq-deadline and kyber schedulers and the iocost cgroup controller, read for how each handles IO priority and when iocost throttles.
---
# Linux block layer source: mq-deadline, kyber, blk-iocost, Kconfig.iosched

Why: the deadline docs page says nothing about priorities and the cgroup docs only
summarise iocost; the code settles what mq-deadline does with ionice, whether kyber does
anything with it, and when iocost would actually throttle on our volume.

## Assessment

- Evidence: A. Mainline Linux (master at 0fcb05b, Oct 2026); mq-deadline is the default
  for single-queue devices on most distributions; iocost written and run at Facebook.
  Our box runs 6.17, so details may differ slightly; the prio and iocost logic shown has
  been stable since 5.x/6.x.
- Reasoning: strong. blk-iocost.c's header is a design document explaining the model,
  its control signals and costs.
- Interests: none.
- Weigh: code is what the kernel does; the iocost coefficients are defaults to be replaced
  for a real device.

## Findings

- [ops/io] mq-deadline maps ionice classes to three priority queues (RT, BE, IDLE);
  unset is treated as best-effort. `block/mq-deadline.c` ^f1
  > [IOPRIO_CLASS_NONE]	= DD_BE_PRIO,
  > [IOPRIO_CLASS_IDLE]	= DD_IDLE_PRIO,
- [ops/io] mq-deadline dispatches strictly by priority: a lower class gets nothing while a
  higher class has requests queued in the scheduler. `block/mq-deadline.c` dd_dispatch_request ^f2
  > Next, dispatch requests in priority order. Ignore lower priority
  > requests if any higher priority requests are pending.
- [ops/io] The only exception is ageing: lower-priority requests queued longer than
  prio_aging_expire (default 10 s, sysfs-tunable) are served anyway, so idle-class IO can
  wait up to ~10 s under constant higher-class load. `block/mq-deadline.c` ^f3
  > Time after which to dispatch lower priority requests even if higher
  > priority requests are pending.
  > static const int prio_aging_expire = 10 * HZ;
- [ops/io] (inferred) mq-deadline's priority only acts on requests waiting in the
  scheduler at the same moment; with average queue depth ~1.3 most requests find nothing
  else queued and dispatch at once, so ionice under mq-deadline reorders little unless
  the device queue is full. ^f4
- [ops/io] Kyber ignores IO priority entirely (no ioprio reference in the file); it
  throttles per-class queue depth to hit latency targets of 2 ms for reads and 10 ms for
  sync writes. `block/kyber-iosched.c` ^f5
  > [KYBER_READ] = 2ULL * NSEC_PER_MSEC,
  > [KYBER_WRITE] = 10ULL * NSEC_PER_MSEC,
- [ops/io] Kconfig describes kyber as for fast multiqueue devices and BFQ as the
  weight-based one. `block/Kconfig.iosched` ^f6
  > The Kyber I/O scheduler is a low-overhead scheduler suitable for
  > multiqueue and other fast devices.
- [ops/io] iocost is a scheduler-independent cgroup controller that charges each IO an
  estimated device-time cost from a linear model (sequential/random base cost plus a size
  term) and splits device time by cgroup weight. `block/blk-iocost.c` header ^f7
  > Each IO is classified as sequential or random and given a base cost accordingly.
  > A given cgroup's vtime runs slower in inverse proportion to its hweight.
- [ops/io] iocost's default "device busy" signal only fires when both hardware and
  software queues are full; finer control needs io.cost.qos latency targets, which are off
  by default and cost bandwidth. `block/blk-iocost.c` header ^f8
  > This saturation signal is fairly conservative as it only triggers when both hardware and software queues are filled up, and is used as the default busy signal.
  > There is an inherent trade-off - the tighter the latency QoS, the higher the bandwidth lossage.  Latency QoS is disabled by default
- [ops/io] iocost is work-conserving: a cgroup that uses less than its share donates the
  surplus, so weights only bite under contention. `block/blk-iocost.c` header ^f9
  > To conserve the total amount of work done, we keep track of how much
  > each active cgroup is actually using and yield part of its weight if
  > there are other cgroups which can make use of it.
- [ops/io] iocost picks its default model from the rotational flag: a device reporting
  rotational gets the HDD parameters (about 370 random read IOPS, 250 ms latency
  targets). Our volume reports rotational=1, so a default iocost would model it as a disk.
  `block/blk-iocost.c` ioc_autop_idx, autop ^f10
  > if (blk_queue_rot(disk->queue))
  > return AUTOP_HDD;
  > [I_LCOEF_RRANDIOPS]	=           370,
- [ops/io] (inferred) Enabling iocost on our volume therefore needs an explicit
  io.cost.model (e.g. measured with tools/cgroup/iocost_coef_gen.py, or the volume's
  published IOPS) and probably io.cost.qos latency targets, since at queue depth ~1.3 the
  default busy signal would never fire. ^f11

## Read

- `block/mq-deadline.c`: prio map, aged dispatch, dd_dispatch_request.
- `block/kyber-iosched.c`: constants only.
- `block/blk-iocost.c`: header comment, autop table, ioc_autop_idx.
- `block/Kconfig.iosched`: whole.

## Not read

- `block/blk-iolatency.c` (io.latency), `block/blk-throttle.c` (io.max): covered at doc
  level in [[kernel-cgroup-v2-io]].
- `block/bfq-*.c`: docs used instead ([[kernel-bfq-iosched]]).
