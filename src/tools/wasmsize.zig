//! wasmsize: each ui.wasm family's gzip size against the last pushed main's and its
//! budget; on growth over a threshold or a failure, which functions grew, the source
//! files they come from and, for std code, which of ours calls it.
//!
//! The baseline is a store of earlier runs, one file per commit
//! (<git common dir>/meiolol-wasm-sizes/<sha>), written by --record when the tree is
//! clean (pre-push ci's build tree) and every family is within budget (a failed save only
//! warns), and looked up for origin/main or its nearest recorded first-parent ancestor. Symbols come from a build with a name section (strip = false);
//! the shipped size is that module minus its custom sections, or a stripped build if one
//! is given.
//!
//! usage: wasmsize [--tree DIR] [--store DIR] [--std DIR] [--record] [--threshold BYTES] [--base REV]
//!          NAME BUDGET WASM NAMED_WASM [NAME BUDGET WASM NAMED_WASM...]
//!        wasmsize --list NAMED_WASM: every function, biggest first
//!        wasmsize --numbers NAMED_WASM: std's number formatting in it, and which of our
//!          functions keep each piece alive
//! WASM or NAMED_WASM may be "-" (no symbols, or the shipped size from NAMED_WASM)

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const usage = "usage: wasmsize [--tree DIR] [--store DIR] [--std DIR] [--record] [--threshold BYTES] " ++
    "[--base REV] NAME BUDGET WASM NAMED_WASM...\n";

/// Families recorded per commit: older files are deleted past this
const keep = 40;
/// Lines of changed symbols per family in a report
const max_lines = 12;
/// Our source roots, to name a symbol's file: the names carry no module (`tree.H.fmt`,
/// `champmore.loaded` for src/site/ui/wasm/champmore.zig)
const our_roots = [_][]const u8{ "src/site/ui", "src/site/ui/wasm", "src/tpl", "src/core" };

const Family = struct {
    name: []const u8,
    budget: u64,
    raw: u64 = 0,
    gz: u64 = 0,
    /// Normalised symbol name to its bytes and instances
    syms: std.StringArrayHashMapUnmanaged(Sym) = .empty,
    module: ?Module = null,
};

const Sym = struct { bytes: u64 = 0, count: u32 = 0 };

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    var tree: []const u8 = ".";
    var store: ?[]const u8 = null;
    var std_dir: ?[]const u8 = null;
    var record = false;
    var threshold: u64 = 200;
    var base_rev: []const u8 = "origin/main";
    var fams: std.ArrayList(Family) = .empty;
    var files: std.ArrayList([2][]const u8) = .empty;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.eql(u8, a, "--record")) {
            record = true;
        } else if (std.mem.eql(u8, a, "--list")) {
            if (i + 1 >= argv.len) fail("--list needs a wasm", .{});
            return listFuncs(io, arena, argv[i + 1]);
        } else if (std.mem.eql(u8, a, "--numbers")) {
            if (i + 1 >= argv.len) fail("--numbers needs a wasm", .{});
            return numbers(io, arena, tree, std_dir, argv[i + 1]);
        } else if (std.mem.startsWith(u8, a, "--")) {
            if (i + 1 >= argv.len) fail("{s} needs a value", .{a});
            i += 1;
            const v = argv[i];
            if (std.mem.eql(u8, a, "--tree")) {
                tree = v;
            } else if (std.mem.eql(u8, a, "--store")) {
                store = v;
            } else if (std.mem.eql(u8, a, "--std")) {
                std_dir = v;
            } else if (std.mem.eql(u8, a, "--base")) {
                base_rev = v;
            } else if (std.mem.eql(u8, a, "--threshold")) {
                threshold = std.fmt.parseInt(u64, v, 10) catch fail("--threshold: not a number", .{});
            } else fail("unknown option {s}", .{a});
        } else {
            if (i + 3 >= argv.len) fail("{s}: NAME BUDGET WASM NAMED_WASM", .{a});
            const budget = std.fmt.parseInt(u64, argv[i + 1], 10) catch fail("{s}: budget not a number", .{a});
            try fams.append(arena, .{ .name = a, .budget = budget });
            try files.append(arena, .{ argv[i + 2], argv[i + 3] });
            i += 3;
        }
    }
    if (fams.items.len == 0) fail("", .{});

    const store_dir = store orelse try storeDir(io, arena, tree);
    for (fams.items, files.items) |*f, paths| try measure(io, arena, f, paths[0], paths[1]);
    const base = try findBase(io, arena, tree, store_dir, base_rev);
    var out_buf: [4096]u8 = undefined;
    var out_file = Io.File.stdout().writerStreaming(io, &out_buf);
    const out = &out_file.interface;
    var res: Resolver = .{ .io = io, .arena = arena, .tree = tree, .std_dir = std_dir orelse stdDir(io, arena) };
    try report(arena, out, fams.items, base, threshold, &res);
    try out.flush();

    for (fams.items) |f| if (f.gz > f.budget) std.process.exit(1);
    // Only sizes within budget become a baseline; the sizes are checked either way
    if (record) if (try cleanHead(io, arena, tree)) |sha| save(io, arena, store_dir, sha, fams.items) catch |err|
        std.debug.print("wasmsize: baseline for {s} not saved in {s}: {t}\n", .{ sha[0..8], store_dir, err });
}

