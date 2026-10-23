//! Scope chip: what a block's numbers cover, in the subbar's words, "EUW · 30 days ·
//! Plat+". A dimension the block doesn't follow is marked against the page's picks
//! ("Plat+, not by rank"); on champion pages static/filters.js markChips redoes it for
//! each pick. Plain data in, markup out (no Site), so it can move into a ui.zig

const std = @import("std");
const html = @import("html.zig");
const tpl = html.tpl;

const Writer = std.Io.Writer;

/// One dimension: `key` as filters.js picks it (region "EUW1" or "all", period
/// "days30" or "patch:16.21", rank "" or a tier index as html.ranks), any other key for
/// a scope no pick names ("every": every patch), or `follows` when the block is redrawn
/// for each pick (filters.js writes the pick's text)
pub const Dim = struct {
    key: []const u8,
    text: []const u8,

    pub const follows = "*";

    pub const days30: Dim = .{ .key = "days30", .text = "30 days" };
    /// Every game we crawl: Platinum IV+ players' lobbies
    pub const plat: Dim = .{ .key = "", .text = "Plat+" };
    pub const every_patch: Dim = .{ .key = "every", .text = "Every patch" };

    pub fn region(r: html.Region, home: []const u8) Dim {
        return switch (r) {
            .euw => .{ .key = home, .text = html.platformName(home) },
            .all => .{ .key = "all", .text = "All regions" },
        };
    }

    /// `label`: "16.21"
    pub fn patch(a: std.mem.Allocator, label: []const u8) !Dim {
        return .{ .key = try a.print("patch:{s}", .{label}), .text = try a.print("Patch {s}", .{label}) };
    }

    /// A rank floor by tier index (filters.zig tiers); the crawl's own floor, Platinum,
    /// and below are every game's
    pub fn rank(tier: usize) Dim {
        for (html.ranks[1..]) |r| {
            if ((std.fmt.parseInt(usize, r[0], 10) catch unreachable) == tier) return .{ .key = r[0], .text = r[1] };
        }
        return if (tier <= 4) plat else .{ .key = "high", .text = "Grandmaster+" };
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

pub const Chip = struct {
    region: Dim,
    period: Dim,
    rank: Dim = Dim.plat,
    picks: Picks,

    pub fn render(c: Chip, w: *Writer) !void {
        try tpl.render(w,
            \\<span class="scope" data-chip data-region="{rk}" data-period="{pk}" data-rank="{kk}" title="Region, period and rank these numbers are from">{r}{p}{k}</span>
        , .{
            .rk = c.region.key,
            .pk = c.period.key,
            .kk = c.rank.key,
            .r = part(c.region, c.picks.region, .region),
            .p = part(c.period, c.picks.period, .period),
            .k = part(c.rank, c.picks.rank, .rank),
        });
    }
};

const Kind = enum { region, period, rank };

fn part(d: Dim, pick: Dim, comptime kind: Kind) Part {
    return .{ .text = if (std.mem.eql(u8, d.key, Dim.follows)) pick.text else d.text, .note = if (d.matches(pick.key)) null else note(d, pick, kind) };
}

const Part = struct {
    text: []const u8,
    note: ?Note,

    pub fn render(p: Part, w: *Writer) !void {
        try tpl.render(w, "<span{off}>{text}{note}</span>", .{
            .off = tpl.flag(p.note != null, "class=\"off\""),
            .text = p.text,
            .note = if (p.note) |n| tpl.t("<i>, {n}</i>", .{ .n = n }) else null,
        });
    }
};

/// As filters.js chipNote: what the block doesn't follow. "not by rank" for a block
/// over every rank (region: "not KR alone"), "not the 30 days picked" for another period
const Note = struct {
    d: Dim,
    pick: Dim,
    kind: Kind,

    pub fn format(n: Note, w: *Writer) Writer.Error!void {
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

fn note(d: Dim, pick: Dim, kind: Kind) Note {
    return .{ .d = d, .pick = pick, .kind = kind };
}

test "chip marks what the block doesn't follow" {
    const euw: Dim = .{ .key = "EUW1", .text = "EUW" };
    const picks: Picks = .{ .region = euw, .period = Dim.days30, .rank = Dim.rank(5) };
    var aw: Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    const c: Chip = .{ .region = Dim.region(.all, "EUW1"), .period = .{ .key = "patch:16.21", .text = "Patch 16.21" }, .rank = .{ .key = Dim.follows, .text = "" }, .picks = picks };
    try c.render(&aw.writer);
    try std.testing.expectEqualStrings(
        \\<span class="scope" data-chip data-region="all" data-period="patch:16.21" data-rank="*" title="Region, period and rank these numbers are from"><span class="off">All regions<i>, not EUW alone</i></span><span class="off">Patch 16.21<i>, not the 30 days picked</i></span><span>Emerald+</span></span>
    , aw.written());
    aw.clearRetainingCapacity();
    try (Chip{ .region = euw, .period = Dim.every_patch, .picks = picks }).render(&aw.writer);
    try std.testing.expect(std.mem.indexOf(u8, aw.written(), "<span>EUW</span><span class=\"off\">Every patch<i>, not by period</i></span><span class=\"off\">Plat+<i>, not by rank</i></span>") != null);
    try std.testing.expectEqualStrings("6", Dim.rank(6).key);
    try std.testing.expectEqualStrings("", Dim.rank(4).key);
}
