//! Keyed diff: old tree against new, as DOM ops on `O` (zjb calls in ui.wasm, the fake
//! DOM in tests): el, text, attr, del, data, ins (insert or move before a node, 0 the
//! end) and rm. New nodes get DOM ids; kept nodes carry theirs over; removed subtrees
//! give theirs back to the free list (ui.wasm releases the node's handle)
const std = @import("std");
const tree = @import("tree.zig");
const N = tree.N;
const Tree = tree.Tree;

pub const Ids = struct {
    next: u32 = 1,
    free: std.ArrayList(u32) = .empty,

    pub fn take(ids: *Ids) u32 {
        if (ids.free.pop()) |id| return id;
        return ids.fresh();
    }

    /// Never a recycled one: hydration numbers the server's nodes in a run
    pub fn fresh(ids: *Ids) u32 {
        defer ids.next += 1;
        return ids.next;
    }
};

pub fn Diff(comptime O: type) type {
    return struct {
        old: *const Tree,
        new: *const Tree,
        o: *O,
        ids: *Ids,
        /// Scratch, and the free list's allocator
        a: std.mem.Allocator,
        gpa: std.mem.Allocator,
        /// The focused node's id; `lost` once it is removed (its id may go to a new node)
        focused: u32 = 0,
        lost: bool = false,

        const D = @This();

        pub fn run(d: *D) void {
            d.patch(d.old.root, d.new.root);
        }

        fn same(d: *D, o: N, n: N) bool {
            const x = d.old.node(o);
            const y = d.new.node(n);
            return x.tag == y.tag and x.key == y.key;
        }

        fn patch(d: *D, o: N, n: N) void {
            const x = d.old.node(o);
            const y = d.new.node(n);
            y.dom = x.dom;
            if (y.tag == .@"#text") {
                if (!std.mem.eql(u8, x.text, y.text)) d.o.data(y.dom, y.text);
                return;
            }
            const oa = d.old.attrsOf(o);
            for (d.new.attrsOf(n)) |na| {
                const was = for (oa) |a| {
                    if (a.name.ptr == na.name.ptr or std.mem.eql(u8, a.name, na.name)) break a.value;
                } else null;
                if (was == null or !std.mem.eql(u8, was.?, na.value)) d.o.attr(y.dom, na.name, na.value);
            }
            for (oa) |a| {
                if (d.new.attr(n, a.name) == null) d.o.del(y.dom, a.name);
            }
            d.kids(y.dom, d.old.kidsOf(o), d.new.kidsOf(n));
        }

        fn create(d: *D, n: N) u32 {
            const y = d.new.node(n);
            const id = d.ids.take();
            y.dom = id;
            if (y.tag == .@"#text") {
                d.o.text(id, y.text);
                return id;
            }
            d.o.el(id, y.tag);
            for (d.new.attrsOf(n)) |a| d.o.attr(id, a.name, a.value);
            for (d.new.kidsOf(n)) |k| d.o.ins(id, d.create(k), 0);
            return id;
        }

        fn destroy(d: *D, o: N) void {
            d.o.rm(d.old.node(o).dom);
            d.recycle(o);
        }

        /// Every node of a removed subtree: its id is free and its handle released
        fn recycle(d: *D, o: N) void {
            d.o.forget(d.old.node(o).dom);
            if (d.old.node(o).dom == d.focused) d.lost = true;
            d.ids.free.append(d.gpa, d.old.node(o).dom) catch {};
            for (d.old.kidsOf(o)) |k| d.recycle(k);
        }

        fn kids(d: *D, parent: u32, ok: []const N, nk: []const N) void {
            var s: usize = 0;
            while (s < ok.len and s < nk.len and d.same(ok[s], nk[s])) : (s += 1) d.patch(ok[s], nk[s]);
            var oe = ok.len;
            var ne = nk.len;
            while (oe > s and ne > s and d.same(ok[oe - 1], nk[ne - 1])) {
                oe -= 1;
                ne -= 1;
                d.patch(ok[oe], nk[ne]);
            }
            const tail: u32 = if (ne < nk.len) d.new.node(nk[ne]).dom else 0;
            if (s == oe) {
                for (nk[s..ne]) |k| d.o.ins(parent, d.create(k), tail);
                return;
            }
            if (s == ne) {
                for (ok[s..oe]) |k| d.destroy(k);
                return;
            }
            // Middle: match by key (unkeyed: by tag and order), keep the longest run already
            // in order, move the rest
            var map: std.AutoHashMapUnmanaged(u64, u32) = .empty;
            var ord: [64]u32 = @splat(0);
            for (ok[s..oe], s..) |k, j| {
                map.put(d.a, matchKey(d.old.node(k), &ord), @intCast(j)) catch {};
            }
            ord = @splat(0);
            const src = d.a.alloc(i32, ne - s) catch return;
            var used = d.a.alloc(bool, oe - s) catch return;
            @memset(used, false);
            for (nk[s..ne], src) |k, *sj| {
                sj.* = -1;
                if (map.get(matchKey(d.new.node(k), &ord))) |j| {
                    if (!used[j - s]) {
                        used[j - s] = true;
                        sj.* = @intCast(j);
                        d.patch(ok[j], k);
                    }
                }
            }
            for (ok[s..oe], used) |k, u| if (!u) d.destroy(k);
            const keep = lis(d.a, src) catch return;
            var anchor = tail;
            var i = ne - s;
            while (i > 0) {
                i -= 1;
                const n = nk[s + i];
                if (src[i] < 0) {
                    d.o.ins(parent, d.create(n), anchor);
                } else if (!keep[i]) {
                    d.o.ins(parent, d.new.node(n).dom, anchor);
                }
                anchor = d.new.node(n).dom;
            }
        }
    };
}

fn matchKey(x: *const tree.Node, ord: *[64]u32) u64 {
    const tag: u64 = @backingInt(x.tag);
    if (x.key != 0) return (@as(u64, x.key) << 8) | tag;
    const slot: usize = @intCast(tag % 64);
    const nth = ord[slot];
    ord[slot] += 1;
    return (1 << 63) | (@as(u64, nth) << 8) | tag;
}

/// Marks the longest increasing run of `src` (ignoring -1): those nodes stay put
fn lis(a: std.mem.Allocator, src: []const i32) ![]bool {
    const keep = try a.alloc(bool, src.len);
    @memset(keep, false);
    const prev = try a.alloc(i32, src.len);
    var tails: std.ArrayList(u32) = .empty;
    for (src, 0..) |v, i| {
        if (v < 0) continue;
        var lo: usize = 0;
        var hi: usize = tails.items.len;
        while (lo < hi) {
            const mid = (lo + hi) / 2;
            if (src[tails.items[mid]] < v) lo = mid + 1 else hi = mid;
        }
        prev[i] = if (lo > 0) @intCast(tails.items[lo - 1]) else -1;
        if (lo == tails.items.len) try tails.append(a, @intCast(i)) else tails.items[lo] = @intCast(i);
    }
    if (tails.items.len == 0) return keep;
    var k: i32 = @intCast(tails.items[tails.items.len - 1]);
    while (k >= 0) : (k = prev[@intCast(k)]) keep[@intCast(k)] = true;
    return keep;
}
