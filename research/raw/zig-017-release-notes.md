# 0.17.0 Release Notes ⚡ The Zig Programming Language

<https://ziglang.org/download/0.17.0/release-notes.html>

# 0.17.0 Release Notes

[Download & Documentation](https://ziglang.org/download/#release-0.17.0)

Zig is a general-purpose programming language and toolchain for maintaining **robust**, **optimal**, and **reusable** software.

Zig development is funded via [Zig Software Foundation](https://ziglang.org/zsf/), a 501(c)(3) non-profit organization. Please consider a recurring donation so that we can offer more billable hours to our core team members. This is the most straightforward way to accelerate the project along the [Roadmap](https://ziglang.org/download/0.17.0/release-notes.html#Roadmap) to 1.0. If you need **donation receipts** or are looking to migrate away from GitHub Sponsors, we recommend [donating via Every.org](https://www.every.org/zig-software-foundation-inc).

This release features **5 months of work**: changes from **206 different contributors**, spread among **925 commits**.

Originally predicted to be shorter, this release cycle ended up substantial, with the [Build System](https://ziglang.org/download/0.17.0/release-notes.html#Build-System) reworked, including the introduction of the [Build Server Protocol](https://ziglang.org/download/0.17.0/release-notes.html#Build-Server-Protocol), and the [ELF Linker](https://ziglang.org/download/0.17.0/release-notes.html#ELF) enhanced to the point where we expect [Incremental Compilation](https://ziglang.org/download/0.17.0/release-notes.html#Incremental-Compilation) to work for everyone on x86\_64-linux.

## [Table of Contents](https://ziglang.org/download/0.17.0/release-notes.html#toc-Table-of-Contents) [§](https://ziglang.org/download/0.17.0/release-notes.html#Table-of-Contents)

-   [Table of Contents](https://ziglang.org/download/0.17.0/release-notes.html#Table-of-Contents)
-   [Target Support](https://ziglang.org/download/0.17.0/release-notes.html#Target-Support)
    -   [Tier System](https://ziglang.org/download/0.17.0/release-notes.html#Tier-System)
        -   [Tier 1](https://ziglang.org/download/0.17.0/release-notes.html#Tier-1)
        -   [Tier 2](https://ziglang.org/download/0.17.0/release-notes.html#Tier-2)
        -   [Tier 3](https://ziglang.org/download/0.17.0/release-notes.html#Tier-3)
        -   [Tier 4](https://ziglang.org/download/0.17.0/release-notes.html#Tier-4)
    -   [Support Table](https://ziglang.org/download/0.17.0/release-notes.html#Support-Table)
    -   [OS Version Requirements](https://ziglang.org/download/0.17.0/release-notes.html#OS-Version-Requirements)
    -   [Additional Platforms](https://ziglang.org/download/0.17.0/release-notes.html#Additional-Platforms)
-   [Language Changes](https://ziglang.org/download/0.17.0/release-notes.html#Language-Changes)
    -   [Language Stability Progress](https://ziglang.org/download/0.17.0/release-notes.html#Language-Stability-Progress)
    -   [`@bitCast` changes](https://ziglang.org/download/0.17.0/release-notes.html#codebitCastcode-changes)
    -   [Formally Specified and Fuzzed Grammar](https://ziglang.org/download/0.17.0/release-notes.html#Formally-Specified-and-Fuzzed-Grammar)
    -   [C Translation Moving to External Package](https://ziglang.org/download/0.17.0/release-notes.html#C-Translation-Moving-to-External-Package)
    -   [Added `@backingInt` and `@fromBackingInt`](https://ziglang.org/download/0.17.0/release-notes.html#Added-codebackingIntcode-and-codefromBackingIntcode)
    -   [Added `@SpirvType`](https://ziglang.org/download/0.17.0/release-notes.html#Added-codeSpirvTypecode)
    -   [Array Multiplication Syntax Removed](https://ziglang.org/download/0.17.0/release-notes.html#Array-Multiplication-Syntax-Removed)
    -   [Added `@divCeil`](https://ziglang.org/download/0.17.0/release-notes.html#Added-codedivCeilcode)
    -   [`@hasDecl` Returns `true` Only for Public Declarations](https://ziglang.org/download/0.17.0/release-notes.html#codehasDeclcode-Returns-codetruecode-Only-for-Public-Declarations)
    -   [Allow Dereference and Coercion to Array Pointer of `comptime` Length Slices](https://ziglang.org/download/0.17.0/release-notes.html#Allow-Dereference-and-Coercion-to-Array-Pointer-of-codecomptimecode-Length-Slices)
    -   [`void{}` Syntax Removed](https://ziglang.org/download/0.17.0/release-notes.html#codevoidcode-Syntax-Removed)
    -   [`errdefer` Capture Removed](https://ziglang.org/download/0.17.0/release-notes.html#codeerrdefercode-Capture-Removed)
    -   [`i0` Removed](https://ziglang.org/download/0.17.0/release-notes.html#codei0code-Removed)
    -   [`internal` and `link_once` Global Linkage Removed](https://ziglang.org/download/0.17.0/release-notes.html#codeinternalcode-and-codelink_oncecode-Global-Linkage-Removed)
-   [Standard Library](https://ziglang.org/download/0.17.0/release-notes.html#Standard-Library)
    -   [Deprecations](https://ziglang.org/download/0.17.0/release-notes.html#Deprecations)
        -   [Potential `containsAtLeastScalar` Footgun](https://ziglang.org/download/0.17.0/release-notes.html#Potential-codecontainsAtLeastScalarcode-Footgun)
    -   [StackFallbackAllocator Reworked and Renamed](https://ziglang.org/download/0.17.0/release-notes.html#StackFallbackAllocator-Reworked-and-Renamed)
    -   [SafeAllocator Introduced](https://ziglang.org/download/0.17.0/release-notes.html#SafeAllocator-Introduced)
    -   [ArrayList](https://ziglang.org/download/0.17.0/release-notes.html#ArrayList)
        -   [ArrayList Pointer Stability](https://ziglang.org/download/0.17.0/release-notes.html#ArrayList-Pointer-Stability)
    -   [`debug.SafetyLock` Gains Support for Shared Locking](https://ziglang.org/download/0.17.0/release-notes.html#codedebugSafetyLockcode-Gains-Support-for-Shared-Locking)
    -   [`fmt.allocPrint` moved to `mem.Allocator`](https://ziglang.org/download/0.17.0/release-notes.html#codefmtallocPrintcode-moved-to-codememAllocatorcode)
    -   [Formatted Printing Enhancements](https://ziglang.org/download/0.17.0/release-notes.html#Formatted-Printing-Enhancements)
    -   [`std.zon.parse` Reworked](https://ziglang.org/download/0.17.0/release-notes.html#codestdzonparsecode-Reworked)
    -   [Rename `bit_set` Variants and Deprecate the Managed One](https://ziglang.org/download/0.17.0/release-notes.html#Rename-codebit_setcode-Variants-and-Deprecate-the-Managed-One)
    -   [Struct-Of-Arrays Style for `std.lang.Type`](https://ziglang.org/download/0.17.0/release-notes.html#Struct-Of-Arrays-Style-for-codestdlangTypecode)
    -   [Rename `lang.OptimizeMode` to `lang.Optimize`](https://ziglang.org/download/0.17.0/release-notes.html#Rename-codelangOptimizeModecode-to-codelangOptimizecode)
    -   [`lang.Optimize.runtimeSafety`](https://ziglang.org/download/0.17.0/release-notes.html#codelangOptimizeruntimeSafetycode)
    -   [@import("builtin") Deprecations](https://ziglang.org/download/0.17.0/release-notes.html#importbuiltin-Deprecations)
    -   [Handle Floats Correctly in `mem.eql` and `mem.findDiff`](https://ziglang.org/download/0.17.0/release-notes.html#Handle-Floats-Correctly-in-codememeqlcode-and-codememfindDiffcode)
    -   [Decouple `Uri` and `net.HostName`](https://ziglang.org/download/0.17.0/release-notes.html#Decouple-codeUricode-and-codenetHostNamecode)
-   [Build System](https://ziglang.org/download/0.17.0/release-notes.html#Build-System)
    -   [Separate the Maker Process from the Configurer Process](https://ziglang.org/download/0.17.0/release-notes.html#Separate-the-Maker-Process-from-the-Configurer-Process)
    -   [Cache System Reworked](https://ziglang.org/download/0.17.0/release-notes.html#Cache-System-Reworked)
    -   [Introduce the Concept of Configure Cache Poisoning](https://ziglang.org/download/0.17.0/release-notes.html#Introduce-the-Concept-of-Configure-Cache-Poisoning)
    -   [findProgram](https://ziglang.org/download/0.17.0/release-notes.html#findProgram)
    -   [findProgramLazy](https://ziglang.org/download/0.17.0/release-notes.html#findProgramLazy)
    -   [Run Step: Passthru Args](https://ziglang.org/download/0.17.0/release-notes.html#Run-Step-Passthru-Args)
    -   [Fmt Step: Options](https://ziglang.org/download/0.17.0/release-notes.html#Fmt-Step-Options)
    -   [`Step.Options`: add addOptionPathDirectory](https://ziglang.org/download/0.17.0/release-notes.html#codeStepOptionscode-add-addOptionPathDirectory)
    -   [Lazy Dependency Ergonomic Enhancements](https://ziglang.org/download/0.17.0/release-notes.html#Lazy-Dependency-Ergonomic-Enhancements)
    -   [Removed Ability to Override Build Runner](https://ziglang.org/download/0.17.0/release-notes.html#Removed-Ability-to-Override-Build-Runner)
    -   [Package Management](https://ziglang.org/download/0.17.0/release-notes.html#Package-Management)
        -   [Ability to Override Package Path](https://ziglang.org/download/0.17.0/release-notes.html#Ability-to-Override-Package-Path)
        -   [Global vs Local Fetching](https://ziglang.org/download/0.17.0/release-notes.html#Global-vs-Local-Fetching)
    -   [Slight Difference in PATH for DLL Arguments](https://ziglang.org/download/0.17.0/release-notes.html#Slight-Difference-in-PATH-for-DLL-Arguments)
    -   [Build Server Protocol](https://ziglang.org/download/0.17.0/release-notes.html#Build-Server-Protocol)
-   [Compiler](https://ziglang.org/download/0.17.0/release-notes.html#Compiler)
    -   [Incremental Compilation](https://ziglang.org/download/0.17.0/release-notes.html#Incremental-Compilation)
    -   [SPIR-V Backend](https://ziglang.org/download/0.17.0/release-notes.html#SPIR-V-Backend)
    -   [aarch64 Backend](https://ziglang.org/download/0.17.0/release-notes.html#aarch64-Backend)
    -   [loongarch Backend](https://ziglang.org/download/0.17.0/release-notes.html#loongarch-Backend)
    -   [WebAssembly Backend](https://ziglang.org/download/0.17.0/release-notes.html#WebAssembly-Backend)
-   [Linker](https://ziglang.org/download/0.17.0/release-notes.html#Linker)
    -   [ELF](https://ziglang.org/download/0.17.0/release-notes.html#ELF)
    -   [COFF](https://ziglang.org/download/0.17.0/release-notes.html#COFF)
    -   [New Linker Testing Framework](https://ziglang.org/download/0.17.0/release-notes.html#New-Linker-Testing-Framework)
    -   [SPIR-V](https://ziglang.org/download/0.17.0/release-notes.html#SPIR-V)
-   [Fuzzer](https://ziglang.org/download/0.17.0/release-notes.html#Fuzzer)
-   [Bug Fixes](https://ziglang.org/download/0.17.0/release-notes.html#Bug-Fixes)
    -   [This Release Contains Bugs](https://ziglang.org/download/0.17.0/release-notes.html#This-Release-Contains-Bugs)
        -   [Notable Regressions](https://ziglang.org/download/0.17.0/release-notes.html#Notable-Regressions)
-   [Toolchain](https://ziglang.org/download/0.17.0/release-notes.html#Toolchain)
    -   [LLVM 22](https://ziglang.org/download/0.17.0/release-notes.html#LLVM-22)
        -   [Loop Vectorization Disabled to Work Around Regression](https://ziglang.org/download/0.17.0/release-notes.html#Loop-Vectorization-Disabled-to-Work-Around-Regression)
    -   [musl 1.2.5](https://ziglang.org/download/0.17.0/release-notes.html#musl-125)
    -   [glibc 2.44](https://ziglang.org/download/0.17.0/release-notes.html#glibc-244)
    -   [Linux 7.2 Headers](https://ziglang.org/download/0.17.0/release-notes.html#Linux-72-Headers)
    -   [macOS 27.0 Headers](https://ziglang.org/download/0.17.0/release-notes.html#macOS-270-Headers)
    -   [MinGW-w64](https://ziglang.org/download/0.17.0/release-notes.html#MinGW-w64)
    -   [NetBSD 11.0 libc](https://ziglang.org/download/0.17.0/release-notes.html#NetBSD-110-libc)
    -   [OpenBSD 7.9 libc](https://ziglang.org/download/0.17.0/release-notes.html#OpenBSD-79-libc)
    -   [WASI libc](https://ziglang.org/download/0.17.0/release-notes.html#WASI-libc)
    -   [zig libc](https://ziglang.org/download/0.17.0/release-notes.html#zig-libc)
    -   [zig cc](https://ziglang.org/download/0.17.0/release-notes.html#zig-cc)
    -   [zig objdump](https://ziglang.org/download/0.17.0/release-notes.html#zig-objdump)
    -   [resinator](https://ziglang.org/download/0.17.0/release-notes.html#resinator)
        -   [Windows Resource Compilation Moving to an External Package](https://ziglang.org/download/0.17.0/release-notes.html#Windows-Resource-Compilation-Moving-to-an-External-Package)
    -   [zig fmt](https://ziglang.org/download/0.17.0/release-notes.html#zig-fmt)
        -   [Added `--complexity` Flag](https://ziglang.org/download/0.17.0/release-notes.html#Added-code--complexitycode-Flag)
-   [Roadmap](https://ziglang.org/download/0.17.0/release-notes.html#Roadmap)
-   [Thank You Contributors!](https://ziglang.org/download/0.17.0/release-notes.html#Thank-You-Contributors)
-   [Thank You Sponsors!](https://ziglang.org/download/0.17.0/release-notes.html#Thank-You-Sponsors)

## [Target Support](https://ziglang.org/download/0.17.0/release-notes.html#toc-Target-Support) [§](https://ziglang.org/download/0.17.0/release-notes.html#Target-Support)

Zig supports a wide range of architectures and operating systems. The [Support Table](https://ziglang.org/download/0.17.0/release-notes.html#Support-Table) and [Additional Platforms](https://ziglang.org/download/0.17.0/release-notes.html#Additional-Platforms) sections cover the targets that Zig can build programs for, while the [zig-bootstrap README](https://codeberg.org/ziglang/zig-bootstrap#supported-targets) covers the targets that the Zig [Compiler](https://ziglang.org/download/0.17.0/release-notes.html#Compiler) itself can be easily cross-compiled to run on.

Notable changes:

-   `aarch64-openbsd` is now tested natively in Zig's CI, ensuring high-quality support going forward.
-   `aarch64-freebsd` and `aarch64-netbsd` CI jobs now run on pull requests too, in addition to `master` pushes.
-   [An LLVM bug](https://github.com/llvm/llvm-project/issues/199581) that broke most `aarch64-windows` binaries, including the Zig [Compiler](https://ziglang.org/download/0.17.0/release-notes.html#Compiler), has been worked around.
-   The Zig [Compiler](https://ziglang.org/download/0.17.0/release-notes.html#Compiler) now applies mandatory code hardening techniques when targeting `aarch64-openbsd` so that the resulting binaries actually work.
-   Zig now provides stack traces on crashes and failed assertions on 32-bit ARM. Some work [still remains](https://codeberg.org/ziglang/zig/issues/30931) for Thumb-only targets.
-   Zig now provides stack traces on crashes and failed assertions on SPARC.
-   Zig now handles pointer authentication opcodes when doing stack unwinding on AArch64.
-   Support for the `loongarch32-linux-gnu[sf]` targets has been added.
-   Zig now has generally usable support for 64-bit SPARC, and especially `sparc64-linux`. This is largely thanks to Zig's new ELF linker which now has better support for this target than LLD.
-   The Zig [Standard Library](https://ziglang.org/download/0.17.0/release-notes.html#Standard-Library) has been ported to the x32 and N32 ABIs on x86-64 and 64-bit MIPS, respectively. These are niche ILP32 ABIs that allow using the 64-bit instruction set while only having 32-bit pointers - the idea being to trade available address space for lower memory usage and better cache utilization.
-   Target information has been added for some game consoles: `aarch64-switch`, `arm-gba`, `mipsel-psx`, and `powerpc-wiiu`
-   Very early `xtensa-linux` support has been added to Zig. Note that, for now, this support can only be exercised via the C backend or the experimental [LLVM](https://ziglang.org/download/0.17.0/release-notes.html#LLVM-22) backend.
-   The Zig [Standard Library](https://ziglang.org/download/0.17.0/release-notes.html#Standard-Library) now has support for `arc[eb]-linux`, `csky-linux`, and `m88k-openbsd` when using the C backend.
-   The Zig [Standard Library](https://ziglang.org/download/0.17.0/release-notes.html#Standard-Library) now has support for no-libc `microblaze[el]-linux`, `sh[eb]-linux`, and `sparc-linux`.
-   Zig now enforces `-mabi=ieeelongdouble` for all PowerPC targets. This is just a formalization of what was already reality; Zig has never supported the IBM "double-double" format for `long double` and likely never will. As a result, this release drops support for `powerpc-linux-gnueabi[hf]` because glibc only supports the "double-double" format on these targets. The `powerpc-linux-musleabi[hf]` targets remain supported as they use the IEEE format.
-   This release drops support for `powerpc64-linux-gnu`. Zig has only ever supported linking ELFv2 binaries for 64-bit PowerPC, and glibc does not officially support ELFv2 on big endian - nor IEEE `long double`, as above.
-   Zig's ability to detect the native CPU model and features has been greatly enhanced across the board; this affects almost every architecture on every supported OS.
-   The baseline CPU model has been changed for some targets:
    -   `aarch64-haiku`: `cortex_a55`
    -   `m68k-*`: `M68030`
    -   `mips64-openbsd`: `octeon`
    -   `powerpc-netbsd`: `750`
    -   `powerpc64-freebsd`: `pwr8`
    -   `powerpc64-linux`: `pwr8`
    -   `powerpc64-openbsd`: `pwr9`
    -   `s390x-*`: `arch11`
    -   `sparc-*`: `generic`
    -   `sparc-linux`: `v9`
    -   `sparc64-*`: `ultrasparc`
    -   `xtensa-*`: `esp32`
-   In Zig's target query syntax, native libc version detection now only happens if the triple actually uses native libc (i.e. the ABI component is omitted). We expect this new behavior to better match people's mental model for how target queries work, particularly when considering how the OS component works.

### [Tier System](https://ziglang.org/download/0.17.0/release-notes.html#toc-Tier-System) [§](https://ziglang.org/download/0.17.0/release-notes.html#Tier-System)

Zig's level of support for various targets is broadly categorized into four tiers with Tier 1 being the highest. The goal is for Tier 1 targets to have zero disabled tests - this will become a requirement for post-1.0.0 Zig releases.

#### [Tier 1](https://ziglang.org/download/0.17.0/release-notes.html#toc-Tier-1) [§](https://ziglang.org/download/0.17.0/release-notes.html#Tier-1)

-   All non-experimental [language](https://ziglang.org/download/0.17.0/release-notes.html#Language-Changes) features are known to work correctly.
-   The [Compiler](https://ziglang.org/download/0.17.0/release-notes.html#Compiler) can generate machine code for this target without relying on [LLVM](https://ziglang.org/download/0.17.0/release-notes.html#LLVM-22).
-   The integrated [fuzzer](https://ziglang.org/download/0.17.0/release-notes.html#Fuzzer) works on this target (if applicable).

#### [Tier 2](https://ziglang.org/download/0.17.0/release-notes.html#toc-Tier-2) [§](https://ziglang.org/download/0.17.0/release-notes.html#Tier-2)

-   The [Standard Library](https://ziglang.org/download/0.17.0/release-notes.html#Standard-Library) cross-platform abstractions have implementations for this target.
-   Failed assertions and crashes produce stack traces on this target.
-   libc is available for this target even when cross-compiling (if applicable).
-   Continuous integration machines build the module tests for this target on every push.

#### [Tier 3](https://ziglang.org/download/0.17.0/release-notes.html#toc-Tier-3) [§](https://ziglang.org/download/0.17.0/release-notes.html#Tier-3)

-   The [Compiler](https://ziglang.org/download/0.17.0/release-notes.html#Compiler) can generate machine code for this target by relying on an external backend such as [LLVM](https://ziglang.org/download/0.17.0/release-notes.html#LLVM-22).
-   The [Linker](https://ziglang.org/download/0.17.0/release-notes.html#Linker) can produce object files, libraries, and executables for this target.

#### [Tier 4](https://ziglang.org/download/0.17.0/release-notes.html#toc-Tier-4) [§](https://ziglang.org/download/0.17.0/release-notes.html#Tier-4)

-   The [Compiler](https://ziglang.org/download/0.17.0/release-notes.html#Compiler) can generate assembly or C source code for this target.

### [Support Table](https://ziglang.org/download/0.17.0/release-notes.html#toc-Support-Table) [§](https://ziglang.org/download/0.17.0/release-notes.html#Support-Table)

In the following table, ✅ indicates full support, ❌ indicates no support, and ⚠️ indicates that there is partial support, e.g. only for some sub-targets, or with some notable known issues. ❔ indicates that the status is largely unknown, typically because the target is rarely exercised. Hover over other icons for details.

Targets marked with 🪦 are obsolescent; the Zig compiler and standard library maintain best-effort support for them, but that support is expected to be removed eventually.

| Tier | Target | Code Gen. | Linker | Lang. Feat. | Std. Lib. | Stack Traces | Fuzzer | libc | CI |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | [`x86_64-linux`](https://ziglang.org/learn/platform-support/x86_64-linux) | 🖥️⚡ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 
* * *

 |
| 2 | [`aarch64-freebsd`](https://ziglang.org/learn/platform-support/aarch64-freebsd) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`aarch64[_be]-linux`](https://ziglang.org/learn/platform-support/aarch64-linux) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`aarch64-maccatalyst`](https://ziglang.org/learn/platform-support/aarch64-maccatalyst) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`aarch64-macos`](https://ziglang.org/learn/platform-support/aarch64-macos) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`aarch64[_be]-netbsd`](https://ziglang.org/learn/platform-support/aarch64-netbsd) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`aarch64-openbsd`](https://ziglang.org/learn/platform-support/aarch64-openbsd) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`aarch64-windows`](https://ziglang.org/learn/platform-support/aarch64-windows) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`arm-freebsd`](https://ziglang.org/learn/platform-support/arm-freebsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`arm[eb]-linux`](https://ziglang.org/learn/platform-support/arm-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`arm[eb]-netbsd`](https://ziglang.org/learn/platform-support/arm-netbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`arm-openbsd`](https://ziglang.org/learn/platform-support/arm-openbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`hexagon-linux`](https://ziglang.org/learn/platform-support/hexagon-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`loongarch32-linux`](https://ziglang.org/learn/platform-support/loongarch32-linux) | 🖥🛠 | ✅ | ❔ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`loongarch64-linux`](https://ziglang.org/learn/platform-support/loongarch64-linux) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`mips[el]-linux`](https://ziglang.org/learn/platform-support/mips-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`mips[el]-netbsd`](https://ziglang.org/learn/platform-support/mips-netbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`mips64[el]-linux`](https://ziglang.org/learn/platform-support/mips64-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`mips64[el]-openbsd`](https://ziglang.org/learn/platform-support/mips64-openbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`powerpc-linux`](https://ziglang.org/learn/platform-support/powerpc-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`powerpc-netbsd`](https://ziglang.org/learn/platform-support/powerpc-netbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`powerpc-openbsd`](https://ziglang.org/learn/platform-support/powerpc-openbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`powerpc64[le]-freebsd`](https://ziglang.org/learn/platform-support/powerpc64-freebsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`powerpc64[le]-linux`](https://ziglang.org/learn/platform-support/powerpc64-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`powerpc64-openbsd`](https://ziglang.org/learn/platform-support/powerpc64-openbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`riscv32-linux`](https://ziglang.org/learn/platform-support/riscv32-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`riscv32-netbsd`](https://ziglang.org/learn/platform-support/riscv32-netbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 2 | [`riscv64-freebsd`](https://ziglang.org/learn/platform-support/riscv64-freebsd) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 2 | [`riscv64-linux`](https://ziglang.org/learn/platform-support/riscv64-linux) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`riscv64-netbsd`](https://ziglang.org/learn/platform-support/riscv64-netbsd) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 2 | [`riscv64-openbsd`](https://ziglang.org/learn/platform-support/riscv64-openbsd) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 | [`s390x-linux`](https://ziglang.org/learn/platform-support/s390x-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`sparc64-linux`](https://ziglang.org/learn/platform-support/sparc64-linux) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`thumb[eb]-linux`](https://ziglang.org/learn/platform-support/thumb-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`wasm32-wasi`](https://ziglang.org/learn/platform-support/wasm32-wasi) | 🖥️🛠️ | ✅ | ✅ | ✅ | ⚠️ | ❌ | ✅ | ✅ |
| 2 | [`x86-linux`](https://ziglang.org/learn/platform-support/x86-linux) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`x86-netbsd`](https://ziglang.org/learn/platform-support/x86-netbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`x86-openbsd`](https://ziglang.org/learn/platform-support/x86-openbsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| 2 🪦 | [`x86-windows`](https://ziglang.org/learn/platform-support/x86-windows) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`x86_64-freebsd`](https://ziglang.org/learn/platform-support/x86_64-freebsd) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 🪦 | [`x86_64-maccatalyst`](https://ziglang.org/learn/platform-support/x86_64-maccatalyst) | 🖥️⚡ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 2 🪦 | [`x86_64-macos`](https://ziglang.org/learn/platform-support/x86_64-macos) | 🖥️⚡ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 2 | [`x86_64-netbsd`](https://ziglang.org/learn/platform-support/x86_64-netbsd) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | [`x86_64-openbsd`](https://ziglang.org/learn/platform-support/x86_64-openbsd) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | [`x86_64-windows`](https://ziglang.org/learn/platform-support/x86_64-windows) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 

* * *

 |
| 3 | [`aarch64-haiku`](https://ziglang.org/learn/platform-support/aarch64-haiku) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❔ | ❌️ | ❌️ |
| 3 | [`aarch64-ios`](https://ziglang.org/learn/platform-support/aarch64-ios) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 3 | [`aarch64-serenity`](https://ziglang.org/learn/platform-support/aarch64-serenity) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❔ | ❌️ | ❌️ |
| 3 | [`aarch64-tvos`](https://ziglang.org/learn/platform-support/aarch64-tvos) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 3 | [`aarch64-visionos`](https://ziglang.org/learn/platform-support/aarch64-visionos) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 3 | [`aarch64-watchos`](https://ziglang.org/learn/platform-support/aarch64-watchos) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 3 | [`arm-haiku`](https://ziglang.org/learn/platform-support/arm-haiku) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 3 | [`mips64[el]-netbsd`](https://ziglang.org/learn/platform-support/mips64-netbsd) | 🖥️ | ✅ | ✅ | ✅ | ❌️ | ✅ | ❌️ | ❌️ |
| 3 | [`riscv64-haiku`](https://ziglang.org/learn/platform-support/riscv64-haiku) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❔ | ❌️ | ❌️ |
| 3 | [`riscv64-serenity`](https://ziglang.org/learn/platform-support/riscv64-serenity) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❔ | ❌️ | ❌️ |
| 3 🪦 | [`thumb-windows`](https://ziglang.org/learn/platform-support/thumb-windows) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌️ |
| 3 | [`wasm64-wasi`](https://ziglang.org/learn/platform-support/wasm64-wasi) | 🖥️🛠️ | ✅ | ❔ | ❌️ | ⚠️ | ❌ | ❌️ | ❌️ |
| 3 🪦 | [`x86-freebsd`](https://ziglang.org/learn/platform-support/x86-freebsd) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| 3 | [`x86-haiku`](https://ziglang.org/learn/platform-support/x86-haiku) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 3 🪦 | [`x86-illumos`](https://ziglang.org/learn/platform-support/x86-illumos) | 🖥️ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 3 | [`x86_64-dragonfly`](https://ziglang.org/learn/platform-support/x86_64-dragonfly) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❔ | ❌️ | ❌️ |
| 3 | [`x86_64-haiku`](https://ziglang.org/learn/platform-support/x86_64-haiku) | 🖥️⚡ | ✅ | ✅ | ✅ | ✅ | ❔ | ❌️ | ❌️ |
| 3 | [`x86_64-illumos`](https://ziglang.org/learn/platform-support/x86_64-illumos) | 🖥️🛠️ | ✅ | ✅ | ✅ | ✅ | ❔ | ❌️ | ❌️ |
| 3 | [`x86_64-serenity`](https://ziglang.org/learn/platform-support/x86_64-serenity) | 🖥️⚡ | ✅ | ✅ | ✅ | ✅ | ❔ | ❌️ | ❌️ |
| 

* * *

 |
| 4 | [`alpha-linux`](https://ziglang.org/learn/platform-support/alpha-linux) | 📄 | ❌️ | ❔ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 4 | [`alpha-netbsd`](https://ziglang.org/learn/platform-support/alpha-netbsd) | 📄 | ❌️ | ❔ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 4 | [`alpha-openbsd`](https://ziglang.org/learn/platform-support/alpha-openbsd) | 📄 | ❌️ | ❔ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 4 | [`arc[eb]-linux`](https://ziglang.org/learn/platform-support/arc-linux) | 📄 | ❌️ | ❔ | ✅ | ✅ | ❌ | ✅ | ❌️ |
| 4 | [`csky-linux`](https://ziglang.org/learn/platform-support/csky-linux) | 📄 | ❌️ | ❔ | ✅ | ✅ | ❌ | ✅ | ❌️ |
| 4 | [`hppa-linux`](https://ziglang.org/learn/platform-support/hppa-linux) | 📄 | ❌️ | ❔ | ❌️ | ❌️ | ❌ | ❌️ | ❌️ |
| 4 | [`hppa-netbsd`](https://ziglang.org/learn/platform-support/hppa-netbsd) | 📄 | ❌️ | ❔ | ✅ | ❌️ | ❌ | ❌️ | ❌️ |
| 4 | [`hppa-openbsd`](https://ziglang.org/learn/platform-support/hppa-openbsd) | 📄 | ❌️ | ❔ | ✅ | ❌️ | ❌ | ❌️ | ❌️ |
| 4 | [`hppa64-linux`](https://ziglang.org/learn/platform-support/hppa64-linux) | 📄 | ❌️ | ❔ | ❌️ | ❌️ | ❌ | ❌️ | ❌️ |
| 4 | [`m68k-linux`](https://ziglang.org/learn/platform-support/m68k-linux) | 🖥️ | ❌️ | ❔ | ✅ | ✅ | ❌ | ✅ | ❌️ |
| 4 | [`m68k-netbsd`](https://ziglang.org/learn/platform-support/m68k-netbsd) | 🖥️ | ❌️ | ❔ | ✅ | ✅ | ❌ | ✅ | ❌️ |
| 4 | [`m88k-openbsd`](https://ziglang.org/learn/platform-support/m88k-openbsd) | 📄 | ❌️ | ❔ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 4 | [`microblaze[el]-linux`](https://ziglang.org/learn/platform-support/microblaze-linux) | 📄 | ❌️ | ❔ | ✅ | ❌️ | ❌ | ❌️ | ❌️ |
| 4 | [`or1k-linux`](https://ziglang.org/learn/platform-support/or1k-linux) | 📄 | ❌️ | ❔ | ✅ | ✅ | ❌ | ❌️ | ❌️ |
| 4 | [`sh[eb]-linux`](https://ziglang.org/learn/platform-support/sh-linux) | 📄 | ❌️ | ❔ | ✅ | ❌️ | ❌ | ❌️ | ❌️ |
| 4 | [`sh[eb]-netbsd`](https://ziglang.org/learn/platform-support/sh-netbsd) | 📄 | ❌️ | ❔ | ✅ | ❌️ | ❌ | ❌️ | ❌️ |
| 4 | [`sh-openbsd`](https://ziglang.org/learn/platform-support/sh-openbsd) | 📄 | ❌️ | ❔ | ✅ | ❌️ | ❌ | ❌️ | ❌️ |
| 4 | [`sparc-linux`](https://ziglang.org/learn/platform-support/sparc-linux) | 🖥️ | ❌️ | ❔ | ✅ | ✅ | ❌ | ✅ | ❌️ |
| 4 | [`sparc-netbsd`](https://ziglang.org/learn/platform-support/sparc-netbsd) | 🖥️ | ❌️ | ❔ | ✅ | ❌️ | ❌ | ✅ | ❌️ |
| 4 | [`sparc64-netbsd`](https://ziglang.org/learn/platform-support/sparc64-netbsd) | 🖥️🛠️ | ⚠️ | ✅ | ✅ | ❌️ | ✅ | ✅ | ❌️ |
| 4 | [`sparc64-openbsd`](https://ziglang.org/learn/platform-support/sparc64-openbsd) | 🖥️🛠️ | ⚠️ | ✅ | ✅ | ❌️ | ❌ | ✅ | ❌️ |
| 4 | [`xtensa[eb]-linux`](https://ziglang.org/learn/platform-support/xtensa-linux) | 🖥️ | ❌️ | ❔ | ✅ | ❌️ | ❌ | ❌️ | ❌️ |

### [OS Version Requirements](https://ziglang.org/download/0.17.0/release-notes.html#toc-OS-Version-Requirements) [§](https://ziglang.org/download/0.17.0/release-notes.html#OS-Version-Requirements)

The Zig standard library has minimum version requirements for some supported operating systems, which in turn affect the Zig compiler itself:

| OS | Version |
| --- | --- |
| Darwin | 15.0+ |
| DragonFly BSD | 6.4+ |
| FreeBSD | 14.0+ |
| Linux | 5.10+ |
| NetBSD | 10.1+ |
| OpenBSD | 7.8+ |
| Windows | 10+ |

### [Additional Platforms](https://ziglang.org/download/0.17.0/release-notes.html#toc-Additional-Platforms) [§](https://ziglang.org/download/0.17.0/release-notes.html#Additional-Platforms)

Zig also has varying levels of support for these targets, for which the tier system does not quite apply:

-   `aarch64-driverkit`
-   `aarch64[_be]-freestanding`
-   `aarch64-fuchsia`
-   `aarch64-hurd`
-   `aarch64-switch`
-   `aarch64-uefi`
-   `alpha-freestanding`
-   `amdgcn-amdhsa`
-   `amdgcn-amdpal`
-   `amdgcn-mesa3d`
-   `arc[eb]-freestanding`
-   `arm[eb]-freestanding`
-   `arm-3ds`
-   `arm-fuchsia`
-   `arm-gba`
-   `arm-uefi`
-   `arm-vita`
-   `avr-freestanding`
-   `bpf(eb,el)-freestanding`
-   `csky-freestanding`
-   `ez80-freestanding`
-   `ez80-tios`
-   `hexagon-freestanding`
-   `hppa[64]-freestanding`
-   `kalimba-freestanding`
-   `kvx-freestanding`
-   `lanai-freestanding`
-   `loongarch(32,64)-freestanding`
-   `loongarch(32,64)-uefi`
-   `m68k-freestanding`
-   `m88k-freestanding`
-   `microblaze[el]-freestanding`
-   `mips[64][el]-freestanding`
-   `mipsel-psx`
-   `mipsel-psp`
-   `msp430-freestanding`
-   `nvptx[64]-cuda`
-   `nvptx[64]-nvcl`
-   `or1k-freestanding`
-   `powerpc-wiiu`
-   `powerpc[64][le]-freestanding`
-   `powerpc64-ps3`
-   `propeller-freestanding`
-   `riscv(32,64)[be]-freestanding`
-   `riscv(32,64)-uefi`
-   `riscv64-fuchsia`
-   `riscv64-hurd`
-   `s390x-freestanding`
-   `sh[eb]-freestanding`
-   `sparc[64]-freestanding`
-   `spirv(32,64)-opencl`
-   `spirv(32,64)-opengl`
-   `spirv(32,64)-vulkan`
-   `spork8-freestanding`
-   `thumb[eb]-freestanding`
-   `thumb-fuchsia`
-   `thumb-gba`
-   `thumb-vita`
-   `ve-freestanding`
-   `wasm(32,64)-emscripten`
-   `wasm(32,64)-freestanding`
-   `x86[_16,_64]-freestanding`
-   `x86[_64]-hurd`
-   `x86[_64]-uefi`
-   `x86_64-driverkit`
-   `x86_64-fuchsia`
-   `x86_64-plan9`
-   `x86_64-ps4`
-   `x86_64-ps5`
-   `xcore-freestanding`
-   `xtensa[eb]-freestanding`

## [Language Changes](https://ziglang.org/download/0.17.0/release-notes.html#toc-Language-Changes) [§](https://ziglang.org/download/0.17.0/release-notes.html#Language-Changes)

### [Language Stability Progress](https://ziglang.org/download/0.17.0/release-notes.html#toc-Language-Stability-Progress) [§](https://ziglang.org/download/0.17.0/release-notes.html#Language-Stability-Progress)

Since the release of Zig 0.16.0, a lot of progress has been made towards stabilizing the language. This is a key step in our [roadmap](https://ziglang.org/download/0.17.0/release-notes.html#Roadmap), and a requirement before tagging Zig 1.0.

In particular, since the last release, we have discussed and made decisions on many language proposals—accepting around 25 and rejecting around 125. At the time of writing, 23 undecided language proposals remain open on the Codeberg issue tracker, and 61 undecided language proposals remain open on the legacy GitHub issue tracker. Therefore, this effort represents a significant step towards finalizing the language design (although [some](https://github.com/ziglang/zig/issues/1639) [major](https://github.com/ziglang/zig/issues/3806) [decisions](https://codeberg.org/ziglang/zig/issues/35197) [remain](https://github.com/ziglang/zig/issues/23446)).

### [`@bitCast` changes](https://ziglang.org/download/0.17.0/release-notes.html#toc-codebitCastcode-changes) [§](https://ziglang.org/download/0.17.0/release-notes.html#codebitCastcode-changes)

Zig 0.17.0 changes the definition of the `@bitCast` builtin.

In many cases, the new behavior is equivalent to the old: in particular, casting between an integer type and another integer type is unaffected, as is casting between an integer type and a `packed struct` or `packed union`.

However, the semantics of `@bitCast` calls involving array or vector types have changed. **Unfortunately, this change has the potential to break existing code without triggering a compile error.**. Therefore, it may be useful when upgrading to audit any `@bitCast` uses which involve array or vector types.

The new definition of `@bitCast` is that it reinterprets the _logical bit representation_ of a value as a different type. The following types are considered to have logical bit representations:

-   `void`
-   `bool`
-   integer types, except for `comptime_int`
-   floating-point types, except for `comptime_float`
-   integer-backed types `enum(T)`, `packed struct(T)`, and `packed union(T)`
-   arrays or vectors of any of these types

For integer and floating-point types, the logical bit representation starts with the least-significant bit and ends with the most-significant bit. For array and vector types, all elements' logical bit representations are concatenated in order starting with the first element.

In practice, this means that the new `@bitCast` definition largely aligns with the old behavior on little-endian targets. Unlike the old behavior, the new behavior is fully endian-agnostic, i.e. the operation behaves the same regardless of the target endian.

The new `@bitCast` definition disallows casts between some types which _were_ previously allowed. In particular, casts involving `extern struct` or `extern union` types are no longer permitted. In most cases, code which was using such casts is aiming to reinterpret the value's in-memory representation (sometimes called "type punning")—to achieve this, use `@ptrCast` or an `extern union`.

bitcast\_extern\_struct.zig

```
const TwoBytes = extern struct {
    b0: u8,
    b1: u8,
};
test "type pun extern struct" {
    const bytes: TwoBytes = .{ .b0 = 0x12, .b1 = 0xAB };
    const int: u16 = @bitCast(bytes);
    switch (std.lang.Endian.native) {
        .little => try expectEqual(0xAB_12, int),
        .big => try expectEqual(0x12_AB, int),
    }
}
const std = @import("std");
const expectEqual = std.testing.expectEqual;
```

Shell

$ zig test bitcast\_extern\_struct.zig
/home/ci/.cache/act/05230427828f0a88/hostexecutor/src/download/0.17.0/release-notes/bitcast\_extern\_struct.zig:7:31: error: cannot @bitCast from 'bitcast\_extern\_struct.TwoBytes'
    const int: u16 = @bitCast(bytes);
                              ^~~~~
/home/ci/.cache/act/05230427828f0a88/hostexecutor/src/download/0.17.0/release-notes/bitcast\_extern\_struct.zig:1:25: note: struct declared here
const TwoBytes = extern struct {
                 \~~~~~~~^~~~~~

⬇️

ptrcast\_extern\_struct.zig

```
const TwoBytes = extern struct {
    b0: u8,
    b1: u8,
};
test "type pun extern struct" {
    const bytes: TwoBytes = .{ .b0 = 0x12, .b1 = 0xAB };
    const int_ptr: *align(1) const u16 = @ptrCast(&bytes);
    switch (std.lang.Endian.native) {
        .little => try expectEqual(0xAB_12, int_ptr.*),
        .big => try expectEqual(0x12_AB, int_ptr.*),
    }
}
const std = @import("std");
const expectEqual = std.testing.expectEqual;
```

Shell

$ zig test ptrcast\_extern\_struct.zig
1/1 ptrcast\_extern\_struct.test.type pun extern struct...OK
All 1 tests passed.

### [Formally Specified and Fuzzed Grammar](https://ziglang.org/download/0.17.0/release-notes.html#toc-Formally-Specified-and-Fuzzed-Grammar) [§](https://ziglang.org/download/0.17.0/release-notes.html#Formally-Specified-and-Fuzzed-Grammar)

Zig's formal grammar.peg and the actual language implementation did not agree in many places. Probably, the formal grammar has never actually 100% matched the actual handwritten tokenizer and parser.

This problem is now fixed and unblocks future grammar changes and language specification work.

At a high level, the approach was to write a tool that accepts Zig's grammar.peg as input and outputs a simple recursive descent parser. This generated parser is then used as an oracle for fuzz testing and the handwritten `std.zig.Ast.parse()` is compared against it. This approach ensures a single source of truth and allows for easy iteration as the grammar changes.

More details: [#36094](https://codeberg.org/ziglang/zig/pulls/36094)

### [C Translation Moving to External Package](https://ziglang.org/download/0.17.0/release-notes.html#toc-C-Translation-Moving-to-External-Package) [§](https://ziglang.org/download/0.17.0/release-notes.html#C-Translation-Moving-to-External-Package)

[@cImport was deprecated in Zig 0.16.0](https://ziglang.org/download/0.16.0/release-notes.html#cImport-Moving-to-Build-System) and is now removed. Furthermore, in this release `std.Build.Step.TranslateC` is deprecated in favor of an explicit package dependency on [official ZSF translate-c package](https://codeberg.org/ziglang/translate-c), which is the same implementation the build step provides, but offers more [configuration options](https://codeberg.org/ziglang/translate-c#options) for the translated code, and has an independent release cadence from the main Zig toolchain.

Upgrade guide:

```
zig fetch --save git+https://codeberg.org/ziglang/translate-c
```

```
--- a/build.zig
+++ b/build.zig
@@ -1,20 +1,22 @@
 const std = @import("std");
+const Translator = @import("translate_c").Translator;
 
 pub fn build(b: *std.Build) void {
     const target = b.standardTargetOptions(.{});
     const optimize = b.standardOptimizeOption(.{});
 
-    const translate_c = b.addTranslateC(.{
-        .root_source_file = b.path("src/c.h"),
+    const translate_c = b.dependency("translate_c", .{});
+
+    const translator: Translator = .init(translate_c, .{
+        .c_source_file = b.path("src/c.h"),
         .target = target,
         .optimize = optimize,
+        .link_system_libs = &.{
+            .{ .name = "glfw" },
+            .{ .name = "epoxy" },
+        },
+ // additional options now available that go here:
+ // https://codeberg.org/ziglang/translate-c#options
     });
 
-    const c_module = translate_c.createModule();
-    c_module.linkSystemLibrary("glfw", .{});
-    c_module.linkSystemLibrary("epoxy", .{});
-
     const exe = b.addExecutable(.{
         .name = "tetris",
         .root_module = b.createModule(.{
@@ -24,7 +26,7 @@ pub fn build(b: *std.Build) void {
             .imports = &.{
                 .{
                     .name = "c",
-                    .module = c_module,
+                    .module = translator.mod,
                 },
             },
         }),
```

### [Added `@backingInt` and `@fromBackingInt`](https://ziglang.org/download/0.17.0/release-notes.html#toc-Added-codebackingIntcode-and-codefromBackingIntcode) [§](https://ziglang.org/download/0.17.0/release-notes.html#Added-codebackingIntcode-and-codefromBackingIntcode)

The `@backingInt` and `@fromBackingInt` builtins are new. These builtins replace the now-deprecated `@intFromEnum` and `@enumFromInt` builtins ([#35966](https://codeberg.org/ziglang/zig/pulls/35966)).

`@backingInt` works with all enums and with bitpacks with _explicit_ backing integer types only. It also works with tagged unions, returning the backing integer of the active tag value. An `undefined` enum or bitpack yields an `undefined` backing integer.

`@fromBackingInt` infers its result type, which may be any enum or a bitpack with an _explicit_ backing integer type. It takes a parameter of exactly that backing integer type. For enums, passing a backing integer that is either `undefined` or would yield an invalid tag value results in safety-checked Illegal Behavior. For bitpacks, passing an `undefined` backing integer yields an `undefined` bitpack.

`@bitCast` now also performs a safety check for invalid tag values if its destination type is an `enum`.

Also adds a `std.meta.BackingInt` function to get the result type of `@backingInt`.

Zig now requires empty enums to have `noreturn` as their backing integer because they are uninstantiable.

Upgrade example:

```
--- a/lib/std/Build.zig
+++ b/lib/std/Build.zig
@@ -145,7 +145,7 @@ pub const Graph = struct {
 
     pub fn addGeneratedFile(graph: *Graph, owner: *Step) Configuration.GeneratedFileIndex {
         graph.generated_files.append(graph.arena, owner) catch @panic("OOM");
-        return @enumFromInt(graph.generated_files.items.len - 1);
+        return @fromBackingInt(@intCast(graph.generated_files.items.len - 1));
     }
 
     pub fn dupeString(graph: *const Graph, bytes: []const u8) []const u8 {
@@ -2607,7 +2607,7 @@ pub const LazyPath = union(enum) {
             .src_path, .cwd_relative, .relative, .dependency => {},
             .generated => |gen| {
                 const graph = other_step.owner.graph;
-                const generated_owner_step = graph.generated_files.items[@intFromEnum(gen.index)];
+                const generated_owner_step = graph.generated_files.items[@backingInt(gen.index)];
                 other_step.dependOn(generated_owner_step);
             },
         }
```

[zig fmt](https://ziglang.org/download/0.17.0/release-notes.html#zig-fmt) automatically performs this upgrade.

### [Added `@SpirvType`](https://ziglang.org/download/0.17.0/release-notes.html#toc-Added-codeSpirvTypecode) [§](https://ziglang.org/download/0.17.0/release-notes.html#Added-codeSpirvTypecode)

SPIR-V has a number of types, such as images and samplers, that have no equivalent in Zig's type system. Previously, the only way to refer to one of them was through inline assembly, which made it impossible to declare a texture or a storage buffer as an ordinary global variable. Zig 0.17.0 implements accepted proposal [#35240](https://codeberg.org/ziglang/zig/issues/35240), adding the `@SpirvType` builtin alongside the other type-creating builtins:

sample\_code

```
@SpirvType(comptime options: std.lang.Type.Spirv) type
```

-   `.sampler` creates an `OpTypeSampler`.
-   `.image` creates an `OpTypeImage`.
-   `.sampled_image` creates an `OpTypeSampledImage` from an image type whose usage is `.sampled`.
-   `.runtime_array` creates an `OpTypeRuntimeArray`. It supports indexing and exposes a `len` field just like the array type.

Using this builtin when not targeting SPIR-V is a compile error. The options are also validated against the target OS.

spirv\_type.zig

```
const std = @import("std");

const Image = @SpirvType(.{ .image = .{
    .usage = .{ .sampled = f32 },
    .format = .unknown,
    .dim = .@"2d",
    .depth = .not_depth,
    .arrayed = false,
    .multisampled = false,
    .access = .unknown,
} });
const SampledImage = @SpirvType(.{ .sampled_image = Image });

const texture = @extern(*addrspace(.constant) const SampledImage, .{
    .name = "texture",
    .decoration = .{ .descriptor = .{ .set = 0, .binding = 0 } },
});
const uv_in = @extern(*addrspace(.input) const @Vector(2, f32), .{
    .name = "uv",
    .decoration = .{ .location = 0 },
});
const color_out = @extern(*addrspace(.output) @Vector(4, f32), .{
    .name = "color",
    .decoration = .{ .location = 0 },
});

export fn main() callconv(.{ .spirv_fragment = .{} }) void {
    color_out.* = std.spirv.imageSampleImplicitLod(texture, uv_in.*);
}
```

Shell

$ zig build-obj spirv\_type.zig -target spirv32-vulkan

### [Array Multiplication Syntax Removed](https://ziglang.org/download/0.17.0/release-notes.html#toc-Array-Multiplication-Syntax-Removed) [§](https://ziglang.org/download/0.17.0/release-notes.html#Array-Multiplication-Syntax-Removed)

Array multiplication syntax (`a ** b`) has been removed in favor of `@splat`.

Migration:

```
--- a/player/chromaprint.zig
+++ b/player/chromaprint.zig
@@ -35,7 +35,7 @@ pub const Chroma = struct {
     const max_index = @min(window_size / 2, freqToIndex(max_freq));
     const notes: [window_size]u8 = n: {
         @setEvalBranchQuota(window_size);
-        var result = [1]u8{0} ** window_size;
+        var result: [window_size]u8 = @splat(0);
         for (min_index..max_index) |i| {
             const freq = indexToFreq(i);
             const octave = freqToOctave(freq);
@@ -123,7 +123,7 @@ const RollingIntegralImage = struct {
     num_rows: u32,
 
     pub const init: RollingIntegralImage = .{
-        .data = [1]Float{0} ** data_size,
+        .data = @splat(0),
         .num_rows = 0,
     };
```

### [Added `@divCeil`](https://ziglang.org/download/0.17.0/release-notes.html#toc-Added-codedivCeilcode) [§](https://ziglang.org/download/0.17.0/release-notes.html#Added-codedivCeilcode)

The new `@divCeil` builtin performs integer division rounded toward positive infinity, complementing the existing `@divTrunc`, `@divFloor`, and `@divExact` builtins.

sample\_code

```
@divCeil(5, 3) == 2
@divCeil(-5, 3) == -1
```

As with the other division builtins, caller guarantees that `denominator != 0` and that result does not overflow.

No more `std.math.divCeil(a, b) catch unreachable`!

### [`@hasDecl` Returns `true` Only for Public Declarations](https://ziglang.org/download/0.17.0/release-notes.html#toc-codehasDeclcode-Returns-codetruecode-Only-for-Public-Declarations) [§](https://ziglang.org/download/0.17.0/release-notes.html#codehasDeclcode-Returns-codetruecode-Only-for-Public-Declarations)

Previously, `@hasDecl` returned `true` for public declarations and declarations in the same file. Now, the behavior is the same independently of which file `@hasDecl` is in.

hasdecl.zig

```
const std = @import("std");

const Foo = struct {
    bar: i32,

    const baz = 1;
    pub var quux = "xxx";
};

test "@hasDecl example" {
    try std.testing.expect(!@hasDecl(Foo, "bar"));
    try std.testing.expect(!@hasDecl(Foo, "baz")); // different in 0.17.0
    try std.testing.expect(@hasDecl(Foo, "quux"));
}
```

Shell

$ zig test hasdecl.zig
1/1 hasdecl.test.@hasDecl example...OK
All 1 tests passed.

### [Allow Dereference and Coercion to Array Pointer of `comptime` Length Slices](https://ziglang.org/download/0.17.0/release-notes.html#toc-Allow-Dereference-and-Coercion-to-Array-Pointer-of-codecomptimecode-Length-Slices) [§](https://ziglang.org/download/0.17.0/release-notes.html#Allow-Dereference-and-Coercion-to-Array-Pointer-of-codecomptimecode-Length-Slices)

Now allowed:

sample\_code

```
const slice: []const u16 = &.{ 1, 2, 3 };
const array: [3]u16 = slice.*;
const array_ptr: *const [3]u16 = slice;
```

### [`void{}` Syntax Removed](https://ziglang.org/download/0.17.0/release-notes.html#toc-codevoidcode-Syntax-Removed) [§](https://ziglang.org/download/0.17.0/release-notes.html#codevoidcode-Syntax-Removed)

`void{}` is no longer valid syntax. Use `{}` instead ([#15213](https://github.com/ziglang/zig/issues/15213)).

### [`errdefer` Capture Removed](https://ziglang.org/download/0.17.0/release-notes.html#toc-codeerrdefercode-Capture-Removed) [§](https://ziglang.org/download/0.17.0/release-notes.html#codeerrdefercode-Capture-Removed)

sample\_code

```
errdefer |err| {
    // `err` was the error being returned; you could do stuff with it!
    // Like a normal `defer/`errdefer`, you can't `return` or `try` in this block, so you can't change
    // which error is returned; but you can e.g. log it
}
```

The capture (`|err|`) is no longer allowed ([#23734](https://github.com/ziglang/zig/issues/23734)).

To migrate, split the function into two:

```
fn processOneTarget(job: Job) void {
-    errdefer |err| std.debug.panic("panic: {s}", .{@errorName(err)});
+    processOneTargetInner(job) catch |err| std.debug.panic("panic: {s}", .{@errorName(err)});
+}
+fn processOneTargetInner(job: Job) !void {
     const target = job.target;
```

### [`i0` Removed](https://ziglang.org/download/0.17.0/release-notes.html#toc-codei0code-Removed) [§](https://ziglang.org/download/0.17.0/release-notes.html#codei0code-Removed)

`i0` is no longer an allowed primitive integer type.

This type was nonsensical, so does not have a direct alternative. However, any uses of it can almost certainly be transparently replaced with `u0`.

### [`internal` and `link_once` Global Linkage Removed](https://ziglang.org/download/0.17.0/release-notes.html#toc-codeinternalcode-and-codelink_oncecode-Global-Linkage-Removed) [§](https://ziglang.org/download/0.17.0/release-notes.html#codeinternalcode-and-codelink_oncecode-Global-Linkage-Removed)

The `internal` and `link_once` tags of `std.lang.GlobalLinkage` have been removed as they had unclear semantics and incomplete support in codegen and linking ([#36956](https://codeberg.org/ziglang/zig/pulls/36956)). Any use of `link_once` is likely served by `weak`, while the replacement for `internal` is to simply not `@export` the symbol in the first place.

## [Standard Library](https://ziglang.org/download/0.17.0/release-notes.html#toc-Standard-Library) [§](https://ziglang.org/download/0.17.0/release-notes.html#Standard-Library)

-   Added `f128` support for `@exp` and `@exp2` based on "Table-Driven Implementation of the Exponential Function in IEEE Floating-Point Arithmetic" by Ping Tak Peter Tang, adapted to work with 128-bit numbers ([#31846](https://codeberg.org/ziglang/zig/pulls/31846)).
-   Added `std.Io.Semaphore.waitTimeout` ([#31924](https://codeberg.org/ziglang/zig/pulls/31924)).
-   Added `std.spirv` helpers for sampling, querying, and writing images ([#36187](https://codeberg.org/ziglang/zig/pulls/36187)).
-   `ArrayHashMap.setKey` no longer recomputes the entire index ([#32136](https://codeberg.org/ziglang/zig/pulls/32136)).
-   `std.Target.parseCpuModel` now returns optional rather than error.
-   `std.debug.Pdb`: deduplicate inline source locations ([#35438](https://codeberg.org/ziglang/zig/pulls/35438)).
-   `hash.crc` full namespace audit ([#35952](https://codeberg.org/ziglang/zig/pulls/35952)).
-   `std.fs.path` add appending variants for `relative` and `resolve` ([#36784](https://codeberg.org/ziglang/zig/pulls/36784)).

### [Deprecations](https://ziglang.org/download/0.17.0/release-notes.html#toc-Deprecations) [§](https://ziglang.org/download/0.17.0/release-notes.html#Deprecations)

-   `std.heap.memory_pool.AlignedManaged` removed in favor of `std.heap.memory_pool.Aligned`.
-   `std.heap.memory_pool.ExtraManaged` removed in favor of `std.heap.memory_pool.Extra`.
-   Deprecated `std.builtin` in favor of `std.lang`.
-   Deprecated `std.meta.fieldInfo` in favor of `@typeInfo`.
-   Deprecated `std.meta.fieldNames` in favor of `@typeInfo`.
-   Deprecated `std.meta.fieldTypes` in favor of `@typeInfo`.
-   Deprecated `std.DoublyLinkedList.pop` in favor of `std.DoublyLinkedList.popLast`.
-   Renamed `std.gpu` to `std.spirv`.
-   Removed `std.ascii.indexOfIgnoreCase` in favor of `std.ascii.findIgnoreCase`.
-   Removed `std.ascii.indexOfIgnoreCasePos` in favor of `std.ascii.findIgnoreCasePos`.
-   Removed `std.ascii.indexOfIgnoreCasePosLinear` in favor of `std.ascii.findIgnoreCasePosLinear`.
-   Removed `std.bit_set.Integer.initEmpty` in favor of `std.bit_set.Integer.empty`.
-   Removed `std.bit_set.Integer.initFull` in favor of `std.bit_set.Integer.full`.
-   Removed `std.bit_set.Array.initEmpty` in favor of `std.bit_set.Array.empty`.
-   Removed `std.bit_set.Array.initFull` in favor of `std.bit_set.Array.full`.
-   Removed `std.enums.EnumSet.initEmpty` in favor of `std.enums.EnumSet.empty`.
-   Removed `std.enums.EnumSet.initFull` in favor of `std.enums.EnumSet.full`.
-   Renamed `std.mem.containsAtLeastScalar2` to `std.mem.containsAtLeastScalar`, replacing the deprecated `containsAtLeastScalar`.
-   Removed `std.mem.readPackedIntNative` in favor of `std.mem.readPackedInt`.
-   Removed `std.mem.readPackedIntForeign` in favor of `std.mem.readPackedInt`.
-   Removed `std.mem.writePackedIntNative` in favor of `std.mem.writePackedInt`.
-   Removed `std.mem.writePackedIntForeign` in favor of `std.mem.writePackedInt`.

#### [Potential `containsAtLeastScalar` Footgun](https://ziglang.org/download/0.17.0/release-notes.html#toc-Potential-codecontainsAtLeastScalarcode-Footgun) [§](https://ziglang.org/download/0.17.0/release-notes.html#Potential-codecontainsAtLeastScalarcode-Footgun)

The previously deprecated `containsAtLeastScalar` has been replaced with `containsAtLeastScalar2`, which has a similar enough API that usage sites may still compile but now be incorrect since the `element` and `minimum` parameters have swapped places.

Migration guide:

sample\_code

```
const result = containsAtLeastScalar(u8, "aa", 1, 'a');
```

⬇️

sample\_code

```
const result = containsAtLeastScalar(u8, "aa", 'a', 1);
```

### [StackFallbackAllocator Reworked and Renamed](https://ziglang.org/download/0.17.0/release-notes.html#toc-StackFallbackAllocator-Reworked-and-Renamed) [§](https://ziglang.org/download/0.17.0/release-notes.html#StackFallbackAllocator-Reworked-and-Renamed)

`std.heap.StackFallbackAllocator` is an abstraction that is useful for the "small vec" optimization, in which common cases can fit on a pre-allocated stack buffer, but rare cases need dynamic heap allocation. The previous design had a few problems:

-   There was no way to specify the alignment of the buffer.
-   It was generic over the size of the buffer.
-   Calling `.allocator().get()` mutated the type, unlike all other allocators, [requiring a runtime safety check](https://github.com/ziglang/zig/issues/16344).

Now, the buffer is provided as an argument, like most other std APIs that need a buffer.

Consequently, `StackFallbackAllocator` has been renamed to `BufferFirstAllocator`, and `std.heap.stackFallback` has been removed.

Migration guide:

sample\_code

```
var stack align(@max(
    @alignOf(std.heap.StackFallbackAllocator(0)),
    @alignOf(Item)),
) = std.heap.stackFallback(@sizeOf(Item), self.gpa);
const allocator = stack.get();
```

⬇️

sample\_code

```
var stack_buf: [1]Item = undefined;
var stack: std.heap.BufferFirstAllocator = .init(@ptrCast(&stack_buf), gpa);
const allocator = stack.allocator();
```

### [SafeAllocator Introduced](https://ziglang.org/download/0.17.0/release-notes.html#toc-SafeAllocator-Introduced) [§](https://ziglang.org/download/0.17.0/release-notes.html#SafeAllocator-Introduced)

`std.heap.DebugAllocator` is replaced by a thread-safe allocator with the following guarantees:

-   `deinit` reports all leaks and frees all backing memory.
-   All allocation mismatches result in either a panic or segmentation fault.
-   Allocations from other `SafeAllocator` instances cause a panic (if `Options.canary` differ).
-   Double frees and operation (resize, remap, and free) races panic or segmentation fault.

Given the backing allocator does not reuse memory, it does not reuse memory either and most writes after free will segmentation fault or are eventually detected and panic.

`std.heap.DebugAllocator` and `std.heap.Check` are deprecated.

Every allocation is trailed by an `AllocFooter` which contains metadata for the allocation and stack traces. It is protected by a checksum to catch corruption from allocation overwrites and report canary mismatches. An allocation's memory has a minimum alignment of `AllocFooter` so that the footer is at a fixed offset determined from the allocation size. An allocation's memory is stored either:

-   Inside linearly-filled buckets for small allocations.
-   Inside an allocation directly from the backing allocator.

To track allocations, each thread maintains a table of backing allocations. The table may be modified by other threads in the case of a producer-consumer operation, so the table is a linked list only expanded by creating new segments. Each thread maintains a linked list of free entries, which may contain entries from other threads' tables.

In the case of producer-consumer operations, acquire/release ordering is assumed to be provided externally. This is also assumed by all other thread-safe allocators that reuse memory as otherwise there would be data races on reuse of allocated memory.

Two fuzz tests have also been added for the allocator. They check that there is no memory reuse, that returned memory is writable, and that it is not overwritten. The multi-threaded fuzz test spawns a number of worker threads which are used for all the test runs. I have run these tests extensively under TSAN.

Building the standard library tests with an `-Osafe` compiler build and `-Ddebug-allocator`:

```
Benchmark 1 (3 runs): ./master-out/bin/zig test --zig-lib-dir lib lib/std/std.zig -femit-bin=test --test-no-exec
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          29.4s  ±  157ms    29.2s  … 29.5s           0 ( 0%)        0%
  peak_rss           2.24GB ± 3.49MB    2.23GB … 2.24GB          0 ( 0%)        0%
  cpu_cycles          143G  ±  999M      142G  …  144G           0 ( 0%)        0%
  instructions        268G  ± 5.22M      268G  …  268G           0 ( 0%)        0%
  cache_references   13.1G  ± 88.8M     13.0G  … 13.2G           0 ( 0%)        0%
  cache_misses       2.38G  ± 30.7M     2.35G  … 2.41G           0 ( 0%)        0%
  branch_misses       634M  ± 6.22M      629M  …  641M           0 ( 0%)        0%
Benchmark 2 (3 runs): ./branch-out/bin/zig test --zig-lib-dir lib lib/std/std.zig -femit-bin=test --test-no-exec
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          22.1s  ± 88.6ms    22.0s  … 22.2s           0 ( 0%)        ⚡- 24.7% ±  1.0%
  peak_rss           1.11GB ±  799KB    1.11GB … 1.11GB          0 ( 0%)        ⚡- 50.3% ±  0.3%
  cpu_cycles          136G  ±  480M      136G  …  137G           0 ( 0%)        ⚡-  4.4% ±  1.2%
  instructions        273G  ± 2.07M      273G  …  273G           0 ( 0%)        💩+  1.6% ±  0.0%
  cache_references   12.3G  ± 71.3M     12.2G  … 12.4G           0 ( 0%)        ⚡-  6.0% ±  1.4%
  cache_misses       2.02G  ± 11.5M     2.01G  … 2.03G           0 ( 0%)        ⚡- 14.9% ±  2.2%
  branch_misses       569M  ± 2.65M      567M  …  572M           0 ( 0%)        ⚡- 10.2% ±  1.7%
```

### [ArrayList](https://ziglang.org/download/0.17.0/release-notes.html#toc-ArrayList) [§](https://ziglang.org/download/0.17.0/release-notes.html#ArrayList)

-   `getLastOrNull` has been deprecated and renamed to `last`
-   `getLast` has been deprecated in favor of `last` combined with `.?`
-   `lastPtr` has been added which returns `?*T`

Upgrade guide:

sample\_code

```
if (list.getLastOrNull()) |foo| {
    // ...
}
const foo = list.getLast();
```

⬇️

sample\_code

```
if (list.last()) |foo| {
    // ...
}
const foo = list.last().?;
```

#### [ArrayList Pointer Stability](https://ziglang.org/download/0.17.0/release-notes.html#toc-ArrayList-Pointer-Stability) [§](https://ziglang.org/download/0.17.0/release-notes.html#ArrayList-Pointer-Stability)

This is an enhancement that can help track down ArrayList usage bugs faster ([#36239](https://codeberg.org/ziglang/zig/pulls/36239)).

[Devlog Entry](https://ziglang.org/devlog/2026/#2026-08-27)

### [`debug.SafetyLock` Gains Support for Shared Locking](https://ziglang.org/download/0.17.0/release-notes.html#toc-codedebugSafetyLockcode-Gains-Support-for-Shared-Locking) [§](https://ziglang.org/download/0.17.0/release-notes.html#codedebugSafetyLockcode-Gains-Support-for-Shared-Locking)

The existing `lock` and `unlock` methods continue to act exclusively. They should be used when data may be mutated. New methods, `lockShared` and `unlockShared`, may be used for shared locking in situations where multiple independent users are reading but not mutating data.

### [`fmt.allocPrint` moved to `mem.Allocator`](https://ziglang.org/download/0.17.0/release-notes.html#toc-codefmtallocPrintcode-moved-to-codememAllocatorcode) [§](https://ziglang.org/download/0.17.0/release-notes.html#codefmtallocPrintcode-moved-to-codememAllocatorcode)

sample\_code

```
try std.fmt.allocPrint(arena, "{s}={d}", .{ x, y });
```

⬇️

sample\_code

```
try arena.print("{s}={d}", .{ x, y });
```

### [Formatted Printing Enhancements](https://ziglang.org/download/0.17.0/release-notes.html#toc-Formatted-Printing-Enhancements) [§](https://ziglang.org/download/0.17.0/release-notes.html#Formatted-Printing-Enhancements)

The `"{q}"` specifier which escapes strings so that they can appear in double-quoted string literals has relaxed escaping rules such that UTF-8 encoded data can pass through unmangled.

`"{qf}"` is introduced for double-quote escaping the output of a `format()`.

### [`std.zon.parse` Reworked](https://ziglang.org/download/0.17.0/release-notes.html#toc-codestdzonparsecode-Reworked) [§](https://ziglang.org/download/0.17.0/release-notes.html#codestdzonparsecode-Reworked)

`std.zon.parse` now takes struct args and allocates both its results and diagnostics from an arena.

Migration guide:

sample\_code

```
var diag: std.zon.parse.Diagnostics = .{};
defer diag.deinit(gpa);
const result = std.zon.parse.fromSlice(
    MyZonType,
    gpa,
    source,
    &diag,
    .{},
) catch |err| switch (err) {
    error.ParseZon => std.process.fatal("input.zon: {f}", .{diag}),
    error.OutOfMemory => |e| return e,
};
defer std.zon.parse.free(result);
```

⬇️

sample\_code

```
var diag: std.zon.parse.Diagnostics = undefined;
const result = std.zon.parse.fromSlice(MyZonType, .{
    .gpa = gpa,
    .arena = arena,
    .source = source,
    .diagnostics = &diag,
}) catch |err| switch (err) {
    error.ParseZon => diag.fatal("input.zon"),
    error.OutOfMemory => |e| return e,
}
```

Some methods were renamed:

-   `fromSliceAlloc` ➡️ `fromSlice`
-   `fromSlice` ➡️ `fromSliceNoAlloc`
-   The other "from" methods were renamed following this same scheme.

"updateFrom" variants such as `updateFromSlice` were added. These update an in memory value, overwriting the value's fields with fields specified in the ZON source. This can be useful when using ZON to load configuration files with varying precedence, for example a text editor that has a global config file and a per-project config file.

### [Rename `bit_set` Variants and Deprecate the Managed One](https://ziglang.org/download/0.17.0/release-notes.html#toc-Rename-codebit_setcode-Variants-and-Deprecate-the-Managed-One) [§](https://ziglang.org/download/0.17.0/release-notes.html#Rename-codebit_setcode-Variants-and-Deprecate-the-Managed-One)

Renames the types for consistency, deprecating the previous names and the managed variant.

-   `std.bit_set.IntegerBitSet` ➡️ `std.bit_set.Integer`
-   `std.bit_set.ArrayBitSet` ➡️ `std.bit_set.Array`
-   `std.StaticBitset`, `std.bit_set.StaticBitSet` ➡️ `std.bit_set.Static`
-   `std.DynamicBitSetUnmanaged`, `std.bit_set.DynamicBitSetUnmanaged` ➡️ `std.bit_set.Dynamic`
-   `std.DynamicBitSet`, `std.bit_set.DynamicBitSet` ➡️ `std.bit_set.DynamicManaged` (deprecated)

### [Struct-Of-Arrays Style for `std.lang.Type`](https://ziglang.org/download/0.17.0/release-notes.html#toc-Struct-Of-Arrays-Style-for-codestdlangTypecode) [§](https://ziglang.org/download/0.17.0/release-notes.html#Struct-Of-Arrays-Style-for-codestdlangTypecode)

When doing type reflection, structs and unions return their information in struct-of-arrays style [(#35234)](https://codeberg.org/ziglang/zig/pulls/35234).

```
--- a/lib/compiler/Maker/ScannedConfig.zig
+++ b/lib/compiler/Maker/ScannedConfig.zig
@@ -49,9 +49,10 @@ pub fn print(sc: *const ScannedConfig, w: *Writer) Writer.Error!void {
 }
 
 fn printStruct(sc: *const ScannedConfig, s: *Serializer.Struct, comptime S: type, v: S) !void {
-    inline for (@typeInfo(S).@"struct".fields) |field| {
-        try s.fieldPrefix(field.name);
-        try printValue(sc, s.container.serializer, field.type, @field(v, field.name));
+    const info = @typeInfo(S).@"struct";
+    inline for (info.field_names, info.field_types) |field_name, field_type| {
+        try s.fieldPrefix(field_name);
+        try printValue(sc, s.container.serializer, field_type, @field(v, field_name));
     }
 }
```

### [Rename `lang.OptimizeMode` to `lang.Optimize`](https://ziglang.org/download/0.17.0/release-notes.html#toc-Rename-codelangOptimizeModecode-to-codelangOptimizecode) [§](https://ziglang.org/download/0.17.0/release-notes.html#Rename-codelangOptimizeModecode-to-codelangOptimizecode)

And remove "release" from the enum tag names.

No functional change, however, despite the addition of backwards-compatibile declarations in this patch, it is breaking because expressions that use `==` or `!=` operators will not able to use the deprecated names.

-   `std.lang`: `OptimizeMode` ➡️ `Optimize`
    -   `Debug` ➡️- `debug`
    -   `ReleaseSafe` ➡️- `safe`
    -   `ReleaseFast` ➡️- `fast`
    -   `ReleaseSmall` ➡️- `small`

### [`lang.Optimize.runtimeSafety`](https://ziglang.org/download/0.17.0/release-notes.html#toc-codelangOptimizeruntimeSafetycode) [§](https://ziglang.org/download/0.17.0/release-notes.html#codelangOptimizeruntimeSafetycode)

`std.lang.Optimize.runtimeSafety` is preferred as an alternative to `std.debug.runtime_safety` since it will offer callsites knowledge about their own module rather than standard library module.

### [@import("builtin") Deprecations](https://ziglang.org/download/0.17.0/release-notes.html#toc-importbuiltin-Deprecations) [§](https://ziglang.org/download/0.17.0/release-notes.html#importbuiltin-Deprecations)

The redundant constants `cpu`, `os`, `abi`, and `object_format` in `@import("builtin")` have been deprecated and will be removed in 0.18.0. Please replace any usage with the corresponding fields on the `target` constant:

-   `@import("builtin").cpu` ➡️ `@import("builtin").target.cpu`
-   `@import("builtin").os` ➡️ `@import("builtin").target.os`
-   `@import("builtin").abi` ➡️ `@import("builtin").target.abi`
-   `@import("builtin").object_format` ➡️ `@import("builtin").target.ofmt`

### [Handle Floats Correctly in `mem.eql` and `mem.findDiff`](https://ziglang.org/download/0.17.0/release-notes.html#toc-Handle-Floats-Correctly-in-codememeqlcode-and-codememfindDiffcode) [§](https://ziglang.org/download/0.17.0/release-notes.html#Handle-Floats-Correctly-in-codememeqlcode-and-codememfindDiffcode)

The functions `std.mem.eql` and `std.mem.findDiff` short-circuit when their two inputs are slices to the same memory. This short-circuiting is only correct when the `==` operator, for the given type, is reflexive. This isn't the case for floats, as for example `std.math.nan(f64) != std.math.nan(f64)`. The change in this PR disables that optimisation when working on float slices.

Previously-failing, now-succeeding tests:

sample\_code

```
const x: [3]f64 = .{ 42.0, std.math.nan(f64), 3.1415 };
try std.testing.expect(!std.mem.eql(f64, &x, &x));
try std.testing.expectEqual(1, std.mem.findDiff(f64, &x, &x));
```

### [Decouple `Uri` and `net.HostName`](https://ziglang.org/download/0.17.0/release-notes.html#toc-Decouple-codeUricode-and-codenetHostNamecode) [§](https://ziglang.org/download/0.17.0/release-notes.html#Decouple-codeUricode-and-codenetHostNamecode)

Uri was sometimes using HostName.validate for `host` (in resolveInPlace) and sometimes not (in parseAfterScheme). On its own, this was a problem, but the bigger problem is that RFC3986 (Uri) has a much different idea of what a valid host name is than RFC1123 (HostName), and so just making Uri consistently use HostName.validate would make Uri less useful overall.

Instead, all `HostName`\-related stuff has been removed from `Uri`. `Uri.getHost` has been moved to `HostName.fromUri` (without a graceful deprecation, since the semantics are different enough for users to need to evaluate usage sites), while `Uri.getHostAlloc` has been removed entirely.

Migration guide:

sample\_code

```
var host_buf: [HostName.max_len]u8 = undefined;
const host = try uri.getHost(&host_buf);
```

⬇️

sample\_code

```
var host_buf: [HostName.max_len]u8 = undefined;
// note: the error set is different than it was before since fromUri does validation
const host = try HostName.fromUri(uri, &host_buf);
```

[#36036](https://codeberg.org/ziglang/zig/pulls/36036)

## [Build System](https://ziglang.org/download/0.17.0/release-notes.html#toc-Build-System) [§](https://ziglang.org/download/0.17.0/release-notes.html#Build-System)

-   `b.build_root` (Directory) ➡️ `b.root` (Path)
-   `ConfigHeader.Options`: `include_guard_override` ➡️ `include_guard`
-   `LazyPath`: `getDisplayName` ➡️ `format` (`"{f}"`)
-   `LazyPath.basename`: removed since the value is not known until make phase
-   `b.findProgram` divided into `findProgram` and `findProgramLazy` and API future-proofed.
-   `ConfigHeader` fixed; now reports unused values for all styles
-   `addArtifactArg`, `addPrefixedArtifactArg` ➡️ `addArtifactArg2`
-   `addOutputFileArg`, `addPrefixedOutputFileArg` ➡️ `addOutputFileArg2`
-   `addFileContentArg`, `addPrefixedFileContentArg` ➡️ `addFileContentArg2`
-   `addOutputDirectoryArg`, `addPrefixedOutputDirectoryArg` ➡️ `addOutputDirectoryArg2`
-   `addDirectoryArg`, `addPrefixedDirectoryArg`, `addDecoratedDirectoryArg` ➡️ `addDirectoryArg2`
-   `addDepFileOutputArg`, `addPrefixedDepFileOutputArg` ➡️ `addDepFileOutputArg2`
-   `addFileArg`, `addPrefixedFileArg` ➡️ `addFileArg2`

### [Separate the Maker Process from the Configurer Process](https://ziglang.org/download/0.17.0/release-notes.html#toc-Separate-the-Maker-Process-from-the-Configurer-Process) [§](https://ziglang.org/download/0.17.0/release-notes.html#Separate-the-Maker-Process-from-the-Configurer-Process)

`zig build` now runs projects' `build.zig` code in a separate executable than the one that performs [Package Management](https://ziglang.org/download/0.17.0/release-notes.html#Package-Management) and executes the build graph, making `zig build` faster for several reasons ([#35428](https://codeberg.org/ziglang/zig/pulls/35428)):

-   The `maker` executable remains unmodified when `build.zig` script is edited, and therefore only needs to be built exactly once ("first time setup") after installing Zig.
-   The `maker` executable is built with optimizations enabled, which is starting to become more valuable now that we have introduced `--watch` and `--fuzz`.
-   `build.zig` logic can be skipped sometimes depending on what CLI flags are used with `zig build`.

Furthermore, configuration is now serialized into a compact binary format that can be consumed by third party tooling and is part of the new [Build Server Protocol](https://ziglang.org/download/0.17.0/release-notes.html#Build-Server-Protocol). The prior way of satisfying this use case by forking the build runner is [no longer supported](https://ziglang.org/download/0.17.0/release-notes.html#Removed-Ability-to-Override-Build-Runner).

To render configuration as .zon to stdout, pass `--print-configuration`.

### [Cache System Reworked](https://ziglang.org/download/0.17.0/release-notes.html#toc-Cache-System-Reworked) [§](https://ziglang.org/download/0.17.0/release-notes.html#Cache-System-Reworked)

New features:

-   Directory support. Ability for entries added, removed, or renamed in directories to cause a cache miss.
-   Metadata mode. Normally, only changed contents causes a cache miss. In metadata mode, when size, inode, or mtime changes, it always causes a cache miss independent of contents.

All four combinations are possible (is\_directory=true/false, metadata\_mode=true/false). These features are exposed as new API in the [Build System](https://ziglang.org/download/0.17.0/release-notes.html#Build-System).

Since the Zig toolchain is heavily reliant on the caching system, this release also switches to a binary format, saving roughly 25% on file size, which eases a bit of pressure on the file system cache while also simplifying the work the computer needs to do - directly copy bytes from disk rather than parsing text files. The new `zig cache-cat` subcommand is available for troubleshooting or tinkering with files inside a zig-cache directory.

The cache system also now has the capability to explain why a "miss" happened. The public-facing API of `std.Build.Cache` has many breaking changes, but outside of compiler tooling, this is an uncommon API to be used, and all the changes make it harder to misuse.

This change has been observed to speed up cache hits by 5-10% ([#36822](https://codeberg.org/ziglang/zig/pulls/36832)).

### [Introduce the Concept of Configure Cache Poisoning](https://ziglang.org/download/0.17.0/release-notes.html#toc-Introduce-the-Concept-of-Configure-Cache-Poisoning) [§](https://ziglang.org/download/0.17.0/release-notes.html#Introduce-the-Concept-of-Configure-Cache-Poisoning)

If the cache is poisoned means that the **configure logic** had side effects, or otherwise did something that could not be tracked by the cache system.

This is not to be confused with whether individual steps may have side effects when being evaluated; it has to do with the logic inside build.zig itself. For example, a `Run` step that prints "hello world" has side effects _at make time_ and therefore does not warrant setting this flag, while checking for the existence of `scdoc` _at configure time_ in order to choose the default value for a configuration option does.

Keeping the cache pure will make `zig build` faster, bypassing the configurer process when identical configuration would be generated.

When the cache is poisoned, the maker process will delete the build configuration file upon ingesting it since it cannot be reused.

Ways to poison the cache include calling [findProgram](https://ziglang.org/download/0.17.0/release-notes.html#findProgram), or more directly `std.Build.Graph.poisonCache`. A better alternative than cache poisoning is to explicitly declare the configuration dependencies with these new functions:

-   `std.Build.dependOnFileContents` - indicates that the build.zig logic depends on a particular file's contents.
-   `std.Build.dependOnFileMetadata` - indicates that the build.zig logic depends on a particular file's size, inode, mtime, and contents.
-   `std.Build.dependOnDirectoryContents` - indicates that the build.zig logic depends on a particular directory's entries.
-   `std.Build.dependOnDirectoryMetadata` - indicates that the build.zig logic depends on a particular directory's last modification date.

Advanced users can override the cache poisoning behavior with a new CLI option:

```
  --cache-poison[=mode]        Override configuration caching behavior
      pure                     (default) Avoid false positive cache hits
      poisoned                 Don't cache the configuration
      disallowed               Panics when cache would be poisoned
      ignored                  A little poison never hurt anybody
```

### [findProgram](https://ziglang.org/download/0.17.0/release-notes.html#toc-findProgram) [§](https://ziglang.org/download/0.17.0/release-notes.html#findProgram)

Immediately (in the configure phase), searches for an executable on the host that has more than one possible name.

Names are searched in order, observing search prefixes first and then PATH environment variable.

Calling this function poisons the configuration cache, so it is only appropriate when the existence of the program or its output needs to be observed by configuration logic. That's why there is also [findProgramLazy](https://ziglang.org/download/0.17.0/release-notes.html#findProgramLazy) now.

### [findProgramLazy](https://ziglang.org/download/0.17.0/release-notes.html#toc-findProgramLazy) [§](https://ziglang.org/download/0.17.0/release-notes.html#findProgramLazy)

Creates an anonymous `Step` that searches for an executable on the host that has more than one possible name.

Unlike [findProgram](https://ziglang.org/download/0.17.0/release-notes.html#findProgram), this function does not [poison the configuration cache](https://ziglang.org/download/0.17.0/release-notes.html#Introduce-the-Concept-of-Configure-Cache-Poisoning), however the result cannot be used in the configuration phase, hence the return type being `LazyPath`.

Returns the `LazyPath` of the found executable. The search only takes place if the `LazyPath` will be used by a depending `Step`.

This API is useful in the following cases:

-   The binary is not named the same across all systems (for example "python" vs "python3").
-   The binary may be produced by building from source rather than being globally installed and will therefore be possibly found in one of the search prefix paths.

### [Run Step: Passthru Args](https://ziglang.org/download/0.17.0/release-notes.html#toc-Run-Step-Passthru-Args) [§](https://ziglang.org/download/0.17.0/release-notes.html#Run-Step-Passthru-Args)

In the Run step, passthru args are all together now, not observable in configure phase whether run args are provided.

```
--- build.zig
+++ build.zig
@
-if (b.args) |args| {
-    run_cmd.addArgs(args);
-}
+run_cmd.addPassthruArgs();
```

This removes a capability from build scripts since they can no longer observe those arguments. In exchange, it means that when changing those arguments, build scripts no longer must be rebuilt from source.

### [Fmt Step: Options](https://ziglang.org/download/0.17.0/release-notes.html#toc-Fmt-Step-Options) [§](https://ziglang.org/download/0.17.0/release-notes.html#Fmt-Step-Options)

`paths` and `exclude_paths` are now `LazyPath` lists. There is a convenience method to create them: `b.pathList`.

```
--- build.zig
+++ build.zig
@
-    const fmt_include_paths = &.{ "lib", "src", "test", "tools", "build.zig", "build.zig.zon" };
-    const fmt_exclude_paths = &.{ "test/cases", "test/behavior/zon" };
+    const fmt_include_paths = b.pathList(&.{ "lib", "src", "test", "tools", "build.zig", "build.zig.zon" });
+    const fmt_exclude_paths = b.pathList(&.{ "test/cases", "test/behavior/zon" });
```

### [`Step.Options`: add addOptionPathDirectory](https://ziglang.org/download/0.17.0/release-notes.html#toc-codeStepOptionscode-add-addOptionPathDirectory) [§](https://ziglang.org/download/0.17.0/release-notes.html#codeStepOptionscode-add-addOptionPathDirectory)

Now, when adding an option that is a file path, one must explicitly choose between ([#36876](https://codeberg.org/ziglang/zig/pulls/36876)):

-   `addOptionPath` (must be a file)
-   `addOptionPathDirectory` (must be a directory)
-   `addOptionPathUntracked` (opt out of dependency tracking)

### [Lazy Dependency Ergonomic Enhancements](https://ziglang.org/download/0.17.0/release-notes.html#toc-Lazy-Dependency-Ergonomic-Enhancements) [§](https://ziglang.org/download/0.17.0/release-notes.html#Lazy-Dependency-Ergonomic-Enhancements)

-   Log when lazy dependencies are fetched.
-   `std.Build.dependency`: support lazy dependencies
-   Introduce `std.Build.dependencyLazy` which possibly returns `error.LazyDependencyNeeded` instead of `null`, so that you can use `try`
-   When user `build` functions return `error.LazyDependencyNeeded`, build system proceeds to fetch them rather than failing configuration.

### [Removed Ability to Override Build Runner](https://ziglang.org/download/0.17.0/release-notes.html#toc-Removed-Ability-to-Override-Build-Runner) [§](https://ziglang.org/download/0.17.0/release-notes.html#Removed-Ability-to-Override-Build-Runner)

There is no concept of a "build runner" any more; it has been [split into: configurer and maker](https://ziglang.org/download/0.17.0/release-notes.html#Separate-the-Maker-Process-from-the-Configurer-Process)

This use case is now handled by the [Build Server Protocol](https://ziglang.org/download/0.17.0/release-notes.html#Build-Server-Protocol).

### [Package Management](https://ziglang.org/download/0.17.0/release-notes.html#toc-Package-Management) [§](https://ziglang.org/download/0.17.0/release-notes.html#Package-Management)

All package management functionality has been moved out of the [Compiler](https://ziglang.org/download/0.17.0/release-notes.html#Compiler) and into the [Build System](https://ziglang.org/download/0.17.0/release-notes.html#Build-System). This includes the following sub-commands:

-   `zig build`
-   `zig fetch`
-   `zig init`
-   `zig libc`
-   `zig cache-cat`

This means that large parts of what used to be included in the compiler executable are now shipped in source form instead, including:

-   package fetching logic
-   http client and networking
-   TLS (Transport Layer Security) and associated crypto
-   git protocol
-   xz, gzip, zstd, flate, zip
-   parsing, validation, and otherwise dealing with build.zig.zon files

All of this functionality is now compiled in `-Osafe` optimization mode rather than `-Ofast` due to being in the compiler. When hacking on the build system itself, the environment variable `ZIG_DEBUG_CMD=1` may be used to compile the build system in debug mode instead.

Miscellaneous changes:

-   Bug fix: reject path deps that escape the parent package root.

#### [Ability to Override Package Path](https://ziglang.org/download/0.17.0/release-notes.html#toc-Ability-to-Override-Package-Path) [§](https://ziglang.org/download/0.17.0/release-notes.html#Ability-to-Override-Package-Path)

`--pkg-path` CLI arg and `ZIG_LOCAL_PKG_DIR` env var are now observed for both fetch and build commands.

#### [Global vs Local Fetching](https://ziglang.org/download/0.17.0/release-notes.html#toc-Global-vs-Local-Fetching) [§](https://ziglang.org/download/0.17.0/release-notes.html#Global-vs-Local-Fetching)

Now `zig fetch` only fetches into the global cache, just like it used to. However, if `--save` (or any variant) is used, then it also fetches into the local package path. When fetching globally, does not require `build.zig` to be present. `zig build` always fetches locally (in addition to globally).

Notably, this fixes the regressed use case `zig fetch .`

When fetching by path, the hash is always computed, recompressed tarball is always created, always overwrites any existing global cache entry.

### [Slight Difference in PATH for DLL Arguments](https://ziglang.org/download/0.17.0/release-notes.html#toc-Slight-Difference-in-PATH-for-DLL-Arguments) [§](https://ziglang.org/download/0.17.0/release-notes.html#Slight-Difference-in-PATH-for-DLL-Arguments)

It used to be the case that, when targeting Windows or Wine, artifact args added to Run steps modified PATH based on the set of directories containing the recursive set of DLL dependencies. Now this is only done for argv\[0\]. The motivation for also doing this for the other command line arguments is unclear, since those DLLs don't need to be loaded in order to execute argv\[0\].

### [Build Server Protocol](https://ziglang.org/download/0.17.0/release-notes.html#toc-Build-Server-Protocol) [§](https://ziglang.org/download/0.17.0/release-notes.html#Build-Server-Protocol)

Now, when `--listen=-` is passed, the build system serves a protocol that allows connected clients to monitor and control the build graph as it executes. This is intended to be consumed by third-party tooling such as IDEs.

Current things you can do:

-   Get full access to the entire build graph's static, post-configuration information, such as which build steps are available, which options are set, dependencies, etc. There are a couple things yet to be included, such as the exposed set of module names.
-   Get notified when a build step starts and completes, including information about errors and which files were generated.
-   Request specific steps to build.

In particular, the [separation of maker process and configurer process](https://ziglang.org/download/0.17.0/release-notes.html#Separate-the-Maker-Process-from-the-Configurer-Process) is a breaking change that prevents the [ZLS](https://zigtools.org/zls/) project from working with 0.17.0. Although some progress was made to restore functionality in this release cycle, Zig team and ZLS team are still working together to enhance the build server protocol further to the point that ZLS can not only restore functionality, but surpass the power and capabilities compared to before.

In the future it is expected for much of Zig's own first-party build system tooling to become a client of the build server protocol, dogfooding it to ensure that third-party tooling enjoys equivalent capabilities ([#36497](https://codeberg.org/ziglang/zig/issues/36497)).

It is also planned for the build server to multiplex compiler server protocol for the compilation steps, providing type-system information, refactoring, and other advanced editing capabilities ([#615](https://github.com/ziglang/zig/issues/615)).

## [Compiler](https://ziglang.org/download/0.17.0/release-notes.html#toc-Compiler) [§](https://ziglang.org/download/0.17.0/release-notes.html#Compiler)

### [Incremental Compilation](https://ziglang.org/download/0.17.0/release-notes.html#toc-Incremental-Compilation) [§](https://ziglang.org/download/0.17.0/release-notes.html#Incremental-Compilation)

The Zig compiler's implementation of incremental compilation—a feature allowing near-instant rebuilds of projects after changing the code—has been significantly improved in Zig 0.17.0. Many bugs have been fixed, and the new [ELF Linker](https://ziglang.org/download/0.17.0/release-notes.html#ELF) introduced in the previous release has gained good support for the feature.

**Thanks to these enhancements, it is now possible for most projects targeting `x86_64-linux` to take advantage of incremental compilation.** To do so, add the arguments `-fincremental --watch` to your `zig build` command (e.g. `zig build -fincremental --watch`)—this will cause the Zig build system to listen for changes to source files, and react to them by performing an incremental rebuild.

For more information on ways to use incremental compilation in your own projects, or to learn more about how this feature works under the hood, consider checking out [this blog post](https://mlugg.co.uk/posts/incremental-compilation-internals/) by a Zig core team member.

Future releases will continue to focus on improving this feature, including introducing a new Mach-O linker and self-hosted [aarch64 Backend](https://ziglang.org/download/0.17.0/release-notes.html#aarch64-Backend) with good support for incremental compilation; adding support for using incremental compilation without `--watch`; and fixing any remaining bugs.

### [SPIR-V Backend](https://ziglang.org/download/0.17.0/release-notes.html#toc-SPIR-V-Backend) [§](https://ziglang.org/download/0.17.0/release-notes.html#SPIR-V-Backend)

The self-hosted SPIR-V backend is now multi-threaded like the other backends.

Execution modes such as `LocalSize` and `OriginUpperLeft` are now derived from the function's calling convention instead of being set through inline assembly, and the new `spirv_task` and `spirv_mesh` calling conventions add support for task and mesh shaders ([#35676](https://codeberg.org/ziglang/zig/pulls/35676)).

Declaring capabilities and extensions in inline assembly with `OpCapability` and `OpExtension` is no longer allowed. They are enabled through target CPU features instead, i.e. the `-mcpu` option.

[22 bugs were fixed](https://codeberg.org/ziglang/zig/issues?q=&state=closed&labels=741711%2C746694&milestone=69474) in the SPIR-V backend during this release cycle.

### [aarch64 Backend](https://ziglang.org/download/0.17.0/release-notes.html#toc-aarch64-Backend) [§](https://ziglang.org/download/0.17.0/release-notes.html#aarch64-Backend)

Progress towards this is blocked on [Linker](https://ziglang.org/download/0.17.0/release-notes.html#Linker) enhancements, many of which were completed during this release cycle.

### [loongarch Backend](https://ziglang.org/download/0.17.0/release-notes.html#toc-loongarch-Backend) [§](https://ziglang.org/download/0.17.0/release-notes.html#loongarch-Backend)

Initial implementation of self-hosted backend for loongarch64 has been contributed ([#36418](https://codeberg.org/ziglang/zig/pulls/36418)). It is still experimental and not yet usable. There are two ways to contribute to this backend: working on it directly, and contributing to [AIR Legalization Features](https://codeberg.org/ziglang/zig/issues/36719), which helps all unfinished backends reach the finish line quicker.

### [WebAssembly Backend](https://ziglang.org/download/0.17.0/release-notes.html#toc-WebAssembly-Backend) [§](https://ziglang.org/download/0.17.0/release-notes.html#WebAssembly-Backend)

Zig's WebAssembly backend is now passing 2060/2054 (100%) behavior tests compared to the LLVM backend. However, it is not yet the default when compiling in debug optimization mode due to lack of debug info support ([#37032](https://codeberg.org/ziglang/zig/issues/37032)).

## [Linker](https://ziglang.org/download/0.17.0/release-notes.html#toc-Linker) [§](https://ziglang.org/download/0.17.0/release-notes.html#Linker)

### [ELF](https://ziglang.org/download/0.17.0/release-notes.html#toc-ELF) [§](https://ziglang.org/download/0.17.0/release-notes.html#ELF)

This release makes significant progress towards replacing Zig's legacy self-hosted ELF linker with its new implementation introduced in the previous release. Specific enhancements include:

-   Full x86\_64 support
-   Full SPARC64 support
-   Partial Loongarch support
-   Static library generation
-   Shared library generation
-   Errors for undefined symbols in executables
-   GOT generation
-   Copy relocations
-   GNU symbol versioning
-   DWARF debug information
-   Symbol hash table generation
-   Mostly-reproducible binaries
-   Arbitrary section alignment
-   Support for small host file system block sizes

While this linker has not quite reached feature parity with our old self-hosted ELF linker yet—and so remains disabled by default—it is already capable in practice of building the vast majority of Zig projects targeting `x86_64-linux`. This unlocks the ability to use [Incremental Compilation](https://ziglang.org/download/0.17.0/release-notes.html#Incremental-Compilation) for these projects—like in Zig 0.16.0, the new linker is enabled by default in this case.

In the next release of Zig, we hope to fully eliminate the legacy ELF linker in favour of this implementation.

### [COFF](https://ziglang.org/download/0.17.0/release-notes.html#toc-COFF) [§](https://ziglang.org/download/0.17.0/release-notes.html#COFF)

COFF support in the linker is enhanced with the following features ([#35674](https://codeberg.org/ziglang/zig/pulls/35674)):

-   Outputing objects (.obj) and archives (.lib)
-   Outputing implibs alongside images
-   Outputing the TLS and Exports data directories for images
-   Consuming objects, archives, and import libraries as inputs
-   Only links in objects from archives as required, ie. if they contain a symbol needed to satisfy a reference
-   COMDAT rules (enough support for linking compiler\_rt and libc, some COMDAT types are not supported yet)
-   Supports linking against both -gnu and -msvc libc
-   TLS support
-   `__dllimport` support: Indirect calls / loads from the IAT directly
-   Detects which entrypoint to choose based on exported symbols
-   `-gnu`: Constructor / destructor support (ie. merge .ctor and .dtor, and set up the `__CTOR_LIST__`, `__DTOR_LIST__` symbols)
-   Support for several `.drectve` arguments (these are required to correctly link `msvc` libc):
    -   `/INCLUDE`: Forcing a symbol to be referenced
    -   `/ALTERNATENAME`: Adding symbol aliases
    -   `/MERGE`: Section merging. This functionality is also used to direct certain sections into the right place (like `.ctor` / `.dtor` into `.rdata`)
    -   `/DEFAULTLIB`: Adding new inputs

### [New Linker Testing Framework](https://ziglang.org/download/0.17.0/release-notes.html#toc-New-Linker-Testing-Framework) [§](https://ziglang.org/download/0.17.0/release-notes.html#New-Linker-Testing-Framework)

Zig is moving towards snapshot-based testing for its linkers.

Tests are a combination of comparing objdump snapshot output, actually running the artifacts, and checking for linker errors.

`zig build -Dlink-snapshot-update` causes tests to run in a mode that outputs snapshots instead of checking against them.

A typical workflow for adding a new test:

1.  Add the test
2.  `zig-debug build test-link -Dtest-filter=my-test -Dlink-snapshot-update`
    -   This will output a .dmp file for all the snapshot combinations defined in any `verifyObjdump` calls.
    -   A single snapshot intentionally aliases between many targets to reduce noise in the snapshot folder, so snapshot updates are made by whichever test runs first for that snapshot name. If differences between targets do exist, they will be revealed in step 4.
3.  Inspect the snapshot output for correctness.
4.  `zig-debug build test-link -Dtest-filter=my-test`
    -   This will now run all targets against the newly added snapshots
5.  If there are now snapshot failures, that means different targets had different snapshot outputs. The output should be inspected to see if these results are indeed valid differences. If they are, then the `scope` parameter should be used to cause `-Dlink-snapshot-update` to output snapshot to different filenames, scoped on the diference.
6.  Re-run `-Dlink-snapshot-update` to update the new set of snapshots.

### [SPIR-V](https://ziglang.org/download/0.17.0/release-notes.html#toc-SPIR-V) [§](https://ziglang.org/download/0.17.0/release-notes.html#SPIR-V)

The SPIR-V linker has been rewritten ([#36828](https://codeberg.org/ziglang/zig/pulls/36828)). It now supports incremental compilation and can link external `.spv` object files.

## [Fuzzer](https://ziglang.org/download/0.17.0/release-notes.html#toc-Fuzzer) [§](https://ziglang.org/download/0.17.0/release-notes.html#Fuzzer)

Although this release's [Build System](https://ziglang.org/download/0.17.0/release-notes.html#Build-System) changes are loosely related to Zig's integrated fuzzer and its interaction with the build system, no changes were made to the fuzzer itself.

We expect to focus on improving the fuzzer in a future release cycle.

## [Bug Fixes](https://ziglang.org/download/0.17.0/release-notes.html#toc-Bug-Fixes) [§](https://ziglang.org/download/0.17.0/release-notes.html#Bug-Fixes)

Full list of the 329 bug reports closed during this release cycle:

-   [Tracked on GitHub](https://github.com/ziglang/zig/issues?q=is%3Aclosed+is%3Aissue+label%3Abug+milestone%3A0.17.0)
-   [Tracked on Codeberg](https://codeberg.org/ziglang/zig/issues?q=&type=all&sort=relevance&state=closed&labels=741711&milestone=69474&project=0&assignee=0&poster=0)

Many bugs were both introduced and resolved within this release cycle. Most bug fixes are omitted from these release notes for the sake of brevity.

### [This Release Contains Bugs](https://ziglang.org/download/0.17.0/release-notes.html#toc-This-Release-Contains-Bugs) [§](https://ziglang.org/download/0.17.0/release-notes.html#This-Release-Contains-Bugs)

Zig has known [bugs](https://codeberg.org/ziglang/zig/issues?q=&type=all&sort=relevance&labels=741711&state=open&milestone=0&project=0&assignee=0&poster=0), [miscompilations](https://codeberg.org/ziglang/zig/issues?q=&type=all&sort=relevance&labels=746970&state=open&milestone=0&project=0&assignee=0&poster=0), and [regressions](https://codeberg.org/ziglang/zig/issues?q=&type=all&sort=relevance&labels=741714&state=open&milestone=0&project=0&assignee=0&poster=0).

Even with Zig 0.17.x, working on a non-trivial project using Zig may require participating in the development process.

When Zig reaches 1.0.0, Tier 1 support will gain a bug policy as an additional requirement.

#### [Notable Regressions](https://ziglang.org/download/0.17.0/release-notes.html#toc-Notable-Regressions) [§](https://ziglang.org/download/0.17.0/release-notes.html#Notable-Regressions)

We are aware of these notable regressions in 0.17.0:

-   [#37006](https://codeberg.org/ziglang/zig/issues/37006): compiler-rt fails to compile for soft float on x86
-   [#36986](https://codeberg.org/ziglang/zig/pulls/36916): `std.debug.simple_panic` fails to compile
-   [#36986](https://codeberg.org/ziglang/zig/issues/36986): Weak Zig libc symbols cannot be reliably overridden
-   [#36444](https://codeberg.org/ziglang/zig/issues/36444): The [separation of maker process and configurer process](https://ziglang.org/download/0.17.0/release-notes.html#Separate-the-Maker-Process-from-the-Configurer-Process) breaks response file use cases for `std.Build.Step.Run`
-   [#37050](https://codeberg.org/ziglang/zig/pulls/37050): SPIR-V backend regressions

## [Toolchain](https://ziglang.org/download/0.17.0/release-notes.html#toc-Toolchain) [§](https://ziglang.org/download/0.17.0/release-notes.html#Toolchain)

### [LLVM 22](https://ziglang.org/download/0.17.0/release-notes.html#toc-LLVM-22) [§](https://ziglang.org/download/0.17.0/release-notes.html#LLVM-22)

This release of Zig upgrades to [LLVM 22.1.8](https://releases.llvm.org/22.1.0/docs/ReleaseNotes.html). This covers Clang ([zig cc](https://ziglang.org/download/0.17.0/release-notes.html#zig-cc)), libc++, libc++abi, libunwind, and libtsan as well.

#### [Loop Vectorization Disabled to Work Around Regression](https://ziglang.org/download/0.17.0/release-notes.html#toc-Loop-Vectorization-Disabled-to-Work-Around-Regression) [§](https://ziglang.org/download/0.17.0/release-notes.html#Loop-Vectorization-Disabled-to-Work-Around-Regression)

In the previous release of Zig, we were forced to disable a key LLVM optimization pass—loop vectorization—to work around a [miscompilation](https://github.com/llvm/llvm-project/issues/186922) which affected the Zig compiler.

Since we first introduced that workaround, a [fix](https://github.com/llvm/llvm-project/pull/187023) has been merged into LLVM's main branch. However, the fix is not available in [LLVM 22](https://ziglang.org/download/0.17.0/release-notes.html#LLVM-22), the LLVM version used by Zig 0.17.0. Therefore, this workaround remains enabled for now.

Zig 0.18.0 will upgrade to LLVM 23, so will allow us to re-enable this optimization pass.

### [musl 1.2.5](https://ziglang.org/download/0.17.0/release-notes.html#toc-musl-125) [§](https://ziglang.org/download/0.17.0/release-notes.html#musl-125)

Zig 0.17.0 distributes musl 1.2.5 plus backported security and portability fixes. Meanwhile, upstream has tagged 1.2.6. Zig 0.18.0 will update to musl 1.2.6.

When targeting musl statically, many functions are now provided by [zig libc](https://ziglang.org/download/0.17.0/release-notes.html#zig-libc) rather than source files copied from musl. Therefore, if you encounter bugs with musl libc provided by Zig, please respect upstream by reporting them to Zig's issue tracker rather than musl's.

### [glibc 2.44](https://ziglang.org/download/0.17.0/release-notes.html#toc-glibc-244) [§](https://ziglang.org/download/0.17.0/release-notes.html#glibc-244)

glibc version 2.44 is now available when cross-compiling.

### [Linux 7.2 Headers](https://ziglang.org/download/0.17.0/release-notes.html#toc-Linux-72-Headers) [§](https://ziglang.org/download/0.17.0/release-notes.html#Linux-72-Headers)

This release includes Linux kernel headers for version 7.2.

### [macOS 27.0 Headers](https://ziglang.org/download/0.17.0/release-notes.html#toc-macOS-270-Headers) [§](https://ziglang.org/download/0.17.0/release-notes.html#macOS-270-Headers)

This release includes macOS system headers for version 27.0.

### [MinGW-w64](https://ziglang.org/download/0.17.0/release-notes.html#toc-MinGW-w64) [§](https://ziglang.org/download/0.17.0/release-notes.html#MinGW-w64)

Zig 0.17.distributes MinGW-w64 commit `31bd54ab7d5fe03c67ed2bb1a57e531b9c7f8cc4`.

However, many functions are now provided by [zig libc](https://ziglang.org/download/0.17.0/release-notes.html#zig-libc) rather than source files copied from MinGW-w64. Therefore, if you encounter bugs with MinGW-w64 libc provided by Zig, please respect upstream by reporting them to Zig's issue tracker rather than MinGW-w64's.

### [NetBSD 11.0 libc](https://ziglang.org/download/0.17.0/release-notes.html#toc-NetBSD-110-libc) [§](https://ziglang.org/download/0.17.0/release-notes.html#NetBSD-110-libc)

NetBSD libc version 11.0 is now available when cross-compiling.

### [OpenBSD 7.9 libc](https://ziglang.org/download/0.17.0/release-notes.html#toc-OpenBSD-79-libc) [§](https://ziglang.org/download/0.17.0/release-notes.html#OpenBSD-79-libc)

OpenBSD libc version 7.9 is now available when cross-compiling.

### [WASI libc](https://ziglang.org/download/0.17.0/release-notes.html#toc-WASI-libc) [§](https://ziglang.org/download/0.17.0/release-notes.html#WASI-libc)

Zig 0.17.0 continues to distribute [WASI libc](https://github.com/WebAssembly/wasi-libc) commit `c89896107d7b57aef69dcadede47409ee4f702ee`.

However, many functions are now provided by [zig libc](https://ziglang.org/download/0.17.0/release-notes.html#zig-libc) rather than source files copied from WASI libc.

Furthermore, starting with Zig 0.18.0, instead of distributing third party WASI libc code, Zig will provide libc for WASI targets via [zig libc](https://ziglang.org/download/0.17.0/release-notes.html#zig-libc). For more information, see:

-   [Define a distinct Zig libc ABI](https://codeberg.org/ziglang/zig/issues/35379)
-   [remove support for wasi-libc](https://codeberg.org/ziglang/zig/pulls/36633)

### [zig libc](https://ziglang.org/download/0.17.0/release-notes.html#toc-zig-libc) [§](https://ziglang.org/download/0.17.0/release-notes.html#zig-libc)

In `libc.txt` files, the `gcc_dir` field has been renamed to `cc_dir` to reflect the reality that it is not specific to GCC. The old name will still be accepted for now, but users are encouraged to migrate their `libc.txt` to the new name ([#36951](https://codeberg.org/ziglang/zig/pulls/36951)).

Additionally, `cc_dir` is now required on Linux targets. Note that, because Android and OpenHarmony store the relevant object files in an unusual location, users of these targets will likely want to set `cc_dir` to the same path as `crt_dir`.

### [zig cc](https://ziglang.org/download/0.17.0/release-notes.html#toc-zig-cc) [§](https://ziglang.org/download/0.17.0/release-notes.html#zig-cc)

`zig cc` and `zig c++` are now based on Clang 22.1.8.

### [zig objdump](https://ziglang.org/download/0.17.0/release-notes.html#toc-zig-objdump) [§](https://ziglang.org/download/0.17.0/release-notes.html#zig-objdump)

This was a requirement for [snapshot testing](https://ziglang.org/download/0.17.0/release-notes.html#New-Linker-Testing-Framework), as well as aiding in developing the [COFF](https://ziglang.org/download/0.17.0/release-notes.html#COFF) [Linker](https://ziglang.org/download/0.17.0/release-notes.html#Linker).

Supported features:

```
Usage: zig objdump [options] file

Options:
  -h, --help                         Print this help and exit
  --all-headers                      Alias for --file-headers --linker-member=2 --member-headers --section-headers --relocs --symbols
  --exports[=sort]                   Display exported symbols.
                                     In the case of COFF import libraries, displays the symbol list and import headers.
                                     Specify =sort to optionally sort the import headers by symbol name.
  --file-headers                     Display file-format specific headers
  --imports                          Display imported symbols
  --linker-member[=1|2|longnames]    (Coff) Display contents of the specified archive linker member (default 2)
  --member-headers                   Display archive member headers
  --elements=[e1],[e2],-[e3],...     Select which formatting elements are displayed. Intended for snapshot testing.
      file-type                      File type summary
      header-name                    Name that precedes a header block
      member-path                    Display full member paths. If removed, only basenames will be used.
      newlines                       Newlines between output sections
      table-header                   Table headers with column names
      all                            (default) All of the above
  --only-member=[name]               Only consider archive members names that contain [name]. Can be specified multiple times.
  --only-section=[name]              Only consider section names that contain [name]. Can be specified multiple times.
  --only-symbol=[name]               Only consider symbol names that contain [name]. Can be specified multiple times.
  --redact=[kind]                    Redact the specified field kind. Intended for snapshot testing.
      rva                            Relative virtual addresses
      va                             Virtual addresses and file offsets
      ord                            Symbol ordinals / hints
      size                           Sizes and lengths
      all                            All of the above
  --relocs                           Display relocations
  -s, --snapshot                     Alias for --redact=all --elements=-all
  --section-headers                  Display section headers
  --strings                          Display string tables
  --symbols                          Display symbol tables
  --tls                              Display TLS information
```

Some example output:

```
❯ zig objdump mathtest-dync-exe-no-llvm.dll --all-headers
mathtest-dync-exe-no-llvm.dll: PE/COFF image

COFF Header:
            8664 machine (AMD64)
               7 number_of_sections
        6a08670a time_date_stamp
               0 pointer_to_symbol_table
               0 number_of_symbols
              f0 size_of_optional_header
            2022 flags
               | EXECUTABLE_IMAGE
               | LARGE_ADDRESS_AWARE
               | DLL

COFF Optional Header:
             20b magic (PE32+)
           14.00 linker_version
          14a400 size_of_code
           84e00 size_of_initialized_data
               0 size_of_uninitialized_data
            1000 address_of_entry_point (       180001000)
            1000 base_of_code (       180001000)
       180000000 image_base
            1000 section_alignment
             200 file_alignment
            6.00 operating_system_version
            1.00 image_version
            6.00 subsystem_version
               0 win32_version_value
          1d6000 size_of_image
             400 size_of_headers
               0 checksum
               2 subsystem (WINDOWS_GUI)
             160 dll_flags
               | HIGH_ENTROPY_VA
               | DYNAMIC_BASE
               | NX_COMPAT
          100000 size_of_stack_reserve
            1000 size_of_stack_commit
          100000 size_of_heap_reserve
            1000 size_of_heap_commit
               0 loader_flags
              10 number_of_rva_and_sizes

Data Directories:
          1b48d0       54 EXPORT
          1b4924       8c IMPORT
               0        0 RESOURCE
          1cc000     633c EXCEPTION
               0        0 SECURITY
          1d4000     1280 BASERELOC
          1bc000       1c DEBUG
               0        0 ARCHITECTURE
               0        0 GLOBALPTR
          1aebc8       28 TLS
               0        0 LOAD_CONFIG
               0        0 BOUND_IMPORT
          1b4c80      2d0 IAT
               0        0 DELAY_IMPORT
               0        0 COM_DESCRIPTOR
               0        0 RESERVED

Sections in 'mathtest-dync-exe-no-llvm.dll':
Num Name          RVA Virt Size Data Size   & Data & Relocs  & Lines # Relocs  # Lines    Flags
  1 .text        1000    14a346    14a400      400        0        0    0    0 60000020 | CNT_CODE MEM_EXECUTE MEM_READ
  2 .rdata     14c000     6fe3c     70000   14a800        0        0    0    0 40000040 | CNT_INITIALIZED_DATA MEM_READ
  3 .buildid   1bc000        52       200   1ba800        0        0    0    0 40000040 | CNT_INITIALIZED_DATA MEM_READ
  4 .data      1bd000      e2a0      d200   1baa00        0        0    0    0 c0000040 | CNT_INITIALIZED_DATA MEM_READ MEM_WRITE
  5 .pdata     1cc000      633c      6400   1c7c00        0        0    0    0 40000040 | CNT_INITIALIZED_DATA MEM_READ
  6 .tls       1d3000        20       200   1ce000        0        0    0    0 c0000040 | CNT_INITIALIZED_DATA MEM_READ MEM_WRITE
  7 .reloc     1d4000      1280      1400   1ce200        0        0    0    0 42000040 | CNT_INITIALIZED_DATA MEM_DISCARDABLE MEM_READ

No symbol table found
```

If this output was used for a snapshot test that wanted to test the presence of a particular export:

```
❯ zig objdump mathtest-dync-exe-no-llvm.dll --exports --only-symbol=add --redact=rva --elements=-all
Export directory:
               0 flags
               0 time_date_stamp
            0.00 version
xxxxxxxxxxxxxxxx name_rva
               1 ordinal_base
               1 number_of_entries
               1 number_of_names
xxxxxxxxxxxxxxxx export_address_table_rva
xxxxxxxxxxxxxxxx name_pointer_table_rva
xxxxxxxxxxxxxxxx ordinal_table_rva
   1    0 xxxxxxxx | add
```

The redaction (`--redact=`) and element removal (`--elements=`) functionality is used to remove parts of the output that don't matter for the particular test, as to not cause spurious failures if say, an RVA for a symbol changes due to some unrelated change to the linker. `-s` is shorthand which enables all the redacts and removes all extra output elements, but particular tests may not use this if they do care about specific values.

### [resinator](https://ziglang.org/download/0.17.0/release-notes.html#toc-resinator) [§](https://ziglang.org/download/0.17.0/release-notes.html#resinator)

#### [Windows Resource Compilation Moving to an External Package](https://ziglang.org/download/0.17.0/release-notes.html#toc-Windows-Resource-Compilation-Moving-to-an-External-Package) [§](https://ziglang.org/download/0.17.0/release-notes.html#Windows-Resource-Compilation-Moving-to-an-External-Package)

[Windows resource script compilation](https://www.ryanliptak.com/blog/zig-is-a-windows-resource-compiler/) will be moved out of the compiler and into an [official-but-external build system package](https://codeberg.org/ziglang/rc) in the next release. As such, the corresponding `std.Build` functions and fields (`Build.Module.addWin32ResourceFile`, etc) have been marked as deprecated in this release.

The `zig rc` subcommand will remain after this change in order to continue supporting the use case of using the Zig toolchain with other build systems.

### [zig fmt](https://ziglang.org/download/0.17.0/release-notes.html#toc-zig-fmt) [§](https://ziglang.org/download/0.17.0/release-notes.html#zig-fmt)

#### [Added `--complexity` Flag](https://ziglang.org/download/0.17.0/release-notes.html#toc-Added-code--complexitycode-Flag) [§](https://ziglang.org/download/0.17.0/release-notes.html#Added-code--complexitycode-Flag)

It's a simple tool for counting tokens and AST nodes, which can be used to share how an edit to a source file increases or reduces complexity with a heuristic that is more insightful than line count.

For example, running it on old ELF linker directory:

```
info: src/link/Elf/gc.zig: tokens=1538 nodes=770
info: src/link/Elf/Atom.zig: tokens=15576 nodes=7768
info: src/link/Elf/Merge.zig: tokens=2288 nodes=1092
info: src/link/Elf/Thunk.zig: tokens=1128 nodes=519
info: src/link/Elf/SharedObject.zig: tokens=4566 nodes=2236
info: src/link/Elf/eh_frame.zig: tokens=4840 nodes=2335
info: src/link/Elf/Symbol.zig: tokens=3770 nodes=1872
info: src/link/Elf/synthetic_sections.zig: tokens=13287 nodes=6375
info: src/link/Elf/Object.zig: tokens=13903 nodes=6842
info: src/link/Elf/LinkerDefined.zig: tokens=4140 nodes=2091
info: src/link/Elf/relocatable.zig: tokens=3598 nodes=1848
info: src/link/Elf/Archive.zig: tokens=2176 nodes=1028
info: src/link/Elf/ZigObject.zig: tokens=20783 nodes=10274
info: src/link/Elf/AtomList.zig: tokens=1819 nodes=933
info: src/link/Elf/relocation.zig: tokens=1289 nodes=551
info: src/link/Elf/file.zig: tokens=2330 nodes=1087
info: total: tokens=97031 nodes=47621
```

Another example is after editing Lld.zig to use [`arena.print` rather than `std.fmt.allocPrint`](https://ziglang.org/download/0.17.0/release-notes.html#codefmtallocPrintcode-moved-to-codememAllocatorcode). The line count is roughly the same but `--complexity` tells a different story:

-   before: tokens=11929 nodes=5900
-   after: tokens=11832 nodes=5852 (1% reduction in source complexity)

In the future this metric may be helpful for an automatic import organizer to determine whether to create an import alias or not.

## [Roadmap](https://ziglang.org/download/0.17.0/release-notes.html#toc-Roadmap) [§](https://ziglang.org/download/0.17.0/release-notes.html#Roadmap)

1.  Work with ZLS team to enhance [Build Server Protocol](https://ziglang.org/download/0.17.0/release-notes.html#Build-Server-Protocol) to the point where satisfies all their use cases.
2.  Complete Windows support in the x86\_64 backend so that it can be enabled by default.
3.  Complete and [stabilize the language](https://ziglang.org/download/0.17.0/release-notes.html#Language-Stability-Progress).
4.  Complete the [aarch64 Backend](https://ziglang.org/download/0.17.0/release-notes.html#aarch64-Backend) and make it the default backend for debug mode.
5.  Enhance the [Linker](https://ziglang.org/download/0.17.0/release-notes.html#Linker) implementations, eliminating dependency on [LLD](https://lld.llvm.org/) and support [Incremental Compilation](https://ziglang.org/download/0.17.0/release-notes.html#Incremental-Compilation).
6.  Enhance the integrated [Fuzzer](https://ziglang.org/download/0.17.0/release-notes.html#Fuzzer) to be competitive with AFL and other state-of-the-art fuzzers.
7.  Transition from a library dependency on LLVM to a process dependency on Clang ([#16270](https://github.com/ziglang/zig/issues/16270)).
8.  Complete the [Build System](https://ziglang.org/download/0.17.0/release-notes.html#Build-System), in particular [Package Management](https://ziglang.org/download/0.17.0/release-notes.html#Package-Management) features.
9.  Audit the [Standard Library](https://ziglang.org/download/0.17.0/release-notes.html#Standard-Library) ([#1629](https://github.com/ziglang/zig/issues/1629)).

## [Thank You Contributors!](https://ziglang.org/download/0.17.0/release-notes.html#toc-Thank-You-Contributors) [§](https://ziglang.org/download/0.17.0/release-notes.html#Thank-You-Contributors)

Here are all the people who landed at least one contribution into this release:

-   Alex Rønne Petersen
-   Andrew Kelley
-   Matthew Lugg
-   Casey Banner
-   Jacob Young
-   Frank Denis
-   Ali Chraghi
-   Isaac Freund
-   Pavel Verigo
-   Ryan Liptak
-   Techatrix
-   Justus Klausecker
-   Linus Groh
-   xtex
-   rpkak
-   David Rubin
-   Elaine Gibson
-   David Senoner
-   K4
-   fardragon
-   pentuppup
-   Krzysztof Wolicki
-   Mason Remaley
-   Meghan Denny
-   Christophe Delage
-   Robbie Lyman
-   Lukáš Lalinský
-   Brandon Black
-   Kendall Condon
-   hemisputnik
-   whatisaphone
-   Ben Anderman
-   GasInfinity
-   Huang Zhichao
-   Jakub Konka
-   Jari Vetoniemi
-   Kleshzz
-   Mick Sayson
-   Mikołaj Rosowski
-   Ryan Mehri
-   Sertonix
-   jeffkdev
-   lg
-   Carl Åstholm
-   EJ
-   Hila Friedman
-   Quint Daenen
-   Saurabh Mishra
-   Stephen Gregoratto
-   Subo2002
-   Ten Eugene
-   zacoons
-   Arthur Teixeira
-   Ben Burkert
-   Bernard Assan
-   CursedByTheVoid
-   Daniel Kareh
-   Ennui Langeweile
-   Igor Anić
-   Janne Hellsten
-   Jay Petacat
-   Nguyễn Gia Phong
-   Ragul R
-   Rue04
-   Ryan Mehri
-   Sam Connelly
-   Scott Redig
-   Theo Fabi
-   Vitor Fernandes
-   c-kappel
-   gero3
-   glowsquid
-   taoqy
-   teflate
-   xeondev
-   AI Xin
-   ARandomOSDever
-   Acid Bong
-   Adrià Arrufat
-   Akshay Trivedi
-   Alan Cocanour
-   Alex Kladov
-   Amilia MacIntyre
-   Anders Stenberg
-   Andrew Kraevskiii
-   Anshul Gupta
-   Anthon van der Neut
-   Ari Becker
-   Ashley (holtowd)
-   C19
-   Carter Snook
-   Chadwain Holness
-   Chloé Vulquin
-   Chris Boesch
-   Christoffer Lerno
-   Corentin Kerisit
-   David
-   Devin J. Pohly
-   Diego Peña y Lillo
-   Dmitry Mostovenko
-   Eric Joldasov
-   Erik Schlyter
-   FalsePattern
-   Fitti
-   Gabriel Sa
-   Gereon V
-   Giuseppe Cesarano
-   Gota7
-   GrimTyr
-   Guillaume Wenzek
-   Guy Fischman
-   Henry Kupty
-   Ignacio Ibarra
-   Jan Procházka
-   Jan200101
-   Jeff Fowler
-   Jeremy Linton
-   John Benediktsson
-   Jonathan Marler
-   Joseph Lyncheski
-   Josh Megnauth
-   Kirk Scheibelhut
-   Leon Lombar
-   Leonid Emar-Kar
-   Mai-Lapyst
-   Manlio Perillo
-   Marcel W. Wysocki
-   Mark Rushakoff
-   Mathieu Suen
-   Matthew Knight
-   Matthias Portzel
-   Michael Farber Brodsky
-   Miloš Kozák
-   Nguyen Gia Huy
-   Nico Elbers
-   Noam Rothschild
-   Nurul Huda (Apon)
-   Paul Anderson
-   Paulo Duarte
-   Perry Fraser
-   Pivok
-   Preeternal
-   Prokop Randáček
-   RadsammyT
-   Rayan Halder
-   Richalsu
-   Richard Levitte
-   Rue04
-   Ryan Davis
-   Ryan King
-   Sage Hane
-   Samuel Hunter
-   Sawyer X
-   Siddharth Sinha
-   Steve
-   Tapir
-   Thibault Leclercq
-   Yasin Gorgij
-   Zhalkhas
-   abdessalem
-   agave
-   ahwayakchih
-   akbarhusain
-   arshidkv12
-   avalyn0x45
-   badayvedat
-   binarycraft007
-   brianferri
-   brkzlr
-   carmooo
-   cheesecakecatttt
-   conmaster2112
-   drex\_vk
-   gDator
-   gemmaro
-   gubbu
-   ilovapples
-   jmcaine
-   johan0A
-   jpk68
-   krystiann
-   kubashi
-   l1yefeng
-   levinqua
-   llogick
-   marximimus
-   mihael
-   mlugg
-   nash1111
-   ndjenks
-   nekogirl
-   nyx-xyn
-   pancelor
-   skdishansachin
-   sphaerophoria
-   squidy239
-   sstochi
-   vlkrs
-   zirunis
-   Ömer Faruk IRMAK
-   Έλλεν Εμίλια Άννα Zscheile
-   林晨 (Leo Cheng)

## [Thank You Sponsors!](https://ziglang.org/download/0.17.0/release-notes.html#toc-Thank-You-Sponsors) [§](https://ziglang.org/download/0.17.0/release-notes.html#Thank-You-Sponsors)

Special thanks to those who [sponsor Zig](https://ziglang.org/zsf/). Because of diverse, recurring donations, Zig is driven by the open source community, rather than the goal of making profit. In particular, those below sponsored Zig for an average of $50/month or more during this release cycle using our [preferred donation platform](https://www.every.org/zig-software-foundation-inc):

-   Sergey M
-   Mitchell Kember
-   David Vanderson
-   Thomas Manner
-   Kirk Scheibelhut
-   Kazuhiro Kondo
-   Merlyn Morgan-Graham
-   Freddi Linse
-   Numan Sachwani
-   Aurélien Cibrario
-   Erik Dunteman
-   Ondra Voves
-   Mitchell Gayner
-   Dylan Conway
-   Trevor John
-   Jason Watson
-   Greg Clark
-   Benjamin Crist
-   Alexander Weavers
-   Natalie Vais
-   Stevie Hryciw
-   Kyle Hill
-   Felix Queißner
-   Srinivasan Balram
-   Peter Ronnquist
-   Lajos Nagy
-   Gauthier Voron
-   Andrew Mangogna
-   Alex Kladov
-   Jacob Sandlund
-   Jordan Lucier
-   Wolfgang Sanyer
-   Matthew Knight
-   Nick Macholl
-   Ceri Elenbaas
-   Michael Keathley
-   Daniele Cocca
-   Bartosz Bogacz
-   James Cox-Morton
-   William Canan
-   Fabio Arnold
-   Johannes Meyer
-   Silver van Koten
-   Flavius Gruian
-   Daniel MacDougall
-   Karrick McDermott
-   Dan Mack
-   Caleb Hearon
-   Richard Levitte
-   Ingimar Jóhannesson
-   David Fendley
-   Aaron Cross
-   Jeremiah Oard
-   Simon Ekström
-   Jorge De León
-   Saurabh Mishra
-   Rob Green
-   Kytezign q
-   Mykhailo Tsiuptsiun
-   Paul Sargent
-   Erik Mållberg
-   Igor Anic
-   Fawzi Mohamed
-   David Jones
-   Magnus Holm
-   Nicholas Woolmer
-   Samarth Kishor
-   Charles Haws
-   Shlomi Atar
-   Robbie Lyman
-   Andrius Bentkus
-   Jean-Luc Geering
-   Aaron Mady
-   coleman broaddus
-   Trace Andreason
-   Jim Calabro
-   Chris Baldwin
-   Ian Johnson
-   Brandon Black
-   Michael Lynch
-   O Y
-   Francesco Gualazzi
-   David Sugar
-   Malcolm Still
-   Jeff Fowler
-   Yaroslav Zhavoronkov
-   Miles McGruder
-   Álvaro Justen
-   FELIPE SOARES GONCALVES SA ROSA
-   Noah Betzen
-   Manuel Barkhau
-   Rikard Karlsen
-   Frank Ittermann
-   Eli Janssen
-   Peter Snelgrove
-   Will Pragnell
-   Pete Dietl
-   Vaughn Spielman
-   Michael Kato
-   Daniel Dubecky Hodan
-   Dan Boykis
-   Richard Feldman
-   Markus Ort
-   Peyman Mortazavi
-   Wilson Bilkovich
-   Kev Burns
-   Francisco Nevitt Gonçalves
-   Mark Banhidi
-   Kristoffer Ström
-   Carl Distefano
-   Alexander Reustle
-   Martin Hovda Haugsand
-   Lexa Tang
-   Lennart Tuijnder
-   Enver Bisevac
-   Jameson York
-   Hong Shick Pak
-   Travis Staloch
-   Clover Caruso
-   Matthew Chavez
-   Daniel Gregoire
-   Jose M Rico
-   Xavier Cochran
-   Nas Denkov
-   Pavel Rychlý
-   papa leromi
-   Ronald Zielaznicki
-   Tommi Komulainen
-   Matthew Jee
-   Johan Forsberg
-   Łukasz Mróz
-   Fabio Leimgruber
-   Maurice van Veen
-   Dean Simmons
-   Pierre Marc Levasseur
-   Sebastian Appler
-   Sam Windell
-   Aksel Hjerpbakk
-   Jonathan Helland
-   Karl Fleischmann
-   Erik Hansen
-   Chris Boesch
-   Pablo Álvarez
-   Jacob Hooper
-   Avinash Lakshman
-   Joshua Park
-   Nicholas Clark
-   Ryan Higgins
-   Jeffrey Ollie
-   Adam Goertz
-   David Nowotny
-   Gus Louw
-   David Francoeur
-   David Sparby
-   Tyler Bender
-   Mark Halonen
-   Reinis Taukulis
-   Nancy Remaley
-   Isaac F
-   Kjell Hoffhenke
-   Vlad Panazan
-   Jordan Rowland
-   Jay Van Der Wall
-   Jean-Philippe Quenord
-   Jakob Külzer
-   Varun Pramanik
-   Benjamin Edwards
-   Andreas Herrmann
-   Adam Nilsson
-   Joseph Ruiz
-   Anthony Nguyen
-   Marcin Wolcendorf
-   Tobias Lahrmann Hansen
-   Pat Smuk
-   Martin Weber
-   Jordan Kardon
-   Benjamin LE BERRE
-   John Goen
-   Sebastian Ahlman
-   Anthony Hernandez
-   Shail Patel
-   Alexander Genaud
-   Morten Dalfoss
-   Jason Dubaniewicz
-   Mark Hayes
-   Eivind Rovik
-   Renan Silva
-   Isak Källman
-   Ladislav Böhm
-   LeRoyce Pearson
-   Rowan Saunders
-   Joshua Masci
-   Raymond Imber
-   Daniel Worley
-   Owen Cabalceta
-   Erez Shomron
-   Max Grosse
-   Ehden Sinai
-   Christopher Redden
-   Antoine Balaine
-   Chris Durkin
-   Dave Wallace
-   Aura Birb
-   Andy Armstrong
-   Spencer Brower
-   Simon Clavet
-   Guido Schmidt
-   Peter McGaughey
-   Callum McArthur
-   David Lei
-   David Brotz
-   Matti Hänninen
-   Joseph Chan
-   Vincent Weber
-   Jeremy McAdams
-   Morgan Gallant
-   Brett Pechiney
-   Thilina Jayanath Nenathunga Liyanage
-   Kevin Bockelandt
-   Gunnar Zötl

Special thanks also to [TigerBeetle](https://tigerbeetle.com/), [Synadia Communications](https://www.synadia.com/), and [ZML](https://zml.ai/) for substantial contributions.
