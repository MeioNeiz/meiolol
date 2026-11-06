//! LockBar: the champion page's locks (docs/plan/ui/champion-locks.md), one Chip with ×
//! per lock, then the games under all of them with their win rate and range, then
//! Clear. Hidden with no lock. The lock set (`Set`) is the `lk` query as text: per kind
//! its code and the values dot-joined, as lockanswer.Locks.format writes them (kinds in
//! one order, so one lock set is one URL and one cached answer); no number is parsed
const std = @import("std");
const tree = @import("tree.zig");
const art = @import("art.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const chip = @import("chip.zig");
const button = @import("button.zig");
const url = @import("url.zig");
const rate = @import("rate.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "LockBar";
pub const scope = .{ ".c-lockbar", ".c-lockmark" };

/// lockanswer.Kind's, in its order (site/locks.zig asserts they agree)
pub const Kind = enum { keystone, runes, rune, shards, shard, spells, start, boots, core2, core3, item4, item5, item6, skills, skill_path, opponent, reach, damage };

/// Each kind's code in `lk`, in Kind's order
pub const codes = [_][]const u8{ "ks", "rp", "ru", "sh", "sd", "sp", "st", "bo", "c2", "c3", "i4", "i5", "i6", "mo", "lv", "vs", "vr", "vd" };

comptime {
    std.debug.assert(codes.len == std.enums.values(Kind).len);
}

/// At most one lock per kind: a new value in a kind replaces the old
pub const Set = struct {
    s: url.Str(200) = .{},

    pub fn any(set: *const Set) bool {
        return set.s.len > 0;
    }

    /// `kind`'s values ("8010", "3071.6333.3053"), null when not locked
    pub fn get(set: *const Set, kind: Kind) ?[]const u8 {
        var it = std.mem.tokenizeScalar(u8, set.s.slice(), ',');
        while (it.next()) |part| if (part.len > 2 and tree.eql(part[0..2], codes[@backingInt(kind)])) return part[2..];
        return null;
    }

    pub fn has(set: *const Set, kind: Kind, v: []const u8) bool {
        const now = set.get(kind) orelse return false;
        return tree.eql(now, v);
    }

    /// Locks `kind` on `v`, or unlocks it when that is its lock. Unchanged when the
    /// set would outgrow its URL key
    pub fn toggle(set: *Set, kind: Kind, v: []const u8) void {
        set.put(kind, if (set.has(kind, v)) null else v);
    }

    pub fn remove(set: *Set, kind: Kind) void {
        set.put(kind, null);
    }

    pub fn clear(set: *Set) void {
        set.s.len = 0;
    }

    fn put(set: *Set, kind: Kind, new: ?[]const u8) void {
        var buf: [200]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        for (std.enums.values(Kind)) |k| {
            const v = (if (k == kind) new else set.get(k)) orelse continue;
            if (w.end > 0) w.writeByte(',') catch return;
            w.writeAll(codes[@backingInt(k)]) catch return;
            w.writeAll(v) catch return;
        }
        set.s.set(w.buffered());
    }
};

/// `v` dot-joined into `buf`, as a lock's value ("" when it doesn't fit)
pub fn text(buf: []u8, v: []const u32) []const u8 {
    var w: std.Io.Writer = .fixed(buf);
    for (v, 0..) |x, i| {
        if (i > 0) w.writeByte('.') catch return "";
        fmt.write(&w, .int, x) catch return "";
    }
    return w.buffered();
}

/// As text, in `a`
pub fn value(a: std.mem.Allocator, v: []const u32) []const u8 {
    var buf: [value_max]u8 = undefined;
    return a.dupe(u8, text(&buf, v)) catch "";
}

/// builds.max_values ids of up to 10 digits, dot-joined
pub const value_max = 96;

/// A lock as its chip shows it: icons, then words (either may be empty)
pub const Label = struct {
    kind: Kind,
    art: []const art.Art = &.{},
    text: []const u8 = "",
};

const W = struct {
    pub const games = Phrase("{n:count} games");
    pub const none = plain("No games");
    pub const clear = plain("Clear");
    pub const remove = Phrase("Unlock {x:text}");
    pub const locks = plain("Locks");
};

pub const LockBar = struct {
    set: *Set,
    /// The games under every lock and their wins; null while the answer is out
    games: ?u32 = null,
    wins: u32 = 0,
    /// What follows the locks when not the whole page ("Build only")
    scope: ?tree.Text = null,

    pub const Msg = union(enum) { remove: Kind, clear };

    pub fn update(b: *LockBar, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .remove => |k| b.set.remove(k),
            .clear => b.set.clear(),
        }
        ev.push = true;
    }

    /// `labels`: one per lock in the set, in its order
    pub fn view(b: *LockBar, h: *H, labels: []const Label) N {
        if (!b.set.any()) return .none;
        var chips = h.list();
        for (labels) |label| {
            const l = named(label);
            var icons = h.list();
            for (l.art) |a| icons.add(art.view(h, a, .{ .k = artKind(l.kind), .px = .@"20", .named = false }));
            const what = if (l.text.len > 0) l.text else if (l.art.len > 0) l.art[0].name else "";
            chips.add(chip.view(h, .{ .remove = true, .label = W.remove.with(h, .{ .x = what }), .on = h.on(b, .{ .remove = l.kind }) }, .{
                icons.done(),
                if (l.text.len > 0) h.span(.{ .class = "t" }, .{l.text}) else null,
            }));
        }
        const line: N = if (b.games) |g| h.span(.{ .class = "n" }, if (g == 0) .{ W.none, null, null } else .{
            W.games.with(h, .{ .n = g }),
            " · ",
            rate.view(h, .counted(g, b.wins), .{ .count = false }),
        }) else .none;
        return h.div(.{ .class = "c-lockbar", .role = "group", .aria_label = W.locks }, .{
            h.div(.{ .class = "chips" }, .{chips.done()}),
            line,
            if (b.scope) |x| h.span(.{ .class = "s" }, .{x}) else .none,
            button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(b, .clear) }, .{W.clear}),
        });
    }
};

