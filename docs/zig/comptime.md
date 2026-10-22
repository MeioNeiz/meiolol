# 8. Comptime

## 8.1 What it is: partial evaluation

Generics are comptime parameters and functions that return `type`; type functions are
memoised; untaken comptime branches are never analysed [[zig-langref-017-b#^f39]],
[[zig-langref-017-b#^f45]], [[zig-langref-017-a#^f74]]. matklad's framing: comptime is
partial evaluation; marking an argument `comptime` guarantees specialisation per value.
It has no eval, no DSLs, no IO, no new methods; codegen that needs IO goes in build.zig
[[matklad-comptime-wont-do#^f3]], [[matklad-comptime-wont-do#^f8]],
[[matklad-comptime-wont-do#^f9]]. The langref: comptime is for guarantees, not speed
[[zig-langref-017-b#^f41]].

```zig
// research/raw/zig-langref-017.md:11522
fn List(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,

        fn length(self: Self) usize {
            return self.items.len;
        }
    };
}
```

## 8.2 Keep it sparse in applications

Per 10k lines, `anytype` appears 16 times in ZLS, 0.7 in River, 1.9 in SuperHTML;
comptime lives in a few generic helpers (slot map, flag parser, tracing) and nowhere else
[[zls-repo#^f38]], [[river-repo#^f25]]. Mitchell warns against "full metaprogramming": it
hurts readability and compile time [[mitchellh-ghostty-and-useful-zig-patterns#^f9]].
Bun shows the cost at scale: dropping comptime overuse took its binary from 6.8 to 3.8
MB [[bun-in-rust#^f9]], and Kelley says the team warned Bun about comptime abuse for years
and built `zig build --time-report` to audit it [[ak-bun-rust-rewrite#^f4]]. Each
comptime parameter monomorphises: drop `comptime` where a runtime value works
[[tigerbeetle-blog-copy-hunting#^f4]]. Loris Cro: complex comptime in dependencies
breaks on toolchain updates and reads badly; a generated file can be read and
go-to-definitioned [[kristoff-comptime-sqlite#^f7]].

## 8.3 Reject misuse at construction with a sentence

```zig
// ziglang/zig lib/std/hash_map.zig:11 @ 0.17.0
pub fn getAutoHashFn(comptime K: type, comptime Context: type) (fn (Context, K) u64) {
    comptime {
        assert(@hasDecl(std, "StringHashMap")); // detect when the following message needs updated
        if (K == []const u8) {
            @compileError("std.hash.autoHash does not allow slices here (" ++
                @typeName(K) ++
                ") because the intent is unclear. " ++
                "Consider using std.StringHashMap for hashing the contents of []const u8. " ++
                "Alternatively, consider using std.hash.autoHashStrat or providing your own hash function instead.");
        }
    }
```

A compile error that tells you what to do instead [[zig-std-containers#^f22]]. Loris
Cro's comptime SQLite rows fail at compile time on an unknown column
[[kristoff-comptime-sqlite#^f3]]:

```
// research/raw/kristoff-comptime-sqlite.md:117
pub fn int(r: Row, comptime col: @EnumLiteral()) i64 {
    const idx = comptime col_map.get(@tagName(col)) orelse {
        @compileError("column '" ++ @tagName(col) ++ "' not found in query");
    };
    return r.row.int(idx);
 }
```

Good comptime APIs often have a runtime twin, so comptime is a convenience, not a
second implementation: zig-clap parses its parameter spec with the same parser at either
time, and reports the spec's line and column [[zig-clap-repo#^f2]]:

```zig
// zig-clap clap.zig:97 @ 05faf390
pub fn parseParamsComptime(comptime str: []const u8) [countParams(str)]Param(Help) {
    var end: usize = undefined;
    var res: [countParams(str)]Param(Help) = undefined;
    _ = parseParamsIntoSliceEx(&res, str, &end) catch {
        const loc = std.zig.findLineColumn(str, end);
        @compileError(std.fmt.comptimePrint("error:{}:{}: Failed to parse parameter:\n{s}", .{
            loc.line + 1,
            loc.column + 1,
            loc.source_line,
        }));
    };
    return res;
}
```

## 8.4 anytype or `comptime T: type`

`anytype` hides the contract in the body and tools can't help; `comptime T: type` puts it
in the signature, as `std.mem.eql` does [[ziggit-generic-anytype#^f2]],
[[ziggit-generic-anytype#^f3]]. matklad uses `anytype` freely for comptime duck-typed
inputs ("monomorphization maximus", not dynamic typing) while keeping return types
explicit [[matklad-comptime-orm#^f14]]. Rule by role: on public runtime APIs, a concrete
type or interface (the std replaced `writer: anytype` with `*Io.Writer`,
[[zig-015-release-notes#^f12]]); in internal comptime helpers, `anytype` is fine when the
contract is obvious. Return types stay explicit.

## 8.5 Per-variant code: inline else, not inline for

`inline else` is a real switch the compiler checks for exhaustiveness; `inline for` over
fields is a chain of ifs that needs a trailing `unreachable` [[zig-langref-017-a#^f108]]:

```zig
// research/raw/zig-langref-017.md:5672
fn withFor(any: AnySlice) usize {
    const Tag = @typeInfo(AnySlice).@"union".tag_type.?;
    const info = @typeInfo(Tag).@"enum";
    inline for (info.field_names, info.field_values) |field_name, field_value| {
        // With `inline for` the function gets generated as
        // a series of `if` statements relying on the optimizer
        // to convert it to a switch.
        if (field_value == @backingInt(any)) {
            return @field(any, field_name).len;
        }
    }
    // When using `inline for` the compiler doesn't know that every
    // possible case has been handled requiring an explicit `unreachable`.
    unreachable;
}

fn withSwitch(any: AnySlice) usize {
    return switch (any) {
        // With `inline else` the function is explicitly generated
        // as the desired switch and the compiler can check that
        // every possible case is handled.
        inline else => |slice| slice.len,
    };
}
```

`inline` loops only when comptime semantics need them or a benchmark shows a win
[[zig-langref-017-a#^f112]]. `inline fn` is not a hint: it restricts the compiler and
"can harm binary size, compilation speed, and even runtime performance"; use it for
comptime-propagating arguments, and `@branchHint` for hints [[zig-langref-017-a#^f122]].

## 8.6 Exhaustive switches over a subset: generate the subset

An `else` prong loses the check when a tag is added; listing no-ops lets the signature
accept tags it never handles. Mitchell's answer: one exhaustive `scope()` classifies the
tags, and a comptime function builds the subset union
[[mitchellh-zig-comptime-tagged-union-subset#^f2]]. The 0.17 form, with `@Union` and
`@Enum`:

```zig
// ghostty src/input/Binding.zig:1483 @ 08a9518
        inline for (field_names, field_types, field_attrs) |field_name, field_type, field_attr| {
            const action = @unionInit(Action, field_name, undefined);
            if (action.scope() == s) {
                names[i] = field_name;
                types[i] = field_type;
                attrs[i] = field_attr;
                raw_values[i] = i;
                i += 1;
            }
        }

        const TagInt = std.math.IntFittingRange(0, i);
        var values: [i]TagInt = undefined;
        for (raw_values[0..i], &values) |raw, *v| v.* = raw;

        // Build our union
        return @Union(
            .auto,
            @Enum(TagInt, .exhaustive, names[0..i], &values),
            names[0..i],
            types[0..i],
            attrs[0..i],
        );
```

## 8.7 Compile code out with comptime if; mind the call boundary

Dead comptime branches aren't analysed, so they may name types that exist only in some
builds. But a plain call `if (hasFeature())` compiles both branches: mark the call
`comptime`, or make a mixed helper `inline fn`; build every option in CI
[[mitchellh-zig-comptime-conditional-disable#^f5]],
[[mitchellh-zig-comptime-conditional-disable#^f7]].

```zig
// ghostty src/simd/index_of.zig:10 @ 08a9518
pub fn indexOf(input: []const u8, needle: u8) ?usize {
    if (comptime options.simd) {
        const result = ghostty_simd_index_of(needle, input.ptr, input.len);
        return if (result == input.len) null else result;
    }

    return indexOfScalar(input, needle);
}
```

## 8.8 Pick backends at comptime

When an implementation never changes at runtime, select it at comptime from build
options; every binary has exactly one [[ghostty-repo#^f38]]:

```zig
// ghostty src/apprt.zig:39 @ 08a9518
/// The implementation to use for the app runtime. This is comptime chosen
/// so that every build has exactly one application runtime implementation.
/// Note: it is very rare to use Runtime directly; most usage will use
/// Window or something.
pub const runtime = switch (build_config.artifact) {
    .exe => switch (build_config.app_runtime) {
        .none => none,
        .gtk => gtk,
    },
    .lib => embedded,
    .wasm_module => browser,
};
```

Optional hooks on a comptime interface are probed with `@hasDecl` (required ones are
just called, so a missing one is a compile error at the use site); document the contract
in the doc comment, since the type system won't [[ghostty-repo#^f40]],
[[seguin-comptime-config#^f1]]. Static dispatch over a closed set with a comptime tag:

```zig
// ghostty src/terminal/stream.zig:3948 @ 08a9518 (test handler)
        pub fn vt(self: *@This(), comptime action: Action.Tag, value: Action.Value(action)) void {
            _ = value;
            switch (action) {
                .soft_reset => self.calls += 1,
                else => {},
            }
        }
```

## 8.9 Reflection in 0.17

`@typeInfo` is struct-of-arrays: iterate `field_names` and `field_types` in parallel;
build types with `@Int`, `@Struct`, `@Union`, `@Enum`, `@Tuple`; `@Type` is gone; error
sets are written out [[zig-017-release-notes#^f3]], [[zig-016-release-notes#^f26]]:

```zig
// research/raw/zig-017-release-notes.md:1019 (upgrade diff, + lines)
    const info = @typeInfo(S).@"struct";
    inline for (info.field_names, info.field_types) |field_name, field_type| {
        try s.fieldPrefix(field_name);
        try printValue(sc, s.container.serializer, field_type, @field(v, field_name));
    }
```

Reflection is for wide repetitive surfaces: Ghostty's config parser walks hundreds of
fields, lets field types opt in with a `parseCLI` hook, and ends unsupported types in a
compile error that names the type [[ghostty-repo#^f42]], [[ghostty-repo#^f45]]. matklad
teaches a full comptime ORM, then: "You should avoid this feature if possible"
[[matklad-comptime-orm#^f15]]. When you do reflect, pass fields as
`std.meta.FieldEnum(T)`, not strings: a bad field errors at the call site and stays
greppable [[matklad-comptime-orm#^f9]].

## 8.10 Comptime data

Tables computed at container level with ordinary functions cost no runtime and keep one
source of truth; raise `@setEvalBranchQuota` only where needed (default 1000 backward
branches) [[zig-langref-017-b#^f44]], [[mitchellh-ghostty-devlog-004#^f1]]. Fill a local
`comptime var`, then copy into a `const` before taking its address; no global mutable
comptime state [[zig-012-release-notes#^f5]], [[zig-012-release-notes#^f7]]:

```zig
// research/raw/zig-012-release-notes.md:625
fn getName() []const u8 {
    comptime var buf: [9]u8 = undefined;
    // In practice there would likely be more complex logic here to populate `buf`.
    @memcpy(&buf, "some name");
    const final_name = buf;
    return &final_name;
}
```

## 8.11 Type-erase generic calls with ArgsTuple

The std's `Io.async` takes any function plus a typed argument tuple and erases it in a
local struct; no `anytype` argument list, full type checking [[zig-std-io#^f5]]:

```zig
// ziglang/zig lib/std/Io.zig:2526 @ 0.17.0
pub fn async(
    io: Io,
    function: anytype,
    args: std.meta.ArgsTuple(@TypeOf(function)),
) Future(@typeInfo(@TypeOf(function)).@"fn".return_type.?) {
    const Result = @typeInfo(@TypeOf(function)).@"fn".return_type.?;
    const Args = @TypeOf(args);
    const TypeErased = struct {
        fn start(context: *const anyopaque, result: *anyopaque) void {
            const args_casted: *const Args = @ptrCast(@alignCast(context));
            const result_casted: *Result = @ptrCast(@alignCast(result));
            result_casted.* = @call(.auto, function, args_casted.*);
        }
    };
```

TigerBeetle erases typed callbacks the same way so its IO layer needs no closure
allocation [[tigerbeetle-code#^f31]].
