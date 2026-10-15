---
title: Block Volume Performance, Oracle Cloud docs
url: https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm
kind: docs
commit: 
for: [box-io-priority]
looked: 2026-10-15
depth: docs (performance levels table, formulas, VM shape table, limitations)
relevance: high
grade: B/fair
description: Oracle's published IOPS and throughput per GB for each Block Volume performance level, per-instance limits by shape, and SLA conditions.
---
# Block Volume Performance, Oracle Cloud docs

Why: is the box's 150 GB Balanced volume anywhere near its IOPS or throughput limit at
~1,900 reads/s and ~10 MB/s?

## Assessment

- Evidence: B. Vendor's own published service limits (and SLA basis); no independent
  measurement here.
- Reasoning: fair. Tables and formulas; little on latency.
- Interests: vendor.
- Weigh: trust the caps as ceilings; latency and small-VM paravirtualised behaviour need
  our own measurement (fio on the box).

## Findings

- [ops/io] Block Volume is NVMe-backed network storage. Intro ^f1
  > The Oracle Cloud Infrastructure Block Volume service uses NVMe-based storage infrastructure
- [ops/io] Balanced (10 VPUs, the default) gives 60 IOPS/GB up to 25,000 per volume and
  480 KB/s per GB up to 480 MB/s. Performance levels table ^f2
  > | Balanced | 10 | 60 | 25,000 | 417 | 480 | 480 |
- [ops/io] (inferred) Our 150 GB Balanced volume: 150 x 60 = 9,000 IOPS and
  150 x 480 KB/s = 72 MB/s. At ~1,900 reads/s and ~10 MB/s we use about 21% of the IOPS
  and 14% of the throughput: the volume is not saturated. ^f3
- [ops/io] A1 Flex VMs get 1 Gbps per OCPU, and per-instance block limits of 20,000 IOPS
  and 120 MB/s per Gbps; at 2 OCPU that is 40,000 IOPS and 240 MB/s, above the volume's
  own caps. VM shapes table ^f4
  > | VM.Standard.A1.Flex | 1 OCPU minimum, 80 OCPU maximum | 1 GB minimum, 1024 GB maximum | 1 Gbps per OCPU, maximum 40 Gbps | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps (up to 4,800 MB/s) |
- [ops/io] VM throughput is further limited by the instance's network bandwidth, which the
  volume shares with other traffic. Limitations ^f5
  > Throughput performance on virtual machine (VM) compute instances depends on the network bandwidth that's available to the instance, and further limited by that bandwidth for the volume.
- [ops/io] The IOPS SLA covers paravirtualised attachments for Balanced only on VMs of 8
  cores or more; our 2-OCPU paravirtualised attachment has no IOPS SLA. Limitations ^f6
  > paravirtualized volume attachments for 16 core or higher VMs for **Ultra High Performance**, and for 8 cores or higher VMs for **Balanced** and **Higher Performance**
- [ops/io] More performance is a setting: VPUs can be raised on a live volume
  (Higher Performance, 20 VPUs: 75 IOPS/GB, 50,000 max). Performance levels ^f7
  > You can change this when create the volume or you can update it at any point after the volume is created.
  > | Higher Performance | 20 | 75 | 50,000 | 667 | 600 | 680 |
- [ops/io] Checked, not there: no published per-IO latency for Balanced, nothing on the
  rotational flag the guest sees, and nothing on queue depth needed to reach the IOPS
  figures. ^f8
- [ops/io] (inferred) Little's law fits our numbers: 1.3 in flight / 0.67 ms per read is
  about 1,940 reads/s, the rate we see. Throughput is set by per-read latency times how
  many reads are in flight, not by the volume's IOPS cap; adding concurrency (or cache
  hits) is what raises it, and reordering a near-empty queue cannot. ^f9

## Read

- Performance levels, formulas, VM shape table (A1 row), limitations.

## Not read

- Ultra High Performance multipath requirements; metrics and testing page (fio recipes,
  may be worth reading before benchmarking).
