---
title: Zig 0.17.0 language reference, part A (Introduction to Functions)
url: https://ziglang.org/documentation/0.17.0/
kind: docs
commit:
for: [zig-good-practice, zig-style, zig-memory, zig-errors-safety, zig-comptime, zig-api-design, zig-testing, zig-perf]
looked: 2026-10-22
depth: docs (raw lines 366-6906: Introduction to Functions, every section read)
relevance: high
grade: A/fair
description: Official Zig 0.17.0 langref, first half (values, tests, variables, numbers, operators, arrays, vectors, pointers, slices, struct, enum, union, opaque, blocks, control flow, defer, unreachable, noreturn, functions)
---
# Zig 0.17.0 language reference, part A (Introduction to Functions)

Why: what the language's own reference recommends or warns against, which construct
exists for what purpose, and the idioms its (compiled and tested) examples use, as
ground truth for a guide on good Zig 0.17. Raw is a copy of `zig-langref-017.md`; part B
(Errors onwards, Style Guide) is [[zig-langref-017-b]].

## Assessment

- Evidence: A. The canonical reference by the language's authors, versioned per release;
  its examples are built and run by the compiler test suite (^f3), so code shown is valid
  0.17 code.
- Reasoning: fair. Mostly describes what constructs do; explains WHY in a few places
  (const over var, slices over pointers, default field values, slice by length, labelled
  switch dispatch, inline not a hint, inline loops). Few costs or alternatives beyond
  those.
- Interests: none beyond the language itself.
- Weigh: trust for semantics and the stated recommendations. It is a reference, not a
  style guide: idioms shown in examples (naming `gpa`, `.empty`, `initBuffer`) are
  signals of current std practice, not rules. Some TODOs remain (^f56).

## Findings

### Intent and philosophy

- [zig] Zig's goals include maintainability: code should state intent precisely to the
  compiler and to readers. Introduction ^f1
  > Precisely communicate intent to the compiler and other programmers. The language imposes a low overhead to reading code and is resilient to changing requirements and environments.
- [zig/memory] Robustness is defined to include out of memory: OOM is an edge case code
  must handle correctly, not ignore. Introduction ^f2
  > Behavior is correct even for edge cases such as out of memory.
- [zig/test] Every langref code sample is compiled and tested in Zig's own test suite, so
  its examples are current 0.17 idiom. Introduction ^f3
  > The code samples in this document are compiled and tested as part of the main test suite of Zig.
- [zig/style] No operator overloading: an operator always means one of the built-in
  operations, so reading code needs no lookup. Operators ^f45
  > There is no operator overloading. When you see an operator in Zig, you know that it is doing something from this table, and nothing else.

### Hello World and std.Io (0.17)

- [zig/api] [toolchain] 0.17 Hello World: `main` takes `std.process.Init` and passes
  `init.io` to the write; I/O needs an explicit `Io`. Hello World ^f4
  > pub fn main(init: std.process.Init) !void {
  > try std.Io.File.stdout().writeStreamingAll(init.io, "Hello, World!\n");
- [zig/errors] For diagnostics, write to stderr with `std.debug.print`, where a failed
  write does not matter; `main` can then be `void`. Hello World ^f5
  > Most of the time, it is more appropriate to write to stderr rather than stdout, and whether or not the message is successfully written to the stream is irrelevant.
  > In this case, the `!` may be omitted from the return type of `main` because no errors are returned from the function.

### Comments and doc comments

- [zig/style] Only line comments exist, by design: every line tokenises on its own.
  Comments ^f6
  > There are no multiline comments. Zig has the property that each line of code can be tokenized independently.
- [zig/style] `///` documents whatever follows (declarations and fields); misplaced doc
  comments are compile errors, so docs can't silently detach. Doc Comments ^f7
  > A doc comment is one that begins with exactly three slashes
  > it is a compile error to have a doc comment in an unexpected place, such as in the middle of an expression, or just before a non-doc comment.
  > unattached documentation comment
- [zig/style] The doc's example: `///` on the type, each field and each pub fn; a plain
  `//` trailing comment for an implementation note (why the field is signed). Doc
  Comments ^f9
  > /// The number of seconds since the epoch (this is also a doc comment).
  > seconds: i64, // signed so we can represent pre-1970 (not a doc comment)
- [zig/style] `//!` documents the file's (or namespace's) type and must come first;
  inside non-file namespaces it is currently ignored by doc generation, so put module
  docs at the top of the file. Top-Level Doc Comments ^f8
  > It is a compile error if a top-level doc comment is not placed at the start of a namespace, before any expressions.
  > when producing the package documentation, these comments are ignored.

### Namespaces, identifiers, declarations

