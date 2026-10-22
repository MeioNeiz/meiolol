---
title: Zig 0.15.1 release notes
url: https://ziglang.org/download/0.15.1/release-notes.html
kind: docs
commit: 
for: [zig-good-practice, zig-style, zig-memory, zig-api-design, zig-errors-safety, zig-comptime, zig-perf, zig-build, zig-testing]
looked: 2026-10-22
depth: docs (language changes, standard library, build system, compiler, fuzzer, roadmap)
relevance: high
grade: A/strong
description: Official release notes for Zig 0.15.1 (2025-08): usingnamespace and async removed, Writergate (std.Io.Writer/Reader), {f} format, ArrayList unmanaged by default, BoundedArray removed
---
# Zig 0.15.1 release notes

Why: 0.15 is the biggest idiom break before 0.16 (I/O, formatting, containers); the guide
needs the replacements and the reasons the Zig team gave.

## Assessment

- Evidence: A. Canonical reference from the Zig team, with upgrade diffs.
- Reasoning: strong. usingnamespace, Writergate, unmanaged ArrayList and BoundedArray
  each get a stated cost-benefit argument and per-use-case migration.
- Interests: none beyond promoting the release; Writergate is openly one-sided ("worth it").
- Weigh: the 0.15 stdout example (`std.fs.File.stdout().writer(&buf)`) changed again in
  0.16 (std.Io, Juicy Main); the reasoning about buffers in the interface holds.

## Findings

- [zig/style] usingnamespace removed: it hid where a declaration is defined, from people
  and tools (Autodoc); without it every identifier traces back trivially. ^f1
  > This keyword added distance between the "expected" definition of a declaration and its "actual" definition.
  > By eliminating this feature, all identifiers can be trivially traced back to where they are imported - by humans and machines alike.
- [zig/style] It also encouraged poor namespacing: a separate file usually deserves its own
  namespace. ^f2
  > **namespacing is good, actually**
  > Finally, removal of this feature makes Incremental Compilation fundamentally simpler.
- [zig/comptime] Conditional inclusion: declare unconditionally (lazy analysis), or make the
  value a @compileError per target; for feature detection use `{}` and test
  `@TypeOf(x) == void`, less prone to typos than @hasDecl. ^f3
  > usually, you can just include the declaration unconditionally. Zig's lazy compilation means that it will not be analyzed unless referenced
  > a better approach—less prone to typos and bitrotting—is to conditionally initialize the declaration to some "sentinel" value which can be detected.
- [zig/comptime] Implementation switching: make each definition a switch on target, e.g.
  `pub const init = switch (target) { .windows => initWindows, else => initOther };`. ^f4
  > The alternative to this is simpler and results in better code: make the definition itself a conditional.
- [zig/api] Mixins: use a zero-bit field plus @fieldParentPtr (`foo.counter.increment()`);
  the notes add that mixins are rarely needed. ^f5
  > This can be achieved using a zero-bit field and `@fieldParentPtr`.
  > this is a demonstration that the need for mixins is relatively rare.
- [toolchain] async/await keywords and @frameSize removed; async moves to the std as part of
  the Io interface. ^f6
  > it is settled that there will not be async/await keywords in the language. Instead, they will be in the Standard Library as part of the Io Interface.
- [zig/style] Switch on non-exhaustive enums can mix named tags with `_`, and have both
  `else` (named) and `_` (unnamed). ^f7
  > Switching on non-exhaustive enums now allows mixing explicit tags with the `_` prong
- [zig/safety] Arithmetic on undefined is illegal behaviour (compile error at comptime)
  for any operator that can trigger IB; best practice: never operate on undefined. ^f8
  > Generally, it is always best practice to avoid any operation on `undefined`.
- [zig/safety] Lossy comptime int-to-float coercion is a compile error; write a float
  literal to opt in to rounding. ^f9
  > The solution is typically just to change an integer literal to a floating-point literal, thereby opting in to floating-point rounding behavior
- [zig/safety] @ptrCast can turn a single-item pointer into a byte slice; planned to move to
  a safer @memCast. ^f10
  > it is planned to move this functionality from `@ptrCast` to a new `@memCast` builtin
- [zig/api] Writergate: std.io readers and writers deprecated for non-generic
  std.Io.Reader/Writer with the buffer in the interface; hot paths work on the buffer and
  the vtable is only called when it is full. ^f11
  > the buffer is **in the interface, not the implementation**
  > all of the interface functions have a concrete hot path operating on the buffer, and only make vtable calls when the buffer is full.
- [zig/api] Motive: the old generic interface poisoned structs and forced `anytype` on every
  function; the concrete one keeps APIs off raw sockets and files (http.Server no longer
  depends on std.net). ^f12
  > The old interface was generic, poisoning structs that contain them and forcing all functions to be generic as well with `anytype`. The new interface is concrete.
  > the concreteness removes temptation to make APIs operate directly on networking streams, file handles, or memory buffers, giving us a more reusable body of code.
- [zig/errors] Motive: old streams passed errors through, as useful as anyerror; the new
  one defines precise, actionable error sets per function (e.g. ReadFailed, then ask the
  implementation for diagnostics). ^f13
  > The new interface carefully defines precise error sets for each function with actionable meaning.
  > error.ReadFailed, // caller can check reader implementation for diagnostics
- [zig/perf] Buffer in the interface is more optimiser friendly, especially in Debug; vectors,
  splat and fd-to-fd send propagate through reader/writer graphs. ^f14
  > This is more optimizer friendly, particularly for debug mode.
  > The stream user provides the buffer, but the stream implementation decides the minimum buffer size.