/// Every function, biggest first, with the file it comes from
fn listFuncs(io: Io, arena: Allocator, path: []const u8) !void {
    const m = try parse(arena, try readFile(io, arena, path));
    std.mem.sort(Func, m.funcs, {}, struct {
        fn more(_: void, a: Func, b: Func) bool {
            return a.size > b.size;
        }
    }.more);
    var buf: [4096]u8 = undefined;
    var out_file = Io.File.stdout().writerStreaming(io, &buf);
    const out = &out_file.interface;
    for (m.funcs) |f| try out.print("{d} {s}\n", .{ f.size, f.name });
    try out.flush();
}

/// std number formatting: Writer.print's instances and what they reach
fn isFormatter(name: []const u8) bool {
    return std.mem.startsWith(u8, name, "Io.Writer.print") or std.mem.startsWith(u8, name, "fmt.format") or
        std.mem.startsWith(u8, name, "fmt.float");
}

/// Generic wrappers of ours whose instances belong to their call sites (one per format
/// string): a call is followed through them to the component
const pass_through = [_][]const u8{"tree.H.fmt"};

fn passThrough(name: []const u8) bool {
    for (pass_through) |p| if (std.mem.eql(u8, name, p)) return true;
    return false;
}

fn numbers(io: Io, arena: Allocator, tree: []const u8, std_dir: ?[]const u8, path: []const u8) !void {
    const m = try parse(arena, try readFile(io, arena, path));
    var res: Resolver = .{ .io = io, .arena = arena, .tree = tree, .std_dir = std_dir orelse stdDir(io, arena) };
    const n = m.funcs.len;
    // Owners: our functions (not pass-through) that reach a function through std and
    // pass-through code only
    const owner = try arena.alloc(bool, n);
    for (m.funcs, 0..) |f, k| {
        const name = f.key;
        owner[k] = res.ours(name) and !passThrough(name);
    }
    const owners = try arena.alloc(std.ArrayList(u32), n);
    for (owners) |*o| o.* = .empty;
    const seen = try arena.alloc(u32, n);
    @memset(seen, std.math.maxInt(u32));
    var stack: std.ArrayList(u32) = .empty;
    for (0..n) |c| if (owner[c]) {
        stack.clearRetainingCapacity();
        try stack.append(arena, @intCast(c));
        seen[c] = @intCast(c);
        while (stack.pop()) |k| for (m.funcs[k].calls) |callee| {
            if (callee < m.imported or callee - m.imported >= n) continue;
            const g = callee - m.imported;
            if (owner[g] or seen[g] == c) continue;
            seen[g] = @intCast(c);
            try owners[g].append(arena, @intCast(c));
            try stack.append(arena, g);
        };
    };
    var buf: [4096]u8 = undefined;
    var out_file = Io.File.stdout().writerStreaming(io, &buf);
    const out = &out_file.interface;
    var total: u64 = 0;
    var excl: std.AutoArrayHashMapUnmanaged(u32, u64) = .empty;
    try out.writeAll("std number formatting (raw bytes; gz is about a third), and what keeps it:\n");
    var order: std.ArrayList(u32) = .empty;
    for (m.funcs, 0..) |f, k| if (isFormatter(f.key)) try order.append(arena, @intCast(k));
    std.mem.sort(u32, order.items, m, struct {
        fn more(mm: Module, a: u32, b: u32) bool {
            return mm.funcs[a].size > mm.funcs[b].size;
        }
    }.more);
    for (order.items) |k| {
        const f = m.funcs[k];
        total += f.size;
        try out.print("  {d:>5} {s}\n        kept by: ", .{ f.size, f.name });
        if (owners[k].items.len == 0) try out.writeAll("(no direct caller of ours: a vtable)");
        var names: std.StringArrayHashMapUnmanaged(u32) = .empty;
        for (owners[k].items) |o| (try names.getOrPutValue(arena, m.funcs[o].key, 0)).value_ptr.* += 1;
        for (names.keys(), names.values(), 0..) |name, count, j| {
            if (j > 0) try out.writeAll(", ");
            try out.writeAll(name);
            if (count > 1) try out.print(" x{d}", .{count});
        }
        try out.writeAll("\n");
        if (owners[k].items.len == 1) (try excl.getOrPutValue(arena, owners[k].items[0], 0)).value_ptr.* += f.size;
    }
    try out.print("  {d} B raw in all\n\nours, by formatter bytes only they keep:\n", .{total});
    excl.sort(struct {
        v: []const u64,
        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return ctx.v[a] > ctx.v[b];
        }
    }{ .v = excl.values() });
    for (excl.keys(), excl.values()) |o, v| {
        const name = m.funcs[o].key;
        try out.print("  {d:>5} {s}", .{ v, name });
        if (try res.place(name)) |p| try out.print("  {s}", .{p.file});
        try out.writeAll("\n");
    }
    if (m.unparsed > 0) try out.print("({d} functions with opcodes not followed: their calls are missing)\n", .{m.unparsed});
    try out.flush();
}

