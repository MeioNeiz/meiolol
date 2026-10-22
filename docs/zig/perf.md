# 12. Performance and data-oriented design

## 12.1 Shrink the struct you have most of

Kelley's DOD talk: the CPU is fast and memory slow, so a computation beats a load and
cheap math should not be memoised; then shrink the most numerous struct
[[zig-talk-kelley-dod#^f1]], [[zig-talk-kelley-dod#^f2]]. The tricks, each with his
numbers:

- u32 indexes instead of pointers: halves the field, alignment 8 to 4
- out-of-band bools (two arrays instead of a flag field): 24 to 12 bytes
- struct-of-arrays via `MultiArrayList`: 160 KB to 91 KB for 10k items
- sparse fields in a hash map keyed by index: 366 KB to 198 KB
- encodings instead of polymorphism: 32 to 17 bytes

Applied to the compiler: tokens 64 to 5 bytes, AST nodes 120 to 15.6, ZIR 54 to 20.3;
parsing 22% and AstGen 39% faster in wall time [[zig-talk-kelley-dod#^f12]],
[[zig-talk-kelley-dod#^f13]]. Flat arrays save and load with one `writev`/`readv`. The
caveats: SoA costs an extra access when you need the whole record, and hash-map lookups
cost more than direct access, so choose by access pattern [[zig-talk-kelley-dod#^f16]].

## 12.2 The std's AST is the worked example

```zig
// ziglang/zig lib/std/zig/Ast.zig:17 @ 0.17.0
/// Reference to externally-owned data.
source: [:0]const u8,

tokens: TokenList.Slice,
nodes: NodeList.Slice,
extra_data: []u32,
mode: Mode = .zig,

errors: []const Error,

pub const ByteOffset = u32;

pub const TokenList = std.MultiArrayList(struct {
    tag: Token.Tag,
    start: ByteOffset,
});
pub const NodeList = std.MultiArrayList(Node);
```

Smaller items (no padding, u32 not pointers), cache lines that hold only the field a pass
reads, and a structure that serialises as a few arrays; variable payloads go in a `[]u32`
extra array decoded by a comptime `extraData` [[zig-compiler-dod#^f1]],
[[zig-compiler-dod#^f7]]. The InternPool separates the rich API type (`Key`, a tagged
union) from the storage type (`Item`: a u8 tag plus u32 data), and interning makes
equality an index compare [[zig-compiler-dod#^f16]], [[zig-compiler-dod#^f17]]:

```zig
// ziglang/zig src/InternPool.zig:3932 @ 0.17.0
pub const Item = struct {
    tag: Tag,
    /// The doc comments on the respective Tag explain how to interpret this.
    data: u32,
};
```

Roc goes further: per-id data as parallel columns on the owning store, and a lint bans
hash maps keyed by an id [[roc-zig-compiler#^f12]].

## 12.3 Indexes over pointers, before profiling

matklad: 4 bytes saved per pointer spreads evenly and never shows in a profiler, so
decide it up front; lists become ranges into shared storage; no deep pointer recursion
(stack overflows in production); relocatable and bulk-serialisable
[[matklad-newtype-index#^f1]], [[matklad-newtype-index#^f3]]. Ghostty's terminal pages
are one contiguous block addressed by typed offsets, with zero as the empty state, so a
page can be copied, compressed or serialised as a unit [[ghostty-repo#^f12]]. Recursion
over input-shaped data becomes heap worklists [[roc-zig-compiler#^f15]].

## 12.4 Hot loops as free functions over slices

TigerBeetle's merge loops take explicit inputs and outputs, no `self`, so the optimiser
need not prove fields stay in registers; control-plane decisions stay in the caller,
which can afford heavy asserts [[tigerbeetle-tiger-style#^f26]],
[[tigerbeetle-code#^f18]]:

```zig
// tigerbeetle src/lsm/compaction.zig:2043 @ 0450c32
        // The three functions below are hot CPU loops doing the actual merging, TigerBeetle's data
        // plane. To reduce the probability of the optimizer getting confused over pointers, don't
        // use 'self' and instead specify all inputs and outputs explicitly. Its the caller's job to
        // apply control plane changes to the compaction state.
        //
        // TODO: Add micro benchmarks.

        fn values_copy(values_target: []Value, values_source: []const Value) u32 {
            assert(values_source.len > 0);
            assert(values_source.len <= Table.data.value_count_max);
            assert(values_target.len > 0);
            assert(values_target.len <= Table.data.value_count_max);

            const len: u32 = @intCast(@min(values_source.len, values_target.len));
            stdx.copy_disjoint(
                .exact,
                Value,
                values_target[0..len],
                values_source[0..len],
            );

            return len;
        }
```

(Note the honest TODO: no micro benchmark backs it yet.) matklad's constant-work
variant: iterate full fixed arrays with a neutral `reserved` value instead of index lists
of active items; it vectorises and keeps P100 latency flat
[[matklad-static-alloc-constant-work#^f9]].

## 12.5 Packed records

Small hot records as `packed struct(u64)` read in one load, and masked compares answer
multi-field questions in one AND; flags that may be false-positive but never
false-negative let slow paths be skipped (4x on erase in Ghostty) [[ghostty-repo#^f73]].
Derive the backing integer instead of hardcoding it [[ghostty-repo#^f47]]:

```zig
// ghostty src/terminal/page.zig:2092 @ 08a9518
    /// The backing integer of this packed struct. Prefer this over
    /// hardcoding the integer type so that code is resilient to the
    /// size changing.
    pub const Backing = @typeInfo(Row).@"struct".backing_integer.?;
```

## 12.6 Everyday SIMD

Mitchell's five-step shape: splat the constants, loop whole vectors, reduce, turn the
bool vector into a bit mask and `@ctz` it, finish with the scalar loop, which is also the
fallback where `simd.lanes` returns null. Compilers rarely auto-vectorise branchy scans,
and it only pays on large inputs [[mitchellh-everyone-should-know-simd#^f1]],
[[mitchellh-everyone-should-know-simd#^f2]]:

```zig
// ghostty src/terminal/stream.zig:876 @ 08a9518
                        if (simd.lanes(u32)) |lanes| {
                            const V = @Vector(lanes, u32);
                            // Non-printable (C0 or decoded C1) is
                            // equivalent to "no bit outside 0x9F is
                            // set": one AND-test per lane.
                            const mask: V = @splat(~@as(u32, 0x9F));
                            const zero: V = @splat(0);
                            while (end + lanes <= cps.len) {
                                const v: V = cps[end..][0..lanes].*;
                                const stop = (v & mask) == zero;
                                if (@reduce(.Or, stop)) {
                                    const bits: @Int(.unsigned, lanes) = @bitCast(stop);
                                    end += @ctz(bits);
                                    break :scan;
                                }
                                end += lanes;
                            }
                        }
                        while (end < cps.len and (cps[end] & ~@as(u32, 0x9F)) != 0) end += 1;
```

Keep vector lengths small powers of two; load from runtime offsets with
`[off..][0..N].*` [[zig-langref-017-a#^f53]].

## 12.7 Measure, then complicate

- profile first: a profile put 30% of Ghostty's per-character time in codepoint width
  [[mitchellh-ghostty-devlog-006#^f3]]
- benchmark against a do-nothing baseline (memcpy, noop) to see headroom, and report
  end-to-end separately: 7.3x in a microbenchmark became 2x on `cat`
  [[mitchellh-ghostty-devlog-006#^f4]], [[mitchellh-ghostty-devlog-006#^f5]]
- River: complexity for performance only with profiling evidence [[river-repo#^f4]]
- benchmarks read their inputs at runtime (env or args with defaults) so nothing
  constant-folds, and print a hash of the result so nothing is deleted
  [[matklad-do-not-optimize-away#^f4]], [[matklad-do-not-optimize-away#^f5]]:

```zig
// research/raw/matklad-do-not-optimize-away.md:64
fn benchmark(arena: Allocator) !void {
    const element_count =
        try parameter("element_count", 1_000_000);
    const search_count =
        try parameter("search_count", 10_000);

    const elements: []const u32 =
        make_elements(arena, element_count);
    const searches: []const u32 =
        make_searches(arena, search_count);

    const start = now();
    var hash: u32 = 0;
    for (searches) |key| {
        hash +%= insertion_point(elements, key);
    }
    const elapsed = now().duration_since(start);

    print("hash={}\n", .{hash});
    print("elapsed={}\n", .{elapsed});
}
```

- look for implicit copies and comptime bloat in `-femit-llvm-ir`
  [[tigerbeetle-blog-copy-hunting#^f2]]
- `@branchHint(.cold)` on rare paths (`grow`, empty map), `.likely` on buffered fast
  paths; each with a reason in a comment [[zig-std-containers#^f15]]
- zero-cost profiling hooks: ZLS's tracy calls compile to nothing when off
  [[zls-repo#^f29]]
- hash maps slow after many removals; array hash maps don't
  [[zig-014-release-notes#^f24]]; sorting is unstable pdqsort by default
  [[zig-011-release-notes#^f13]]
