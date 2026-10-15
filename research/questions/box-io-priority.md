---
status: answered
priority: now
area: ops
tags: [ops]
description: How should a small cloud VM prioritise IO between a latency-sensitive writer, a web renderer and heavy batch readers: scheduler, ionice, cgroup io controls, or memory?
---
# How should a small cloud VM prioritise IO between a latency-sensitive writer, a web renderer and heavy batch readers: scheduler, ionice, cgroup io controls, or memory?

Feeds: how the box runs the crawler, renderer and the web loop's batch jobs (docs/hosting.md,
deploy/web-loop.sh); Jacob 15 Oct: balance and prioritise the box, look into the
scheduler.

## Answer

Measured 15 Oct (sysstat history and live samples): CPU ~10% busy, memory pressure 0,
disk 7-15 MB/s of 4-8 KB reads at ~0.7 ms with ~1.3 in flight, about 21% of the
volume's IOPS cap and 14% of its throughput (C2). Only after deploys (14 Oct 21-01 UTC,
15 Oct 08-09) did several loads together reach 55-70 MB/s with 7-13 queued, the cap.
Per service: the renderer's IO pressure is 0, the crawler's 4-5%, the web loop's batch
job ~51%, so the batch jobs stall on their own serial reads; the crawler re-read ~207
GB of evicted pages in 14 h (workingset_refault_file 51.7M).

So today a scheduler buys little: ionice does nothing under `none` (C1), mq-deadline
would honour it at no cost (C4) but rarely has two requests to order (C3), BFQ enforces
priorities at short queues by idling, which costs throughput (C5), and cgroup io
settings need io delegated to the user manager and iocost tuning (C6). The levers are:
not running heavy loads together, fewer page-cache misses (C8), and reads in flight in
parallel, since the volume has 4-5x headroom. Once batch jobs read in parallel the queue
grows, and mq-deadline plus ionice -c 3 starts to matter: switch at runtime first
(`echo mq-deadline > /sys/block/sda/queue/scheduler`, `echo none` reverts).

## Claims

- C1: Under `none` (and kyber), ionice classes have no effect on disk IO; only bfq and mq-deadline use them. for: [[kernel-ioprio#^f1]], [[linux-block-src#^f1]], [[linux-block-src#^f5]]
- C2: The 150 GB Balanced volume is capped at 9,000 IOPS and 72 MB/s; read rate below that is per-read latency times reads in flight. for: [[oci-block-volume-performance#^f2]], [[oci-block-volume-performance#^f3]], [[oci-block-volume-performance#^f4]]
- C3 (inferred): mq-deadline serves priority classes strictly but only among queued requests, so at ~1.3 in flight its priorities rarely apply. from: C2; for: [[linux-block-src#^f2]], [[linux-block-src#^f3]]
- C4: Switching between `none` and mq-deadline costs nothing measurable at our IOPS. for: [[redhat-virt-io-scheduler#^f2]], [[redhat-virt-io-scheduler#^f3]], [[kernel-bfq-iosched#^f4]]
- C5: BFQ enforces priorities and weights even at short queues by idling the device for the served queue, which costs throughput on random workloads and internally queueing devices. for: [[kernel-bfq-iosched#^f1]], [[kernel-bfq-iosched#^f5]], [[kernel-bfq-iosched#^f6]] against: [[iocost-asplos-2022#^f3]]
- C6: cgroup io settings in systemd --user units do nothing until io is delegated to user@.service, and iocost needs a hand-set model and QoS; the volume reports rotational=1, which picks iocost's hard-disk model. for: [[systemd-user-delegation#^f1]], [[linux-block-src#^f10]], [[linux-block-src#^f8]], [[iocost-asplos-2022#^f5]]
- C7: io.max caps apply even when the disk is idle. for: [[kernel-cgroup-v2-io#^f5]], [[systemd-resource-control#^f3]]
- C8: memory.low protects a cgroup's page cache from reclaim and memory.high caps one without the OOM killer; memory is delegated to user services. for: [[kernel-cgroup-v2-io#^f10]], [[kernel-cgroup-v2-io#^f11]], [[systemd-resource-control#^f5]], [[systemd-user-delegation#^f2]]

## Disagreements

BFQ (C5): kernel docs claim low latency for interactive work; Meta's iocost paper found
its idling costly on fast devices. Ours is NVMe-backed but reports rotational=1. A timed
trial would settle it, after the cheaper levers.

## Open

- Volume latency under parallel reads (a short fio run, or the first parallel batch job).
- Whether MemoryLow= on the crawler and renderer cuts the crawler's refaults.
