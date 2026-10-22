---
title: Zig 0.17.0 language reference, part B (Errors to Keyword Reference)
url: https://ziglang.org/documentation/0.17.0/index.html
kind: docs
commit:
origin: zig-langref-017-a
for: [zig-good-practice, zig-style, zig-memory, zig-errors-safety, zig-comptime, zig-api-design, zig-testing, zig-perf, zig-build]
looked: 2026-10-22
depth: docs (raw lines 6907-14972: Errors, Optionals, Casting, Zero Bit Types, Result Location Semantics, comptime, Assembly, Atomics, Builtin Functions, Optimization Mode, Single Threaded, Illegal Behavior, Memory, Compile Variables, Compilation Model, Build System, C, WebAssembly, Targets, Style Guide, Source Encoding, Keyword Reference)
relevance: high
grade: A/strong
description: Second half of the official Zig 0.17.0 language reference: error handling, casting, comptime, builtins, build modes, illegal behaviour, allocator choice, compilation model, C interop and the official Style Guide
---
# Zig 0.17.0 language reference, part B (Errors to Keyword Reference)

Why: the language's own guidance for a guide on good Zig: Style Guide in full, choosing an
allocator, error idioms, illegal behaviour and build modes, comptime idioms and limits,
casting builtins, C interop. Same document as [[zig-langref-017-a]] (origin), which covers
raw lines 366-6906. Raw: `raw/zig-langref-017-b.md` (a copy of `raw/zig-langref-017.md`).

## Assessment

- Evidence: A. The canonical reference shipped with the compiler by the Zig team; the Style
  Guide calls itself the point of reference "should anyone wish to point to an authority".
  Every code sample is a test run by the docs build (outputs shown, paths in
  /home/andy/src/zig/doc/langref).
