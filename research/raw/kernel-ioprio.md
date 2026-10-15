# Block io priorities — The Linux Kernel documentation

<https://docs.kernel.org/block/ioprio.html>

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

-   [Show Source](https://docs.kernel.org/_sources/block/ioprio.rst.txt)

# Block io priorities[¶](https://docs.kernel.org/block/ioprio.html#block-io-priorities "Permalink to this heading")

## Intro[¶](https://docs.kernel.org/block/ioprio.html#intro "Permalink to this heading")

The io priority feature enables users to io nice processes or process groups, similar to what has been possible with cpu scheduling for ages. Support for io priorities is io scheduler dependent and currently supported by bfq and mq-deadline.

## Scheduling classes[¶](https://docs.kernel.org/block/ioprio.html#scheduling-classes "Permalink to this heading")

Three generic scheduling classes are implemented for io priorities that determine how io is served for a process.

IOPRIO\_CLASS\_RT: This is the realtime io class. This scheduling class is given higher priority than any other in the system, processes from this class are given first access to the disk every time. Thus it needs to be used with some care, one io RT process can starve the entire system. Within the RT class, there are 8 levels of class data that determine exactly how much time this process needs the disk for on each service. In the future this might change to be more directly mappable to performance, by passing in a wanted data rate instead.

IOPRIO\_CLASS\_BE: This is the best-effort scheduling class, which is the default for any process that hasn’t set a specific io priority. The class data determines how much io bandwidth the process will get, it’s directly mappable to the cpu nice levels just more coarsely implemented. 0 is the highest BE prio level, 7 is the lowest. The mapping between cpu nice level and io nice level is determined as: io\_nice = (cpu\_nice + 20) / 5.

IOPRIO\_CLASS\_IDLE: This is the idle scheduling class, processes running at this level only get io time when no one else needs the disk. The idle class has no class data, since it doesn’t really apply here.

## Tools[¶](https://docs.kernel.org/block/ioprio.html#tools "Permalink to this heading")

See below for a sample ionice tool. Usage:

\# ionice -c<class> -n<level> -p<pid>

If pid isn’t given, the current process is assumed. IO priority settings are inherited on fork, so you can use ionice to start the process at a given level:

\# ionice -c2 -n0 /bin/ls

will run ls at the best-effort scheduling class at the highest priority. For a running process, you can give the pid instead:

\# ionice -c1 -n2 -p100

will change pid 100 to run at the realtime scheduling class, at priority 2.

ionice.c tool:

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <getopt.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <asm/unistd.h>

extern int sys\_ioprio\_set(int, int, int);
extern int sys\_ioprio\_get(int, int);

#if defined(\_\_i386\_\_)
#define \_\_NR\_ioprio\_set               289
#define \_\_NR\_ioprio\_get               290
#elif defined(\_\_ppc\_\_)
#define \_\_NR\_ioprio\_set               273
#define \_\_NR\_ioprio\_get               274
#elif defined(\_\_x86\_64\_\_)
#define \_\_NR\_ioprio\_set               251
#define \_\_NR\_ioprio\_get               252
#else
#error "Unsupported arch"
#endif

static inline int ioprio\_set(int which, int who, int ioprio)
{
      return syscall(\_\_NR\_ioprio\_set, which, who, ioprio);
}

static inline int ioprio\_get(int which, int who)
{
      return syscall(\_\_NR\_ioprio\_get, which, who);
}

enum {
      IOPRIO\_CLASS\_NONE,
      IOPRIO\_CLASS\_RT,
      IOPRIO\_CLASS\_BE,
      IOPRIO\_CLASS\_IDLE,
};

enum {
      IOPRIO\_WHO\_PROCESS = 1,
      IOPRIO\_WHO\_PGRP,
      IOPRIO\_WHO\_USER,
};

#define IOPRIO\_CLASS\_SHIFT    13

const char \*to\_prio\[\] = { "none", "realtime", "best-effort", "idle", };

int main(int argc, char \*argv\[\])
{
      int ioprio = 4, set = 0, ioprio\_class = IOPRIO\_CLASS\_BE;
      int c, pid = 0;

      while ((c = getopt(argc, argv, "+n:c:p:")) != EOF) {
              switch (c) {
              case 'n':
                      ioprio = strtol(optarg, NULL, 10);
                      set = 1;
                      break;
              case 'c':
                      ioprio\_class = strtol(optarg, NULL, 10);
                      set = 1;
                      break;
              case 'p':
                      pid = strtol(optarg, NULL, 10);
                      break;
              }
      }

      switch (ioprio\_class) {
              case IOPRIO\_CLASS\_NONE:
                      ioprio\_class = IOPRIO\_CLASS\_BE;
                      break;
              case IOPRIO\_CLASS\_RT:
              case IOPRIO\_CLASS\_BE:
                      break;
              case IOPRIO\_CLASS\_IDLE:
                      ioprio = 7;
                      break;
              default:
                      printf("bad prio class %d\\n", ioprio\_class);
                      return 1;
      }

      if (!set) {
              if (!pid && argv\[optind\])
                      pid = strtol(argv\[optind\], NULL, 10);

              ioprio = ioprio\_get(IOPRIO\_WHO\_PROCESS, pid);

              printf("pid=%d, %d\\n", pid, ioprio);

              if (ioprio == -1)
                      perror("ioprio\_get");
              else {
                      ioprio\_class = ioprio >> IOPRIO\_CLASS\_SHIFT;
                      ioprio = ioprio & 0xff;
                      printf("%s: prio %d\\n", to\_prio\[ioprio\_class\], ioprio);
              }
      } else {
              if (ioprio\_set(IOPRIO\_WHO\_PROCESS, pid, ioprio | ioprio\_class << IOPRIO\_CLASS\_SHIFT) == -1) {
                      perror("ioprio\_set");
                      return 1;
              }

              if (argv\[optind\])
                      execvp(argv\[optind\], &argv\[optind\]);
      }

      return 0;
}

March 11 2005, Jens Axboe <[jens.axboe@oracle.com](mailto:jens.axboe%40oracle.com)\>

©The kernel development community. | Powered by [Sphinx 5.3.0](https://www.sphinx-doc.org/) & [Alabaster 0.7.16](https://alabaster.readthedocs.io/) | [Page source](https://docs.kernel.org/_sources/block/ioprio.rst.txt)
