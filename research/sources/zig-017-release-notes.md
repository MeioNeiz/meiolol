---
title: Zig 0.17.0 release notes
url: https://ziglang.org/download/0.17.0/release-notes.html
kind: docs
commit:
for: [zig-only-frontend, zig-017-migration, zig-good-practice, zig-style, zig-memory, zig-errors-safety, zig-comptime, zig-api-design, zig-build, zig-testing]
looked: 2026-10-11
depth: docs (language changes, standard library, build system, package management, regressions, roadmap)
relevance: high
grade: A/strong
description: Official release notes for Zig 0.17.0 (2026-10-01): breaking language, std and build system changes with upgrade guides
---
# Zig 0.17.0 release notes

Why: which 0.17 changes hit meiolol (std.Io, build.zig, http client, sqlite C build,
wasm, Windows), and what the upgrade guides say to do.

## Assessment

- Evidence: A. The canonical reference from the Zig team, with upgrade diffs per change.
- Reasoning: strong. Explains motives and trade-offs (passthru args, maker process).
- Interests: none beyond promoting the release.
- Weigh: lists what changed, not what is still deprecated-but-working; our trial port
  ([[zig-017-trial-port]]) shows which changes actually break this repo.

## Findings

- [toolchain] @cImport is removed; TranslateC build step deprecated in favour of the external
  translate-c package. ^f1
  > @cImport was deprecated in Zig 0.16.0 and is now removed. Furthermore, in this release `std.Build.Step.TranslateC` is deprecated in favor of an explicit package dependency on official ZSF translate-c package
- [toolchain] Array multiplication `a ** b` is removed in favour of @splat. ^f2
  > Array multiplication syntax (`a ** b`) has been removed in favor of `@splat`.
- [toolchain] Struct and union type info is now struct-of-arrays (field_names, field_types). ^f3
  > When doing type reflection, structs and unions return their information in struct-of-arrays style
- [toolchain] bit_set and ascii renames: initEmpty/initFull become empty/full; indexOfIgnoreCase
  becomes findIgnoreCase. ^f4
  > Removed `std.bit_set.Integer.initEmpty` in favor of `std.bit_set.Integer.empty`.
  > Removed `std.ascii.indexOfIgnoreCase` in favor of `std.ascii.findIgnoreCase`.
- [toolchain] Run step: `b.args` is gone; use addPassthruArgs. ^f5
  > In the Run step, passthru args are all together now, not observable in configure phase whether run args are provided.
- [toolchain] build.zig now runs in a separate configurer process from the maker. ^f6
  > `zig build` now runs projects' `build.zig` code in a separate executable than the one that performs
- [toolchain] Deprecated, still working in 0.17: std.builtin (to std.lang), fmt.allocPrint (to
  Allocator.print), ArrayList getLast. ^f7
  > Deprecated `std.builtin` in favor of `std.lang`.
  > `getLastOrNull` has been deprecated and renamed to `last`
- [toolchain] Footgun: containsAtLeastScalar swapped parameter order and may still compile. ^f8
  > now be incorrect since the `element` and `minimum` parameters have swapped places
