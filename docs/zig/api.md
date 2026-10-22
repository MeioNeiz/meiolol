# 9. API and interface design

## 9.1 Dependencies positional, behaviour in options

Dependencies with unique types (`io`, `gpa`) go positionally with canonical names;
behaviour knobs go by name in an options struct [[matklad-aphorisms#^f6]],
[[tigerbeetle-tiger-style#^f34]]. Tiger Style: a function taking two `u64`s must use an
options struct, and pass library options explicitly so a changed default can't bite.

```zig
// research/raw/matklad-aphorisms.md:39
pub const HistoryOptions = struct {
    file: []const u8,

    pub fn from_environment(
        environment: *const std.process.Environ.Map,
    ) HistoryOptions;
};

pub fn readHistory(
    io: std.Io,
    gpa: Allocator,
    options: HistoryOptions,
) ReadHistoryError!void;
```

Ghostty's constructors all look like this [[ghostty-repo#^f51]]:

```zig
// ghostty src/terminal/Terminal.zig:281 @ 08a9518
pub const Options = struct {
    cols: size.CellCountInt,
    rows: size.CellCountInt,

    /// The maximum size of scrollback in bytes. Null is unlimited and zero
    /// disables scrollback.
    max_scrollback_bytes: ?usize = 10_000,
    ...
};

/// Initialize a new terminal.
pub fn init(
    io_impl: std.Io,
    alloc: Allocator,
    opts: Options,
) !Terminal {
```

## 9.2 Options structs and decl literals

Options structs default and document every independent field and are passed as `.{}` or
with one override; new options are non-breaking; small closed choices are inline
anonymous enums [[zig-std-json-fmt-args#^f1]]:

```zig
// ziglang/zig lib/std/json/static.zig:16 @ 0.17.0
/// Controls how to deal with various inconsistencies between the JSON document and the Zig struct type passed in.
/// For duplicate fields or unknown fields, set options in this struct.
/// For missing fields, give the Zig struct fields default values.
pub const ParseOptions = struct {
    /// Behaviour when a duplicate field is encountered.
    /// The default is to return `error.DuplicateField`.
    duplicate_field_behavior: enum {
        use_first,
        @"error",
        use_last,
    } = .@"error",

    /// If false, finding an unknown field returns `error.UnknownField`.
    ignore_unknown_fields: bool = false,
```

Initial states and presets are declarations reached with decl literals: `.empty`,
`.init`, `.default`, and calls like `.init(gpa)` [[zig-014-release-notes#^f5]],
[[seguin-decl-literals#^f2]]. The rule that reconciles the two: independent knobs as field
defaults, values that only make sense together as a declaration (idioms.md 4.13).

## 9.3 init/deinit for values, create/destroy for heap objects

```zig
// zls src/Server.zig:1347 @ 82ba5351
pub fn create(options: CreateOptions) std.mem.Allocator.Error!*Server {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();

    const io = options.io;
    const allocator = options.allocator;

    const server = try allocator.create(Server);
    errdefer allocator.destroy(server);

    server.* = .{
        .io = io,
        .allocator = allocator,
        .config_manager = options.config_manager,
        .document_store = .{
            .io = io,
            .allocator = allocator,
            .config = undefined, // set below
            .diagnostics_collection = &server.diagnostics_collection,
        },
```

A type whose children hold a pointer to it must live at a stable address: `create` it or
take `init(self: *T)`, never return it by value [[seguin-heap-value-address#^f1]]. Large
structs initialise in place through an out pointer [[tigerbeetle-tiger-style#^f39]].

Short-lived objects take options in and come out finished, with no undefined fields to
set afterwards; `std.process.spawn` replaced init-then-set-fields-then-spawn
[[zig-013-release-notes#^f1]], [[zig-016-release-notes#^f16]]:

```zig
// research/raw/zig-016-release-notes.md:1713
var child = try std.process.spawn(io, .{
        .argv = argv,
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    });
```

## 9.4 Return types: simpler is better

Tiger Style ranks them: `void` over `bool` over `u64` over `?u64` over `!u64`; each step
adds a branch at every call site [[tigerbeetle-tiger-style#^f41]].

## 9.5 Caller buffers and indexes

Don't pick a capacity for the caller: take a buffer, or allocate
[[zig-015-release-notes#^f24]]. For small outputs, return a slice of the caller's buffer
with an explicit `error.BufferTooSmall` [[ghostty-repo#^f20]]:

```zig
// ghostty src/os/homedir.zig:11 @ 08a9518
pub inline fn home(io: std.Io, environ_map: *const std.process.Environ.Map, buf: []u8) !?[]const u8 {
    return switch (builtin.target.os.tag) {
        .linux, .freebsd, .macos => try homeUnix(io, environ_map, buf),
        .windows => homeWindows(environ_map, buf) catch return error.BufferTooSmall,

        // iOS doesn't have a user-writable home directory
        .ios => null,

        else => @compileError("unimplemented"),
    };
}
```

For a stack buffer with list semantics, `ArrayList.initBuffer(&buf)` plus the
`*Bounded` methods (idioms.md 4.8). Return indexes rather than pointers: an index works for
const and mutable access and for parallel arrays [[matklad-random-numbers-included#^f3]].
Prefer streaming into a `*Io.Writer` over returning an allocated string
[[seguin-learning-zig-heap-memory#^f17]].

## 9.6 Push ifs up, fors down

Preconditions checked once by the caller (or the type) instead of in every callee;
control flow centralised where dead branches show; batch operations as the base case,
which amortise fixed costs and take branches out of loops [[matklad-push-ifs-up#^f1]],
[[matklad-push-ifs-up#^f4]]:

```
// research/raw/matklad-push-ifs-up.md:131
// GOOD
if condition {
  for walrus in walruses {
    walrus.frobnicate()
  }
} else {
  for walrus in walruses {
    walrus.transmogrify()
  }
}

// BAD
for walrus in walruses {
  if condition {
    walrus.frobnicate()
  } else {
    walrus.transmogrify()
  }
}
```

A "dissolving enum", built by one branch and matched by another, is the same condition
twice [[matklad-push-ifs-up#^f3]]. Tiger Style's version: the parent keeps control flow
and state, leaves are pure [[tigerbeetle-tiger-style#^f16]].

## 9.7 State in instances, not globals

So callers can have two, and so code is safe under any Io model
[[kristoff-talk-better-software#^f1]]. main creates resources and passes them down
(memory.md 5.2).

## 9.8 Interfaces: only when reuse pays

Kelley: "too many times I see less experienced programmers use interfaces or function
pointers when they could be simply calling functions directly"; function pointers are
opaque to the optimiser, and Zig has no interface sugar on purpose
[[zig-talk-kelley-flush#^f11]], [[zig-talk-roadmap-2026#^f11]]. The ladder:

1. a direct call
2. a closed set: tagged union with `inline else`, or a comptime-selected backend
   (comptime.md 8.8) [[seguin-interfaces#^f4]]
3. a generic over the dependency, with a public alias to the real type, as a zero-cost
   test seam [[seguin-generics-test-stubs#^f1]]
4. an open set: `ptr` plus `*const VTable`

The std's vtable shape, used by Allocator, Io, Writer and Reader
[[zig-std-allocators#^f1]], [[zig-std-allocators#^f4]]:

```zig
// ziglang/zig lib/std/heap/FixedBufferAllocator.zig:19 @ 0.17.0
pub fn allocator(self: *FixedBufferAllocator) Allocator {
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        },
    };
}
...
pub fn alloc(ctx: *anyopaque, n: usize, alignment: mem.Alignment, ra: usize) ?[*]u8 {
    const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
```

The interface holds `&self`, so the implementation must not move while in use.
TigerBeetle injects time the same way, which makes its simulator deterministic
[[tigerbeetle-code#^f29]]:

```zig
// tigerbeetle src/stdx/time.zig:17 @ 0450c32
pub const Time = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        monotonic: *const fn (*anyopaque) Instant,
        realtime: *const fn (*anyopaque) InstantUnix,
    };
```

Embedded interfaces recover their owner with `@fieldParentPtr`; River's Wayland
listeners are the textbook case [[river-repo#^f11]]:

```zig
// river river/XdgPopup.zig:22 @ 13752403
destroy: wl.Listener(void) = .init(handleDestroy),
commit: wl.Listener(*wlr.Surface) = .init(handleCommit),
...
fn handleDestroy(listener: *wl.Listener(void)) void {
    const xdg_popup: *XdgPopup = @fieldParentPtr("destroy", listener);

    xdg_popup.destroy.link.remove();
    xdg_popup.commit.link.remove();
    xdg_popup.new_popup.link.remove();
    xdg_popup.reposition.link.remove();

    util.gpa.destroy(xdg_popup);
}
```

Intrusive lists work the same way (`std.DoublyLinkedList.Node` as a field); "if you're
not already doing that, there's a good chance linked list is the wrong data structure"
[[zig-015-release-notes#^f21]]. Never hand-code field offsets
[[seguin-linkedlist-fieldparentptr#^f3]].

## 9.9 Typed indexes

`enum(u32) { _ }` gives a distinct integer type per index space at zero cost, and an
optional index with a `none = maxInt` tag stays 4 bytes where `?u32` is 8. Kelley uses it
"in all my projects" [[zig-devlog-2024#^f1]], [[zig-compiler-dod#^f4]]; ZLS, Roc and
matklad agree [[zls-repo#^f27]], [[matklad-newtype-index#^f6]].

```zig
// ziglang/zig lib/std/zig/Ast.zig:2937 @ 0.17.0
    /// Index into `nodes`, or null.
    pub const OptionalIndex = enum(u32) {
        root = 0,
        none = std.math.maxInt(u32),
        _,

        pub fn unwrap(oi: OptionalIndex) ?Index {
            return if (oi == .none) null else @fromBackingInt(@intCast(@backingInt(oi)));
        }

        pub fn fromOptional(oi: ?Index) OptionalIndex {
            return if (oi) |i| i.toOptional() else .none;
        }
    };
```

Doc-comment each index type with the array it indexes [[zig-devlog-2024#^f3]]. It is
not an encapsulation boundary: anyone can `@fromBackingInt` [[matklad-newtype-index#^f9]].

## 9.10 Format methods

Since 0.15 a format method takes only a writer and is selected with `{f}`; adding or
removing one used to change `{}` output silently. Variants come from `std.fmt.alt` or a
small wrapper struct; `{t}` prints tag names, `{B}` sizes, `{x}` hex
[[zig-015-release-notes#^f18]], [[zig-015-release-notes#^f20]]:

```zig
pub fn format(this: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void { ... }
```
