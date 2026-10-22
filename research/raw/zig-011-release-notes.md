# 0.11.0 Release Notes ⚡ The Zig Programming Language

<https://ziglang.org/download/0.11.0/release-notes.html>

# 0.11.0 Release Notes

[Download & Documentation](https://ziglang.org/download/#release-0.11.0)

Zig is a general-purpose programming language and toolchain for maintaining **robust**, **optimal**, and **reusable** software.

Backed by the [Zig Software Foundation](https://ziglang.org/zsf/), the project is **financially sustainable**. These core team members are paid for their time:

-   [Andrew Kelley](https://andrewkelley.me/)
-   [Loris Cro](https://kristoff.it/)
-   [Jakub Konka](http://www.jakubkonka.com/)
-   [Veikka Tuominen](https://vexu.eu/)
-   [Jacob Young](https://github.com/jacobly0)

Please consider a [recurring donation to the ZSF](https://ziglang.org/zsf/) to help us pay more contributors!

This release features **8 months of work**: changes from **269 different contributors**, spread among **4457 commits**. It is the début of [Package Management](https://ziglang.org/download/0.11.0/release-notes.html#Package-Management).

## [Table of Contents](https://ziglang.org/download/0.11.0/release-notes.html#toc-Table-of-Contents) [§](https://ziglang.org/download/0.11.0/release-notes.html#Table-of-Contents)

-   [Table of Contents](https://ziglang.org/download/0.11.0/release-notes.html#Table-of-Contents)
-   [Support Table](https://ziglang.org/download/0.11.0/release-notes.html#Support-Table)
    -   [Tier System](https://ziglang.org/download/0.11.0/release-notes.html#Tier-System)
        -   [Tier 1 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support)
        -   [Tier 2 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support)
        -   [Tier 3 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-3-Support)
        -   [Tier 4 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-4-Support)
    -   [CPU Architectures](https://ziglang.org/download/0.11.0/release-notes.html#CPU-Architectures)
        -   [x86](https://ziglang.org/download/0.11.0/release-notes.html#x86)
        -   [ARM](https://ziglang.org/download/0.11.0/release-notes.html#ARM)
        -   [WebAssembly](https://ziglang.org/download/0.11.0/release-notes.html#WebAssembly)
            -   [WasmAllocator](https://ziglang.org/download/0.11.0/release-notes.html#WasmAllocator)
        -   [PowerPC](https://ziglang.org/download/0.11.0/release-notes.html#PowerPC)
        -   [AVR](https://ziglang.org/download/0.11.0/release-notes.html#AVR)
        -   [GPGPU](https://ziglang.org/download/0.11.0/release-notes.html#GPGPU)
    -   [Operating Systems](https://ziglang.org/download/0.11.0/release-notes.html#Operating-Systems)
        -   [Windows](https://ziglang.org/download/0.11.0/release-notes.html#Windows)
            -   [Resource Files (.res)](https://ziglang.org/download/0.11.0/release-notes.html#Resource-Files-res)
            -   [Support UNC, Rooted, Drive-Relative, and Namespaced/Device Paths](https://ziglang.org/download/0.11.0/release-notes.html#Support-UNC-Rooted-Drive-Relative-and-NamespacedDevice-Paths)
            -   [ARM64 Windows](https://ziglang.org/download/0.11.0/release-notes.html#ARM64-Windows)
        -   [Linux](https://ziglang.org/download/0.11.0/release-notes.html#Linux)
        -   [macOS](https://ziglang.org/download/0.11.0/release-notes.html#macOS)
        -   [FreeBSD](https://ziglang.org/download/0.11.0/release-notes.html#FreeBSD)
        -   [OpenBSD](https://ziglang.org/download/0.11.0/release-notes.html#OpenBSD)
        -   [NetBSD](https://ziglang.org/download/0.11.0/release-notes.html#NetBSD)
        -   [WASI](https://ziglang.org/download/0.11.0/release-notes.html#WASI)
            -   [Give Executable Bit to wasm Executables](https://ziglang.org/download/0.11.0/release-notes.html#Give-Executable-Bit-to-wasm-Executables)
        -   [UEFI](https://ziglang.org/download/0.11.0/release-notes.html#UEFI)
        -   [Plan9](https://ziglang.org/download/0.11.0/release-notes.html#Plan9)
-   [Documentation](https://ziglang.org/download/0.11.0/release-notes.html#Documentation)
    -   [Language Reference](https://ziglang.org/download/0.11.0/release-notes.html#Language-Reference)
    -   [Autodoc](https://ziglang.org/download/0.11.0/release-notes.html#Autodoc)
        -   [New Search System](https://ziglang.org/download/0.11.0/release-notes.html#New-Search-System)
        -   [Other Improvements](https://ziglang.org/download/0.11.0/release-notes.html#Other-Improvements)
-   [Language Changes](https://ziglang.org/download/0.11.0/release-notes.html#Language-Changes)
    -   [Peer Type Resolution Improvements](https://ziglang.org/download/0.11.0/release-notes.html#Peer-Type-Resolution-Improvements)
    -   [Multi-Object For Loops](https://ziglang.org/download/0.11.0/release-notes.html#Multi-Object-For-Loops)
    -   [@memcpy and @memset](https://ziglang.org/download/0.11.0/release-notes.html#memcpy-and-memset)
    -   [@min and @max](https://ziglang.org/download/0.11.0/release-notes.html#min-and-max)
    -   [@trap](https://ziglang.org/download/0.11.0/release-notes.html#trap)
    -   [@inComptime](https://ziglang.org/download/0.11.0/release-notes.html#inComptime)
    -   [Split @qualCast into @constCast and @volatileCast](https://ziglang.org/download/0.11.0/release-notes.html#Split-qualCast-into-constCast-and-volatileCast)
    -   [Rename Casting Builtins](https://ziglang.org/download/0.11.0/release-notes.html#Rename-Casting-Builtins)
    -   [Cast Inference](https://ziglang.org/download/0.11.0/release-notes.html#Cast-Inference)
        -   [Pointer Casts](https://ziglang.org/download/0.11.0/release-notes.html#Pointer-Casts)
        -   [@splat](https://ziglang.org/download/0.11.0/release-notes.html#splat)
    -   [Tuple Type Declarations](https://ziglang.org/download/0.11.0/release-notes.html#Tuple-Type-Declarations)
    -   [Concatenation of Arrays and Tuples](https://ziglang.org/download/0.11.0/release-notes.html#Concatenation-of-Arrays-and-Tuples)
    -   [Allow Indexing Tuple and Vector Pointers](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Indexing-Tuple-and-Vector-Pointers)
    -   [Overflow Builtins Return Tuples](https://ziglang.org/download/0.11.0/release-notes.html#Overflow-Builtins-Return-Tuples)
    -   [Slicing By Length](https://ziglang.org/download/0.11.0/release-notes.html#Slicing-By-Length)
    -   [Inline Function Call Comptime Propagation](https://ziglang.org/download/0.11.0/release-notes.html#Inline-Function-Call-Comptime-Propagation)
    -   [Exporting C Variadic Functions](https://ziglang.org/download/0.11.0/release-notes.html#Exporting-C-Variadic-Functions)
    -   [Added c\_char Type](https://ziglang.org/download/0.11.0/release-notes.html#Added-c_char-Type)
    -   [Forbid Runtime Operations in comptime Blocks](https://ziglang.org/download/0.11.0/release-notes.html#Forbid-Runtime-Operations-in-comptime-Blocks-)
    -   [@intFromBool always returns u1](https://ziglang.org/download/0.11.0/release-notes.html#intFromBool-always-returns-u1)
    -   [@fieldParentPtr Supports Unions](https://ziglang.org/download/0.11.0/release-notes.html#fieldParentPtr-Supports-Unions)
    -   [@typeInfo No Longer Returns Private Declarations](https://ziglang.org/download/0.11.0/release-notes.html#typeInfo-No-Longer-Returns-Private-Declarations)
    -   [Zero-Sized Fields Allowed in Extern Structs](https://ziglang.org/download/0.11.0/release-notes.html#Zero-Sized-Fields-Allowed-in-Extern-Structs)
    -   [Eliminate Bound Functions](https://ziglang.org/download/0.11.0/release-notes.html#Eliminate-Bound-Functions)
    -   [@call Stack](https://ziglang.org/download/0.11.0/release-notes.html#call-Stack)
    -   [Allow Tautological Integer Comparisons](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Tautological-Integer-Comparisons)
    -   [Forbid Source Files Being Part of Multiple Modules](https://ziglang.org/download/0.11.0/release-notes.html#Forbid-Source-Files-Being-Part-of-Multiple-Modules)
    -   [Single-Item Array Pointers Gain .ptr Field](https://ziglang.org/download/0.11.0/release-notes.html#Single-Item-Array-Pointers-Gain-ptr-Field)
    -   [Allow Method Call Syntax on Optional Pointers](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Method-Call-Syntax-on-Optional-Pointers)
    -   [comptime Function Calls No Longer Cause Runtime Analysis](https://ziglang.org/download/0.11.0/release-notes.html#comptime-Function-Calls-No-Longer-Cause-Runtime-Analysis)
    -   [Multi-Item Switch Prong Type Coercion](https://ziglang.org/download/0.11.0/release-notes.html#Multi-Item-Switch-Prong-Type-Coercion)
    -   [Allow Functions to Return null and undefined](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Functions-to-Return-null-and-undefined)
    -   [Generic Function Calls](https://ziglang.org/download/0.11.0/release-notes.html#Generic-Function-Calls)
    -   [Naked Functions](https://ziglang.org/download/0.11.0/release-notes.html#Naked-Functions)
    -   [@embedFile Supports Module-Mapped Names](https://ziglang.org/download/0.11.0/release-notes.html#embedFile-Supports-Module-Mapped-Names)
-   [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library)
    -   [Compile-Time Configuration Consolidated](https://ziglang.org/download/0.11.0/release-notes.html#Compile-Time-Configuration-Consolidated)
    -   [Memory Allocation](https://ziglang.org/download/0.11.0/release-notes.html#Memory-Allocation)
        -   [Allow Shrink To Fail](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Shrink-To-Fail)
    -   [Strings](https://ziglang.org/download/0.11.0/release-notes.html#Strings)
        -   [Restrict mem.span and mem.len to Sentinel-Terminated Pointers](https://ziglang.org/download/0.11.0/release-notes.html#Restrict-memspan-and-memlen-to-Sentinel-Terminated-Pointers)
    -   [Math](https://ziglang.org/download/0.11.0/release-notes.html#Math)
    -   [File System](https://ziglang.org/download/0.11.0/release-notes.html#File-System)
    -   [Data Structures](https://ziglang.org/download/0.11.0/release-notes.html#Data-Structures)
    -   [Sorting](https://ziglang.org/download/0.11.0/release-notes.html#Sorting)
    -   [Compression](https://ziglang.org/download/0.11.0/release-notes.html#Compression)
    -   [Crypto](https://ziglang.org/download/0.11.0/release-notes.html#Crypto)
        -   [New Features](https://ziglang.org/download/0.11.0/release-notes.html#New-Features)
        -   [Breaking Changes](https://ziglang.org/download/0.11.0/release-notes.html#Breaking-Changes)
        -   [Keccak](https://ziglang.org/download/0.11.0/release-notes.html#Keccak)
        -   [Kyber](https://ziglang.org/download/0.11.0/release-notes.html#Kyber)
        -   [Constant-Time, Allocation-Free Field Arithmetic](https://ziglang.org/download/0.11.0/release-notes.html#Constant-Time-Allocation-Free-Field-Arithmetic)
        -   [Configurable Side Channels Mitigations](https://ziglang.org/download/0.11.0/release-notes.html#Configurable-Side-Channels-Mitigations)
        -   [Hello Ascon; Farewell to Gimli and Xoodoo](https://ziglang.org/download/0.11.0/release-notes.html#Hello-Ascon-Farewell-to-Gimli-and-Xoodoo)
        -   [std.crypto Bug Fixes](https://ziglang.org/download/0.11.0/release-notes.html#stdcrypto-Bug-Fixes)
        -   [Performance Improvements](https://ziglang.org/download/0.11.0/release-notes.html#Performance-Improvements)
    -   [Concurrency](https://ziglang.org/download/0.11.0/release-notes.html#Concurrency)
    -   [Networking](https://ziglang.org/download/0.11.0/release-notes.html#Networking)
        -   [TLS Client](https://ziglang.org/download/0.11.0/release-notes.html#TLS-Client)
        -   [HTTP Client](https://ziglang.org/download/0.11.0/release-notes.html#HTTP-Client)
        -   [Ignore SIGPIPE by Default](https://ziglang.org/download/0.11.0/release-notes.html#Ignore-SIGPIPE-by-Default)
    -   [Testing](https://ziglang.org/download/0.11.0/release-notes.html#Testing)
    -   [Debugging](https://ziglang.org/download/0.11.0/release-notes.html#Debugging)
        -   [Stack Unwinding](https://ziglang.org/download/0.11.0/release-notes.html#Stack-Unwinding)
        -   [External Debug Info](https://ziglang.org/download/0.11.0/release-notes.html#External-Debug-Info)
    -   [Formatted Printing](https://ziglang.org/download/0.11.0/release-notes.html#Formatted-Printing)
    -   [JSON](https://ziglang.org/download/0.11.0/release-notes.html#JSON)
        -   [`parse` replaced by `parseFromSlice` or other `parseFrom*`](https://ziglang.org/download/0.11.0/release-notes.html#codeparsecode-replaced-by-codeparseFromSlicecode-or-other-codeparseFromcode)
            -   [`parseFree` replaced by `Parsed(T).deinit()`](https://ziglang.org/download/0.11.0/release-notes.html#codeparseFreecode-replaced-by-codeParsedTdeinitcode)
        -   [`Parser.parse` replaced by `parseFromSlice` into `Value`](https://ziglang.org/download/0.11.0/release-notes.html#codeParserparsecode-replaced-by-codeparseFromSlicecode-into-codeValuecode)
            -   [`ValueTree` replaced by `Parsed(Value)`](https://ziglang.org/download/0.11.0/release-notes.html#codeValueTreecode-replaced-by-codeParsedValuecode)
        -   [`writeStream` API simplification](https://ziglang.org/download/0.11.0/release-notes.html#codewriteStreamcode-API-simplification)
            -   [Custom `jsonStringify` signature changed](https://ziglang.org/download/0.11.0/release-notes.html#Custom-codejsonStringifycode-signature-changed)
            -   [`stringify` limits nesting to 256 by default](https://ziglang.org/download/0.11.0/release-notes.html#codestringifycode-limits-nesting-to-256-by-default)
        -   [`StringifyOptions` overhauled](https://ziglang.org/download/0.11.0/release-notes.html#codeStringifyOptionscode-overhauled)
        -   [`TokenStream` replaced by `Scanner`](https://ziglang.org/download/0.11.0/release-notes.html#codeTokenStreamcode-replaced-by-codeScannercode)
        -   [`StreamingParser` replaced by `Reader`](https://ziglang.org/download/0.11.0/release-notes.html#codeStreamingParsercode-replaced-by-codeReadercode)
        -   [parse/stringify for `union` types](https://ziglang.org/download/0.11.0/release-notes.html#parsestringify-for-codeunioncode-types)
        -   [An allocator is always required for parsing now](https://ziglang.org/download/0.11.0/release-notes.html#An-allocator-is-always-required-for-parsing-now)
    -   [posix\_spawn Considered Harmful](https://ziglang.org/download/0.11.0/release-notes.html#posix_spawn-Considered-Harmful)
-   [Build System](https://ziglang.org/download/0.11.0/release-notes.html#Build-System)
    -   [Terminology Changes](https://ziglang.org/download/0.11.0/release-notes.html#Terminology-Changes)
    -   [Rename Types and Functions](https://ziglang.org/download/0.11.0/release-notes.html#Rename-Types-and-Functions)
    -   [Target and Optimization](https://ziglang.org/download/0.11.0/release-notes.html#Target-and-Optimization)
    -   [Package Management](https://ziglang.org/download/0.11.0/release-notes.html#Package-Management)
    -   [Install and Run Executables](https://ziglang.org/download/0.11.0/release-notes.html#Install-and-Run-Executables)
    -   [Compiler Protocol](https://ziglang.org/download/0.11.0/release-notes.html#Compiler-Protocol)
    -   [Build Summary](https://ziglang.org/download/0.11.0/release-notes.html#Build-Summary)
    -   [Custom Build Runners](https://ziglang.org/download/0.11.0/release-notes.html#Custom-Build-Runners)
    -   [Share the Compiler's Cache System](https://ziglang.org/download/0.11.0/release-notes.html#Share-the-Compilers-Cache-System)
    -   [Steps Run In Parallel](https://ziglang.org/download/0.11.0/release-notes.html#Steps-Run-In-Parallel)
    -   [Embrace LazyPath for Inputs and Outputs](https://ziglang.org/download/0.11.0/release-notes.html#Embrace-LazyPath-for-Inputs-and-Outputs)
    -   [System Resource Awareness](https://ziglang.org/download/0.11.0/release-notes.html#System-Resource-Awareness)
    -   [Foreign Target Execution and Testing](https://ziglang.org/download/0.11.0/release-notes.html#Foreign-Target-Execution-and-Testing)
    -   [Configuration File Generation](https://ziglang.org/download/0.11.0/release-notes.html#Configuration-File-Generation)
    -   [Run Step Enhancements](https://ziglang.org/download/0.11.0/release-notes.html#Run-Step-Enhancements)
    -   [addTest No Longer Runs It](https://ziglang.org/download/0.11.0/release-notes.html#addTest-No-Longer-Runs-It)
-   [Compiler](https://ziglang.org/download/0.11.0/release-notes.html#Compiler)
    -   [Performance](https://ziglang.org/download/0.11.0/release-notes.html#Performance)
    -   [Bootstrapping](https://ziglang.org/download/0.11.0/release-notes.html#Bootstrapping)
    -   [Reproducible Builds](https://ziglang.org/download/0.11.0/release-notes.html#Reproducible-Builds)
    -   [C ABI Compatibility](https://ziglang.org/download/0.11.0/release-notes.html#C-ABI-Compatibility)
    -   [C Translation](https://ziglang.org/download/0.11.0/release-notes.html#C-Translation)
    -   [Cache System](https://ziglang.org/download/0.11.0/release-notes.html#Cache-System)
    -   [Code Generation](https://ziglang.org/download/0.11.0/release-notes.html#Code-Generation)
        -   [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend)
        -   [C Backend](https://ziglang.org/download/0.11.0/release-notes.html#C-Backend)
        -   [x86 Backend](https://ziglang.org/download/0.11.0/release-notes.html#x86-Backend)
        -   [WebAssembly Backend](https://ziglang.org/download/0.11.0/release-notes.html#WebAssembly-Backend)
        -   [SPIR-V Backend](https://ziglang.org/download/0.11.0/release-notes.html#SPIR-V-Backend)
        -   [aarch64 Backend](https://ziglang.org/download/0.11.0/release-notes.html#aarch64-Backend)
    -   [Error Return Tracing](https://ziglang.org/download/0.11.0/release-notes.html#Error-Return-Tracing)
    -   [Safety Checks](https://ziglang.org/download/0.11.0/release-notes.html#Safety-Checks)
    -   [Struct Field Order](https://ziglang.org/download/0.11.0/release-notes.html#Struct-Field-Order)
    -   [Incremental Compilation](https://ziglang.org/download/0.11.0/release-notes.html#Incremental-Compilation)
    -   [New Module CLI](https://ziglang.org/download/0.11.0/release-notes.html#New-Module-CLI)
-   [Linker](https://ziglang.org/download/0.11.0/release-notes.html#Linker)
    -   [MachO](https://ziglang.org/download/0.11.0/release-notes.html#MachO)
    -   [COFF](https://ziglang.org/download/0.11.0/release-notes.html#COFF)
    -   [ELF](https://ziglang.org/download/0.11.0/release-notes.html#ELF)
    -   [WASM Modules](https://ziglang.org/download/0.11.0/release-notes.html#WASM-Modules)
    -   [DWARF](https://ziglang.org/download/0.11.0/release-notes.html#DWARF)
    -   [Move Library Path Resolution to the Frontend](https://ziglang.org/download/0.11.0/release-notes.html#Move-Library-Path-Resolution-to-the-Frontend)
-   [Bug Fixes](https://ziglang.org/download/0.11.0/release-notes.html#Bug-Fixes)
    -   [This Release Contains Bugs](https://ziglang.org/download/0.11.0/release-notes.html#This-Release-Contains-Bugs)
    -   [Bug Stability Program](https://ziglang.org/download/0.11.0/release-notes.html#Bug-Stability-Program)
-   [Toolchain](https://ziglang.org/download/0.11.0/release-notes.html#Toolchain)
    -   [LLVM 16](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-16)
    -   [musl 1.2.4](https://ziglang.org/download/0.11.0/release-notes.html#musl-124)
    -   [glibc 2.34](https://ziglang.org/download/0.11.0/release-notes.html#glibc-234)
    -   [mingw-w64 10.0.0](https://ziglang.org/download/0.11.0/release-notes.html#mingw-w64-1000)
    -   [WASI-libc](https://ziglang.org/download/0.11.0/release-notes.html#WASI-libc)
    -   [compiler-rt](https://ziglang.org/download/0.11.0/release-notes.html#compiler-rt)
        -   [Bundling Into Object Files](https://ziglang.org/download/0.11.0/release-notes.html#Bundling-Into-Object-Files)
    -   [zig cc](https://ziglang.org/download/0.11.0/release-notes.html#zig-cc)
        -   [Fail Hard on Unsupported Linker Flags](https://ziglang.org/download/0.11.0/release-notes.html#Fail-Hard-on-Unsupported-Linker-Flags)
    -   [zig c++](https://ziglang.org/download/0.11.0/release-notes.html#zig-c)
    -   [zig fmt](https://ziglang.org/download/0.11.0/release-notes.html#zig-fmt)
        -   [Canonicalization of Identifiers](https://ziglang.org/download/0.11.0/release-notes.html#Canonicalization-of-Identifiers)
    -   [zig objcopy](https://ziglang.org/download/0.11.0/release-notes.html#zig-objcopy)
-   [Roadmap](https://ziglang.org/download/0.11.0/release-notes.html#Roadmap)
    -   [Accepted Proposals](https://ziglang.org/download/0.11.0/release-notes.html#Accepted-Proposals)
-   [Thank You Contributors!](https://ziglang.org/download/0.11.0/release-notes.html#Thank-You-Contributors)
-   [Thank You Sponsors!](https://ziglang.org/download/0.11.0/release-notes.html#Thank-You-Sponsors)

## [Support Table](https://ziglang.org/download/0.11.0/release-notes.html#toc-Support-Table) [§](https://ziglang.org/download/0.11.0/release-notes.html#Support-Table)

### [Tier System](https://ziglang.org/download/0.11.0/release-notes.html#toc-Tier-System) [§](https://ziglang.org/download/0.11.0/release-notes.html#Tier-System)

A green check mark (✅) indicates the target meets all the requirements for the support tier. The other icons indicate what is _preventing the target from reaching the support tier_. In other words, the icons are **to-do items**. If you find any wrong data here please [submit a pull request](https://github.com/ziglang/www.ziglang.org)!

#### [Tier 1 Support](https://ziglang.org/download/0.11.0/release-notes.html#toc-Tier-1-Support) [§](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support)

-   Not only can Zig generate machine code for these targets, but the [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) cross-platform abstractions have implementations for these targets.
-   The CI server automatically tests these targets on every commit to master branch. The 🧪 icon means this target does not yet have CI test coverage.
-   The CI server automatically produces pre-built binaries for these targets, on every commit to master, and updates [the download page](https://ziglang.org/download/) with links. The 📦 icon means the download page is missing this target.
-   These targets have [debug info capabilities](https://ziglang.org/download/0.11.0/release-notes.html#Debugging) and therefore produce stack traces on failed assertions.
-   libc is available for this target even when cross compiling.
-   All the behavior tests and applicable standard library tests pass for this target. All language features are known to work correctly. Experimental features do not count towards disqualifying an operating system or architecture from Tier 1. The 🐛 icon means there are known [bugs](https://ziglang.org/download/0.11.0/release-notes.html#This-Release-Contains-Bugs) preventing this target from reaching Tier 1.
-   [zig cc](https://ziglang.org/download/0.11.0/release-notes.html#zig-cc), [zig c++](https://ziglang.org/download/0.11.0/release-notes.html#zig-c), and related toolchain commands support this target.
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

#### [Tier 2 Support](https://ziglang.org/download/0.11.0/release-notes.html#toc-Tier-2-Support) [§](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support)

-   The [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) supports this target, but it is possible that some APIs will give an "Unsupported OS" compile error. One can link with libc or other libraries to fill in the gaps in the standard library. The 📖 icon means the standard library is too incomplete to be considered Tier 2 worthy.
-   These targets are known to work, but may not be automatically tested, so there are occasional regressions. 🔍 means that nobody has really looked into this target so whether or not it works is unknown.
-   Some tests may be disabled for these targets as we work toward [Tier 1 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support).

|  | free standing | Linux 3.16+ | macOS 11+ | Windows 10+ | FreeBSD 12.0+ | NetBSD 8.0+ | Dragon FlyBSD 5.8+ | OpenBSD 7.3+ | UEFI |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| x86\_64 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | ✅ | ✅ | ✅ | ✅ |
| x86 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | 💀 | ✅ | 🔍 | 🔍 | N/A | 🔍 | ✅ |
| aarch64 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | 🔍 | 🔍 | N/A | 🔍 | 🔍 |
| arm | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | 💀 | 🔍 | 🔍 | 🔍 | N/A | 🔍 | 🔍 |
| mips64 | ✅ | ✅ | N/A | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |
| mips | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | N/A | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |
| powerpc64 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | 💀 | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |
| powerpc | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | 💀 | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |
| riscv64 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | N/A | N/A | 🔍 | 🔍 | N/A | 🔍 | 🔍 |
| sparc64 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ | N/A | N/A | 🔍 | 🔍 | N/A | 🔍 | N/A |

#### [Tier 3 Support](https://ziglang.org/download/0.11.0/release-notes.html#toc-Tier-3-Support) [§](https://ziglang.org/download/0.11.0/release-notes.html#Tier-3-Support)

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
| x86\_64 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) |
| x86 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | ✅ | ✅ | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) |
| aarch64 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | ✅ | ✅ | ✅ |
| arm | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | ✅ | ✅ | ✅ | ✅ |
| mips64 | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | N/A |
| mips | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | N/A |
| riscv64 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | ✅ |
| powerpc32 | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | N/A |
| powerpc64 | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | [Tier 2](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) | N/A | ✅ | ✅ | N/A |
| bpf | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| hexagon | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| amdgcn | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| sparc | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| s390x | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| lanai | ✅ | ✅ | N/A | ✅ | ✅ | N/A |
| csky | ✅ | ✅ | N/A | ✅ | ✅ | N/A |

|  | freestanding | emscripten |
| --- | --- | --- |
| wasm32 | [Tier 1](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) | ✅ |

#### [Tier 4 Support](https://ziglang.org/download/0.11.0/release-notes.html#toc-Tier-4-Support) [§](https://ziglang.org/download/0.11.0/release-notes.html#Tier-4-Support)

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

### [CPU Architectures](https://ziglang.org/download/0.11.0/release-notes.html#toc-CPU-Architectures) [§](https://ziglang.org/download/0.11.0/release-notes.html#CPU-Architectures)

#### [x86](https://ziglang.org/download/0.11.0/release-notes.html#toc-x86) [§](https://ziglang.org/download/0.11.0/release-notes.html#x86)

The baseline value used for "i386" was a pentium4 CPU model, which is actually i686. It is also possible to target a more bare bones CPU than pentium4. Therefore it is more correct to use "x86" rather than "i386" for this CPU architecture. This architecture has been renamed in the CLI and [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) APIs ([#4663](https://github.com/ziglang/zig/issues/4663)).

#### [ARM](https://ziglang.org/download/0.11.0/release-notes.html#toc-ARM) [§](https://ziglang.org/download/0.11.0/release-notes.html#ARM)

Removed the always-single-threaded limitation for libc++ ([#6573](https://github.com/ziglang/zig/issues/6573)).

Fixed [Bootstrapping](https://ziglang.org/download/0.11.0/release-notes.html#Bootstrapping) on this host.

Development builds of Zig are now available on the [download page](https://ziglang.org/download) with every successful CI run.

#### [WebAssembly](https://ziglang.org/download/0.11.0/release-notes.html#toc-WebAssembly) [§](https://ziglang.org/download/0.11.0/release-notes.html#WebAssembly)

[Luuk de Gram](https://github.com/Luukdegram) writes:

Starting from this release, Zig no longer unconditionally passes `--allow-undefined` to the [Linker](https://ziglang.org/download/0.11.0/release-notes.html#Linker). By removing this flag, the user will now be faced with an error during the linking stage rather than a panic during runtime for undefined functions. If your project requires such behavior, the flag `import-symbols` can be used, which will allow undefined symbols during linking.

For this change we also had to update the strategy of exporting all symbols to the host. We no longer unconditionally export all symbols to the host. Previously this would result in unwanted symbols existing in the final binary. By default we now only export the symbol to the linker, meaning they will only be visible to other object files so they can be resolved correctly. If you wish to export a symbol to the host environment, the flag `--export=[name]` can be used. Alternatively, the flag `-rdynamic` can be used to export all visible symbols to the host environment. By setting the `visibility` field to `.hidden` on `std.builtin.ExportOptions` a symbol will remain only visible to the linker and not be exported to the host. With this breaking change, the linker will behave the same whether a user is using [zig cc](https://ziglang.org/download/0.11.0/release-notes.html#zig-cc) or Clang directly.

##### [WasmAllocator](https://ziglang.org/download/0.11.0/release-notes.html#toc-WasmAllocator) [§](https://ziglang.org/download/0.11.0/release-notes.html#WasmAllocator)

The [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) gained `std.heap.wasm_allocator`, a WebAssembly-only simple, fast, and small allocator ([#13513](https://github.com/ziglang/zig/issues/13513)). It is able to simultaneously achieve all three of these things thanks to the new [Memory Allocation](https://ziglang.org/download/0.11.0/release-notes.html#Memory-Allocation) API of Zig 0.11.0 which [allows shrink to fail](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Shrink-To-Fail).

example.zig

```
const std = @import("std");
export fn alloc() ?*i32 {
    return std.heap.wasm_allocator.create(i32) catch null;
}
export fn free(p: *i32) void {
    std.heap.wasm_allocator.destroy(p);
}
```

Compiled with `-target wasm32-freestanding -OReleaseSmall`, this example produces a 1 KB wasm object file. It is used as the memory allocator when [Bootstrapping](https://ziglang.org/download/0.11.0/release-notes.html#Bootstrapping) Zig.

#### [PowerPC](https://ziglang.org/download/0.11.0/release-notes.html#toc-PowerPC) [§](https://ziglang.org/download/0.11.0/release-notes.html#PowerPC)

A couple enhancements to [zig cc](https://ziglang.org/download/0.11.0/release-notes.html#zig-cc) and [compiler-rt](https://ziglang.org/download/0.11.0/release-notes.html#compiler-rt).

#### [AVR](https://ziglang.org/download/0.11.0/release-notes.html#toc-AVR) [§](https://ziglang.org/download/0.11.0/release-notes.html#AVR)

AVR remains an experimental target, however, in this release cycle, the [Compiler](https://ziglang.org/download/0.11.0/release-notes.html#Compiler) implements AVR address spaces, and places functions on AVR in the flash address space.

#### [GPGPU](https://ziglang.org/download/0.11.0/release-notes.html#toc-GPGPU) [§](https://ziglang.org/download/0.11.0/release-notes.html#GPGPU)

[Robin "Snektron" Voetter](https://github.com/Snektron/) writes:

Three new built-in functions are added to aid with writing GPGPU kernels in Zig: `@workGroupId`, `@workItemId`, and `@workGroupSize`. These are respectively used to query the index of the work group of the current thread in a kernel invocation, the size of a work group in threads, and the thread index in the current work group. For now, these are only wired up to work when compiling Zig to AMD GCN machine code via LLVM, that can be used with ROCm. In the future they will be added to the LLVM-based NVPTX and self-hosted SPIR-V backends as well.

For example, the following Zig GPU kernel performs a simple reduction on its inputs:

example.zig

```
const block_dim = 256;
var shared: [block_dim]f32 addrspace(.shared) = undefined;

export fn reduce(in: [*]addrspace(.global) f32, out: [*]addrspace(.global) f32) callconv(.Kernel) void {
    const tid = @workItemId(0);
    const bid = @workGroupId(0);
    shared[tid] = in[bid * block_dim + tid];
    comptime var i: usize = 1;
    inline while (i < block_dim) : (i *= 2) {
        if (tid % (i * 2) == 0) shared[tid] += shared[tid + i];
        asm volatile ("s_barrier");
    }
    if (tid == 0) out[bid] = shared[0];
}
```

This kernel can be compiled to a HIP module for use with ROCm using Zig and clang-offload-bundler:

Shell

$ zig build-obj -target amdgcn-amdhsa-none -mcpu=gfx1100 ./test.zig
$ clang-offload-bundler -type=o -bundle-align=4096 \\
    -targets=host-x86\_64-unknown-linux,hipv4-amdgcn-amd-amdhsa--gfx1100
    -input=/dev/null -input=./test.o -output=module.co

The resulting module can be loaded directly using `hipModuleLoadData` and executed using `hipModuleLaunchKernel`.

### [Operating Systems](https://ziglang.org/download/0.11.0/release-notes.html#toc-Operating-Systems) [§](https://ziglang.org/download/0.11.0/release-notes.html#Operating-Systems)

#### [Windows](https://ziglang.org/download/0.11.0/release-notes.html#toc-Windows) [§](https://ziglang.org/download/0.11.0/release-notes.html#Windows)

The officially supported minimum version of Windows is now 10, because [Microsoft dropped LTS support for 8.1 in January](https://support.microsoft.com/en-us/help/13853/windows-lifecycle-fact-sheet). Patches to Zig supporting for older versions of Windows are still accepted into the codebase, but they are not regularly tested, not part of the [Bug Stability Program](https://ziglang.org/download/0.11.0/release-notes.html#Bug-Stability-Program), and not covered by the [Tier System](https://ziglang.org/download/0.11.0/release-notes.html#Tier-System).

-   Fix \_tls\_index not being defined if libc wasn't linked, and fix x86 name mangling.
-   replace GetPhysicallyInstalledSystemMemory with ntdll ([#15264](https://github.com/ziglang/zig/issues/15264)).
-   std.os.sendto: use ws2\_32 on Windows ([#9971](https://github.com/ziglang/zig/issues/9971)).
-   std.os.windows: add possible error NETNAME\_DELETED of ReadFile ([#13631](https://github.com/ziglang/zig/issues/13631))
-   std: implement os.mprotect on Windows
-   Implement root certificate scanning for the [TLS Client](https://ziglang.org/download/0.11.0/release-notes.html#TLS-Client) ([#14229](https://github.com/ziglang/zig/issues/14229))
-   debug info lookup improvements ([#14247](https://github.com/ziglang/zig/issues/14247))
-   std.debug.TTY: Fix colors not resetting on Windows
-   std.os.windows.ReadLink: add missing alignment of local data buffer
-   os: windows: fix unhandled error
-   Detect ANSI support in more terminals ([#16080](https://github.com/ziglang/zig/issues/16080)).
-   windows.sendto fix ([#15831](https://github.com/ziglang/zig/issues/15831))
-   std.c: fix return type of recv/recvfrom on windows
-   debug: fix missing stack traces during crashes on windows
-   debug: replace RtlCaptureStackBackTrace (which was spuriously failing) with a new implementation which uses RtlVirtualUnwind instead ([#12740](https://github.com/ziglang/zig/issues/12740))
-   windows.OpenFile/DeleteFile: Add NetworkNotFound as a possible error. When calling NtCreateFile with a UNC path, if either \`\\\\server\` or \`\\\\server\\share\` are not found, then the statuses \`BAD\_NETWORK\_PATH\` or \`BAD\_NETWORK\_NAME\` are returned (respectively).
-   Remove std.os.windows.QueryInformationFile (a wrapper of NtQueryInformationFile). This function was unused, and implementation contained a few footguns.
-   std.process: Fix crash on some Windows machines
-   std.os.windows.DeviceIoControl: Handle INVALID\_DEVICE\_REQUEST. This is possible when e.g. calling CreateSymbolicLink on a FAT32 filesystem
-   child\_process: Fix regression on Windows for FAT filesystems ([#16374](https://github.com/ziglang/zig/issues/16374)).
-   DeleteFile: Use FileDispositionInformationEx if possible, but fallback if not ([#16499](https://github.com/ziglang/zig/issues/16499)).
-   advapi32: Add RegCloseKey
-   `spawnWindows`: Improve worst-case performance considerably + tests ([#13993](https://github.com/ziglang/zig/issues/13993))
-   `ChildProcess.spawnWindows`: `PATH` search fixes + optimizations ([#13983](https://github.com/ziglang/zig/issues/13983))
-   Fix GetFileInformationByHandle compile error ([#14829](https://github.com/ziglang/zig/issues/14829))
-   \`std.coff\`: check strtab lengths against \`data\` length. Fixes illegal behavior. Invalid-length sections are now skipped in \`Coff.getSectionByName\`.

##### [Resource Files (.res)](https://ziglang.org/download/0.11.0/release-notes.html#toc-Resource-Files-res) [§](https://ziglang.org/download/0.11.0/release-notes.html#Resource-Files-res)

Zig now recognizes the `.res` extension and links it as if it were an object file ([#6488](https://github.com/ziglang/zig/issues/6488)).

`.res` files are compiled Windows resource files that get linked into executables/libraries. The linker knows what to do with them, but previously you had to trick Zig into thinking it was an object file (by renaming it to have the .obj extension, for example).

Now, the following works:

```
zig build-exe main.zig resource.res
```

or, in build.zig:

```
exe.addObjectFile("resource.res");
```

##### [Support UNC, Rooted, Drive-Relative, and Namespaced/Device Paths](https://ziglang.org/download/0.11.0/release-notes.html#toc-Support-UNC-Rooted-Drive-Relative-and-NamespacedDevice-Paths) [§](https://ziglang.org/download/0.11.0/release-notes.html#Support-UNC-Rooted-Drive-Relative-and-NamespacedDevice-Paths)

[Windows: Support UNC, rooted, drive relative, and namespaced/device paths](https://github.com/ziglang/zig/pull/15768)

##### [ARM64 Windows](https://ziglang.org/download/0.11.0/release-notes.html#toc-ARM64-Windows) [§](https://ziglang.org/download/0.11.0/release-notes.html#ARM64-Windows)

In this release, 64-bit ARM (aarch64) Windows becomes a [Tier 2 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) target. Zip files are available on [the download page](https://ziglang.org/download) and this target is tested with every commit to source control. However, there are [known bugs](https://github.com/ziglang/zig/issues/16665) preventing this target from reaching [Tier 1 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support).

-   Add CPU feature detection for ARMv8 processors on Windows - the feature detection is based on parsing Windows registry values which contain a read-only view at the contents of `EL1` system ID registers. The values are mapped as `CP 40xx` registry keys which we now pull and parse for CPU feature information.
-   Introduce `system/arm.zig` containing CPU model table. Now we can reuse the table between CPU model parsers on [Linux](https://ziglang.org/download/0.11.0/release-notes.html#Linux) and Windows.
-   Fixed aarch64-windows-gnu libc. We were missing some math functions. After this enhancement I verified that I was able to cross-compile ninja.exe for aarch64-windows and produce a viable binary.
-   [C Backend](https://ziglang.org/download/0.11.0/release-notes.html#C-Backend): fixed compiling for aarch64-windows. These bugs were triggered in the C backend by aarch64-specific code in os/windows.zig.

#### [Linux](https://ziglang.org/download/0.11.0/release-notes.html#toc-Linux) [§](https://ziglang.org/download/0.11.0/release-notes.html#Linux)

-   Fix missing pthread\_key\_t definition on linux ([#13950](https://github.com/ziglang/zig/issues/13950)).
-   linux.bpf: expose map\_get\_next\_key
-   fix CPU model detection for neoverse\_n1 on aarch64-linux ([#10086](https://github.com/ziglang/zig/issues/10086))
-   stdlib: make linux.PERF.TYPE non-exhaustive
-   std.os.linux: Add setitimer and getitimer syscalls
-   Fixes to linux/bpf/btf.zig
-   std.os.linux.T: translate more MIPS values
-   fix type errors in os.linux ([#15801](https://github.com/ziglang/zig/issues/15801))
-   Add tcsetpgrp and tcgetpgrp to std.os.linux
-   std.os.linux: fix incorrect struct definition
-   std.os.linux: Add new CAP constants
-   linux: do not set stack size hard limit
-   std.os.linux | Fix sendmmsg function ([#16513](https://github.com/ziglang/zig/issues/16513))
-   std.os: Allow write functions to return INVAL errors. In Linux when interacting with the virtual file system when writing in invalid value to a file the OS will return errno 22 (INVAL). Instead of triggering an unreachable, this change now returns a newly introduced error.InvalidArgument.
-   std.os: Add DeviceBusy as a possible write error. In Linux when writing to various files in the virtual file system, for example /sys/fs/cgroup, if you write an invalid value to a file you'll get errno 16.
-   Update Linux syscall list for 6.1, support Mips64 ([#14541](https://github.com/ziglang/zig/issues/14541))
-   bpf: expose "syscall" program type and F\_SLEEPABLE flag
-   bpf: correct return type of ringbuf\_output helper
-   io\_uring: Change ordering of prep provide buffers args

#### [macOS](https://ziglang.org/download/0.11.0/release-notes.html#toc-macOS) [§](https://ziglang.org/download/0.11.0/release-notes.html#macOS)

Catalina (version 10.15) is unsupported by Apple as of November 30, 2022. Likewise, Zig 0.11.0 drops support for this version.

-   expose `ptrace` syscall with errno handling
-   expose more Mach kernel primitives for issuing user-land Mach messages
-   remove incorrect assertion in `readMachODebugInfo` panicking during panic - this fixes a class of bugs on macOS where a segfault happening in a loaded dylib with no debug info would cause a panic in the panic handler instead of simply noting that the dylib has no valid debug info via `error.MissingDebugInfo`. An example could be code linking some system dylib and causing some routine to segfault on say invalid pointer value, which should normally cause Zig to print an incomplete stack trace anchored at the currently loaded image and backtrace all the way back to the Zig binary with valid debug info. Currently, in a situation like this we would trigger a panic within a panic.
-   update macOS libc headers and `libSystem.tbd` to macOS 13
-   bump max macOS version to 13.3
-   fix parsing of SDK version string into `std.SemanticVersion`
-   std.os.darwin: drop underscore from SIG.\_{BLOCK,UNBLOCK,SETMASK}. this makes them match decls in other OSes
-   std.macho: add missing defs of compact unwind info records

#### [FreeBSD](https://ziglang.org/download/0.11.0/release-notes.html#toc-FreeBSD) [§](https://ziglang.org/download/0.11.0/release-notes.html#FreeBSD)

-   FreeBSD: add mcontext\_t for aarch64, enabling [stack traces](https://ziglang.org/download/0.11.0/release-notes.html#Debugging) when a segmentation fault occurs.
-   std.os: take advantage of `copy_file_range`
-   std.process.totalSystemMemory: return correct error type on FreeBSD
-   Progress towards BSD [Tier 2 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-2-Support) ([#13700](https://github.com/ziglang/zig/issues/13700))

#### [OpenBSD](https://ziglang.org/download/0.11.0/release-notes.html#toc-OpenBSD) [§](https://ziglang.org/download/0.11.0/release-notes.html#OpenBSD)

-   openbsd: fix NativeTargetInfo semver
-   fix bad return types for BSDs getdents and debitrot openbsd ([#16052](https://github.com/ziglang/zig/issues/16052)).
-   std.c: openbsd sigcontext/ucontext fix enum
-   fix std.Thread name buffer size

#### [NetBSD](https://ziglang.org/download/0.11.0/release-notes.html#toc-NetBSD) [§](https://ziglang.org/download/0.11.0/release-notes.html#NetBSD)

-   use versioned \_\_msync13 from libc ([#14422](https://github.com/ziglang/zig/issues/14422))
-   Add termios constants to std.c.netbsd
-   pkgsrc ([#15511](https://github.com/ziglang/zig/issues/15511))

#### [WASI](https://ziglang.org/download/0.11.0/release-notes.html#toc-WASI) [§](https://ziglang.org/download/0.11.0/release-notes.html#WASI)

[Luuk de Gram](https://github.com/Luukdegram) writes:

In this release-cycle the [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) gained experimental support for WASI-threads. This means it will be possible to create a multi-threaded application when targeting WASI without having to change your codebase. Keep in mind that the feature is still in proposal phase 1 of the WASI specification, so support within the standard library is still experimental and bugs are to be expected. As the feature is still experimental, we still default to single-threaded builds when targeting WebAssembly. To disable this, one can pass `-fno-single-threaded` in combination with the `--shared-memory` flags. This also requires the CPU features `atomics` and `bulk-memory` to be enabled.

The same flags will also work for freestanding [WebAssembly](https://ziglang.org/download/0.11.0/release-notes.html#WebAssembly) modules, allowing a user to build a multi-threaded WebAssembly module for other runtimes. Be aware that the threads in the standard library are only available for WASI. For freestanding, the user must implement their own such as Web Workers when building a WebAssembly module for the browser.

-   wasi: fixes IterableDir.nextWasi for large directory ([#13725](https://github.com/ziglang/zig/issues/13725))
-   Implement some more environment functions for WASI.
-   Fix bug in WASI environment variable handling ([#14121](https://github.com/ziglang/zig/issues/14121)).
-   wasi: fixes os.isatty on type mismatch ([#13813](https://github.com/ziglang/zig/issues/13813))
-   wasi: remove unnecessary breakpoint() in abort

##### [Give Executable Bit to wasm Executables](https://ziglang.org/download/0.11.0/release-notes.html#toc-Give-Executable-Bit-to-wasm-Executables) [§](https://ziglang.org/download/0.11.0/release-notes.html#Give-Executable-Bit-to-wasm-Executables)

Zig now gives `+x` to the `.wasm` file if it is an executable and the OS is WASI. Some systems may be configured to execute such binaries directly. Even if that is not the case, it means we will get "exec format error" when trying to run it rather than "access denied", and then can react to that in the same way as trying to run an ELF file from a foreign CPU architecture.

This is part of the strategy for [Foreign Target Execution and Testing](https://ziglang.org/download/0.11.0/release-notes.html#Foreign-Target-Execution-and-Testing).

#### [UEFI](https://ziglang.org/download/0.11.0/release-notes.html#toc-UEFI) [§](https://ziglang.org/download/0.11.0/release-notes.html#UEFI)

-   Delete unneeded alignment and use default 4K ([#7484](https://github.com/ziglang/zig/issues/7484)).
-   Do not use -fPIC when compiling a UEFI application.
-   Fixed wrong calling convention used sometimes ([#16339](https://github.com/ziglang/zig/issues/16339)).
-   Fixed bug where not enough memory was allocated for the header or to align the pointer.
-   Delete unnecessary padding and fix number\_of\_pages type
-   check for UEFI in io.StreamSource
-   implement std.time.sleep for uefi
-   fix alignment error in uefi FileInfo protocol
-   std.os.uefi: fix shift in pool allocator ([#14497](https://github.com/ziglang/zig/issues/14497)).

#### [Plan9](https://ziglang.org/download/0.11.0/release-notes.html#toc-Plan9) [§](https://ziglang.org/download/0.11.0/release-notes.html#Plan9)

[Jacob G-W](https://github.com/g-w1) writes:

During this release cycle, the Plan 9 [Linker](https://ziglang.org/download/0.11.0/release-notes.html#Linker) backend has been updated so that it can link most code from the [x86 Backend](https://ziglang.org/download/0.11.0/release-notes.html#x86-Backend). The [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) has also been improved, broadening its support for Plan 9's features:

-   Introduced a `page_allocator` implementation for Plan 9, employing the `SbrkAllocator` available in the standard library. This addition now permits [Memory Allocation](https://ziglang.org/download/0.11.0/release-notes.html#Memory-Allocation) on Plan 9.
-   New functions have been added to facilitate interaction with the filesystem, ensuring that `std.fs` works. This is a crucial improvement, as Plan 9 heavily utilizes filesystem interfaces for system interactions.
-   Added the ability to read the top-of-stack struct, allowing access to process PID and clock cycle information.
-   Support for `std.os.plan9.errstr` has been implemented, enabling users to read error messages from system calls that return `-1`. However, as error messages in Plan 9 are string-based, additional efforts will be needed to make these errors interface with Zig errors.

## [Documentation](https://ziglang.org/download/0.11.0/release-notes.html#toc-Documentation) [§](https://ziglang.org/download/0.11.0/release-notes.html#Documentation)

### [Language Reference](https://ziglang.org/download/0.11.0/release-notes.html#toc-Language-Reference) [§](https://ziglang.org/download/0.11.0/release-notes.html#Language-Reference)

Minor changes and upkeep to the [language reference](https://ziglang.org/documentation/0.11.0/). Nothing major with this release.

### [Autodoc](https://ziglang.org/download/0.11.0/release-notes.html#toc-Autodoc) [§](https://ziglang.org/download/0.11.0/release-notes.html#Autodoc)

This feature is still experimental.

[Loris Cro](https://kristoff.it/) writes:

Thank you to all contributors who helped with Autodoc in this release cycle.

In particular welcome to two new Autodoc contributors:

-   [Emile Badenhorst](https://github.com/Myvar)
-   [Ian Johnson](https://github.com/ianprime0509)

And renewed thanks to long term Autodoc contributor [Krzysztof Wolicki](https://github.com/der-teufel-programming).

#### [New Search System](https://ziglang.org/download/0.11.0/release-notes.html#toc-New-Search-System) [§](https://ziglang.org/download/0.11.0/release-notes.html#New-Search-System)

When searching, right below the search box, you will now see a new expandable help section that explains how to use the new search system more effectively ([#15475](https://github.com/ziglang/zig/issues/15475)). The text is reported here:

-   Matching
    -   Search is case-insensitive by default.
    -   Using uppercase letters in your query will make the search case-sensitive.
    -   Given `ArrayListUnmanaged`:
        -   the following words (and their prefixes) will match:
            -   `array`
            -   `list`
            -   `unmanaged`
        -   the following words will **NOT** match:
            -   `stun`
            -   `ray`
            -   `managed`
    -   More precisely, the search system is based on a Radix Tree. The Radix Tree contains full decl names plus some suffixes, split by following the official style guide (e.g. `HashMapUnmanaged` also produces `MapUnmanaged` and `Unmanaged`, same with snake\_case and camelCase names).
-   Multiple terms
    -   When a search query contains multiple terms, order doesn't matter when all terms match within a single decl name (e.g. "map auto" will match `AutoHashMap`).
    -   Query term order does matter when matching different decls alongside a path (e.g. "js parse" matching `std.json.parse`), in which case the order of the terms will determine whether the match goes above or below the "other results" line.
    -   As an example, "fs create" will put above the line all things related to the creation of files and directories inside of `std.fs`, while still showing (but below the line) matches from `std.Build`.
    -   As another example, "fs windows" will prioritize windows-related results in `std.fs`, while "windows fs" will prioritize "fs"-related results in `std.windows`.
    -   This means that if you're searching inside a target namespace, you never have to read below the "other results" line.
    -   Since matching doesn't have to be perfect, you can also target a group of namespaces to search into. For example "array orderedremove" will show you all "Array-" namespaces that support orderedRemove.
    -   Periods are replaced by spaces because the Radix Tree doesn't index full paths, and in practice you should expect the match scoring system to consistently give you what you're looking for even when your query path is split into multiple terms.

#### [Other Improvements](https://ziglang.org/download/0.11.0/release-notes.html#toc-Other-Improvements) [§](https://ziglang.org/download/0.11.0/release-notes.html#Other-Improvements)

-   Added missing support for the following language features:
    
    -   Top-level doc comments (`//!`)
    -   Tuple structs
    -   `usingnamespace`
    -   Default values in structs and enums
    -   Improved handling of calling conventions
    -   Rendering of backing integers for packed structs
    -   Rendering of `_` function parameter names
    -   Rendering of boolean operators
    -   **Doctests are now supported!**
        
        -   Doctests are tests that are meant to be part of the documentation. You can create a doc test by giving it the name of a decl like so:
            
            example.zig
            
            ```
            const MyType = struct {
              // ...
            };
            
            test MyType {
              // Referencing a decl directly makes this a doctest!
              //
              // This test is meant to showcase usage of MyType 
              // and will be shown by Autodoc.
            }
            
            test "normal test" {
              // This is a normal test that will not be shown
              // by Autodoc.
            }
            ```
            
            Check out `std.json` for some more examples.
            
-   Added a Zig tokenizer to Autodoc for better source rendering ([#16306](https://github.com/ziglang/zig/issues/16306)).
-   Improved support for more Markdown syntax in rendering of doc comments.
-   Fixed broken links to various elements.
-   Links to private decls now lead you to source listings.
-   Improved rendering of comptime expressions.
-   Fixed rendering of function pointer types.
-   Added the ability to expand function descriptions ([#14260](https://github.com/ziglang/zig/issues/14260)).
-   Initial support for guides, see the "Guides" section in a build of Autodoc for more info.
-   Single-backtick mentions of importable identifiers in doc comments or guides will now be linked to their corresponding Autodoc page.
-   Pressing `/` will focus the searchbar on all browsers except Firefox. You can use the new Autodoc preferences (`p`) menu to enable it also on Firefox.
-   Fixed a crash related to complex expressions in function calls.
-   Autodoc now properly integrates with the cache system of the Zig compiler ([#15864](https://github.com/ziglang/zig/issues/15864)).

## [Language Changes](https://ziglang.org/download/0.11.0/release-notes.html#toc-Language-Changes) [§](https://ziglang.org/download/0.11.0/release-notes.html#Language-Changes)

-   Changed bits field of `builtin.Type.Int` and `builtin.Type.Float` to a `u16` instead of `comptime_int`.
-   Replaced `builtin.Version` with `SemanticVersion`.

### [Peer Type Resolution Improvements](https://ziglang.org/download/0.11.0/release-notes.html#toc-Peer-Type-Resolution-Improvements) [§](https://ziglang.org/download/0.11.0/release-notes.html#Peer-Type-Resolution-Improvements)

The [Peer Type Resolution](https://ziglang.org/documentation/0.11.0/#Peer-Type-Resolution) algorithm has been improved to resolve more types and in a more consistent manner. Below are a few examples which did not resolve correctly in 0.10 but do now.

| Peer Types | Resolved Type |
| --- | --- |
| `[:s]const T`, `[]T` | `[]const T` |
| `E!*T`, `?*T` | `E!?*T` |
| `[*c]T`, `@TypeOf(null)` | `[*c]T` |
| `?u32`, `u8` | `?u32` |
| `[2]u32`, `struct { u32, u32 }` | `[2]u32` |
| `*const @TypeOf(.{})`, `[]const u8` | `[]const u8` |

### [Multi-Object For Loops](https://ziglang.org/download/0.11.0/release-notes.html#toc-Multi-Object-For-Loops) [§](https://ziglang.org/download/0.11.0/release-notes.html#Multi-Object-For-Loops)

This release cycle introduces [multi-object `for` loops](https://github.com/ziglang/zig/pull/14671) into the Zig language. This is a new construct providing a way to cleanly iterate over multiple sequences of the same length.

Consider the case of mapping a function over an array. Previously, your code may have looked like this:

map\_func\_old.zig

```
const std = @import("std");

test "double integer values in sequence" {
    const input: []const u32 = &.{ 1, 2, 3 };
    const output = try std.testing.allocator.alloc(u32, input.len);
    defer std.testing.allocator.free(output);

    for (input) |x, i| {
        output[i] = x * 2;
    }

    try std.testing.expectEqualSlices(u32, &.{ 2, 4, 6 }, output);
}
```

This code has an unfortunate property: in the loop, we had to make the arbitrary choice to iterate over `input`, using the captured index `i` to access the corresponding element in `output`. With multi-object for loops, this code becomes much cleaner:

map\_func\_new.zig

```
const std = @import("std");

test "double integer values in sequence" {
    const input: []const u32 = &.{ 1, 2, 3 };
    const output = try std.testing.allocator.alloc(u32, input.len);
    defer std.testing.allocator.free(output);

    for (input, output) |x, *out| {
        out.* = x * 2;
    }

    try std.testing.expectEqualSlices(u32, &.{ 2, 4, 6 }, output);
}
```

Shell

$ zig test map\_func\_new.zig
1/1 test.double integer values in sequence... OK
All 1 tests passed.

In this new code, we use the new for loop syntax to iterate over both slices simultaneously, capturing the output element by reference so we can write to it. The index capture is no longer necessary in this case. Note that this is not limited to two operands: arbitrarily many slices can be passed to the loop provided each has a corresponding capture. The language asserts that all passed slices have the same length: if they do not, this is safety-checked [Undefined Behavior](https://ziglang.org/documentation/0.11.0/#Undefined-Behavior).

Previously, index captures were implicitly provided if you added a second identifier to the loop's captures. With the new multi-object loops, this has changed. As well as standard expressions, the operand passed to a for loop can also be a _range_. These take the form `a..` or `a..b`, with the latter form being exclusive on the upper bound. If an upper bound is provided, `b - a` must match the length of any given slices (or other bounded ranges). If no upper bound is provided, the loop is bounded based on other range or slice operands. All for loops must be bounded (i.e. you cannot iterate over only an unbounded range). The old behavior is equivalent to adding a trailing `0..` operand to the loop.

for\_index\_capture.zig

```
const std = @import("std");

test "index capture in for loop" {
    const vals: []const u32 = &.{ 10, 11, 12, 13 };

    // We can use an unbounded range, since vals provides a length
    for (vals, 0..) |x, i| {
        try std.testing.expectEqual(i + 10, x);
    }

    // We can also use a bounded range, provided its length matches
    for (vals, 0..4) |x, i| {
        try std.testing.expectEqual(i + 10, x);
    }

    // The lower bound does not need to be 0
    for (vals, 10..) |x, i| {
        try std.testing.expectEqual(i, x);
    }

    // The range does not need to come last
    for (10..14, vals) |i, x| {
        try std.testing.expectEqual(i, x);
    }
    
    // You can have multiple captures of any kind
    for (10..14, vals, vals, 0..) |i, val, *val_ptr, j| {
        try std.testing.expectEqual(i, j + 10);
        try std.testing.expectEqual(i, val);
        try std.testing.expectEqual(i, val_ptr.*);
    }
}
```

Shell

$ zig test for\_index\_capture.zig
1/1 test.index capture in for loop... OK
All 1 tests passed.

The lower and upper bounds of ranges are of type `usize`, as is the capture, since this feature is primarily intended for iterating over data in memory. Note that it is valid to loop over only a range:

for\_range\_only.zig

```
const std = @import("std");

test "for loop over range" {
    var val: usize = 0;
    for (0..20) |i| {
        try std.testing.expectEqual(val, i);
        val += 1;
    }
}
```

Shell

$ zig test for\_range\_only.zig
1/1 test.for loop over range... OK
All 1 tests passed.

To automatically migrate old code, `zig fmt` automatically adds `0..` operands to loops with an index capture and no corresponding operand.

The behavior of pointer captures in for loops has changed slightly. Previously, the following code was valid, but now it emits a compile error:

pointer\_capture\_from\_array.zig

```
const std = @import("std");

test "pointer capture from array" {
    var arr: [3]u8 = undefined;
    for (arr) |*x| {
        x.* = 123;
    }
    try std.testing.expectEqualSlices(u8, &arr, &.{ 123, 123, 123 });
}
```

Shell

$ zig test pointer\_capture\_from\_array.zig
docgen\_tmp/pointer\_capture\_from\_array.zig:5:16: error: pointer capture of non pointer type '\[3\]u8'
    for (arr) |\*x| {
               ^~~
docgen\_tmp/pointer\_capture\_from\_array.zig:5:10: note: consider using '&' here
    for (arr) |\*x| {
         ^~~

This code previously worked because the language implicitly took a reference to `arr`. This no longer happens: if you use a pointer capture, the corresponding iterable must be a pointer or slice. In this case, the fix - as suggested by the error note - is simply to take a reference to the array.

pointer\_capture\_from\_array\_pointer.zig

```
const std = @import("std");

test "pointer capture from array" {
    var arr: [3]u8 = undefined;
    for (&arr) |*x| {
        x.* = 123;
    }
    try std.testing.expectEqualSlices(u8, &arr, &.{ 123, 123, 123 });
}
```

Shell

$ zig test pointer\_capture\_from\_array\_pointer.zig
1/1 test.pointer capture from array... OK
All 1 tests passed.

### [@memcpy and @memset](https://ziglang.org/download/0.11.0/release-notes.html#toc-memcpy-and-memset) [§](https://ziglang.org/download/0.11.0/release-notes.html#memcpy-and-memset)

0.11.0 changes the usage of the builtins `@memcpy` and `@memset` to make them more useful.

`@memcpy` now takes two parameters. The first is the destination, and the second is the source. The builtin copies values from the source address to the destination address. Both parameters may be a slice or many-pointer of any element type; the destination parameter must be mutable in either case. At least one of the parameters must be a slice; if both parameters are a slice, then the two slices must be of equal length.

The source and destination memory must not overlap (overlap is considered safety-checked [Undefined Behavior](https://ziglang.org/documentation/0.11.0/#Undefined-Behavior)). This is one of the key motivators for using this builtin over the standard library.

memcpy.zig

```
const std = @import("std");

test "@memcpy usage" {
    const a: [4]u32 = .{ 1, 2, 3, 4 };

    var b: [4]u32 = undefined;
    @memcpy(&b, &a);
    try std.testing.expectEqualSlices(u32, &a, &b);

    // If the second operand is a many-ptr, the length is taken from the first operand
    var c: [4]u32 = undefined;
    const a_manyptr: [*]const u32 = (&a).ptr;
    @memcpy(&c, a_manyptr);
    try std.testing.expectEqualSlices(u32, &a, &c);
}
```

Shell

$ zig test memcpy.zig
1/1 test.@memcpy usage... OK
All 1 tests passed.

Since this builtin now encompasses the most common use case of `std.mem.copy`, that function has been renamed to `std.mem.copyForwards`. Like `copyBackwards`, the only use case for that function is when the source and destination slices overlap, meaning elements must be copied in a particular order. When migrating code, it is safe to replace all uses of `copy` with `copyForwards`, but potentially more optimal and clearer to instead use `@memcpy` provided the slices are guaranteed not to overlap.

`@memset` has also changed signature. It takes two parameters: the first is a mutable slice of any element type, and the second is a value which is coerced to that element type. All values referenced by the destination slice are set the provided value.

memset.zig

```
const std = @import("std");

test "@memset usage" {
    var a: [4]u32 = undefined;
    @memset(&a, 10);

    try std.testing.expectEqualSlices(u32, &.{ 10, 10, 10, 10 }, &a);
}
```

Shell

$ zig test memset.zig
1/1 test.@memset usage... OK
All 1 tests passed.

This builtin now precisely encompasses the former use cases of `std.mem.set`. Therefore, this standard library function has been removed in favor of the builtin.

### [@min and @max](https://ziglang.org/download/0.11.0/release-notes.html#toc-min-and-max) [§](https://ziglang.org/download/0.11.0/release-notes.html#min-and-max)

The builtins `@min` and `@max` have undergone two key changes. The first is that they now take arbitrarily many arguments, finding the minimum/maximum value across _all_ arguments: for instance, `@min(2, 1, 3) == 1`. The second change relates to the type returned by these operations. Previously, [Peer Type Resolution](https://ziglang.org/documentation/0.11.0/#Peer-Type-Resolution) was used to unify the operand types. However, this sometimes led to redundant uses of `@intCast`: for instance `@min(some_u16, 255)` can always fit in a `u8`. To avoid this, when these operations are performed on integers (or vectors thereof), the compiler will now notice comptime-known bounds of the result (based on either comptime-known operands or on differing operand types) and refine the result type as tightly as possible.

min\_max.zig

```
const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;

test "@min/@max takes arbitrarily many arguments" {
    try expectEqual(11, @min(19, 11, 35, 18));
    try expectEqual(35, @max(19, 11, 35, 18));
}

test "@min/@max refines result type" {
    const x: u8 = 20; // comptime-known
    var y: u64 = 12345;
    // Since an exact bound is comptime-known, the result must fit in a u5
    comptime assert(@TypeOf(@min(x, y)) == u5);

    var x_rt: u8 = x; // runtime-known
    // Since one argument to @min is a u8, the result must fit in a u8
    comptime assert(@TypeOf(@min(x_rt, y)) == u8);
}
```

Shell

$ zig test min\_max.zig
1/2 test.@min/@max takes arbitrarily many arguments... OK
2/2 test.@min/@max refines result type... OK
All 2 tests passed.

This is a breaking change, as any usage of these values without an explicit type annotation may now result in overflow: for instance, `@min(my_u32, 255) + 1` used to be always valid but may now overflow. This is solved with explicit type annotations, either with `@as` or using an intermediate `const`.

Since these changes have been applied to the builtin functions, several standard library functions are now redundant. Therefore, the following functions have been deprecated:

-   `std.math.min`
-   `std.math.max`
-   `std.math.min3`
-   `std.math.max3`

For more information on these changes, see [the proposal](https://github.com/ziglang/zig/issues/14039) and [the PR implementing it](https://github.com/ziglang/zig/pull/15522).

### [@trap](https://ziglang.org/download/0.11.0/release-notes.html#toc-trap) [§](https://ziglang.org/download/0.11.0/release-notes.html#trap)

New builtin:

```
@trap() noreturn
```

This function inserts a platform-specific trap/jam instruction which can be used to exit the program abnormally. This may be implemented by explicitly emitting an invalid instruction which may cause an illegal instruction exception of some sort. Unlike `@breakpoint`, execution does not continue afterwards:

trap\_noreturn.zig

```
test "@trap is noreturn" {
    @trap();
    return error.Foo; // Control flow will never reach this line!
}
```

Shell

$ zig test trap\_noreturn.zig
docgen\_tmp/trap\_noreturn.zig:3:5: error: unreachable code
    return error.Foo; // Control flow will never reach this line!
    ^~~~~~~~~~~~~~~~
docgen\_tmp/trap\_noreturn.zig:2:5: note: control flow is diverted here
    @trap();
    ^~~~~~~

### [@inComptime](https://ziglang.org/download/0.11.0/release-notes.html#toc-inComptime) [§](https://ziglang.org/download/0.11.0/release-notes.html#inComptime)

A new builtin, `@inComptime()`, has been introduced. This builtin returns a `bool` indicating whether or not it was evaluated in a `comptime` scope.

in\_comptime.zig

```
const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;

const global_val = blk: {
    assert(@inComptime());
    break :blk 123;
};

comptime {
    assert(@inComptime());
}

fn f() u32 {
    if (@inComptime()) {
        return 1;
    } else {
        return 2;
    }
}

test "@inComptime" {
    try expectEqual(true, comptime @inComptime());
    try expectEqual(false, @inComptime());
    try expectEqual(@as(u32, 1), comptime f());
    try expectEqual(@as(u32, 2), f());
}
```

Shell

$ zig test in\_comptime.zig
1/1 test.@inComptime... OK
All 1 tests passed.

### [Split @qualCast into @constCast and @volatileCast](https://ziglang.org/download/0.11.0/release-notes.html#toc-Split-qualCast-into-constCast-and-volatileCast) [§](https://ziglang.org/download/0.11.0/release-notes.html#Split-qualCast-into-constCast-and-volatileCast)

qualcast.zig

```
const std = @import("std");
const expect = std.testing.expect;

test "qualCast" {
    const x: i32 = 1234;
    const y = @qualCast(&x);
    try expect(@TypeOf(y) == *i32);
    try expect(y.* == 1234);
}
```

Shell

$ zig test qualcast.zig
docgen\_tmp/qualcast.zig:6:15: error: invalid builtin function: '@qualCast'
    const y = @qualCast(&x);
              ^~~~~~~~~~~~~

Use `@constCast` instead to fix the error.

### [Rename Casting Builtins](https://ziglang.org/download/0.11.0/release-notes.html#toc-Rename-Casting-Builtins) [§](https://ziglang.org/download/0.11.0/release-notes.html#Rename-Casting-Builtins)

An [accepted proposal](https://github.com/ziglang/zig/issues/6128) has been implemented to rename all casting builtins of the form `@xToY` to `@yFromX`. The goal of this change is to make code more readable by ensuring information flows in a consistent direction (right-to-left) through function-call-like expressions.

The full list of affected builtins is as follows:

| old name | new name |
| --- | --- |
| `@boolToInt` | `@intFromBool` |
| `@enumToInt` | `@intFromEnum` |
| `@errorToInt` | `@intFromError` |
| `@floatToInt` | `@intFromFloat` |
| `@intToEnum` | `@enumFromInt` |
| `@intToError` | `@errorFromInt` |
| `@intToFloat` | `@floatFromInt` |
| `@intToPtr` | `@ptrFromInt` |
| `@ptrToInt` | `@intFromPtr` |

`zig fmt` will automatically update usages of the old builtin names in your code.

### [Cast Inference](https://ziglang.org/download/0.11.0/release-notes.html#toc-Cast-Inference) [§](https://ziglang.org/download/0.11.0/release-notes.html#Cast-Inference)

Zig 0.11.0 implements [an accepted proposal](https://github.com/ziglang/zig/issues/5909) which changes how "casting" builtins (e.g. `@intCast`, `@enumFromInt`) behave. The goal of this change is to improve readability and safety.

In previous versions of Zig, casting builtins took as a parameter the **destination type** of the cast, for instance `@intCast(u8, x)`. This was easy to understand, but can lead to code duplication where a type must be repeated at the usage site despite already being specified as, for instance, a parameter type or field type.

As a motivating example, consider a function parameter of type `u16` which you are passing a `u64`. You need to use `@intCast` to convert your value to the correct type. Now suppose that down the line, you find out the parameter needs to be a `u32` so you can pass in larger values. There is now a footgun here: if you don't change every `@intCast` to cast to the correct type, you have a silent bug in your program which may not cause a problem for a while, making it hard to spot.

This is the basic pattern motivating this change. The idea is that instead of writing `f(@intCast(u16, x))`, you instead write `f(@intCast(x))`, and the destination type of the cast is inferred based on the type. This is not just about function parameters: it is also applicable to struct initializations, return values, and more.

This language change removes the destination type parameter from all cast builtins. Instead, these builtins now use [Result Location Semantics](https://ziglang.org/documentation/0.11.0/#Reuslt-Location-Semantics) to infer the result type of the cast from the expression's "result type". In essence, this means type inference is used. Most expressions which have a known concrete type for their operand will provide a result type. For instance:

-   `const x: T = e` gives `e` a result type of `T`
-   `@as(T, e)` gives `e` a result type of `T`
-   `return e` gives `e` a result type of the function's return type
-   `S{ .f = e }` gives `e` a result type of the type of the field `S.f`
-   `f(e)` gives `e` a result type of the first parameter type of `f`

The full list of affected cast builtins is as follows:

-   `@addrSpaceCast`, `@alignCast`, `@ptrCast`
-   `@errSetCast`, `@floatCast`, `@intCast`
-   `@intFromFloat`, `@enumFromInt`, `@floatFromInt`, `@ptrFromInt`
-   `@truncate`, `@bitCast`

Using these builtins in an expression with no result type will give a compile error:

no\_cast\_result\_type.zig

```
test "cast without result type" {
    const x: u16 = 200;
    const y = @intCast(x);
    _ = y;
}
```

Shell

$ zig test no\_cast\_result\_type.zig
docgen\_tmp/no\_cast\_result\_type.zig:3:15: error: @intCast must have a known result type
    const y = @intCast(x);
              ^~~~~~~~~~~
docgen\_tmp/no\_cast\_result\_type.zig:3:15: note: use @as to provide explicit result type

This error indicates one possible method of providing an explicit result type: using `@as`. This will always work, however it is usually not necessary. Instead, result types are normally inferred from type annotations, struct/array initialization expressions, parameter types, and so on.

cast\_result\_type\_inference.zig

```
test "infer cast result type from type annotation" {
    const x: u16 = 200;
    const y: u8 = @intCast(x);
    _ = y;
}

test "infer cast result type from field type" {
    const S = struct { x: f32 };
    const val: f64 = 123.456;
    const s: S = .{ .x = @floatCast(val) };
    _ = s;
}

test "infer cast result type from parameter type" {
    const val: u64 = 123;
    f(@intCast(val));
}
fn f(x: u32) void {
    _ = x;
}

test "infer cast result type from return type" {
    _ = g(123);
}
fn g(x: u64) u32 {
    return @intCast(x);
}

test "explicitly annotate result type with @as" {
    const E = enum(u8) { a, b };
    const x: u8 = 1;
    _ = @as(E, @enumFromInt(x));
}
```

Shell

$ zig test cast\_result\_type\_inference.zig
1/5 test.infer cast result type from type annotation... OK
2/5 test.infer cast result type from field type... OK
3/5 test.infer cast result type from parameter type... OK
4/5 test.infer cast result type from return type... OK
5/5 test.explicitly annotate result type with @as... OK
All 5 tests passed.

Where possible, `zig fmt` has been made to automatically migrate uses of the old builtins, using a naive translation based on `@as`. Most builtins can be automatically updated correctly, but there are a few exceptions.

-   `@addrSpaceCast` and `@alignCast` cannot be translated as the old usage does not provide the full result type. `zig fmt` will not modify it.
-   `@ptrCast` may sometimes decrease alignment where it previously did not, potentially triggering compile errors. This can be fixed by modifying the type to have the correct alignment.
-   `@truncate` will be translated incorrectly for vectors, causing a compile error. This can be fixed by changing the scalar type `T` to the vector type `@Vector(n, T)`.
-   `@splat` cannot be translated as the old usage does not provide the full result type. `zig fmt` will not modify it.

#### [Pointer Casts](https://ziglang.org/download/0.11.0/release-notes.html#toc-Pointer-Casts) [§](https://ziglang.org/download/0.11.0/release-notes.html#Pointer-Casts)

The builtins `@addrSpaceCast` and `@alignCast` would become quite cumbersome to use under this system as described, since you would now have to specify the full intermediate pointer types. Instead, pointer casts (those two builtins and `@ptrCast`) are special. They combine into a single logical operation, with each builtin effectively "allowing" a particular component of the pointer to be cast rather than "performing" it. (Indeed, this may be a helpful mental model for the new cast builtins more generally.) This means any sequence of nested pointer cast builtins requires only one result type, rather than one at every intermediate computation.

pointer\_cast.zig

```
test "pointer casts" {
    const ptr1: *align(1) const u32 = @ptrFromInt(0x1000);
    const ptr2: *u64 = @constCast(@alignCast(@ptrCast(ptr1)));
    _ = ptr2;
}
```

Shell

$ zig test pointer\_cast.zig
1/1 test.pointer casts... OK
All 1 tests passed.

#### [@splat](https://ziglang.org/download/0.11.0/release-notes.html#toc-splat) [§](https://ziglang.org/download/0.11.0/release-notes.html#splat)

The `@splat` builtin has undergone a similar change. It no longer has a parameter to indicate the length of the resulting vector, instead using the expression's result type to infer this and the type of its operand.

splat\_result\_type.zig

```
test "@splat result type" {
    const vec: @Vector(8, u8) = @splat(123);
    _ = vec;
}
```

Shell

$ zig test splat\_result\_type.zig
1/1 test.@splat result type... OK
All 1 tests passed.

### [Tuple Type Declarations](https://ziglang.org/download/0.11.0/release-notes.html#toc-Tuple-Type-Declarations) [§](https://ziglang.org/download/0.11.0/release-notes.html#Tuple-Type-Declarations)

Tuple types can now be declared using struct declaration syntax without the field types ([#4335](https://github.com/ziglang/zig/issues/4335)):

tuple\_decl.zig

```
const std = @import("std");
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

test "tuple declarations" {
    const T = struct { u32, []const u8 };
    var t: T = .{ 1, "foo" };
    try expect(t[0] == 1);
    try expectEqualStrings(t[1], "foo");

    var mul = t ** 3;
    try expect(@TypeOf(mul) != T);
    try expect(mul.len == 6);
    try expect(mul[2] == 1);
    try expectEqualStrings(mul[3], "foo");

    var t2: T = .{ 2, "bar" };
    var cat = t ++ t2;
    try expect(@TypeOf(cat) != T);
    try expect(cat.len == 4);
    try expect(cat[2] == 2);
    try expectEqualStrings(cat[3], "bar");
}
```

Shell

$ zig test tuple\_decl.zig
1/1 test.tuple declarations... OK
All 1 tests passed.

Packed and extern tuples are forbidden ([#16551](https://github.com/ziglang/zig/issues/16551)).

### [Concatenation of Arrays and Tuples](https://ziglang.org/download/0.11.0/release-notes.html#toc-Concatenation-of-Arrays-and-Tuples) [§](https://ziglang.org/download/0.11.0/release-notes.html#Concatenation-of-Arrays-and-Tuples)

tuple\_array\_cat.zig

```
const std = @import("std");

test "concatenate array with tuple" {
    const array: [2]u8 = .{ 1, 2 };
    const seq = array ++ .{ 3, 4 };
    try std.testing.expect(std.mem.eql(u8, &seq, &.{ 1, 2, 3, 4 }));
}
```

Shell

$ zig test tuple\_array\_cat.zig
1/1 test.concatenate array with tuple... OK
All 1 tests passed.

This can be a nice tool when writing [Crypto](https://ziglang.org/download/0.11.0/release-notes.html#Crypto) code, and indeed is used extensively by the [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) to avoid heap [Memory Allocation](https://ziglang.org/download/0.11.0/release-notes.html#Memory-Allocation) in the new [TLS Client](https://ziglang.org/download/0.11.0/release-notes.html#TLS-Client).

### [Allow Indexing Tuple and Vector Pointers](https://ziglang.org/download/0.11.0/release-notes.html#toc-Allow-Indexing-Tuple-and-Vector-Pointers) [§](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Indexing-Tuple-and-Vector-Pointers)

Zig allows you to directly index pointers to arrays like plain arrays, which transparently dereferences the pointer as required. For consistency, this is now additionally allowed for pointers to tuples and vectors (the other non-pointer indexable types).

index\_tuple\_vec\_ptr.zig

```
const std = @import("std");

test "index tuple pointer" {
    var raw: struct { u32, u32 } = .{ 1, 2 };
    const ptr = &raw;

    try std.testing.expectEqual(@as(u32, 1), ptr[0]);
    try std.testing.expectEqual(@as(u32, 2), ptr[1]);

    ptr[0] = 3;
    ptr[1] = 4;

    try std.testing.expectEqual(@as(u32, 3), ptr[0]);
    try std.testing.expectEqual(@as(u32, 4), ptr[1]);
}

test "index vector pointer" {
    var raw: @Vector(2, u32) = .{ 1, 2 };
    const ptr = &raw;

    try std.testing.expectEqual(@as(u32, 1), ptr[0]);
    try std.testing.expectEqual(@as(u32, 2), ptr[1]);

    ptr[0] = 3;
    ptr[1] = 4;

    try std.testing.expectEqual(@as(u32, 3), ptr[0]);
    try std.testing.expectEqual(@as(u32, 4), ptr[1]);
}
```

Shell

$ zig test index\_tuple\_vec\_ptr.zig
1/2 test.index tuple pointer... OK
2/2 test.index vector pointer... OK
All 2 tests passed.

### [Overflow Builtins Return Tuples](https://ziglang.org/download/0.11.0/release-notes.html#toc-Overflow-Builtins-Return-Tuples) [§](https://ziglang.org/download/0.11.0/release-notes.html#Overflow-Builtins-Return-Tuples)

Now that we have started to get into writing our own [Code Generation](https://ziglang.org/download/0.11.0/release-notes.html#Code-Generation) and not relying exclusively on [LLVM](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-16), the flaw with the previous API becomes clear: writing the result through a pointer parameter makes it too hard to use a special value returned from the builtin and detect the pattern that allows lowering to the efficient code.

Furthermore, the result pointer is incompatible with SIMD vectors (related: [Cast Inference](https://ziglang.org/download/0.11.0/release-notes.html#Cast-Inference)).

Arithmetic overflow functions now return a tuple, like this:

```
@addWithOverflow(a: T, b: T) struct {T, u1}
@addWithOverflow(a: @Vector(T, N), b: @Vector(T, N)) struct {@Vector(T, N), @Vector(u1, N)}
```

If [#498](https://github.com/ziglang/zig/issues/498) were implemented, `parseInt` would look like this:

```
fn parseInt(comptime T: type, buf: []const u8, radix: u8) !T {
    var x: T = 0;

    for (buf) |c| {
        const digit = switch (c) {
            '0'...'9' => c - '0',
            'A'...'Z' => c - 'A' + 10,
            'a'...'z' => c - 'a' + 10,
            else => return error.InvalidCharacter,
        };
        x, const mul_overflow = @mulWithOverflow(x, radix);
        if (mul_overflow != 0) return error.Overflow;

        x, const add_overflow = @addWithOverflow(x, digit);
        if (add_overflow != 0) return error.Overflow;
    }

    return x;
}
```

However [#498](https://github.com/ziglang/zig/issues/498) is neither implemented nor accepted yet, so actual usage must do this:

```
const std = @import("std");

fn parseInt(comptime T: type, buf: []const u8, radix: u8) !T {
    var x: T = 0;

    for (buf) |c| {
        const digit = switch (c) {
            '0'...'9' => c - '0',
            'A'...'Z' => c - 'A' + 10,
            'a'...'z' => c - 'a' + 10,
            else => return error.InvalidCharacter,
        };
        const mul_result = @mulWithOverflow(x, radix);
        x = mul_result[0];
        const mul_overflow = mul_result[1];
        if (mul_overflow != 0) return error.Overflow;

        const add_result = @addWithOverflow(x, digit);
        x = add_result[0];
        const add_overflow = add_result[1];
        if (add_overflow != 0) return error.Overflow;
    }

    return x;
}
```

More details: [#10248](https://github.com/ziglang/zig/issues/10248)

### [Slicing By Length](https://ziglang.org/download/0.11.0/release-notes.html#toc-Slicing-By-Length) [§](https://ziglang.org/download/0.11.0/release-notes.html#Slicing-By-Length)

This is technically not a _change_ to the language, however, it bears mentioning in the language changes section, because it makes a particular idiom be even more idiomatic, by recognizing the pattern directly in the [Compiler](https://ziglang.org/download/0.11.0/release-notes.html#Compiler).

This pattern is extremely common:

slice\_by\_len.zig

```
fn foo(s: []const i32, start: usize, len: usize) []const i32 {
    return s[start..][0..len];
}
```

The pattern is useful because it is effectively a slice-by-length rather than slice by end index. With this pattern, when `len` is compile-time known, the expression will be a pointer to an array rather than a slice type, which is generally a preferable type.

The actual language change here is that this is now supported for many-ptrs. Where previously you had to write `(ptr + off)[0..len]`, you can now instead write `ptr[off..][0..len]`. Note that in general, unbounded slicing of many-pointers is still not permitted, requiring pointer arithmetic: only this "slicing by length" pattern is allowed.

Zig 0.11.0 now detects this pattern and generates more efficient code.

You can think of Zig as having both slice-by-end and slice-by-len syntax, it's just that one of them is expressed in terms of the other.

More details: [#15482](https://github.com/ziglang/zig/issues/15482)

### [Inline Function Call Comptime Propagation](https://ziglang.org/download/0.11.0/release-notes.html#toc-Inline-Function-Call-Comptime-Propagation) [§](https://ziglang.org/download/0.11.0/release-notes.html#Inline-Function-Call-Comptime-Propagation)

inline\_call.zig

```
const std = @import("std");

var call_count: u32 = 0;

inline fn isGreaterThan(x: i32, y: i32) bool {
    call_count += 1;
    return x > y;
}

test "inline call comptime propagation" {
    // Runtime-known parameters to inline function, nothing new here.
    var a: i32 = 1234;
    var b: i32 = 5678;
    try std.testing.expect(!isGreaterThan(a, b));

    // Now it gets interesting...
    const c = 1234;
    const d = 5678;
    if (isGreaterThan(c, d)) {
        @compileError("that wasn't supposed to happen");
    }

    try std.testing.expect(call_count == 2);
}
```

Shell

$ zig test inline\_call.zig
1/1 test.inline call comptime propagation... OK
All 1 tests passed.

In this example, there is no compile error because the comptime-ness of the arguments is propagated to the return value of the inlined function. However, as demonstrated by the `call_count` global variable, runtime side-effects of the inlined function still occur.

The `inline` keyword in Zig is an extremely powerful tool that should not be used lightly. It's best to let the compiler decide when to inline a function, except for these scenarios:

-   You want to change how many stack frames are in the call stack, for debugging purposes.
-   You want the comptime-ness of the arguments to propagate to the return value of the function, as demonstrated above.
-   Performance measurements _demand_ it. Don’t guess!

### [Exporting C Variadic Functions](https://ziglang.org/download/0.11.0/release-notes.html#toc-Exporting-C-Variadic-Functions) [§](https://ziglang.org/download/0.11.0/release-notes.html#Exporting-C-Variadic-Functions)

Generally we don't want Zig programmers to use C-style variadic functions. But sometimes you have to interface with C code.

Here are two use cases for it:

-   Implementing libc in Zig
-   [C Translation](https://ziglang.org/download/0.11.0/release-notes.html#C-Translation), for example an inline static function in MSVC's stdio.h

Only some targets support this new feature:

-   [exporting a C var args function triggers LLVM assertion when targeting non-Darwin aarch64](https://github.com/ziglang/zig/issues/14096)
-   It's also not working on [Windows](https://ziglang.org/download/0.11.0/release-notes.html#Windows).

That makes this feature **experimental** because it does not disqualify a target from [Tier 1 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) if it does not support C-style var args.

More information: [#515](https://github.com/ziglang/zig/issues/515)

### [Added c\_char Type](https://ziglang.org/download/0.11.0/release-notes.html#toc-Added-c_char-Type) [§](https://ziglang.org/download/0.11.0/release-notes.html#Added-c_char-Type)

This is strictly for [C ABI Compatibility](https://ziglang.org/download/0.11.0/release-notes.html#C-ABI-Compatibility) and should only be used when it is required by the ABI.

See [#875](https://github.com/ziglang/zig/issues/875) for more details.

### [Forbid Runtime Operations in comptime Blocks](https://ziglang.org/download/0.11.0/release-notes.html#toc-Forbid-Runtime-Operations-in-comptime-Blocks-) [§](https://ziglang.org/download/0.11.0/release-notes.html#Forbid-Runtime-Operations-in-comptime-Blocks-)

Previously, `comptime` blocks in runtime code worked in a highly unintuitive way: they [did not actually enforce compile-time evaluation of their bodies](https://github.com/ziglang/zig/issues/7056). This has been resolved in 0.11.0. The entire body of a `comptime` block will now be evaluated at compile time, and a compile error is triggered if this is not possible.

comptime\_block.zig

```
test "runtime operations in comptime block" {
    var x: u32 = 1;
    comptime {
        x += 1;
    }
}
```

Shell

$ zig test comptime\_block.zig
docgen\_tmp/comptime\_block.zig:4:11: error: unable to evaluate comptime expression
        x += 1;
        ~~^~~~
docgen\_tmp/comptime\_block.zig:4:9: note: operation is runtime due to this operand
        x += 1;
        ^

This change has one particularly notable consequence. Previously, it was allowed to `return` from a runtime function within a `comptime` block. However, this is illogical: the return cannot actually happen at comptime, since this function is being called at runtime. Therefore, this is now illegal.

return\_from\_comptime\_block.zig

```
const expectEqual = @import("std").testing.expectEqual;
test "return from runtime function in comptime block" {
    try expectEqual(@as(u32, 123), f());
}

fn f() u32 {
    // We want to call `foo` at comptime
    comptime {
        return foo();
    }
}
fn foo() u32 {
    return 123;
}
```

Shell

$ zig test return\_from\_comptime\_block.zig
docgen\_tmp/return\_from\_comptime\_block.zig:9:9: error: function called at runtime cannot return value at comptime
        return foo();
        ^~~~~~~~~~~~
referenced by:
    test.return from runtime function in comptime block: docgen\_tmp/return\_from\_comptime\_block.zig:3:36
    remaining reference traces hidden; use '-freference-trace' to see all reference traces

The workaround for this issue is to _compute_ the return value at comptime, but _return_ it at runtime:

compute\_return\_from\_comptime\_block.zig

```
const expectEqual = @import("std").testing.expectEqual;
test "compute return value of runtime function in comptime block" {
    try expectEqual(@as(u32, 123), f());
}

fn f() u32 {
    // We want to call `foo` at comptime
    return comptime foo();
}
fn foo() u32 {
    return 123;
}
```

Shell

$ zig test compute\_return\_from\_comptime\_block.zig
1/1 test.compute return value of runtime function in comptime block... OK
All 1 tests passed.

This change similarly disallows `comptime try` from within a runtime function, since on error this attempts to return a value at compile time. To retain the old behavior, this sequence should be replaced with `try comptime`.

### [@intFromBool always returns u1](https://ziglang.org/download/0.11.0/release-notes.html#toc-intFromBool-always-returns-u1) [§](https://ziglang.org/download/0.11.0/release-notes.html#intFromBool-always-returns-u1)

The `@intFromBool` builtin (previously called `@boolToInt`) previously returned either a `u1` or a `comptime_int`, depending on whether or not it was evaluated at `comptime`. It has since been changed to always return a `u1` to improve consistency between code running at runtime and comptime.

int\_from\_bool.zig

```
const std = @import("std");

test "@intFromBool returns u1" {
    const x = @intFromBool(true); // implicitly evaluated at comptime
    const y = comptime @intFromBool(true); // explicitly evaluated at comptime

    try std.testing.expect(@TypeOf(x) == u1);
    try std.testing.expect(@TypeOf(y) == u1);

    try std.testing.expect(x == 1);
    try std.testing.expect(y == 1);
}
```

Shell

$ zig test int\_from\_bool.zig
1/1 test.@intFromBool returns u1... OK
All 1 tests passed.

### [@fieldParentPtr Supports Unions](https://ziglang.org/download/0.11.0/release-notes.html#toc-fieldParentPtr-Supports-Unions) [§](https://ziglang.org/download/0.11.0/release-notes.html#fieldParentPtr-Supports-Unions)

It already worked on structs; there was no reason for it to not work on unions ([#6611](https://github.com/ziglang/zig/issues/6611)).

field\_parent\_ptr\_union.zig

```
const std = @import("std");
const expect = std.testing.expect;

test "@fieldParentPtr on a union" {
    try quux(&bar.c);
    try comptime quux(&bar.c);
}

const bar = Bar{ .c = 42 };

const Bar = union(enum) {
    a: bool,
    b: f32,
    c: i32,
    d: i32,
};

fn quux(c: *const i32) !void {
    try expect(c == &bar.c);

    const base = @fieldParentPtr(Bar, "c", c);
    try expect(base == &bar);
    try expect(&base.c == c);
}
```

Shell

$ zig test field\_parent\_ptr\_union.zig
1/1 test.@fieldParentPtr on a union... OK
All 1 tests passed.

Calling `@fieldParentPtr` on a pointer that is not actually a field of the parent type is currently **unchecked illegal behavior**, however there is an accepted proposal to add a safety check: [add safety checks for pointer casting](https://github.com/ziglang/zig/issues/2414)

### [@typeInfo No Longer Returns Private Declarations](https://ziglang.org/download/0.11.0/release-notes.html#toc-typeInfo-No-Longer-Returns-Private-Declarations) [§](https://ziglang.org/download/0.11.0/release-notes.html#typeInfo-No-Longer-Returns-Private-Declarations)

It was a [bug](https://ziglang.org/download/0.11.0/release-notes.html#Bug-Fixes) that private declarations were included in the result of `@typeInfo` ([#10731](https://github.com/ziglang/zig/issues/10731)).

The `is_pub` field has been removed from `std.builtin.Type.Declaration`.

### [Zero-Sized Fields Allowed in Extern Structs](https://ziglang.org/download/0.11.0/release-notes.html#toc-Zero-Sized-Fields-Allowed-in-Extern-Structs) [§](https://ziglang.org/download/0.11.0/release-notes.html#Zero-Sized-Fields-Allowed-in-Extern-Structs)

Zero-sized fields are now allowed in `extern struct` types, because they do not compromise the well-defined memory layout ([#16404](https://github.com/ziglang/zig/issues/16404)).

ice\_cream.zig

```
const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

const T = extern struct {
    blah: i32,
    ice_cream: if (builtin.is_test) void else i32,
};

test "no ice cream" {
    var t: T = .{
        .blah = 1234,
        .ice_cream = {},
    };
    try expect(t.blah == 1234);
}
```

Shell

$ zig test ice\_cream.zig
1/1 test.no ice cream... OK
All 1 tests passed.

This change allows the following types to appear in extern structs:

-   Zero-bit integers
-   `void`
-   zero-sized structs and packed structs
-   enums with zero-bit backing integers
-   arrays of any length with zero-size elements

Note that packed structs are already allowed in extern structs, provided that their backing integer is allowed.

### [Eliminate Bound Functions](https://ziglang.org/download/0.11.0/release-notes.html#toc-Eliminate-Bound-Functions) [§](https://ziglang.org/download/0.11.0/release-notes.html#Eliminate-Bound-Functions)

Did you know Zig had bound functions?

No? I rest my case. Good riddance!

The following code was valid in 0.10, but is not any more:

bound\_functions.zig

```
const std = @import("std");

test "bound functions" {
    var runtime_true = true;

    // This code was valid in 0.10, and gave 'x' a "bound function" type.
    // Bound functions have been removed from the language, so this code is no longer valid.
    const obj: Foo = .{};
    const x = if (runtime_true) obj.a else obj.b;

    try std.testing.expect(x() == 'a');
}

const Foo = struct {
    fn a(_: Foo) u8 {
        return 'a';
    }
    fn b(_: Foo) u8 {
        return 'b';
    }
};
```

Shell

$ zig test bound\_functions.zig
docgen\_tmp/bound\_functions.zig:9:37: error: no field named 'a' in struct 'bound\_functions.Foo'
    const x = if (runtime\_true) obj.a else obj.b;
                                    ^
docgen\_tmp/bound\_functions.zig:14:13: note: struct declared here
const Foo = struct {
            ^~~~~~

Method calls are now restricted to the exact syntactic form `a.b(args)`. Any deviation from this syntax - for instance, extra parentheses as in `(a.b)(args)` - will be treated as a field access.

### [@call Stack](https://ziglang.org/download/0.11.0/release-notes.html#toc-call-Stack) [§](https://ziglang.org/download/0.11.0/release-notes.html#call-Stack)

The `stack` option has been removed from `@call` ([#13907](https://github.com/ziglang/zig/issues/13907)).

There is no upgrade path for this one, I'm afraid. This feature has proven difficult to implement in the [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend).

More investigation will be needed to see if something that solves the use case of switching call stacks can be brought back to the language before Zig reaches 1.0.

### [Allow Tautological Integer Comparisons](https://ziglang.org/download/0.11.0/release-notes.html#toc-Allow-Tautological-Integer-Comparisons) [§](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Tautological-Integer-Comparisons)

Previously, comparing an integer to a comptime-known value required that value to fit in the integer type. For instance, comparing a `u8` to `500` was a compile error. However, such comparisons can be useful when writing generic or future-proof code.

As such, comparisons of this form are now allowed. However, since these comparisons are tautological, they do not cause any runtime checks: instead, the result is comptime-known based on the type. For instance, `my_u8 == 500` is comptime-known `false`, even if `my_u8` is not itself comptime-known.

tautological\_compare\_comptime.zig

```
test "tautological comparisons are comptime-known" {
    var x: u8 = 123;
    if (x > 500) @compileError("unreachable branch analyzed");
    if (x == -20) @compileError("unreachable branch analyzed");
    if (x < 0) @compileError("unreachable branch analyzed");
    if (x != 500) {} else @compileError("unreachable branch analyzed");
}
```

Shell

$ zig test tautological\_compare\_comptime.zig
1/1 test.tautological comparisons are comptime-known... OK
All 1 tests passed.

### [Forbid Source Files Being Part of Multiple Modules](https://ziglang.org/download/0.11.0/release-notes.html#toc-Forbid-Source-Files-Being-Part-of-Multiple-Modules) [§](https://ziglang.org/download/0.11.0/release-notes.html#Forbid-Source-Files-Being-Part-of-Multiple-Modules)

A Zig module (previously known as "package") is a collection of source files, with a single root source file, which can be imported in your code by name. For instance, `std` is a module. An interesting case comes up when two modules attempt to `@import` the same source file.

Previously, when this happened, the source file became "owned" by whichever import the compiler happened to reach first. This was a problem, because it could lead to inconsistent behavior in the compiler based on a race condition. This could be fixed by having the compiler analyzing the files multiple times - once for each module they're imported from - however, this could lead to slowdowns in compile times, and generally this kind of structure is indicative of a mistake anyway.

Therefore, another solution was chosen: **having a single source file within multiple modules is now illegal**. When a source file is encountered in two different modules, an error like the following will be emitted:

Shell

$ ls
foo.zig  main.zig  common.zig

$ cat common.zig
// An empty file

$ cat foo.zig
// This is the root of the 'foo' module
pub const common = @import("common.zig");

$ cat main.zig
// This file is the root of the main module
comptime {
    \_ = @import("foo").common;
    \_ = @import("common.zig");
}

$ zig test main.zig --mod foo::foo.zig --deps foo
common.zig:1:1: error: file exists in multiple modules
main.zig:4:17: note: imported from module root
    \_ = @import("common.zig");
                ^~~~~~~~~~~~
foo.zig:2:28: note: imported from module root.foo
pub const common = @import("common.zig");
                           ^~~~~~~~~~~~

The correct way to resolve this error is usually to factor the shared file out into its own module, which other modules can then import. This can be done in the [Build System](https://ziglang.org/download/0.11.0/release-notes.html#Build-System) using `std.Build.addModule`.

### [Single-Item Array Pointers Gain .ptr Field](https://ziglang.org/download/0.11.0/release-notes.html#toc-Single-Item-Array-Pointers-Gain-ptr-Field) [§](https://ziglang.org/download/0.11.0/release-notes.html#Single-Item-Array-Pointers-Gain-ptr-Field)

In general, it is intended for single-item array pointers to act equivalently to a slice. That is, `*const [5]u8` is essentially equivalent to `[]const u8` but with a comptime-known length.

Previously, the `ptr` field on slices was an exception to this rule, as it did not exist on single-item array pointers. This field [has been added](https://github.com/ziglang/zig/issues/4765), and is equivalent to simple coercion from `*[N]T` to `[*]T`.

array\_pointer\_ptr\_field.zig

```
const std = @import("std");

test "array pointer has ptr field" {
    const x: *const [4] u32 = &.{ 1, 2, 3, 4 };
    const y: []const u32 = &.{ 1, 2, 3, 4 };

    const xp: [*]const u32 = x.ptr;
    const yp: [*]const u32 = y.ptr;

    try std.testing.expectEqual(xp, @as([*]const u32, x));

    for (0..4) |i| {
        try std.testing.expectEqual(x[i], xp[i]);
        try std.testing.expectEqual(y[i], yp[i]);
    }
}
```

Shell

$ zig test array\_pointer\_ptr\_field.zig
1/1 test.array pointer has ptr field... OK
All 1 tests passed.

### [Allow Method Call Syntax on Optional Pointers](https://ziglang.org/download/0.11.0/release-notes.html#toc-Allow-Method-Call-Syntax-on-Optional-Pointers) [§](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Method-Call-Syntax-on-Optional-Pointers)

Method call syntax `object.method(args)` only works when the first parameter of `method` has a specific type: previously, this was either the type containing the method, or a pointer to it. It is now additionally allowed for this type to be an optional pointer. The value the method call is performed on must still be a non-optional pointer, but it is coerced to an optional pointer for the method call.

method\_syntax\_opt\_ptr.zig

```
const std = @import("std");

const Foo = struct {
    x: u32,

    fn xOrDefault(self: ?*const Foo) u32 {
        const foo = self orelse return 0;
        return foo.x;
    }
};

test "method call with optional pointer parameter" {
    const a: Foo = .{ .x = 7 };
    const b: Foo = .{ .x = 9 };

    try std.testing.expectEqual(@as(u32, 0), Foo.xOrDefault(null));
    try std.testing.expectEqual(@as(u32, 7), a.xOrDefault());
    try std.testing.expectEqual(@as(u32, 9), b.xOrDefault());
}
```

Shell

$ zig test method\_syntax\_opt\_ptr.zig
1/1 test.method call with optional pointer parameter... OK
All 1 tests passed.

### [comptime Function Calls No Longer Cause Runtime Analysis](https://ziglang.org/download/0.11.0/release-notes.html#toc-comptime-Function-Calls-No-Longer-Cause-Runtime-Analysis) [§](https://ziglang.org/download/0.11.0/release-notes.html#comptime-Function-Calls-No-Longer-Cause-Runtime-Analysis)

There has been an [open issue](https://github.com/ziglang/zig/issues/6256) for several years about the fact that Zig will emit all referenced functions to a binary, even if the function is only used at compile-time. This can cause [binary bloat](https://github.com/ziglang/zig/issues/15353), as well as potentially triggering false positive compile errors if a function is intended to only be used at compile-time.

This issue [has been resolved](https://github.com/ziglang/zig/pull/15891) in this release cycle. Zig will now only emit a runtime version of a function to the binary if one of the following conditions holds:

-   The function is called at runtime.
-   The function has a reference taken to it. In this case, a call may occur through a function pointer, so the function must be emitted.

As well as avoiding potential false positive compile errors, this change leads to a slight decrease in binary sizes, and may slightly speed up compilation in some cases. Note that as a consequence of this change, it is no longer sufficient to write `comptime { _ = f; }` to force a function to be analyzed and emitted to the binary. Instead, you must write `comptime { _ = &f; }`.

### [Multi-Item Switch Prong Type Coercion](https://ziglang.org/download/0.11.0/release-notes.html#toc-Multi-Item-Switch-Prong-Type-Coercion) [§](https://ziglang.org/download/0.11.0/release-notes.html#Multi-Item-Switch-Prong-Type-Coercion)

Prior to 0.11.0, when a `switch` prong captured a union payload, all payloads were required to have the exact same type. This has been changed so that [Peer Type Resolution](https://ziglang.org/documentation/0.11.0/#Peer-Type-Resolution) is used to combine the payload types, allowing distinct but compatible types to be captured together.

Pointer captures also make use of peer type resolution, but are more limited: the payload types must all have the same in-memory representation so that the payload pointer can be safely cast.

switch\_capture\_ptr.zig

```
const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;

const U1 = union(enum) {
    x: u8,
    y: ?u32,
};
test "switch capture resolves peer types" {
    try f(1, .{ .x = 1 });
    try f(2, .{ .y = 2 });
    try f(0, .{ .y = null });
}
fn f(expected: u32, u: U1) !void {
    switch (u) {
        .x, .y => |val| {
            comptime assert(@TypeOf(val) == ?u32);
            try expectEqual(expected, val orelse 0);
        },
    }
}

const U2 = union(enum) {
    x: c_uint,
    /// This type has the same number of bits as `c_uint`, but is distinct.
    y: @Type(.{ .Int = .{
        .signedness = .unsigned,
        .bits = @bitSizeOf(c_uint),
    } }),
};
test "switch pointer capture resolves peer types" {
    var a: U2 = .{ .x = 10 };
    var b: U2 = .{ .y = 20 };
    g(&a);
    g(&b);
    try expectEqual(U2{ .x = 11 }, a);
    try expectEqual(U2{ .y = 21 }, b);
}
fn g(u: *U2) void {
    switch (u.*) {
        .x, .y => |*ptr| {
            ptr.* += 1;
        },
    }
}
```

Shell

$ zig test switch\_capture\_ptr.zig
1/2 test.switch capture resolves peer types... OK
2/2 test.switch pointer capture resolves peer types... OK
All 2 tests passed.

### [Allow Functions to Return null and undefined](https://ziglang.org/download/0.11.0/release-notes.html#toc-Allow-Functions-to-Return-null-and-undefined) [§](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Functions-to-Return-null-and-undefined)

0.10 had some arbitrary restrictions on the types of function parameters and their return types: they were not permitted to be `@TypeOf(null)` or `@TypeOf(undefined)`. While these types are rarely useful in this context, they are still completely normal comptime-only types, so this restriction on their usage was needless. As such, they are now allowed as parameter and return types.

null\_undef\_param\_ret\_ty.zig

```
const std = @import("std");

fn foo(comptime x: @TypeOf(undefined)) @TypeOf(null) {
    _ = x;
    return null;
}

test "null and undefined as function parameter and return types" {
    const my_null = foo(undefined);
    try std.testing.expect(my_null == null);
}
```

Shell

$ zig test null\_undef\_param\_ret\_ty.zig
1/1 test.null and undefined as function parameter and return types... OK
All 1 tests passed.

### [Generic Function Calls](https://ziglang.org/download/0.11.0/release-notes.html#toc-Generic-Function-Calls) [§](https://ziglang.org/download/0.11.0/release-notes.html#Generic-Function-Calls)

Sometimes the language design drives the [Compiler](https://ziglang.org/download/0.11.0/release-notes.html#Compiler) development, but sometimes it's the other way around, as we discover through trial and error what _fundamental simplicity_ looks like.

In this case, generic functions and inferred error sets have been reworked for a few reasons:

-   To make the language simpler to specify.
-   To make the compiler implementation simpler.
-   Progress towards [Incremental Compilation](https://ziglang.org/download/0.11.0/release-notes.html#Incremental-Compilation).

Things are mostly the same, except there may be two kinds of breakages caused by it. Firstly, type declarations are evaluated for every generic function call:

generic\_call\_demo.zig

```
const std = @import("std");
const expect = std.testing.expect;

test "generic call demo" {
    const a = foo(i32, 1234);
    const b = foo(i32, 5678);
    try expect(@TypeOf(a) == @TypeOf(b));
}

fn foo(comptime T: type, init: T) struct { x: T } {
    return .{ .x = init };
}
```

Shell

$ zig test generic\_call\_demo.zig
1/1 test.generic call demo... FAIL (TestUnexpectedResult)
/home/andy/Downloads/zig/lib/std/testing.zig:515:14: 0x22423f in expect (test)
    if (!ok) return error.TestUnexpectedResult;
             ^
/home/andy/tmp/docgen\_tmp/generic\_call\_demo.zig:7:5: 0x224375 in test.generic call demo (test)
    try expect(@TypeOf(a) == @TypeOf(b));
    ^
0 passed; 0 skipped; 1 failed.
error: the following test command failed with exit code 1:
/home/andy/.cache/zig/o/1badee6b5c51bdd719adb838ec138cd4/test

With Zig 0.10.x, this test passed. With 0.11.0, it fails. Which behavior Zig will have at 1.0 is yet to be determined. In the meantime, it is best not to rely on type equality in this case.

Suggested workaround is to make a function that returns the type:

generic\_call\_workaround.zig

```
const std = @import("std");
const expect = std.testing.expect;

test "generic call demo" {
    const a = foo(i32, 1234);
    const b = foo(i32, 5678);
    try expect(@TypeOf(a) == @TypeOf(b));
}

fn foo(comptime T: type, init: T) Make(T) {
    return .{ .x = init };
}

fn Make(comptime T: type) type {
    return struct { x: T };
}
```

Shell

$ zig test generic\_call\_workaround.zig
1/1 test.generic call demo... OK
All 1 tests passed.

The second fallout from this change is mutually recursive functions with inferred error sets:

inferred\_mutual\_recursion.zig

```
const std = @import("std");

test "generic call demo" {
    try foo(49);
}

fn foo(x: i32) !void {
    if (x == 1000) return error.BadNumber;
    return bar(x - 1);
}

fn bar(x: i32) !void {
    if (x > 100000) return error.TooBig;
    if (x == 0) return;
    return foo(x - 1);
}
```

Shell

$ zig test inferred\_mutual\_recursion.zig
docgen\_tmp/inferred\_mutual\_recursion.zig:12:1: error: unable to resolve inferred error set
fn bar(x: i32) !void {
^~~~~~~~~~~~~~~~~~~~
referenced by:
    foo: docgen\_tmp/inferred\_mutual\_recursion.zig:9:12
    bar: docgen\_tmp/inferred\_mutual\_recursion.zig:15:12
    remaining reference traces hidden; use '-freference-trace' to see all reference traces

Suggested workaround is to introduce an explicit error set:

error\_set\_workaround.zig

```
const std = @import("std");

test "mutual recursion inferred error set demo" {
    try foo(49);
}

const Error = error{ BadNumber, TooBig };

fn foo(x: i32) Error!void {
    if (x == 1000) return error.BadNumber;
    return bar(x - 1);
}

fn bar(x: i32) Error!void {
    if (x > 100000) return error.TooBig;
    if (x == 0) return;
    return foo(x - 1);
}
```

Shell

$ zig test error\_set\_workaround.zig
1/1 test.mutual recursion inferred error set demo... OK
All 1 tests passed.

More information: [#16318](https://github.com/ziglang/zig/issues/16318)

### [Naked Functions](https://ziglang.org/download/0.11.0/release-notes.html#toc-Naked-Functions) [§](https://ziglang.org/download/0.11.0/release-notes.html#Naked-Functions)

Some things that used to be allowed in `callconv(.Naked)` functions are now compile errors:

-   runtime calls
-   explicit returns
-   runtime safety checks (which produce runtime calls)

Runtime calls are disallowed because it is not possible to know the current stack alignment in order to follow the proper ABI to automatically compile a call. Explicit returns are disallowed because on some targets, it is not mandated for the return address to be stored in a consistent place.

* * *

The most common kind of upgrade that needs to be performed is:

example.zig

```
pub export fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\ push %rbp
        \\ jmp %[start:P]
        :
        : [start] "X" (&start),
    );
    unreachable;
}
fn start() void {}
```

Shell

$ zig build-exe example.zig
example.zig:8:5: error: runtime safety check not allowed in naked function
    unreachable;
    ^~~~~~~~~~~
example.zig:8:5: note: use @setRuntimeSafety to disable runtime safety
example.zig:8:5: note: the end of a naked function is implicitly unreachable

As the note indicates, an explicit `unreachable` is not needed at the end of a naked function anymore. Since explicit returns are no longer allowed, it will just be assumed to be unreachable. Therefore, all that needs to be done is to delete the `unreachable` statement, which works even when the return type of the function is not `unreachable`.

* * *

In general, naked functions should only contain comptime logic and `asm volatile` statements, which allows any required target-specific runtime calls and returns to be constructed.

### [@embedFile Supports Module-Mapped Names](https://ziglang.org/download/0.11.0/release-notes.html#toc-embedFile-Supports-Module-Mapped-Names) [§](https://ziglang.org/download/0.11.0/release-notes.html#embedFile-Supports-Module-Mapped-Names)

The `@embedFile` builtin, as well as literal file paths, now supports module-mapped names, like `@import`.

embed\_module.zig

```
// This embeds the contents of the root file of the module 'foo'.
const data = @embedFile("foo");
```

## [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#toc-Standard-Library) [§](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library)

The Zig standard library is still unstable and mainly serves as a testbed for the language. After there are no more planned [Language Changes](https://ziglang.org/download/0.11.0/release-notes.html#Language-Changes), it will be time to start working on stabilizing the standard library. Until then, experimentation and breakage without warning is allowed.

-   DynLib.lookup: cast the pointer to the correct alignment ([#15308](https://github.com/ziglang/zig/issues/15308))
-   std.process: avoids allocating zero length buffers for args or env on [WebAssembly](https://ziglang.org/download/0.11.0/release-notes.html#WebAssembly)
-   std.process: remove unused function getSelfExeSharedLibPaths
-   std.process.Child: implement maxrss on Darwin
-   std.process.Child: remove pid and handle, add id. Previously, this API had pid, to be used on POSIX systems, and handle, to be used on Windows. This change unifies the API, defining an Id type that is either the pid or the HANDLE depending on the target OS.
-   Introduce std.process.Child.collectOutput ([#12295](https://github.com/ziglang/zig/issues/12295))
-   std.Target: add xtensa to toCoffMachine
-   std.Target.ObjectFormat: specify dxcontainer file ext
-   std.target: adds ps4 and ps5 type sizes.
-   std.Target: fixes to \`ptrBitWidth\`, \`c\_type\_byte\_size\`, and \`c\_type\_alignment\`.
-   std.target.riscv: fix baseline\_rv32 missing feature "32bit"
-   std.target: mark helper functions inline so that callsites don't need `comptime`
-   std: remove meta.assumeSentinel ([#14440](https://github.com/ziglang/zig/issues/14440))
-   std: add meta.FieldType
-   std.meta: remove bitCount
-   std: fixed handling of empty structs in meta.FieldEnum.
-   std.meta: remove isTag ([#15584](https://github.com/ziglang/zig/issues/15584)).
-   std.meta: allow ArgsTuple to be used on functions with comptime parameters
-   std.meta: remove tagName
-   Update std.meta.intToEnum to support non-exhaustive enums, which was preventing \`std.json\` from deserializing non-exhaustive enums ([#15491](https://github.com/ziglang/zig/issues/15491)).
-   std: stop using LinearFifo in BufferedReader ([#14029](https://github.com/ziglang/zig/issues/14029))
-   std.io.reader.Reader: add \`streamUntilDelimiter\`
-   std.io.Writer: add support for non-power-of-two int sizes
-   Fix type mismatch for Reader.readIntoBoundedBytes ([#16416](https://github.com/ziglang/zig/issues/16416))
-   std.io.multi-writer: support non-comptime streams ([#15770](https://github.com/ziglang/zig/issues/15770)).
-   Add 0-length buffer checks to os.read and os.write, preventing errors related to undefined pointers being passed through to some OS APIs when slices have 0 length.
-   std.os: fix alignment of Sigaction.handler\_fn ([#13418](https://github.com/ziglang/zig/issues/13418))
-   std.os.sigprocmask: @bitCast flags parameter
-   \`os.isCygwinPty\`: Fix a bug, replace kernel32 call, and optimize ([#14841](https://github.com/ziglang/zig/issues/14841))
-   std.os: add mincore syscall which is available on some UNIX like operating systems and allows a user to determine if a page is resident in memory.
-   std.os: add missing mmap errors
-   start code: Don't initialize the static TLS area in single-threaded builds
-   Make std.tz namespace accessible ([#13978](https://github.com/ziglang/zig/issues/13978))
-   std: add object format extension for dxcontainer
-   std: Add Wasm SIMD opcodes and value type ([#13910](https://github.com/ziglang/zig/issues/13910))
-   std: fix bug in Pcg32 fill function ([#13894](https://github.com/ziglang/zig/issues/13894))
-   std.ascii: remove Look-Up-Table ([#13370](https://github.com/ziglang/zig/issues/13370)).
-   Improve and remove duplicate doNotOptimizeAway() implementations ([#13790](https://github.com/ziglang/zig/issues/13790))
-   std.Random: add functions with explicit index type ([#13417](https://github.com/ziglang/zig/issues/13417)).
-   add std.c.pthread\_sigmask ([#13525](https://github.com/ziglang/zig/issues/13525))
-   std.time: add microTimestamp() ([#13327](https://github.com/ziglang/zig/issues/13327))
-   std: Make getenv return 0-terminated slice
-   publicize std.rand.ziggurat
-   std: Snake-case some public facing enums ([#15803](https://github.com/ziglang/zig/issues/15803)).
-   std: Move TTY from std.debug to std.io and add missing colors ([#15806](https://github.com/ziglang/zig/issues/15806)).
-   std.enums: make Ext parameter optional
-   std.enums: add tagName(), an alternative to \`@tagName()\` for non-exhaustive enums that doesn't panic when given an enum value that has no tag.
-   elf: add more missing defs for SHT\_\* and SHF\_\*
-   elf: add helpers for extracting type and bind from symbol def
-   std.simd: add wasm-simd support for suggestVectorSizeForCpu ([#14992](https://github.com/ziglang/zig/issues/14992))
-   std.base64: don't overflow dest with padding
-   Fix counting in SingleThreadedRwLock's tryLockShared ([#16560](https://github.com/ziglang/zig/issues/16560))
-   introduce std.io.poll ([#14744](https://github.com/ziglang/zig/issues/14744))
-   std.c: Add umask.

### [Compile-Time Configuration Consolidated](https://ziglang.org/download/0.11.0/release-notes.html#toc-Compile-Time-Configuration-Consolidated) [§](https://ziglang.org/download/0.11.0/release-notes.html#Compile-Time-Configuration-Consolidated)

[collect all options under one namespace](https://github.com/ziglang/zig/pull/14181)

### [Memory Allocation](https://ziglang.org/download/0.11.0/release-notes.html#toc-Memory-Allocation) [§](https://ziglang.org/download/0.11.0/release-notes.html#Memory-Allocation)

-   Add std.ArenaAllocator.reset() ([#12590](https://github.com/ziglang/zig/issues/12590))
-   Adds std.heap.MemoryPool ([#12586](https://github.com/ziglang/zig/issues/12586))
-   std.heap.raw\_c\_allocator: fix illegal alignment cast ([#14090](https://github.com/ziglang/zig/issues/14090)).
-   std.mem.ValidationAllocator: forward free() calls ([#15978](https://github.com/ziglang/zig/issues/15978))
-   arena\_allocator/reset: fix use after free, fix buffer overrun ([#15985](https://github.com/ziglang/zig/issues/15985)).
-   std.mem.Allocator: add error when passing a non-single-item pointer to allocator.destroy
-   std: GPA deinit return an enum instead of a bool
-   GPA: Catch invalid frees ([#14791](https://github.com/ziglang/zig/issues/14791)).
-   Optimize Allocator functions to create less duplicate code for similar types ([#16332](https://github.com/ziglang/zig/issues/16332)).

#### [Allow Shrink To Fail](https://ziglang.org/download/0.11.0/release-notes.html#toc-Allow-Shrink-To-Fail) [§](https://ziglang.org/download/0.11.0/release-notes.html#Allow-Shrink-To-Fail)

The Allocator interface now allows implementations to refuse to shrink ([#13666](https://github.com/ziglang/zig/issues/13666)). This makes ArrayList more efficient because it avoids copying allocated but unused bytes by attempting a resize in place, and falling back to allocating a new buffer and doing its own copy. With a realloc() call, the allocator implementation would pointlessly copy the extra capacity:

array\_list.zig

```
const old_memory = self.allocatedSlice();
if (allocator.resize(old_memory, new_capacity)) {
    self.capacity = new_capacity;
} else {
    const new_memory = try allocator.alignedAlloc(T, alignment, new_capacity);
    @memcpy(new_memory[0..self.items.len], self.items);
    allocator.free(old_memory);
    self.items.ptr = new_memory.ptr;
    self.capacity = new_memory.len;
}
```

It also enabled implementing [WasmAllocator](https://ziglang.org/download/0.11.0/release-notes.html#WasmAllocator) which was not possible with the previous interface requirements.

### [Strings](https://ziglang.org/download/0.11.0/release-notes.html#toc-Strings) [§](https://ziglang.org/download/0.11.0/release-notes.html#Strings)

-   Removed std.cstr ([#16032](https://github.com/ziglang/zig/issues/16032))
-   std: Handle field struct defaults in std.mem.zeroInit ([#14116](https://github.com/ziglang/zig/issues/14116)).
-   add std.mem.reverseIterator
-   std: added std.mem.window
-   Handle sentinel slices in \`std.mem.zeroes\` ([#13256](https://github.com/ziglang/zig/issues/13256))
-   std: add mem.SplitIterator.peek() ([#15670](https://github.com/ziglang/zig/issues/15670))
-   std.mem.zeroes now works with allowzero pointers
-   mem: rename alignForwardGeneric to mem.alignForward
-   privatize std.mem.writePackedIntBig and writePackedIntLittle. These are unnecessary since writePackedInt accepts an endian parameter.
-   Split \`std.mem.split\` and \`tokenize\` into \`sequence\`, \`any\`, and \`scalar\` versions ([#15579](https://github.com/ziglang/zig/issues/15579)).
-   std.mem.byteSwapAllFields: add support for nested structs ([#15696](https://github.com/ziglang/zig/issues/15696))
-   std.mem.zeroInit: zero hidden padding for extern struct
-   Add std.mem.indexOfNone
-   std.mem.reverseIterator improvements ([#15134](https://github.com/ziglang/zig/issues/15134))

#### [Restrict mem.span and mem.len to Sentinel-Terminated Pointers](https://ziglang.org/download/0.11.0/release-notes.html#toc-Restrict-memspan-and-memlen-to-Sentinel-Terminated-Pointers) [§](https://ziglang.org/download/0.11.0/release-notes.html#Restrict-memspan-and-memlen-to-Sentinel-Terminated-Pointers)

[Isaac Freund](https://isaacfreund.com/) writes:

These functions were footgunny when working with pointers to arrays and slices. They just returned the stated length of the array/slice without iterating and looking for the first sentinel, even if the array/slice is a sentinel-terminated type.

From looking at the quite small list of places in the [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) and [Compiler](https://ziglang.org/download/0.11.0/release-notes.html#Compiler) that this change breaks existing code, the new code looks to be more readable in all cases.

The usage of std.mem.span/len was totally unneeded in most of the cases affected by this breaking change.

We could remove these functions entirely in favor of other existing functions in std.mem such as std.mem.sliceTo(), but that would be a somewhat nasty breaking change as std.mem.span() is very widely used for converting sentinel terminated pointers to slices. It is however not at all widely used for anything else.

Therefore I think it is better to break these few non-standard and potentially incorrect usages of these functions now and at some later time, if deemed worthwhile, finally remove these functions.

If we wait for at least a full release cycle so that everyone adapts to this change first, updating for the removal could be a simple find and replace without needing to worry about the semantics.

### [Math](https://ziglang.org/download/0.11.0/release-notes.html#toc-Math) [§](https://ziglang.org/download/0.11.0/release-notes.html#Math)

-   Remove math.ln in favor of `@log`
-   Implements math.sign for float vectors.
-   math.big.int: implement popCount() for Const
-   big.int.Mutable: fix set(@as(DoubleLimb, 0)). Previously, this would set len to 1 but fail to initialize any limbs.
-   math: implement absInt for integer vectors. This commit adds support to absInt for integer vectors.
-   math: port \`int\_log10\` from Rust ([#14827](https://github.com/ziglang/zig/issues/14827))
-   math: add lerp ([#13002](https://github.com/ziglang/zig/issues/13002))
-   math.big.int: Initialize limbs in addWrap, preventing invalid results ([#13571](https://github.com/ziglang/zig/issues/13571))
-   Normalize remainder in math.big.int.Managed.divTrunc ([#15535](https://github.com/ziglang/zig/issues/15535)).
-   math.atan: fix mistyped magic constant
-   math.big.int: Add Sqrt (with reference to Modern Computer Arithmetic, Algorithm 1.13)
-   math.big.int: rename "eq" to "eql" for consistency ([#16303](https://github.com/ziglang/zig/issues/16303)).
-   Change math.Order integer tag values, speeding up binary search ([#16356](https://github.com/ziglang/zig/issues/16356)).

### [File System](https://ziglang.org/download/0.11.0/release-notes.html#toc-File-System) [§](https://ziglang.org/download/0.11.0/release-notes.html#File-System)

-   std.fs.path: add stem() ([#13276](https://github.com/ziglang/zig/issues/13276))
-   os.windows.OpenFile: Add \`USER\_MAPPED\_FILE\` as a possible error
-   Dir.openDirAccessMaskW: Add ACCESS\_DENIED as a possible error
-   Dir.statFile now uses fstatat (fewer syscalls) ([#11594](https://github.com/ziglang/zig/issues/11594))
-   std: add fchmodat as well as \`std.fs.has\_executable\_bit\` for doing conditional compilation.
-   windows: use NtSetInformationFile in DeleteFile ([#15316](https://github.com/ziglang/zig/issues/15316)).
-   fs.Dir.deleteTree: Fix DirNotEmpty condition
-   fs.path: Fix Windows path component comparison being ASCII-only ([#16100](https://github.com/ziglang/zig/issues/16100))
-   std.windows: use posix semantics to delete files, if available ([#15501](https://github.com/ziglang/zig/issues/15501))
-   fixed windows resource leaks ([#15450](https://github.com/ziglang/zig/issues/15450)).
-   A few \`IterableDir.Walker\`/\`Iterator\` fixes ([#15980](https://github.com/ziglang/zig/issues/15980))
-   Add fs.path.ComponentIterator and use it in Dir.makePath, fixing some bugs
-   os.renameatW: Handle OBJECT\_NAME\_COLLISION from NtSetInformationFile ([#16374](https://github.com/ziglang/zig/issues/16374))

### [Data Structures](https://ziglang.org/download/0.11.0/release-notes.html#toc-Data-Structures) [§](https://ziglang.org/download/0.11.0/release-notes.html#Data-Structures)

-   std: added pure functions to StaticBitSet and EnumSet
-   The following functions were added to both IntegerBitSet and ArrayBitSet:
    -   `fn eql(self: Self, other: Self) bool`
    -   `fn subsetOf(self: Self, other: Self) bool`
    -   `fn supersetOf(self: Self, other: Self) bool`
    -   `fn complement(self: Self) Self`
    -   `fn unionWith(self: Self, other: Self) Self`
    -   `fn intersectWith(self: Self, other: Self) Self`
    -   `fn xorWith(self: Self, other: Self) Self`
    -   `fn differenceWith(self: Self, other: Self) Self`
-   std.MultiArrayList: add support for tagged unions.
-   Add more [Sorting](https://ziglang.org/download/0.11.0/release-notes.html#Sorting) functions to MultiArrayList ([#16377](https://github.com/ziglang/zig/issues/16377))
-   std.ArrayHashMap: capacity function now accepts const instance
-   std.atomic.Queue: fix unget implementation and add docs
-   Add fromOwnedSliceSentinel to ArrayList ArrayList and ArrayListUnmanaged, add fromOwnedSlice to ArrayListUnmanaged
-   Add the two functions 'getLast' and 'getLastOrNull' to ArrayListAligned/ArrayListAlignedUnmanaged.
-   std: Expose Int parameter in std.PackedInt\[Array,Slice\]
-   ArrayList.toOwnedSlice: Fix potential for leaks when using errdefer ([#13946](https://github.com/ziglang/zig/issues/13946))
-   Allow const ArrayLists to be cloned
-   Smaller memory footprint for BoundedArray ([#16299](https://github.com/ziglang/zig/issues/16299))
-   \[priority\_dequeue\] Fix out-of-bounds access
-   \[priority\_dequeue\] simplify and optimize isMinLayer ([#16124](https://github.com/ziglang/zig/issues/16124)).
-   std: Fix update() method in PriorityQueue and PriorityDequeue ([#13908](https://github.com/ziglang/zig/issues/13908))
-   \[priority\_queue\] Simplify sifting and fix edge case
-   std.IndexedSet.iterator: allow iteration on const EnumSet
-   std: implement subsetOf and supersetOf for EnumMultiset
-   std: implement subsetOf and supersetOf for DynamicBitSet
-   std: add EnumMultiSet
-   std: Add ArrayList.insertAssumeCapacity()
-   ArrayList: Allow const for getLast ([#14522](https://github.com/ziglang/zig/issues/14522))
-   std.enums.IndexedSet: Add initOne and initMany
-   std: added eql to DynamicBitSet and DynamicBitSetUnmanaged

### [Sorting](https://ziglang.org/download/0.11.0/release-notes.html#toc-Sorting) [§](https://ziglang.org/download/0.11.0/release-notes.html#Sorting)

Sorting is now split into two categories: stable and unstable. Generally, it's best to use unstable if you can, but stable is a more conservative choice. Zig's stable sort remains a blocksort implementation, while unstable sort is a new pdqsort implementation. heapsort is also available in the standard library ([#15412](https://github.com/ziglang/zig/issues/15412)).

Now, debug builds have assertions to ensure that the comparator function (`lessThan`) does not return conflicting results ([#16183](https://github.com/ziglang/zig/issues/16183)).

std.sort.binarySearch: relax requirements to support both homogeneous and heterogeneous keys ([#12727](https://github.com/ziglang/zig/issues/12727)).

### [Compression](https://ziglang.org/download/0.11.0/release-notes.html#toc-Compression) [§](https://ziglang.org/download/0.11.0/release-notes.html#Compression)

-   Added xz decoder ([#14434](https://github.com/ziglang/zig/issues/14434))
-   Implement gzip header CRC check.
-   std.compress: Improve tests, remove reliance on openDirAbsolute ([#13952](https://github.com/ziglang/zig/issues/13952))
-   std.tar: make sub dirs + trim spaces ([#15222](https://github.com/ziglang/zig/issues/15222))
-   gzip: add missing header fields and bounds for header parsing ([#13142](https://github.com/ziglang/zig/issues/13142))
-   Added Zstandard decompressor ([#14183](https://github.com/ziglang/zig/issues/14183))
-   Added zlib stream writer ([#15010](https://github.com/ziglang/zig/issues/15010)).
-   Added LZMA decoder ([#14518](https://github.com/ziglang/zig/issues/14518))

### [Crypto](https://ziglang.org/download/0.11.0/release-notes.html#toc-Crypto) [§](https://ziglang.org/download/0.11.0/release-notes.html#Crypto)

[Frank Denis](https://www.prettysimpleimages.com/) writes:

#### [New Features](https://ziglang.org/download/0.11.0/release-notes.html#toc-New-Features) [§](https://ziglang.org/download/0.11.0/release-notes.html#New-Features)

-   Salsa20: round-reduced variants can now be used.
-   The POLYVAL universal hash function was added.
-   AEGIS: support for 256-bit tags was added.
-   A MAC API was added to AEGIS (`std.crypto.auth.aegis`) - AEGIS can be used as a high-performance MAC on systems with hardware AES support. Note that this is not a hash function; a secret key is absolutely required in order to authenticate untrusted messages.
-   Edwards25519: a `rejectLowOrder()` function was added to quickly reject low-order points.
-   HKDF: with `extractInit()`, a PRK can now be initialized with only a salt, the keying material being added later, possibly as multiple chunks.
-   Hash functions that returns a fixed-length digest now include a `finalResult()` function that returns the digest as an array, as well as a `peek()` function that returns it without changing the state.
-   AES-CMAC has been implemented, and is available in `crypto.auth.cmac`.
-   `std.crypto.ecc`: the `isOdd()` function was added to return the parity of a field element.
-   `bcrypt`: bcrypt has a slightly annoying limitation: passwords are limited to 72 bytes, and additional bytes are silently ignored. A new option, `silently_truncate_password`, can be set to `true` to transparently pre-hash the passwords and overcome this limitation.
-   wyhash: support comptime usage ([#16070](https://github.com/ziglang/zig/issues/16070)).
-   std.hash.crc: implement algorithms listed in CRC RevEng catalog ([#14396](https://github.com/ziglang/zig/issues/14396))

#### [Breaking Changes](https://ziglang.org/download/0.11.0/release-notes.html#toc-Breaking-Changes) [§](https://ziglang.org/download/0.11.0/release-notes.html#Breaking-Changes)

-   A HMAC key size can have any length, and `crypto.Hmac*.key_size` was previously set to 256 bits for general guidance. This has been changed to match the actual security level of each function.
-   `secp256k1`: the `mulPublic()` and `verify()` functions can now return a `NonCanonicalError` in addition to existing errors.
-   `Ed25519`: the top-level `Ed25519.sign()`, `Ed25519.verify()`, `key_blinding.sign()` and `key_blinding.unblindPublicKey()` functions, that were already deprecated in version 0.10.0, have been removed. For consistency with other signature schemes, these functions have been moved to the `KeyPair`, `PublicKey`, `BlindKeyPair` and `BlindPublicKey` structures.

#### [Keccak](https://ziglang.org/download/0.11.0/release-notes.html#toc-Keccak) [§](https://ziglang.org/download/0.11.0/release-notes.html#Keccak)

The Keccak permutation was only used internally for `sha3`. It was completely revamped and has now its dedicated public interface in `crypto.core.keccak`.

`keccak.KeccakF` is the permutation itself, which now supports sizes between 200 and 1600 bits, as well as a configurable number of rounds. And `keccak.State` offers an API for standard sponge-based constructions.

Taking advantage of this, the SHAKE extendable output function (XOF) has been added, and can be found in `std.crypto.hash.sha3.Shake128` and `std.crypto.hash.sha3.Sha256`. SHAKE is based on SHA-3, NIST-approved, and the output of can be of any length, which has many applications and is something we were missing in the standard library.

The more recent TurboSHAKE variant is also available, as `crypto.hash.sha3.TurboShake128` and `crypto.hash.sha3.TurboShake256`. TurboSHAKE benefits from the extensive analysis of SHA-3, its output can also be of any length, and it has good performance across all platforms. In fact, on CPUs without SHA-256 acceleration, and when using WebAssembly, TurboSHAKE is the fastest function we have in the standard library. If you need a modern, portable, secure, overall fast hash function / XOF, that is not vulnerable to length-extension attacks (unlike SHA-256), TurboSHAKE should be your go-to choice.

#### [Kyber](https://ziglang.org/download/0.11.0/release-notes.html#toc-Kyber) [§](https://ziglang.org/download/0.11.0/release-notes.html#Kyber)

Kyber is a post-quantum public key encryption and key exchange mechanism. It was selected by NIST for the first post-quantum cryptography standard.

It is available in the standard library, in the `std.crypto.kem` namespace, making Zig the first language with post-quantum cryptography available right in the standard library.

`Kyber512`, `Kyber768` and `Kyber1024`, as specified in the current draft, are supported.

The [TLS Client](https://ziglang.org/download/0.11.0/release-notes.html#TLS-Client) also supports the hybrid `X25519Kyber768` post-quantum key agreement mechanism by default.

Thanks a lot to Bas Westerbaan for contributing this!

#### [Constant-Time, Allocation-Free Field Arithmetic](https://ziglang.org/download/0.11.0/release-notes.html#toc-Constant-Time-Allocation-Free-Field-Arithmetic) [§](https://ziglang.org/download/0.11.0/release-notes.html#Constant-Time-Allocation-Free-Field-Arithmetic)

Cryptography frequently requires computations over arbitrary finite fields.

This is why a new namespace made its appearance: `std.crypto.ff`.

Functions from this namespace never require dynamic allocations, are designed to run in constant time, and transparently perform conversions from/to the Montgomery domain.

This allowed us to implement RSA verification without using any allocators.

#### [Configurable Side Channels Mitigations](https://ziglang.org/download/0.11.0/release-notes.html#toc-Configurable-Side-Channels-Mitigations) [§](https://ziglang.org/download/0.11.0/release-notes.html#Configurable-Side-Channels-Mitigations)

Side channels in cryptographic code can be exploited to leak secrets.

And mitigations are useful but also come with a performance hit.

For some applications, performance is critical, and side channels may not be part of the threat model. For other applications, hardware-based attacks is a concern, and mitigations should go beyond constant-time code.

Zig 0.11 introduces the `std_options.side_channels_mitigations` global setting to accomodate the different use cases.

It can have 4 different values:

-   `none`: which doesn't enable additional mitigations. "Additional", because it only disables mitigations that don't have a big performance cost. For example, checking authentication tags will still be done in constant time.
-   `basic`: which enables mitigations protecting against attacks in a common scenario, where an attacker doesn't have physical access to the device, cannot run arbitrary code on the same thread, and cannot conduct brute-force attacks without being throttled.
-   `medium`: which enables additional mitigations, targeting protection against practical attacks even in a shared environment.
-   `full`: which enables all the available mitigations, going beyond ensuring that the code runs in constant time.

The more mitigations are enabled, the bigger the performance hit will be. But this lets applications choose what's best for their use case.

`medium` is the default.

#### [Hello Ascon; Farewell to Gimli and Xoodoo](https://ziglang.org/download/0.11.0/release-notes.html#toc-Hello-Ascon-Farewell-to-Gimli-and-Xoodoo) [§](https://ziglang.org/download/0.11.0/release-notes.html#Hello-Ascon-Farewell-to-Gimli-and-Xoodoo)

Gimli and Xoodoo have been removed from the standard library, in favor of Ascon.

These are great permutations, and there's nothing wrong with them from a practical security perspective.

However, both were competing in the NIST lightweight crypto competition.

Gimli didn't pass the 3rd selection round, and was not used much in the wild besides Zig and libhydrogen. It will never be standardized and is unlikely to get more traction in the future.

The Xoodyak mode, that Xoodoo is the permutation of, brought some really nice ideas. There are discussions to standardize a Xoodyak-like mode, but without Xoodoo.

So, the Zig implementations of these permutations are better maintained outside the standard library.

For lightweight crypto, Ascon is the one that we know NIST will standardize and that we can safely rely on from a usage perspective.

So, Ascon was added instead (in `crypto.core.Ascon`). We support the `128` and `128a` variants, both with Little-Endian or Big-Endian encoding.

Note that we currently only ship the permutation itself, as the actual constructions are very likely to change a lot during the ongoing standardization process.

The default CSPRNG (`std.rand.DefaultCsprng`) used to be based on Xoodoo. It was replaced by a traditional ChaCha-based random number generator, that also improves performance on most platforms.

For constrained environments, `std.rand.Ascon` is also available as an alternative. As the name suggest, it's based on Ascon, and has very low memory requirements.

#### [std.crypto Bug Fixes](https://ziglang.org/download/0.11.0/release-notes.html#toc-stdcrypto-Bug-Fixes) [§](https://ziglang.org/download/0.11.0/release-notes.html#stdcrypto-Bug-Fixes)

-   HKDF: expansion to `<hash size> * 255` bytes not an error any more.
-   Curve25519: when compiled to WebAssembly, scalar multiplication emitted too many local variables for some runtimes. This has been fixed. The code is also significantly smaller in `ReleaseSmall` mode.
-   Prime-order curves: points whose X coordinate was `0` used to be rejected with an `IdentityElement` error. These points were also not properly serialized. That has been fixed.
-   Argon2: outputs larger than 64 bytes are now correctly handled.
-   std.hash\_map: fetchRemove increment available to avoid leaking slots ([#15989](https://github.com/ziglang/zig/issues/15989)).

#### [Performance Improvements](https://ziglang.org/download/0.11.0/release-notes.html#toc-Performance-Improvements) [§](https://ziglang.org/download/0.11.0/release-notes.html#Performance-Improvements)

-   GHASH was reimplemented and is now ~3x faster.
-   AES encryption now takes advantage of the `EOR3` instruction on Apple Silicon for a slight performance boost.
-   The ChaCha20 implementation can now take advantage of CPUs with 256 and 512 bit vector registers for a significant speedup.
-   Poly1305 got a little bit faster, too.
-   SHA256 can take advantage of hardware acceleration on x86\_64 and aarch64.
-   Reimplement wyhash v4.1 ([#15969](https://github.com/ziglang/zig/issues/15969))
-   Improvements for xxHash performance, both on small keys as well as large slices ([#15947](https://github.com/ziglang/zig/issues/15947)).

### [Concurrency](https://ziglang.org/download/0.11.0/release-notes.html#toc-Concurrency) [§](https://ziglang.org/download/0.11.0/release-notes.html#Concurrency)

-   stdlib: fix condition variable broadcast FutexImpl ([#13577](https://github.com/ziglang/zig/issues/13577)).
-   std.Thread.Futex.PosixImpl.Address.from: fix \`alignment\` type ([#13673](https://github.com/ziglang/zig/issues/13673))
-   std.Thread: make Id smaller where possible
-   Add a debug implementation to Mutex that detects deadlocks caused by calling lock twice in a single thread.

### [Networking](https://ziglang.org/download/0.11.0/release-notes.html#toc-Networking) [§](https://ziglang.org/download/0.11.0/release-notes.html#Networking)

For a few releases, there was a `std.x` namespace which was a playground for some contributors to experiment with networking. In Zig 0.11, networking is no longer experimental; it is part of the [Package Management](https://ziglang.org/download/0.11.0/release-notes.html#Package-Management) strategy. However, networking is still immature and [buggy](https://ziglang.org/download/0.11.0/release-notes.html#Bug-Fixes), so use it at your own risk.

-   net: Make `res` nullable in `std.c.getaddrinfo`
-   net: check for localhost names before asking DNS
-   remove std.url and add std.uri which is more complete and RFC-compliant ([#14176](https://github.com/ziglang/zig/issues/14176)).
-   net.StreamServer.Options: add reuse\_port
-   Uri: Don't double-escape escaped query parameters ([#16043](https://github.com/ziglang/zig/issues/16043))
-   os.connect: mark ECONNABORTED as unreachable ([#13677](https://github.com/ziglang/zig/issues/13677)).
-   os.sendfile: On BrokenPipe error, return error rather than unreachable
-   os.bind: handle EPERM errno

#### [TLS Client](https://ziglang.org/download/0.11.0/release-notes.html#toc-TLS-Client) [§](https://ziglang.org/download/0.11.0/release-notes.html#TLS-Client)

Zig 0.11.0 now provides a client implementation of [Transport Layer Security v1.3](https://datatracker.ietf.org/doc/html/rfc8446)

Thanks to Zig's excellent [Crypto](https://ziglang.org/download/0.11.0/release-notes.html#Crypto), the [implementation](https://github.com/ziglang/zig/blob/0.11.0/lib/std/crypto/tls/Client.zig) came out lovely. Search for `++` if you want to see a nice demonstration of [Concatenation of Arrays and Tuples](https://ziglang.org/download/0.11.0/release-notes.html#Concatenation-of-Arrays-and-Tuples). This is also a nice showcase of [inline switch cases](https://ziglang.org/documentation/0.11.0/#Inline-switch).

As lovely as it may be, there is not yet a TLS server implementation and so this code has not been fuzz-tested. In fact there is not yet _any_ automated testing for this API, so use it at your own risk.

I want to recognize [Shigueredo](https://shiguredo.jp/) whose TLSv1.3 implementation I took inspiration from. For [sponsoring](https://ziglang.org/download/0.11.0/release-notes.html#Thank-You-Sponsors) us and for allowing us to copy their RSA implementation until Frank Denis implemented [Constant-Time, Allocation-Free Field Arithmetic](https://ziglang.org/download/0.11.0/release-notes.html#Constant-Time-Allocation-Free-Field-Arithmetic), 本当にありがとうございました!

The TLS client is a dependency of the [HTTP Client](https://ziglang.org/download/0.11.0/release-notes.html#HTTP-Client) which is a dependency of [Package Management](https://ziglang.org/download/0.11.0/release-notes.html#Package-Management).

Open follow-up issues:

-   [send an alert message to the server when an error occurs](https://github.com/ziglang/zig/issues/14167)
-   [audit the implementation with respect to RFC 8446](https://github.com/ziglang/zig/issues/14178)
-   [test the implementation against many real world servers](https://github.com/ziglang/zig/issues/14172)
-   [look into TCP fastopen and TCP\_QUICKACK](https://github.com/ziglang/zig/issues/14173)
-   [increase test coverage](https://github.com/ziglang/zig/issues/14174)
-   [std.crypto.Certificate.verify: additionally verify "key usage](https://github.com/ziglang/zig/issues/14175)

#### [HTTP Client](https://ziglang.org/download/0.11.0/release-notes.html#toc-HTTP-Client) [§](https://ziglang.org/download/0.11.0/release-notes.html#HTTP-Client)

There is now an HTTP client ([#15123](https://github.com/ziglang/zig/issues/15123)). It is used by the [Compiler](https://ziglang.org/download/0.11.0/release-notes.html#Compiler) to fetch URLs as part of [Package Management](https://ziglang.org/download/0.11.0/release-notes.html#Package-Management).

It supports some basic features such as:

-   transfer-encoding: chunked ([#14224](https://github.com/ziglang/zig/issues/14224))
-   HTTP redirects ([#14202](https://github.com/ziglang/zig/issues/14202))
-   connection pooling, keep-alive, and compressed content ([#14762](https://github.com/ziglang/zig/issues/14762))

It is still very immature and not yet tested in a robust manner. Please use it at your own risk.

For more information, please refer to this article written by the maintainer of std.http: [Coming Soon to a Zig Near You: HTTP Client](https://zig.news/nameless/coming-soon-to-a-zig-near-you-http-client-5b81)

#### [Ignore SIGPIPE by Default](https://ziglang.org/download/0.11.0/release-notes.html#toc-Ignore-SIGPIPE-by-Default) [§](https://ziglang.org/download/0.11.0/release-notes.html#Ignore-SIGPIPE-by-Default)

Start code now tells the kernel to ignore SIGPIPE before calling main ([#11982](https://github.com/ziglang/zig/issues/11982)). This can be disabled by adding this to the root module:

```
pub const keep_sigpipe = true;
```

Adjust this for [Compile-Time Configuration Consolidated](https://ziglang.org/download/0.11.0/release-notes.html#Compile-Time-Configuration-Consolidated).

\`SIGPIPE\` is triggered when a process attempts to write to a broken pipe. By default, SIGPIPE will terminate the process without giving the program an opportunity to handle the situation. Unlike a segfault, it doesn't trigger the panic handler so all the developer sees is that the program terminated with no indication as to why.

By telling the kernel to instead ignore SIGPIPE, writes to broken pipes will return the EPIPE error (error.BrokenPipe) and the program can handle them like any other error.

### [Testing](https://ziglang.org/download/0.11.0/release-notes.html#toc-Testing) [§](https://ziglang.org/download/0.11.0/release-notes.html#Testing)

-   std.testing: Fully absorb expectEqualBytes into expectEqualSlices
-   std.testing: Improve expectEqualBytes for large inputs and make expectEqualSlices use it
-   std.testing: Add expectEqualBytes that outputs hexdumps with diffs highlighted in red. The coloring is controlled by \`std.debug.detectTTYConfig\` so it will be disabled when appropriate.
-   std: add expectEqualDeep ([#13995](https://github.com/ziglang/zig/issues/13995))

### [Debugging](https://ziglang.org/download/0.11.0/release-notes.html#toc-Debugging) [§](https://ziglang.org/download/0.11.0/release-notes.html#Debugging)

-   Added support for DWARF5 `DW_AT_ranges` in subprograms. Some DWARF5 subprograms have non-contiguous instruction ranges, which wasn't supported before. An example of such a function is `puts` in Ubuntu's libc. Stack traces now include the names of these functions.
-   Support for DWARF information embedded inside COFF binaries has been fixed. This is relatively uncommon combination, as typically this information is in a PDB file, but can be output using `-gdwarf` when compiling C/C++ code for Windows.
-   std.debug: fix segfault/panic race condition ([#7859](https://github.com/ziglang/zig/issues/7859)) ([#12207](https://github.com/ziglang/zig/issues/12207)).
-   std.debug: Replace tabs with spaces when printing a line for trace output.
-   std.log: add functionality to check if a specific log level and scope are enabled
-   std.log.defaultLog: remove freestanding compile error
-   Added valgrind client request support for aarch64 ([#13292](https://github.com/ziglang/zig/issues/13292)).
-   std.dwarf: handle DWARF 5 compile unit DW\_AT\_ranges correctly
-   pdb: make SuperBlock def public

#### [Stack Unwinding](https://ziglang.org/download/0.11.0/release-notes.html#toc-Stack-Unwinding) [§](https://ziglang.org/download/0.11.0/release-notes.html#Stack-Unwinding)

[Casey Banner](https://github.com/kcbanner) writes:

When something goes wrong in your program, at the very least you expect it to output a stack trace. In many cases, upon seeing the stack trace, the error is obvious and can be fixed without needing to attach a debugger. If you are a project maintainer, having correct stack trace output is a necessity for your users to be able to provide actionable bug reports when something goes wrong.

In order to print a stack trace, the panic (or segfault) handler needs to unwind the stack, by traversing back through the stack frames starting at the crash site. Up until now, this was done strictly by utilizing the [frame pointer](https://en.wikipedia.org/wiki/Call_stack#Stack_and_frame_pointers). This method of stack unwinding works assuming that a frame pointer is available, which isn't the case if the code is compiled without one - ie. if `-fomit-frame-pointer`was used.

It can be beneficial for performance reasons to not use a frame pointer, since this frees up an additional register, so some software maintainers may choose to ship libraries compiled without it. One of the motivating reasons for this change was solving a bug where unwinding a stack trace that started in Ubuntu's libc wasn't working - and indeed it is compiled with `-fomit-frame-pointer`.

Since [#15823](https://github.com/ziglang/zig/pull/15823) was merged, the [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) stack unwinder (`std.debug.StackIterator`) now supports unwinding stacks using both DWARF unwind tables, and [MachO](https://ziglang.org/download/0.11.0/release-notes.html#MachO) compact unwind information. These unwind tables encode how to unwind all the register state and recover the return address for any location in the program.

In order to save space, DWARF unwind tables aren't program-sized lookup tables, but instead sets of opcodes which run on a virtual machine inside the unwinder to build the lookup table dynamically. Additionally, these tables can define register values in terms of DWARF expressions, which is a separate stack-machine based bytecode. This is all supported in the new unwinder.

As an example of how this improves stack trace output, consider the following zig program and C library (which will be built with `-fomit-frame-pointer`):

main.zig

```
const std = @import("std");

extern fn add_mult(x: i32, y: i32, n: ?*i32) i32;

pub fn main() !void {
    std.debug.print("add: {}\n", .{ add_mult(5, 3, null) });
}
```

lib.c

```
#include <stdio.h>

#ifndef LIB_API
#define LIB_API
#endif

int add_mult3(int x, int y, int* n) {
    puts((const char*)0x1234);
    return (x + y) * (*n);
}

int add_mult2(int x, int y, int* n) {
    return add_mult3(x, y, n);
}

int add_mult1(int x, int y, int* n) {
    return add_mult2(x, y, n);
}

LIB_API int add_mult(int x, int y, int* n) {
    return add_mult1(x, y, n);
}
```

Before the stack unwinding changes, the user would see the following output:

```
Segmentation fault at address 0x1234
???:?:?: 0x7f71d9ec997d in ??? (???)
/home/user/kit/zig/build-stage3-release-linux/lib/zig/std/start.zig:608:37: 0x20a505 in main (main)
            const result = root.main() catch |err| {
                                    ^
Aborted
```

With the new unwinder:

```
Segmentation fault at address 0x1234
../sysdeps/x86_64/multiarch/strlen-avx2.S:74:0: 0x7fefd03b297d in ??? (../sysdeps/x86_64/multiarch/strlen-avx2.S)
./libio/ioputs.c:35:16: 0x7fefd0295ee7 in _IO_puts (ioputs.c)
src/lib.c:8:5: 0x7fefd04484aa in add_mult3 (/home/user/temp/stack/src/lib.c)
    puts((const char*)0x1234);
    ^
src/lib.c:13:12: 0x7fefd0448542 in add_mult2 (/home/user/temp/stack/src/lib.c)
    return add_mult3(x, y, n);
           ^
src/lib.c:17:12: 0x7fefd0448572 in add_mult1 (/home/user/temp/stack/src/lib.c)
    return add_mult2(x, y, n);
           ^
src/lib.c:21:12: 0x7fefd04485a2 in add_mult (/home/user/temp/stack/src/lib.c)
    return add_mult1(x, y, n);
           ^
/home/user/temp/stack/src/main.zig:6:45: 0x2123b7 in main (main)
    std.debug.print("add: {}\n", .{ add_mult(5, 3, null) });
                                            ^
/home/user/kit/zig/build-stage3-release-linux/lib/zig/std/start.zig:608:37: 0x2129b4 in main (main)
            const result = root.main() catch |err| {
                                    ^
../sysdeps/nptl/libc_start_call_main.h:58:16: 0x7fefd023ed8f in __libc_start_call_main (../sysdeps/x86/libc-start.c)
../csu/libc-start.c:392:3: 0x7fefd023ee3f in __libc_start_main_impl (../sysdeps/x86/libc-start.c)
???:?:?: 0x212374 in ??? (???)
???:?:?: 0x0 in ??? (???)
Aborted
```

The unwind information for libc (which comes from a separate file, see below) was loaded and used to unwind the stack correctly, resulting in a much more useful stack trace.

If there is no unwind information available for a given frame, the unwinder will fall back to frame pointer unwinding for the rest of the stack trace. For example, if the above program is built for x86-linux-gnu on the same system (which only has x86\_64 libc debug information installed), it results in the following output:

```
Segmentation fault at address 0x1234
???:?:?: 0xf7dc9555 in ??? (libc.so.6)
Unwind information for `libc.so.6:0xf7dc9555` was not available (error.MissingDebugInfo), trace may be incomplete

???:?:?: 0x0 in ??? (???)
Aborted
```

The user is notified that unwind information is missing, and they could choose to install it to enhance the stack trace output.

This system works for both panic traces as well as segfaults. In the case of a segfault, the OS will pass a context (containing the state of all the registers at the time of the segfault) to the handler, which will be used by the unwinder. In the case of a panic, the unwinder still needs a register context, so one is captured by the panic handler. If the program is linking libc, then libc's `getcontext` is used, otherwise an implementation in `std` is used if available. On platforms where `getcontext` isn't available, the stack unwinder falls back to frame pointer based unwinding.

Implementations of `getcontext` have been added for `x86_64-linux` and `x86-linux`.

#### [External Debug Info](https://ziglang.org/download/0.11.0/release-notes.html#toc-External-Debug-Info) [§](https://ziglang.org/download/0.11.0/release-notes.html#External-Debug-Info)

The ELF format allows for splitting debug information sections into separate files. If the user of the software does not typically need to debug it, then debug info can be shipped an as optional dependency to reduce the size of the installation. A primary use case for this feature is libc debug information, which can be quite large. Some distributions have a separate package that contains only the debug info for their libc, which can be installed separately.

These extra files are simply additional ELF files that contain only the debug info sections. As an additional space-saving measure, these sections can also be compressed. For example, in the libc stack traces above the debug information came from `/usr/lib/debug/.build-id/69/389d485a9793dbe873f0ea2c93e02efaa9aa3d.debug`, not `libc.so.6`.

Support for reading external debug information has been added, with this set of changes:

-   Support reading the build-id from the elf headers in order to lookup external debug info
-   Support reading the `.gnu_debuglink` section to look up external debug info
-   Add support for reading compressed ELF sections
-   Rework how sections are loaded from disk in order to support merging the list of sections that are present in the binary itself and the ones from the external debug info
-   Fixed up some memory management issues with the existing debug information loader

### [Formatted Printing](https://ziglang.org/download/0.11.0/release-notes.html#toc-Formatted-Printing) [§](https://ziglang.org/download/0.11.0/release-notes.html#Formatted-Printing)

-   Consistent use of "invalid format string" compile error response for badly formatted format strings ([#13526](https://github.com/ziglang/zig/issues/13526))
-   Make invalidFmtError public and use in place of compileErrors for bad format strings ([#13526](https://github.com/ziglang/zig/issues/13526))
-   std.fmt.formatInt: Use an optimized path for decimals, enabling faster decimal-to-string conversions for values in the range \[0, 100).
-   Fix buffer overflow in fmt when DAZ is set ([#14270](https://github.com/ziglang/zig/issues/14270)).
-   parse\_float: Error when a float is attempted to be parsed into an invalid type ([#15593](https://github.com/ziglang/zig/issues/15593)).
-   Add std.fmt.parseIntSizeSuffix and use for --maxrss ([#14955](https://github.com/ziglang/zig/issues/14955))
-   std.fmt.parseIntSizeSuffix: add R and Q
-   std: expose fmt methods and structs for parsing
-   std: fix parseInt for single-digit signed minInt ([#15966](https://github.com/ziglang/zig/issues/15966))
-   std.fmt: fix error set of formatDuration ([#16093](https://github.com/ziglang/zig/issues/16093))
-   mark parse\_float.convertSlow as cold, reducing stack usage ([#16438](https://github.com/ziglang/zig/issues/16438)).
-   fmt: Make default\_max\_depth configurable
-   std.fmt: add bytesToHex() to encode bytes as hex digits
-   Fixed parseFloat parsing of \`0x\` ([#14901](https://github.com/ziglang/zig/issues/14901)).
-   std: improve error for formatting a function body type ([#14915](https://github.com/ziglang/zig/issues/14915))

### [JSON](https://ziglang.org/download/0.11.0/release-notes.html#toc-JSON) [§](https://ziglang.org/download/0.11.0/release-notes.html#JSON)

[Josh Wolfe](https://github.com/thejoshwolfe/) writes:

New `std.json` features:

-   Read a json document from a streaming source with `json.reader`. See `json.Token` for fine control over the interaction between large tokens, streaming input, and allocators.
-   Unlimited `{}` and `[]` nesting depth subject to allocator limitations.
-   After parsing into a dynamic `json.Value` tree/array union, you can now call `json.parseFromValue*` to parse that into a static type `T` following essentially the same semantics as parsing directly.
-   Parsing via `json.parseFrom*` is customizable by implementing `pub fn jsonParse` and/or `pub fn jsonParseFromValue` in your `struct`, `enum`, or `union(enum)`. This mirrors the customizable `pub fn jsonStringify` functionality.
-   Added a generic `json.HashMap(T)` container for serializing/deserializing objects with arbitrary string fields. It's a thin wrapper around `StringArrayHashMapUnmanaged` that implements `jsonParse`, `jsonParseFromValue`, and `jsonStringify`.
-   `json.WriteStream` features now available to custom `pub fn jsonStringify` implementations due to the unification of `json.stringify` and `json.WriteStream`.
-   Writing JSON now supports saving memory by disabling assertions for correct syntax, e.g. disabling assertions that `endArray` matches a corresponding `beginArray`.
-   `@Vector` support for std.json.parse

Here is an upgrade guide:

_These instructions include the breaking changes from [#15602](https://github.com/ziglang/zig/pull/15602), [#15705](https://github.com/ziglang/zig/pull/15705), [#15981](https://github.com/ziglang/zig/pull/15981), and [#16405](https://github.com/ziglang/zig/pull/16405)._

#### [`parse` replaced by `parseFromSlice` or other `parseFrom*`](https://ziglang.org/download/0.11.0/release-notes.html#toc-codeparsecode-replaced-by-codeparseFromSlicecode-or-other-codeparseFromcode) [§](https://ziglang.org/download/0.11.0/release-notes.html#codeparsecode-replaced-by-codeparseFromSlicecode-or-other-codeparseFromcode)

For code that used to look like this:

example.zig

```
var stream = json.TokenStream.init(slice);
const options = json.ParseOptions{ .allocator = allocator };
const result = try json.parse(T, &stream, options);
defer json.parseFree(T, result, options);
```

Now do this:

example.zig

```
const parsed = try json.parseFromSlice(T, allocator, slice, .{});
defer parsed.deinit();
const result = parsed.value;
```

##### [`parseFree` replaced by `Parsed(T).deinit()`](https://ziglang.org/download/0.11.0/release-notes.html#toc-codeparseFreecode-replaced-by-codeParsedTdeinitcode) [§](https://ziglang.org/download/0.11.0/release-notes.html#codeparseFreecode-replaced-by-codeParsedTdeinitcode)

See above. Alternatively, use the `parseFrom*Leaky` variants and manage your own arena.

#### [`Parser.parse` replaced by `parseFromSlice` into `Value`](https://ziglang.org/download/0.11.0/release-notes.html#toc-codeParserparsecode-replaced-by-codeparseFromSlicecode-into-codeValuecode) [§](https://ziglang.org/download/0.11.0/release-notes.html#codeParserparsecode-replaced-by-codeparseFromSlicecode-into-codeValuecode)

For code that used to look like this:

example.zig

```
var parser = json.Parser.init(allocator, false);
defer parser.deinit();
var tree = try parser.parse(slice);
defer tree.deinit();
const root = tree.root;
```

Now do this:

example.zig

```
const parsed = try json.parseFromSlice(json.Value, allocator, slice, .{});
defer parsed.deinit();
const root = parsed.value;
```

##### [`ValueTree` replaced by `Parsed(Value)`](https://ziglang.org/download/0.11.0/release-notes.html#toc-codeValueTreecode-replaced-by-codeParsedValuecode) [§](https://ziglang.org/download/0.11.0/release-notes.html#codeValueTreecode-replaced-by-codeParsedValuecode)

The result of `json.parseFrom*(T, ...)` (except for `json.parseFrom*Leaky(T, ...)`) is `json.Parsed(T)`, which replaces the old `ValueTree`.

#### [`writeStream` API simplification](https://ziglang.org/download/0.11.0/release-notes.html#toc-codewriteStreamcode-API-simplification) [§](https://ziglang.org/download/0.11.0/release-notes.html#codewriteStreamcode-API-simplification)

The default max depth for `writeStream` is now 256. To specify a deeper max depth, use `writeStreamMaxDepth`.

You don't need to call `arrayElem()` anymore.

All the `emit*()` methods (`emitNumber`, `emitString`, `emitBool`, `emitNull`, `emitJson`) replaced by the generic `write()` method, which takes `anytype`. The generic `json.stringify` functionality for structs, unions, etc. is also available in `WriteStream.write()` (the implementation of `stringify` now uses `WriteStream.write`.).

##### [Custom `jsonStringify` signature changed](https://ziglang.org/download/0.11.0/release-notes.html#toc-Custom-codejsonStringifycode-signature-changed) [§](https://ziglang.org/download/0.11.0/release-notes.html#Custom-codejsonStringifycode-signature-changed)

Instead of `pub fn jsonStringify(self: *@This(), options: json.StringifyOptions, out_stream: anytype) !void`, use `pub fn jsonStringify(self: *@This(), jw: anytype) !void`, where `jw` is a mutable pointer to a `WriteStream`. Instead of writing bytes to the `out_stream`, you should call `write()` and `beginObject` and such on the `WriteStream`.

##### [`stringify` limits nesting to 256 by default](https://ziglang.org/download/0.11.0/release-notes.html#toc-codestringifycode-limits-nesting-to-256-by-default) [§](https://ziglang.org/download/0.11.0/release-notes.html#codestringifycode-limits-nesting-to-256-by-default)

The depth of `{`/`[` nesting in the output of `json.stringify` is now 256. Now that the implementation of `stringify` uses a `WriteStream`, we have safety checks for matching `endArray` to `beginArray` and such, which requires memory: 1 bit per nesting level. To disable syntax checks and save that memory, use `stringifyMaxDepth(..., null)`. To make syntax checks available to custom `pub fn jsonStringify` implementations to arbitrary nesting depth, use `stringifyArbitraryDepth` and provide an allocator.

#### [`StringifyOptions` overhauled](https://ziglang.org/download/0.11.0/release-notes.html#toc-codeStringifyOptionscode-overhauled) [§](https://ziglang.org/download/0.11.0/release-notes.html#codeStringifyOptionscode-overhauled)

-   `escape_unicode` moved to the top level.
-   `escape_solidus` removed.
-   `string = .Array` replaced by `.emit_strings_as_arrays = true`.
-   `whitespace.indent_level` removed.
-   `whitespace.separator` and `whitespace.indent` combined into `.whitespace = .minified` vs `.whitespace = .indent_2` etc.

**The default whitespace in all contexts is now `.minified`.** This is changed from the old `WriteStream` having effectively `.indent_1`, and the old `StringifyOptions{ .whitespace = .{} }` having effectively `.indent_4`.

#### [`TokenStream` replaced by `Scanner`](https://ziglang.org/download/0.11.0/release-notes.html#toc-codeTokenStreamcode-replaced-by-codeScannercode) [§](https://ziglang.org/download/0.11.0/release-notes.html#codeTokenStreamcode-replaced-by-codeScannercode)

For code that used to look like this:

example.zig

```
var stream = json.TokenStream.init(slice);
while (try stream.next()) |token| {
    handleToken(token);
}
```

Now do this:

example.zig

```
var tokenizer = json.Scanner.initCompleteInput(allocator, slice);
defer tokenizer.deinit();
while (true) {
    const token = try tokenizer.next();
    if (token == .end_of_document) break;
    handleToken(token);
}
```

See `json.Token` for more info.

#### [`StreamingParser` replaced by `Reader`](https://ziglang.org/download/0.11.0/release-notes.html#toc-codeStreamingParsercode-replaced-by-codeReadercode) [§](https://ziglang.org/download/0.11.0/release-notes.html#codeStreamingParsercode-replaced-by-codeReadercode)

For code that used to look like this:

example.zig

```
const slice = try reader.readAllAlloc(allocator, max_size);
defer allocator.free(slice);
var tokenizer = json.StreamingParser.init();
for (slice) |c| {
    var token1: ?json.Token = undefined;
    var token2: ?json.Token = undefined;
    try tokenizer.feed(c, &token1, &token2);
    if (token1) |t| {
        handleToken(t);
        if (token2) |t2| handleToken(t2);
    }
}
```

Now do this:

example.zig

```
var stream = json.reader(allocator, reader);
defer stream.deinit();
while (true) {
    const token = try stream.next();
    if (token == .end_of_document) break;
    handleToken(token);
}
```

See `json.Token` for more info.

#### [parse/stringify for `union` types](https://ziglang.org/download/0.11.0/release-notes.html#toc-parsestringify-for-codeunioncode-types) [§](https://ziglang.org/download/0.11.0/release-notes.html#parsestringify-for-codeunioncode-types)

Parsing and stringifying `union(enum)` types works differently now by default. For `const T = union(enum) { s: []const u8, i: i32};`, the old behavior used to accept documents in the form `"abc"` or `123` to parse into `.{.s="abc"}` or `.{.i=123}` respectively; the new behavior accepts documents in the form `{"s":"abc"}` or `{"i":123}` instead. Stringifying is updated as well to maintain the bijection.

The dynamic value `json.Value` can be used for simple int-or-string cases. For more complex cases, you can implement `jsonParse`, `jsonParseFromValue`, and `jsonStringify` as needed.

#### [An allocator is always required for parsing now](https://ziglang.org/download/0.11.0/release-notes.html#toc-An-allocator-is-always-required-for-parsing-now) [§](https://ziglang.org/download/0.11.0/release-notes.html#An-allocator-is-always-required-for-parsing-now)

Sorry for the inconvenience. There are some ideas to restore support for allocatorless json parsing, but for now, you always must use an allocator. At a minimum it is used for tracking the `{}` vs `[]` nesting depth, and possibly other uses depending on what `std.json` API is being called.

If you use a `std.FixedBufferAllocator`, you can make parsing json work at comptime.

### [posix\_spawn Considered Harmful](https://ziglang.org/download/0.11.0/release-notes.html#toc-posix_spawn-Considered-Harmful) [§](https://ziglang.org/download/0.11.0/release-notes.html#posix_spawn-Considered-Harmful)

posix\_spawn is trash. It's actually implemented on top of fork/exec inside of libc (or libSystem in the case of macOS).

So, anything posix\_spawn can do, we can do better. In particular, what we can do better is handle spawning of child processes that are potentially foreign binaries. If you try to spawn a wasm binary, for example, posix spawn does the following:

-   Goes ahead and creates a child process.
-   The child process writes "foo.wasm: foo.wasm: cannot execute binary file" to stderr (yes, it prints the filename twice).
-   The child process then exits with code 126.

This behavior is indistinguishable from the binary being successfully spawned, and then printing to stderr, and exiting with a failure - something that is an extremely common occurrence.

Meanwhile, using the lower level fork/exec will simply return ENOEXEC code from the execve syscall (which is mapped to zig error.InvalidExe).

The posix\_spawn behavior means the zig build runner can't tell the difference between a failure to run a foreign binary, and a binary that did run, but failed in some other fashion. This is unacceptable, because attempting to execve is the proper way to support things like Rosetta.

Therefore, use of posix\_spawn is eliminated from the standard library, in order to facilitate [Foreign Target Execution and Testing](https://ziglang.org/download/0.11.0/release-notes.html#Foreign-Target-Execution-and-Testing).

## [Build System](https://ziglang.org/download/0.11.0/release-notes.html#toc-Build-System) [§](https://ziglang.org/download/0.11.0/release-notes.html#Build-System)

With this release, the Zig Build System is no longer **experimental**. It is the début of [Package Management](https://ziglang.org/download/0.11.0/release-notes.html#Package-Management).

-   Detect and disallow top-level step name clashes.
-   Rename `std.Build.FooStep` to `std.Build.Step.Foo` ([#14947](https://github.com/ziglang/zig/issues/14947)).
-   Fixed `WriteFile.getFileSource` failure on [Windows](https://ziglang.org/download/0.11.0/release-notes.html#Windows) ([#15730](https://github.com/ziglang/zig/issues/15730)).
-   Allow dynamicbase to be disabled by Step.Compile ([#14771](https://github.com/ziglang/zig/issues/14771)).
-   addition of config step, cmake step
-   allow run step to skip foreign binary execution if executor fails
-   enhancements to CheckObjectStep
-   build system: make \`@embedFile\` support module-mapped names the same way as \`@import\` ([#14553](https://github.com/ziglang/zig/issues/14553))
-   build system: Add ability to import dependencies from build.zig
-   build: fix adding rpaths on darwin, improve CheckObjectStep to allow matching LazyPath paths ([#15061](https://github.com/ziglang/zig/issues/15061))
-   move src.type.CType to std lib, use it from std.Build, this will help with populating config.h files. ([motivating change](https://github.com/andrewrk/libmp3lame/commit/a33ffeb1bd0942405af77b6022e1954fad48e09d))
-   std.Build.addAssembly: add missing .kind
-   std.Build.RunStep: fix default caching logic ([#14666](https://github.com/ziglang/zig/issues/14666))
-   std.Build.WriteFileStep: integrate with cache system and additionally support writing files to source files. This means a custom build step in zig's own build.zig is no longer needed for copying zig.h because it is handled by WriteFileStep.
-   std.Build.Step.Compile: fix clearing logic for empty cflags
-   std.Build: Add methods for creating modules from a TranslateC object.
-   avoid repeating objects when linking a static library ([#15708](https://github.com/ziglang/zig/issues/15708))
-   std: add ELF parse'n'dump functionality to std.Build.Step.CheckObject ([#16398](https://github.com/ziglang/zig/issues/16398))
-   std.Build.Step.Compile: getEmittedDocs API enhancements

### [Terminology Changes](https://ziglang.org/download/0.11.0/release-notes.html#toc-Terminology-Changes) [§](https://ziglang.org/download/0.11.0/release-notes.html#Terminology-Changes)

The introduction of [Package Management](https://ziglang.org/download/0.11.0/release-notes.html#Package-Management) required some terminology in the Zig Build System to be changed.

Previously, a directory of Zig source files with one root source file which could be imported by name was known as a **package**. It is now instead called a **module**.

This frees up the term **package** to be used in the context of package management. A package is a directory of files, uniquely identified by a hash of all files, which can export any number of compilation artifacts and modules.

### [Rename Types and Functions](https://ziglang.org/download/0.11.0/release-notes.html#toc-Rename-Types-and-Functions) [§](https://ziglang.org/download/0.11.0/release-notes.html#Rename-Types-and-Functions)

A large amount of types and functions in the build system have been renamed in this release cycle.

-   `std.build` and `std.build.Builder` combined into `std.Build`
-   `LibExeObjStep` to `CompileStep`
-   `InstallRawStep` to `ObjCopyStep`
-   `std.Build.FooStep` to `std.Build.Step.Foo` (e.g. `std.Build.Step.Compile`)
-   `std.Build.FileSource` to `std.Build.LazyPath` ([#16446](https://github.com/ziglang/zig/issues/16446))
-   Any type or function with `LazyPath` in the name has been renamed, generally replacing it with either `File` or `Path`
-   `std.builtin.Mode` to `std.builtin.OptimizeMode`, and all references to "build mode" changed to "optimize mode"
-   `std.Build.Pkg` to `std.Build.Module`

### [Target and Optimization](https://ziglang.org/download/0.11.0/release-notes.html#toc-Target-and-Optimization) [§](https://ziglang.org/download/0.11.0/release-notes.html#Target-and-Optimization)

The target and optimization level for `std.Build.Step.Compile` is no longer set separately using setter methods (previously `setTarget` and `setBuildMode`). Instead, they are provided at the time of step creation, for instance to `std.Build.addExecutable`.

### [Package Management](https://ziglang.org/download/0.11.0/release-notes.html#toc-Package-Management) [§](https://ziglang.org/download/0.11.0/release-notes.html#Package-Management)

Zig 0.11 is the début of the official package manager. The package manager is still in its early stages, but is mature enough to use in many cases. There is no "official" package repository: packages are simply arbitrary directory trees which can be local directories or archives from the Internet.

Package information is declared in a file named `build.zig.zon`. ZON (Zig Object Notation) is a simple data interchange format introduced in this release cycle, which uses Zig's anonymous struct and array initialization syntax to declare objects in a manner similar to other formats such as JSON. The `build.zig.zon` file for a package should look like this:

build.zig.zon

```
.{
    .name = "my_package_name",
    .version = "0.1.0",
    .dependencies = .{
        .dep_name = .{
            .url = "https://link.to/dependency.tar.gz",
            .hash = "12200f41f9804eb9abff259c5d0d84f27caa0a25e0f72451a0243a806c8f94fdc433",
        },
    },
}
```

The information provided is the package name and version, and a list of dependencies, each of which has a name, a URL to an archive, and a hash. The hash is not of the archive itself, but of its contents. In order to find it, it can be omitted from the file, and `zig build` will emit an error containing the expected hash. There will be tooling in future to make this file easier to modify.

So far, tar.gz and tar.xz formats are supported, with more planned, as well as a plan for custom fetch plugins.

This information is provided in a separate file (rather than declared in the `build.zig` script) to speed up the package manager by allowing package fetching to happen without the need to build and run the build script. This also allows tooling to observe dependency graphs without having to execute potentially dangerous code.

Every dependency can expose a collection of **binary artifacts** and **Zig modules** from itself. The `std.Build.addModule` function creates a new Zig module which is publicly exposed from your package; i.e. one which dependant packages can use. (To create a private module, instead use `std.Build.createModule`.) Regarding binary artifacts, any artifact which is **installed** (for instance, via `std.Build.installArtifact`) is exposed to dependant packages.

In the build script, dependencies can be referenced using the `std.Build.dependency` function. This takes the name of a dependency (as given in `build.zig.zon`) and returns a `*std.Build.Dependency`. You can then use the `artifact` and `module` methods on this object to get binary artifacts and Zig modules exposed by the dependency.

If you wish to vendor a dependency rather than fetch it from the Internet, you can use the `std.Build.anonymousDependency` function, which takes as arguments a path to the package's build root, and an `@import` of its build script.

Both `dependency` and `anonymousDependency` take a parameter `args`. This is an anonymous struct containing arbitrary arguments to pass to the build script, which it can access as if they were passed to the script through `-D` flags (through `std.Build.option`. Options from the current package are not implicitly provided to dependencies, and must be explicitly forwarded where required.

It is standard for packages to use `std.Build.standardOptimizeOption` and `std.Build.standardTargetOptions` when they need an optimization level and/or target from their dependant. This allows the dependant to simply forward these values with the names `optimize` and `target`.

build.zig

```
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const my_remote_dep = b.dependency("my_remote_dep", .{
        // These are the arguments to the dependency. It expects a target and optimization level.
        .target = target,
        .optimize = optimize,
    });
    const my_local_dep = b.anonymousDependency("deps/bar/", @import("deps/bar/build.zig"), .{
        // This dependency also expects those options, as well as a boolean indicating whether to
        // build against another library.
        .target = target,
        .optimize = optimize,
        .use_libfoo = false,
    });

    const exe = try b.addExecutable(.{
        .name = "my_binary",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // my_remote_dep exposes a Zig module we wish to depend on.
    exe.addModule(my_remote_dep.module("some_mod"));

    // my_local_dep exposes a static library we wish to link to.
    exe.linkLibrary(my_local_dep.artifact("some_lib"));

    b.addInstallArtifact(exe);
}
```

Explicitly passing the target and optimization level like this allows a build script to build some binaries for different targets or at different optimization levels, which can, for instance, be useful when [interfacing with WebAssembly](https://github.com/andrewrk/groovebasin/blob/271bd7e4014e55a089b8d956228d90b57d8e3fa5/build.zig#L5-L31) .

Every package uses a separate instance of `std.Build`, managed by the build system. It is important to perform operations on the correct instance. This will always be the one passed as a parameter to the `build` function in your build script.

**The package manager is in its early stages, and will likely undergo significant changes before 1.0.** Some planned features include optional dependencies, better support for binary dependencies, the ability to construct a `LazyPath` from an arbitrary file from a dependency, improved tooling, and more. However, the package manager is in a state where it is usable for some projects, particularly simple pure-Zig projects.

### [Install and Run Executables](https://ziglang.org/download/0.11.0/release-notes.html#toc-Install-and-Run-Executables) [§](https://ziglang.org/download/0.11.0/release-notes.html#Install-and-Run-Executables)

The build system supports adding steps to install and run compiled executables. This was previously done using the `install` and `run` methods on `std.Build.Step.Compile`. However, this leads to ambiguities about the owner package in the presence of package management. Therefore, these operations must now be done with these functions:

-   `b.installArtifact(exe)` creates an install step for `exe` and adds it as a dependency of `b`'s top-level install step
-   `b.addRunArtifact(exe)` creates and returns a run artifact for `exe`

Example use case unlocked by this change: [depending on nasm and using it to produce object files](https://github.com/andrewrk/ffmpeg/blob/73ac2d6ce909854436a23a26a9f712861eec2b4e/build.zig#L873)

### [Compiler Protocol](https://ziglang.org/download/0.11.0/release-notes.html#toc-Compiler-Protocol) [§](https://ziglang.org/download/0.11.0/release-notes.html#Compiler-Protocol)

Previously, when the build system invoked the Zig compiler, it simply forwarded stderr to the terminal, so the user could see any errors. This solution limits the possibility of integration between the build system and the compiler. Therefore, the build system now communicates information to the compiler using a binary protocol.

This protocol will likely not be used by end users, but it is enabled using the `--listen` argument to the compiler, and communicates over TCP (with default port 14735) or stdio. The types in `std.zig.Server` are used by the protocol, and a usage example can be found in `std.Build.Step.evalZigProcess`.

The usage of this compiler protocol does mean there can be a small time delay between something like a compilation error occurring and it being reported by `zig build`, however it has the advantage of allowing the build system to receive much more detailed information about the build, allowing for functionality like the [Build Summary](https://ziglang.org/download/0.11.0/release-notes.html#Build-Summary).

### [Build Summary](https://ziglang.org/download/0.11.0/release-notes.html#toc-Build-Summary) [§](https://ziglang.org/download/0.11.0/release-notes.html#Build-Summary)

`zig build` will now print a summary of all build steps after completing. This summary includes information on which steps succeeded, which failed, and why. The `--summary` option controls what information is printed:

Shell

\--summary \[mode\]              Control the printing of the build summary
    all                         Print the build summary in its entirety
    failures                    (Default) Only print failed steps
    none                        Do not print the build summary

Please note that the output from this option is currently [not color-blind friendly](https://github.com/ziglang/zig/issues/14937). This will be improved in the future.

Here is example output from running `zig build test-behavior -fqemu -fwasmtime --summary all` in zig's codebase:

```
Build Summary: 67/80 steps succeeded; 13 skipped; 36653/39320 tests passed; 2667 skipped
test-behavior success
├─ run test behavior-native-Debug cached
│  └─ zig test Debug native cached 21s MaxRSS:52M
├─ run test behavior-native-Debug-libc cached
│  └─ zig test Debug native cached 21s MaxRSS:52M
├─ run test behavior-native-Debug-single cached
│  └─ zig test Debug native cached 20s MaxRSS:52M
├─ run test behavior-native-Debug-libc-cbe 1666 passed 113 skipped 16ms MaxRSS:20M
│  └─ zig build-exe behavior-native-Debug-libc-cbe Debug native success 16s MaxRSS:731M
│     └─ zig test Debug native success 21s MaxRSS:134M
├─ run test behavior-x86_64-linux-none-Debug-selfhosted 1488 passed 291 skipped 29ms MaxRSS:17M
│  └─ zig test Debug x86_64-linux-none success 1s MaxRSS:115M
├─ run test behavior-wasm32-wasi-Debug-selfhosted 1441 passed 342 skipped 639ms MaxRSS:51M
│  └─ zig test Debug wasm32-wasi success 718ms MaxRSS:115M
├─ run test behavior-x86_64-macos-none-Debug-selfhosted skipped
│  └─ zig test Debug x86_64-macos-none success 21s MaxRSS:121M
├─ run test behavior-x86_64-windows-gnu-Debug-selfhosted skipped
│  └─ zig test Debug x86_64-windows-gnu success 2s MaxRSS:114M
├─ run test behavior-wasm32-wasi-Debug 1674 passed 109 skipped 2s MaxRSS:83M
│  └─ zig test Debug wasm32-wasi cached 20ms MaxRSS:51M
├─ run test behavior-wasm32-wasi-Debug-libc 1674 passed 109 skipped 1s MaxRSS:93M
│  └─ zig test Debug wasm32-wasi cached 8ms MaxRSS:51M
├─ run test behavior-x86_64-linux-none-Debug cached
│  └─ zig test Debug x86_64-linux-none cached 24ms MaxRSS:52M
├─ run test behavior-x86_64-linux-gnu-Debug-libc skipped
│  └─ zig test Debug x86_64-linux-gnu success 13s MaxRSS:440M
├─ run test behavior-x86_64-linux-musl-Debug-libc 1698 passed 91 skipped 353ms MaxRSS:17M
│  └─ zig test Debug x86_64-linux-musl success 13s MaxRSS:439M
├─ run test behavior-x86-linux-none-Debug 1693 passed 96 skipped 20ms MaxRSS:20M
│  └─ zig test Debug x86-linux-none success 21s MaxRSS:436M
├─ run test behavior-x86-linux-musl-Debug-libc 1693 passed 96 skipped 26ms MaxRSS:19M
│  └─ zig test Debug x86-linux-musl success 20s MaxRSS:454M
├─ run test behavior-x86-linux-gnu-Debug-libc skipped
│  └─ zig test Debug x86-linux-gnu success 21s MaxRSS:462M
├─ run test behavior-aarch64-linux-none-Debug 1687 passed 102 skipped 2s MaxRSS:31M
│  └─ zig test Debug aarch64-linux-none success 16s MaxRSS:449M
├─ run test behavior-aarch64-linux-musl-Debug-libc 1687 passed 102 skipped 1s MaxRSS:34M
│  └─ zig test Debug aarch64-linux-musl success 17s MaxRSS:457M
├─ run test behavior-aarch64-linux-gnu-Debug-libc skipped
│  └─ zig test Debug aarch64-linux-gnu success 14s MaxRSS:457M
├─ run test behavior-aarch64-windows-gnu-Debug-libc skipped
│  └─ zig test Debug aarch64-windows-gnu success 14s MaxRSS:402M
├─ run test behavior-arm-linux-none-Debug 1686 passed 103 skipped 737ms MaxRSS:29M
│  └─ zig test Debug arm-linux-none cached 12ms MaxRSS:51M
├─ run test behavior-arm-linux-musleabihf-Debug-libc 1686 passed 103 skipped 768ms MaxRSS:31M
│  └─ zig test Debug arm-linux-musleabihf cached 12ms MaxRSS:52M
├─ run test behavior-mips-linux-none-Debug 1686 passed 103 skipped 447ms MaxRSS:36M
│  └─ zig test Debug mips-linux-none success 25s MaxRSS:454M
├─ run test behavior-mips-linux-musl-Debug-libc 1686 passed 103 skipped 417ms MaxRSS:39M
│  └─ zig test Debug mips-linux-musl success 28s MaxRSS:471M
├─ run test behavior-mipsel-linux-none-Debug 1688 passed 101 skipped 406ms MaxRSS:34M
│  └─ zig test Debug mipsel-linux-none success 23s MaxRSS:454M
├─ run test behavior-mipsel-linux-musl-Debug-libc 1688 passed 101 skipped 751ms MaxRSS:37M
│  └─ zig test Debug mipsel-linux-musl cached 14ms MaxRSS:53M
├─ run test behavior-powerpc-linux-none-Debug 1687 passed 102 skipped 849ms MaxRSS:31M
│  └─ zig test Debug powerpc-linux-none cached 13ms MaxRSS:51M
├─ run test behavior-powerpc-linux-musl-Debug-libc 1687 passed 102 skipped 782ms MaxRSS:32M
│  └─ zig test Debug powerpc-linux-musl cached 8ms MaxRSS:51M
├─ run test behavior-powerpc64le-linux-none-Debug 1690 passed 99 skipped 758ms MaxRSS:31M
│  └─ zig test Debug powerpc64le-linux-none cached 12ms MaxRSS:51M
├─ run test behavior-powerpc64le-linux-musl-Debug-libc 1690 passed 99 skipped 542ms MaxRSS:31M
│  └─ zig test Debug powerpc64le-linux-musl cached 9ms MaxRSS:51M
├─ run test behavior-powerpc64le-linux-gnu-Debug-libc skipped
│  └─ zig test Debug powerpc64le-linux-gnu cached 11ms MaxRSS:51M
├─ run test behavior-riscv64-linux-none-Debug 1689 passed 100 skipped 669ms MaxRSS:28M
│  └─ zig test Debug riscv64-linux-none cached 7ms MaxRSS:49M
├─ run test behavior-riscv64-linux-musl-Debug-libc 1689 passed 100 skipped 711ms MaxRSS:30M
│  └─ zig test Debug riscv64-linux-musl cached 7ms MaxRSS:51M
├─ run test behavior-x86_64-macos-none-Debug skipped
│  └─ zig test Debug x86_64-macos-none cached 20s MaxRSS:51M
├─ run test behavior-aarch64-macos-none-Debug skipped
│  └─ zig test Debug aarch64-macos-none cached 7ms MaxRSS:49M
├─ run test behavior-x86-windows-msvc-Debug skipped
│  └─ zig test Debug x86-windows-msvc cached 7ms MaxRSS:50M
├─ run test behavior-x86_64-windows-msvc-Debug skipped
│  └─ zig test Debug x86_64-windows-msvc cached 21s MaxRSS:51M
├─ run test behavior-x86-windows-gnu-Debug-libc skipped
│  └─ zig test Debug x86-windows-gnu cached 7ms MaxRSS:50M
└─ run test behavior-x86_64-windows-gnu-Debug-libc skipped
   └─ zig test Debug x86_64-windows-gnu cached 7ms MaxRSS:52M
```

### [Custom Build Runners](https://ziglang.org/download/0.11.0/release-notes.html#toc-Custom-Build-Runners) [§](https://ziglang.org/download/0.11.0/release-notes.html#Custom-Build-Runners)

Zig build scripts are, by default, run by `build_runner.zig`, a program distributed with Zig. In some cases, such as for custom tooling which wishes to observe the step graph, it may be useful to override the build runner to a different Zig file. This is now possible using the option `--build-runner path/to/runner.zig`.

### [Share the Compiler's Cache System](https://ziglang.org/download/0.11.0/release-notes.html#toc-Share-the-Compilers-Cache-System) [§](https://ziglang.org/download/0.11.0/release-notes.html#Share-the-Compilers-Cache-System)

[Moved the cache system from compiler to std lib and start using it in the build system](https://github.com/ziglang/zig/pull/14571)

### [Steps Run In Parallel](https://ziglang.org/download/0.11.0/release-notes.html#toc-Steps-Run-In-Parallel) [§](https://ziglang.org/download/0.11.0/release-notes.html#Steps-Run-In-Parallel)

The Zig build system is now capable of running multiple build steps in parallel. The build runner analyzes the build step graph, and runs steps in a thread pool, with a default thread count corresponding to the number of CPU cores available for optimal CPU utilization. The number of threads used can be changed with the `-j` option.

This change can allow projects with many build steps to build significantly faster.

### [Embrace LazyPath for Inputs and Outputs](https://ziglang.org/download/0.11.0/release-notes.html#toc-Embrace-LazyPath-for-Inputs-and-Outputs) [§](https://ziglang.org/download/0.11.0/release-notes.html#Embrace-LazyPath-for-Inputs-and-Outputs)

The build system contains a type called `LazyPath` (formerly `FileSource`) which allows depending on a file or directory which originates from one of many sources: an absolute path, a path relative to the build runner's working directory, or a build artifact. The build system now makes extensive use of `LazyPath` anywhere we reference an arbitrary path.

This makes the build system more versatile by making it easier to use generated files in a variety of contexts, since a `LazyPath` may be created to reference the result of any step emitting a file, such as a `std.Build.Step.Compile` or `std.Build.Step.Run`.

The most notable change here is that `Step.Compile` no longer has an `output_dir` field. Rather than depending on the location a binary is emitted to, the `LazyPath` abstraction must be used, for instance through `getEmittedBin` (formerly `getOutputSource`). There are also methods to get the paths corresponding to other compilation artifacts:

-   `Step.Compile.getEmittedBin`
-   `Step.Compile.getEmittedImplib`
-   `Step.Compile.getEmittedH`
-   `Step.Compile.getEmittedPdb`
-   `Step.Compile.getEmittedDocs`
-   `Step.Compile.getEmittedAsm`
-   `Step.Compile.getEmittedLlvmIr`
-   `Step.Compile.getEmittedLlvmBc`

Getting these files will cause the build system to automatically set the appropriate compiler flags to generate them. As such, the old `emit_X` fields have been removed.

`Step.InstallDir` now uses a `LazyPath` for its `source_dir` field, allowing installing a generated directory without a known path. As a general rule, hardcoded paths outside of the installation directory should be avoided where possible.

### [System Resource Awareness](https://ziglang.org/download/0.11.0/release-notes.html#toc-System-Resource-Awareness) [§](https://ziglang.org/download/0.11.0/release-notes.html#System-Resource-Awareness)

You can monitor and limit the peak memory usage for a given step which helps the build system avoid scheduling too many intensive tasks simultaneously, and also helps you detect when a process is starting to exceed reasonable resource usage.

### [Foreign Target Execution and Testing](https://ziglang.org/download/0.11.0/release-notes.html#toc-Foreign-Target-Execution-and-Testing) [§](https://ziglang.org/download/0.11.0/release-notes.html#Foreign-Target-Execution-and-Testing)

The build system has these switches to enable cross-target testing:

```
-fdarling,  -fno-darling     Integration with system-installed Darling to
                               execute macOS programs on Linux hosts
                               (default: no)
  -fqemu,     -fno-qemu        Integration with system-installed QEMU to execute
                               foreign-architecture programs on Linux hosts
                               (default: no)
  --glibc-runtimes [path]      Enhances QEMU integration by providing glibc built
                               for multiple foreign architectures, allowing
                               execution of non-native programs that link with glibc.
  -frosetta,  -fno-rosetta     Rely on Rosetta to execute x86_64 programs on
                               ARM64 macOS hosts. (default: no)
  -fwasmtime, -fno-wasmtime    Integration with system-installed wasmtime to
                               execute WASI binaries. (default: no)
  -fwine,     -fno-wine        Integration with system-installed Wine to execute
                               Windows programs on Linux hosts. (default: no)
```

However, there is even tighter integration with the system, if the system is configured for it. First, zig will try executing a given binary, without guessing whether the system will be able to run it. This takes advantage of binfmt\_misc, for example.

Use `skip_foreign_checks` if you want to prevent a cross-target failure from failing the build.

This even integrates with the [Compiler Protocol](https://ziglang.org/download/0.11.0/release-notes.html#Compiler-Protocol), allowing foreign executables to communicate metadata back to the build runner.

### [Configuration File Generation](https://ziglang.org/download/0.11.0/release-notes.html#toc-Configuration-File-Generation) [§](https://ziglang.org/download/0.11.0/release-notes.html#Configuration-File-Generation)

The build system has API to help you create C configuration header files from common formats, such as automake and CMake.

### [Run Step Enhancements](https://ziglang.org/download/0.11.0/release-notes.html#toc-Run-Step-Enhancements) [§](https://ziglang.org/download/0.11.0/release-notes.html#Run-Step-Enhancements)

It is recommended to generally use Run steps instead of custom steps because it will properly integrate with the [Cache System](https://ziglang.org/download/0.11.0/release-notes.html#Cache-System).

Added prefixed versions of addFileSource and addDirectorySource to Step.Run

Changed Step.Run's stdin to accept LazyPath ([#16358](https://github.com/ziglang/zig/issues/16358)).

### [addTest No Longer Runs It](https://ziglang.org/download/0.11.0/release-notes.html#toc-addTest-No-Longer-Runs-It) [§](https://ziglang.org/download/0.11.0/release-notes.html#addTest-No-Longer-Runs-It)

Before, addTest created and ran a test. Now you need to use b.addRunArtifact to run your test executable.

## [Compiler](https://ziglang.org/download/0.11.0/release-notes.html#toc-Compiler) [§](https://ziglang.org/download/0.11.0/release-notes.html#Compiler)

-   Ensure f128 alignment matches c\_longdouble alignment.
-   [Many compile error messages were improved to be more helpful](https://github.com/ziglang/zig/issues?q=is%3Aclosed+is%3Aissue+label%3A%22error+message%22+milestone%3A0.11.0+).
-   Implement packed unions ([#13340](https://github.com/ziglang/zig/issues/13340)).
-   Support modifiers in inline asm. These are supported using `%[ident:mod]` syntax. This allows requesting, e.g., the "w" (32-bit) vs. "x" (64-bit) views of AArch64 registers.
-   Fix error reporting the wrong line for struct field inits ([#13502](https://github.com/ziglang/zig/issues/13502)).
-   zig-cache: support windows drive + fwd-slash paths ([#13539](https://github.com/ziglang/zig/issues/13539)).
-   Added Valgrind client request support for aarch64 ([#13292](https://github.com/ziglang/zig/issues/13292)).
-   Added detection of duplicate enum tag values.
-   Added a helpful note when using `**` on number types ([#13871](https://github.com/ziglang/zig/issues/13871)).
-   Fixed packed vectors regression from 0.10.0 ([#12812](https://github.com/ziglang/zig/issues/12812)) ([#13925](https://github.com/ziglang/zig/issues/13925)).
-   Fixed lowering a string literal converted to vector ([#13897](https://github.com/ziglang/zig/issues/13897)).
-   Fixed taking the address of a field in a zero-bit struct ([#14000](https://github.com/ziglang/zig/issues/14000)).
-   Handle vectors in packed structs ([#14004](https://github.com/ziglang/zig/issues/14004)).
-   Fixed `@export` with `linksection` option ([#14035](https://github.com/ziglang/zig/issues/14035)).
-   Fixed cache-dir specified on the command line ([#14076](https://github.com/ziglang/zig/issues/14076)).
-   Fixed some spurious "depends on itself" errors ([#14159](https://github.com/ziglang/zig/issues/14159)).
-   Added `-fopt-bisect-limit` for debugging [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend) miscompilations ([#13826](https://github.com/ziglang/zig/issues/13826)).
-   Expose an option for producing 64-bit DWARF info ([#15193](https://github.com/ziglang/zig/issues/15193)).
-   Added missing compile error for coercing a slice to an anyopaque pointer.
-   Added missing compile error for always\_inline call of noinline function ([#15503](https://github.com/ziglang/zig/issues/15503)).
-   Add support for `--build-id` styles ([#15459](https://github.com/ziglang/zig/issues/15459)).
-   Deduplicate uses of the same package across dependencies ([#15755](https://github.com/ziglang/zig/issues/15755)).
-   Added runtime safety for noreturn function returning ([#15235](https://github.com/ziglang/zig/issues/15235)).
-   Added support for multiple global asm blocks per decl ([#16076](https://github.com/ziglang/zig/issues/16076)).
-   Fixed auto-numbered enums with signed tag types ([#16095](https://github.com/ziglang/zig/issues/16095)).
-   Fixed `usize` type inference in `for` range start and end ([#16311](https://github.com/ziglang/zig/issues/16311)).
-   Fixed wrong error location for `@unionInit` when first parameter is not a type ([#16384](https://github.com/ziglang/zig/issues/16384)).
-   Include system headers path when compiling preprocessed assembly files ([#16449](https://github.com/ziglang/zig/issues/16449)).
-   Add framework path detection for NIX\_CFLAGS\_COMPILE.
-   rpaths work differently
-   Implemented `writeToMemory`/`readFromMemory` for pointers, optionals, and packed unions.
-   Fixed `@embedFile("")` not giving a proper error ([#16480](https://github.com/ziglang/zig/issues/16480)).
-   Implemented `@export` for arbitrary values.
-   `@extern` fixes.
-   CLI: detect linker color diagnostics flags
-   CLI: stop special-casing LLVM, LLD, and Clang
-   CLI: Added --verbose-generic-instances to provide visibility on the number of generic function instantiations
-   Added error for bad cast from `*T` to `*[n]T`
-   Added -ferror-tracing and -fno-error-tracing compile options
-   build: add -Dpie option
-   Implemented inline switch capture at comptime ([#15157](https://github.com/ziglang/zig/issues/15157)).
-   correctly detect use of undefined within slices in `@Type` ([#14712](https://github.com/ziglang/zig/issues/14712))
-   Emit compile error for comptime or inline call of function pointer.
-   Improved error message when calling non-member function as method ([#14880](https://github.com/ziglang/zig/issues/14880)).
-   Fixed crash on callconv(.C) generic return type ([#14854](https://github.com/ziglang/zig/issues/14854)).
-   Allow comptime mutation of multiple array elements.
-   Fixed discarding of result location in `for`/`while` loops ([#14684](https://github.com/ziglang/zig/issues/14684)).
-   Added compile-error on primitive value export ([#14778](https://github.com/ziglang/zig/issues/14778))
-   Fixed some builtin functions not returning `void` ([#14779](https://github.com/ziglang/zig/issues/14779))
-   Fixed miscompilation: Error propagates with `return x()` but not with `return try x()` inside recursion ([#15669](https://github.com/ziglang/zig/issues/15669)).
-   fix potential integer underflow in std.zig.Ast.fullCall
-   std.zig.Ast: add helper functions to std.zig.Ast for extracting data out of nodes
-   std.zig.Ast.parse: fix integer overflows during parsing, found while fuzzing zls.
-   std: replace parseAppend with parseWrite in std.zig.string\_literal
-   std.zig.number\_literal; Fix parsing of hexadecimal literals

### [Performance](https://ziglang.org/download/0.11.0/release-notes.html#toc-Performance) [§](https://ziglang.org/download/0.11.0/release-notes.html#Performance)

During this release cycle we worked towards [Incremental Compilation](https://ziglang.org/download/0.11.0/release-notes.html#Incremental-Compilation) and linking, but it is not ready to be enabled yet. We also worked towards [Code Generation](https://ziglang.org/download/0.11.0/release-notes.html#Code-Generation) backends that compete with the [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend) instead of depending on it, but those are also not ready to be enabled by default yet.

Those two efforts will yield drastic results. However, even without those done, this release of the compiler is generally expected to be a little bit faster and use a little bit less memory than 0.10.x releases.

Here are some performance data points, 0.10.1 vs this release:

-   `zig build-exe` on [this Tetris demo](https://github.com/andrewrk/tetris): 14.5% ± 2.7% faster wall clock time, 7.6% ± 0.2% fewer bytes of peak memory usage (x86\_64-linux, baseline).
-   `zig build-exe` on [someone's Advent-of-Code project](https://ziggit.dev/t/can-anyone-provide-compilation-speed-comparisons-for-their-project-0-10-1-to-0-11-x-dev-version/1241/4?u=andrewrk): 6.3% slower wall clock time, 8.7% more bytes of peak memory usage

Note that the compiler is doing more work in 0.11.0 for most builds (including "Hello, World!") due to the [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library) having more advanced [Debugging](https://ziglang.org/download/0.11.0/release-notes.html#Debugging) capabilities, such as [Stack Unwinding](https://ziglang.org/download/0.11.0/release-notes.html#Stack-Unwinding). The long-term plan to address this is [Incremental Compilation](https://ziglang.org/download/0.11.0/release-notes.html#Incremental-Compilation).

### [Bootstrapping](https://ziglang.org/download/0.11.0/release-notes.html#toc-Bootstrapping) [§](https://ziglang.org/download/0.11.0/release-notes.html#Bootstrapping)

During this release cycle, the C++ implementation of Zig was _deleted_. The `-fstage1` flag is no longer a recognized command-line parameter.

Zig is now bootstrapped using a 2.4 MiB [WebAssembly](https://ziglang.org/download/0.11.0/release-notes.html#WebAssembly) file and a C compiler. Please enjoy this blog post which goes into the details: [Goodbye to the C++ Implementation of Zig](https://ziglang.org/news/goodbye-cpp/)

Thanks to improvements to the [C Backend](https://ziglang.org/download/0.11.0/release-notes.html#C-Backend), it is now possible to bootstrap on [Windows](https://ziglang.org/download/0.11.0/release-notes.html#Windows) using MSVC.

Also fixed: bootstrapping the compiler on [ARM](https://ziglang.org/download/0.11.0/release-notes.html#ARM) and on mingw.

The logic for detecting MSVC installations on [Windows](https://ziglang.org/download/0.11.0/release-notes.html#Windows) has been ported from C++ to Zig ([#15657](https://github.com/ziglang/zig/issues/15657)). That was the last C++ source file; the compiler is now 100% Zig code, except for [LLVM](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-16) libraries.

### [Reproducible Builds](https://ziglang.org/download/0.11.0/release-notes.html#toc-Reproducible-Builds) [§](https://ziglang.org/download/0.11.0/release-notes.html#Reproducible-Builds)

According to Zig's [build modes documentation](https://ziglang.org/documentation/0.11.0/#Build-Mode):

-   `-ODebug/` is not required to be reproducible (building the same zig source may output a different, semantically equivalent, binary)
-   `-OReleaseSafe`, `-OReleaseSmall` and `-OReleaseFast` are all required to be reproducible (building the same zig source outputs a deterministic binary)

Terminology:

-   **stage1** is the compiler implementation in `src/stage1/*`, compiled with system toolchain
-   **stage2** is the compiler implementation in `src/*.zig`, compiled with stage1.
-   **stage3** is the compiler implementation in `src/*.zig`, compiled with stage2.
-   **stage4** is the compiler implementation in `src/*.zig`, compiled with stage3.

In theory, stage3 and stage4 should be byte-for-byte identical when compiled in release mode. In practice, this was not true. However, this has been fixed in this release. They now produce byte-for-byte identical executable files.

This property is verified by CI checks for these targets:

-   x86-64 Linux
-   aarch64 macOS

### [C ABI Compatibility](https://ziglang.org/download/0.11.0/release-notes.html#toc-C-ABI-Compatibility) [§](https://ziglang.org/download/0.11.0/release-notes.html#C-ABI-Compatibility)

-   Fixed C ABI compatibility with C `double` types and add a lot of new test coverage for them ([#13376](https://github.com/ziglang/zig/issues/13376)).
-   Fixed x86\_64 sysV ABI of big vectors on avx512 enabled CPUs in the [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend) ([#13629](https://github.com/ziglang/zig/issues/13629)).
-   Fixed some floating-point issues ([#14271](https://github.com/ziglang/zig/issues/14271)).
-   Various fixes ([#16593](https://github.com/ziglang/zig/issues/16593)).

To get a sense of Zig's C ABI compatibility, have a look at the [target coverage](https://github.com/ziglang/zig/blob/0.11.0/test/tests.zig#L460-L517) and [test cases](https://github.com/ziglang/zig/tree/0.11.0/test/c_abi).

### [C Translation](https://ziglang.org/download/0.11.0/release-notes.html#toc-C-Translation) [§](https://ziglang.org/download/0.11.0/release-notes.html#C-Translation)

-   Remainder macro fix ([#13371](https://github.com/ziglang/zig/issues/13371)).
-   Use .identifier tokens in .identifier AST nodes ([#13343](https://github.com/ziglang/zig/issues/13343)).
-   Cast unsuffixed floats to f64.
-   Handle more wrapper types in `isAnyopaque`.
-   Support brace-enclosed string initializers (c++20 9.4.2.1).
-   Fixed codegen when C source has variables named the same as mangling prefixes ([#15420](https://github.com/ziglang/zig/issues/15420)).
-   Deduplicate global declarations ([#15456](https://github.com/ziglang/zig/issues/15456)).
-   Use `@constCast` and `@volatileCast` to remove CV-qualifiers instead of converting a pointer to an int and then back to a pointer.
-   Fixed types on assign expression bool
-   fixed typedeffed pointer subtraction ([#14560](https://github.com/ziglang/zig/issues/14560))
-   translate extern unknown-length arrays using @extern ([#14743](https://github.com/ziglang/zig/issues/14743)).

### [Cache System](https://ziglang.org/download/0.11.0/release-notes.html#toc-Cache-System) [§](https://ziglang.org/download/0.11.0/release-notes.html#Cache-System)

-   Fixed zir caching race condition and deadlock ([#14821](https://github.com/ziglang/zig/issues/14821)).
-   Introduced prefixes to manifests ([#13596](https://github.com/ziglang/zig/issues/13596)).
-   Fixed LockViolation during C compilation paths ([#13591](https://github.com/ziglang/zig/issues/13591)).
-   glibc: avoid poisoning the cache namespace with zig lib dir ([#13619](https://github.com/ziglang/zig/issues/13619)).
-   Fixed another LockViolation case on [Windows](https://ziglang.org/download/0.11.0/release-notes.html#Windows) ([#14162](https://github.com/ziglang/zig/issues/14162)).
-   Fixed multi-process race condition on [macOS](https://ziglang.org/download/0.11.0/release-notes.html#macOS).
-   Retry ZIR cache file creation. There are no dir components, so you would think that ENOENT was unreachable, however we have observed on macOS two processes racing to do openat() with O\_CREAT manifest in ENOENT ([#12138](https://github.com/ziglang/zig/issues/12138)).

### [Code Generation](https://ziglang.org/download/0.11.0/release-notes.html#toc-Code-Generation) [§](https://ziglang.org/download/0.11.0/release-notes.html#Code-Generation)

The Zig compiler has several code backends. The primary one in usage today is the LLVM backend, which emits LLVM IR in order to emit highly optimized binaries. However, this release cycle also saw major improvements to many of our "self-hosted" backends, most notably the [x86 Backend](https://ziglang.org/download/0.11.0/release-notes.html#x86-Backend) which is now passing the vast majority of behavior tests. Improvements to these backends is key to reaching the goal of [Incremental Compilation](https://ziglang.org/download/0.11.0/release-notes.html#Incremental-Compilation).

#### [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#toc-LLVM-Backend) [§](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend)

-   Mangle extern function names for Wasm target ([#13396](https://github.com/ziglang/zig/issues/13396)).
-   Improved emitted debug info ([#12257](https://github.com/ziglang/zig/issues/12257)) ([#12665](https://github.com/ziglang/zig/issues/12665)) ([#13719](https://github.com/ziglang/zig/issues/13719)) ([#14130](https://github.com/ziglang/zig/issues/14130)) ([#15349](https://github.com/ziglang/zig/issues/15349)).
-   Improved load elision ([#12215](https://github.com/ziglang/zig/issues/12215)).
-   Fixed f16, f32, and f64 signaled NaN bitcasts ([#14198](https://github.com/ziglang/zig/issues/14198)).
-   Implement Stdcall calling convention.
-   Optimize access of array member in a structure.
-   Stop generating FPU code if there is no FPU ([#14465](https://github.com/ziglang/zig/issues/14465)).
-   Began work on eliminating dependency on LLVM's IRBuilder API ([#13265](https://github.com/ziglang/zig/issues/13265)).
-   Support read-write output constraints in assembly ([#15227](https://github.com/ziglang/zig/issues/15227)).

#### [C Backend](https://ziglang.org/download/0.11.0/release-notes.html#toc-C-Backend) [§](https://ziglang.org/download/0.11.0/release-notes.html#C-Backend)

Now passing **1652/1679 (98%)** of the behavior tests, compared to the [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend).

The generated C code is now MSVC-compatible.

This backend is now used for [Bootstrapping](https://ziglang.org/download/0.11.0/release-notes.html#Bootstrapping) and is no longer considered **experimental**.

It has seen some optimizations to reduce the size of the outputted C code, such as reusing locals where possible. However, there are still many more optimizations that could be done to further reduce the size of the outputted C code.

#### [x86 Backend](https://ziglang.org/download/0.11.0/release-notes.html#toc-x86-Backend) [§](https://ziglang.org/download/0.11.0/release-notes.html#x86-Backend)

Although the x86 backend is still considered **experimental**, it is now passing **1474/1679 (88%)** of the behavior tests, compared to the [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend).

-   add [DWARF](https://ziglang.org/download/0.11.0/release-notes.html#DWARF) encoding for SIMD registers
-   introduce table-drive instruction encoder based on [`zig-dis-x86_64`](https://github.com/kubkon/zig-dis-x86_64)
-   add basic Thread-Local Storage support when targeting [MachO](https://ziglang.org/download/0.11.0/release-notes.html#MachO)

#### [WebAssembly Backend](https://ziglang.org/download/0.11.0/release-notes.html#toc-WebAssembly-Backend) [§](https://ziglang.org/download/0.11.0/release-notes.html#WebAssembly-Backend)

This release did not see many user-facing features added to the WebAssembly backend. A few notable features are:

-   atomics
-   packed structs
-   initial SIMD support
-   Several safety-checks

Besides those language features, the WebAssembly backend now also uses the regular `start.zig` logic as well as the standard test-runner. This is a big step as the default test-runner logic uses a client-server architecture, requiring a lot of the language to be implemented for it to work. This will also help us further with completing the WebAssembly backend as the test-runner provides us with more details about which test failed.

Lastly, a lot of bugs and miscompilations were fixed, passing more behavior tests. Although the WebAssembly backend is still considered **experimental**, it is now passing **1428/1657 (86%)** of the behavior tests, compared to the [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend).

#### [SPIR-V Backend](https://ziglang.org/download/0.11.0/release-notes.html#toc-SPIR-V-Backend) [§](https://ziglang.org/download/0.11.0/release-notes.html#SPIR-V-Backend)

[Robin "Snektron" Voetter](https://github.com/Snektron/) writes:

This release cycle saw significant improvement of the self-hosted SPIR-V backend. SPIR-V is a bytecode representation for shaders and kernels that run on GPUs. For now, the SPIR-V backend of Zig is focused on generating code for OpenCL kernels, though Vulkan compatible shaders may see support in the future too.

The main contributions in this release cycle feature a crude assembler for SPIR-V inline assembly, which is useful for supporting fringe types and operations, and other features from SPIR-V that do not expose itself well from within Zig.

The backend also saw improvements to codegen, and is now able to compile and execute about 37% of the compiler behavior test suite on select OpenCL implementations. Unfortunately this does not yet include Rusticl, which is currently missing a few features that the Zig SPIR-V backend requires.

Currently, executing SPIR-V tests requires third-party implementations of the test runner and test executor. In the future, these will be integrated further with Zig.

#### [aarch64 Backend](https://ziglang.org/download/0.11.0/release-notes.html#toc-aarch64-Backend) [§](https://ziglang.org/download/0.11.0/release-notes.html#aarch64-Backend)

During this release cycle, some progress was made on this **experimental** backend, but there is nothing user-facing to report. It has not yet graduated beyond the **simplified start code** routines, so we have no behavior test percentage to report.

### [Error Return Tracing](https://ziglang.org/download/0.11.0/release-notes.html#toc-Error-Return-Tracing) [§](https://ziglang.org/download/0.11.0/release-notes.html#Error-Return-Tracing)

This release cycle sees minor improvements to error return traces. These traces are created by Zig for binaries built in safe release modes, and report the source of an error which was not correctly handled where a simple stack trace would be less useful.

A bug involving [incorrect frames from loop bodies appearing in traces](https://github.com/ziglang/zig/issues/13618) has been fixed. The following test case now gives a correct error return trace:

loop\_continue\_error\_trace.zig

```
fn foo() !void {
    return error.UhOh; // this should not appear in the trace
}

pub fn main() !void {
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        foo() catch continue;
    }
    return error.UnrelatedError;
}
```

Shell

$ zig build-exe loop\_continue\_error\_trace.zig
$ ./loop\_continue\_error\_trace
error: UnrelatedError
/home/andy/tmp/docgen\_tmp/loop\_continue\_error\_trace.zig:10:5: 0x21e375 in main (loop\_continue\_error\_trace)
    return error.UnrelatedError;
    ^

### [Safety Checks](https://ziglang.org/download/0.11.0/release-notes.html#toc-Safety-Checks) [§](https://ziglang.org/download/0.11.0/release-notes.html#Safety-Checks)

-   Safety panic improvements and some bug fixes ([#13693](https://github.com/ziglang/zig/issues/13693)).
-   compiler: start moving safety-checks into backends for [Performance](https://ziglang.org/download/0.11.0/release-notes.html#Performance) ([#16190](https://github.com/ziglang/zig/issues/16190)).

### [Struct Field Order](https://ziglang.org/download/0.11.0/release-notes.html#toc-Struct-Field-Order) [§](https://ziglang.org/download/0.11.0/release-notes.html#Struct-Field-Order)

Automatically optimize order of struct fields ([#14336](https://github.com/ziglang/zig/issues/14336))

### [Incremental Compilation](https://ziglang.org/download/0.11.0/release-notes.html#toc-Incremental-Compilation) [§](https://ziglang.org/download/0.11.0/release-notes.html#Incremental-Compilation)

While still a highly WIP feature, this release cycle saw many improvements paving the way to incremental compilation capabilities in the compiler. One of the most significant was the [InternPool changeset](https://github.com/ziglang/zig/pull/15569). This change is mostly invisible to Zig users, but brings many benefits to the compiler, amongst them being that we are now much closer to incremental compilation. This is because this changeset brings new in-memory representations to many internal compiler datastructures (most notably types and values) which are trivially serializable to disk, a requirement for incremental compilation.

This release additionally saw big improvements to Zig's native code generation and linkers, as well as beginning to move to emitting LLVM bitcode manually. The former will unlock extremely fast incremental compilations, and the latter is necessary for incremental compilation to work on the LLVM backend.

Incremental compilation will be a key focus of the 0.12.0 release cycle. The path to incremental compilation will roughly consist of the following steps:

-   Improve the representation of some internal compiler datastructures (comptime-mutable memory and declarations)
-   Implement improved dependency graph analysis, to avoid incorrect compile errors whilst keeping incremental updates as small as possible
-   Get the self-hosted [Code Generation](https://ziglang.org/download/0.11.0/release-notes.html#Code-Generation) backends and linkers into a usable state (the x86 backend is already passing most behavior tests!)
-   Implement serialization to cache for key compiler datastructures
-   Enable and fuzz-test incremental compilation to catch bugs

While no guarantees can be made, it is possible that a basic form of incremental compilation will be usable in 0.12.0.

### [New Module CLI](https://ziglang.org/download/0.11.0/release-notes.html#toc-New-Module-CLI) [§](https://ziglang.org/download/0.11.0/release-notes.html#New-Module-CLI)

The method for specifying modules on the CLI has been changed to support recursive module dependencies and shared dependencies. Previously, the `--pkg-begin` and `--pkg-end` options were used to define modules in a "hierarchical" manner, nesting dependencies inside their parent. This system was not compatible with shared dependencies or recursive dependencies.

Modules are now specified using the `--mod` and `--deps` options, which have the following syntax:

Shell

\--mod \[name\]:\[deps\]:\[src\] Make a module available for dependency under the given name
      deps: \[dep\],\[dep\],...
      dep:  \[\[import=\]name\]
  --deps \[dep\],\[dep\],...    Set dependency names for the root package
      dep:  \[\[import=\]name\]

`--mod` defines a module with a given name, dependency list, and root source file. `--deps` specifies the list of dependencies of the main module. These options are not order-dependant. This defines modules in a "flat" manner, and specifies dependencies indirectly, allowing dependency loops and shared dependencies. The name of a dependency can optionally be overridden from the "default" name in the dependency string.

For instance, the following `zig build-exe` invocation defines two modules, `foo` and `bar`. `foo` depends on `bar` under the name `bar1`, `bar` depends on itself (under the default name `bar`), and the main module depends on both `foo` and `bar`.

Shell

$ zig build-exe main.zig --mod foo:bar1=bar:foo.zig --mod bar:bar:bar.zig --deps foo,bar

The [Build System](https://ziglang.org/download/0.11.0/release-notes.html#Build-System) supports creating module dependency loops by manually modifying the `dependencies` of a `std.Build.Module`. Note that this API (and the CLI invocation) is likely to undergo further changes in the future.

## [Linker](https://ziglang.org/download/0.11.0/release-notes.html#toc-Linker) [§](https://ziglang.org/download/0.11.0/release-notes.html#Linker)

Depending on the target, Zig will use [LLD](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-16), or its own linker implementation. In order to override the default, pass `-fLLD` or `-fno-LLD`.

-   decouple `Decl` from `Atom` - now every linker is free to track `Decl` however they like; the (in)famous change that removed the dreaded `link.File.allocateDeclIndexes` function
-   handle `-u` flag
-   Elf: switch link order of libcompiler\_rt and libc ([#13971](https://github.com/ziglang/zig/issues/13971)).

### [MachO](https://ziglang.org/download/0.11.0/release-notes.html#toc-MachO) [§](https://ziglang.org/download/0.11.0/release-notes.html#MachO)

-   fix bug where we do not zero-out file if there are only zerofill sections
-   parse weak symbols in TBD files - emitting weak import definitions is still unimplemented however
-   improve parsing of DWARF debug info including `DW_FORM_block*` and `DW_FORM_string` forms
-   when linking incrementally, creating `dSYM` bundle directly in the emit directory rather than local cache
-   ensure `__DWARF` segment comes before `__LINKEDIT` in `dSYM` bundle which greatly simplifies incremental linking of debug info on macOS
-   implement parallel MD5-like hash for UUID calculation - by pulling out the parallel hashing setup from `CodeSignature.zig`, we can now reuse it in different places across the MachO linker. The parallel hasher is generic over an actual hasher such as Sha256 or MD5.
-   fix source of nondeterminism in code signature - identifier string in code signature should be just basename
-   add missing clang options: `-install_name` and `-undefined`
-   handle `-undefined error` flag
-   add strict MachO validation test with test matrix pulled from Apple's `libstuff` library - ensures we catch regression which may invalidate the binary when inspected by Apple tooling such as `codesign`, etc.
-   improve `dyld` opcodes emitters - we now generate vastly compressed opcodes for the loader reducing overall binary size and improve loading times
-   parse, synthesise and emit unwind information records - includes emitting `__TEXT,__unwind_info` and `__TEXT, __eh_frame` sections making Zig linked binaries compatible with `libunwind`
-   downgrade alignment requirements for symtab in object files, and especially object files in static archives - instead of requiring 8-byte alignment, we operate directly on unaligned data now
-   move macOS kernel inode cache invalidation to the MachO linker, and clean up opening/closing of file descriptors ensuring we don't leak any file descriptors by accident
-   relax assumption about dead strip atoms uniqueness - in case the compiler output an object file that is not `MH_SUBSECTIONS_VIA_SYMBOLS` compatible, entry point may overlap with a section atom which is perfectly fine, so don't panic in that case
-   use `TOOL=0x5` to mean Zig as the build tool in `LC_BUILD_VERSION`
-   save all defined globals in the export trie for executable - this matches the behavior of other linkers
-   when finding by address, note the end of section symbols too - previously, if we were looking for the very last symbol by address in some section, and the next symbol happened to also have the same address value but would reside in a different section, we would keep going finding the wrong symbol in the wrong section. This mechanism turns out vital for correct linking of Go binaries where the runtime looks for specially crafted synthetic symbols which mark the beginning and end of each section. In this case, we had an unfortunate clash between the end of PC marked machine code section (`_runtime.etext`) and beginning of read-only data (`_runtime.rodata`).
-   look for entry point in static archives and dynamic libraries
-   handle weird case of entry point being a stub entry (`__TEXT,__stubs` entry)
-   implement emitting TLS variables in incremental codepath
-   fix memory bugs in TAPI/yaml parser
-   fix parsing of `__TEXT,__eh_frame` sections emitted by Nix C++ compiler
-   fix parsing of TBDv3 input files
-   implement working hot-code swapping PoC

### [COFF](https://ziglang.org/download/0.11.0/release-notes.html#toc-COFF) [§](https://ziglang.org/download/0.11.0/release-notes.html#COFF)

-   handle incremental linking of `aarch64-windows` target
-   handle linking and loading against multiple DLLs
-   implement working hot-code swapping PoC

### [ELF](https://ziglang.org/download/0.11.0/release-notes.html#toc-ELF) [§](https://ziglang.org/download/0.11.0/release-notes.html#ELF)

-   rename `TextBlock` into `Atom`
-   move logic for allocating a GOT entry into a helper
-   fully zero-out ELF symbol record when appending to freelist - avoids uninitialized data in the output ELF file
-   do not reserve a GOT slot for atoms that won't require them

### [WASM Modules](https://ziglang.org/download/0.11.0/release-notes.html#toc-WASM-Modules) [§](https://ziglang.org/download/0.11.0/release-notes.html#WASM-Modules)

[Luuk de Gram](https://github.com/Luukdegram) writes:

During this release, a lot of work has gone into the in-house WebAssembly linker. The biggest feature it gained was the support of the `shared memory` feature. This allows multiple WebAssembly modules to access the same memory. This feature opens support for multi-threading in WebAssembly. This also required us to implement support for Thread-Local Storage. The linker is now fully capable of linking with [WASI-libc](https://ziglang.org/download/0.11.0/release-notes.html#WASI-libc), also. Users can now make use of the in-house linker by supplying the `-fno-LLD` flag to your `zig build-{lib/exe}` CLI invocation.

We are closer than ever to replace LLVM's linker wasm-ld with our in-house linker. The last feature to implement for statically built WebAssembly modules is garbage collection. This ensures unreferenced symbols get removed from the final binary keeping the binaries small in disk size. Once implemented, we can make the in-house linker the default linker when building a WebAssembly module and gather feedback and fix any bugs that haven't been found yet. We can then start working on other features such as dynamic-linking support and any future proposals.

Additionally:

-   emit build\_id section ([#14820](https://github.com/ziglang/zig/issues/14820))

### [DWARF](https://ziglang.org/download/0.11.0/release-notes.html#toc-DWARF) [§](https://ziglang.org/download/0.11.0/release-notes.html#DWARF)

-   add support for multiple source files in self-hosted backends - this means we emit correct debug info for multifile Zig programs such as `zig test behavior.zig` and is now debuggable in a debugger
-   decouple `Dwarf.Atom` from linkers' `Atom`s

### [Move Library Path Resolution to the Frontend](https://ziglang.org/download/0.11.0/release-notes.html#toc-Move-Library-Path-Resolution-to-the-Frontend) [§](https://ziglang.org/download/0.11.0/release-notes.html#Move-Library-Path-Resolution-to-the-Frontend)

Library path resolution is now handled by the Zig frontend rather than the linker (LLD). Some compiler flags are introduced to control this behavior.

Shell

\-search\_paths\_first            For each library search path, check for dynamic
                               lib then static lib before proceeding to next path.
-search\_paths\_first\_static     For each library search path, check for static
                               lib then dynamic lib before proceeding to next path.
-search\_dylibs\_first           Search for dynamic libs in all library search
                               paths, then static libs.
-search\_static\_first           Search for static libs in all library search
                               paths, then dynamic libs.
-search\_dylibs\_only            Only search for dynamic libs.
-search\_static\_only            Only search for static libs.

These arguments are stateful: they affect all subsequent libraries linked by name, such as by the flags `-l`, `-weak-l`, and `-needed-l`.

Error reporting for failure to find a system library is improved:

Shell

$ zig build-exe test.zig -lfoo -L. -L/a -target x86\_64-macos --sysroot /home/andy/local
error: unable to find Dynamic system library 'foo' using strategy 'paths\_first'. searched paths:
  ./libfoo.tbd
  ./libfoo.dylib
  ./libfoo.so
  ./libfoo.a
  /home/andy/local/a/libfoo.tbd
  /home/andy/local/a/libfoo.dylib
  /home/andy/local/a/libfoo.so
  /home/andy/local/a/libfoo.a
  /a/libfoo.tbd
  /a/libfoo.dylib
  /a/libfoo.so
  /a/libfoo.a

Previously, the [Build System](https://ziglang.org/download/0.11.0/release-notes.html#Build-System) exposed `-search_paths_first` and `-search_dylibs_first` from the `zig build` command, which had the ability to affect all libraries. Now, the build script instead explicitly chooses the search strategy and preferred link mode for each library independently.

## [Bug Fixes](https://ziglang.org/download/0.11.0/release-notes.html#toc-Bug-Fixes) [§](https://ziglang.org/download/0.11.0/release-notes.html#Bug-Fixes)

[Full list of the 711 bug reports closed during this release cycle](https://github.com/ziglang/zig/issues?q=is%3Aclosed+is%3Aissue+label%3Abug+milestone%3A0.11.0).

Many bugs were both introduced and resolved within this release cycle. Most bug fixes are omitted from these release notes for the sake of brevity.

### [This Release Contains Bugs](https://ziglang.org/download/0.11.0/release-notes.html#toc-This-Release-Contains-Bugs) [§](https://ziglang.org/download/0.11.0/release-notes.html#This-Release-Contains-Bugs)

Zig has [known bugs](https://github.com/ziglang/zig/issues?q=is%3Aopen+is%3Aissue+label%3Abug) and even some [miscompilations](https://github.com/ziglang/zig/issues?q=is%3Aopen+is%3Aissue+label%3Amiscompilation).

Zig is immature. Even with Zig 0.11.0, working on a non-trivial project using Zig will likely require participating in the development process.

When Zig reaches 1.0.0, [Tier 1 Support](https://ziglang.org/download/0.11.0/release-notes.html#Tier-1-Support) will gain a bug policy as an additional requirement.

A [0.11.1 release](https://github.com/ziglang/zig/milestone/21) is planned. Please test your projects against 0.11.0 and report any problems on the issue tracker so that we can deliver a stable 0.11.1 release.

### [Bug Stability Program](https://ziglang.org/download/0.11.0/release-notes.html#toc-Bug-Stability-Program) [§](https://ziglang.org/download/0.11.0/release-notes.html#Bug-Stability-Program)

To be announced next week...

## [Toolchain](https://ziglang.org/download/0.11.0/release-notes.html#toc-Toolchain) [§](https://ziglang.org/download/0.11.0/release-notes.html#Toolchain)

-   Ability to specify a custom test runner via a new `--test-runner` CLI option, or the `std.Build.test_runner_path` field ([#6621](https://github.com/ziglang/zig/issues/6621)).

### [LLVM 16](https://ziglang.org/download/0.11.0/release-notes.html#toc-LLVM-16) [§](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-16)

This release of Zig upgrades to [LLVM 16.0.6](http://releases.llvm.org/16.0.0/docs/ReleaseNotes.html).

During this release cycle, it has become a goal of the Zig project to eventually [eliminate all dependencies on LLVM, LLD, and Clang libraries](https://github.com/ziglang/zig/issues/16270). There will still be an [LLVM Backend](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-Backend), however it will [directly output bitcode files rather than using LLVM C++ APIs](https://github.com/ziglang/zig/issues/13265).

### [musl 1.2.4](https://ziglang.org/download/0.11.0/release-notes.html#toc-musl-124) [§](https://ziglang.org/download/0.11.0/release-notes.html#musl-124)

Zig ships with the source code to [musl](http://musl.libc.org/). When the musl C ABI is selected, Zig builds static musl from source for the selected target. Zig also supports targeting dynamically linked musl which is useful for Linux distributions that use it as their system libc, such as [Alpine Linux](https://www.alpinelinux.org/).

This release upgrades from v1.2.3 to v1.2.4.

### [glibc 2.34](https://ziglang.org/download/0.11.0/release-notes.html#toc-glibc-234) [§](https://ziglang.org/download/0.11.0/release-notes.html#glibc-234)

Unfortunately, glibc is still stuck on 2.34. Users will need to wait until 0.12.0 for a glibc upgrade.

The only change:

-   Allow linking against external libcrypt ([#5990](https://github.com/ziglang/zig/issues/5990)).

### [mingw-w64 10.0.0](https://ziglang.org/download/0.11.0/release-notes.html#toc-mingw-w64-1000) [§](https://ziglang.org/download/0.11.0/release-notes.html#mingw-w64-1000)

Unfortunately, mingw-w64 is still stuck on 10.0.0. Users will need to wait until 0.12.0 for a mingw-w64 upgrade.

The only change:

-   Added missing vscprintf.c file ([#13733](https://github.com/ziglang/zig/issues/13733)).

### [WASI-libc](https://ziglang.org/download/0.11.0/release-notes.html#toc-WASI-libc) [§](https://ziglang.org/download/0.11.0/release-notes.html#WASI-libc)

Zig's wasi-libc is updated to 3189cd1ceec8771e8f27faab58ad05d4d6c369ef ([#15817](https://github.com/ziglang/zig/issues/15817))

### [compiler-rt](https://ziglang.org/download/0.11.0/release-notes.html#toc-compiler-rt) [§](https://ziglang.org/download/0.11.0/release-notes.html#compiler-rt)

compiler-rt is the library that provides, for example, 64-bit integer multiplication for 32-bit architectures which do not have a machine code instruction for it. The [GNU](https://gcc.gnu.org/) toolchain calls this library **libgcc**.

Unlike most compilers, which depend on a binary build of compiler-rt being installed alongside the compiler, Zig builds compiler-rt from source, lazily, for the target platform. It avoids repeating this work unnecessarily via the [Cache System](https://ziglang.org/download/0.11.0/release-notes.html#Cache-System).

This release saw some improvements to Zig's compiler-rt implementation:

-   Fixed duplicate symbol error on aarch64 [Windows](https://ziglang.org/download/0.11.0/release-notes.html#Windows) ([#13430](https://github.com/ziglang/zig/issues/13430)).
-   Removed some no-longer-needed workarounds thanks to [Compiler](https://ziglang.org/download/0.11.0/release-notes.html#Compiler) bugs being fixed ([#13553](https://github.com/ziglang/zig/issues/13553)).
-   Added aarch64 outline atomics ([#11828](https://github.com/ziglang/zig/issues/11828)).
-   Added `__udivei4` and `__umodei4` for dividing and formatting arbitrary-large unsigned integers ([#14023](https://github.com/ziglang/zig/issues/14023)).
-   Added `__ashlsi3`, `__ashrsi3`, `__lshrsi3` for libgcc symbol compatibility.
-   Added `__divmodti4` for libgcc symbol compatibility ([#14608](https://github.com/ziglang/zig/issues/14608)).
-   Added `__powihf2`, `__powisf2`, `__powidf2`, `__powitf2`, `__powixf2`.
-   Fixed `f16` ABI on [macOS](https://ziglang.org/download/0.11.0/release-notes.html#macOS) with [LLVM 16](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-16).
-   Added `__fixkfti`, `__fixunskfti`, `__floattikf`, `__negkf2`, `__mulkc3`, `__divkc3`, and `__powikf2` for [PowerPC](https://ziglang.org/download/0.11.0/release-notes.html#PowerPC) ([#16057](https://github.com/ziglang/zig/issues/16057)).
-   Optimized udivmod ([#15265](https://github.com/ziglang/zig/issues/15265)).

#### [Bundling Into Object Files](https://ziglang.org/download/0.11.0/release-notes.html#toc-Bundling-Into-Object-Files) [§](https://ziglang.org/download/0.11.0/release-notes.html#Bundling-Into-Object-Files)

When the following is specified

Shell

$ zig build-obj -fcompiler-rt example.zig

the resulting relocatable object file will have the compiler-rt unconditionally embedded inside:

Shell

$ nm example.o
...
0000000012345678 W \_\_truncsfhf2
...

### [zig cc](https://ziglang.org/download/0.11.0/release-notes.html#toc-zig-cc) [§](https://ziglang.org/download/0.11.0/release-notes.html#zig-cc)

`zig cc` is Zig's drop-in C compiler tool. Enhancements in this release:

-   Support `-z` stack-size arguments.
-   Add missing clang opts: `-install_name` and `-undefined`.
-   Add support for `-undefined error` ([#14046](https://github.com/ziglang/zig/issues/14046)).
-   Avoid passing redzone args when targeting powerpc.
-   Support `-x` to override the language.
-   Support `-r` ([#11683](https://github.com/ziglang/zig/issues/11683)).
-   Properly pass soft-float option for MIPS assembly files.
-   Fixed generating [COFF](https://ziglang.org/download/0.11.0/release-notes.html#COFF) debug info on GNU ABIs.
-   Support reading from stdin ([#14462](https://github.com/ziglang/zig/issues/14462)).
-   Implement `-###` (dry run) ([#7170](https://github.com/ziglang/zig/issues/7170)).
-   Support `-l :path/to/lib.so` ([#15743](https://github.com/ziglang/zig/issues/15743)).
-   Support `-version-script`.
-   Support more [Linker](https://ziglang.org/download/0.11.0/release-notes.html#Linker) arguments:
    -   `--version` ([#15549](https://github.com/ziglang/zig/issues/15549))
    -   `--dynamicbase`
    -   `-wrap` ([#15097](https://github.com/ziglang/zig/issues/15097))
    -   `-stack` and `--stack`
    -   `--sort-common` (ignore)
    -   `--sort-section`
    -   `--no-undefined` and `-z undefs` ([#11912](https://github.com/ziglang/zig/issues/11912))
    -   `-z<arg>` (equivalent to `-z <arg>`) ([#14680](https://github.com/ziglang/zig/issues/14680))

This feature is covered by our [Bug Stability Program](https://ziglang.org/download/0.11.0/release-notes.html#Bug-Stability-Program).

#### [Fail Hard on Unsupported Linker Flags](https://ziglang.org/download/0.11.0/release-notes.html#toc-Fail-Hard-on-Unsupported-Linker-Flags) [§](https://ziglang.org/download/0.11.0/release-notes.html#Fail-Hard-on-Unsupported-Linker-Flags)

Before, `zig cc`, when confronted with a linker argument it did not understand, would skip the flag and emit a warning.

This caused headaches for people that build third-party software. Zig would seemingly build and link the final executable, only to have it segfault when executed.

If there are linker warnings when compiling software, the first thing we have to do is add support for ones linker is complaining, and only then go file issues. If Zig "successfully" (i.e. status code = 0) compiles a binary, there is instead a tendency to blame "Zig doing something weird". Adding the unsupported arguments is straightforward; see [#11679](https://github.com/ziglang/zig/issues/11679), [#11875](https://github.com/ziglang/zig/issues/11875), [#11874](https://github.com/ziglang/zig/issues/11874) for examples.

With Zig 0.11.0, unrecognized linker arguments are hard errors.

### [zig c++](https://ziglang.org/download/0.11.0/release-notes.html#toc-zig-c) [§](https://ziglang.org/download/0.11.0/release-notes.html#zig-c)

`zig c++` is equivalent to [zig cc](https://ziglang.org/download/0.11.0/release-notes.html#zig-cc) with an added `-lc++` parameter, but I made a separate heading here because I realized that some people are not aware that Zig supports compiling C++ code and providing libc++ too!

hello.cpp

```
#include <iostream>
int main() {
    std::cout << "Hello World!" << std::endl;
    return 0;
}
```

Shell

$ zig c++ -o hello hello.cpp
$ ./hello
Hello World!

Cross-compiling too, of course:

Shell

$ zig c++ -o hello hello.cpp -target riscv64-linux
$ qemu-riscv64 ./hello
Hello World!

One thing that trips people up when they use this feature is that the **C++ ABI is not stable across compilers**, so always remember the rule: You must use the same C++ compiler to compile _all_ your objects and static libraries. This is an unfortunate limitation of C++ which Zig can never fix.

### [zig fmt](https://ziglang.org/download/0.11.0/release-notes.html#toc-zig-fmt) [§](https://ziglang.org/download/0.11.0/release-notes.html#zig-fmt)

-   Fixed extra whitespace with multiline strings ([#13937](https://github.com/ziglang/zig/issues/13937)).
-   Improved handling of comptime tuple fields.
-   Omit extra whitespace after last comment before EOF.
-   Avoid canonicalizing enum fields named `@"_"` to `_` ([#15617](https://github.com/ziglang/zig/issues/15617)).
-   additionally format .zon files
-   make \`--exclude\` work on files ([#16178](https://github.com/ziglang/zig/issues/16178))
-   fix file ending in a multi line comment
-   Correctly handle carriage return characters according to the spec ([#12661](https://github.com/ziglang/zig/issues/12661)).

#### [Canonicalization of Identifiers](https://ziglang.org/download/0.11.0/release-notes.html#toc-Canonicalization-of-Identifiers) [§](https://ziglang.org/download/0.11.0/release-notes.html#Canonicalization-of-Identifiers)

This adds new behavior to `zig fmt` which normalizes (renders a canonical form of) quoted identifiers like `@"hi_mom"` to some extent. This can make codebases more consistent and searchable.

To prevent making the details of Unicode and UTF-8 dependencies of the Zig language, only bytes in the ASCII range are interpreted and normalized. Besides avoiding complexity, this means invalid UTF-8 strings cannot break `zig fmt`.

Both the tokenizer and the new formatting logic may overlook certain errors in quoted identifiers, such as nonsense escape sequences like `\m`. For now, those are ignored and we defer to existing later analysis to catch.

This change is not expected to break any existing code.

## Behavior

Below, "verbatim" means "as it was in the original source"; in other words, not altered.

-   If an identifier is bare (not quoted) in the original source, no change is made. Everything below only applies to quoted identifiers.
-   Quoted identifiers are processed byte-wise, not interpreted as a UTF-8 sequence.
-   `\x` and `\u` escapes are processed.
    -   If the escape sequence itself is invalid, the sequence is rendered verbatim.
    -   If the un-escaped codepoint is not ASCII, the sequence is rendered verbatim.
    -   Otherwise, the character is rendered with [`formatEscapes`](https://github.com/ziglang/zig/blob/cbdd21c/lib/std/zig/fmt.zig#L50-L87) rules: either literally or `\x`\-escaped as needed.
-   If the resulting identifier still contains escapes, it remains quoted.
-   If the resulting identifier is not a valid bare symbol (`[A-Za-z_][A-Za-z0-9_]*`), it remains quoted.
-   If the resulting identifier is a keyword, it remains quoted.
-   If the resulting identifier is a primitive value/type (`i33`, `void`, `type`, `null`, `_`, etc.), it is rendered unquoted if the syntactical context allows it (field access, container member), otherwise it remains quoted.
-   Otherwise, it is unquoted. Celebrate in the manner of your choosing.

([#166](https://github.com/ziglang/zig/issues/166))

### [zig objcopy](https://ziglang.org/download/0.11.0/release-notes.html#toc-zig-objcopy) [§](https://ziglang.org/download/0.11.0/release-notes.html#zig-objcopy)

This is a new subcommand added in this release. Functionality is limited, but we can add features as needed. This subcommand has no dependency on [LLVM](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-16).

## [Roadmap](https://ziglang.org/download/0.11.0/release-notes.html#toc-Roadmap) [§](https://ziglang.org/download/0.11.0/release-notes.html#Roadmap)

The major themes of the 0.12.0 release cycle will be **language changes**, **compilation speed**, and **package management**.

Some upcoming milestones we will be working towards in the 0.12.0 release cycle:

-   Many [Accepted Proposals](https://ziglang.org/download/0.11.0/release-notes.html#Accepted-Proposals) implemented. Expect breakage!
-   Behavior tests passing for the [x86 Backend](https://ziglang.org/download/0.11.0/release-notes.html#x86-Backend), [aarch64 Backend](https://ziglang.org/download/0.11.0/release-notes.html#aarch64-Backend), and [WebAssembly Backend](https://ziglang.org/download/0.11.0/release-notes.html#WebAssembly-Backend). Unleashes our full compilation speed when targeting the respective architecture.
-   Fuzz test [Incremental Compilation](https://ziglang.org/download/0.11.0/release-notes.html#Incremental-Compilation) so that we can enable it and gain compilation speed for all backends, including the [LLVM](https://ziglang.org/download/0.11.0/release-notes.html#LLVM-16) backend.
-   [Linker](https://ziglang.org/download/0.11.0/release-notes.html#Linker) support for [ELF](https://ziglang.org/download/0.11.0/release-notes.html#ELF) and [COFF](https://ziglang.org/download/0.11.0/release-notes.html#COFF). Eliminate dependency on [LLD](https://lld.llvm.org/).
-   Hot code swapping for [Windows](https://ziglang.org/download/0.11.0/release-notes.html#Windows), [macOS](https://ziglang.org/download/0.11.0/release-notes.html#macOS), and [Linux](https://ziglang.org/download/0.11.0/release-notes.html#Linux).
-   Introduce [Concurrency](https://ziglang.org/download/0.11.0/release-notes.html#Concurrency) to semantic analysis to further increase compilation speed.
-   An explosion of reusable packages in the Zig ecosystem, creating the need for [additional tooling](https://github.com/ziglang/zig/issues/14288) to deal with [Build System](https://ziglang.org/download/0.11.0/release-notes.html#Build-System) dependency trees.

Here are the **steps for Zig to reach 1.0**:

1.  Stabilize the language. No more [Language Changes](https://ziglang.org/download/0.11.0/release-notes.html#Language-Changes) after this.
2.  Complete the language specification first draft.
3.  Stabilize the [Build System](https://ziglang.org/download/0.11.0/release-notes.html#Build-System) (this includes [Package Management](https://ziglang.org/download/0.11.0/release-notes.html#Package-Management)).
4.  Stabilize the [Standard Library](https://ziglang.org/download/0.11.0/release-notes.html#Standard-Library). That means to add any missing functionality, audit the existing functionality, curate it, re-organize everything, and fix all the [bugs](https://ziglang.org/download/0.11.0/release-notes.html#Bug-Fixes).
5.  Go one full release cycle without any breaking changes.
6.  Finally we can tag 1.0.

### [Accepted Proposals](https://ziglang.org/download/0.11.0/release-notes.html#toc-Accepted-Proposals) [§](https://ziglang.org/download/0.11.0/release-notes.html#Accepted-Proposals)

If you want more of a sense of the direction Zig is heading, you can look at [the set of accepted proposals](https://github.com/ziglang/zig/issues?q=is%3Aopen+is%3Aissue+label%3Aaccepted).

## [Thank You Contributors!](https://ziglang.org/download/0.11.0/release-notes.html#toc-Thank-You-Contributors) [§](https://ziglang.org/download/0.11.0/release-notes.html#Thank-You-Contributors)

Here are all the people who landed at least one contribution into this release:

-   Andrew Kelley
-   Jacob Young
-   Jakub Konka
-   Veikka Tuominen
-   Casey Banner
-   Luuk de Gram
-   mlugg
-   Wooster
-   Robin Voetter
-   Dominic
-   Loris Cro
-   Frank Denis
-   Ryan Liptak
-   Krzysztof Wolicki
-   Manlio Perillo
-   Michael Dusan
-   Nameless
-   Eric Joldasov
-   Motiejus Jakštys
-   Koakuma
-   Evin Yulo
-   Linus Groh
-   Xavier Bouchoux
-   Ali Chraghi
-   fn ⌃ ⌥
-   Jan Philipp Hafer
-   xEgoist
-   Cody Tapscott
-   Joachim Schmidt
-   Jacob G-W
-   Stevie Hryciw
-   Techatrix
-   Jonathan Marler
-   Josh Wolfe
-   IntegratedQuantum
-   Meghan Denny
-   antlilja
-   John Schmidt
-   Ian Johnson
-   Isaac Freund
-   Niles Salter
-   xdBronch
-   Auguste Rame
-   Ryo Ota
-   Zachary Raineri
-   DraagrenKirneh
-   Evan Haas
-   Jan200101
-   Marc Tiehuis
-   yujiri8
-   Bogdan Romanyuk
-   David Gonzalez Martin
-   Erik Arvstedt
-   Felix "xq" Queißner
-   Ganesan Rajagopal
-   Tw
-   GethDW
-   Guillaume Wenzek
-   InKryption
-   Jimmi Holst Christensen
-   Ronald Chen
-   Takeshi Yoneda
-   Travis Staloch
-   jim price
-   matu3ba
-   mllken
-   Bas Westerbaan
-   Carl Åstholm
-   Emile Badenhorst
-   Igor Anić
-   Lee Cannon
-   Matt Knight
-   Mizuochi Keita
-   Nguyễn Gia Phong
-   Nicolas Sterchele
-   Pyrolistical
-   Roman Frołow
-   Ryan Schneider
-   Tom Read Cutting
-   bfredl
-   jcalabro
-   notcancername
-   praschke
-   AdamGoertz
-   Adrian Delgado
-   Alex Kladov
-   Brendan Burns
-   Chris Boesch
-   Clement Espeute
-   Coin
-   Cortex
-   Eckhart Köppen
-   Edoardo Vacchi
-   Emile Badenhorst
-   Eric Milliken
-   Ganesan Rajagopal
-   Garrett
-   Gaëtan S
-   Gregory Mullen
-   Jason Phan
-   Jay Petacat
-   Jeremy Volkman
-   Lauri Tirkkonen
-   Leo Constantinides
-   Luis Cáceres
-   Maciej 'vesim' Kuliński
-   Martin Wickham
-   Mason Remaley
-   Mateusz Poliwczak
-   Mathew R Gordon
-   Michael Bartnett
-   Mitchell Hashimoto
-   Philippe Pittoli
-   Stephen Gregoratto
-   Tw
-   cryptocode
-   d18g
-   hequn
-   serg
-   shwqf
-   star-tek-mb
-   travisstaloch
-   \-k
-   0x5a4
-   Adam Goertz
-   Adrian Cole
-   Alexis Brodeur
-   Andrius Bentkus
-   AnnikaCodes
-   Arnau
-   Arya-Elfren
-   Asherah Connor
-   Bertie Wheen
-   Binary Craft
-   Björn Linse
-   Borja Clemente
-   Brett Hill
-   Chris Heyes
-   Christofer Nolander
-   David Carlier
-   David Vanderson
-   DerryAlex
-   Devin Singh
-   Dumitru Stavila
-   Ed Yu
-   Eric Rowley
-   Evan Typanski
-   Fabio Arnold
-   Frechdachs
-   George Zhao
-   Gregory Oakes
-   Halil
-   Hao Li
-   Hardy
-   Hashi364
-   Hayden Pope
-   Hubert Jasudowicz
-   Ivan Velickovic
-   J.C. Moyer
-   Janne Hellsten
-   Jarred Sumner
-   Jayden
-   Jens Goldberg
-   Jiacai Liu
-   Jim Price
-   Jobat
-   John Schmidt
-   John Simon
-   John Zhang
-   Jon
-   Jon-Eric Cook
-   Jonathan
-   Jonta
-   Jordan Lewis
-   Josh
-   Josh Holland
-   KOUNOIKE Yuusuke
-   Ken Kochis
-   Kim SHrier
-   Kirk Scheibelhut
-   Kitty-Cricket Piapiac
-   Kotaro Inoue
-   Kyle Coffey
-   Lavt Niveau
-   Luiz Berti
-   Marco Munizaga
-   Marcos O
-   Marcus Ramse
-   Mateusz Radomski
-   Matt Chudleigh
-   Matteo Briani
-   Micah Switzer
-   Michael Buckley
-   Mikael Berthe
-   Mikko Kaihlavirta
-   Naoki MATSUMOTO
-   Nathan Bourgeois
-   Nick Cernis
-   Nicolas Goy
-   Nikita Ronja
-   Phil Eaton
-   Philipp Lühmann
-   Piotr Sarna
-   Piotr Sikora
-   Pyry Kovanen
-   Reuben Dunnington
-   Robert Burke
-   Rohlem
-   Sebastian Bensusan
-   Silver
-   Simon A. Nielsen Knights
-   Sizhe Zhao
-   Steven Kabbes
-   Suirad
-   The Potato Chronicler
-   Tristan Ross
-   Walther Chen
-   Yujiri
-   Yusuf Bham
-   Zach Cheung
-   Zapolsky Anton
-   alex
-   alion02
-   begly
-   bing
-   dantecatalfamo
-   dec05eba
-   delitako
-   e4m2
-   ee7
-   flexicoding
-   frmdstryr
-   fsh
-   gettsu
-   h57624paen
-   iacore
-   jackji
-   jagt
-   jiacai2050
-   kkHAIKE
-   leap123
-   lockbox
-   mateusz
-   mike
-   mnordine
-   mparadinha
-   nc
-   ominitay
-   pluick
-   protty
-   pseudoc
-   remeh
-   sentientwaffle
-   square
-   sv99
-   techatrix
-   tison
-   tjog
-   tranquillity-codes
-   wrongnull
-   ypsvlq
-   zenith391
-   zhaozg
-   zigster64
-   山下
-   朕与将军解战袍

## [Thank You Sponsors!](https://ziglang.org/download/0.11.0/release-notes.html#toc-Thank-You-Sponsors) [§](https://ziglang.org/download/0.11.0/release-notes.html#Thank-You-Sponsors)

Special thanks to those who [sponsor Zig](https://ziglang.org/zsf/). Because of recurring donations, Zig is driven by the open source community, rather than the goal of making profit. In particular, these fine folks sponsor Zig for $50/month or more:

-   [Josh Wolfe](https://github.com/thejoshwolfe)
-   [Matt Knight](https://mattnite.blog/)
-   [Stevie Hryciw](https://www.hryx.net/)
-   [Jethro Nederhof](https://jethron.id.au/)
-   [Karrick McDermott](https://hachyderm.io/@karrick)
-   [José M Rico](https://www.kapricornmedia.com/)
-   [drfuchs](https://github.com/drfuchs)
-   [Joran Dirk Greef](https://github.com/tigerbeetle/tigerbeetle)
-   [Rui Ueyama](https://github.com/rui314)
-   [bfredl](https://github.com/bfredl)
-   [Stephen Gutekanst](https://slimsag.com/)
-   [Derek Collison](https://derekcollison.net/)
-   [Daniele Cocca](https://twitter.com/dcocca88)
-   [Rafael Batiati](https://twitter.com/rbatiati)
-   [Alun Bestor](https://github.com/alunbestor)
-   [Aras Pranckevičius](https://aras-p.info/)
-   [Terin Stock](https://terinstock.com/)
-   [Loïc Tosser](https://kalvad.com/)
-   [Kirk Scheibelhut](https://scheibo.com/)
-   [Mitchell Hashimoto](https://mitchellh.com/)
-   [Brian Gold](https://github.com/briangold)
-   [Paul Harrington](https://github.com/phrrngtn)
-   [MikoVerse](https://mikoverse.com/)
-   [Clark Gaebel](https://github.com/cgaebel)
-   [Oven](https://oven.sh/)
-   [Marcus](https://www.marcus.art/)
-   [Brandon H. Gomes](https://bhgomes.dev/)
-   [Ken Chilton](https://www.kchilton.com/)
-   [Sebastian](https://twitter.com/soworston)
-   [jake hemmerle](https://keybase.io/jakehemmerle)
-   Luuk de Gram
-   Jamie Brandon
-   Auguste Rame
-   Jay Petacat
-   Dirk de Visser
-   Santiago Andaluz
-   Andrew Mangogna
-   Yaroslav Zhavoronkov
-   Charlie Cheever
-   Anton Kochkov
-   Max Bernstein
-   Timothy Ham
-   Jordan Orelli
-   James McGill
-   Luke Champine
-   王爱国
-   Wojtek Mach
-   Daniel Hensley
-   Erik Mållberg
-   Christopher Dolan
-   Fabio Arnold
-   Mateusz Czarnecki
-   Ross Rheingans-Yoo
-   Emily A. Bellows
-   Mykhailo Tsiuptsiun (miktwon)
-   sparrisable
-   Kiril Mihaylov
-   Brett Slatkin
-   Martin H
-   Sean Carey
-   Yurii Rashkovskii
-   Benjamin Ebby
-   Ralph Brorsen
-   OM PropTech GmbH
-   Alex Sergeev
-   mlugg
-   Aaron Olson
-   Marco Munizaga
-   Baptiste Canton
-   Josh Ashby
-   Chris Baldwin
-   Malcolm Still
-   Francis Bouvier
-   Jacob Young
-   Alve Larsson
-   Nicolas Goy
-   Ian Johnson
-   Carlos Pizano Uribe
-   Rene Schallner
-   Alec Graves
-   Lucas Myers
-   Jinkyu Yi