- Reasoning: strong for errors, illegal behaviour, allocator choice and style (each rule
  says why, e.g. the overcommit argument, the @hasDecl dead-code risk, "a word that
  applies to all types"). Weak spots: Atomics is two TODOs, noalias and addrspace are TODO,
  the build system is deferred to an external page, recursion text dates from 0.3.0.
- Interests: none beyond the language's own philosophy (no default allocator, handle OOM).
- Weigh: trust it as the definition of 0.17 semantics and names. Some examples lag the
  0.17 renames: @intFromFloat is used in examples although marked deprecated, and the
  @setRuntimeSafety sample comments still say ReleaseFast/ReleaseSmall although modes are
  now debug/safe/fast/small. Cross-check renames against [[zig-017-release-notes]].

## Findings

### Errors

- [zig/errors] Error names are global small integers: every error name in the compilation
  gets one unsigned integer, the same value wherever it is declared; default type u16. ^f1
  > each error name across the entire compilation gets assigned an unsigned integer greater than 0
  > The error set type defaults to a `u16`
- [zig/errors] Avoid `anyerror`: a known error set gives better docs and lets switch flag a
  forgotten error. ^f2
  > The global error set should generally be avoided because it prevents the compiler from knowing what errors are possible at compile-time.
  > Knowing the error set at compile-time is better for generated documentation and helpful error messages, such as forgetting a possible error value in a switch
- [zig/errors] Four ways to consume an error union: default with `catch value`, propagate with
  `try`, assert with `catch unreachable`, or branch per error with `if ... else |err| switch`. ^f3
  > You want to provide a default value if it returned an error.
  > You know with complete certainty it will not return an error, so want to unconditionally unwrap it.
  > You want to take a different action for each possible error.
- [zig/errors] `try x` is shorthand for `x catch |err| return err`. ^f4
  > `try` evaluates an error union expression. If it is an error, it returns from the current function with the same error. Otherwise, the expression results in the unwrapped value.
- [zig/errors] [zig/safety] `catch unreachable` is an assertion: it panics in debug and safe
  builds if the assumption is wrong, and is the sanctioned way to ignore an error. ^f5
  > If you really want to ignore the error, you can add `catch unreachable` and get the added benefit of crashing in debug and safe modes if your assumption was wrong.
- [zig/errors] Handle some errors and pass the rest on: the `else` prong of the switch
  captures a narrower error set. ^f6
  > you can capture the unhandled errors in the `else` case, which now contains a narrower error set
- [zig/errors] [zig/memory] `errdefer` runs only when the block exits with an error; the
  cleanup sits right after the acquisition, so every exit path is covered. ^f7
  > evaluates the deferred expression on block exit path if and only if the function returned with an error from the block
  > The deallocation code is always directly following the allocation code.
- [zig/errors] An unchecked error is a compile error; error types let the compiler weight
  branches towards success. ^f8
  > it's completely practical to have failing to check for an error be a compile error
  > it can pre-weight branches in favor of errors not occurring
- [zig/errors] Merge sets with `||`, mainly for functions whose errors differ by comptime
  branch (std: `LinuxFileOpenError || WindowsFileOpenError`); left-hand doc comments win. ^f9
  > This is especially useful for functions which return different error sets depending on comptime branches.
  > Doc comments from the left-hand side override doc comments from the right-hand side.
- [zig/errors] [zig/api] Inferred error sets (`!T`) make the function generic: no function
  pointer, set may differ by target, no recursion. Use an explicit set there, grown from
  empty by following compile errors. ^f10
  > When a function has an inferred error set, that function becomes generic and thus it becomes trickier to do certain things with it, such as obtain a function pointer, or have an error set that is consistent across different build targets. Additionally, inferred error sets are incompatible with recursion.
  > In these situations, it is recommended to use an explicit error set. You can generally start with an empty error set and let compile errors guide you toward completing the set.
- [zig/errors] Error return traces record every point an error was returned through, not just
  the final stack, so `try` everywhere stays debuggable; on by default only in debug. ^f11
  > This makes it practical to use try everywhere and then still be able to know what happened if an error ends up bubbling all the way out of your application.
  > Error Return Traces are enabled by default in debug builds and disabled by default in fast, safe and small builds.
- [zig/errors] [zig/perf] Trace cost: one memory write on the success path, a couple of math ops
  per error return. ^f12
  > That's it for the path when no errors occur. It's practically free in terms of performance.
- [zig/errors] Traces print when an error is returned from main, reaches `catch unreachable`
  (default panic handler), or via @errorReturnTrace and `std.debug.dumpErrorReturnTrace`. ^f13
  > Return an error from main
  > You can use `std.debug.dumpErrorReturnTrace` to print it.
- [zig/errors] Don't persist error integers: @intFromError and @errorFromInt are discouraged
  because the numbering changes with the source. ^f14
  > It is generally recommended to avoid this cast, as the integer representation of an error is not stable across source code changes.
- [zig/errors] [zig/perf] The error name table is only emitted if @errorName is called with a
  runtime value. ^f15
  > If there are no calls to `@errorName` in an entire application, or all calls have a compile-time known value for `err`, then no error name table will be generated.
- [zig/errors] [zig/memory] Allocation failure is an error (`error.OutOfMemory`), not a crash; the
  doc rejects the "Linux overcommits anyway" argument (Windows, embedded and real-time don't
  overcommit; OOM killer is nondeterministic; libraries get reused). ^f16
  > Instead, `error.OutOfMemory` represents heap allocation failure, and Zig libraries return this error code whenever heap allocation failure prevented an operation from completing successfully.
  > By making code handle allocation failure correctly, a library becomes eligible to be reused in more contexts.
- [zig/errors] main may return void, E!void, u8 or E!u8; an error prints the trace and exits 1. ^f17
  > Returning an error value from this function will print an Error Return Trace and exit with code 1.
- [zig/errors] [zig/safety] Checked arithmetic: std.math.add/sub/mul/divTrunc/divFloor/divCeil/
  divExact/shl return errors; @addWithOverflow and friends return a (result, u1) tuple; `+%`
  `-%` `*%` wrap by definition. ^f18
  > These functions provided by the standard library return possible errors.
  > These operations have guaranteed wraparound semantics.

### Optionals

- [zig/safety] [zig/perf] `?*T` is the size of `*T` (null is address 0), so optional pointers
  cost nothing; plain pointers can never be null. ^f19
  > An optional pointer is guaranteed to be the same size as a pointer. The `null` of the optional is guaranteed to be address 0.
- [zig/errors] `x orelse return null` unwraps once and the name is non-null for the rest of
  the function, as concise as C's null check. ^f20
  > The `orelse` keyword unwrapped the optional type and therefore `ptr` is guaranteed to be non-null everywhere it is used in the function.

### Casting

- [zig/safety] Coercion is for conversions that are completely safe; explicit casts (builtins)
  for those that should not happen by accident. ^f21
  > Type coercions are only allowed when it is completely unambiguous how to get from one type to another, and the transformation is guaranteed to be safe.
  > Some explicit casts can violate type safety when used incorrectly.
- [zig/style] Prefer `@as` (coercion) whenever it works. ^f22
  > is the preferred way to convert between types, whenever possible
- [zig/style] Cast builtins take their destination from the result type; give one with a
  typed `const`, a field or `@as` where context has none. ^f23
  > Rather than taking as an argument the type to cast to, these builtins use their result type to determine this information. The result type is often known from context; where it is not, the `@as` builtin can be used to explicitly provide a result type.
- [zig/safety] `@intCast` asserts the value fits (safety-checked); `@truncate` deliberately
  drops high bits and is defined for any value. Pick by intent. ^f24
  > Attempting to convert a number which is out of range of the destination type results in safety-checked Illegal Behavior.
  > Calling `@truncate` on a number out of range of the destination type is well defined and working code
  > Use @intCast to convert numbers guaranteed to fit the destination type.
- [toolchain] [zig/style] 0.17: @enumFromInt is deprecated for @fromBackingInt (or @bitCast). ^f25
  > Deprecated. Use @fromBackingInt or @bitCast instead.
- [toolchain] [zig/style] 0.17: @intFromEnum is deprecated for @backingInt (or @bitCast); both new
  builtins also cover packed structs and packed unions. ^f26
  > Deprecated. Use @backingInt or @bitCast instead.
  > Converts an enum, a packed struct or a packed union value to its backing integer.
- [toolchain] [zig/safety] 0.17: @intFromFloat is deprecated; @round, @floor, @ceil and @trunc
  convert straight to an integer result type, with a safety check that it fits. ^f27
  > Deprecated. Equivalent to @trunc.
  > When the inferred result type is an integer, the integer part is extracted from the rounded result. If that value cannot fit in the destination type, it invokes safety-checked Illegal Behavior.
- [zig/safety] @floatFromInt is always legal; it rounds to the closest float. ^f28
  > Converts an integer to the closest floating point representation.
  > This operation is legal for all values of all integer types.
- [zig/safety] @ptrCast is deliberately narrow: const, volatile, address space and alignment
  each have their own cast, and pointer-to-slice uses slicing. ^f29
  > Removing `const` qualifier, use @constCast.
  > Increasing pointer alignment, use @alignCast.
  > Casting a non-slice pointer to a slice, use slicing syntax `ptr[start..end]`.
- [zig/safety] @bitCast needs equal sizes and a defined layout: not for bare structs, slices,
  optionals, error unions or pointers (use @ptrCast/@ptrFromInt). ^f30
  > It's a compile error to bitcast a value of undefined layout
  > Asserts that `@typeInfo(DestType) != .pointer`. Use `@ptrCast` or `@ptrFromInt` if you need this.
- [zig/safety] @alignCast inserts a runtime alignment check. ^f31
  > A pointer alignment safety check is added to the generated code to make sure the pointer is aligned as promised.
- [zig/safety] Integers coerce to floats only when exact (u24 to f32, u53 to f64); larger need
  @floatFromInt. A comptime-known value may narrow implicitly when it fits. ^f32
  > Integers coerce to Floats if every possible integer value can be stored in the float without rounding
  > When a number is comptime-known to be representable in the destination type, it may be coerced

### Zero bit types and result locations

- [zig/perf] [zig/api] `void` as a generic argument deletes the field and its code:
  `AutoHashMap(K, void)` is a set with no value storage. ^f33
  > By using `void` as the type of the value, the hash map entry type has no value field, and thus the hash map takes up less space.
- [zig/style] Non-void results must be used or discarded explicitly with `_ =`. ^f34
  > Expressions of type `void` are the only ones whose value can be ignored.
- [zig/api] Result location semantics are language spec, not an optimisation detail, and are
  the main type inference mechanism. ^f35
  > This is not an implementation detail: the logic outlined above is codified into the Zig language specification, and is the primary mechanism of type inference in the language.
- [zig/api] [zig/perf] Anonymous initialisers write fields straight into the destination, which
  avoids copies and matters for pinned types. ^f36
  > This system can be used to prevent intermediate copies when initializing data structures, which can be important for types which must have a fixed memory address
- [zig/safety] Gotcha: `arr = .{ arr[1], arr[0] }` is not a swap, because the initialiser
  desugars into field-by-field stores into the destination. ^f37
  > In essence, Zig desugars the assignment `foo = .{ .a = x, .b = y }` to the two statements `foo.a = x; foo.b = y;`.
  > the following logic looks sound, but in fact is not
- [zig/api] Typed initialisers `T{ .a = x }` do not forward the result location; anonymous
  `.{ .a = x }` with a result type does. ^f38
  > typed initializers do not propagate result locations

### comptime

- [zig/comptime] Generics are comptime parameters: compile-time duck typing, checked when each
  instantiation is analysed. ^f39
  > Compile-time parameters is how Zig implements generics. It is compile-time duck typing.
- [zig/comptime] A comptime-known `if`/`switch` condition skips analysis of the untaken branch,
  so type-specific code can sit in one generic function. ^f40
  > the compiler guarantees that it will skip analysis of the branch not taken
- [zig/comptime] [zig/perf] comptime is about guarantees, not speed. ^f41
  > This is not a way to write more optimized code, but it is a way to make sure that what should happen at compile-time, does happen at compile-time.
- [zig/comptime] Inside a `comptime` block anything runtime-dependent is a compile error; the
  same function can run at comptime and runtime unchanged. ^f42
  > All code with runtime side effects or depending on runtime values emits a compile error.
  > This means that a programmer can create a function which is called both at compile-time and run-time, with no modification to the function required.
- [zig/comptime] Comptime evaluation has a 1000 backwards-branch budget, raised per scope with
  @setEvalBranchQuota (smaller values are ignored). Known flaw: runaway comptime recursion
  can overflow the compiler stack instead (#13724). ^f43
  > evaluation exceeded 1000 backwards branches
  > If the `new_quota` is smaller than the default quota (`1000`) or a previously explicitly set quota, it is ignored.
  > there is a design flaw in the compiler causing it to stack overflow instead of having the proper behavior here
- [zig/comptime] [zig/perf] Container-level expressions are implicitly comptime: lookup tables
  can be computed by ordinary functions at declaration. ^f44
  > At Namespace level (outside of any function), all expressions are implicitly `comptime` expressions. This means that we can use functions to initialize complex constant data.
- [zig/comptime] [zig/api] A generic type is a function returning an anonymous struct; Zig names
  it after the call (`List(i32)`); assign to a const to name a type. ^f45
  > It's a function that returns an anonymous `struct`.
  > To explicitly give a type a name, we assign it to a constant.
- [zig/comptime] std's print is userland comptime code: format strings are parsed at compile
  time and mismatched arguments are compile errors. ^f46
  > Zig does not special case string formatting in the compiler and instead exposes enough power to accomplish this task in userland.
  > Zig doesn't care whether the format argument is a string literal, only that it is a compile-time known value that can be coerced to a `[]const u8`
- [zig/comptime] Avoid @hasDecl for conditional compilation: a rename or typo silently disables
  code; check `builtin.target.os.tag` and similar instead. ^f47
  > using `@hasDecl` to implement conditional compilation based on the presence or absence of declarations in an API runs the risk of introducing dead code into the codebase, unnoticed.
  > it is more maintainable to check `@import("builtin").target.os.tag` rather than `@hasDecl`
- [zig/comptime] @inComptime is for comptime-friendly alternative implementations, not for
  keeping functions out of comptime. ^f48
  > It should not be used, for instance, to exclude certain functions from being evaluated at comptime.
- [zig/comptime] @compileLog is comptime printf debugging that always fails the build, so it
  can't be left in. ^f49
  > To prevent accidentally leaving compile log statements in a codebase, a compilation error is added to the build
- [toolchain] [zig/comptime] 0.17 type construction: per-kind builtins @Int, @Tuple, @Pointer,
  @Fn, @Struct, @Union, @Enum (struct-of-arrays arguments); checked, not there: no `@Type`
  builtin in the 0.17 list. ^f50
  > Returns an integer type with the given signedness and bit width.
  > Returns a struct type with the properties specified by the arguments.
- [toolchain] [zig/comptime] 0.17 language types live in `std.lang` (std.lang.Type,
  AtomicOrder, CallModifier, SourceLocation, Signedness); checked, not there: `std.builtin`
  appears nowhere in the reference. ^f51
  > `AtomicOrder` can be found with `@import("std").lang.AtomicOrder`.
  > @typeInfo(comptime T: type) std.lang.Type
- [zig/comptime] @typeInfo fields and decls come in source order. ^f52
  > has fields which are guaranteed to be in the same order as appearance in the source file
- [zig/comptime] @TypeOf evaluates its operands without runtime side effects. ^f53
  > The expressions are evaluated, however they are guaranteed to have no runtime side-effects
- [zig/comptime] [zig/style] `const Self = @This();` inside a returned struct; at file scope
  @This() is the file's struct. ^f54
  > When `@This()` is used at file scope, it returns a reference to the struct that corresponds to the current file.

### Builtins the doc steers towards or away from

- [zig/errors] Prefer `std.debug.panic` over @panic, except in libraries calling the root's
  handler or mixed C/Zig objects. ^f55
  > Generally it is better to use `@import("std").debug.panic`.
- [zig/safety] Use `std.crypto.secureZero`, not @memset, to wipe secrets. ^f56
  > For securely zeroing out sensitive contents from memory, you should use `std.crypto.secureZero`
- [zig/memory] Don't call @wasmMemoryGrow/@wasmMemorySize unless writing an allocator; use
  `std.heap.WasmPageAllocator`. ^f57
  > So unless you are writing a new allocator from scratch, you should use something like `@import("std").heap.WasmPageAllocator`.
- [zig/perf] In a retry loop use @cmpxchgWeak; @cmpxchgStrong only when you need the stronger
  guarantee. ^f58
  > If you are using cmpxchg in a retry loop, the sporadic failure will be no problem, and `cmpxchgWeak` is the better choice
- [zig/safety] @divExact/@divFloor/@divTrunc/@divCeil/@mod/@rem put the preconditions on the
  caller; `std.math` versions return errors instead. ^f59
  > Caller guarantees `denominator != 0` and `@divTrunc(numerator, denominator) * denominator == numerator`.
  > For a function that returns a possible error code, use `@import("std").math.divExact`.
- [zig/safety] [zig/perf] @setRuntimeSafety overrides the build mode per scope, both ways;
  planned to become @optimizeFor. ^f60
  > Sets whether runtime safety checks are enabled for the scope that contains the function call.
  > it is planned to replace `@setRuntimeSafety` with `@optimizeFor`
- [zig/perf] @setFloatMode(.optimized) is -ffast-math for a scope; strict IEEE is default. ^f61
  > This is equivalent to `-ffast-math` in GCC.
- [zig/perf] @call modifiers force or forbid inlining and tail calls, failing to compile if
  impossible; @branchHint must be the first statement of a branch or function. ^f62
  > Guarantees that the call will be inlined at the callsite.
  > This function is only valid as the first statement in a control flow branch, or the first statement in a function.

### Build modes and illegal behaviour

- [toolchain] [zig/safety] 0.17 optimise modes are debug, safe, fast, small (`-Odebug`
  etc.); `builtin.mode` is deprecated for `builtin.optimize`. ^f63
  > pub const optimize: std.lang.Optimize = .debug;
  > Deprecated, to be removed after 0.18.0
  > Optimizations on and safety on
- [zig/safety] Mode traits: debug fast compile, safety on; safe medium speed, safety on; fast
  safety off; small safety off, small binary; all but debug reproducible. ^f64
  > Medium runtime performance
  > Safety checks disabled
  > No reproducible build requirement
- [zig/perf] -fsingle-threaded makes threadlocals plain globals and std.Mutex a no-op. ^f65
  > For example `std.Mutex` becomes an empty data structure and all of its functions become no-ops.
- [zig/safety] Illegal behaviour: compile error if caught at comptime; otherwise safety-checked
  (panics) or unchecked (anything can happen, like C UB). ^f66
  > If Illegal Behavior is detected at compile-time, Zig emits a compile error and refuses to continue.
  > If Unchecked Illegal Behavior is invoked at runtime, anything can happen
  > Unchecked Illegal Behavior still always results in a compile error if evaluated at comptime
- [zig/safety] Most IB is checked, but fast and small turn checks off, and then checked IB
  becomes unchecked. ^f67
  > Most Illegal Behavior is safety-checked. However, to facilitate optimizations, safety checks are disabled by default in the fast and small optimization modes.
  > When safety checks are disabled, Safety-Checked Illegal Behavior behaves like Unchecked Illegal Behavior; that is, any behavior may result from invoking it.
- [zig/safety] (inferred) The safety-checked list, one section each: reaching unreachable, index
  out of bounds, negative to unsigned cast, cast truncates data, integer overflow (+ - neg *
  / and the @div builtins), exact shift overflow (left, right), division and remainder by
  zero, exact division remainder, unwrapping null, unwrapping an error, invalid error code,
  invalid enum cast, invalid error set cast, incorrect pointer alignment, wrong union field
  access, out-of-bounds float to int, pointer cast to null. Sample panic texts: ^f68
  > panic: index out of bounds: index 5, len 5
  > panic: integer does not fit in destination type
  > panic: access of union field 'float' while field 'int' is active
- [zig/safety] Bare-union field checks don't exist for `extern` or `packed` unions; switch the
  active field by assigning the whole union (with `undefined` payload if needed). ^f69
  > This safety is not available for `extern` or `packed` unions.
  > To change the active field of a union, assign the entire union
- [zig/safety] [zig/memory] Unchecked IB the doc names: dangling pointers into a returned
  stack frame, missing asm clobbers, @fieldParentPtr on the wrong field. ^f70
  > Once a function returns, any Pointers to variables in the function's stack frame become invalid references, and dereferencing them becomes unchecked Illegal Behavior.
  > Failure to declare the full set of clobbers for a given inline assembly expression is unchecked Illegal Behavior.
- [zig/safety] `unreachable` panics in debug, safe and zig test; in fast and small it is an
  optimiser assumption. ^f71
  > Emits a panic in debug and safe mode, or when using zig test.
  > Does not emit a panic in fast and small mode.
- [zig/safety] (inferred) The unwrap-null and unwrap-error sections give the fix as testing with
  `if (x) |v|` instead of assuming, so `.?` and `catch unreachable` are assertions to use
  only where the invariant really holds. ^f72
  > One way to avoid this crash is to test for null instead of assuming non-null

### Memory

- [zig/memory] [zig/api] No default allocator: functions that allocate take an `Allocator`. ^f73
  > However, by convention, there is no default allocator in Zig. Instead, functions which need to allocate accept an `Allocator` parameter.
- [zig/memory] [zig/api] Allocator choice 1: libraries accept an Allocator and let the user
  decide. ^f74
  > Are you making a library? In this case, best to accept an `Allocator` as a parameter and allow your library's users to decide what allocator to use.
- [zig/memory] Allocator choice 2-3: linking libc, `std.heap.c_allocator`; bound known at
  comptime, `FixedBufferAllocator`. ^f75
  > Are you linking libc? In this case, `std.heap.c_allocator` is likely the right choice, at least for your main allocator.
  > Is the maximum number of bytes that you will need bounded by a number known at comptime? In this case, use `std.heap.FixedBufferAllocator`.
- [zig/memory] Allocator choice 4: a run-to-completion CLI uses one arena over page_allocator,
  freed once with `arena.deinit()`. ^f76
  > When using this kind of allocator, there is no need to free anything manually. Everything gets freed at once with the call to `arena.deinit()`.
- [zig/memory] [zig/perf] Allocator choice 5: cyclical work (frame, request) uses an arena per
  cycle, or a FixedBufferAllocator if the cycle has a memory bound. ^f77
  > If the allocations can all be freed at once, at the end of the cycle, for example once the video game frame has been fully rendered, or the web server request has been served, then `std.heap.ArenaAllocator` is a great candidate.
  > Note also that if an upper bound of memory can be established, then `std.heap.FixedBufferAllocator` can be used as a further optimization.
- [zig/memory] [zig/test] Allocator choice 6-7: tests use `std.testing.allocator` (leak
  detection), and `std.testing.FailingAllocator` to test OOM handling. ^f78
  > Are you writing a test, and you want to make sure `error.OutOfMemory` is handled correctly? In this case, use `std.testing.FailingAllocator`.
  > which will also perform basic leak detection
- [zig/memory] Allocator choice 8-9: otherwise a general purpose allocator, set up once in main
  and passed down: DebugAllocator in debug, `smp_allocator` in fast. Checked, not there: the
  name GeneralPurposeAllocator. ^f79
  > Generally, you will set up exactly one in your main function, and then pass it or sub-allocators around to various parts of your application.
  > If you are compiling in fast mode, `std.heap.smp_allocator` is a solid choice for a general purpose allocator.
- [zig/memory] Where bytes live: string literals and comptime-known consts in constant data;
  function `var`s on the stack; container-level `var`s in global data; allocations where the
  allocator puts them. ^f80
  > String literals such as `"hello"` are in the global constant data section.
  > `var` declarations inside functions are stored in the function's stack frame.
  > The location of memory allocated with `allocator.alloc` or `allocator.create` is determined by the allocator's implementation.
- [zig/memory] [zig/api] Document ownership and lifetime of every returned pointer ("caller
  owns the returned memory"); e.g. ArrayList `.items` dies on the next resize. ^f81
  > In general, when a function returns a pointer, the documentation for the function should explain who owns the pointer.
  > the `std.ArrayList(T).items` slice has a lifetime that remains valid until the next time the list is resized, such as by appending new elements.
  > Ownership determines whose responsibility it is to free the memory referenced by the pointer, and lifetime determines the point at which the memory becomes inaccessible
- [zig/memory] [zig/safety] Recursion is unbounded memory, and there is no stack overflow
  protection yet. ^f82
  > Recursion is a fundamental tool in modeling software. However it has an often-overlooked problem: unbounded memory allocation.
  > Although Zig code is not yet protected from stack overflow

### Compile variables and compilation model

- [toolchain] [zig/build] `builtin.os`, `builtin.cpu`, `builtin.abi`, `builtin.object_format`
  are deprecated (removed in 0.18) for `builtin.target.*`. ^f83
  > Deprecated; to be removed in 0.18.0. Use `target.os` instead.
- [zig/style] [zig/api] A file with top-level fields is a type: TitleCase file name and
  `const Name = @This();` at the top. ^f84
  > Because this file contains fields, it is a type which is intended to be instantiated, and so is named in TitleCase instead of snake_case by convention.
  > In files with fields, it is quite common to name the type here, so it can be easily referenced by other declarations in this file.
- [zig/test] [zig/build] Only the root module's tests run, and only from files that are
  discovered; reference test files with `test { _ = @import("tests.zig"); }`. ^f85
  > and the module the type is within is the root module of the compilation, then all `test` declarations within it are also analyzed.
  > a common strategy for this is to use `@import` within a `comptime` or `test` block
- [zig/api] Root-file hooks: `std_options: std.Options` (e.g. logFn, segfault handler) and
  `panic` (e.g. `std.debug.FullPanic(myPanic)` keeps formatted safety panics). ^f86
  > If present, this declaration is expected to be a struct of type `std.Options`, and allows the program to customize some standard library functionality, such as the `std.log` implementation.
  > Overriding how the panic handler actually outputs messages, but keeping the formatted safety panics which are enabled by default, can be easily achieved with `std.debug.FullPanic`
- [zig/api] [toolchain] 0.17 main can take `std.process.Init`, which carries args, an arena
  and preopens. ^f87
  > pub fn main(init: std.process.Init) !void {
  > const args = try init.minimal.args.toSlice(init.arena.allocator());
- [zig/build] The langref defers build-system docs to an external page; its examples use
  `root_module = b.createModule(...)`, `b.addLibrary(.{ .linkage = .dynamic })` and
  `exe.root_module.addCSourceFile` / `linkLibrary`. ^f88
  > For the time being, the build system documentation is hosted externally
  > exe.root_module.addCSourceFile(.{ .file = b.path("test.c"), .flags = &.{"-std=c99"} });
- [zig/build] Without `-target` the binary targets the host CPU and is not portable. ^f89
  > When no target option is provided to the compiler, the default choice is to target the host computer

### C and WebAssembly

- [zig/build] Avoid C pointers `[*c]T` outside generated bindings; use `*T`/`[*]T`/optional. ^f90
  > This type is to be avoided whenever possible. The only valid reason for using a C pointer is in auto-generated code from translating C code.
- [zig/build] translate-c must get the same `-target` and cflags as the real build, or ABI
  mismatches follow. ^f91
  > you must use the same -target triple that you will use when compiling the translated code
- [zig/build] Untranslatable C demotes to opaque, extern or @compileError, and only errors if
  used (lazy analysis). ^f92
  > Demotion comes in three varieties - opaque, extern, and @compileError.
  > untranslatable entities will not cause a compile error in your code unless you actually use them
- [zig/build] [toolchain] Checked, not there: the 0.17 C chapter has no @cImport section;
  C headers come in through the `zig translate-c` CLI. C `void` is `anyopaque`. ^f93
  > Zig's C translation capability is available as a CLI tool via zig translate-c.
  > To interop with the C `void` type, use `anyopaque`.
- [zig/build] Exporting a C ABI library is a primary use case: `export fn`, build-lib, mixed
  object files. ^f94
  > One of the primary use cases for Zig is exporting a library with the C ABI for other programming languages to call into.
- [zig/build] Browser/node wasm: freestanding executable, `-fno-entry --export=name`. ^f95
  > For host environments like the web browser and nodejs, build as an executable using the freestanding OS target.

### Style Guide

- [zig/style] The Style Guide is the official reference style, not compiler-enforced. ^f96
  > These coding conventions are not enforced by the compiler, but they are shipped in this documentation along with the compiler in order to provide a point of reference
- [zig/style] Keep Value, Data, Context, Manager, State, utils, misc and initials out of type
  names: they apply to every type and say nothing. ^f97
  > Everything is a value, all types are data, everything is context, all logic manages state. Nothing is communicated by using a word that applies to all types.
- [zig/style] utils/misc modules are a categorisation failure: put the declarations at the
  root of the module that needs them. ^f98
  > is a failure to categorize, or more commonly, overcategorization. Such declarations can live at the root of a module that needs them with no namespace needed.
- [zig/style] Name against the fully qualified path: `json.JsonValue` should be `json.Value`;
  file names count as namespace segments. ^f99
  > Choose names based on the fully-qualified namespace, and avoid redundant name segments.
  > remember that files also act as part of the fully-qualified namespace
- [zig/style] No underscore prefixes: there are no private fields; name and document fields
  for their invariants, and note semver exceptions in doc comments. ^f100
  > In Zig, there are no private fields, and this style guide recommends against pretending otherwise.
  > fields should be named carefully based on their semantics and documentation should indicate how to use fields without violating data invariants
- [zig/style] Name collisions: longer names at outer scopes, shorter at inner; keyword clashes
  use `@"name"`; reflection should rely on types, not name conventions. ^f101
  > this guide recommends more verbose names at outer scopes and more abbreviated names at inner scopes
  > it is less error prone and more maintainable to use the type system than to make field names meaningful
- [zig/style] Whitespace: 4 spaces, braces on the same line, lists over 2 items one per line
  with a trailing comma, aim for 100 columns. ^f102
  > If a list of things is longer than 2, put each item on its own line and exercise the ability to put an extra comma at the end.
  > Line length: aim for 100; use common sense.
- [zig/style] Names: namespaces (0-field structs) snake_case; types and type-returning
  functions TitleCase; other callables camelCase; everything else snake_case. ^f103
  > If `x` is callable, and `x`'s return type is `type`, then `x` should be `TitleCase`.
  > If `x` is a `struct` with 0 fields and is never meant to be instantiated then `x` is considered to be a namespace and should be `snake_case`.
- [zig/style] Acronyms are ordinary words, even two-letter ones: `XmlParser`, `readU32Be`. ^f104
  > Even acronyms that are only 2 letters long are subject to these conventions.
- [zig/style] Files with top-level fields TitleCase, others snake_case; directories snake_case;
  established names like ENOENT may stay. ^f105
  > If the file (implicitly a struct) has top level fields, it should be named like any other struct with fields using `TitleCase`. Otherwise, it should use `snake_case`. Directory names should be `snake_case`.
  > if there is an established convention such as `ENOENT`, follow the established convention
- [zig/style] Doc comments: drop what the name says; duplicating text across similar functions
  is fine (tools show it). ^f106
  > Omit any information that is redundant based on the name of the thing being documented.
  > Duplicating information onto multiple similar functions is encouraged because it helps IDEs and other tools provide better help text.
- [zig/style] [zig/safety] Doc vocabulary: "assume" for invariants whose violation is unchecked
  IB, "assert" for safety-checked IB. ^f107
  > Use the word assume to indicate invariants that cause unchecked Illegal Behavior when violated.
  > Use the word assert to indicate invariants that cause safety-checked Illegal Behavior when violated.
- [zig/style] Source is UTF-8, LF line endings including the last line, no BOM, no CR or other
  control characters; zig fmt can repair encodings. ^f108
  > This byte value terminates every line of Zig source code, including last line of the file.
  > tooling such as zig fmt provides convenience functionality to convert invalid source encodings to valid source encodings

### Other

- [toolchain] Async is still absent; the plan is a lower-level primitive under I/O. ^f109
  > Async functions regressed with the release of 0.11.0. The current plan is to reintroduce them as a lower level primitive that powers I/O implementations.
- [zig/build] Inline asm uses AT&T syntax on x86 and its constraints are unstable. ^f110
  > For x86 and x86\_64 targets, the syntax is AT&T syntax, rather than the more popular Intel syntax.
- [zig/perf] Checked, not there: the Atomics chapter is only TODOs and see-also links. ^f111
  > TODO: builtin atomic memory ordering enum