- [zig/style] [toolchain] 0.17 calls struct, enum, union and opaque bodies namespaces
  (section "Namespace", "Namespace Level Variables"); test names in the examples still
  say "container", the older term. Namespace, Variables ^f11
  > Every Zig source file is implicitly a struct, with the keyword struct and curly braces omitted.
  > test "container level variables" {
- [zig/style] A namespace's braces are not a block: it holds declarations, not
  statements. Namespace ^f12
  > Although namespaces use curly braces to surround their definition, they should not be confused with
- [zig/style] Top-level declarations are order-independent (the example puts `print`
  before the `std` import it uses). Values ^f14
  > // Top-level declarations are order-independent:
- [zig/api] `@"..."` names exist for names that are keywords or invalid identifiers,
  mainly for linking with external libraries. String Identifier Syntax ^f13
  > If a name that does not fit these requirements is needed, such as for linking with external libraries, the `@""` syntax may be used.
- [zig/style] No shadowing, anywhere: so an identifier means one thing throughout its
  scope; reusing a name in sibling scopes is fine. Variables, Shadowing ^f35
  > Because of this, when you read Zig code you can always rely on an identifier to consistently mean the same thing within the scope it is defined.
  > local variable shadows declaration of 'pi'

### Values, strings, assignment, undefined

- [zig/style] Prefer `const` over `var`: less work for readers and the compiler, more
  optimisation. Variables ^f18
  > It is generally preferable to use `const` rather than `var` when declaring a variable. This causes less work for both humans and computers to do when reading code, and creates more optimization opportunities.
- [zig/memory] `const` covers only the bytes the name addresses; pointee const-ness is
  part of the pointer type. Assignment ^f19
  > `const` applies to all of the bytes that the identifier immediately addresses.
- [zig/style] Strings are byte slices by convention, UTF-8; literals are
  `*const [N:0]u8` and coerce to `[]const u8` and `[:0]const u8`. Slices, String
  Literals ^f16
  > // Zig has no concept of strings. String literals are const pointers
  > // that are "strings" are expected to be UTF-8 encoded slices of u8.
  > The type of string literals encodes both the length, and the fact that they are null-terminated
  > Generally, you can use UTF-8 and not worry about whether something is a
- [zig/style] Multiline string literals (`\\` lines) take no escapes; good for embedded
  text and code. Multiline String Literals ^f17
  > Multiline string literals have no escapes and can span across multiple lines.
- [zig/safety] Every variable needs an initialiser; leaving it uninitialised must be
  written as `= undefined`, which means "a bug if read". Assignment, undefined ^f20
  > expected '=', found ';'
  > Translated into English, `undefined` means "Not a meaningful value. Using this value would be a bug. The value will be unused, or overwritten before being used."
- [zig/safety] Once coerced, `undefined` can't be detected; the 0xaa fill in Debug and
  ReleaseSafe is a debugging aid, not semantics code may rely on. undefined ^f21
  > Once this happens, it is no longer possible to detect that the value is `undefined`.
  > This is to catch bugs early, and to help detect use of undefined memory in a debugger. However, this behavior is only an implementation feature, not a language semantic, so it is not guaranteed to be observable to code.
- [zig/style] Destructuring splits tuples, arrays and vectors; the left side may mix new
  `const`/`var` declarations and existing lvalues, `_` discards; block scope only.
  Destructuring ^f23
  > x, var y : u32, const z = tuple;
  > // You can use _ to throw away unwanted values.
  > A destructuring expression may only appear within a block (i.e. not at
- [zig/api] Multiple return values: return an anonymous tuple type and destructure at the
  call site; same for a labelled block yielding two values. Destructuring Tuples ^f24
  > fn divmod(numerator: u32, denominator: u32) struct { u32, u32 } {
  > const div, const mod = divmod(10, 3);
  > Tuple destructuring is helpful for returning multiple values from a block
  > break :blk .{ min, max };
- [zig/style] Destructuring makes swizzles readable. Destructuring Arrays ^f25
  > // readable swizzling by destructuring
  > const r, const g, const b, const a = rgba;

### Zig Test

- [zig/test] Prefer the specific `expectEqual` over `expect(a == b)`: better failure
  messages. Zig Test ^f26
  > However, in most cases it is more convenient to use a more specific function like `expectEqual`.
  > This gives you much clearer and more helpful error messages when a test fails.
- [zig/test] `expectEqual(expected, actual)`: expected first, and actual is coerced to
  expected's type (so a literal expected needs care with types). Testing Namespace ^f27
  > The first argument to `expectEqual` is the known, expected, result.
  > The actual's type is casted to the type of expected.
- [zig/test] Doctests: `test name {}` with an identifier documents that declaration and
  shows in generated docs; should be a focused usage example, beside (not instead of) a
  doc comment. Doctests ^f28
  > // A test name can also be written using an identifier.
  > An effective doctest should be self-contained and focused on the declaration being tested, answering questions a new user might have about its interface or intended usage, while avoiding unnecessary or confusing details.
  > A doctest is not a substitute for a doc comment, but rather a supplement and companion providing a testable, code-driven example, verified by zig test.
- [zig/test] Unnamed `test {}` blocks always run and ignore the test filter (the usual
  home for `refAllDecls`-style imports). Test Declarations ^f29
  > Non-named test blocks always run during test builds and are exempt from
- [zig/test] Tests return `anyerror!void`, are dropped from non-test builds, and can sit
  in the same file as the code or a separate file. Test Declarations ^f30
  > When a Zig source file is not built using the zig test tool, the test declarations are omitted from the build.
  > Test declarations can be written in the same file, where code under test is written, or in a separate Zig source file.
- [zig/test] Skip at runtime by returning `error.SkipZigTest`. Skip Tests ^f31
  > To programmatically skip a test, make a `test` return the error `error.SkipZigTest`
- [zig/test] [zig/memory] `std.testing.allocator` makes the runner report leaks and fail
  the run. The 0.17 example: unmanaged `ArrayList` initialised `.empty`, allocator named
  `gpa` passed per call, leak report from `SafeAllocator` (new in 0.17). Report Memory
  Leaks ^f32
  > the default test runner will report any leaks that are found from using the testing allocator
  > var list: std.ArrayList(u21) = .empty;
  > // missing `defer list.deinit(gpa);`
  > try list.append(gpa, '☔');
  > 1 tests leaked memory.
- [zig/test] `@import("builtin").is_test` detects a test build. Detecting Test Build ^f33
  > return builtin.is_test;

### Variables: globals, statics, thread-locals, comptime

- [zig/comptime] Namespace-level variables have global lifetime, are order-independent
  and lazily analysed (unused ones are never compiled); initialisers run at comptime.
  Namespace Level Variables ^f36
  > have global lifetime and are order-independent and lazily analyzed.
- [zig/style] A function-local `const S = struct { var x ... }` gives a static local
  (global lifetime, local name). Locally-Scoped Global Variables ^f37
  > It is also possible to have local variables with global lifetime by using
  > const S = struct {
- [zig/perf] `threadlocal var` gives each thread its own copy; it may not be const and is
  a plain global in single-threaded builds. Thread Local Variables ^f38
  > threadlocal var x: i32 = 1234;
  > Thread local variables may not be `const`.
- [zig/comptime] `comptime var` loads and stores happen during analysis; conditions on it
  are evaluated statically, so dead branches with `@compileError` never fire. Local
  Variables ^f39
  > and all loads and stores of the variable to happen during semantic analysis of the program, rather than at runtime.
  > // This compile error never triggers because y is a comptime variable,

### Integers, floats, operators

- [zig/safety] Runtime integers can overflow and divide by zero (illegal behaviour);
  wrapping (`+%`) and saturating (`+|`) operators state the intent instead. Runtime
  Integer Values ^f41
  > Alternative operators are provided for wrapping and saturating arithmetic on all targets.
  > `+%` and `-%` perform wrapping arithmetic while `+|` and `-|` perform saturating arithmetic.
- [zig/perf] Arbitrary bit-width integers (`u3`, `i7`) up to 65535 bits; signed are two's
  complement. Integers ^f42
  > The maximum allowed bit-width of an integer type is `65535`.
- [zig/safety] [toolchain] `/` on signed ints needs comptime-known positive operands;
  otherwise pick the rounding explicitly with `@divTrunc`, `@divFloor`, `@divCeil` (new
  in 0.17) or `@divExact`; `%` likewise needs `@rem` or `@mod`. Table of Operators ^f43
  > Signed integer operands must be comptime-known and positive. In other cases, use
  > Signed or floating-point operands must be comptime-known and positive.
- [zig/safety] A runtime shift amount must have the log2 type of the shifted operand
  (e.g. `u5` for `u32`), so out-of-range shifts don't type-check. Table of Operators ^f44
  > or have a type with log2 number of bits as
- [zig/errors] `x.?` is `x orelse unreachable`; the right side of `orelse` and `catch`
  may be `noreturn` (`return`, `unreachable`, a panic). Table of Operators ^f46
  > a orelse unreachable
  > If `a` is `null`, returns `b` ("default value"), otherwise returns the unwrapped value of `a`.
- [zig/comptime] `++` needs comptime-known lengths of both sides. Arrays ^f47
  > // array concatenation works if the values are known
- [toolchain] Checked, not there: no `**` array multiplication in the 0.17 operator table
  or precedence list (removed, [[zig-017-release-notes#^f2]]); arrays are filled with
  `@splat`, nested for 2D. Arrays, Multidimensional Arrays ^f48
  > const all_zero: [10]u16 = @splat(0);
  > var more_points: [10]Point = @splat(makePoint(3));
  > const all_zero: [4][5]f32 = @splat(@splat(0));
- [zig/perf] Floats default to strict IEEE mode; `@setFloatMode(.optimized)` relaxes it
  per block (the example changes the result). Floating Point Operations ^f51
  > By default floating point operations use `.strict` mode, but you can switch to `.optimized` mode on a per-block basis
- [zig/style] No literal syntax for NaN or infinity: use `std.math.inf` and
  `std.math.nan`. Float Literals ^f52
  > There is no syntax for NaN, infinity, or negative infinity.

### Arrays and vectors

- [zig/style] Array literals: `[_]T{...}` infers length; with a typed declaration the
  anonymous `.{...}` literal initialises the result location. Arrays ^f50
  > // alternative initialization using result location
  > const alt_message: [5]u8 = .{ 'h', 'e', 'l', 'l', 'o' };
- [zig/comptime] A labelled block computes a complex initial value at comptime (here a
  global array filled in a loop) and `break`s it out. Arrays ^f49
  > var fancy_array = init: {
  > break :init initial_value;
- [zig/perf] `@Vector` maps to SIMD where possible; small power-of-two lengths are
  typical; very long vectors can crash the compiler. Vectors ^f53
  > Operations on vectors shorter than the target machine's native SIMD size will typically compile to single SIMD instructions
  > Note that excessively long vector lengths (e.g. 2^20) may result in compiler crashes on current versions of Zig.
  > It is prohibited to use a math operator on a mixture of scalars (individual numbers) and vectors.
- [zig/perf] Load a vector from a runtime offset by slicing to a comptime length and
  dereferencing: `slice[offset..][0..N].*`. Vectors ^f54
  > // To extract a comptime-known length from a runtime-known offset,
  > const vec3: @Vector(2, f32) = slice[offset..][0..2].*;
- [zig/safety] Arrays and vectors share bit layout (`@bitCast` fine) but vectors have no
  defined byte layout, so `@ptrCast` between them is illegal behaviour. Relationship with
  Arrays ^f55
  > Arrays have well-defined byte layout, but vectors do not, making
- [zig/perf] The doc has an open TODO to recommend `std.MultiArrayList` (struct of
  arrays) in the vectors section. Vectors ^f56
  > TODO consider suggesting std.MultiArrayList

### Pointers and slices

- [zig/memory] Pointer kinds and their purpose: `*T` one item, `[*]T` unknown count
  (indexing, arithmetic), `*[N]T` array pointer with `.len`, `[]T` slice = many-pointer
  plus length. Pointers ^f57
  > `*T` - single-item pointer to exactly one item.
  > `[*]T` - many-item pointer to unknown number of items.
  > is a slice (a fat pointer, which contains a pointer of type `[*]T` and a length).
- [zig/safety] Prefer slices to many-item and sentinel pointers: slices are bounds
  checked. Pointers ^f58
  > Slices have bounds checking and are therefore protected against this kind of Illegal Behavior. This is one reason we prefer slices to pointers.
  > index out of bounds: index 10, len 4
- [zig/safety] For pointer arithmetic, copy to a `[*]T` and increment that; bumping a
  slice's `.ptr` leaves its `len` wrong. Pointers ^f59
  > It's better to assign the pointer to `[*]T` and increment that variable. For example, directly incrementing the pointer from a slice will corrupt it.
- [zig/safety] `@ptrCast` can cause undetectable illegal behaviour and depends on
  endianness; prefer other conversions, e.g. `@bitCast` for value reinterpretation.
  Pointers ^f60
  > Generally, other kinds of type conversions are preferable to `@ptrCast` if possible.
  > // To instead reinterpret the logical bit representation of `bytes` with no
- [zig/safety] `volatile` is for MMIO only; using it for concurrency is a bug (use
  atomics). volatile ^f61
  > If you see code that is using `volatile` for something other than Memory Mapped Input/Output, it is probably a bug.
- [zig/safety] `@alignCast` raises a pointer's alignment with a runtime safety check;
  over-aligned pointers coerce to less-aligned ones, not the reverse. Alignment ^f62
  > If you have a pointer or a slice that has a small alignment, but you know that it actually has a bigger alignment, use
  > a pointer with a larger alignment can be implicitly cast to a pointer with a smaller alignment, but not vice versa.
- [zig/safety] `allowzero` is only for freestanding targets; to represent null use an
  optional pointer. allowzero ^f63
  > This is only ever needed on the freestanding OS target, where the address zero is mappable. If you want to represent null pointers, use
- [zig/api] Sentinel pointers `[*:0]const u8` type C strings, catching a missing
  terminator at compile time. Sentinel-Terminated Pointers ^f64
  > This provides protection against buffer overflow and overreads.
  > pub extern "c" fn printf(format: [*:0]const u8, ...) c_int;
  > destination pointer requires '0' sentinel
- [zig/perf] Slice by length as `s[a..][0..n]`, never `s[a .. a + n]`: one subtraction
  fewer, and with comptime `n` the result is a `*[n]T` with a compile-time length.
  Slicing by Length ^f65
  > The pattern `[a .. a + b]` is always better expressed `[a..][0..b]` because
  > Despite syntactically appearing as twice the work, it is actually one less subtraction in machine code.
  > a generally more safe type because the length is compile-time known.
- [zig/api] Slicing with comptime-known bounds yields an array pointer, not a slice.
  Slices ^f66
  > // If you slice with comptime-known start and end positions, the result is
  > // a pointer to an array, rather than a slice.
- [zig/safety] `slice.ptr` is unchecked; `&slice[0]` asserts a non-empty slice. Slices ^f67
  > // Note that `slice.ptr` does not invoke safety checking, while `&slice[0]`
  > // asserts that the slice has len > 0.
- [zig/style] Empty slice of a known type: `&.{}`, valid even for a mutable slice.
  Slices ^f68
  > const empty2: []u8 = &.{};
  > // A zero-length initialization can always be used to create an empty slice, even if the slice is mutable.
- [zig/safety] `[:x]T` guarantees the sentinel at `len` but not its absence earlier;
  `data[a..b :0]` checks the sentinel at runtime. Sentinel-Terminated Slices ^f69
  > The type does not guarantee that there are no sentinel elements before that.
  > Sentinel-terminated slicing asserts that the element in the sentinel position of the backing data is actually the sentinel value.
- [zig/api] [toolchain] The 0.17 string example formats into a stack buffer with
  `std.mem.print`; 0.17 std marks `fmt.bufPrint` "Deprecated in favor of `mem.print`"
  (lib/std/fmt.zig:599, checked in the installed 0.17 std, not this source). Slices ^f70
  > const hello_world = try mem.print(all_together_slice, "{s} {s}", .{ hello, world });

### struct

- [zig/perf] Plain structs give no field order or size guarantees, so the compiler may
  reorder; use `extern` only when C layout is needed. struct, extern struct ^f71
  > // Zig gives no guarantees about the order of fields and the size of
  > If well-defined in-memory layout is not required, [struct](https://ziglang.org/documentation/0.17.0/#struct) is a better choice because it places fewer restrictions on the compiler.
  > An `extern struct` has in-memory layout matching the C ABI for the target.
- [zig/api] Methods are plain namespaced functions; dot call is sugar for
  `Type.fn(value, ...)`. The example constructor is `pub fn init(...) T` returning a
  value. struct ^f72
  > // Other than being available to call with dot syntax, struct methods are
  > pub fn init(x: f32, y: f32, z: f32) Vec3 {
  > try expectEqual(0.0, Vec3.dot(v1, v2));
- [zig/api] `@fieldParentPtr` recovers the containing struct from a field pointer (the
  intrusive-node pattern). struct ^f73
  > const point: *Point = @fieldParentPtr("x", x);
- [zig/comptime] Generics are functions returning `type`; comptime calls are memoised so
  `List(i32) == List(i32)`; such types are named after the call. struct, Struct Naming ^f74
  > fn LinkedList(comptime T: type) type {
  > // Functions called at compile-time are memoized.
  > If the struct is in the `return` expression, it gets named after the function it is returning from, with the parameter values serialized.
- [zig/api] Field defaults only when omitting the field can't break an invariant;
  otherwise drop the defaults and offer a named default declaration (`.default`), or an
  init function taking the runtime values. Faulty Default Field Values ^f75
  > Default field values are only appropriate when the data invariants of a struct cannot be violated by omitting that field from an initialization.
  > To fix this, remove the default values from all the struct fields, and provide a named default value
  > const default: Threshold = .{
  > If a struct value requires a runtime-known value in order to be initialized without violating data invariants, then use an initialization method that accepts those runtime values, and populates the remaining fields.
- [zig/perf] `packed struct` = a backing integer with fields laid out from the least
  significant bit; same ABI as the integer; suits flags. packed struct ^f77
  > Packed structs have well-defined memory layout - exactly the same ABI as their backing integer.
  > Each field of a packed struct is interpreted as a logical sequence of bits, arranged from least to most significant.
  > which can be useful for modeling flags
- [zig/safety] An explicit backing integer `packed struct(u32)` is checked against the
  fields' total width at compile time. packed struct ^f78
  > When explicitly provided, its bit width will be enforced at compile time to exactly match the total bit width of the fields
  > backing integer bit width does not match total bit width of fields
- [toolchain] [zig/api] 0.17 converts packed structs, enums and tagged unions to and from
  integers with `@backingInt` / `@fromBackingInt` (they replace `@intFromEnum` and
  `@enumFromInt`); checked, not there: part A never uses `@intFromEnum`. packed struct,
  enum ^f79
  > const backing_int = @backingInt(original);
  > const reconstructed: PackedStruct = @fromBackingInt(backing_int);
  > try expectEqual(0, @backingInt(Value.zero));
- [zig/safety] A pointer to a non-byte-aligned packed field has a bit-offset type and
  can't be passed as a normal `*T`. packed struct ^f80
  > the pointer to a non-byte-aligned field has special properties and cannot be passed when a normal pointer is expected
- [zig/safety] Packed field writes are read-modify-write shifts, not atomic: for MMIO
  build the whole value and store it once through the volatile pointer. packed struct ^f81
  > construct a fully-formed new value first, then write that value to the volatile pointer.
  > // BAD! gpio.GPIO0 = true; BAD!
  > gpio.* = new_states;
- [zig/api] Packed structs and unions compare with `==`/`!=` on the backing integer.
  packed struct ^f82
  > Equating packed structs results in a comparison of the backing integer
- [zig/perf] With a result type, an anonymous literal `.{...}` builds the value directly
  in its result location, with no copy. Anonymous Struct Literals ^f84
  > Zig allows omitting the struct type of a literal.
  > the struct literal will directly instantiate the result location, with no copy
- [zig/comptime] Tuples (anonymous structs without names) have `.len`, comptime indexing,
  `++` and `inline for`; fields are `@"0"`. Tuples ^f85
  > Like arrays, tuples have a .len field, can be indexed (provided the index is comptime-known) and work with the ++ operator.
- [zig/comptime] `anytype` parameters plus anonymous struct arguments (`.{ .int = ... }`)
  are how std passes ad-hoc argument packs (`print`'s args). Anonymous Struct Literals ^f86
  > fn check(args: anytype) !void {

### enum, union, opaque

- [zig/api] Enums, like structs and unions, carry methods as namespaced functions.
  enum ^f87
  > // Enum methods are not special, they are only namespaced
  > pub fn isClubs(self: Suit) bool {
- [toolchain] [zig/comptime] 0.17 type info is struct-of-arrays: `field_names`,
  `field_types`, `field_values`, `param_types` instead of a `fields` array of structs.
  enum, inline else, Function Reflection ^f88
  > try expectEqual(4, @typeInfo(Small).@"enum".field_names.len);
  > const field_types = @typeInfo(T).@"struct".field_types;
  > inline for (info.field_names, info.field_values) |field_name, field_value| {
  > try testing.expectEqual(bool, @typeInfo(@TypeOf(testing.expect)).@"fn".param_types[0].?);
- [zig/perf] An enum without a tag type gets the smallest one that fits (`u2` for four
  members). enum ^f89
  > try expectEqual(u2, @typeInfo(Small).@"enum".tag_type);
- [zig/api] Enums crossing the C ABI need an explicit tag type (`enum(c_int)`). extern
  enum ^f90
  > For a C-ABI-compatible enum, provide an explicit tag type to the enum
  > consider explicitly specifying the integer tag type
- [zig/style] Enum literals (`.auto`) name a field when the type is known from context;
  the doc uses them in switches to avoid repeating the type. Enum Literals ^f91
  > Enum literals allow specifying the name of an enum field without specifying the enum type
- [zig/api] Non-exhaustive enums (`_` field, explicit tag type) model open sets like
  protocol codes; a `_` prong still forces every named tag to be handled, unlike `else`.
  Non-exhaustive enum ^f92
  > The enum must specify a tag type and cannot consume every enumeration value.
  > A switch on a non-exhaustive enum can include a `_` prong as an alternative to an `else` prong. With a `_` prong the compiler errors if all the known tag names are not handled by the switch.
- [zig/safety] `@fromBackingInt` on a non-exhaustive enum is always valid; on an
  exhaustive enum an invalid value is safety-checked illegal behaviour (release notes).
  Non-exhaustive enum ^f93
  > on a non-exhaustive enum always results in a valid enum value.
- [zig/safety] Bare unions have no layout guarantee and can't reinterpret memory; reading
  the inactive field panics in safe modes; switch to another field by assigning the whole
  union. union ^f94
  > The in-memory representation of bare unions is not guaranteed. Bare unions cannot be used to reinterpret memory.
  > access of union field 'float' while field 'int' is active
  > You can activate another field by assigning the entire union
- [zig/api] Tagged unions (`union(enum)`) are the sum type: switch with payload capture,
  `|*p|` to mutate in place, a second capture for the tag, `void` payloads written as a
  bare name and built with `.none`. Tagged union ^f95
  > In order to modify the payload of a tagged union in a switch expression, place a `*` before the variable name to make it a pointer
  > // Because we're in the '.ok' prong, 'tag' is compile-time known to be '.ok':
  > // void can be omitted when inferring enum tag type.
  > var v3: Variant = .none;
- [zig/api] Tagged unions coerce to their tag enum, so `u == .tag` checks work.
  Tagged union ^f96
  > Tagged unions coerce to their tag type
- [zig/api] `opaque {}` gives distinct handle types for C objects whose layout is hidden,
  so two handles can't be mixed up. opaque ^f98
  > This is typically used for type safety when interacting with C code that does not expose struct details.
  > expected type '*test_opaque.Derp', found '*test_opaque.Wat'

### Blocks and switch

- [zig/style] Blocks are expressions: a labelled block returns a value with
  `break :label value`, replacing a helper variable or function. Blocks ^f99
  > Blocks are expressions. When labeled, `break` can be used to return a value from the block
- [zig/style] switch: no fallthrough (combine cases with `,`), inclusive ranges `a...b`,
  arbitrary comptime-known case expressions, `else` required unless exhaustive. switch ^f101
  > // Branches cannot fallthrough. If fallthrough behavior is desired, combine
  > // Ranges can be specified using the ... syntax. These are inclusive
  > // Else branches are mandatory unless the entire range of values
- [zig/comptime] A switch on a comptime-known value (e.g. target OS) only analyses the
  taken prong, so per-target code and `@compileError` sit in plain switches. switch ^f102
  > // Inside a function, switch statements implicitly are compile-time
  > // On an OS other than fuchsia, block is not even analyzed,
- [zig/errors] A switch without `else` must list every value, a compile error otherwise;
  so omitting `else` makes adding an enum member flag every switch. Exhaustive Switching ^f103
  > When a `switch` expression does not have an `else` clause, it must exhaustively list all the possible values. Failure to do so is a compile error
  > unhandled enumeration value: 'off'
- [zig/errors] Switching on errors: `else => unreachable`, `else => return` and
  `else => |e| return e` are allowed even when unreachable; in generic code, prongs for
  errors outside the set are `comptime unreachable`. Switching on Errors ^f104
  > //    `else => |e| return e,` (where `e` is any identifier)
  > error.OutOfMemory => comptime unreachable, // not in `FileOpenError1`!
- [zig/perf] Labelled switch with `continue :sw value` is meant for state machines and
  dispatch loops: comptime targets become direct jumps, runtime ones a branch per prong,
  which predicts better than one loop dispatch point. Labeled switch ^f105
  > This can improve clarity of (for example) state machines, where the syntax `continue :sw .next_state` is unambiguous, explicit, and immediately understandable.
  > However, the motivating example is a switch on each element of an array, where using a single switch can improve clarity and performance
  > Such a branch is perfectly predicted, and hence typically very fast to execute.
  > A loop-based lowering would force every branch through the same dispatch point, hindering branch prediction.
- [zig/memory] The 0.17 dispatch example uses a stack-buffer `ArrayList` with
  `initBuffer` and `appendBounded` (returns an error when full) instead of an allocator.
  Labeled switch ^f106
  > var stack = std.ArrayList(i32).initBuffer(&buffer);
  > try stack.appendSliceBounded(initial_stack);
  > try stack.appendBounded(stack.pop().? + stack.pop().?);
- [zig/comptime] `inline` prongs (values, ranges or `inline else`) instantiate the body
  per value, making the capture comptime-known: runtime value to comptime dispatch.
  Inline Switch Prongs ^f107
  > Switch prongs can be marked as `inline` to generate the prong's body for each possible value it could have
  > inline 0...field_types.len - 1 => |idx| @typeInfo(field_types[idx]) == .optional,
- [zig/comptime] Prefer `inline else` over `inline for` across union fields: it is a real
  switch the compiler checks for exhaustiveness, while `inline for` is a chain of ifs
  needing a trailing `unreachable`. Inline Switch Prongs ^f108
  > `inline else` prongs can be used as a type safe alternative to `inline for` loops
  > // When using `inline for` the compiler doesn't know that every
  > inline else => |slice| slice.len,
- [zig/comptime] An inline prong on a union can also capture the tag at comptime while
  the payload stays runtime. Inline Switch Prongs ^f109
  > an additional capture can be used to obtain the union's enum tag value at comptime, even though its payload might only be known at runtime.
  > inline else => |num, tag| {

### Loops and if

- [zig/style] while has a continue expression `: (i += 1)` (run on `continue` too);
  while and for are expressions whose `else` runs when the loop ends without `break`.
  while ^f110
  > While loops support a continue expression which is executed when the loop is continued. The `continue` keyword respects this expression.
  > When you `break` from a while loop, the `else` branch is not evaluated.
  > return while (i < end) : (i += 1) {
- [zig/style] `while (opt()) |x|` loops until null (the iterator idiom); `while (eu())
  |x| ... else |err|` until an error. while with Optionals, Error Unions ^f111
  > while (eventuallyNullSequence()) |value| {
  > When the condition results in an error code the else branch is evaluated and the loop is finished.
- [zig/perf] [zig/comptime] Use `inline` loops only when comptime semantics need them or
  a benchmark shows unrolling is faster. inline while, inline for ^f112
  > It is recommended to use `inline` loops only for one of these reasons:
  > You have a benchmark to prove that forcibly unrolling the loop in this way is measurably faster.
- [zig/style] for iterates slices, arrays and ranges; several sequences at once (lengths
  must match, checked); index via an extra `0..`; mutate via `&items` with `|*v|`;
  unbounded ranges are errors. for ^f113
  > for (items, 0..) |_, i| {
  > // All lengths must be equal at the start of the loop, otherwise detectable
  > for (&items) |*value| {
  > // Unbounded range is always a compile error.
- [zig/style] Labelled while and for loops let `break :outer` and `continue :outer`
  target an outer loop. Labeled while, Labeled for ^f114
  > outer: for (1..6) |_| {
- [zig/style] `if` is the ternary; it also unwraps optionals (`|v|`) and error unions
  (`|v| ... else |err|`, the else capture is mandatory), `|*v|` for in-place edits; test
  null alone with `== null`. if ^f115
  > // If expressions are used instead of a ternary expression.
  > // The else and |err| capture is strictly required.
  > // To test against null only, use the binary equality operator.
  > // If expressions test for errors before unwrapping optionals.

### defer, unreachable, noreturn

- [zig/memory] `defer` runs at scope exit (block, not function), in reverse order, only
  if the defer statement was reached; it can't `return`. defer ^f116
  > Executes an expression unconditionally at scope exit.
  > Defer expressions are evaluated in reverse order.
  > // defers are not run if they are never executed.
  > Inside a defer expression the return statement is not allowed.
- [zig/memory] Checked, not there: `errdefer` is not in part A (it is under Errors, part
  B, [[zig-langref-017-b]]). defer ^f117
- [zig/safety] `unreachable` panics in Debug and ReleaseSafe but is an optimiser
  assumption in ReleaseFast and ReleaseSmall; `std.debug.assert` is just
  `if (!ok) unreachable`, so asserts are checks in safe modes and hints in fast ones.
  unreachable ^f118
  > the optimizer uses the assumption that `unreachable` code will never be hit to perform optimizations.
  > if (!ok) unreachable; // assertion failure
- [zig/comptime] Reaching `unreachable` at comptime is a compile error, so
  `comptime unreachable` asserts a branch is statically dead. unreachable, Default Field
  Values ^f119
  > unreachable expressions are compile errors.
  > comptime unreachable;
- [zig/errors] `noreturn` (`return`, `break`, `unreachable`, exit functions) fits any
  type in if and switch, enabling `const a = if (c) b else return;` and
  `catch exit(1)`. noreturn ^f120
  > When resolving types together, such as `if` clauses or `switch` prongs, the `noreturn` type is compatible with every other type.
  > const a = if (condition) b else return;
  > const value = bar() catch ExitProcess(1);

### Functions

- [zig/perf] Parameters are immutable, so Zig may pass structs by copy or by reference as
  it judges faster; don't take a parameter's address expecting it to outlive the call.
  Pass-by-value Parameters ^f121
  > When these types are passed as parameters, Zig may choose to copy and pass by value, or pass by reference, whichever way Zig decides will be faster. This is made possible, in part, by the fact that parameters are immutable.
  > // taking the address of the parameter - it should be treated as if
  > // the address will become invalid when the function returns.
- [zig/perf] `inline fn` is not a hint: it forces semantic inlining, restricts the
  compiler and can cost binary size, compile time and speed; for a hint use
  `@branchHint`. Inline Is Not A Hint ^f122
  > Use of `inline` _restricts_ what the compiler is allowed to do.
  > This can harm binary size, compilation speed, and even runtime performance.
  > For an alternative to `inline` that merely hints to the compiler that inlining a function may be valuable, use
- [zig/comptime] Legitimate `inline fn` uses: comptime-known arguments propagate to the
  return value (the example's `@compileError` check passes only when inlined).
  inline fn ^f123
  > Unlike normal function calls, arguments at an inline function callsite which are compile-time known are treated as
  > If `inline` is removed, the test fails with the compile error instead of passing.
- [zig/perf] `@branchHint(.cold)` marks a rarely called function. Functions ^f124
  > // The @branchHint builtin can be used to tell the optimizer that a function is rarely called ("cold").
- [zig/api] Function pointers are `*const fn (...) T`; function bodies are comptime-only
  values, pointers can be runtime. Functions ^f125
  > const Call2Op = *const fn (a: i8, b: i8) i8;
  > There is a difference between a function _body_ and a function _pointer_.
- [zig/api] `pub` makes a declaration importable; `export` gives C ABI and external
  visibility; `extern "lib"` declares a symbol resolved at link or load time; `callconv`
  sets the calling convention. Functions ^f126
  > // The pub specifier allows the function to be visible when importing.
  > // The export specifier makes a function externally visible in the generated
  > extern "c" fn atan2(a: f64, b: f64) f64;
- [zig/comptime] `anytype` parameters infer their type per call; return types can be
  computed from them with `@TypeOf`. Function Parameter Type Inference ^f127
  > fn addFortyTwo(x: anytype) @TypeOf(x) {
- [zig/api] Checked, not there: part A has no section on decl literals or result
  location semantics as such (Result Location Semantics is in part B; no "decl literal"
  phrase anywhere in the langref); `.empty` appears only in the leak example (^f32). ^f128

## Read

- Raw lines 366-6906 (Introduction through Function Reflection): every line, including
  examples and their shell output.

## Not read

- Lines 6907 onwards (Errors, errdefer, Optionals, Casting, Result Location Semantics,
  comptime, builtins, Memory, Build Mode, Illegal Behavior, Style Guide): owned by
  [[zig-langref-017-b]].
