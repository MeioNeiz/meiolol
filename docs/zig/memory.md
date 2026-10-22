# 5. Memory: allocators, ownership, lifetimes

## 5.1 Every function that allocates takes an Allocator

No default allocator, no hidden allocation: the caller owns lifetime policy and the call
site shows which calls can allocate [[zig-langref-017-b#^f73]],
[[seguin-learning-zig-heap-memory#^f9]]. Libraries never choose. OOM is an error, not a
crash: the langref argues against "Linux overcommits anyway" (Windows, embedded, OOM
killer nondeterminism, reuse) [[zig-langref-017-b#^f16]].

```zig
// research/raw/zig-langref-017.md:13305
fn concat(allocator: Allocator, a: []const u8, b: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, a.len + b.len);
    @memcpy(result[0..a.len], a);
    @memcpy(result[a.len..], b);
    return result;
}
```

Order: dependencies first (`io`, `gpa`), positionally, then the specifics; writers last
[[matklad-aphorisms#^f6]], [[seguin-learning-zig-heap-memory#^f18]].

Exception seen in two apps over C libraries: one global (River `pub const gpa =
std.heap.c_allocator;`, Bun's mimalloc) [[river-repo#^f7]], [[bun-repo#^f7]]. It loses
`testing.allocator` leak checks, so pass it.

## 5.2 main owns the process resources (0.16+)

```zig
// research/raw/zig-016-release-notes.md:2030
pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const ptr = try gpa.create(i32);
    defer gpa.destroy(ptr);

    try std.Io.File.stdout().writeStreamingAll(io, "Hello, world!\n");

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    for (args, 0..) |arg, i| {
        std.log.info("arg[{d}] = {s}", .{ i, arg });
    }
```

What 0.17 `Init` holds [[zig-std-allocators#^f22]], [[zig-std-allocators#^f23]]:

```zig
// ziglang/zig lib/std/process.zig:31 @ 0.17.0
pub const Init = struct {
    /// `Init` is a superset of `Minimal`; the latter is included here.
    minimal: Minimal,
    /// Permanent storage for the entire process, cleaned automatically on
    /// exit. Threadsafe.
    arena: *std.heap.ArenaAllocator,
    /// A default-selected general purpose allocator for temporary heap
    /// allocations. Debug mode will set up leak checking if possible.
    /// Threadsafe.
    gpa: Allocator,
    /// An appropriate default Io implementation based on the target
    /// configuration. Debug mode will set up leak checking if possible.
    io: Io,
    /// Environment variables, initialized with `gpa`. Not threadsafe.
    environ_map: *Environ.Map,
```

`init.gpa` is SafeAllocator with a leak report in debug and safe builds, `c_allocator`
with libc, `smp_allocator` otherwise. Leaks are logged but do not change the exit code,
so CI that must fail on leaks needs `testing.allocator` [[zig-std-allocators#^f24]]. Use
`std.process.Init.Minimal` when you want to pick your own allocator and Io (ZLS does)
[[zls-repo#^f8]]. Environment goes down as values or `*const Environ.Map`, never read
from a global [[zig-016-release-notes#^f20]].

## 5.3 Choosing an allocator

The langref's chart, in order [[zig-langref-017-b#^f74]]:

1. A library: take an `Allocator` parameter.
2. Linking libc: `c_allocator` is reasonable.
3. Comptime-known maximum: `FixedBufferAllocator` (or just a buffer).
4. Run-to-completion CLI: one arena over `page_allocator`, freed at exit.
5. Cyclical work (frame, request, batch): an arena per cycle, or an FBA when bounded.
6. Testing OOM handling: `testing.FailingAllocator`.
7. Other tests: `testing.allocator`.
8. Otherwise: one general purpose allocator set up in main, passed down.
9. Fast builds: `smp_allocator`.

In 0.17 steps 8 and 9 are what `init.gpa` does for you. `page_allocator` is for big
blocks, never small allocations [[zigguide-allocators#^f1]]. `ThreadSafeAllocator` is
gone; thread safety comes from lock-free design (ArenaAllocator is now thread-safe), the
wrapper "is an anti-pattern" [[zig-016-release-notes#^f18]].

## 5.4 Unmanaged containers, `.empty`, allocator per call

Since 0.15 `std.ArrayList` stores no allocator; every allocating call takes one
[[zig-015-release-notes#^f22]], [[zig-std-containers#^f1]]. Why: one field less per
container (it adds up inside structs of many lists), the allocator a call uses is
visible, containers nest without copying it, and static initialisation works.
`ArrayListUnmanaged` is a deprecated alias; the managed form survives as deprecated
`array_list.Managed`.

```zig
// ziglang/zig lib/std/array_list.zig:655 @ 0.17.0
        /// An ArrayList containing no elements.
        pub const empty: Self = .{
            .items = &.{},
            .capacity = 0,
            .pointer_stability = .{},
        };
...
        /// Release all allocated memory.
        pub fn deinit(self: *Self, gpa: Allocator) void {
            self.pointer_stability.assertUnlocked();
            gpa.free(self.allocatedSlice());
            self.* = undefined;
        }
```

Use:

```zig
// ziglang/zig lib/init/src/main.zig:34 @ 0.17.0 (the zig init template)
test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
```

The hazard unmanaged creates: nothing checks that one container always gets the same
allocator. Bun built a CI-only `CheckedAllocator` for exactly that
[[bun-repo#^f10]]. Keep one allocator per container, named for its lifetime.

Hash maps in 0.17: `std.array_hash_map.Auto`, `.String`, `.Custom`, and `.empty`, not the
deprecated `AutoArrayHashMapUnmanaged` and `.{}` [[zig-std-containers#^f17]].

## 5.5 deinit takes `*Self` and poisons it

End `deinit` with `self.* = undefined`: in safe builds the bytes become 0xaa, so use
after deinit fails loudly (and Valgrind sees an undefined region)
[[zig-std-containers#^f4]], [[zls-repo#^f14]], [[mitchellh-ghostty-gtk-rewrite#^f5]].

```zig
// ghostty src/terminal/Terminal.zig:376 @ 08a9518
pub fn deinit(self: *Terminal, alloc: Allocator) void {
    self.tabstops.deinit(alloc);
    self.screens.deinit(alloc);
    self.colors.palette.deinit(alloc);
    self.pwd.deinit(alloc);
    self.title.deinit(alloc);
    self.glyph_glossary.deinit(alloc);
    if (self.kitty_dnd) |dnd| dnd.destroy(alloc);
    self.* = undefined;
}
```

Exception: handles commonly copied by value (ArenaAllocator, json `Parsed`) take `self`
by value and can't poison.

## 5.6 defer and errdefer: cleanup next to acquisition

`defer` for anything temporary, `errdefer` for anything you hand back, each on the line
after the acquisition [[zig-langref-017-b#^f7]]:

```zig
// research/raw/zig-langref-017.md:7206
fn createFoo(param: i32) !Foo {
    const foo = try tryToAllocateFoo();
    // now we have allocated foo. we need to free it if the function fails.
    // but we want to return it if the function succeeds.
    errdefer deallocateFoo(foo);

    const tmp_buf = allocateTmpBuffer() orelse return error.OutOfMemory;
    // tmp_buf is truly a temporary resource, and we for sure want to clean it up
    // before this block leaves scope
    defer deallocateTmpBuffer(tmp_buf);

    if (param > 1337) return error.InvalidParam;

    // here the errdefer will not run since we're returning success from the function.
    // but the defer will run!
    return foo;
}
```

Rules that follow:

- `defer` is per block: inside a loop body it runs every iteration
  [[zig-langref-017-a#^f116]].
- Add the last `errdefer` even when nothing fallible follows yet, so a future edit can't
  leak [[seguin-learning-zig-heap-memory#^f3]].
- **End an errdefer's scope where ownership moves**, or a later failure frees it twice.
  A callee's errdefer and the caller's never both run for one failure
  [[ziggit-errdefer-double-free#^f2]]:

```
// research/raw/ziggit-errdefer-double-free.md:108 (squeek502)
{
    var duped = allocator.dupe(u8, foo);
    errdefer allocator.free(duped);

    try something.takeOwnershipOf(duped);
}
// The errdefer is no longer active since it's block-scoped.

try someFunctionThatCanFail();
```

- TigerBeetle guards errdefers with an ownership flag once a parent takes over
  [[tigerbeetle-code#^f13]]:

```zig
// tigerbeetle src/vsr/replica.zig:667 @ 0450c32
            // Once initialized, the replica is responsible for deinitializing replica components.
            var initialized = false;

            self.superblock = try SuperBlock.init(
                allocator,
                storage,
                .{
                    .storage_size_limit = options.storage_size_limit,
                },
            );
            errdefer if (!initialized) self.superblock.deinit(allocator);
```

- matklad's warning: humans forget defers; "replace RAII with defer" code has resource
  bugs, so prefer designs with few owners (arenas, startup allocation) over more defers
  [[matklad-defer-patterns#^f1]], [[matklad-zig-and-rust#^f7]].
- A one-shot `main` may skip errdefers since the process exits on failure (River does)
  [[river-repo#^f9]]; never in code that others call.

## 5.7 Reserve first, then mutate infallibly

An error between two mutations leaves broken state. Reserve everything that can fail
first, then mutate with `*AssumeCapacity`, and mark the boundary with `errdefer comptime
unreachable` so the compiler rejects any fallible call added below it
[[matklad-reserve-first#^f4]], [[matklad-reserve-first#^f5]],
[[zig-std-containers#^f25]]. matklad found two real bugs of this kind, one in Ghostty and
one in Kelley's own talk code [[matklad-reserve-first#^f1]].

```zig
// research/raw/matklad-reserve-first.md:140 (fixed internString)
pub fn internString(
    state: *State,
    gpa: Allocator,
    bytes: []const u8,
) !String {
    try state.string_table.ensureUnusedCapacityContext(
        gpa,
        1,
        @as(String.TableContext, .{
        .bytes = state.string_bytes.items,
        }),
    );
    try state.string_bytes.ensureUnusedCapacity(gpa, bytes.len + 1);
    errdefer comptime unreachable; // End reservation phase.

    const gop = state.string_table.getOrPutAssumeCapacityAdapted(
        @as([]const u8, bytes),
        @as(String.TableIndexAdapter, .{
            .bytes = state.string_bytes.items,
        }),
    );
    if (gop.found_existing) return gop.key_ptr.*;
```

The std containers are built for this: each growing operation has three forms, `x`
(allocates), `xAssumeCapacity` (asserts) and `xBounded` (returns `error.OutOfMemory`
from a fixed buffer) [[zig-std-containers#^f6]], [[zig-std-containers#^f7]]. The std's
own hash map `grow` and Ghostty's `PageList.init` end their fallible phase the same way:

```zig
// ziglang/zig lib/std/hash_map.zig:1430 @ 0.17.0
        fn grow(self: *Self, allocator: Allocator, new_capacity: Size, ctx: Context) Allocator.Error!void {
            @branchHint(.cold);
            const new_cap = @max(new_capacity, minimal_capacity);
            assert(new_cap > self.capacity());
            assert(std.math.isPowerOfTwo(new_cap));

            var map: Self = .{};
            try map.allocate(allocator, new_cap);
            errdefer comptime unreachable;
            map.pointer_stability.lock();
            map.initMetadatas();
```

Review smell: an allocator and a `try` in the same scope after a mutation
[[matklad-look-for-bugs#^f4]].

## 5.8 Arenas for one-lifetime work

A request, a parse, a batch, a config: one `deinit` frees everything and callers stop
tracking frees [[seguin-leveraging-allocators#^f2]], [[zls-repo#^f17]] (ZLS has 92
`arena:` parameters). In loops, `reset(.retain_capacity)`: after the biggest iteration
there are no more backing allocations [[zig-std-allocators#^f13]].

```zig
// research/raw/seguin-leveraging-allocators.md:86 (http.zig)
  var arena = std.heap.ArenaAllocator.init(allocator);
  defer arena.deinit();

  while (queue.pop()) |conn| {
    // Here be magic!
    defer _ = arena.reset(.{.retain_with_limit = 8192});

    const action = worker.route(conn.req.url);
    action(arena.allocator(), conn.req, conn.res) catch { // TODO: 500 };
    worker.write(conn.res);
  }
```

Know the costs:

- arena `free` is a no-op unless it is the last allocation
  [[seguin-arena-free-nested#^f1]]
- growing an ArrayList inside an arena leaves every old buffer behind (up to ~3x
  memory): size it first with `initCapacity`, and don't interleave other allocations
  [[seguin-arena-arraylist#^f2]], [[seguin-arena-arraylist#^f4]]
- nesting arenas gains nothing; a library's internal arena should sit on a non-arena
  parent [[seguin-arena-free-nested#^f3]]
- copying a stateful struct by value loses allocations: pg.zig shipped `.arena = arena`
  and allocated through the local afterwards, so `deinit` freed nothing. Heap-allocate
  the arena, or store `ArenaAllocator.State` and `promote` it
  [[seguin-assigning-arenas#^f2]], [[seguin-assigning-arenas#^f5]]

## 5.9 Results that own many allocations carry their arena

Parse results point into many allocations; tying them to one arena gives one `deinit`.
A `*Leaky` variant makes the caller's arena the owner and says so in its name
[[zig-std-json-fmt-args#^f3]], [[zig-std-json-fmt-args#^f4]].

```zig
// ziglang/zig lib/std/json/static.zig:57 @ 0.17.0
pub fn Parsed(comptime T: type) type {
    return struct {
        arena: *ArenaAllocator,
        value: T,

        pub fn deinit(self: @This()) void {
            const allocator = self.arena.child_allocator;
            self.arena.deinit();
            allocator.destroy(self.arena);
        }
    };
}
```

zig-clap's parse `Result` and Ghostty's Config do the same [[zig-clap-repo#^f12]],
[[ghostty-repo#^f11]].

## 5.10 Pointers into containers are short-lived

`items[i]`, `getPtr`, `value_ptr` point into a backing array that moves on growth;
removed map slots become undefined. Any pointer into a container is invalid after any
mutation [[seguin-learning-zig-coding-in-zig#^f1]], [[ziggit-invalidate-pointers#^f1]].
Fixes: re-derive after mutation, copy with `get`, reserve first, store indexes or
handles (perf.md 12.3). The std now asserts it: hash maps have had pointer-stability
locks since 0.12, ArrayList gained `lockPointers()` in 0.17, which turns a silent
dangling slice into a panic [[zig-012-release-notes#^f17]], [[zig-017-release-notes#^f26]],
[[zig-devlog-2026#^f13]].

Stack memory dies with its frame: never return a slice of a local buffer
(`bufPrint(&local_buf, ...)` still compiles), and never hand `&local` to children in an
`init` that returns by value [[seguin-learning-zig-stack-memory#^f1]],
[[seguin-heap-value-address#^f1]]. Use a caller buffer, `init(self: *T)`, or `create`.

## 5.11 Ownership is stored, never inferred

Ghostty's largest leak (37 GB after 10 days) came from deciding pool-or-mmap ownership
from page size, which a fast path then changed. The fix is a field every construction
site must set [[mitchellh-ghostty-memory-leak-fix#^f4]], [[ghostty-repo#^f18]]:

```zig
// ghostty src/terminal/PageList.zig:65 @ 08a9518
    /// How the backing memory of the embedded Page was allocated. Pool-owned
    /// memory is always a full standard-size item from the memory
    /// pool, regardless of the page layout size. Heap-owned memory
    /// is allocated directly with the page allocator and is exactly
    /// `Page.memory.len` bytes.
    ///
    /// This must never be inferred from the memory length: heap-owned
    /// pages can be smaller than the standard size (e.g. compacted
    /// pages), and returning one to the pool would corrupt it.
    ///
    /// This has no default on purpose so that every construction site
    /// is forced to make an explicit decision.
    owned: Owned,
```

Document every returned pointer's owner and lifetime ("The caller owns the returned
memory.") [[zig-langref-017-b#^f81]].

## 5.12 Hash map keys

Keys must outlive the map. The owner dupes them, only on insert, and frees them before
`deinit`; the map can't, because keys may be literals or from another allocator
[[seguin-learning-zig-coding-in-zig#^f4]], [[seguin-getorput-string-keys#^f4]]. For
upserts, `getOrPut` with the borrowed key, then dupe on miss; to stay correct if the
dupe fails, use the early-return shape:

```
// research/raw/ziggit-errdefer-scope.md:85
const gop = try map.getOrPut(key);
if (gop.found_existing) return;
errdefer _ = map.swapRemove(key);

gop.value_ptr.* = try SomeValue.init(allocator);
errdefer gop.value_ptr.deinit();
```

## 5.13 Limits on everything

Tiger Style: put a limit on everything, every loop and queue gets an upper bound, so
runaway work fails fast and overload gets backpressure [[tigerbeetle-tiger-style#^f4]].
The std bounds every read from outside: `allocRemaining(gpa, limit)`, 4 MiB json values
by default [[zig-std-io#^f23]], [[zig-std-json-fmt-args#^f9]]. Never trust a length field
from input [[liptak-fuzz-allocators#^f1]]. matklad's bounded loop (safety.md 7.6) is the
same idea in the small.

## 5.14 Static allocation: TigerBeetle's rule and its scope

TigerBeetle allocates everything at startup and forbids allocation afterwards, enforced
by an allocator that asserts once switched to static [[tigerbeetle-code#^f10]]:

```zig
// tigerbeetle src/static_allocator.zig:58 @ 0450c32
fn alloc(ctx: *anyopaque, len: usize, ptr_align: Alignment, ret_addr: usize) ?[*]u8 {
    const self: *StaticAllocator = @ptrCast(@alignCast(ctx));
    assert(self.state == .init);
    return self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
}
```

Why it works for them: every input is bounded (connections, message size, 8k-item
batches, two record types), and storage growth goes to disk
[[tigerbeetle-blog-no-dynamic-memory#^f5]]. matklad: it composes only when inputs and
outputs are bounded; compilers (and batch statistics) are not, and his sketch for them is
an O(N) output arena plus O(1) scratch per chunk [[matklad-static-alloc-compilers#^f8]].

What transfers to ordinary apps is the forcing function: a named maximum for every
buffer, allocation in an init phase per job, `AssumeCapacity` in the loop, and passing
the allocator to `init` only so the loop provably cannot allocate
[[matklad-static-alloc-constant-work#^f4]], [[matklad-zig-and-rust#^f10]].

## 5.15 OOM policy

std and the langref: OOM is a recoverable error, propagate it. matklad: in applications,
consider aborting; he has seen one app whose errdefers held up
[[matklad-reserve-first#^f9]]. The std itself splits by context: `Build.zig` does
`catch @panic("OOM")` 58 times because a failed build script has nothing to recover
[[zig-std-json-fmt-args#^f20]]. A reasonable line: library-shaped code propagates;
one-shot tools may panic; reserve-first stays either way because it protects invariants
against every error, not just OOM.