fn fail(comptime f: []const u8, args: anytype) noreturn {
    std.debug.print("wasmsize: " ++ f ++ "\n" ++ usage, args);
    std.process.exit(2);
}

fn measure(io: Io, arena: Allocator, f: *Family, wasm: []const u8, named: []const u8) !void {
    const have_named = !std.mem.eql(u8, named, "-");
    const have_wasm = !std.mem.eql(u8, wasm, "-");
    const shipped: []const u8 = if (have_wasm)
        try readFile(io, arena, wasm)
    else if (have_named)
        try stripCustom(arena, try readFile(io, arena, named))
    else
        fail("{s}: no wasm", .{f.name});
    f.raw = shipped.len;
    f.gz = try gzipSize(arena, shipped);
    if (!have_named) return;
    const m = try parse(arena, try readFile(io, arena, named));
    f.module = m;
    for (m.funcs) |fn_| {
        const g = try f.syms.getOrPut(arena, fn_.key);
        if (!g.found_existing) g.value_ptr.* = .{};
        g.value_ptr.bytes += fn_.size;
        g.value_ptr.count += 1;
    }
    // Data and the rest grow too (string literals, tables)
    try f.syms.put(arena, "[data]", .{ .bytes = m.data, .count = 1 });
    try f.syms.put(arena, "[other sections]", .{ .bytes = m.other, .count = 1 });
}

fn readFile(io: Io, arena: Allocator, path: []const u8) ![]u8 {
    return Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20)) catch |err|
        fail("{s}: {t}", .{ path, err });
}

/// The .gz nginx serves: the site writer's own flate (src/store/raw.zig compressWith,
/// .default), so the same number on every host (Apple and GNU gzip -9 differ by ~20 B)
fn gzipSize(arena: Allocator, bytes: []const u8) !u64 {
    const flate = std.compress.flate;
    const window = try arena.alloc(u8, flate.max_window_len);
    var out: Io.Writer.Allocating = try .initCapacity(arena, @max(64, bytes.len / 2));
    var c = try flate.Compress.init(&out.writer, window, .gzip, .default);
    try c.writer.writeAll(bytes);
    try c.finish();
    return out.written().len;
}

// The wasm module: function names and body sizes, and who calls whom

const Func = struct {
    name: []const u8,
    /// The name without instance numbers (normalise)
    key: []const u8,
    /// Body bytes with its size prefix
    size: u32,
    calls: []u32,
};

const Module = struct {
    /// Defined functions only; a call's index is into imports then these
    imported: u32,
    funcs: []Func,
    data: u64,
    other: u64,
    /// Bodies with an opcode calls() doesn't know: their calls are missing
    unparsed: u32,
};

fn parse(arena: Allocator, bytes: []const u8) !Module {
    if (bytes.len < 8 or !std.mem.eql(u8, bytes[0..4], "\x00asm")) return error.NotWasm;
    var r: Io.Reader = .fixed(bytes[8..]);
    var imported: u32 = 0;
    var names: std.AutoHashMapUnmanaged(u32, []const u8) = .empty;
    var funcs: []Func = &.{};
    var data: u64 = 0;
    var other: u64 = 0;
    var unparsed: u32 = 0;
    while (r.seek < r.end) {
        const id = try r.takeByte();
        const len = try r.takeLeb128(u32);
        const start = r.seek;
        const body = try r.take(len);
        var s: Io.Reader = .fixed(body);
        switch (id) {
            2 => {
                const n = try s.takeLeb128(u32);
                for (0..n) |_| {
                    _ = try s.take(try s.takeLeb128(u32));
                    _ = try s.take(try s.takeLeb128(u32));
                    const kind = try s.takeByte();
                    switch (kind) {
                        0 => {
                            _ = try s.takeLeb128(u32);
                            imported += 1;
                        },
                        1 => {
                            _ = try s.takeByte();
                            try skipLimits(&s);
                        },
                        2 => try skipLimits(&s),
                        3 => _ = try s.take(2),
                        else => return error.BadImport,
                    }
                }
                other += r.seek - start;
            },
            10 => {
                const n = try s.takeLeb128(u32);
                funcs = try arena.alloc(Func, n);
                for (funcs) |*f| {
                    const at = s.seek;
                    const size = try s.takeLeb128(u32);
                    const code = try s.take(size);
                    f.* = .{
                        .name = "",
                        .key = "",
                        .size = @intCast(s.seek - at),
                        .calls = calls(arena, code) catch blk: {
                            unparsed += 1;
                            break :blk &.{};
                        },
                    };
                }
            },
            11 => data += r.seek - start,
            0 => {
                const name = try s.take(try s.takeLeb128(u32));
                if (std.mem.eql(u8, name, "name")) try readNames(arena, &s, &names);
            },
            else => other += r.seek - start,
        }
    }
    for (funcs, 0..) |*f, k| {
        f.name = names.get(imported + @as(u32, @intCast(k))) orelse
            try std.fmt.allocPrint(arena, "[func {d}]", .{imported + k});
        f.key = try normalise(arena, f.name);
    }
    return .{ .imported = imported, .funcs = funcs, .data = data, .other = other, .unparsed = unparsed };
}

