//! Compact JSON documents packed many to a block, byte-exact: a block decodes to its
//! documents' exact bytes (docs/plan/ops.md "Complete form"). Schema-free, so a field
//! Riot adds needs no change here. The block goes through zstd after: each path's values
//! sit together, so it finds far more to share than in the JSON (a match-v5 timeline:
//! 790 KB of JSON, 44 KB as zstd -15 JSON, ~22 KB as a zstd -19 block of 256).
//!
//! Every value has a path: the object keys and array-element steps from the root.
//! Per block: key names, object shapes (key id lists) and the path tree, then
//!   structure: per object its shape id, per array its length, per ref (back, zigzag j-i)
//!   per path: its types (a byte per value), its integers (zigzag varints, as deltas when
//!   that is fewer bytes for the path), its other values (strings, other numbers)
//! A string is 0, length, bytes when new to the block; else 2i+1 for the path's i-th
//! string, or 2i+2 for the block's i-th long one (>= long_min bytes: PUUIDs recur across
//! paths). An array element equal, byte for byte, to element j of an earlier array in
//! the same object is a ref, `back` arrays back (a timeline's kill repeats most of its
//! damage breakdown in its teamfight one). Integers keep their text only when canonical
//! (no leading zero, no "-0", at most 18 digits); any other number is kept as its text.
//!
//! Layout, LEB128 varints, each stream as its length then bytes: magic, documents, each
//! document's length, keys (count; length and bytes each), shapes (count; length and key
//! ids each), paths (count; parent and step + 1 for each after the root), structure, per
//! path its types, per path a delta byte (0, 1) and its integers, per path its values.
//! Only compact JSON (no whitespace outside strings): `add` refuses anything else.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const magic = "JPK1";
/// Riot bodies are at most 16 MiB; a corrupt length must not grow the output past this
pub const max_doc = 64 << 20;
/// Strings this long or longer share one dictionary across paths
const long_min = 20;
const max_depth = 64;
const elem: u32 = 0xFFFF_FFFF;

const Tag = enum(u8) { object, array, string, int, number, true, false, null, ref };

/// Whether `doc` is one JSON value with no whitespace outside strings, nested at most
/// max_depth deep: what `add` takes
pub fn compact(doc: []const u8) bool {
    if (doc.len > max_doc) return false;
    var v: Validator = .{ .s = doc };
    v.value(0) catch return false;
    return v.i == doc.len;
}

const Validator = struct {
    s: []const u8,
    i: usize = 0,

    fn peek(v: *Validator) !u8 {
        if (v.i >= v.s.len) return error.Invalid;
        return v.s[v.i];
    }

    fn string(v: *Validator) !void {
        v.i += 1;
        while (v.i < v.s.len) : (v.i += 1) switch (v.s[v.i]) {
            '\\' => v.i += 1,
            '"' => {
                v.i += 1;
                return;
            },
            else => {},
        };
        return error.Invalid;
    }

    /// After a member or element: true at the closing `close`
    fn next(v: *Validator, close: u8) !bool {
        const c = try v.peek();
        v.i += 1;
        if (c == close) return true;
        if (c != ',') return error.Invalid;
        return false;
    }

    fn value(v: *Validator, depth: usize) error{Invalid}!void {
        if (depth >= max_depth) return error.Invalid;
        switch (try v.peek()) {
            '{' => {
                v.i += 1;
                if (try v.peek() == '}') {
                    v.i += 1;
                    return;
                }
                while (true) {
                    if (try v.peek() != '"') return error.Invalid;
                    try v.string();
                    if (try v.peek() != ':') return error.Invalid;
                    v.i += 1;
                    try v.value(depth + 1);
                    if (try v.next('}')) return;
                }
            },
            '[' => {
                v.i += 1;
                if (try v.peek() == ']') {
                    v.i += 1;
                    return;
                }
                while (true) {
                    try v.value(depth + 1);
                    if (try v.next(']')) return;
                }
            },
            '"' => try v.string(),
            else => {
                for ([_][]const u8{ "true", "false", "null" }) |l| if (std.mem.startsWith(u8, v.s[v.i..], l)) {
                    v.i += l.len;
                    return;
                };
                const start = v.i;
                while (v.i < v.s.len and isNumber(v.s[v.i])) v.i += 1;
                if (v.i == start) return error.Invalid;
            },
        }
    }
};