/// The one "locked" sign, the same on every lockable thing: a lock in a filled accent
/// circle at its top right corner (the parent is `position: relative`). Unlocked: drawn
/// but hidden, so a parent's hover can show it faint as a hint (the parent's CSS)
pub fn mark(h: *H, on: bool) N {
    return h.span(.{ .class = "c-lockmark", .aria_hidden = true, .data_on = on }, .{});
}

/// The lane opponent locks' values are BuildPanel's groups, so the bar names them
/// itself: no data needed
fn named(l: Label) Label {
    const words: [2][]const u8 = switch (l.kind) {
        .reach => .{ "vs melee", "vs ranged" },
        .damage => .{ "vs AD", "vs AP" },
        else => return l,
    };
    if (std.mem.eql(u8, l.text, "1")) return .{ .kind = l.kind, .text = words[0] };
    if (std.mem.eql(u8, l.text, "2")) return .{ .kind = l.kind, .text = words[1] };
    return l;
}

fn artKind(k: Kind) art.Kind {
    return switch (k) {
        .keystone, .runes, .rune, .shards, .shard => .rune,
        .spells => .spell,
        else => .item,
    };
}

pub const css =
    \\@layer components {
    \\  .c-lockbar { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2) var(--sp-3); min-width: 0;
    \\    font-size: var(--fs-s); color: var(--muted); }
    \\  .c-lockbar > .chips { display: flex; gap: var(--sp-2); min-width: 0; max-width: 100%; overflow-x: auto; scrollbar-width: none; }
    \\  .c-lockbar > .chips > .c-chip { flex: none; padding-left: 6px; border-color: var(--focus); color: var(--text); }
    \\  .c-lockbar .c-chip .c-art { --sz: 20px; }
    \\  .c-lockbar > .n { white-space: nowrap; font-variant-numeric: tabular-nums; }
    \\  .c-lockbar > .n > .c-rate > .v { font-weight: var(--w-b); }
    \\  .c-lockbar > .s { white-space: nowrap; color: var(--faint); }
    \\  .c-lockbar > .c-btn { margin-left: auto; }
    \\  .c-lockmark { position: absolute; top: -5px; right: -5px; z-index: 1; width: 16px; height: 16px; border-radius: 50%;
    \\    background: var(--ctl-bg-2); box-shadow: 0 0 0 1.5px var(--panel); pointer-events: none; opacity: 0; }
    \\  .c-lockmark::after { content: ""; position: absolute; inset: 3px; background: var(--muted);
    \\    mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M3.75 5.5V4a2.25 2.25 0 0 1 4.5 0v1.5' fill='none' stroke='black' stroke-width='1.5'/%3E%3Crect x='2' y='5.5' width='8' height='5.5' rx='1.2'/%3E%3C/svg%3E") no-repeat center / contain; }
    \\  .c-lockmark[data-on] { opacity: 1; background: var(--brand); }
    \\  .c-lockmark[data-on]::after { background: var(--on-brand); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const demo = @import("build_demo.zig");
    const set = h.mem.create(Set) catch {
        h.oom = true;
        return;
    };
    set.* = .{};
    set.toggle(.keystone, "8010");
    set.toggle(.core3, "6631.3071.3053");
    const b = h.mem.create(LockBar) catch {
        h.oom = true;
        return;
    };
    b.* = .{ .set = set, .games = 1284, .wins = 669, .scope = plain("Build only") };
    const core = demo.darius.slots[3].options[0].art;
    g.add("Conqueror and a core path locked: 1,284 games under both", b.view(h, &.{
        .{ .kind = .keystone, .art = &.{.{ .name = "Conqueror", .src = "" }}, .text = "Conqueror" },
        .{ .kind = .core3, .art = core },
    }));
    const thin = h.mem.create(LockBar) catch {
        h.oom = true;
        return;
    };
    thin.* = .{ .set = set, .games = 41, .wins = 25 };
    g.add("thin: the range is wide, so the rate fades", thin.view(h, &.{
        .{ .kind = .keystone, .art = &.{.{ .name = "Conqueror", .src = "" }}, .text = "Conqueror" },
        .{ .kind = .core3, .art = core },
    }));
    const vs = h.mem.create(Set) catch {
        h.oom = true;
        return;
    };
    vs.* = .{};
    vs.toggle(.keystone, "8010");
    vs.toggle(.reach, "2");
    const lane = h.mem.create(LockBar) catch {
        h.oom = true;
        return;
    };
    lane.* = .{ .set = vs, .games = 1630, .wins = 812 };
    g.add("Conqueror against ranged lane opponents: the build panel's row names its chip", lane.view(h, &.{
        .{ .kind = .keystone, .art = &.{.{ .name = "Conqueror", .src = "" }}, .text = "Conqueror" },
        .{ .kind = .reach, .text = "2" },
    }));
    g.add("the mark: on a locked rune, page or build row's top right corner", mark(h, true));
}

test "a lock set keeps one value per kind, in lockanswer's order" {
    var s: Set = .{};
    s.toggle(.opponent, "86");
    s.toggle(.keystone, "8010");
    try std.testing.expectEqualStrings("ks8010,vs86", s.s.slice());
    s.toggle(.keystone, "8008");
    try std.testing.expectEqualStrings("ks8008,vs86", s.s.slice());
    try std.testing.expectEqualStrings("8008", s.get(.keystone).?);
    s.toggle(.keystone, "8008");
    try std.testing.expectEqualStrings("vs86", s.s.slice());
    s.toggle(.shard, "1.5008");
    s.toggle(.core3, "6631.3071.3053");
    try std.testing.expectEqualStrings("sd1.5008,c36631.3071.3053,vs86", s.s.slice());
    try std.testing.expect(s.has(.core3, "6631.3071.3053"));
    try std.testing.expectEqual(null, s.get(.core2));
    s.remove(.opponent);
    try std.testing.expectEqualStrings("sd1.5008,c36631.3071.3053", s.s.slice());
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectEqualStrings("6631.3071.3053", value(arena.allocator(), &.{ 6631, 3071, 3053 }));
    try std.testing.expectEqualStrings("", value(arena.allocator(), &.{}));
}