fn skipLimits(s: *Io.Reader) !void {
    const flags = try s.takeByte();
    _ = try s.takeLeb128(u64);
    if (flags & 1 != 0) _ = try s.takeLeb128(u64);
}

fn readNames(arena: Allocator, s: *Io.Reader, names: *std.AutoHashMapUnmanaged(u32, []const u8)) !void {
    while (s.seek < s.end) {
        const id = try s.takeByte();
        const len = try s.takeLeb128(u32);
        const sub = try s.take(len);
        if (id != 1) continue;
        var t: Io.Reader = .fixed(sub);
        const n = try t.takeLeb128(u32);
        for (0..n) |_| {
            const idx = try t.takeLeb128(u32);
            const name = try t.take(try t.takeLeb128(u32));
            try names.put(arena, idx, name);
        }
    }
}

/// The function indexes a body calls. Errors on an opcode it doesn't know (SIMD,
/// atomics): that function then shows no callees
fn calls(arena: Allocator, code: []const u8) ![]u32 {
    var s: Io.Reader = .fixed(code);
    var out: std.ArrayList(u32) = .empty;
    const groups = try s.takeLeb128(u32);
    for (0..groups) |_| {
        _ = try s.takeLeb128(u32);
        _ = try s.takeByte();
    }
    while (s.seek < s.end) {
        const op = try s.takeByte();
        switch (op) {
            0x00, 0x01, 0x05, 0x0B, 0x0F, 0x1A, 0x1B, 0xD1 => {},
            0x45...0xC4 => {},
            0x02, 0x03, 0x04 => {
                const t = try s.peekByte();
                if (t == 0x40 or (t >= 0x6F and t <= 0x7F)) s.toss(1) else _ = try s.takeLeb128(i64);
            },
            0x0C, 0x0D, 0x20...0x26, 0xD2 => _ = try s.takeLeb128(u32),
            0x0E => {
                const n = try s.takeLeb128(u32);
                for (0..n + 1) |_| _ = try s.takeLeb128(u32);
            },
            0x10, 0x12 => try out.append(arena, try s.takeLeb128(u32)),
            0x11, 0x13 => {
                _ = try s.takeLeb128(u32);
                _ = try s.takeLeb128(u32);
            },
            0x1C => _ = try s.take(try s.takeLeb128(u32)),
            0x28...0x3E => {
                _ = try s.takeLeb128(u32);
                _ = try s.takeLeb128(u64);
            },
            0x3F, 0x40 => _ = try s.takeLeb128(u32),
            0x41 => _ = try s.takeLeb128(i32),
            0x42 => _ = try s.takeLeb128(i64),
            0x43 => _ = try s.take(4),
            0x44 => _ = try s.take(8),
            0xD0 => _ = try s.takeByte(),
            0xFC => switch (try s.takeLeb128(u32)) {
                0...7 => {},
                8 => {
                    _ = try s.takeLeb128(u32);
                    _ = try s.takeByte();
                },
                9, 13, 15, 16, 17 => _ = try s.takeLeb128(u32),
                10, 12, 14 => {
                    _ = try s.takeLeb128(u32);
                    _ = try s.takeLeb128(u32);
                },
                11 => _ = try s.takeByte(),
                else => return error.UnknownOp,
            },
            else => return error.UnknownOp,
        }
    }
    return out.items;
}

/// The module as shipped: custom sections (names, debug info) dropped
fn stripCustom(arena: Allocator, bytes: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(arena, bytes[0..8]);
    var r: Io.Reader = .fixed(bytes[8..]);
    while (r.seek < r.end) {
        const at = r.seek;
        const id = try r.takeByte();
        const len = try r.takeLeb128(u32);
        _ = try r.take(len);
        if (id != 0) try out.appendSlice(arena, bytes[8 + at .. 8 + r.seek]);
    }
    return out.items;
}