fn isNumber(c: u8) bool {
    return switch (c) {
        '0'...'9', '-', '+', '.', 'e', 'E' => true,
        else => false,
    };
}

fn canonicalInt(tok: []const u8) ?i64 {
    const digits = if (tok[0] == '-') tok[1..] else tok;
    if (digits.len == 0 or digits.len > 18) return null;
    for (digits) |d| if (d < '0' or d > '9') return null;
    if (digits[0] == '0' and (digits.len > 1 or tok[0] == '-')) return null;
    return std.fmt.parseInt(i64, tok, 10) catch null;
}

fn putVar(gpa: Allocator, out: *std.ArrayList(u8), v: u64) !void {
    var x = v;
    while (x >= 0x80) : (x >>= 7) try out.append(gpa, @as(u8, @truncate(x)) | 0x80);
    try out.append(gpa, @truncate(x));
}

fn varLen(v: u64) usize {
    return @max(1, (64 - @as(usize, @clz(v)) + 6) / 7);
}

fn zigzag(v: i64) u64 {
    return @bitCast((v << 1) ^ (v >> 63));
}

fn unzigzag(v: u64) i64 {
    return @as(i64, @bitCast(v >> 1)) ^ -@as(i64, @bitCast(v & 1));
}

fn putStream(gpa: Allocator, out: *std.ArrayList(u8), bytes: []const u8) !void {
    try putVar(gpa, out, bytes.len);
    try out.appendSlice(gpa, bytes);
}

const Path = struct {
    tags: std.ArrayList(u8) = .empty,
    ints: std.ArrayList(i64) = .empty,
    values: std.ArrayList(u8) = .empty,
    strings: std.StringHashMapUnmanaged(u32) = .empty,
};

/// Element bytes of an object's earlier array members -> their index, newest last
const Siblings = std.ArrayList(std.StringHashMapUnmanaged(u32));

