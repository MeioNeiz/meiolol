# What is the suggested I/O scheduler to improve disk performance when using Red Hat Enterprise Linux with virtualization? - Red Hat Customer Portal

<https://access.redhat.com/solutions/5427>

[Skip to navigation](https://access.redhat.com/solutions/5427#pfe-navigation) [Skip to main content](https://access.redhat.com/solutions/5427#cp-main)

### Utilities

-   [Subscriptions](https://access.redhat.com/management/)
-   [Downloads](https://access.redhat.com/downloads/)
-   [Red Hat Console](https://console.redhat.com/)
-   [Get Support](https://access.redhat.com/support/)

## Select Your Language

-   [English](https://access.redhat.com/solutions/5427#)
-   [Français](https://access.redhat.com/solutions/5427#)
-   [한국어](https://access.redhat.com/solutions/5427#)
-   [日本語](https://access.redhat.com/solutions/5427#)
-   [中文 (中国)](https://access.redhat.com/solutions/5427#)

## Quick links: redhat.com, Customer Portal, Red Hat's developer site, Red Hat's partner site.

-   [
    
    You are here
    
    ### Red Hat
    
    Learn about our open source products, services, and company.
    
    ](https://www.redhat.com/en)
-   [
    
    You are here
    
    ### Red Hat Customer Portal
    
    Get product support and knowledge from the open source experts.
    
    ](https://access.redhat.com)
-   [
    
    You are here
    
    ### Red Hat Developer
    
    Read developer tutorials and download Red Hat software for cloud application development.
    
    ](https://developers.redhat.com)
-   [
    
    You are here
    
    ### Red Hat Partner Connect
    
    Get training, subscriptions, certifications, and more for partners to build, sell, and support customer solutions.
    
    ](https://connect.redhat.com)

## Products & tools

-   [
    
    ### Red Hat Documentation
    
    ](https://docs.redhat.com)Find answers, get guidance, and learn how to use Red Hat products.
-   [
    
    ### Red Hat Ecosystem Catalog
    
    ](https://catalog.redhat.com)Find hardware, software, and cloud providers―and download container images―certified to perform with Red Hat technologies.

## Try, buy, & sell

-   [
    
    ### Red Hat Hybrid Cloud Console
    
    ](https://www.redhat.com/hybrid-cloud-console)Access technical how-tos, tutorials, and learning paths focused on Red Hat’s hybrid cloud managed services.
-   [
    
    ### Red Hat Store
    
    ](https://www.redhat.com/store)Buy select Red Hat products and services online.

## Events

-   [
    
    ### Red Hat Summit
    
    ](https://www.redhat.com/summit)Register for and learn about our annual open source IT industry event.

-   [Products & Services](https://access.redhat.com/products)
-   [Knowledgebase](https://access.redhat.com/kb)
-   What is the suggested I/O scheduler to improve disk performance when using Red Hat Enterprise Linux ...

# What is the suggested I/O scheduler to improve disk performance when using Red Hat Enterprise Linux with virtualization?

Solution Verified \- Updated August 7 2024 at 7:25 AM -

[English](https://access.redhat.com/solutions/5427)

### Red Hat Lightspeed can detect this issue

Proactively detect and remediate issues impacting your systems.

[View matching systems and remediation](http://console.redhat.com/insights/advisor/recommendations/vm_io_scheduler%7CVM_IO_SCHEDULER_V1)

## Environment

-   Red Hat Enterprise Linux (RHEL) 4, 5, 6, 7, 8, and 9
-   Virtualization, e.g. KVM, Xen, VMware or Microsoft Hyper-V
-   Virtualization guest or virtualization host
-   Virtual disk

## Issue

-   What is the recommended I/O scheduler for Red Hat Enterprise Linux as a virtualization host?

## Resolution

There is no single one "best" I/O scheduler recommendation which applies to all situations or for any given generic environment. Any changes made to the I/O scheduler should be done in conjunction with testing to determine which one provides the most advantages for the application suite's specific I/O workload that is present.

The following are the common starting recommendations for an I/O scheduler for a RHEL based virtual guest based upon kernel version and disk type.

-   RHEL 8,9 : `mq-deadline` is default I/O scheduler unless otherwise changed [\[FN.1\]](https://access.redhat.com/solutions/5427#FN.1)
    
    -   Virtual disks: keep current io scheduler setting (`mq-deadline`)
    -   Physical disks: keep current io scheduler setting (`mq-deadline`, or for NVMe `none`)
-   RHEL 7.5+ : `deadline` is default io scheduler unless otherwise changed
    
    -   Virtual disks: keep current io scheduler setting (`deadline`)
        -   [6.2. I/O Scheduling with Red Hat Enterprise Linux as a Virtualization Guest](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_tuning_and_optimization_guide/sect-virtualization_tuning_optimization_guide-io-scheduler-guest)
    -   Physical disks: keep current io scheduler setting (`deadline`)
-   RHEL 4,5,6,(7.0-7.4) : `cfq` is default I/O scheduler unless otherwise changed
    
    -   Virtual disks: change to `noop` scheduler [\[FN.2\]](https://access.redhat.com/solutions/5427#FN.2)
        -   [6.3. I/O Scheduling with Red Hat Enterprise Linux as a Virtualization Guest](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_tuning_and_optimization_guide/sect-virtualization_tuning_optimization_guide-io-scheduler-guest)
    -   Physical disks: keep current io scheduler setting

### Online configuring the I/O scheduler on Red Hat Enterprise Linux

-   See _["Can I change the I/O scheduler for a particular disk without the system rebooting?"](https://access.redhat.com/articles/75380)_
    
    -   Determine which schedulers are available:
        
        [Raw](https://access.redhat.com/solutions/5427#)
        
        ```
        # cat /sys/block/sda/queue/scheduler
        [mq-deadline] kyber bfq none
        ```
        
    -   Change the scheduler for a device and verify using one of the above:
        
        [Raw](https://access.redhat.com/solutions/5427#)
        
        ```
        # echo 'none' > /sys/block/sda/queue/scheduler
        # cat /sys/block/sda/queue/scheduler
        mq-deadline kyber bfq [none]
        ```
        
-   Additional documentation references:
    
    -   RHEL 9: [Chapter 11. Setting the disk scheduler](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/setting-the-disk-scheduler_monitoring-and-managing-system-status-and-performance#doc-wrapper)
    -   RHEL 8: [Chapter 12. Setting the disk scheduler](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/monitoring_and_managing_system_status_and_performance/setting-the-disk-scheduler_monitoring-and-managing-system-status-and-performance) in Monitoring and Managing System Status and Performance
        -   [Chapter 19. Setting the disk scheduler](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/managing_storage_devices/setting-the-disk-scheduler_managing-storage-devices) in Managing Storage Devices
    -   RHEL 7: [Section 6.2.1. Configuring the I/O Scheduler for Red Hat Enterprise Linux 7](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_tuning_and_optimization_guide/sect-virtualization_tuning_optimization_guide-io-scheduler-guest)
    -   RHEL 6: [Section 6.4. Configuring the I/O Scheduler](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_tuning_and_optimization_guide/sect-virtualization_tuning_optimization_guide-io-scheduler-configuring)

### Configuring the I/O scheduler on Red Hat Enterprise Linux 8 and 9

-   In RHEL8 and newer [new I/O schedulers](https://access.redhat.com/articles/4740651) are available. These are `mq-deadline`, `none`, `kyber`, and `bfq`. Note that the `noop` scheduler is called `none`.
    -   More info on the `noop`/`none` schedulers can be found in _["How to use the Noop or None IO Schedulers "](https://access.redhat.com/solutions/109223)_
    -   In RHEL8 and newer, the [default](https://access.redhat.com/solutions/3755961) scheduler is `mq-deadline`.
-   The I/O scheduler can be set via using [tuned](https://access.redhat.com/solutions/3724971) or [udev rules](https://access.redhat.com/solutions/3756041). The udev method of setting is often preferred due to its robust configuration options.

### Configuring the I/O sheduler via `tuned` and `udev`

-   Another way to change the default I/O scheduler is to use [tuned](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/getting-started-with-tuned_monitoring-and-managing-system-status-and-performance).
    -   More information on creating a custom tuned profile can be found in [Chapter 2. Customizing TuneD profiles](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/customizing-tuned-profiles_monitoring-and-managing-system-status-and-performance)
    -   _["How do I create my own tuned profile on RHEL7 ?"](https://access.redhat.com/solutions/731473)_
    -   The default scheduler in Red Hat Enterprise Linux 4, 5 and 6 is `cfq`. The available tuned profiles use the `deadline` elevator. See _["How do I create my own tuned profile on RHEL6?"](https://access.redhat.com/solutions/1305833)_ on creating a custom I/O scheduler via tuned.
-   See also _["How to set a permanent I/O scheduler on one or more specific devices using udev"](https://access.redhat.com/solutions/3756041)_

### Footnotes

-   FN.1 | With the advent of `mq-deadline` being the default scheduler, there is no longer a compelling reason to change to the `none` I/O scheduler for virtual disks.
    
    -   An exception to that would be if the virtual disks are backed by high speed NVMe or NVDIMM technology within the hypervisor _and_ the guest is performing a very large number of I/O per second along with small I/O sizes (4kb). In this corner case, then switching to the `none` scheduler can provide a slight overall improvement in iops and therefore throughput. This is due to the slightly longer execution code path of `mq-deadline` vs `none` schedulers.
        -   Testing with NVMe backed virtual disks between `none` and `mq-deadline` with simple single io depth test showed ~2% difference with block I/O sizes 32kb or larger, and less than 1% difference at 512kb io size. In normal circumstances, with more real life (more complex) I/O loads this difference can be within statistical noise when testing between the two schedulers as it will depend on what other operations the hypervisor is busy with at any given time and whether the NVMe device is utilized by more than one virtual disk and/or more than one guest.
    -   The `mq-deadline` scheduler is also the scheduler used by the `tuned` profile `virtual-host` and the default scheduler in RHEL 8 and 9 (changed to `mq-deadline` from `deadline` in 7.6+) for all but direct attached SATA rotating media disks.
-   FN.2 | On RHEL 7.5 and earlier: while the default `cfq` scheduler is a reasonable choice even for virtual disks within virtual guests, but it does have drawbacks. The main one being it is tuned to maximize I/O to a single rotating media physical disk. Moreover, most hypervisors also perform their own I/O scheduling for the physical resouces behind the virtual disks. And multiple virtual disks can use the same physical storage resource and presented to one or more guests. Under these circumstances switching to the `noop` I/O scheduler for virtual disks is recommended. Doing so reduces code path time (e.g. removes the slice idle time in `cfq`) associated with `cfq` and other schedulers. Using `noop` reduces the time the I/O spends in the scheduler layer of the linux I/O stack and allows the hypervisor to better schedule the I/O against the physical resources it is managing.
    
    -   If the hypervisor is known to do its own I/O scheduling -- which is normally the case -- then guests often have sufficient benefit from the `noop` I/O scheduler versus `cfq`, and `bfq`, schedulers to make the recommended switch to `noop` as a first step.
    -   If there are heavy I/O loads from a guest, then sometimes switching the guest to `deadline` can provide a small performance edge over the `noop` scheduler -- but it highly dependent on the I/O load itself. For example, a database i/O load of synchronous reads and asynchronous writes can benefit from `deadline` by biasing dispatch of reads first (that are blocking processes) over writes (which are non-blocking I/O).
-   FN.3 | The **storage technology** in use can affect which io scheduler produces the best results for a given configuration and I/O workload.
    
    -   If **physical disks**, iSCSI, SR-IOV pass-through are provisioned to guests, then **the `none` (noop) scheduler should _not_ be used**. Using `none` does not allow the linux virtual host to optimize I/O requests in terms of type or order to the underlying physical device. Only the guest itself should perform I/O scheduling in such configurations so choose `mq-deadline` (or `deadline` depending on kernel version).
    -   If **virtual disks** are presented to guests, then for most I/O workloads, the `mq-deadline` scheduler is likely statistically close enough vs using `none`. Given that `mq-deadline` is the default in later kernel versions, there is no compelling reason to change to `none`.
    -   If the hypervisor is known to do its own I/O scheduling -- which is normally the case -- then guests often benefit greatly from switching to the `noop` I/O scheduler from `cfq` or `bfq` schedulers. There is a much less messurable change in performance if switching to `none` from `mq-deadline` or `deadline` schedulers.
        -   Switching to `noop` from `cfq` allows the hypervisor to optimize the I/O requests and prioritize based on it's view on _all_ of the I/O from one or multiple guests. The hypervisor receives I/O from the guest in as submitted order within the guest. Within the linux virtual guest, the `noop` scheduler can still combine sequential small requests into larger requests before submitting the I/O to the hypervisor.
        -   Switching to `none` from `mq-deadline` results in a slightly shorter code expecution path associated with `none` over `mq-deadline`. But in performing the switch, the linux virtual guest looses the ability to prioritize dispatching blocking I/O over non-blocking I/O.
-   FN.4 | While there is a significant difference between the default `cfq` and `noop` use in RHEL 4, 5, and 6, there is less difference in performance in a virtual disk envoronment betweend the default `mq-deadline` and `none` in RHEL 8 and 9. However, to minimize I/O latency within the guest is more important than maximizing I/O throughput on the guest's I/O workloads then it may be beneficial to switch to `none` in RHEL 8 and 9 environments. Just be aware that nominal measured differences are typically in the range or +/- 1-3% differences between the two schedulers for virtual disks. But every I/O workload is different - so be sure to perform proper testing within your environment to determine how the scheduler change impacts your specific workload.
    

## Root Cause

### Testing

**NOTE:** _All scheduler tuning should be tested under normal operating conditions, as synthetic benchmarks typically do not accurately compare performance of systems using shared resources in virtual environments._

In this document, we refer to testing and comparing multiple schedulers. Some hints:

-   All scheduler tuning should be tested under normal operating conditions, as synthetic benchmarks typically do not accurately compare performance of systems using shared resources in virtual environments. Recommendations and defaults are only a place to start.
    -   Outside of some specific corner cases, the typical change in performance when comparing different schedulers is nominally in the +/- 5% range. Its very unusual, even in corner cases like all sequential reads for video streaming, to see more than a 10-20% improvement in I/O performance via just a scheduler change. So desiring a 5-10x improvement by finding the right scheduler is not very likely to happen.
-   One should first be clear about the goal or the goals one wants to optimize for. Do I want as many I/O as possible to storage? Do I want to optimize an application to provide service in a certain way, for example "this apache webserver should be able to hand out as many static files (fetched from storage) as possible"?
-   With the goal clear, one can decide on the best tool to measure. Applications can then be started, and measured. Not changing the conditions, several schedulers can be tried out, and the measurement might change.
-   Special attention should be payed to mutual influence of the components. A RHEL might host 10 KVM guests, and each of the guests various applications. Benchmarking should consider this whole system.

-   **Product(s)**
-   [Red Hat Enterprise Linux](https://access.redhat.com/search?q=Red+Hat+Enterprise+Linux&documentKind=Article%26Solution)

-   **Component**
-   [kvm](https://access.redhat.com/search?q=kvm&documentKind=Article%26Solution)
-   [vmware](https://access.redhat.com/search?q=vmware&documentKind=Article%26Solution)
-   [xen](https://access.redhat.com/search?q=xen&documentKind=Article%26Solution)

-   **Category**
-   [Learn more](https://access.redhat.com/search?q=Learn+more&documentKind=Article%26Solution)

-   **Tags**
-   [kvm](https://access.redhat.com/search?q=kvm&documentKind=Article%26Solution)
-   [performance](https://access.redhat.com/search?q=performance&documentKind=Article%26Solution)
-   [rhel\_4](https://access.redhat.com/search?q=rhel_4&documentKind=Article%26Solution)
-   [rhel\_5](https://access.redhat.com/search?q=rhel_5&documentKind=Article%26Solution)
-   [rhel\_6](https://access.redhat.com/search?q=rhel_6&documentKind=Article%26Solution)
-   [vmware](https://access.redhat.com/search?q=vmware&documentKind=Article%26Solution)
-   [xen](https://access.redhat.com/search?q=xen&documentKind=Article%26Solution)

This solution is part of Red Hat’s fast-track publication program, providing a huge library of solutions that Red Hat engineers have created while supporting our customers. To give you the knowledge you need the instant it becomes available, these articles may be presented in a raw and unedited form.

## Comments

 [LinkedIn](https://www.linkedin.com/company/red-hat) [YouTube](https://www.youtube.com/user/RedHatVideos) [Facebook](https://www.facebook.com/RedHat) [X, formerly Twitter](https://twitter.com/RedHat)

### Quick Links

### Help

### Site Info

### Related Sites

### About

-   [Red Hat Subscription Value](https://access.redhat.com/subscription-value)
-   [About Red Hat](https://www.redhat.com/about/)
-   [Red Hat Jobs](http://jobs.redhat.com/)

Copyright © 2026 Red Hat
