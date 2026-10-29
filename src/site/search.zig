//! data/search.bin, the header search's index (ui.sitesearch.Data, its island
//! ui-sitesearch.wasm): each champion's name, slug and icon key, and for every pair of
//! champions the role of their matchup page with the most games

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const root = @import("root.zig");
const matchup = @import("matchup.zig");

const Role = core.Role;
const Site = root.Site;
const Data = ui.sitesearch.Data;

pub const path = ui.sitesearch.data_path;

pub fn bin(site: *const Site) ![]const u8 {
    const a = site.arena;
    const n = site.champs.len;
    const champs = try a.alloc(Data.Champ, n);
    for (site.champs, champs) |ch, *c| c.* = .{ .name = ch.name, .slug = ch.slug, .key = ch.key };
    const pairs = try a.alloc(u8, n * (n -| 1) / 2);
    @memset(pairs, Data.no_page);
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
        pairs[at] = h.role;
    };
    var out: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, Data, .{ .ddragon = site.ddragon_version, .champs = champs, .pairs = pairs }, &out);
    return out.items;
}

/// Place in site.champs of champion `id`
fn indexOf(site: *const Site, id: u32) ?usize {
    const c = site.stats.index(id) orelse return null;
    return site.by_c[c];
}