/// Documents added since the last `finish`; dictionaries and streams live in its arena
pub const Block = struct {
    gpa: Allocator,
    arena: std.heap.ArenaAllocator,
    keys: std.StringHashMapUnmanaged(u32) = .empty,
    key_list: std.ArrayList([]const u8) = .empty,
    shapes: std.StringHashMapUnmanaged(u32) = .empty,
    shape_list: std.ArrayList([]const u32) = .empty,
    /// (parent << 32 | step) -> path id; the root is 0
    paths: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    path_list: std.ArrayList(Path) = .empty,
    path_keys: std.ArrayList(u64) = .empty,
    long: std.StringHashMapUnmanaged(u32) = .empty,
    structure: std.ArrayList(u8) = .empty,
    lengths: std.ArrayList(u64) = .empty,
    src: []const u8 = "",
    pos: usize = 0,

    pub fn init(gpa: Allocator) Block {
        return .{ .gpa = gpa, .arena = .init(gpa) };
    }

    pub fn deinit(b: *Block) void {
        b.arena.deinit();
    }

    pub fn count(b: *const Block) usize {
        return b.lengths.items.len;
    }

    /// False, and nothing added, when `doc` is not compact JSON: keep that one as it is
    pub fn add(b: *Block, doc: []const u8) !bool {
        if (!compact(doc)) return false;
        const a = b.arena.allocator();
        if (b.path_list.items.len == 0) {
            try b.path_list.append(a, .{});
            try b.path_keys.append(a, 0);
        }
        b.src = doc;
        b.pos = 0;
        try b.lengths.append(a, doc.len);
        try b.value(0, null);
        return true;
    }

    fn path(b: *Block, parent: u32, step: u32) !u32 {
        const a = b.arena.allocator();
        const k = (@as(u64, parent) << 32) | step;
        const gop = try b.paths.getOrPut(a, k);
        if (!gop.found_existing) {
            gop.value_ptr.* = @intCast(b.path_list.items.len);
            try b.path_list.append(a, .{});
            try b.path_keys.append(a, k);
        }
        return gop.value_ptr.*;
    }

    /// The bytes between the quotes at pos; pos ends after the closing one
    fn string(b: *Block) []const u8 {
        b.pos += 1;
        const start = b.pos;
        while (true) : (b.pos += 1) switch (b.src[b.pos]) {
            '\\' => b.pos += 1,
            '"' => {
                b.pos += 1;
                return b.src[start .. b.pos - 1];
            },
            else => {},
        };
    }

    fn skip(b: *Block) void {
        switch (b.src[b.pos]) {
            '{', '[' => {
                var depth: usize = 0;
                while (true) {
                    switch (b.src[b.pos]) {
                        '"' => {
                            _ = b.string();
                            continue;
                        },
                        '{', '[' => depth += 1,
                        '}', ']' => {
                            depth -= 1;
                            if (depth == 0) {
                                b.pos += 1;
                                return;
                            }
                        },
                        else => {},
                    }
                    b.pos += 1;
                }
            },
            '"' => _ = b.string(),
            else => while (b.pos < b.src.len and std.mem.indexOfScalar(u8, ",]}", b.src[b.pos]) == null) {
                b.pos += 1;
            },
        }
    }

    fn tag(b: *Block, p: u32, t: Tag) !void {
        try b.path_list.items[p].tags.append(b.arena.allocator(), @backingInt(t));
    }

    fn value(b: *Block, p: u32, siblings: ?*Siblings) Allocator.Error!void {
        switch (b.src[b.pos]) {
            '{' => try b.object(p),
            '[' => try b.array(p, siblings),
            '"' => {
                try b.tag(p, .string);
                try b.stringValue(p, b.string());
            },
            't' => {
                try b.tag(p, .true);
                b.pos += 4;
            },
            'f' => {
                try b.tag(p, .false);
                b.pos += 5;
            },
            'n' => {
                try b.tag(p, .null);
                b.pos += 4;
            },
            else => {
                const start = b.pos;
                while (b.pos < b.src.len and isNumber(b.src[b.pos])) b.pos += 1;
                const tok = b.src[start..b.pos];
                const pa = &b.path_list.items[p];
                if (canonicalInt(tok)) |v| {
                    try b.tag(p, .int);
                    try pa.ints.append(b.arena.allocator(), v);
                } else {
                    try b.tag(p, .number);
                    try putStream(b.arena.allocator(), &pa.values, tok);
                }
            },
        }
    }

    fn stringValue(b: *Block, p: u32, s: []const u8) !void {
        const a = b.arena.allocator();
        const pa = &b.path_list.items[p];
        const dict, const first: u64 = if (s.len >= long_min) .{ &b.long, 2 } else .{ &pa.strings, 1 };
        const gop = try dict.getOrPut(a, s);
        if (gop.found_existing) return putVar(a, &pa.values, 2 * @as(u64, gop.value_ptr.*) + first);
        gop.key_ptr.* = try a.dupe(u8, s);
        gop.value_ptr.* = dict.count() - 1;
        try putVar(a, &pa.values, 0);
        try putStream(a, &pa.values, s);
    }

    fn object(b: *Block, p: u32) !void {
        const a = b.arena.allocator();
        try b.tag(p, .object);
        const start = b.pos;
        b.pos += 1;
        var ids: std.ArrayList(u32) = .empty;
        defer ids.deinit(b.gpa);
        if (b.src[b.pos] != '}') while (true) {
            const k = b.string();
            const gop = try b.keys.getOrPut(a, k);
            if (!gop.found_existing) {
                gop.key_ptr.* = try a.dupe(u8, k);
                gop.value_ptr.* = @intCast(b.key_list.items.len);
                try b.key_list.append(a, gop.key_ptr.*);
            }
            try ids.append(b.gpa, gop.value_ptr.*);
            b.pos += 1;
            b.skip();
            if (b.src[b.pos] == '}') break;
            b.pos += 1;
        };
        const gop = try b.shapes.getOrPut(a, std.mem.sliceAsBytes(ids.items));
        if (!gop.found_existing) {
            const kept = try a.dupe(u32, ids.items);
            gop.key_ptr.* = std.mem.sliceAsBytes(kept);
            gop.value_ptr.* = @intCast(b.shape_list.items.len);
            try b.shape_list.append(a, kept);
        }
        try putVar(a, &b.structure, gop.value_ptr.*);

        var siblings: Siblings = .empty;
        defer {
            for (siblings.items) |*s| s.deinit(b.gpa);
            siblings.deinit(b.gpa);
        }
        b.pos = start + 1;
        for (ids.items) |k| {
            _ = b.string();
            b.pos += 1;
            try b.value(try b.path(p, k), &siblings);
            b.pos += 1;
        }
        if (ids.items.len == 0) b.pos += 1;
    }

    fn array(b: *Block, p: u32, siblings: ?*Siblings) !void {
        const a = b.arena.allocator();
        try b.tag(p, .array);
        const start = b.pos;
        b.pos += 1;
        var n: u64 = 0;
        if (b.src[b.pos] != ']') while (true) {
            b.skip();
            n += 1;
            if (b.src[b.pos] == ']') break;
            b.pos += 1;
        };
        try putVar(a, &b.structure, n);
        b.pos = start + 1;
        if (n == 0) {
            b.pos += 1;
            return;
        }
        const ep = try b.path(p, elem);
        var seen: std.StringHashMapUnmanaged(u32) = .empty;
        errdefer seen.deinit(b.gpa);
        for (0..n) |i| {
            if (siblings) |sib| {
                const at = b.pos;
                b.skip();
                const bytes = b.src[at..b.pos];
                try seen.put(b.gpa, bytes, @intCast(i));
                if (findIn(sib.items, bytes)) |hit| {
                    try b.tag(ep, .ref);
                    try putVar(a, &b.structure, hit.back);
                    try putVar(a, &b.structure, zigzag(@as(i64, hit.index) - @as(i64, @intCast(i))));
                    b.pos += 1;
                    continue;
                }
                b.pos = at;
            }
            try b.value(ep, null);
            b.pos += 1;
        }
        if (siblings) |sib| try sib.append(b.gpa, seen) else seen.deinit(b.gpa);
    }

    fn findIn(arrays: []const std.StringHashMapUnmanaged(u32), bytes: []const u8) ?struct { back: usize, index: u32 } {
        var back: usize = 1;
        while (back <= arrays.len) : (back += 1) {
            if (arrays[arrays.len - back].get(bytes)) |j| return .{ .back = back, .index = j };
        }
        return null;
    }

    /// Appends the block to `out` and empties `b` for the next one
    pub fn finish(b: *Block, out: *std.ArrayList(u8)) !void {
        const g = b.gpa;
        try out.appendSlice(g, magic);
        try putVar(g, out, b.lengths.items.len);
        for (b.lengths.items) |l| try putVar(g, out, l);
        try putVar(g, out, b.key_list.items.len);
        for (b.key_list.items) |k| try putStream(g, out, k);
        try putVar(g, out, b.shape_list.items.len);
        for (b.shape_list.items) |s| {
            try putVar(g, out, s.len);
            for (s) |k| try putVar(g, out, k);
        }
        try putVar(g, out, b.path_list.items.len);
        if (b.path_keys.items.len > 1) for (b.path_keys.items[1..]) |k| {
            try putVar(g, out, k >> 32);
            try putVar(g, out, @as(u32, @truncate(k)) +% 1);
        };
        try putStream(g, out, b.structure.items);
        for (b.path_list.items) |p| try putStream(g, out, p.tags.items);
        var ints: std.ArrayList(u8) = .empty;
        defer ints.deinit(g);
        for (b.path_list.items) |p| {
            var plain: usize = 0;
            var delta: usize = 0;
            var last: i64 = 0;
            for (p.ints.items) |v| {
                plain += varLen(zigzag(v));
                delta += varLen(zigzag(v -% last));
                last = v;
            }
            const use_delta = delta < plain;
            ints.clearRetainingCapacity();
            last = 0;
            for (p.ints.items) |v| {
                try putVar(g, &ints, zigzag(if (use_delta) v -% last else v));
                last = v;
            }
            try out.append(g, @intFromBool(use_delta));
            try putStream(g, out, ints.items);
        }
        for (b.path_list.items) |p| try putStream(g, out, p.values.items);
        b.reset();
    }

    pub fn reset(b: *Block) void {
        _ = b.arena.reset(.retain_capacity);
        const gpa = b.gpa;
        const arena = b.arena;
        b.* = .{ .gpa = gpa, .arena = arena };
    }
};

