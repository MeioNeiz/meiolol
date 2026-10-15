---
title: Control Group v2, Linux kernel admin guide (io and memory controllers)
url: https://docs.kernel.org/admin-guide/cgroup-v2.html
kind: docs
commit: 
for: [box-io-priority]
looked: 2026-10-15
depth: docs (IO controller, writeback, io.latency, io.prio.class, memory.low/high, delegation model)
relevance: high
grade: A/strong
description: The kernel's cgroup v2 reference; read for the io controller files (io.weight, io.cost.*, io.max, io.latency, io.prio.class), writeback attribution and memory protection.
---
# Control Group v2, Linux kernel admin guide (io and memory controllers)

Why: which cgroup io controls work on the box's `none` scheduler, what each costs, and
whether memory controls are the better lever for a page-cache-bound workload.

## Assessment

- Evidence: A. Canonical in-tree reference, maintained with the code (Tejun Heo et al.).
- Reasoning: strong. Explains trade-offs (QoS vs bandwidth, writeback attribution limits).
- Interests: none.
- Weigh: trust; device-specific numbers (latency targets) we must measure.

## Findings

- [ops/io] Weight-based io control comes from iocost (any scheduler) or from BFQ's own
  cgroup support; io.max limits work on all devices; io.latency and io.prio.class are
  separate policies. IO ^f1
  > Absolute BPS and IOPS limits are enforced by blk-throttle and apply to all devices, while weight based proportional distribution is provided by the iocost cost model controller (CONFIG\_BLK\_CGROUP\_IOCOST) and, when the BFQ I/O scheduler is in use for a device, by BFQ’s own cgroup support.
- [ops/io] iocost is off by default and is enabled per device on the root cgroup's
  io.cost.qos; without latency percentiles it uses the device saturation state. io.cost.qos ^f2
  > The controller is disabled by default and can be enabled by setting “enable” to 1.
  > “rpct” and “wpct” parameters default to zero and the controller uses internal device saturation state to adjust the overall IO rate between “min” and “max”.
- [ops/io] Tighter iocost latency QoS costs aggregate bandwidth, and badly chosen min/max
  can lose device capacity. io.cost.qos ^f3
  > The lower the saturation point, the better the latency QoS at the cost of aggregate bandwidth.
  > setting “min” and “max” blindly can lead to a significant loss of device capacity or control quality.
- [ops/io] io.weight is 1..10000, default 100, relative IO time among siblings; root
  cgroup processes count as a sibling of weight 200. io.weight, root behaviour ^f4
  > The weights are in the range \[1, 10000\] and specifies the relative amount IO time the cgroup can use in relation to its siblings.
  > as if it was a normal child cgroup of the root cgroup with a weight value of 200.
- [ops/io] io.max is a hard per-device BPS/IOPS cap that delays IO even when the device is
  idle (not work-conserving), with short bursts allowed. io.max ^f5
  > BPS and IOPS are measured in each IO direction and IOs are delayed if limit is reached. Temporary bursts are allowed.
- [ops/io] io.latency protects a group with a latency target by throttling sibling groups
  with looser targets, only while the target is missed; it judges misses by average
  latency on devices reporting rotational. IO Latency ^f6
  > if the group misses its target the controller will throttle any peers that have a lower latency target than the protected workload.
  > on rotational devices the average latency over the window must exceed the target
  > io.latency is work conserving; so as long as everybody is meeting their latency target the controller doesn’t do anything.
- [ops/io] io.latency throttling clamps the peers' queue depth down to 1 and adds delay for
  IO it cannot throttle (swap, metadata). How IO Latency Throttling Works ^f7
  > We will clamp down relatively quickly, starting at no limit and going all the way down to 1 IO at a time.
- [ops/io] io.prio.class sets an ionice class for every request from a cgroup (e.g.
  `idle`), but it still needs a scheduler that honours priorities. IO Priority ^f8
  > Change the I/O priority class of all requests into IDLE, the lowest I/O priority class.
- [ops/io] Writeback of dirty pages is attributed per inode, and ext4/xfs/btrfs support it;
  several cgroups writing one file (as SQLite WAL and DB files would be) are attributed
  poorly. Writeback ^f9
  > use cases where multiple cgroups write to a single inode simultaneously are not supported well.
- [ops/io] memory.low protects a cgroup's memory, page cache included, from reclaim while
  unprotected cgroups still have reclaimable memory. memory.low ^f10
  > If the memory usage of a cgroup is within its effective low boundary, the cgroup’s memory won’t be reclaimed unless there is no reclaimable memory available in unprotected cgroups.
- [ops/io] memory.high throttles and reclaims a cgroup over its limit without invoking
  the OOM killer, which suits capping a batch scan's page-cache footprint. memory.high ^f11
  > If a cgroup’s usage goes over the high boundary, the processes of the cgroup are throttled and put under heavy reclaim pressure.
  > Going over the high limit never invokes the OOM killer
- [ops/io] A delegatee cannot write its own cgroup's resource control files; those are
  the parent's to set, and nothing in a delegated subtree escapes the parent's limits. Delegation ^f12
  > Because the resource control interface files in a given directory control the distribution of the parent’s resources, the delegatee shouldn’t be allowed to write to them.
  > nothing can escape the resource restrictions imposed by the parent.
- [ops/io] (inferred) For us: iocost and io.latency are the only weight/protection tools
  that do not need BFQ; io.max is the bluntest and safest to undo; memory.low on the
  crawler and renderer plus memory.high on batch addresses the likely real cause (batch
  scans evicting hot pages) rather than queue order. ^f13

## Read

- IO controller section (interface files, writeback, io.latency, io.prio.class, root
  behaviour), memory.min/low/high, delegation model.

## Not read

- Rest of the memory controller, PSI file details (accounting/psi.rst), cgroup
  namespaces.