- [toolchain] Uri.getHost moved to HostName.fromUri, with a different error set. ^f9
  > `Uri.getHost` has been moved to `HostName.fromUri` (without a graceful deprecation
- [toolchain] Windows resource compilation (addWin32ResourceFile) moves to an external package
  in the next release (0.18). ^f10
  > will be moved out of the compiler and into an
- [toolchain] Checked, not there: no breaking change listed for std.Io networking or the http
  client API; the only Io addition noted is Semaphore.waitTimeout, not socket timeouts. ^f11
  > Added `std.Io.Semaphore.waitTimeout`
- [toolchain] Known regressions include response files for Run steps after the maker split. ^f12
  > breaks response file use cases for `std.Build.Step.Run`
- [toolchain] 0.18 will move to LLVM 23 and re-enable loop vectorisation. ^f13
  > Zig 0.18.0 will upgrade to LLVM 23, so will allow us to re-enable this optimization pass.


Idiom findings (added 2026-10-22, re-read for the Zig practice guide):

- [zig/safety] @bitCast now reinterprets the logical bit representation, endian-agnostic;
  array and vector casts may change meaning silently, so audit them; casts on extern
  structs are rejected: type-pun with @ptrCast or an extern union. ^f14
  > **Unfortunately, this change has the potential to break existing code without triggering a compile error.**
  > In most cases, code which was using such casts is aiming to reinterpret the value's in-memory representation (sometimes called "type punning")—to achieve this, use `@ptrCast` or an `extern union`.
- [zig/test] The grammar is now checked by fuzzing the hand-written parser against a parser
  generated from grammar.peg, used as an oracle. ^f15
  > This generated parser is then used as an oracle for fuzz testing and the handwritten `std.zig.Ast.parse()` is compared against it.
- [zig/safety] @backingInt / @fromBackingInt replace @intFromEnum / @enumFromInt
  (deprecated; zig fmt upgrades); invalid tag values are safety-checked, and @bitCast into
  an enum is now checked too. ^f16
  > These builtins replace the now-deprecated `@intFromEnum` and `@enumFromInt` builtins
  > `@bitCast` now also performs a safety check for invalid tag values if its destination type is an `enum`.
- [zig/style] `[1]T{0} ** n` is replaced by `@splat(0)` with a typed result, also in
  `.init` declarations. ^f17
  > var result: [window_size]u8 = @splat(0);
- [zig/style] @divCeil added, replacing `std.math.divCeil(a, b) catch unreachable`. ^f18
  > No more `std.math.divCeil(a, b) catch unreachable`!
- [zig/comptime] @hasDecl now sees only pub declarations, from any file. ^f19
  > Previously, `@hasDecl` returned `true` for public declarations and declarations in the same file.
- [zig/style] `void{}` removed; write `{}`. ^f20
  > `void{}` is no longer valid syntax. Use `{}` instead
- [zig/errors] `errdefer |err|` capture removed; to act on the returned error, split the
  function and `catch |err|` at the outer call. ^f21
  > The capture (`|err|`) is no longer allowed
  > To migrate, split the function into two:
- [zig/style] i0 removed (use u0); internal and link_once linkage removed. ^f22
  > This type was nonsensical, so does not have a direct alternative.
- [zig/comptime] std.meta.fieldInfo, fieldNames, fieldTypes deprecated in favour of
  @typeInfo, which is struct-of-arrays: `inline for (info.field_names, info.field_types)`. ^f23
  > Deprecated `std.meta.fieldNames` in favor of `@typeInfo`.
  > inline for (info.field_names, info.field_types) |field_name, field_type| {
- [zig/memory] StackFallbackAllocator renamed BufferFirstAllocator and takes the buffer as an
  argument, like other std APIs; the old one was generic over size and `.get()` mutated it. ^f24
  > Now, the buffer is provided as an argument, like most other std APIs that need a buffer.
  > Calling `.allocator().get()` mutated the type, unlike all other allocators, requiring a runtime safety check.
- [zig/memory] SafeAllocator replaces DebugAllocator (deprecated): thread-safe, never reuses
  memory, deinit reports all leaks, mismatches and double frees panic or segfault;
  fuzz-tested. ^f25
  > `std.heap.DebugAllocator` is replaced by a thread-safe allocator with the following guarantees:
  > `deinit` reports all leaks and frees all backing memory.
  > `std.heap.DebugAllocator` and `std.heap.Check` are deprecated.
- [zig/memory] ArrayList: getLastOrNull is `last()`, getLast is `last().?`; lastPtr added;
  ArrayList gains pointer stability checks. ^f26
  > `getLast` has been deprecated in favor of `last` combined with `.?`
- [zig/safety] debug.SafetyLock gains lockShared/unlockShared for many readers. ^f27
  > New methods, `lockShared` and `unlockShared`, may be used for shared locking in situations where multiple independent users are reading but not mutating data.
- [zig/api] `std.fmt.allocPrint(a, ...)` becomes `a.print(...)` on the Allocator; zig fmt
  --complexity shows it cuts tokens. ^f28
  > try arena.print("{s}={d}", .{ x, y });
- [zig/api] std.zon.parse takes an options struct and allocates results and diagnostics
  from an arena; `diag.fatal(...)`; updateFrom* variants layer config files. ^f29
  > `std.zon.parse` now takes struct args and allocates both its results and diagnostics from an arena.
- [zig/memory] bit_set renamed (Integer, Array, Static, Dynamic) with the managed dynamic
  one deprecated. ^f30
  > Renames the types for consistency, deprecating the previous names and the managed variant.
- [zig/safety] OptimizeMode renamed Optimize with tags debug/safe/fast/small;
  `std.lang.Optimize.runtimeSafety` preferred over std.debug.runtime_safety because it
  knows the caller's module. ^f31
  > `std.lang.Optimize.runtimeSafety` is preferred as an alternative to `std.debug.runtime_safety` since it will offer callsites knowledge about their own module rather than standard library module.
- [zig/comptime] `@import("builtin").cpu/os/abi/object_format` deprecated for
  `.target.cpu` etc. (removed in 0.18). ^f32
  > The redundant constants `cpu`, `os`, `abi`, and `object_format` in `@import("builtin")` have been deprecated and will be removed in 0.18.0.
- [zig/build] Configure cache poisoning: build.zig logic with side effects (findProgram)
  defeats configuration caching; declare inputs with dependOnFileContents etc., or use
  findProgramLazy. ^f33
  > Keeping the cache pure will make `zig build` faster, bypassing the configurer process when identical configuration would be generated.
  > A better alternative than cache poisoning is to explicitly declare the configuration dependencies with these new functions:
- [zig/build] Option paths must say file, directory or untracked (addOptionPath,
  addOptionPathDirectory, addOptionPathUntracked). ^f34
  > Now, when adding an option that is a file path, one must explicitly choose between
- [zig/build] dependencyLazy returns error.LazyDependencyNeeded so build code can `try`. ^f35
  > Introduce `std.Build.dependencyLazy` which possibly returns `error.LazyDependencyNeeded` instead of `null`, so that you can use `try`
- [zig/build] Incremental now usable for most x86_64-linux projects: `zig build
  -fincremental --watch`. ^f36
  > **Thanks to these enhancements, it is now possible for most projects targeting `x86_64-linux` to take advantage of incremental compilation.**
- [zig/style] `zig fmt --complexity` counts tokens and AST nodes, a better measure of an
  edit than line count. ^f37
  > which can be used to share how an edit to a source file increases or reduces complexity with a heuristic that is more insightful than line count.
- [zig/build] The 0.17 break of ZLS: the maker/configurer split stops ZLS working with 0.17
  until the Build Server Protocol catches up. ^f38
  > the separation of maker process and configurer process is a breaking change that prevents the ZLS project from working with 0.17.0.
- [toolchain] Checked, not there: the notes give no reason for renaming std.builtin to
  std.lang; it is listed only as a deprecation. ^f39
- [toolchain] Language stability: about 25 proposals accepted and 125 rejected this cycle;
  some major decisions remain before 1.0. ^f40
  > accepting around 25 and rejecting around 125
- [web/wasm] [toolchain] The self-hosted wasm backend passes all behaviour tests but is
  not the Debug default, because it lacks debug info; Debug wasm still goes through LLVM. ^f41
  > it is not yet the default when compiling in debug optimization mode due to lack of debug info support
- [web/wasm] [toolchain] Checked, not there: the notes do not mention the externref or
  funcref address spaces added in 0.17 (see [[zig-issue-31190]]). ^f42

## Read

- Language Changes, Standard Library, Build System, Package Management, Bug Fixes,
  Toolchain (LLVM, resinator), Roadmap: fully

## Not read

- Target support tables, linker internals, fuzzer, zig objdump: not relevant to meiolol