const Reader = struct {
    b: []const u8,
    i: usize = 0,

    fn byte(r: *Reader) !u8 {
        if (r.i >= r.b.len) return error.Corrupt;
        r.i += 1;
        return r.b[r.i - 1];
    }

    fn varint(r: *Reader) !u64 {
        var v: u64 = 0;
        var shift: u32 = 0;
        while (shift < 64) : (shift += 7) {
            const c = try r.byte();
            v |= @as(u64, c & 0x7f) << @intCast(shift);
            if (c < 0x80) return v;
        }
        return error.Corrupt;
    }

    fn index(r: *Reader, len: usize) !usize {
        const v = try r.varint();
        if (v >= len) return error.Corrupt;
        return @intCast(v);
    }

    fn bytes(r: *Reader, n: u64) ![]const u8 {
        if (n > r.b.len - r.i) return error.Corrupt;
        r.i += @intCast(n);
        return r.b[r.i - @as(usize, @intCast(n)) .. r.i];
    }

    fn stream(r: *Reader) !Reader {
        return .{ .b = try r.bytes(try r.varint()) };
    }

    fn done(r: Reader) bool {
        return r.i == r.b.len;
    }
};

const PathReader = struct {
    tags: Reader = .{ .b = "" },
    ints: Reader = .{ .b = "" },
    delta: bool = false,
    last: i64 = 0,
    values: Reader = .{ .b = "" },
    strings: std.ArrayList([]const u8) = .empty,
};