/// A generic's instances under one name: `Io.Writer.print__func_336` and
/// `tree.H.on__func_609.thunk.call` lose their numbers, which change from build to build
fn normalise(arena: Allocator, name: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var k: usize = 0;
    outer: while (k < name.len) {
        if (std.mem.startsWith(u8, name[k..], "__")) {
            var e = k + 2;
            for ([_][]const u8{ "anon_", "func_", "struct_", "union_", "enum_", "opaque_" }) |pre| {
                if (std.mem.startsWith(u8, name[e..], pre)) e += pre.len;
            }
            const digits = e;
            while (e < name.len and std.ascii.isDigit(name[e])) e += 1;
            const ends = e == name.len or std.mem.startsWith(u8, name[e..], "__") or
                !std.ascii.isAlphanumeric(name[e]) and name[e] != '_';
            if (e > digits and ends) {
                k = e;
                continue :outer;
            }
        }
        try out.append(arena, name[k]);
        k += 1;
    }
    return out.items;
}

// The baseline store

fn git(io: Io, arena: Allocator, tree: []const u8, args: []const []const u8) ?[]const u8 {
    const argv = std.mem.concat(arena, []const u8, &.{ &.{ "git", "-C", tree }, args }) catch return null;
    const r = std.process.run(arena, io, .{ .argv = argv }) catch return null;
    if (r.term != .exited or r.term.exited != 0) return null;
    return std.mem.trim(u8, r.stdout, " \n");
}

fn storeDir(io: Io, arena: Allocator, tree: []const u8) ![]const u8 {
    const common = git(io, arena, tree, &.{ "rev-parse", "--path-format=absolute", "--git-common-dir" }) orelse
        fail("{s}: not a git tree (pass --store)", .{tree});
    return std.fs.path.join(arena, &.{ common, "meiolol-wasm-sizes" });
}

const Base = struct {
    sha: []const u8,
    /// Commits between base_rev and the recorded one
    behind: usize,
    fams: std.StringArrayHashMapUnmanaged(Family),
};

fn findBase(io: Io, arena: Allocator, tree: []const u8, store: []const u8, rev: []const u8) !?Base {
    const list = git(io, arena, tree, &.{ "rev-list", "--first-parent", "-n", "50", rev }) orelse return null;
    var it = std.mem.tokenizeScalar(u8, list, '\n');
    var behind: usize = 0;
    while (it.next()) |sha| : (behind += 1) {
        const path = try std.fs.path.join(arena, &.{ store, sha });
        const text = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20)) catch continue;
        if (!std.mem.startsWith(u8, text, store_version)) continue;
        return .{ .sha = sha, .behind = behind, .fams = try load(arena, text) };
    }
    return null;
}

/// The first line of a store file: a new one when sizes or names are measured differently
const store_version = "v 2\n";

/// Lines `f NAME RAW GZ` and `s NAME BYTES COUNT SYMBOL` after store_version
fn load(arena: Allocator, text: []const u8) !std.StringArrayHashMapUnmanaged(Family) {
    var fams: std.StringArrayHashMapUnmanaged(Family) = .empty;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        var cols = std.mem.splitScalar(u8, line, ' ');
        const kind = cols.next() orelse continue;
        const name = cols.next() orelse continue;
        if (std.mem.eql(u8, kind, "f")) {
            const raw = std.fmt.parseInt(u64, cols.next() orelse continue, 10) catch continue;
            const gz = std.fmt.parseInt(u64, cols.next() orelse continue, 10) catch continue;
            try fams.put(arena, name, .{ .name = name, .budget = 0, .raw = raw, .gz = gz });
        } else if (std.mem.eql(u8, kind, "s")) {
            const f = fams.getPtr(name) orelse continue;
            const bytes = std.fmt.parseInt(u64, cols.next() orelse continue, 10) catch continue;
            const count = std.fmt.parseInt(u32, cols.next() orelse continue, 10) catch continue;
            try f.syms.put(arena, cols.rest(), .{ .bytes = bytes, .count = count });
        }
    }
    return fams;
}

/// HEAD's sha when the tree has no changes: only then are the sizes that commit's
fn cleanHead(io: Io, arena: Allocator, tree: []const u8) !?[]const u8 {
    const status = git(io, arena, tree, &.{ "status", "--porcelain", "--untracked-files=no" }) orelse return null;
    if (status.len != 0) return null;
    return git(io, arena, tree, &.{ "rev-parse", "HEAD" });
}

fn save(io: Io, arena: Allocator, store: []const u8, sha: []const u8, fams: []const Family) !void {
    var text: Io.Writer.Allocating = .init(arena);
    const w = &text.writer;
    try w.writeAll(store_version);
    for (fams) |f| {
        try w.print("f {s} {d} {d}\n", .{ f.name, f.raw, f.gz });
        for (f.syms.keys(), f.syms.values()) |k, v| try w.print("s {s} {d} {d} {s}\n", .{ f.name, v.bytes, v.count, k });
    }
    try Io.Dir.cwd().createDirPath(io, store);
    var dir = try Io.Dir.cwd().openDir(io, store, .{ .iterate = true });
    defer dir.close(io);
    const tmp = try std.fmt.allocPrint(arena, "{s}.tmp", .{sha});
    try dir.writeFile(io, .{ .sub_path = tmp, .data = text.written() });
    try dir.rename(tmp, dir, sha, io);
    try prune(io, arena, dir);
}

