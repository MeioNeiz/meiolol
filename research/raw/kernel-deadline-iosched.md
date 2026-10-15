# Deadline IO scheduler tunables — The Linux Kernel documentation

<https://docs.kernel.org/block/deadline-iosched.html>

# [The Linux Kernel](https://docs.kernel.org/index.html)

7.3.0-rc7

### Quick search

 

### Contents

Working with the development community

-   [Development process](https://docs.kernel.org/process/development-process.html)
-   [Submitting patches](https://docs.kernel.org/process/submitting-patches.html)
-   [Code of conduct](https://docs.kernel.org/process/code-of-conduct.html)
-   [Maintainer handbook](https://docs.kernel.org/maintainer/index.html)
-   [All development-process docs](https://docs.kernel.org/process/index.html)

Internal API manuals

-   [Core API](https://docs.kernel.org/core-api/index.html)
-   [Driver APIs](https://docs.kernel.org/driver-api/index.html)
-   [Subsystems](https://docs.kernel.org/subsystem-apis.html)
    -   [Core subsystems](https://docs.kernel.org/subsystem-apis.html#core-subsystems)
    -   [Human interfaces](https://docs.kernel.org/subsystem-apis.html#human-interfaces)
    -   [Networking interfaces](https://docs.kernel.org/subsystem-apis.html#networking-interfaces)
    -   [Storage interfaces](https://docs.kernel.org/subsystem-apis.html#storage-interfaces)
        -   [Filesystems in the Linux kernel](https://docs.kernel.org/filesystems/index.html)
        -   [Block](https://docs.kernel.org/block/index.html)
        -   [CD-ROM](https://docs.kernel.org/cdrom/index.html)
        -   [SCSI Subsystem](https://docs.kernel.org/scsi/index.html)
        -   [TCM Virtual Device](https://docs.kernel.org/target/index.html)
        -   [NVMe Subsystem](https://docs.kernel.org/nvme/index.html)
    -   [Other subsystems](https://docs.kernel.org/subsystem-apis.html#other-subsystems)
-   [Locking](https://docs.kernel.org/locking/index.html)

Development tools and processes

-   [Licensing rules](https://docs.kernel.org/process/license-rules.html)
-   [Writing documentation](https://docs.kernel.org/doc-guide/index.html)
-   [Development tools](https://docs.kernel.org/dev-tools/index.html)
-   [Testing guide](https://docs.kernel.org/dev-tools/testing-overview.html)
-   [Hacking guide](https://docs.kernel.org/kernel-hacking/index.html)
-   [Tracing](https://docs.kernel.org/trace/index.html)
-   [Fault injection](https://docs.kernel.org/fault-injection/index.html)
-   [Livepatching](https://docs.kernel.org/livepatch/index.html)
-   [Rust](https://docs.kernel.org/rust/index.html)

User-oriented documentation

-   [Administration](https://docs.kernel.org/admin-guide/index.html)
-   [Build system](https://docs.kernel.org/kbuild/index.html)
-   [Reporting issues](https://docs.kernel.org/admin-guide/reporting-issues.html)
-   [Userspace tools](https://docs.kernel.org/tools/index.html)
-   [Userspace API](https://docs.kernel.org/userspace-api/index.html)

Firmware-related documentation

-   [Firmware](https://docs.kernel.org/firmware-guide/index.html)
-   [Firmware and Devicetree](https://docs.kernel.org/devicetree/index.html)

Architecture-specific documentation

-   [CPU architectures](https://docs.kernel.org/arch/index.html)

Other documentation

-   [Unsorted documentation](https://docs.kernel.org/staging/index.html)

Translations

-   [Translations](https://docs.kernel.org/translations/index.html)

### This Page

-   [Show Source](https://docs.kernel.org/_sources/block/deadline-iosched.rst.txt)

# Deadline IO scheduler tunables[¶](https://docs.kernel.org/block/deadline-iosched.html#deadline-io-scheduler-tunables "Permalink to this heading")

This little file attempts to document how the deadline io scheduler works. In particular, it will clarify the meaning of the exposed tunables that may be of interest to power users.

## Selecting IO schedulers[¶](https://docs.kernel.org/block/deadline-iosched.html#selecting-io-schedulers "Permalink to this heading")

Refer to [Switching Scheduler](https://docs.kernel.org/block/switching-sched.html) for information on selecting an io scheduler on a per-device basis.

* * *

## read\_expire (in ms)[¶](https://docs.kernel.org/block/deadline-iosched.html#read-expire-in-ms "Permalink to this heading")

The goal of the deadline io scheduler is to attempt to guarantee a start service time for a request. As we focus mainly on read latencies, this is tunable. When a read request first enters the io scheduler, it is assigned a deadline that is the current time + the read\_expire value in units of milliseconds.

## write\_expire (in ms)[¶](https://docs.kernel.org/block/deadline-iosched.html#write-expire-in-ms "Permalink to this heading")

Similar to read\_expire mentioned above, but for writes.

## fifo\_batch (number of requests)[¶](https://docs.kernel.org/block/deadline-iosched.html#fifo-batch-number-of-requests "Permalink to this heading")

Requests are grouped into `batches` of a particular data direction (read or write) which are serviced in increasing sector order. To limit extra seeking, deadline expiries are only checked between batches. fifo\_batch controls the maximum number of requests per batch.

This parameter tunes the balance between per-request latency and aggregate throughput. When low latency is the primary concern, smaller is better (where a value of 1 yields first-come first-served behaviour). Increasing fifo\_batch generally improves throughput, at the cost of latency variation.

## writes\_starved (number of dispatches)[¶](https://docs.kernel.org/block/deadline-iosched.html#writes-starved-number-of-dispatches "Permalink to this heading")

When we have to move requests from the io scheduler queue to the block device dispatch queue, we always give a preference to reads. However, we don’t want to starve writes indefinitely either. So writes\_starved controls how many times we give preference to reads over writes. When that has been done writes\_starved number of times, we dispatch some writes based on the same criteria as reads.

## front\_merges (bool)[¶](https://docs.kernel.org/block/deadline-iosched.html#front-merges-bool "Permalink to this heading")

Sometimes it happens that a request enters the io scheduler that is contiguous with a request that is already on the queue. Either it fits in the back of that request, or it fits at the front. That is called either a back merge candidate or a front merge candidate. Due to the way files are typically laid out, back merges are much more common than front merges. For some work loads, you may even know that it is a waste of time to spend any time attempting to front merge requests. Setting front\_merges to 0 disables this functionality. Front merges may still occur due to the cached last\_merge hint, but since that comes at basically 0 cost we leave that on. We simply disable the rbtree front sector lookup when the io scheduler merge function is called.

Nov 11 2002, Jens Axboe <[jens.axboe@oracle.com](mailto:jens.axboe%40oracle.com)\>

©The kernel development community. | Powered by [Sphinx 5.3.0](https://www.sphinx-doc.org/) & [Alabaster 0.7.16](https://alabaster.readthedocs.io/) | [Page source](https://docs.kernel.org/_sources/block/deadline-iosched.rst.txt)