const Decoder = struct {
    a: Allocator,
    keys: []const []const u8,
    shapes: []const []const u32,
    children: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    structure: Reader = .{ .b = "" },
    paths: []PathReader,
    long: std.ArrayList([]const u8) = .empty,
    out: *std.ArrayList(u8),
    gpa: Allocator,
    /// Where the current document's bytes must end
    limit: usize = 0,

    const Ranges = std.ArrayList([2]usize);

    fn child(d: *Decoder, p: u32, step: u32) !u32 {
        return d.children.get((@as(u64, p) << 32) | step) orelse error.Corrupt;
    }

    fn write(d: *Decoder, bytes: []const u8) !void {
        if (d.out.items.len + bytes.len > d.limit) return error.Corrupt;
        try d.out.appendSlice(d.gpa, bytes);
    }

    fn tag(d: *Decoder, p: u32) !Tag {
        const t = try d.paths[p].tags.byte();
        return std.enums.fromInt(Tag, t) orelse error.Corrupt;
    }

    fn value(d: *Decoder, p: u32, depth: usize, siblings: ?*std.ArrayList(Ranges)) (Allocator.Error || error{Corrupt})!void {
        if (depth >= max_depth) return error.Corrupt;
        const pr = &d.paths[p];
        switch (try d.tag(p)) {
            .object => {
                const keys = d.shapes[try d.structure.index(d.shapes.len)];
                var mine: std.ArrayList(Ranges) = .empty;
                try d.write("{");
                for (keys, 0..) |k, i| {
                    if (i > 0) try d.write(",");
                    try d.write("\"");
                    try d.write(d.keys[k]);
                    try d.write("\":");
                    try d.value(try d.child(p, k), depth + 1, &mine);
                }
                try d.write("}");
            },
            .array => {
                const n = try d.structure.varint();
                try d.write("[");
                const c = if (n > 0) try d.child(p, elem) else 0;
                var ranges: Ranges = .empty;
                var i: u64 = 0;
                while (i < n) : (i += 1) {
                    if (i > 0) try d.write(",");
                    const at = d.out.items.len;
                    const tags = &d.paths[c].tags;
                    if (tags.i < tags.b.len and tags.b[tags.i] == @backingInt(Tag.ref)) {
                        tags.i += 1;
                        const sib = (siblings orelse return error.Corrupt).items;
                        const back = try d.structure.varint();
                        if (back == 0 or back > sib.len) return error.Corrupt;
                        const from = sib[sib.len - @as(usize, @intCast(back))].items;
                        const j = @as(i128, i) + unzigzag(try d.structure.varint());
                        if (j < 0 or j >= from.len) return error.Corrupt;
                        const r = from[@intCast(j)];
                        if (d.out.items.len + (r[1] - r[0]) > d.limit) return error.Corrupt;
                        try d.out.ensureUnusedCapacity(d.gpa, r[1] - r[0]);
                        d.out.appendSliceAssumeCapacity(d.out.items[r[0]..r[1]]);
                    } else try d.value(c, depth + 1, null);
                    try ranges.append(d.a, .{ at, d.out.items.len });
                }
                try d.write("]");
                if (siblings) |s| try s.append(d.a, ranges);
            },
            .string => {
                const v = try pr.values.varint();
                const s = if (v == 0) blk: {
                    const t = try pr.values.bytes(try pr.values.varint());
                    if (t.len >= long_min) try d.long.append(d.a, t) else try pr.strings.append(d.a, t);
                    break :blk t;
                } else if (v % 2 == 1) blk: {
                    const i = (v - 1) / 2;
                    if (i >= pr.strings.items.len) return error.Corrupt;
                    break :blk pr.strings.items[@intCast(i)];
                } else blk: {
                    const i = v / 2 - 1;
                    if (i >= d.long.items.len) return error.Corrupt;
                    break :blk d.long.items[@intCast(i)];
                };
                try d.write("\"");
                try d.write(s);
                try d.write("\"");
            },
            .int => {
                const raw = unzigzag(try pr.ints.varint());
                const v = if (pr.delta) pr.last +% raw else raw;
                pr.last = v;
                var buf: [24]u8 = undefined;
                try d.write(std.fmt.bufPrint(&buf, "{d}", .{v}) catch unreachable);
            },
            .number => try d.write(try pr.values.bytes(try pr.values.varint())),
            .true => try d.write("true"),
            .false => try d.write("false"),
            .null => try d.write("null"),
            .ref => return error.Corrupt,
        }
    }
};