fn prune(io: Io, arena: Allocator, dir: Io.Dir) !void {
    const Entry = struct { name: []const u8, mtime: i96 };
    var all: std.ArrayList(Entry) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .file) continue;
        const st = dir.statFile(io, e.name, .{}) catch continue;
        try all.append(arena, .{ .name = try arena.dupe(u8, e.name), .mtime = st.mtime.nanoseconds });
    }
    if (all.items.len <= keep) return;
    std.mem.sort(Entry, all.items, {}, struct {
        fn newer(_: void, a: Entry, b: Entry) bool {
            return a.mtime > b.mtime;
        }
    }.newer);
    for (all.items[keep..]) |e| dir.deleteFile(io, e.name) catch {};
}

// The report

fn report(arena: Allocator, out: *Io.Writer, fams: []Family, base: ?Base, threshold: u64, res: *Resolver) !void {
    if (base) |b| {
        try out.print("ui.wasm gzip sizes vs {s}", .{b.sha[0..8]});
        if (b.behind > 0) try out.print(" ({d} commits before origin/main: the newest recorded)", .{b.behind});
        try out.writeAll("\n");
    } else try out.writeAll("ui.wasm gzip sizes (no recorded baseline for origin/main or its 50 ancestors)\n");
    var width: usize = 0;
    for (fams) |f| width = @max(width, f.name.len);
    var flagged: std.ArrayList(usize) = .empty;
    for (fams, 0..) |f, k| {
        const old = if (base) |b| b.fams.get(f.name) else null;
        const pct = f.gz * 100 / f.budget;
        try out.print("  {s}", .{f.name});
        try out.splatByteAll(' ', width - f.name.len);
        try out.print(" {d:>6} B gz {d:>3}% of {d} KB", .{ f.gz, pct, f.budget / 1024 });
        var grew = false;
        if (old) |o| {
            const d = @as(i64, @intCast(f.gz)) - @as(i64, @intCast(o.gz));
            if (d != 0) try out.print("  {s}{d} B", .{ if (d > 0) "+" else "", d });
            grew = d >= @as(i64, @intCast(threshold));
        } else if (base != null) try out.writeAll("  (new)");
        if (f.gz > f.budget) {
            try out.print("  OVER BUDGET by {d} B", .{f.gz - f.budget});
        } else if (pct >= 90) try out.writeAll("  (90% of budget)");
        try out.writeAll("\n");
        if (grew or f.gz > f.budget) try flagged.append(arena, k);
    }
    for (flagged.items) |k| try explain(arena, out, &fams[k], if (base) |b| b.fams.get(fams[k].name) else null, res);
    if (base) |b| try shared(arena, out, fams, flagged.items, b, res);
}

/// What grew in several flagged families at once: a shared component, the usual cause
/// when many go up together (d803924c: champ.view in all 37)
fn shared(arena: Allocator, out: *Io.Writer, fams: []Family, flagged: []const usize, base: Base, res: *Resolver) !void {
    if (flagged.len < 3) return;
    const Grew = struct { families: u32 = 0, bytes: i64 = 0 };
    var all: std.StringArrayHashMapUnmanaged(Grew) = .empty;
    for (flagged) |k| {
        const o = base.fams.get(fams[k].name) orelse continue;
        if (fams[k].module == null or o.syms.count() == 0) continue;
        for (try diff(arena, &fams[k], o)) |c| {
            if (delta(c) < 64 or c.name[0] == '[') continue;
            const g = try all.getOrPutValue(arena, c.name, .{});
            g.value_ptr.families += 1;
            g.value_ptr.bytes += delta(c);
        }
    }
    all.sort(struct {
        v: []const Grew,
        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return ctx.v[a].families > ctx.v[b].families or
                (ctx.v[a].families == ctx.v[b].families and ctx.v[a].bytes > ctx.v[b].bytes);
        }
    }{ .v = all.values() });
    var shown: usize = 0;
    for (all.keys(), all.values()) |name, g| {
        if (g.families * 3 < flagged.len or shown == max_lines) break;
        if (shown == 0) try out.print("\nGrew in most of the {d} families above (a shared component):\n", .{flagged.len});
        shown += 1;
        try out.print("  {s}: in {d}, ~{d} B raw each", .{ name, g.families, @divTrunc(g.bytes, g.families) });
        if (try res.place(name)) |p| try out.print("  {s}", .{p.file});
        try out.writeAll("\n");
    }
}

const Change = struct { name: []const u8, now: Sym, was: Sym };

