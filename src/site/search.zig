//! data/search.json, the header search's index (static/search.js): each champion's name,
//! slug and icon key, and for every pair of champions the role of their matchup page with
//! the most games. "pairs" holds one character per pair i < j of `champs`, at
//! i * (2n - i - 1) / 2 + j - i - 1: the role's place in `roles`, or "." for no page

const std = @import("std");
const core = @import("core");
const root = @import("root.zig");
const matchup = @import("matchup.zig");

const Writer = std.Io.Writer;
const Role = core.Role;
const Site = root.Site;

pub const path = "data/search.json";

pub fn json(site: *const Site) ![]const u8 {
    const a = site.arena;
    const n = site.champs.len;
    var aw: Writer.Allocating = .init(a);
    const w = &aw.writer;
    try w.print("{{\"ddragon\":\"{s}\",\"roles\":[", .{site.ddragon_version});
    for (Role.all, 0..) |r, i| try w.print("{s}\"{s}\"", .{ if (i > 0) "," else "", r.label() });
    try w.writeAll("],\"champs\":[");
    for (site.champs, 0..) |ch, i| {
        if (i > 0) try w.writeByte(',');
        try w.writeByte('[');
        try std.json.Stringify.value(ch.name, .{}, w);
        try w.print(",\"{s}\",", .{ch.slug});
        try std.json.Stringify.value(ch.key, .{}, w);
        try w.writeByte(']');
    }
    const pairs = try a.alloc(u8, n * (n -| 1) / 2);
    @memset(pairs, '.');
    const best = try a.alloc(u32, pairs.len);
    @memset(best, 0);
    if (site.curves) |*curves| for (curves.curves) |c| {
        const h = c.header;
        if (!matchup.isPage(h) or h.role >= Role.count or h.games < @max(1, site.opts.static_min_games)) continue;
        const x = indexOf(site, h.a) orelse continue;
        const y = indexOf(site, h.b) orelse continue;
        if (x == y) continue;
        const i = @min(x, y);
        const j = @max(x, y);
        const at = i * (2 * n - i - 1) / 2 + j - i - 1;
        if (h.games <= best[at]) continue;
        best[at] = h.games;
        pairs[at] = '0' + h.role;
    };
    try w.print("],\"pairs\":\"{s}\"}}\n", .{pairs});
    return aw.written();
}

/// Place in site.champs of champion `id`
fn indexOf(site: *const Site, id: u32) ?usize {
    const c = site.stats.index(id) orelse return null;
    return site.by_c[c];
}
