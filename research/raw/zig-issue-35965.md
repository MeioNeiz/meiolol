#35965 - Struct with .externref field causes LLVM error when targetting`Debug - ziglang/zig - Codeberg.org 

 Codeberg has changed its Terms of Use. View complete changes . 

 LLM-generated content is being restricted. View change or read the blog post 

 Cryptocurrency projects are no longer allowed. View change 

 Dismiss 

 Explore 

 About 
 FAQ 
 Help 

 Donate 

 Register 

 Sign in 

 ziglang / zig 

 Watch 

 390

 Star 

 6.9k

 Fork 

 You've already forked zig 

 980

 Code

 Issues

 899 

 Pull requests

 338 

 Activity

 Actions

 49 

 Struct with .externref field causes LLVM error when targetting`Debug #35965 

 New issue 

 Open

 opened 2026-06-28 18:13:39 +02:00 by d3bug64 

 ·
 2 comments

 d3bug64 

 commented 2026-06-28 18:13:39 +02:00 

 Copy link

 Zig Version

 0.17.0-dev.986+f3544a707

 Steps to Reproduce, Observed Behavior, and Expected Behavior

 Compiling a struct with a .externref field in debug mode causes an LLVM Error. I couldn't catch this early because usually you target ReleaseSmall for wasm however I believe when DWARF is ready

 Raw code

 Compiling with both Debug and Relase{Fast,Small,Safe} work as expected

 const externref = ? * addrspace (. externref ) opaque {}; 
 extern fn _getExtern () externref ; 
 export fn init () void { 
 const js_ref = _getExtern (); 
 _ = js_ref ; 
 } 

 zig build-exe -target wasm32-freestanding -mcpu generic+reference_types -fstrip -fno-entry -rdynamic ./raw_externref.zig -O Debug -femit-bin=./raw_externref.zig.debug.wasm 

 zig build-exe -target wasm32-freestanding -mcpu generic+reference_types -fstrip -fno-entry -rdynamic ./raw_externref.zig -O ReleaseFast -femit-bin=./raw_externref.zig.release.wasm 

 Code with wrapper

 const externref = ? * addrspace (. externref ) opaque {}; 
 const JsRef = struct { 
 ref : externref , 
 // format ... 
 // jsonStringify ... 
 }; 
 extern fn _getExtern () externref ; 
 inline fn getExtern () JsRef { 
 return .{ . ref = _getExtern () }; 
 } 
 export fn init () void { 
 const js_ref = getExtern (); 
 _ = js_ref ; 
 } 

 Compiling with release mode works

 zig build-exe -target wasm32-freestanding -mcpu generic+reference_types -fstrip -fno-entry -rdynamic ./wrapped_externref.zig -O ReleaseFast -femit-bin=./wrapped_externref.zig.release.wasm 

 However with debug mode:

 zig build-exe -target wasm32-freestanding -mcpu generic+reference_types -fstrip -fno-entry -rdynamic ./wrapped_externref.zig -O Debug -femit-bin=./wrapped_externref.zig.debug.wasm --verbose-air --verbose-cc --verbose-link --verbose-llvm-cpu-features 

 compilation: wrapped_externref
 target: wasm32-freestanding-none
 cpu: generic
 features: +bulk-memory,+bulk-memory-opt,+call-indirect-overlong,+multivalue,+mutable-globals,+nontrapping-fptoint,+reference-types,+sign-ext,-atomics,-exception-handling,-extended-const,-fp16,-gc,-multimemory,-relaxed-simd,-simd128,-tail-call,-wide-arithmetic
compilation: compiler_rt
 target: wasm32-freestanding-none
 cpu: generic
 features: +bulk-memory,+bulk-memory-opt,+call-indirect-overlong,+multivalue,+mutable-globals,+nontrapping-fptoint,+reference-types,+sign-ext,-atomics,-exception-handling,-extended-const,-fp16,-gc,-multimemory,-relaxed-simd,-simd128,-tail-call,-wide-arithmetic

 LLVM ERROR: Cannot select: 0x76c00668a4e0: ch = store<(store (s0) into %ir.1)> 0x76c00668a710:1, 0x76c00668a710, TargetFrameIndex:i32<0>, undef:i32
 0x76c00668a710: externref,ch = WebAssemblyISD::CALL 0x76c03415b918, 0x76c00668a6a0
 0x76c00668a6a0: i32 = WebAssemblyISD::Wrapper TargetGlobalAddress:i32<ptr @_getExtern> 0
In function: wrapped_externref.init

 ### Zig Version

0.17.0-dev.986+f3544a707

### Steps to Reproduce, Observed Behavior, and Expected Behavior

Compiling a struct with a .externref field in debug mode causes an LLVM Error. I couldn't catch this early because usually you target ReleaseSmall for wasm however I believe when DWARF is ready

### Raw code
Compiling with both Debug and Relase{Fast,Small,Safe} work as expected

```zig
const externref = ?*addrspace(.externref) opaque {};
extern fn _getExtern() externref;
export fn init() void {
 const js_ref = _getExtern();
 _ = js_ref;
}
```

`zig build-exe -target wasm32-freestanding -mcpu generic+reference_types -fstrip -fno-entry -rdynamic ./raw_externref.zig -O Debug -femit-bin=./raw_externref.zig.debug.wasm`

`zig build-exe -target wasm32-freestanding -mcpu generic+reference_types -fstrip -fno-entry -rdynamic ./raw_externref.zig -O ReleaseFast -femit-bin=./raw_externref.zig.release.wasm`

### Code with wrapper
```zig
const externref = ?*addrspace(.externref) opaque {};
const JsRef = struct {
 ref: externref,
 // format ...
 // jsonStringify ...
};
extern fn _getExtern() externref;
inline fn getExtern() JsRef {
 return .{ .ref = _getExtern() };
}
export fn init() void {
 const js_ref = getExtern();
 _ = js_ref;
}
```

Compiling with release mode works
`zig build-exe -target wasm32-freestanding -mcpu generic+reference_types -fstrip -fno-entry -rdynamic ./wrapped_externref.zig -O ReleaseFast -femit-bin=./wrapped_externref.zig.release.wasm`

However with debug mode:

`zig build-exe -target wasm32-freestanding -mcpu generic+reference_types -fstrip -fno-entry -rdynamic ./wrapped_externref.zig -O Debug -femit-bin=./wrapped_externref.zig.debug.wasm --verbose-air --verbose-cc --verbose-link --verbose-llvm-cpu-features`

```
compilation: wrapped_externref
 target: wasm32-freestanding-none
 cpu: generic
 features: +bulk-memory,+bulk-memory-opt,+call-indirect-overlong,+multivalue,+mutable-globals,+nontrapping-fptoint,+reference-types,+sign-ext,-atomics,-exception-handling,-extended-const,-fp16,-gc,-multimemory,-relaxed-simd,-simd128,-tail-call,-wide-arithmetic