/// Appends every document of `block` to `out`, in order; returns where each ends in
/// `out` (owned by `gpa`). error.Corrupt for anything that is not a whole block
pub fn decode(gpa: Allocator, block: []const u8, out: *std.ArrayList(u8)) ![]usize {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var r: Reader = .{ .b = block };
    if (!std.mem.eql(u8, try r.bytes(magic.len), magic)) return error.Corrupt;
    const n_docs = try r.varint();
    if (n_docs > block.len) return error.Corrupt;
    const lengths = try a.alloc(u64, @intCast(n_docs));
    for (lengths) |*l| {
        l.* = try r.varint();
        if (l.* > max_doc) return error.Corrupt;
    }
    const n_keys = try r.varint();
    if (n_keys > block.len) return error.Corrupt;
    const keys = try a.alloc([]const u8, @intCast(n_keys));
    for (keys) |*k| k.* = try r.bytes(try r.varint());
    const n_shapes = try r.varint();
    if (n_shapes > block.len) return error.Corrupt;
    const shapes = try a.alloc([]const u32, @intCast(n_shapes));
    for (shapes) |*s| {
        const n = try r.varint();
        if (n > block.len) return error.Corrupt;
        const ids = try a.alloc(u32, @intCast(n));
        for (ids) |*k| k.* = @intCast(try r.index(keys.len));
        s.* = ids;
    }
    const n_paths = try r.varint();
    if (n_paths == 0 or n_paths > block.len) return error.Corrupt;
    var d: Decoder = .{
        .a = a,
        .gpa = gpa,
        .keys = keys,
        .shapes = shapes,
        .paths = try a.alloc(PathReader, @intCast(n_paths)),
        .out = out,
    };
    @memset(d.paths, .{});
    for (1..d.paths.len) |i| {
        const parent = try r.index(i);
        const step: u32 = @as(u32, @truncate(try r.varint())) -% 1;
        const gop = try d.children.getOrPut(a, (@as(u64, parent) << 32) | step);
        if (gop.found_existing) return error.Corrupt;
        gop.value_ptr.* = @intCast(i);
    }
    d.structure = try r.stream();
    for (d.paths) |*p| p.tags = try r.stream();
    for (d.paths) |*p| {
        p.delta = switch (try r.byte()) {
            0 => false,
            1 => true,
            else => return error.Corrupt,
        };
        p.ints = try r.stream();
    }
    for (d.paths) |*p| p.values = try r.stream();
    if (!r.done()) return error.Corrupt;

    const ends = try gpa.alloc(usize, lengths.len);
    errdefer gpa.free(ends);
    for (ends, lengths) |*e, l| {
        const start = out.items.len;
        d.limit = start + @as(usize, @intCast(l));
        try d.value(0, 0, null);
        if (out.items.len != d.limit) return error.Corrupt;
        e.* = out.items.len;
    }
    if (!d.structure.done()) return error.Corrupt;
    for (d.paths) |p| if (!p.tags.done() or !p.ints.done() or !p.values.done()) return error.Corrupt;
    return ends;
}