- [zig/api] File.Reader/File.Writer memoise size and position and read positionally, so code
  that seeked on handles should use them instead. ^f15
  > Most code that previously was calling seek functions on a file handle should be updated to operate on this API instead
- [zig/api] Use buffering and flush: stdout writer over a caller buffer, `&w.interface`,
  then `flush()`; consider a global stdout buffer. ^f16
  > Please use buffering! And **don't forget to flush**!
  > Consider making your stdout buffer global.
- [zig/perf] CountingWriter deleted: use Writer.Discarding, Allocating or fixed; don't add a
  stream node just to count, it disrupts buffering. ^f17
  > try not to create an entire node in the stream graph solely for counting bytes. It's very disruptive to optimal buffering.
- [zig/api] `{f}` is required to call a format method (`{any}` skips it), so adding or
  removing a format method can no longer silently change `{}` output. ^f18
  > Introducing a `format` method to a struct caused a bug if there was formatting code somewhere that prints with {} and then starts rendering differently.
  > Using `{f}` always tries to call a `format` method, causing a compile error if none exists.
- [zig/api] Format methods are `fn format(self, w: *std.Io.Writer) std.Io.Writer.Error!void`;
  variants via separate methods, std.fmt.alt or a returned struct. ^f19
  > pub fn format(this: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void { ... }
- [zig/api] New specifiers: {t} for @tagName/@errorName, {b64}; fmt helpers became
  specifiers ({x}, {B}, {D}). ^f20
  > {t} is shorthand for `@tagName()` and `@errorName()`
- [zig/memory] Linked lists de-genericised: embed std.DoublyLinkedList.Node and use
  @fieldParentPtr; intrusive is preferred, and if not, a list is probably wrong. ^f21
  > If you're not already doing that, there's a good chance linked list is the wrong data structure.
- [zig/memory] ArrayList is unmanaged by default (managed is array_list.Managed, to be
  removed): no allocator field is the null hypothesis; costs of the field outweigh the
  wrong-allocator protection, which safety checks catch anyway. ^f22
  > Having an extra field is more complicated than not having an extra field, so not having it is the null hypothesis.
  > inability to statically initialize
  > given that the correct allocator is always handy, and incorrect use can be trivially safety-checked
- [zig/memory] LinearFifo and RingBuffer removed; a comptime enum choosing buffer ownership
  made three data structures in one; ask first whether Io.Reader/Writer is what you need. ^f23
  > Each of these different buffer management strategies describes a fundamentally different data structure.
  > first ask yourself if what you really need is `std.Io.Reader` or `std.Io.Writer`.
- [zig/memory] BoundedArray removed. Arbitrary limit: don't guess, take a caller slice or
  allocate; stack buffer: ArrayList initBuffer plus *Bounded methods. ^f24
  > Don't guess. Don't make that choice for the calling code. Accept a buffer as a slice as an input, or use dynamic allocation.
  > Is it type safety around a stack buffer? Just use ArrayListUnmanaged. It's fine.
- [zig/perf] Copyable growable arrays waste time copying undefined memory and bloat
  generic code. ^f25
  > This wastes time copying undefined memory all over the place and causes unnecessary generic code bloat.
- [zig/perf] SeekableStream, BitReader and BitWriter deleted: use concrete types; bit
  reading tied to the stream keeps hot loops optimisable. ^f26
  > Bit reading should not be abstracted at this layer; it just makes your hot loop harder to optimize.
- [zig/build] Deprecated root_source_file/target/optimize fields on addExecutable removed;
  root_module is required. ^f27
  > Zig 0.15.x removes the deprecated fields.
- [zig/build] The team's advice for large projects: `--watch -fincremental` with a
  `-Dno-bin` option for compile errors. ^f28
  > **If you have a large project that does not compile instantly, you should be taking advantage of `--watch` combined with `-fincremental` and `-Dno-bin` for compile errors.**
- [zig/build] `--time-report` in the build web UI shows which files and declarations are
  slow to analyse and compile. ^f29
  > it can be very useful for determining parts of your code which are needlessly slowing down compilation
- [zig/build] Self-hosted x86_64 backend is the Debug default (about 5x faster compiles,
  slower machine code; `-fllvm` or use_llvm to opt out). ^f30
  > Compilation time is _significantly_ improved—around a 5x decrease compared to LLVM in most cases.
- [zig/safety] UBSan mode per module: `-fsanitize-c=trap|full`; build API sanitize_c is an
  enum. ^f31
  > With `trap`, trap instructions are inserted instead, resulting in `SIGILL` when undefined behavior is triggered, but smaller code size.
- [zig/build] `zig init` template shows a reusable module plus an executable; the old static
  library template misled newcomers. ^f32
  > The old template included code for generating a static library of a Zig module, which caused some newcomers to mistakenly think that this was the preferred way of sharing reusable Zig code.
- [zig/api] Roadmap: everything that can block moves behind a std.Io instance, passed like
  an Allocator, so packages are agnostic to the concurrency model. ^f33
  > All code that performs I/O will need access to an `Io` instance, similar to how all code that allocates memory needs access to an `Allocator` instance.

## Read

- Language Changes, Standard Library, Build System, Compiler, Fuzzer, Roadmap: fully

## Not read

- Target support, linker, toolchain; the Writergate talk ("Don't Forget To Flush")
  is linked but not watched