compilation: compiler_rt
 target: wasm32-freestanding-none
 cpu: generic
 features: +bulk-memory,+bulk-memory-opt,+call-indirect-overlong,+multivalue,+mutable-globals,+nontrapping-fptoint,+reference-types,+sign-ext,-atomics,-exception-handling,-extended-const,-fp16,-gc,-multimemory,-relaxed-simd,-simd128,-tail-call,-wide-arithmetic
```
```
LLVM ERROR: Cannot select: 0x76c00668a4e0: ch = store<(store (s0) into %ir.1)> 0x76c00668a710:1, 0x76c00668a710, TargetFrameIndex:i32<0>, undef:i32
 0x76c00668a710: externref,ch = WebAssemblyISD::CALL 0x76c03415b918, 0x76c00668a6a0
 0x76c00668a6a0: i32 = WebAssemblyISD::Wrapper TargetGlobalAddress:i32<ptr @_getExtern> 0
In function: wrapped_externref.init
```

 d3bug64 

 added the bug
 label 2026-06-28 18:13:39 +02:00 

 justusk 

 added the arch/wasm
 backend/llvm
 labels 2026-06-28 18:17:00 +02:00 

 Kuwazy 

 commented 2026-06-28 19:50:30 +02:00 

 Copy link

 You appear to be using an optional pointer in the .externref addressing. I've already opened an issue related to this. The issue is directly related to this: #35901 

 You appear to be using an optional pointer in the `.externref` addressing. I've already opened an issue related to this. The issue is directly related to this: https://codeberg.org/ziglang/zig/issues/35901

 Kuwazy 

 commented 2026-06-28 19:54:12 +02:00 

 Copy link

 Basically, the compiler doesn't know how to handle NULL pointers when .externref or .funcref is used. Functions cannot return !*addrspace(.externref) opaque {} ; errors encapsulating .externref pointers are not supported. (That's another problem I've found)

 Basically, the compiler doesn't know how to handle NULL pointers when `.externref` or `.funcref` is used. Functions cannot return `!*addrspace(.externref) opaque {}`; errors encapsulating `.externref` pointers are not supported. (That's another problem I've found)

 Sign in to join this conversation.

 No Branch/Tag specified 

 Branches

 Tags

 master

 0.17.x

 cache-manifest-watch-inputs

 start-code

 qemu-ld-prefix

 less-pt-more-zcu

 wasm-default-backend

 macho2-wip

 elf2-wip

 elfv2

 restricted

 panic-rewrite

 parking-futex-lockfree

 windows-Io-cleanup

 Io-watch

 ParseCommandLineOptions

 windows-async-files

 poll-ring

 debug-file-leaks-differently

 debug-file-leaks

 ProcessPrng

 elfv2-dyn

 jobserver

 threadtheft

 io-threaded-no-queue

 0.15.x

 Io.net

 comptime-allocator

 restricted-function-pointers

 cli

 wasm-linker-writer

 wrangle-writer-buffering

 sha1-stream

 async-await-demo

 fixes

 0.14.x

 ast-node-methods

 macos-debug-info

 make-vs-configure

 fuzz-macos

 sans-aro

 ArrayList-reserve

 incr-bug

 llvm-ir-nosanitize-metadata

 ci-tarballs

 ci-scripts

 threadpool

 0.12.x

 new-pkg-hash

 json-diagnostics

 more-doctests

 rework-comptime-mutation

 0.11.x

 ci-perf-comment

 stage2-async

 0.10.x

 autofix

 0.9.x

 aro

 hcs

 0.8.x

 0.7.x

 0.17.0

 0.16.0

 0.15.2

 0.15.1

 0.15.0

 0.14.1

 0.14.0

 0.12.1

 0.13.0

 0.12.0

 0.11.0

 0.10.1

 0.10.0

 0.9.1

 0.9.0

 0.8.1

 0.8.0

 0.7.1

 0.7.0

 0.6.0

 0.5.0

 0.4.0

 0.3.0

 0.2.0

 0.1.1

 0.1.0

 Labels 

 Clear labels 

    abi/f32

    abi/ilp32

    abi/sf

    accepted

 This proposal is planned. 

    arch/21k

    arch/6502

    arch/aarch64

    arch/alpha

    arch/amdgcn

    arch/arc

    arch/arc32

    arch/arc64

    arch/arm

    arch/avr

    arch/bfin

    arch/bpf

    arch/colossus

    arch/cris

    arch/csky

    arch/dlx

    arch/epiphany

    arch/fr30

    arch/frv

    arch/hexagon

    arch/hppa

    arch/hppa64

    arch/ia64

    arch/kalimba

    arch/kvx

    arch/lanai

    arch/lm32

    arch/loongarch32

    arch/loongarch64

    arch/m32r

    arch/m68k

    arch/m88k

    arch/mcore

    arch/microblaze

    arch/mips

    arch/mips64

    arch/mmix

    arch/moxie

    arch/mrisc32

    arch/msp430

    arch/nds32

    arch/ns32k

    arch/nvptx

    arch/or1k

    arch/powerpc

    arch/powerpc64

    arch/propeller

    arch/riscv32

    arch/riscv64

    arch/rl78

    arch/rx

    arch/s390x

    arch/sh

    arch/sparc

    arch/sparc64

    arch/spirv

    arch/spu

    arch/tricore

    arch/v850

    arch/vax

    arch/vc4

    arch/ve

    arch/wasm

    arch/x86

    arch/x86_64

    arch/xcore

    arch/xtensa

    autodoc

 The web application for interactive documentation and generation of its assets. 

    backend/c

 The C backend outputs C source code. 

    backend/llvm

 The LLVM backend outputs an LLVM bitcode module. 

    backend/self-hosted

 The self-hosted backends produce machine code directly. 

    binutils

 Zig's included binary utilities: zig ar, zig dlltool, zig lib, zig ranlib, zig objcopy, and zig rc. 

    breaking

 Implementing this issue could cause existing code to no longer compile or have different behavior. 

    build system

 The Zig build system - zig build, std.Build, the build runner, and package management. 

    debug info

 An issue related to debug information (e.g. DWARF) produced by the Zig compiler. 

    docs

 An issue with documentation, e.g. the language reference or standard library doc comments. 

    error message

 This issue points out an error message that is unhelpful and should be improved. 

    frontend

 Tokenization, parsing, AstGen, ZonGen, Sema, Legalize, and Liveness. 

    fuzzing

 An issue related to Zig's integrated fuzz testing. 

    incremental

 Reuse of internal compiler state for faster compilation. 

    lib/c

 This issue relates to Zig's libc implementation and/or vendored libcs. 

    lib/compiler-rt

 This issue relates to Zig's compiler-rt library. 

    lib/cxx

 This issue relates to Zig's vendored libc++ and/or libc++abi. 

    lib/std

 This issue relates to Zig's standard library. 

    lib/tsan

 This issue relates to Zig's vendored libtsan. 

    lib/ubsan-rt

 This issue relates to Zig's ubsan-rt library. 

    lib/unwind

 This issue relates to Zig's vendored libunwind. 

    linking

 Zig's integrated object file and incremental linker. 

    miscompilation

 The compiler reports success but produces semantically incorrect code. 

    os/android

    os/dragonfly

    os/driverkit

    os/emscripten

    os/freebsd

    os/fuchsia

    os/haiku

    os/hurd

    os/illumos

    os/ios

    os/linux

    os/maccatalyst

    os/macos

    os/managarm

    os/netbsd

    os/ohos

    os/openbsd

    os/plan9

    os/redox

    os/rtems

    os/serenity

    os/tvos

    os/uefi

    os/visionos

    os/wasi

    os/watchos

    os/windows

    proposal

 This issue suggests language modifications. If it also has the "accepted" label then it is planned. 

    release notes

 This issue or pull request should be mentioned in the release notes. 

    testing

 This issue is related to testing the compiler, standard library, or other parts of Zig. 

    zig cc

 Zig as a drop-in C-family compiler. 

    zig fmt

 The Zig source code formatter. 

    zig reduce

 The Zig source code reduction tool. 

    bounty

 https://ziglang.org/news/announcing-donor-bounties 

    bug

 Observed behavior contradicts documented or intended behavior. 

    contributor-friendly

 This issue is limited in scope and/or knowledge of project internals. 

    downstream

 An issue with a third-party project that uses this project. 

    enhancement

 Solving this issue will likely involve adding new logic or components to the codebase. 

    infra

 An issue related to project infrastructure, e.g. continuous integration. 

    optimization

 A task to improve performance and/or resource usage. 

    question

 No questions on the issue tracker; use a community space instead. 

    regression

 Something that used to work in a previous version stopped working 

    upstream

 An issue with a third-party project that this project uses. 

    use case

 Describes a real use case that is difficult or impossible, but does not propose a solution. 

 No labels 

 abi/f32

 abi/ilp32

 abi/sf

 accepted

 arch/21k

 arch/6502

 arch/aarch64

 arch/alpha

 arch/amdgcn

 arch/arc

 arch/arc32

 arch/arc64

 arch/arm

 arch/avr

 arch/bfin

 arch/bpf

 arch/colossus

 arch/cris

 arch/csky

 arch/dlx

 arch/epiphany

 arch/fr30

 arch/frv

 arch/hexagon

 arch/hppa

 arch/hppa64

 arch/ia64

 arch/kalimba

 arch/kvx

 arch/lanai

 arch/lm32

 arch/loongarch32

 arch/loongarch64

 arch/m32r

 arch/m68k

 arch/m88k

 arch/mcore

 arch/microblaze

 arch/mips

 arch/mips64

 arch/mmix

 arch/moxie

 arch/mrisc32

 arch/msp430

 arch/nds32

 arch/ns32k

 arch/nvptx

 arch/or1k

 arch/powerpc

 arch/powerpc64

 arch/propeller

 arch/riscv32

 arch/riscv64

 arch/rl78

 arch/rx

 arch/s390x

 arch/sh

 arch/sparc

 arch/sparc64

 arch/spirv

 arch/spu

 arch/tricore

 arch/v850

 arch/vax

 arch/vc4

 arch/ve

 arch/wasm

 arch/x86

 arch/x86_64

 arch/xcore

 arch/xtensa

 autodoc

 backend/c

 backend/llvm

 backend/self-hosted

 binutils

 breaking

 build system

 debug info

 docs

 error message

 frontend

 fuzzing

 incremental

 lib/c

 lib/compiler-rt

 lib/cxx

 lib/std

 lib/tsan

 lib/ubsan-rt

 lib/unwind

 linking

 miscompilation

 os/android

 os/dragonfly

 os/driverkit

 os/emscripten

 os/freebsd

 os/fuchsia

 os/haiku

 os/hurd

 os/illumos

 os/ios

 os/linux

 os/maccatalyst

 os/macos

 os/managarm

 os/netbsd

 os/ohos

 os/openbsd

 os/plan9

 os/redox

 os/rtems

 os/serenity

 os/tvos

 os/uefi

 os/visionos

 os/wasi

 os/watchos

 os/windows

 proposal

 release notes

 testing

 zig cc

 zig fmt

 zig reduce

 bounty

 bug

 contributor-friendly

 downstream

 enhancement

 infra

 optimization

 question

 regression

 upstream

 use case

 Milestone 

 Clear milestone

 No items

 No milestone 

 Assignees 

 Clear assignees

 No assignees

 2 participants 

 Notifications 

 Subscribe

 Due date 

 The due date is invalid or out of range. Please use the format "yyyy-mm-dd".

 No due date set.

 Dependencies 

 No dependencies set

 Reference

 ziglang/zig#35965 

 Write 
 Preview 

 Loading…

 Add table 

 Rows 

 Columns 

 Cancel 
 OK 

 Add a link 

 Url

 Description

 Hint: With a URL in your clipboard, you can paste directly into the editor to create a link.

 Cancel 
 OK 

 Cancel 
 Save 

 Reference in a new issue

 Repository 

 ziglang/zig

 Title 

 Body 

 Create issue 

 No description provided. 

 Delete branch "%!s( )"

 Deleting a branch is permanent. Although the deleted branch may continue to exist for a short time before it actually gets removed, it CANNOT be undone in most cases. Continue?

 No 
 Yes 

 Powered by 

 with modifications 

 Codeberg 

 Blog 

 Documentation 

 Community issues 

 Contributing 
 Report abuse 

 Association 

 Who are we? 

 Bylaws / Satzung 

 Donate 

 Join / Support 

 Contact 

 Services 

 Codeberg Pages 

 Codeberg Translate 

 Woodpecker CI 

 Forgejo API 

 Status page 

 Legal 

 Imprint / Impressum 

 Privacy Policy 

 Licenses 

 Terms of Use 

 Mastodon |
 Matrix Space 
 (Web link) 

 Powered by Forgejo 

 English

 Bahasa Indonesia 

 Dansk 

 Deutsch 

 English 

 Español 

 Esperanto 

 Filipino 

 Français 

 Italiano 

 Latviešu 

 Magyar nyelv 

 Nederlands 

 Plattdüütsch 

 Polski 

 Português de Portugal 

 Português do Brasil 

 Slovenščina 

 Suomi 

 Svenska 

 Türkçe 

 Čeština 

 Ελληνικά 

 Български 

 Русский 

 Українська 

 فارسی 

 日本語 

 简体中文 

 繁體中文（台灣） 

 繁體中文（香港） 

 한국어 

 Page: 161ms

 Template: 45ms