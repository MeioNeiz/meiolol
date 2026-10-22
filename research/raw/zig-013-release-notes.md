# 0.13.0 Release Notes ⚡ The Zig Programming Language

<https://ziglang.org/download/0.13.0/release-notes.html>

# 0.13.0 Release Notes

[Download & Documentation](https://ziglang.org/download/#release-0.13.0)

Zig is a general-purpose programming language and toolchain for maintaining **robust**, **optimal**, and **reusable** software.

Zig development is funded via [Zig Software Foundation](https://ziglang.org/zsf/), a 501(c)(3) non-profit organization. Please consider a recurring donation so that we can offer more billable hours to our core team members. This is the most straightforward way to accelerate the project along the [Roadmap](https://ziglang.org/download/0.13.0/release-notes.html#Roadmap) to 1.0.

This release features **2 months of work**: changes from **73 different contributors**, spread among **415 commits**.

This is a relatively short release cycle, primarily motivated by [Toolchain](https://ziglang.org/download/0.13.0/release-notes.html#Toolchain) upgrades, such as upgrading to [LLVM 18](https://ziglang.org/download/0.13.0/release-notes.html#LLVM-18).

## [Table of Contents](https://ziglang.org/download/0.13.0/release-notes.html#toc-Table-of-Contents) [§](https://ziglang.org/download/0.13.0/release-notes.html#Table-of-Contents)

-   [Table of Contents](https://ziglang.org/download/0.13.0/release-notes.html#Table-of-Contents)
-   [Support Table](https://ziglang.org/download/0.13.0/release-notes.html#Support-Table)
    -   [Tier System](https://ziglang.org/download/0.13.0/release-notes.html#Tier-System)
        -   [Tier 1 Support](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support)
        -   [Tier 2 Support](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support)
        -   [Tier 3 Support](https://ziglang.org/download/0.13.0/release-notes.html#Tier-3-Support)
        -   [Tier 4 Support](https://ziglang.org/download/0.13.0/release-notes.html#Tier-4-Support)
-   [Standard Library](https://ziglang.org/download/0.13.0/release-notes.html#Standard-Library)
    -   [BatBadBut Mitigation](https://ziglang.org/download/0.13.0/release-notes.html#BatBadBut-Mitigation)
    -   [Simplify hash.crc](https://ziglang.org/download/0.13.0/release-notes.html#Simplify-hashcrc)
    -   [ComptimeStringMap renamed to StaticStringMap and enhanced](https://ziglang.org/download/0.13.0/release-notes.html#ComptimeStringMap-renamed-to-StaticStringMap-and-enhanced)
    -   [PriorityQueue stores capacity instead of length](https://ziglang.org/download/0.13.0/release-notes.html#PriorityQueue-stores-capacity-instead-of-length)
    -   [Rename std.ChildProcess to std.process.Child](https://ziglang.org/download/0.13.0/release-notes.html#Rename-stdChildProcess-to-stdprocessChild)
    -   [Reworked CLI Progress](https://ziglang.org/download/0.13.0/release-notes.html#Reworked-CLI-Progress)
    -   [posix.iovec: use .base and .len instead of .iov\_base and .iov\_len](https://ziglang.org/download/0.13.0/release-notes.html#posixiovec-use-base-and-len-instead-of-iov_base-and-iov_len)
    -   [Added `std.zip` and Zip Archive Support in `build.zig.zon`](https://ziglang.org/download/0.13.0/release-notes.html#Added-codestdzipcode-and-Zip-Archive-Support-in-codebuildzigzoncode)
-   [Build System](https://ziglang.org/download/0.13.0/release-notes.html#Build-System)
    -   [Step.Run: global lock when child inherits stderr](https://ziglang.org/download/0.13.0/release-notes.html#StepRun-global-lock-when-child-inherits-stderr)
    -   [Install Windows DLLs to `<prefix>/bin/` by default](https://ziglang.org/download/0.13.0/release-notes.html#Install-Windows-DLLs-to-codeltprefixgtbincode-by-default)
    -   [Step.ObjCopy: don't accept multiple sections](https://ziglang.org/download/0.13.0/release-notes.html#StepObjCopy-dont-accept-multiple-sections)
-   [Compiler](https://ziglang.org/download/0.13.0/release-notes.html#Compiler)
    -   [Replace the `YES_COLOR` env variable with `CLICOLOR_FORCE`](https://ziglang.org/download/0.13.0/release-notes.html#Replace-the-codeYES_COLORcode-env-variable-with-codeCLICOLOR_FORCEcode)
    -   [LLVM Backend](https://ziglang.org/download/0.13.0/release-notes.html#LLVM-Backend)
    -   [`zig-cache` renamed to `.zig-cache`](https://ziglang.org/download/0.13.0/release-notes.html#codezig-cachecode-renamed-to-codezig-cachecode)
-   [Bug Fixes](https://ziglang.org/download/0.13.0/release-notes.html#Bug-Fixes)
    -   [This Release Contains Bugs](https://ziglang.org/download/0.13.0/release-notes.html#This-Release-Contains-Bugs)
-   [Toolchain](https://ziglang.org/download/0.13.0/release-notes.html#Toolchain)
    -   [LLVM 18](https://ziglang.org/download/0.13.0/release-notes.html#LLVM-18)
    -   [musl 1.2.5](https://ziglang.org/download/0.13.0/release-notes.html#musl-125)
    -   [glibc 2.39](https://ziglang.org/download/0.13.0/release-notes.html#glibc-239)
-   [Roadmap](https://ziglang.org/download/0.13.0/release-notes.html#Roadmap)
-   [Thank You Contributors!](https://ziglang.org/download/0.13.0/release-notes.html#Thank-You-Contributors)
-   [Thank You Sponsors!](https://ziglang.org/download/0.13.0/release-notes.html#Thank-You-Sponsors)

## [Support Table](https://ziglang.org/download/0.13.0/release-notes.html#toc-Support-Table) [§](https://ziglang.org/download/0.13.0/release-notes.html#Support-Table)

### [Tier System](https://ziglang.org/download/0.13.0/release-notes.html#toc-Tier-System) [§](https://ziglang.org/download/0.13.0/release-notes.html#Tier-System)

A green check mark (✅) indicates the target meets all the requirements for the support tier. The other icons indicate what is _preventing the target from reaching the support tier_. In other words, the icons are **to-do items**.

#### [Tier 1 Support](https://ziglang.org/download/0.13.0/release-notes.html#toc-Tier-1-Support) [§](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support)

-   Not only can Zig generate machine code for these targets, but the [Standard Library](https://ziglang.org/download/0.13.0/release-notes.html#Standard-Library) cross-platform abstractions have implementations for these targets.
-   The CI server automatically tests these targets on every commit to master branch. The 🧪 icon means this target does not yet have CI test coverage.
-   The CI server automatically produces pre-built binaries for these targets, on every commit to master, and updates [the download page](https://ziglang.org/download/) with links. The 📦 icon means the download page is missing this target.
-   These targets have debug info capabilities and therefore produce stack traces on failed assertions.
-   libc is available for this target even when cross compiling.
-   All the behavior tests and applicable standard library tests pass for this target. All language features are known to work correctly. Experimental features do not count towards disqualifying an operating system or architecture from Tier 1. The 🐛 icon means there are known [bugs](https://ziglang.org/download/0.13.0/release-notes.html#This-Release-Contains-Bugs) preventing this target from reaching Tier 1.
-   zig cc, zig c++, and related toolchain commands support this target.
-   If the Operating System is proprietary then the target is not marked deprecated by the vendor. The 💀 icon means the OS is officially deprecated, [such as macos/x86](https://support.apple.com/en-us/HT208436).

|  | freestanding | Linux 3.16+ | macOS 11+ | Windows 10+ | WASI |
| --- | --- | --- | --- | --- | --- |
| x86\_64 | ✅ | ✅ | ✅ | ✅ | N/A |
| x86 | ✅ | [#1929](https://github.com/ziglang/zig/issues/1929) 🐛 | 💀 | [#537](https://github.com/ziglang/zig/issues/537) 🐛 | N/A |
| aarch64 | ✅ | [#2443](https://github.com/ziglang/zig/issues/2443) 🐛 | ✅ | [#16665](https://github.com/ziglang/zig/issues/16665) 🐛 | N/A |
| arm | ✅ | [#3174](https://github.com/ziglang/zig/issues/3174) 🐛 | 💀 | 🐛📦🧪 | N/A |
| mips | ✅ | [#3345](https://github.com/ziglang/zig/issues/3345) 🐛📦 | N/A | N/A | N/A |
| riscv64 | ✅ | [#4456](https://github.com/ziglang/zig/issues/4456) 🐛 | N/A | N/A | N/A |
| sparc64 | ✅ | [#4931](https://github.com/ziglang/zig/issues/4931) 🐛📦🧪 | N/A | N/A | N/A |
| powerpc64 | ✅ | 🐛 | N/A | N/A | N/A |
| powerpc | ✅ | 🐛 | N/A | N/A | N/A |
| wasm32 | ✅ | N/A | N/A | N/A | ✅ |

#### [Tier 2 Support](https://ziglang.org/download/0.13.0/release-notes.html#toc-Tier-2-Support) [§](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support)

-   The [Standard Library](https://ziglang.org/download/0.13.0/release-notes.html#Standard-Library) supports this target, but it is possible that some APIs will give an "Unsupported OS" compile error. One can link with libc or other libraries to fill in the gaps in the standard library. The 📖 icon means the standard library is too incomplete to be considered Tier 2 worthy.
-   These targets are known to work, but may not be automatically tested, so there are occasional regressions. 🔍 means that nobody has really looked into this target so whether or not it works is unknown.
-   Some tests may be disabled for these targets as we work toward [Tier 1 Support](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support).

|  | free standing | Linux 3.16+ | macOS 11+ | Windows 10+ | FreeBSD 12.0+ | NetBSD 8.0+ | Dragon FlyBSD 5.8+ | OpenBSD 7.3+ | UEFI |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| x86\_64 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | ✅ | ✅ | ✅ | ✅ |
| x86 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | 💀 | ✅ | 🔍 | 🔍 | N/A | 🔍 | ✅ |
| aarch64 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | 🔍 | 🔍 | N/A | 🔍 | 🔍 |
| arm | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | 💀 | 🔍 | 🔍 | 🔍 | N/A | 🔍 | 🔍 |
| mips64 | ✅ | ✅ | N/A | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |
| mips | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | N/A | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |
| powerpc64 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | 💀 | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |
| powerpc | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | 💀 | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |
| riscv64 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | N/A | N/A | 🔍 | 🔍 | N/A | 🔍 | 🔍 |
| sparc64 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ | N/A | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |

#### [Tier 3 Support](https://ziglang.org/download/0.13.0/release-notes.html#toc-Tier-3-Support) [§](https://ziglang.org/download/0.13.0/release-notes.html#Tier-3-Support)

-   The standard library has little to no knowledge of the existence of this target.
-   If this target is provided by LLVM, LLVM has the target enabled by default.
-   These targets are not frequently tested; one will likely need to contribute to Zig in order to build for these targets.
-   The Zig compiler might need to be updated with a few things such as
    -   what sizes are the C integer types
    -   C ABI calling convention for this target
    -   start code and default panic handler
-   `zig targets` is guaranteed to include this target.

|  | freestanding | Linux 3.16+ | Windows 10+ | FreeBSD 12.0+ | NetBSD 8.0+ | UEFI |
| --- | --- | --- | --- | --- | --- | --- |
| x86\_64 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) |
| x86 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | ✅ | ✅ | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) |
| aarch64 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | ✅ | ✅ | ✅ |
| arm | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | ✅ | ✅ | ✅ | ✅ |
| mips64 | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | N/A |
| mips | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | N/A |
| riscv64 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | ✅ |
| powerpc32 | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | N/A |
| powerpc64 | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.13.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | N/A |
| bpf | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| hexagon | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| amdgcn | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| sparc | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| s390x | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| lanai | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| csky | ✅ | ✅ | N/A | ✅ | ✅ | N/A |

|  | freestanding | emscripten |
| --- | --- | --- |
| wasm32 | [Tier 1](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) | ✅ |

#### [Tier 4 Support](https://ziglang.org/download/0.13.0/release-notes.html#toc-Tier-4-Support) [§](https://ziglang.org/download/0.13.0/release-notes.html#Tier-4-Support)

-   Support for these targets is entirely experimental.
-   If this target is provided by LLVM, LLVM may have the target as an experimental target, which means that you need to use Zig-provided binaries for the target to be available, or build LLVM from source with special configure flags. `zig targets` will display the target if it is available.
-   This target may be considered deprecated by an official party, in which case this target will remain forever stuck in Tier 4.
-   This target may only support `-femit-asm` and cannot emit object files, in which case `-fno-emit-bin` is enabled by default and cannot be overridden.

Tier 4 targets:

-   avr
-   riscv32
-   xcore
-   nvptx
-   msp430
-   r600
-   arc
-   tce
-   le
-   amdil
-   hsail
-   spir
-   kalimba
-   shave
-   renderscript
-   32-bit x86 macOS, 32-bit ARM macOS, powerpc32 and powerpc64 macOS, because [Apple has officially dropped support for them](https://support.apple.com/en-us/HT208436).

## [Standard Library](https://ziglang.org/download/0.13.0/release-notes.html#toc-Standard-Library) [§](https://ziglang.org/download/0.13.0/release-notes.html#Standard-Library)

### [BatBadBut Mitigation](https://ziglang.org/download/0.13.0/release-notes.html#toc-BatBadBut-Mitigation) [§](https://ziglang.org/download/0.13.0/release-notes.html#BatBadBut-Mitigation)

std.process.Child: Mitigate arbitrary command execution vulnerability on Windows (BatBadBut) (#19698)

See [the pull request description for the details](https://github.com/ziglang/zig/pull/19698)

### [Simplify hash.crc](https://ziglang.org/download/0.13.0/release-notes.html#toc-Simplify-hashcrc) [§](https://ziglang.org/download/0.13.0/release-notes.html#Simplify-hashcrc)

This removes the two original implementations in favour of the single generic one based on the Algorithm type. Previously we had three, very similar implementations which was somewhat confusing when knowing what one should actually be used.

The previous polynomials all have equivalent variants available when using the Algorithm type.

The Koopman polynomial did not have an exact equivalent so one has been added to the catalog.txt file. This does mean we have patched this file but this will be clear if updated in future and tests will catch this.

This is a breaking change for direct users of the old polynomial api. Specifically when using a custom or non-standard polynomial (the `Crc32` alias will continue to work). There are clear compile errors indicating what is required in order to retain existing functionality, this may require a small code-change from the user.

```
const hash = Crc32WithPoly(.Castagnoli); // old
const hash = Crc(.Crc32Iscsi); // new
```

Custom polynomials require a bit more interaction and will require a user to define their own Algorithm type. If used note that the previous implementation expected a pre-reflected polynomial and used the following parameters:

```
.{
    .polynomial = 0x741b8cd7, // equivalent to the reflected polynomial: 0xeb31d82e
    .initial = 0xffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffffffff,
});
```

Loose performance measurements below. Table sizes are indicated to the right. Nothing new, helps rationalise the overlap that was present.

crc32-slicing-by-8 # 8K of tables
   iterative:  3074 MiB/s \[2d191d9400000000\]
  small keys:  32B  4650 MiB/s 152387950 Hashes/s \[20024c446a99a300\]
crc32-half-byte-lookup # 64b of tables
   iterative:   281 MiB/s \[2d191d9400000000\]
  small keys:  32B   389 MiB/s 12751954 Hashes/s \[20024c446a99a300\]
crc32 # 1K of tables
   iterative:  3077 MiB/s \[2d191d9400000000\]
  small keys:  32B  4660 MiB/s 152709182 Hashes/s \[20024c446a99a300\]

### [ComptimeStringMap renamed to StaticStringMap and enhanced](https://ziglang.org/download/0.13.0/release-notes.html#toc-ComptimeStringMap-renamed-to-StaticStringMap-and-enhanced) [§](https://ziglang.org/download/0.13.0/release-notes.html#ComptimeStringMap-renamed-to-StaticStringMap-and-enhanced)

ComptimeStringMap is renamed to StaticStringMap, accepts only a single type parameter, and returns a known struct type instead of an anonymous struct. Initial motivation for these changes was to reduce the 'very long type names' issue described in #19682.

This breaks the previous API. Users will now need to write:

```
const map = std.StaticStringMap(T).initComptime(kvs_list);
```

More details:

-   Moved `kvs_list` param from type param to an `initComptime()` param
-   New public methods:
    -   `keys()`, `values()` helpers
    -   `init(allocator)`, `deinit(allocator)` for runtime data
    -   `getLongestPrefix(str)`, `getLongestPrefixIndex(str)` - i'm not sure these belong but have left in for now incase they are deemed useful
-   Performance notes:
    -   Some benchmarking results are here: [travisstaloch/comptime-string-map-revised#1](https://github.com/travisstaloch/comptime-string-map-revised/issues/1)
    -   Speedup from reducing the size of the struct from 48 to 32 bytes and thus use u32s instead of usize for all length fields
    -   Speedup from storing KVs as a struct of arrays
    -   Latest benchmark shows these wall\_time improvements for debug/safe/small/fast builds: -6.6% / -10.2% / -19.1% / -8.9%. Full output in link above.

### [PriorityQueue stores capacity instead of length](https://ziglang.org/download/0.13.0/release-notes.html#toc-PriorityQueue-stores-capacity-instead-of-length) [§](https://ziglang.org/download/0.13.0/release-notes.html#PriorityQueue-stores-capacity-instead-of-length)

This is a breaking change that aligns the PriorityQueue API to the ArrayList API.

Before, PriorityQueue stored the full allocated slice in the `items` field, and length in a separate `len` field. This was inconsistent with ArrayList and led to the mistake of accessing undefined memory.

Now, the `items` field points to only the valid items in the queue, and the extra unused capacity is stored in a separate `cap` field.

#19960

### [Rename std.ChildProcess to std.process.Child](https://ziglang.org/download/0.13.0/release-notes.html#toc-Rename-stdChildProcess-to-stdprocessChild) [§](https://ziglang.org/download/0.13.0/release-notes.html#Rename-stdChildProcess-to-stdprocessChild)

The old name has been deprecated for several releases now.

Upgrade guide:

```
std.ChildProcess
```

↓

```
std.process.Child
```

Some other functions are also moved from `std.ChildProcess` to `std.process` namespace.

In the future there will be even more breaking changes. For example, instead of creating a Child and then setting fields on it and then calling spawn, there will be `std.process.spawn` which takes an "options" parameter and then returns the Child, which is an object that lasts only from spawn until termination. This is a practice that we have been moving more towards in Zig, which is to have types designed to have minimal lifetimes and minimal states with undefined fields.

### [Reworked CLI Progress](https://ziglang.org/download/0.13.0/release-notes.html#toc-Reworked-CLI-Progress) [§](https://ziglang.org/download/0.13.0/release-notes.html#Reworked-CLI-Progress)

Primarily, this is a breaking change to the [Standard Library](https://ziglang.org/download/0.13.0/release-notes.html#Standard-Library). However, the [Compiler](https://ziglang.org/download/0.13.0/release-notes.html#Compiler) and [Build System](https://ziglang.org/download/0.13.0/release-notes.html#Build-System) both lean heavily on this API and are thereby affected.

[simple asciinema demo](https://asciinema.org/a/gDna9RnicwYjDRIDn4e07NFSc) \[[demo source](https://gist.github.com/andrewrk/b22b4f663cef6b4672d7097de95ea343)\]

[demo: building a music player with zig build](https://asciinema.org/a/661404) \[[source code](https://codeberg.org/andrewrk/player)\]

Performance impact: insignificant \[[source](https://github.com/ziglang/zig/pull/20059)\]

Upgrade Guide:

-   Pass around `std.Progress.Node` instead of `*std.Progress.Node` (no longer a pointer).
-   Remove calls to `node.activate()`. Those are not needed anymore.
-   It's now safe to pass short-lived strings to `Node.start` since the data will be copied.
-   It is illegal to initialize `std.Progress` more than once. Do that in main() and nowhere else.
-   Use `std.debug.lockStdErr` and `std.debug.unlockStdErr` before writing to stderr to integrate properly with `std.Progress` (`std.debug.print` already does this for you).

```
var progress = std.Progress{
    ...
};
const root_node = progress.start("Test", test_fn_list.len);
```

↓

```
const root_node = std.Progress.start(.{
    .root_name = "Test",
    .estimated_total_items = test_fn_list.len,
});
```

All the options to `start` are optional.

Finally, when spawning a child process, populate the `progress_node` field first:

```
child.progress_node = node;
try child.spawn();
```

The previous implementation of `std.Progress` had the design limitation that it could not assume ownership of the terminal. This meant that it had to play nicely with sub-processes purely via what was printed to the terminal, and it had to play nicely with progress-unaware stderr writes to the terminal. It also was forbidden from installing a SIGWINCH handler, or running ioctl to find out the rows and cols of the terminal.

The new implementation is designed around the idea that a single process will be the sole owner of the terminal, and all other progress reports will be communicated back to that process. With this change in the requirements, it becomes possible to make a much more useful progress bar.

This creates a standard "Zig Progress Protocol" and uses it so that the same `std.Progress` API works both when an application is the main owner of a terminal, and when an application is a child process. In the latter case, progress information is communicated semantically over a pipe to the parent process.

The file descriptor is given in the `ZIG_PROGRESS` environment variable. `std.process.Child` integrates with this, so attaching a child's progress subtree in a parent process is as easy as setting the `child.progress_node` field before calling `spawn`.

In order to avoid performance penalty for using this API, the `Node.start` and `Node.end` APIs are thread-safe, lock-free, infallible, and do minimal amount of memory loads and stores. In order to accomplish this, a statically allocated buffer of `Node` storage is used - one array for parents, and one array for the rest of the data. Children are not stored. The statically allocated buffer is used for a bespoke `Node` allocator implementation. A static buffer is sufficient because we can set an upper bound on supported terminal width and height. If the terminal size exceeds this, the progress bar output will be truncated regardless.

A separate thread periodically refreshes the terminal on a timer. This progress update thread iterates over the entire preallocated parents array, looking for used nodes. This is efficient because the parents array is only 200 8-bit integers, or about 4 cache lines. When iterating, this thread "serializes" the data into a separate preallocated array by atomically loading from the shared data into data that is only touched by a single thread - the progress update thread. It then looks for nodes that are marked with a file descriptor that is a pipe to a child process. Such nodes are replaced during the serialization process with the data from reading from the pipe. The data can be memcpy'd into place except for the parents array which needs to be relocated. Once this serialization process is complete, there are two paths, one for a child process, and one for the root process that owns the terminal.

The root process that owns the terminal scans the serialized data, computing children and sibling pointers. The canonical data only stores parents, so this is where the tree structure is computed. Then the tree is walked, appending to a static buffer that will be sent to the terminal with a single write() syscall. During this process, the detected rows and cols of the terminal are respected. If the user resizes the terminal, it will cause a SIGWINCH which signals the update thread to wake up and redraw with the new rows and cols.

A child process, instead of drawing to the terminal, takes the same serialized data and sends it across a pipe. The pipe is in non-blocking mode, so if it fills up, the child drops the message; a future update will contain the new progress information. Likewise when the parent reads from the pipe, it discards all messages in the buffer except for the last one. If there are no messages in the pipe, the parent uses the data from the last update.

[Andrew Kelley's blog post on the topic](https://andrewkelley.me/post/zig-new-cli-progress-bar-explained.html)

### [posix.iovec: use .base and .len instead of .iov\_base and .iov\_len](https://ziglang.org/download/0.13.0/release-notes.html#toc-posixiovec-use-base-and-len-instead-of-iov_base-and-iov_len) [§](https://ziglang.org/download/0.13.0/release-notes.html#posixiovec-use-base-and-len-instead-of-iov_base-and-iov_len)

Upgrade guide:

```
.{ .iov_base = message.ptr, .iov_len = message.len },
```

↓

```
.{ .base = message.ptr, .len = message.len },
```

### [Added `std.zip` and Zip Archive Support in `build.zig.zon`](https://ziglang.org/download/0.13.0/release-notes.html#toc-Added-codestdzipcode-and-Zip-Archive-Support-in-codebuildzigzoncode) [§](https://ziglang.org/download/0.13.0/release-notes.html#Added-codestdzipcode-and-Zip-Archive-Support-in-codebuildzigzoncode)

`build.zig.zon` files now support .zip archive dependencies. `std.zip` has also been added which can extract zip files.

## [Build System](https://ziglang.org/download/0.13.0/release-notes.html#toc-Build-System) [§](https://ziglang.org/download/0.13.0/release-notes.html#Build-System)

### [Step.Run: global lock when child inherits stderr](https://ziglang.org/download/0.13.0/release-notes.html#toc-StepRun-global-lock-when-child-inherits-stderr) [§](https://ziglang.org/download/0.13.0/release-notes.html#StepRun-global-lock-when-child-inherits-stderr)

The docs for setting stdio to "inherit" say:

> Causes the Run step to be considered to have side-effects, and therefore always execute when it appears in the build graph. It also means that this step will obtain a global lock to prevent other steps from running in the meantime. The step will fail if the subprocess crashes or returns a non-zero exit code.

The implementation of this lock was missing but is now implemented, ensuring that only one process which owns stdout/stderr is running at a time.

### [Install Windows DLLs to `<prefix>/bin/` by default](https://ziglang.org/download/0.13.0/release-notes.html#toc-Install-Windows-DLLs-to-codeltprefixgtbincode-by-default) [§](https://ziglang.org/download/0.13.0/release-notes.html#Install-Windows-DLLs-to-codeltprefixgtbincode-by-default)

Windows does not support RPATH and only searches for DLLs in a small number of predetermined paths by default, with one of them being the directory from which the application loaded.

Currently, if you build an executable and a DLL, link them and install them with the default settings, the exe will go in `bin/` and the DLL in `lib/`, which makes the exe unable to find the DLL at runtime without manually adding `lib/` to the `PATH` environment variable.

Installing both executables and DLLs to `bin/` by default helps ensure that the executable can find any DLL artifacts it has linked to. DLL import libraries are still installed to `lib/`.

[These defaults match CMake's behavior](https://github.com/ziglang/zig/pull/19743).

Illustrative example:

```
exe.root_module.linkLibrary(sdl3_lib);

b.installArtifact(exe);
b.installArtifact(sdl3_lib);
```

zig-out/
├───bin/
│   ├───example.exe
│   ├───example.pdb
│   ├───SDL3.dll
│   └───SDL3.pdb
├───include/
│   └───SDL3/
│       ├───SDL.h
│       └───<omitted>
└───lib/
    └───SDL3.lib

### [Step.ObjCopy: don't accept multiple sections](https://ziglang.org/download/0.13.0/release-notes.html#toc-StepObjCopy-dont-accept-multiple-sections) [§](https://ziglang.org/download/0.13.0/release-notes.html#StepObjCopy-dont-accept-multiple-sections)

The actual `zig objcopy` does not accept keeping multiple sections. If you pass multiple `-j` `.section` arguments to `zig objcopy`, it will only respect the last one passed.

The build system API now uses a type that reflects this.

## [Compiler](https://ziglang.org/download/0.13.0/release-notes.html#toc-Compiler) [§](https://ziglang.org/download/0.13.0/release-notes.html#Compiler)

### [Replace the `YES_COLOR` env variable with `CLICOLOR_FORCE`](https://ziglang.org/download/0.13.0/release-notes.html#toc-Replace-the-codeYES_COLORcode-env-variable-with-codeCLICOLOR_FORCEcode) [§](https://ziglang.org/download/0.13.0/release-notes.html#Replace-the-codeYES_COLORcode-env-variable-with-codeCLICOLOR_FORCEcode)

Detecting the [`NO_COLOR`](https://no-color.org/) environment variable and disabling color output if set is a standard practice respected by most CLI tools.

When it comes to the inverse task of forcing color output even when not writing to a terminal, there exist two standards, [`CLICOLOR_FORCE`](https://bixense.com/clicolors/) and [`FORCE_COLOR`](https://force-color.org/). Neither of these two standards come even close to being as ubiquitous as `NO_COLOR`, but they both have some precedence and are respected by a handful of CLI tools.

Prior to e45d24c0de29eb6668e56ea927e15505674833a6, Zig used the `ZIG_DEBUG_COLOR` env variable to force color output, but that commit changed it to `YES_COLOR`.

`YES_COLOR` seemingly has next to no precedent in existing software ([a search for `/(?-i)\bYES_COLOR\b/` on GitHub returned 142 files](https://github.com/search?q=%2F%28%3F-i%29%5CbYES_COLOR%5Cb%2F&type=code)).

Instead of throwing a third standard into the mix and making it even harder for users to manage colored output in CLI tooling, it makes more sense to instead tag along with one of `CLICOLOR_FORCE` or `FORCE_COLOR`.

`CLICOLOR_FORCE` is chosen over `FORCE_COLOR` for the following reasons:

-   [https://bixense.com/clicolors/](https://bixense.com/clicolors/), which attempts to standardize `CLICOLOR_FORCE`, was created in 2015. The corresponding [https://force-color.org/](https://force-color.org/) for `FORCE_COLOR` was created in 2023.
-   `CLICOLOR_FORCE` appears to have been introduced by [`ls` in FreeBSD 4.1.1](https://man.freebsd.org/cgi/man.cgi?query=ls&manpath=FreeBSD+4.1.1-RELEASE) in 2000. `FORCE_COLOR` appears to have been introduced by the [chalk JavaScript library](https://github.com/chalk/chalk/releases/tag/v1.0.0) in 2015.
-   `CLICOLOR_FORCE` is supported by CMake and Ninja.
-   While a search for [`/(?-i)\bCLICOLOR_FORCE\b/`](https://github.com/search?q=%2F%28%3F-i%29%5CbCLICOLOR_FORCE%5Cb%2F&type=code) returns 28.9k files and [`/(?-i)\bFORCE_COLOR\b/`](https://github.com/search?q=%2F%28%3F-i%29%5CbFORCE_COLOR%5Cb%2F&type=code) 39k files, the former seems more common with software written in C/C++ while the latter seems more tied to Node.js and Python ecosystems.

In a better universe, someone would have established a convention like `CLICOLOR=ON` or `CLICOLOR=OFF` way back in time so that we wouldn't have to juggle multiple environemnt variables, but that ship has sailed.

`CLICOLOR_FORCE` is also added to the output of `zig env`.

### [LLVM Backend](https://ziglang.org/download/0.13.0/release-notes.html#toc-LLVM-Backend) [§](https://ziglang.org/download/0.13.0/release-notes.html#LLVM-Backend)

loongarch64 support added. It still can't build hello world because [LLVM didn't implement fp\_to\_fp16 for that target yet](https://github.com/llvm/llvm-project/issues/93894).

### [`zig-cache` renamed to `.zig-cache`](https://ziglang.org/download/0.13.0/release-notes.html#toc-codezig-cachecode-renamed-to-codezig-cachecode) [§](https://ziglang.org/download/0.13.0/release-notes.html#codezig-cachecode-renamed-to-codezig-cachecode)

This plays nicely with more tooling. For example, text editors will typically exclude this directory from "find in files" features. It communicates to new users of Zig that these files are ephemeral. I apologize for not getting this right the first time.

`zig-out` is unchanged.

## [Bug Fixes](https://ziglang.org/download/0.13.0/release-notes.html#toc-Bug-Fixes) [§](https://ziglang.org/download/0.13.0/release-notes.html#Bug-Fixes)

[Full list of the 43 bug reports closed during this release cycle](https://github.com/ziglang/zig/issues?q=is%3Aclosed+is%3Aissue+label%3Abug+milestone%3A0.13.0).

Many bugs were both introduced and resolved within this release cycle. Most bug fixes are omitted from these release notes for the sake of brevity.

### [This Release Contains Bugs](https://ziglang.org/download/0.13.0/release-notes.html#toc-This-Release-Contains-Bugs) [§](https://ziglang.org/download/0.13.0/release-notes.html#This-Release-Contains-Bugs)

Zig has [known bugs](https://github.com/ziglang/zig/issues?q=is%3Aopen+is%3Aissue+label%3Abug) and even some [miscompilations](https://github.com/ziglang/zig/issues?q=is%3Aopen+is%3Aissue+label%3Amiscompilation).

Zig is immature. Even with Zig 0.13.0, working on a non-trivial project using Zig will likely require participating in the development process.

When Zig reaches 1.0.0, [Tier 1 Support](https://ziglang.org/download/0.13.0/release-notes.html#Tier-1-Support) will gain a bug policy as an additional requirement.

## [Toolchain](https://ziglang.org/download/0.13.0/release-notes.html#toc-Toolchain) [§](https://ziglang.org/download/0.13.0/release-notes.html#Toolchain)

### [LLVM 18](https://ziglang.org/download/0.13.0/release-notes.html#toc-LLVM-18) [§](https://ziglang.org/download/0.13.0/release-notes.html#LLVM-18)

This release of Zig upgrades to [LLVM 18.1.7](https://releases.llvm.org/18.1.0/docs/ReleaseNotes.html).

This was the primary motivation for tagging the 0.13.0 release.

### [musl 1.2.5](https://ziglang.org/download/0.13.0/release-notes.html#toc-musl-125) [§](https://ziglang.org/download/0.13.0/release-notes.html#musl-125)

Zig ships with the source code to [musl](http://musl.libc.org/). When the musl C ABI is selected, Zig builds static musl from source for the selected target. Zig also supports targeting dynamically linked musl which is useful for Linux distributions that use it as their system libc, such as [Alpine Linux](https://www.alpinelinux.org/).

This release upgrades from v1.2.4 to v1.2.5.

### [glibc 2.39](https://ziglang.org/download/0.13.0/release-notes.html#toc-glibc-239) [§](https://ziglang.org/download/0.13.0/release-notes.html#glibc-239)

glibc version 2.39 are now available when cross-compiling.

## [Roadmap](https://ziglang.org/download/0.13.0/release-notes.html#toc-Roadmap) [§](https://ziglang.org/download/0.13.0/release-notes.html#Roadmap)

The major theme of the 0.14.0 release cycle will be **compilation speed**.

Some upcoming milestones we will be working towards in the 0.14.0 release cycle:

-   Making the x86 Backend the default backend for debug mode.
-   Linker support for COFF. Eliminate dependency on [LLD](https://lld.llvm.org/).
-   Enabling incremental compilation for fast rebuilds.
-   Introduce Concurrency to semantic analysis to further increase compilation speed.

The idea here is that prioritizing faster compilation will increase development velocity on the [Compiler](https://ziglang.org/download/0.13.0/release-notes.html#Compiler) itself, leading to more bugs fixed and features completed in the following release cycles.

It also could potentially lead to language changes that unblock fast compilation.

## [Thank You Contributors!](https://ziglang.org/download/0.13.0/release-notes.html#toc-Thank-You-Contributors) [§](https://ziglang.org/download/0.13.0/release-notes.html#Thank-You-Contributors)

Here are all the people who landed at least one contribution into this release:

-   Andrew Kelley
-   David Rubin
-   Jakub Konka
-   Jacob Young
-   Ryan Liptak
-   Veikka Tuominen
-   Eric Joldasov
-   Wooster
-   Frank Denis
-   Hampus Fröjdholm
-   Matthew Lugg
-   Christofer Nolander
-   Motiejus Jakštys
-   Pat Tullmann
-   clickingbuttons
-   Carl Åstholm
-   Eric Joldasov
-   Garfield Lee
-   Linus Groh
-   Marc Tiehuis
-   Markus F.X.J. Oberhumer
-   Sean
-   Travis Staloch
-   antlilja
-   expikr
-   february cozzocrea
-   190n
-   Abhinav Gupta
-   Alain Greppin
-   Alex Kladov
-   Alexandre Janon
-   Antonio Gomes
-   Ben Crist
-   Casey Banner
-   Dominic
-   Evan Haas
-   George Thayamkery
-   Georgijs
-   Igor Anić
-   IntegratedQuantum
-   Jared Baur
-   Jiacai Liu
-   Jonathan Marler
-   Jordan Yates
-   Julian
-   Kang Seonghoon
-   Karl Bohlmark
-   Lucas Santos
-   Maciej 'vesim' Kuliński
-   Manlio Perillo
-   Marco F
-   Meghan Denny
-   Michael Dusan
-   Nameless
-   Pavel Verigo
-   Pyrolistical
-   Pyry Kovanen
-   Ridai Govinda Pombo
-   Ronald Chen
-   Simon Brown
-   T. M
-   Tim Culverhouse
-   Vahur Sinijärv
-   Wes Koerber
-   Xavier Bouchoux
-   YANG Xudong
-   daurnimator
-   freakmangd
-   koenditor
-   orvit
-   poypoyan
-   reokodoku
-   zhylmzr

## [Thank You Sponsors!](https://ziglang.org/download/0.13.0/release-notes.html#toc-Thank-You-Sponsors) [§](https://ziglang.org/download/0.13.0/release-notes.html#Thank-You-Sponsors)

Special thanks to those who [sponsor Zig](https://ziglang.org/zsf/). Because of recurring donations, Zig is driven by the open source community, rather than the goal of making profit. In particular, these fine folks sponsor Zig for $50/month or more:

-   [Josh Wolfe](https://github.com/thejoshwolfe)
-   [Matt Knight](https://mattnite.net/)
-   [Stevie Hryciw](https://www.hryx.net/)
-   [Jethro Nederhof](https://jethron.id.au/)
-   [Karrick McDermott](https://hachyderm.io/@karrick)
-   [José M Rico](https://www.kapricornmedia.com/)
-   [drfuchs](https://github.com/drfuchs)
-   [Joran Dirk Greef](https://github.com/tigerbeetle/tigerbeetle)
-   [Rui Ueyama](https://github.com/rui314)
-   [bfredl](https://github.com/bfredl)
-   [Simon A. Nielsen Knights](https://git.sr.ht/~tauoverpi)
-   [Stephen Gutekanst](https://slimsag.com/)
-   [Derek Collison](https://derekcollison.net/)
-   [Daniele Cocca](https://github.com/jmc-88)
-   [Rafael Batiati](https://twitter.com/rbatiati)
-   [Aras Pranckevičius](https://aras-p.info/)
-   [Terin Stock](https://terinstock.com/)
-   [Loïc Tosser](https://kalvad.com/)
-   [Kirk Scheibelhut](https://scheibo.com/)
-   [Mitchell Hashimoto](https://mitchellh.com/)
-   [Brian Gold](https://github.com/briangold)
-   [Paul Harrington](https://github.com/phrrngtn)
-   [Clark Gaebel](https://github.com/cgaebel)
-   [Bun](https://bun.sh/)
-   [Marcus Eagan](https://www.marcus.art/)
-   [Ken Chilton](https://www.chilton-consulting.com/)
-   [Sebastian](https://twitter.com/soworston)
-   [Will Manning](https://twitter.com/_willmanning)
-   [Spiral](https://spiraldb.com/)
-   [Alex Mackenzie at Tapestry VC](https://mack.work/)
-   [Alok Parlikar](http://www.parlikar.com/)
-   [Viktor Tratsevskyy](https://www.horster.org/)
-   [johnpyp](https://github.com/johnpyp)
-   [Huly® Platform™](https://huly.io/)
-   [Transloadit](https://transloadit.com/)
-   Reuben Dunnington
-   Isaac Yonemoto
-   Luuk de Gram
-   Auguste Rame
-   Jay Petacat
-   Dirk de Visser
-   Santiago Andaluz
-   Andrew Mangogna
-   Yaroslav Zhavoronkov
-   Christian Wesselhoeft
-   Anton Kochkov
-   Max Bernstein
-   James McGill
-   Luke Champine
-   AG.王爱国
-   Wojtek Mach
-   Nicola Larosa
-   Daniel Hensley
-   cryptocode
-   Erik Mållberg
-   Collin Kemper
-   Fabio Arnold
-   Ross Rheingans-Yoo
-   Justin "J.R." Hill
-   Mykhailo Tsiuptsiun
-   Kiril Mihaylov
-   Brett Slatkin
-   Sean Carey
-   Yurii Rashkovskii
-   Benjamin Ebby
-   Ralph Brorsen
-   OM PropTech GmbH
-   Alex Sergeev
-   Kemal Akkoyun
-   Marco Munizaga
-   Josh Ashby
-   Chris Baldwin
-   Malcolm Still
-   Viktor Hellström
-   Francis Bouvier
-   Fawzi Mohamed
-   Alve Larsson
-   Nicolas Goy
-   Ian Johnson
-   Carlos Pizano Uribe
-   Rene Schallner
-   Linus Groh
-   Jinkyu Yi
-   jake hemmerle
-   Will Pragnell
-   Peter Snelgrove
-   Jeff Fowler
-   Nate Diven
-   Colton Franklin
-   Christian Gibson
-   impactaky
-   Dylan Conway
-   Hlib Kanunnikov
-   merkleplant
-   Omar AlSuwaidi
-   Duncan Marsh