/// Symbols whose bytes differ from the baseline's, most grown first
fn diff(arena: Allocator, f: *const Family, o: Family) ![]Change {
    var changes: std.ArrayList(Change) = .empty;
    for (f.syms.keys(), f.syms.values()) |name, now| {
        const was = o.syms.get(name) orelse Sym{};
        if (now.bytes != was.bytes) try changes.append(arena, .{ .name = name, .now = now, .was = was });
    }
    for (o.syms.keys(), o.syms.values()) |name, was| {
        if (!f.syms.contains(name)) try changes.append(arena, .{ .name = name, .now = .{}, .was = was });
    }
    std.mem.sort(Change, changes.items, {}, struct {
        fn more(_: void, a: Change, b: Change) bool {
            return delta(a) > delta(b);
        }
    }.more);
    return changes.items;
}

fn explain(arena: Allocator, out: *Io.Writer, f: *Family, old: ?Family, res: *Resolver) !void {
    try out.print("\n{s}: ", .{f.name});
    if (f.module == null) return out.writeAll("no named build, no symbols\n");
    var changes: std.ArrayList(Change) = .empty;
    if (old) |o| {
        if (o.syms.count() == 0) return out.writeAll("the baseline has no symbols\n");
        try out.print("raw {d} B ({s}{d} B); what changed, in raw bytes:\n", .{
            f.raw, if (f.raw >= o.raw) "+" else "", @as(i64, @intCast(f.raw)) - @as(i64, @intCast(o.raw)),
        });
        try changes.appendSlice(arena, try diff(arena, f, o));
    } else {
        try out.writeAll("no baseline; its largest functions:\n");
        for (f.syms.keys(), f.syms.values()) |name, now| try changes.append(arena, .{ .name = name, .now = now, .was = .{} });
        std.mem.sort(Change, changes.items, {}, struct {
            fn more(_: void, a: Change, b: Change) bool {
                return a.now.bytes > b.now.bytes;
            }
        }.more);
    }
    const m = f.module.?;
    var shown: usize = 0;
    for (changes.items) |c| {
        if (shown == max_lines or delta(c) <= 0) break;
        shown += 1;
        // A signed int given a width prints its sign
        try out.print("  {d:>6} ", .{delta(c)});
        if (c.was.count == 0 and old != null) try out.writeAll("new ") else if (c.now.count != c.was.count and old != null)
            try out.print("x{d}->{d} ", .{ c.was.count, c.now.count });
        try out.writeAll(c.name);
        const place = try res.place(c.name);
        if (place) |p| try out.print("  {s}", .{p.file});
        try out.writeAll("\n");
        if (!(if (place) |p| p.ours else false) and c.name[0] != '[') {
            const callers = try ourCallers(arena, m, c.name, res);
            if (callers.len > 0) {
                try out.writeAll("        called from ours: ");
                for (callers, 0..) |name, n| {
                    if (n > 0) try out.writeAll(", ");
                    try out.writeAll(name);
                    if (old) |o| if (!o.syms.contains(name)) try out.writeAll(" (new)");
                }
                try out.writeAll("\n");
            }
        }
    }
    var shrank: i64 = 0;
    for (changes.items) |c| shrank += @min(delta(c), 0);
    if (shrank < 0) try out.print("  ({d} B shrank or went elsewhere)\n", .{shrank});
}

fn delta(c: Change) i64 {
    return @as(i64, @intCast(c.now.bytes)) - @as(i64, @intCast(c.was.bytes));
}

/// Our functions that reach a std (or zjb) symbol's instances through std code only: the
/// call sites to change
fn ourCallers(arena: Allocator, m: Module, sym: []const u8, res: *Resolver) ![]const []const u8 {
    const n = m.funcs.len;
    var callers = try arena.alloc(std.ArrayList(u32), n);
    for (callers) |*c| c.* = .empty;
    for (m.funcs, 0..) |f, k| for (f.calls) |c| {
        if (c < m.imported or c - m.imported >= n) continue;
        try callers[c - m.imported].append(arena, @intCast(k));
    };
    const seen = try arena.alloc(bool, n);
    @memset(seen, false);
    var queue: std.ArrayList(u32) = .empty;
    for (m.funcs, 0..) |f, k| if (std.mem.eql(u8, f.key, sym)) {
        seen[k] = true;
        try queue.append(arena, @intCast(k));
    };
    var found: std.StringArrayHashMapUnmanaged(void) = .empty;
    var head: usize = 0;
    while (head < queue.items.len and found.count() < 6) : (head += 1) {
        for (callers[queue.items[head]].items) |c| {
            if (seen[c]) continue;
            seen[c] = true;
            const name = m.funcs[c].key;
            if (res.ours(name)) try found.put(arena, name, {}) else try queue.append(arena, c);
        }
    }
    return found.keys();
}

