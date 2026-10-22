---
title: Zig 0.14.0 release notes
url: https://ziglang.org/download/0.14.0/release-notes.html
kind: docs
commit: 
for: [zig-good-practice, zig-style, zig-memory, zig-api-design, zig-perf, zig-comptime, zig-build, zig-testing, zig-errors-safety]
looked: 2026-10-22
depth: docs (language changes, standard library, build system, compiler, fuzzer, UBSan)
relevance: high
grade: A/strong
description: Official release notes for Zig 0.14.0 (2025-03): labelled switch, decl literals and .empty/.init, DebugAllocator and SmpAllocator, unmanaged containers, root_module, fuzzer
---
# Zig 0.14.0 release notes

Why: 0.14 introduced most of the idioms modern Zig code is judged by (decl literals,
`.empty`, labelled switch, root_module); the guide needs them with the stated reasons.

## Assessment

- Evidence: A. Canonical reference from the Zig team; runnable examples and benchmarks.
- Reasoning: strong. Decl literals and unmanaged containers come with the invariant
  argument and a migration path; labelled switch explains its codegen.
- Interests: none beyond promoting the release.
- Weigh: GeneralPurposeAllocator/DebugAllocator naming and ArrayListUnmanaged spelling
  moved on in 0.15 and 0.17; the reasons still hold.

## Findings

- [zig/perf] Labelled switch: `continue :sw value` re-dispatches a switch, equivalent to
  a switch in a loop, clearer for state machines. ^f1
  > when implementing Finite State Automata where one can write `continue :fsa new_state` to represent a state transition.
- [zig/perf] Its main motive is codegen: one branch per continue helps the branch
  predictor in hot dispatch loops; the tokenizer got 13% faster. ^f2
  > This language construct is designed to generate code which aids the CPU in predicting branches between cases of the switch, allowing for increased performance in hot loops
  > Updating Zig's tokenizer to take advantage of this feature resulted in a 13% performance boost.
- [zig/comptime] A labelled switch targeted by continue is not implicitly comptime, like
  loops. ^f3
  > a labeled `switch` with one or more `continue`s targeting it is not implicitly evaluated at compile-time
- [zig/api] Decl literals: `.foo` resolves to any declaration on the result type, so
  `const v: S = .default` and `.init(x)`, also with `try`. ^f4
  > an enum literal `.foo` doesn't necessarily refer to an enum variant, but, using Result Location Semantics, can also refer to any declaration on the target type.
  > It also supports calling functions which return error unions via `try`.
- [zig/api] Field defaults that are tied together break invariants when one is
  overridden; use a named declaration (`empty`, `default`) instead. ^f5
  > Many existing uses of field default values may be more appropriately handled by a declaration named `default` or `empty` or similar, to ensure data invariants are not violated by overriding single fields.
- [zig/memory] Unmanaged containers are initialised with `.empty`, not `.{}`;
  GeneralPurposeAllocator with `.init`; the default field values were deprecated. ^f6
  > unmanaged containers, including `ArrayListUnmanaged` and `HashMapUnmanaged`, should no longer be default-initialized with `.{}`
  > Similarly, `std.heap.GeneralPurposeAllocator` should now be initialized with its `.init` declaration.
- [zig/style] Fields and declarations may not share names; standard naming (snake_case
  fields, TitleCase types) avoids the clash. ^f7
  > container types (`struct`, `union`, `enum` and `opaque`) cannot have fields and declarations (`const`/`var`/`fn`) with the same names.
- [zig/style] @splat fills arrays too, e.g. `@splat(@splat(.black))` with decl
  literals. ^f8
  > Zig 0.14.0 expands the `@splat` builtin to apply not only to vectors, but to arrays.
- [zig/perf] @branchHint(.likely/.unlikely/.cold/.unpredictable) as first statement of a
  block or function replaces @setCold. ^f9
  > `@setCold` has been removed in favor of `@branchHint`.
  > remember that `@branchHint` must be the _first statement_ in the enclosing block
- [zig/safety] @fence removed: it changes orderings of all atomics and is hard to model
  in a sanitizer; use stronger orderings or another atomic. ^f10
  > it complicates semantics by modifying the memory orderings of all previous and future atomic operations.
- [zig/style] Packed structs compare with == and work in atomics without @bitCast. ^f11
  > Packed structs can now be equated directly, without a `@bitCast` to the underlying integer type.
- [zig/comptime] Anonymous struct types removed; untyped `.{ .a = 1 }` gets a normal
  struct type; all tuples use structural equivalence and cannot have aligned fields or
  defaults. ^f12
  > This mechanism was a holdover from before we used Result Location Semantics as the primary mechanism of type inference.
- [zig/comptime] std.builtin.Type fields lowercased (`.@"struct"`, `.int`, `.pointer`),
  pointer sizes `.one`/`.many`/`.slice`. ^f13
  > Zig 0.14.0 updates the fields of the `std.builtin.Type` tagged union to follow these conventions by lowercasing them
- [zig/comptime] @FieldType(T, "name") replaces std.meta.FieldType. ^f14
  > This serves the same purpose as the `std.meta.FieldType` function
- [zig/memory] GeneralPurposeAllocator rewritten and renamed DebugAllocator. ^f15
  > It is now rewritten to make fewer active mappings, to have better performance, and is renamed to `DebugAllocator`.