const testing = std.testing;

fn roundTrip(docs: []const []const u8) ![]u8 {
    const gpa = testing.allocator;
    var b: Block = .init(gpa);
    defer b.deinit();
    for (docs) |doc| try testing.expect(try b.add(doc));
    var block: std.ArrayList(u8) = .empty;
    errdefer block.deinit(gpa);
    try b.finish(&block);
    try testing.expectEqual(0, b.count());
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    const ends = try decode(gpa, block.items, &out);
    defer gpa.free(ends);
    try testing.expectEqual(docs.len, ends.len);
    var at: usize = 0;
    for (docs, ends) |doc, e| {
        try testing.expectEqualStrings(doc, out.items[at..e]);
        at = e;
    }
    return block.toOwnedSlice(gpa);
}

test "documents come back byte for byte" {
    const docs = [_][]const u8{
        \\{"a":1,"b":[1,2,3],"c":{"d":"x","e":null},"f":true,"g":false}
        ,
        \\{"a":-5,"b":[],"c":{},"f":[[],[[]],{}],"g":"line\nnext \"quoted\" \u00e9 \\"}
        ,
        \\[1.5,-0,1e10,007,12345678901234567890,-9223372036854775808,0,-1,2.50]
        ,
        \\"just a string"
        ,
        \\{"a":1,"a":2,"":3}
        ,
        \\{"long":"abcdefghijklmnopqrstuvwxyz","again":"abcdefghijklmnopqrstuvwxyz"}
        ,
        \\{"k":"short","l":["short","short","abcdefghijklmnopqrstuvwxyz"]}
        ,
        "12",
        "null",
    };
    testing.allocator.free(try roundTrip(&docs));
}

test "an element repeated from an earlier array in the object is a ref" {
    const entry =
        \\{"name":"Ahri","physicalDamage":0,"magicDamage":412,"spellName":"ahriq"}
    ;
    const doc = "{\"dealt\":[" ++ entry ++ "],\"other\":1,\"received\":[" ++ entry ++ "," ++ entry ++ "],\"teamfight\":[" ++ entry ++ ",{\"x\":1}]}";
    const block = try roundTrip(&.{doc});
    defer testing.allocator.free(block);
    try testing.expect(std.mem.count(u8, block, "ahriq") == 1);
}

