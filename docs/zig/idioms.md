# 4. Everyday language idioms

## 4.1 const by default, no shadowing

`const` unless the value changes: "less work for both humans and computers"
[[zig-langref-017-a#^f18]]. A never-mutated `var` has been a compile error since 0.12
[[zig-012-release-notes#^f1]]. Shadowing is forbidden so "you can always rely on an
identifier to consistently mean the same thing" [[zig-langref-017-a#^f35]]: pick
distinct names (`gpa` and `arena`, `items` and `item`). Unused locals and redeclarations
being errors catches real bugs; Kelley's port of an OpenZFS bug to Zig is the example
[[ak-openzfs-bug-zig#^f2]].

## 4.2 Expressions instead of temporaries

Blocks, `if`, `while`, `for` and `switch` are expressions; labelled blocks compute a
value in place; tuples plus destructuring return several values
[[zig-langref-017-a#^f99]], [[zig-langref-017-a#^f24]].

```zig
// research/raw/zig-langref-017.md:5875 and :4378
fn rangeHasNumber(begin: usize, end: usize, number: usize) bool {
    var i = begin;
    return while (i < end) : (i += 1) {
        if (i == number) {
            break true;
        }
    } else false;
}

fn divmod(numerator: u32, denominator: u32) struct { u32, u32 } {
    return .{ numerator / denominator, numerator % denominator };
}
// caller: const div, const mod = divmod(10, 3);
```

Labelled block initialisation, from the 0.14 allocator recipe:

```zig
const gpa, const is_debug = gpa: {
    if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
    break :gpa switch (builtin.mode) { ... };
};
```

## 4.3 for over several sequences, ranges and pointer captures

Lengths are checked equal; no "lead" sequence with an index
[[zig-011-release-notes#^f1]], [[zig-langref-017-a#^f113]].

```zig
// research/raw/zig-011-release-notes.md:715
    for (input, output) |x, *out| {
        out.* = x * 2;
    }
// and: for (items, 0..) |item, i| { ... }    for (&items) |*value| value.* += 1;
```

```zig
// devlog 2024-09-16 (Kelley)
for (scanline, scanline2, result.pixels[j*result.stride..][0..result.w]) |s, s2, *p| {
    sum += s2;
    p.* = @min(@abs(s + sum)*255 + 0.5, 255);
}
```

Prefer `for (0..n) |i|` to `while (i < n) : (i += 1)`; and `defer i += 1` is not the
same thing, it also runs on `break`, `return` and `try` [[matklad-lovely-syntax#^f14]],
[[matklad-lovely-syntax#^f15]].

## 4.4 Slice by length: `s[start..][0..len]`

"Always better expressed": one subtraction fewer, and with a comptime `len` the result is
`*[len]T`, which carries the length in the type [[zig-langref-017-a#^f65]]. The same
trick loads a vector: `slice[offset..][0..4].*` [[zig-langref-017-a#^f54]].

```zig
// research/raw/zig-langref-017.md:3471
test "example" {
    var array = [_]i32{ 1, 2, 3, 4 };
    var runtime_start: usize = 1;
    _ = &runtime_start;
    const length = 2;
    const array_ptr_len = array[runtime_start..][0..length];
    try expectEqual(*[length]i32, @TypeOf(array_ptr_len));
}
```

Where a size is fixed, take `*const [N]T` rather than a slice plus an assert
[[zig-014-release-notes#^f33]].

## 4.5 Slices over many-item pointers

Slices are bounds checked; `[*]T` is for pointer arithmetic, and bumping `slice.ptr`
desynchronises `len` [[zig-langref-017-a#^f58]], [[zig-langref-017-a#^f59]].
`[*:0]const u8` belongs at C boundaries [[zig-langref-017-a#^f64]]. Take `[]const T`
when you don't mutate: callers can then pass literals and temporaries, which are always
const [[seguin-temporaries-const#^f1]].

## 4.6 Exhaustive switch; no else over your own enums

Without `else`, adding a variant breaks every switch that must handle it, at compile
time [[zig-langref-017-a#^f103]], [[seguin-learning-zig-language-overview-2#^f6]]. Roc
lints for it [[roc-zig-compiler#^f7]]. For non-exhaustive enums use the `_` prong, which
still forces every named tag [[zig-langref-017-a#^f92]].

To share code between some variants and keep the check, use inline prongs with
`comptime unreachable`: a later refactor that routes another tag there fails to compile
[[matklad-partial-enums#^f2]].

```zig
// research/raw/matklad-partial-enums.md:100
fn handle(u: U) void {
    switch (u) {
        inline .a, .b => |_, ab| {
            handle_ab();
            switch (ab) {
                .a => handle_a(),
                .b => handle_b(),
                else => comptime unreachable,
            }
        },
        .c => handle_c(),
    }
}
```

## 4.7 Tagged unions are the sum type

`union(enum)` switched with captures; `|*p|` to mutate; bare names for void payloads;
enum literals (`.int =>`) rather than `Variant.int =>` [[zig-langref-017-a#^f95]],
[[zig-langref-017-a#^f91]]. `inline else => |x| x.method()` dispatches over every
variant with static calls [[zig-langref-017-a#^f108]].

Never keep a pointer into a union payload across a write to the union: the pointer
stays typed as the old variant, and no safety check catches it
[[matklad-memory-safety-hardest#^f1]].

## 4.8 Labelled switch for state machines

`continue :label value` is a structured goto. It is clearer than `while (true) switch`
and faster: each prong gets its own branch for the predictor; the std tokenizer got 13%
faster [[zig-014-release-notes#^f1]], [[zig-014-release-notes#^f2]],
[[zig-langref-017-a#^f105]].

```zig
// research/raw/zig-langref-017.md:5545 (langref 0.17.0)
fn evaluate(initial_stack: []const i32, code: []const Instruction) !i32 {
    var buffer: [8]i32 = undefined;
    var stack = std.ArrayList(i32).initBuffer(&buffer);
    try stack.appendSliceBounded(initial_stack);
    var ip: usize = 0;

    return vm: switch (code[ip]) {
        // Because all code after `continue` is unreachable, this branch does
        // not provide a result.
        .add => {
            try stack.appendBounded(stack.pop().? + stack.pop().?);

            ip += 1;
            continue :vm code[ip];
        },
        ...
        .end => stack.pop().?,
    };
}
```

Cost: it may grow code size compared with a switch in a loop.

## 4.9 Casts by intent, type from the result location

- Let the destination type come from the result location (parameter, field, return
  type); `@as` only when nothing supplies one. A type repeated at the call site goes
  silently wrong when the parameter type changes [[zig-011-release-notes#^f4]].
- `@intCast` when the value must fit (asserted, so UB in fast builds); `@truncate` when
  dropping bits is the point [[zig-langref-017-b#^f24]].
- Float to int: `@round`, `@floor`, `@ceil` or `@trunc` into an integer result type;
  `@intFromFloat` is deprecated [[zig-langref-017-b#^f27]].
- Enums and packed types: `@backingInt` / `@fromBackingInt` (0.17), not
  `@intFromEnum` / `@enumFromInt`; zig fmt rewrites them [[zig-017-release-notes#^f16]].
- One qualifier per cast: `@constCast`, `@alignCast`, `@volatileCast`; `@ptrCast` only
  for pointer type changes [[zig-langref-017-b#^f29]].
- 0.17 changed `@bitCast` to work on logical bits, endian-agnostic; type-pun with
  `@ptrCast` or an extern union, and audit array and vector bitcasts
  [[zig-017-release-notes#^f14]].

```zig
// research/raw/zig-langref-017.md:8574
const s: S = .{ .x = @intCast(val) };
// .{ .x = @intCast(val) }   has result type `S` due to the type annotation
//         @intCast(val)     has result type `u32` due to the type of the field `S.x`
//                  val      has no result type, as it is permitted to be any integer type
```

Narrowing that can fail on real data should be an error, not an `@intCast`. Roc:

```zig
// roc src/collections/safe_list.zig:10 @ 55a9d652
/// The most elements a safe list holds, so every index and range count is a
/// `u32`.
const max_len: usize = std.math.maxInt(u32);

/// Rejects a length past the 32-bit index range as allocation failure.
fn checkLen(new_len: usize) Allocator.Error!void {
    if (new_len > max_len) return error.OutOfMemory;
}
```

## 4.10 Arithmetic says what it means

Plain `+ - *` overflow is illegal behaviour; `+%` wraps and `+|` saturates. Signed `/`
and `%` need comptime-known positive operands, else `@divTrunc`, `@divFloor`, `@divCeil`
(new in 0.17), `@divExact`, `@rem`, `@mod` [[zig-langref-017-a#^f41]],
[[zig-017-release-notes#^f18]].

## 4.11 Struct layouts have jobs

Plain `struct` by default (no order guarantee, the compiler may reorder); `extern` for
the C ABI; `packed struct(u8)` with an explicit backing integer for bit-exact flags and
registers [[zig-langref-017-a#^f71]], [[zig-langref-017-a#^f77]]. Packed field writes
are a read-modify-write, so for MMIO build the whole value and store once
[[zig-langref-017-a#^f81]].

## 4.12 undefined means "a bug if read"

Use it only for storage that is written before it is read
(`var buffer: [8]i32 = undefined;` then `initBuffer(&buffer)`); the 0xaa fill in safe
builds is a debugger aid, not semantics [[zig-langref-017-a#^f20]]. Arithmetic on
undefined is illegal [[zig-015-release-notes#^f8]]. No `undefined` field defaults
[[ziggit-code-smells#^f4]]. A 0.17 change bit this repo: assigning `undefined` to an
optional reads as null in safe builds (docs/zig-0.17.md).

## 4.13 Field defaults only when omission can't break an invariant

The langref's own counter-example: overriding only `.maximum` keeps the default
`minimum` and an assert fires. Defaults that only make sense together become a named
declaration [[zig-langref-017-a#^f75]], [[zig-014-release-notes#^f4]].

```zig
// research/raw/zig-014-release-notes.md:401
pub const BufferB = extern struct {
    ptr: ?[*]u32,
    len: usize,
    pub const empty: BufferB = .{ .ptr = null, .len = 0 };
};
// We can still easily create an empty buffer:
var empty_buf_b: BufferB = .empty;
// ...but the language no longer hides incorrect field overrides from us!
// If we want to override a field, we'd have to specify both, making the error obvious:
var bad_buf_b: BufferB = .{ .ptr = null, .len = 10 }; // clearly wrong!
```

Independent knobs (an options struct where each field stands alone) keep field defaults
(api.md 9.2).

## 4.14 Anonymous initialisers write in place

`x = .{ ... }` with a result type builds in place, with no copy, which matters for types
that must not move. It is not a swap: `arr = .{ arr[1], arr[0] }` assigns element by
element and fails [[zig-langref-017-b#^f35]], [[zig-langref-017-b#^f38]]. Pass structs by
value; Zig picks copy or reference, so never keep a parameter's address past the call
[[zig-langref-017-a#^f121]].

## 4.15 Declarations live where they are found

`usingnamespace` is gone (0.15) so every identifier traces to its definition for people
and tools. Include declarations unconditionally (analysis is lazy), switch the
definition per target, and detect features with a `{}` sentinel, not `@hasDecl`, which
silently compiles a feature out on a typo [[zig-015-release-notes#^f3]],
[[zig-langref-017-b#^f47]].

```zig
// research/raw/zig-015-release-notes.md:326
const something = struct {
    // In this example, `foo` is supported but `bar` is not.
    const have_foo = true;
    const have_bar = false;
    pub const foo = if (have_foo) 123 else {};
    pub const bar = if (have_bar) undefined else {};
};

test "use foo if supported" {
    if (@TypeOf(something.foo) == void) return error.SkipZigTest; // unsupported
    try expect(something.foo == 123);
}
```

Target code: `switch (builtin.target.os.tag)`; only the taken prong is analysed, so
`@compileError` in the others is safe [[zig-langref-017-a#^f102]].