- [zig/memory] SmpAllocator: a singleton for ReleaseFast multithreaded, ~200 lines,
  matching glibc malloc building Zig. ^f16
  > An allocator that is designed for ReleaseFast optimization mode, with multi-threading enabled.
  > This allocator is a singleton; it uses global state and only one should be instantiated for the entire process.
- [zig/memory] Recommended main: DebugAllocator in Debug and ReleaseSafe, smp_allocator in
  ReleaseFast and ReleaseSmall, deinit only when debugging. ^f17
  > .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
  > .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
- [zig/memory] Allocator.VTable gains remap (may relocate; null means caller copies);
  resize stays for arenas that must not move. Alignment is typed mem.Alignment. ^f18
  > `resize` is necessary for `std.heap.ArenaAllocator` which must not relocate its allocations. Meanwhile, `remap` is appropriate for `std.ArrayList` when the capacity increases.
- [zig/memory] Page size is runtime-known: std.mem.page_size removed for
  heap.page_size_min/max and heap.pageSize(). ^f19
  > Compile time known `std.mem.page_size` is removed, which is a nonsensical concept since the page size is in fact runtime-known
- [zig/safety] Comparing Allocator.ptr (or Random.ptr) is illegal behaviour: it is
  undefined for stateless allocators. ^f20
  > comparing the `ptr` field of an `Allocator` interface can lead to illegal behavior, since `Allocator.ptr` is set to undefined in cases where the allocator implementation does not have any associated state
- [zig/memory] Managed containers deprecated (ArrayHashMap, ArrayList); veterans
  converged on unmanaged: no duplicated allocator, and the allocator parameter marks
  which calls can allocate, fitting reserve-then-assume-capacity. ^f21
  > This move comes from unanimous agreement among veteran Zig users who have converged on the "unmanaged" container variants.
  > They act as better building blocks, avoiding storing the same data redundantly, and the presence/absence of the allocator parameter dovetails nicely with the reserve capacity / reserved insertion pattern.
- [zig/api] Renames: popOrNull is pop; mem.split/tokenize must pick Scalar, Any or
  Sequence; std.rand is std.Random; TailQueue is DoublyLinkedList. ^f22
  > `popOrNull` renamed to `pop` in all container types.
- [zig/comptime] std.c marks missing symbols as `void` types and `{}` functions instead
  of @compileError, so feature checks use `@TypeOf(f) != void` rather than @hasDecl;
  last std usingnamespace removed. ^f23
  > With this, the last usage of `usingnamespace` site is eliminated from the standard library.
- [zig/perf] Unordered hash maps slow down after many removals (rehash added as a stopgap);
  array hash maps don't. ^f24
  > Unordered hash maps currently have a nasty flaw: removals cause HashMaps to become slow.
  > Note that array hash maps do _not_ have this flaw.
- [zig/build] `--watch` keeps the build runner alive and reruns dirty steps; debounce
  50ms. ^f25
  > Continuously rebuild when source files are modified
- [zig/build] Compile steps take a `root_module` built with createModule, instead of
  root_source_file/target/optimize directly, so module graphs are clearer and reusable
  (e.g. a test step per module). ^f26
  > Instead of passing options like `root_source_file`, `target`, and `optimize` directly to these functions, you should pass in the `root_module` field a `*std.Build.Module` created using these parameters.
- [zig/build] addLibrary(.{ .linkage }) replaces addStaticLibrary/addSharedLibrary. ^f27
  > Acts as a replacement for `addSharedLibrary` and `addStaticLibrary`
- [zig/build] Incremental compilation opt-in with -fincremental; suggested workflow is a
  `-Dno-bin` option plus --watch for fast compile errors (14s then 63ms on 500k lines). ^f28
  > Users are encouraged to create a build option for checking compile errors only
  > after making an edit and saving, it takes only 63ms to perform reanalysis of only the changed code.
- [zig/style] Incremental does not support usingnamespace; avoid it. ^f29
  > This feature is not yet compatible with `usingnamespace`. Users are encouraged to avoid `usingnamespace` as much as possible.
- [zig/build] ZON imports at comptime with a result type: `const foo: Foo = @import("foo.zon")`;
  std.zon.parse/stringify at runtime. ^f30
  > ZON can now be imported at compile time
- [zig/test] Integrated fuzzer (alpha): `std.testing.fuzz` in a test, `zig build test
  --fuzz` with a coverage web UI. ^f31
  > Zig 0.14.0 ships with an integrated fuzzer. It is alpha quality status, which means that using it requires participating in the development process.
- [zig/test] Fuzzing as a design check: the tokenizer crashed at once and was simplified
  rather than patched; future UTF-8 validation must be fuzzed against an independent
  implementation. ^f32
  > I pointed a fuzzer at the tokenizer and it crashed immediately.
  > it must be fuzz-tested while checking the property that it matches an independent Unicode validation implementation on the same file.
- [zig/api] Prefer arrays as parameters over a runtime length assert: utf8Decode2 and
  friends take arrays, using the type system. ^f33
  > Make `utf8Decode2` and friends use arrays as parameters, eliminating a runtime assertion in favor of using the type system.
- [zig/safety] UBSan runtime on by default in Debug for C code. ^f34
  > Zig now provides a runtime library for UBSan, which is enabled by default when compiling in `Debug` mode.

## Read

- Language Changes (all), Standard Library (all sections), Build System (watch, Fmt
  step, root_module, addLibrary), Compiler (incremental, x86, ZON import, tokenizer),
  Fuzzer, UBSan

## Not read

- Calling convention detail, package hash format, wasm linker, target support