test "only compact JSON goes in" {
    var b: Block = .init(testing.allocator);
    defer b.deinit();
    for ([_][]const u8{ "{\"a\": 1}", " 1", "1 ", "[1,]", "{\"a\"}", "tru", "truex", "", "\"open", "[1", "{\"a\":1,}" }) |doc|
        try testing.expect(!try b.add(doc));
    var deep: [2 * max_depth + 2]u8 = undefined;
    @memset(deep[0 .. max_depth + 1], '[');
    @memset(deep[max_depth + 1 ..], ']');
    try testing.expect(!try b.add(&deep));
    try testing.expect(try b.add(deep[1 .. deep.len - 1]));
    b.reset();
    try testing.expectEqual(0, b.count());
}

test "a counter takes deltas, an id does not" {
    var doc: std.ArrayList(u8) = .empty;
    defer doc.deinit(testing.allocator);
    try doc.appendSlice(testing.allocator, "[");
    for (0..200) |i| try doc.print(testing.allocator, "{s}{{\"t\":{d},\"id\":{d}}}", .{ if (i > 0) "," else "", 1_000_000 + i * 60, (i * 7919) % 50 });
    try doc.appendSlice(testing.allocator, "]");
    testing.allocator.free(try roundTrip(&.{doc.items}));
}

test "a cut or damaged block is an error, never a crash" {
    const gpa = testing.allocator;
    const block = try roundTrip(&.{
        \\{"a":[{"x":1,"y":"abcdefghijklmnopqrstuvwxyz"}],"b":[{"x":1,"y":"abcdefghijklmnopqrstuvwxyz"}],"c":2.5}
        ,
        \\{"a":[],"b":[{"x":2,"y":"s"}],"c":-3}
    });
    defer gpa.free(block);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    for (0..block.len) |n| {
        out.clearRetainingCapacity();
        try testing.expectError(error.Corrupt, decode(gpa, block[0..n], &out));
    }
    const copy = try gpa.dupe(u8, block);
    defer gpa.free(copy);
    for (0..copy.len) |i| for ([_]u8{ 0x00, 0x01, 0x7f, 0x80, 0xff }) |x| {
        @memcpy(copy, block);
        copy[i] ^= x;
        out.clearRetainingCapacity();
        if (decode(gpa, copy, &out)) |ends| gpa.free(ends) else |err| try testing.expectEqual(error.Corrupt, err);
    };
}

fn fuzzDocs(_: void, s: *testing.Smith) !void {
    const gpa = testing.allocator;
    var buf: [512]u8 = undefined;
    const doc = buf[0..s.slice(&buf)];
    var b: Block = .init(gpa);
    defer b.deinit();
    if (!try b.add(doc)) return;
    _ = try b.add(doc);
    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(gpa);
    try b.finish(&block);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    const ends = try decode(gpa, block.items, &out);
    defer gpa.free(ends);
    try testing.expectEqualStrings(doc, out.items[0..ends[0]]);
    try testing.expectEqualStrings(doc, out.items[ends[0]..ends[1]]);
}

test "fuzz: any compact document comes back exact" {
    try testing.fuzz({}, fuzzDocs, .{ .corpus = &.{
        \\{"a":[1,{"b":"c"}],"d":[{"e":1}],"f":[{"e":1}]}
        ,
        \\[0,-1,1.5e3,"\\\"",true,false,null,[],{}]
    } });
}

fn fuzzBlock(_: void, s: *testing.Smith) !void {
    const gpa = testing.allocator;
    var buf: [1024]u8 = undefined;
    const n = s.slice(&buf);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    const ends = decode(gpa, buf[0..n], &out) catch return;
    gpa.free(ends);
}

test "fuzz: any bytes decode or fail cleanly" {
    try testing.fuzz({}, fuzzBlock, .{ .corpus = &.{magic ++ "\x01\x01\x00\x00\x01\x00\x01\x03\x00\x00\x01\x00"} });
}
