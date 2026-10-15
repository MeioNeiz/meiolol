---
title: systemd.resource-control(5) man page
url: https://man7.org/linux/man-pages/man5/systemd.resource-control.5.html
kind: docs
commit: 
for: [box-io-priority]
looked: 2026-10-15
depth: docs (controller enabling, Memory*, IO*, Delegate=)
relevance: high
grade: A/fair
description: systemd's reference for unit resource settings (IOWeight=, IOReadBandwidthMax=, IODeviceLatencyTargetSec=, MemoryLow=, MemoryHigh=, Delegate=), man7 render of systemd 262~devel.
---
# systemd.resource-control(5) man page

Why: which systemd unit settings map to which cgroup files, and whether a `systemd --user`
manager can apply them.

## Assessment

- Evidence: A. Upstream man page (262~devel render on man7; the box's Ubuntu systemd is
  older, but these settings date from 230/240).
- Reasoning: fair. Reference text; states caveats (non-work-conserving limits, ancestor
  allocations).
- Interests: none.
- Weigh: trust the mappings; that io works for user units depends on delegation, see
  [[systemd-user-delegation]].

## Findings

- [ops/io] IOWeight= writes io.weight (1..10000, default 100), splitting bandwidth among
  units in the same slice. IOWeight= ^f1
  > This controls the
  > "io.weight" control group attribute, which defaults to 100.
- [ops/io] IODeviceWeight= expects the device to have an IO scheduler, i.e. the whole
  disk, not a partition. IODeviceWeight= ^f2
  > The specified device node should reference a block device that
  > has an I/O scheduler associated, i.e. should not refer to
  > partition or loopback block devices
- [ops/io] IOReadBandwidthMax= and IOReadIOPSMax= write io.max and are not
  work-conserving: capped units cannot use idle capacity. IOReadBandwidthMax= ^f3
  > This limit is not
  > work-conserving and the executed processes are not allowed to
  > use more even if the device has idle capacity.
- [ops/io] IODeviceLatencyTargetSec= writes io.latency (since systemd 240). IODeviceLatencyTargetSec= ^f4
  > This controls the "io.latency" control group attribute.
- [ops/io] MemoryLow= protection generally needs a matching allocation on every ancestor
  (except the root slice); otherwise the protection is capped by the parent. MemoryLow= ^f5
  > For a protection to be effective, it is generally required to set a corresponding allocation on all ancestors, which is then distributed between children (with the exception of the root slice).
- [ops/io] systemd enables a controller only where a unit (or a sibling) configures it,
  and a user manager in user@.service repeats this logic for user units, but only for
  controllers delegated to it. Controller enabling ^f6
  > if the delegatee is
  > **systemd** (in the user@.service unit), it will repeat the same logic
  > as the system instance and enable controllers for user units which
  > have resource limits configured
- [ops/io] (inferred) For the box's user services: MemoryLow= on a user unit is capped by
  user@UID.service and user-UID.slice unless those get MemoryLow= too (system drop-ins). ^f7

## Read

- Description, Example 1, Memory*, IO* settings, Delegate=.

## Not read

- CPU, network, BPF, OOM sections.