/// Where a symbol's code is: one of our files, std's, or neither (zjb, compiler_rt)
const Resolver = struct {
    io: Io,
    arena: Allocator,
    tree: []const u8,
    std_dir: ?[]const u8,
    places: std.StringHashMapUnmanaged(?Place) = .empty,
    sources: std.StringHashMapUnmanaged(?[]const u8) = .empty,

    const Place = struct { file: []const u8, ours: bool };

    fn place(r: *Resolver, sym: []const u8) !?Place {
        if (r.places.get(sym)) |p| return p;
        const p = try r.find(sym);
        try r.places.put(r.arena, sym, p);
        return p;
    }

    fn ours(r: *Resolver, sym: []const u8) bool {
        const p = r.place(sym) catch return false;
        return if (p) |q| q.ours else false;
    }

    fn find(r: *Resolver, sym: []const u8) !?Place {
        // `island.Island(champpage.More,dom.Dom).build`: the type's arguments dropped
        var plain: std.ArrayList(u8) = .empty;
        var depth: usize = 0;
        for (sym) |c| switch (c) {
            '(' => depth += 1,
            ')' => depth -|= 1,
            else => if (depth == 0) try plain.append(r.arena, c),
        };
        var parts: std.ArrayList([]const u8) = .empty;
        var it = std.mem.tokenizeScalar(u8, plain.items, '.');
        while (it.next()) |p| try parts.append(r.arena, p);
        if (parts.items.len < 2) return null;
        for (our_roots) |root| if (try r.walk(r.tree, root, parts.items)) |f| return .{ .file = f, .ours = true };
        if (r.std_dir) |d| if (try r.walk(d, "", parts.items)) |f|
            return .{ .file = try std.fmt.allocPrint(r.arena, "std/{s}", .{f}), .ours = false };
        return null;
    }

    /// The file under base/root that `parts` lead to through directories and files, the
    /// last one declaring the part after it (std/fmt.zig `parseIntWithSign`, not our
    /// src/site/ui/fmt.zig)
    fn walk(r: *Resolver, base: []const u8, root: []const u8, parts: []const []const u8) !?[]const u8 {
        var dir = root;
        for (parts[0 .. parts.len - 1], 0..) |p, k| {
            const sub = if (dir.len == 0) p else try std.fs.path.join(r.arena, &.{ dir, p });
            const next = parts[k + 1];
            const deeper = try std.fmt.allocPrint(r.arena, "{s}/{s}.zig", .{ sub, next });
            if (try r.source(base, deeper) != null) {
                dir = sub;
                continue;
            }
            const file = try std.fmt.allocPrint(r.arena, "{s}.zig", .{sub});
            const src = try r.source(base, file) orelse return null;
            return if (declares(src, next)) file else null;
        }
        return null;
    }

    fn source(r: *Resolver, base: []const u8, file: []const u8) !?[]const u8 {
        const path = try std.fs.path.join(r.arena, &.{ base, file });
        if (r.sources.get(path)) |s| return s;
        const s: ?[]const u8 = Io.Dir.cwd().readFileAlloc(r.io, path, r.arena, .limited(16 << 20)) catch null;
        try r.sources.put(r.arena, path, s);
        return s;
    }
};

fn declares(src: []const u8, name: []const u8) bool {
    for ([_][]const u8{ "fn ", "const ", "var " }) |kw| {
        var k: usize = 0;
        while (std.mem.findPos(u8, src, k, kw)) |at| {
            k = at + kw.len;
            const rest = src[k..];
            if (!std.mem.startsWith(u8, rest, name) or rest.len == name.len) continue;
            const c = rest[name.len];
            if (c == '(' or c == ' ' or c == ':') return true;
        }
    }
    return false;
}

/// lib/std of the zig on PATH
fn stdDir(io: Io, arena: Allocator) ?[]const u8 {
    const r = std.process.run(arena, io, .{ .argv = &.{ "zig", "env" } }) catch return null;
    const key = ".lib_dir = \"";
    const at = std.mem.find(u8, r.stdout, key) orelse return null;
    const end = std.mem.findScalarPos(u8, r.stdout, at + key.len, '"') orelse return null;
    return std.fs.path.join(arena, &.{ r.stdout[at + key.len .. end], "std" }) catch null;
}

test normalise {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("fmt.printValue", try normalise(a, "fmt.printValue__anon_1234"));
    try std.testing.expectEqualStrings("tree.H.fmt", try normalise(a, "tree.H.fmt__anon_12__345"));
    try std.testing.expectEqualStrings("Io.Writer.print", try normalise(a, "Io.Writer.print__func_336"));
    try std.testing.expectEqualStrings("tree.H.on.thunk.call", try normalise(a, "tree.H.on__func_609.thunk.call"));
    try std.testing.expectEqualStrings("kda.view.f", try normalise(a, "kda.view__struct_777.f"));
    try std.testing.expectEqualStrings("a__b", try normalise(a, "a__b"));
    try std.testing.expectEqualStrings("__zig_tag_name_role", try normalise(a, "__zig_tag_name_role"));
}
