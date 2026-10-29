//! ScopeChip: what a block's numbers cover, in the subbar's words, "EUW · 30 days ·
//! Plat+", as a scope Chip. A dimension the block doesn't follow is marked against the
//! page's picks ("All regions, not EUW alone"). Server side only
const std = @import("std");
const tree = @import("tree.zig");
const chip = @import("chip.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "ScopeChip";
pub const scope = .{".c-scope"};

/// One dimension: `key` as a pick names it (region "EUW1" or "all", period "days30" or
/// "patch:16.21", rank ""), or `follows` when the block follows every pick
pub const Dim = struct {
    key: []const u8,
    text: []const u8,

    pub const follows = "*";

    pub const days30: Dim = .{ .key = "days30", .text = "30 days" };
    /// Every game we crawl: Platinum IV+ players' lobbies
    pub const plat: Dim = .{ .key = "", .text = "Plat+" };
    pub const all_regions: Dim = .{ .key = "all", .text = "All regions" };

    /// `label`: "16.21"
    pub fn patch(a: std.mem.Allocator, label: []const u8) !Dim {
        return .{ .key = try a.print("patch:{s}", .{label}), .text = try a.print("Patch {s}", .{label}) };
    }

    fn matches(d: Dim, pick: []const u8) bool {
        return std.mem.eql(u8, d.key, follows) or std.mem.eql(u8, d.key, pick);
    }
};

/// The page's picks as written: its view's (rank "" on every page)
pub const Picks = struct {
    region: Dim,
    period: Dim,
    rank: Dim = Dim.plat,
};

const Kind = enum { region, period, rank };

pub const ScopeChip = struct {
    region: Dim,
    period: Dim,
    rank: Dim = Dim.plat,
    picks: Picks,

    pub fn view(c: ScopeChip, h: *H) N {
        return h.span(.{ .class = "c-scope" }, .{chip.view(h, .{ .v = .scope, .title = W.title.s }, .{
            part(h, c.region, c.picks.region, .region),
            part(h, c.period, c.picks.period, .period),
            part(h, c.rank, c.picks.rank, .rank),
        })});
    }
};

const W = struct {
    const title = plain("Region, period and rank these numbers are from");
};

fn part(h: *H, d: Dim, pick: Dim, comptime kind: Kind) N {
    const text = if (std.mem.eql(u8, d.key, Dim.follows)) pick.text else d.text;
    if (d.matches(pick.key)) return h.span(.{ .class = "part" }, .{text});
    return h.span(.{ .class = "part off" }, .{ text, h.fmt(", {f}", .{Note{ .d = d, .pick = pick, .kind = kind }}) });
}

/// What the block doesn't follow: "not by rank" for a block over every rank (region:
/// "not KR alone"), "not the 30 days picked" for another period
const Note = struct {
    d: Dim,
    pick: Dim,
    kind: Kind,

    pub fn format(n: Note, w: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (n.kind) {
            .region => if (std.mem.eql(u8, n.d.key, "all"))
                try w.print("not {s} alone", .{n.pick.text})
            else if (std.mem.eql(u8, n.pick.key, "all"))
                try w.writeAll("not all regions")
            else
                try w.print("not {s}", .{n.pick.text}),
            .period => if (std.mem.eql(u8, n.d.key, "days30") or std.mem.startsWith(u8, n.d.key, "patch:"))
                try w.print("not the {s} picked", .{if (std.mem.eql(u8, n.pick.key, "days30")) "30 days" else "patch"})
            else
                try w.writeAll("not by period"),
            .rank => if (n.d.key.len == 0)
                try w.writeAll("not by rank")
            else
                try w.print("not {s}", .{n.pick.text}),
        }
    }
};

pub const css =
    \\@layer components {
    \\  .c-scope { display: inline-flex; vertical-align: middle; }
    \\  .c-scope .c-chip { flex-wrap: wrap; gap: 0 var(--sp-1); height: auto; min-height: var(--ctl-s); white-space: normal; }
    \\  .c-scope .part + .part::before { content: "·"; margin-right: var(--sp-1); color: var(--faint); }
    \\  .c-scope .off { color: var(--turn); }
    \\}
    \\
;

const euw: Dim = .{ .key = "EUW1", .text = "EUW" };

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const picks: Picks = .{ .region = euw, .period = Dim.days30 };
    g.add("follows the picks", (ScopeChip{ .region = euw, .period = Dim.days30, .picks = picks }).view(h));
    g.add("every region on an EUW page", (ScopeChip{ .region = Dim.all_regions, .period = Dim.days30, .picks = picks }).view(h));
    const p = Dim.patch(h.mem, "16.21") catch {
        h.oom = true;
        return;
    };
    g.add("a patch, all regions, Emerald+ picked", (ScopeChip{ .region = Dim.all_regions, .period = p, .rank = Dim.plat, .picks = .{ .region = euw, .period = Dim.days30, .rank = .{ .key = "5", .text = "Emerald+" } } }).view(h));
}

const testing = std.testing;

test "the chip marks what the block doesn't follow" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const picks: Picks = .{ .region = euw, .period = Dim.days30, .rank = .{ .key = "5", .text = "Emerald+" } };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const c: ScopeChip = .{ .region = Dim.all_regions, .period = try Dim.patch(a, "16.21"), .rank = .{ .key = Dim.follows, .text = "" }, .picks = picks };
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, c.view(&h), &out.writer);
    try testing.expect(std.mem.find(u8, out.written(), "<span class=\"part off\">All regions, not EUW alone</span><span class=\"part off\">Patch 16.21, not the 30 days picked</span><span class=\"part\">Emerald+</span>") != null);
    out.clearRetainingCapacity();
    try @import("html.zig").write(&t, (ScopeChip{ .region = euw, .period = Dim.days30, .picks = picks }).view(&h), &out.writer);
    try testing.expect(std.mem.find(u8, out.written(), "<span class=\"part off\">Plat+, not by rank</span>") != null);
}
