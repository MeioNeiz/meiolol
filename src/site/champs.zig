//! A view's champions: from its stats file and the database, indexed, as champions.json

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("../stats.zig");
const partials = @import("../partials.zig");

const Writer = std.Io.Writer;
const Role = core.Role;

const root = @import("root.zig");
const Champ = root.Champ;
const Site = root.Site;

pub fn loadChamps(site: *Site, db: store.Db, games: ?*const partials.Store) !void {
    const a = site.arena;
    var banned: std.AutoHashMapUnmanaged(u32, u32) = .empty;
    if (games) |g| try g.bansIn(a, &banned, site.opts.patches, site.opts.platforms, site.since_ms) else {
        const patch_json = try std.json.Stringify.valueAlloc(a, site.opts.patches, .{});
        const platform_json = try std.json.Stringify.valueAlloc(a, site.opts.platforms, .{});
        // Games each champion was banned in, counted here: count(DISTINCT) with GROUP BY
        // took ~6x as long as reading the rows. CROSS JOIN keeps a match's bans together
        var q = try db.prepare(
            \\SELECT b.match_id, b.champion_id
            \\FROM matches m CROSS JOIN bans b USING (match_id)
            \\WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
            \\  AND m.platform IN (SELECT value FROM json_each(?))
            \\  AND m.remake = 0 AND m.game_start >= ?
        );
        defer q.deinit();
        try q.bind(.{ patch_json, stats.ranked_solo, platform_json, site.since_ms });
        var match: std.ArrayList(u8) = .empty;
        // A match's bans so far: a champion banned by both teams counts once
        var seen: std.ArrayList(u32) = .empty;
        while (try q.step()) {
            const r = q.row(struct { match_id: []const u8, champion: u32 });
            if (!std.mem.eql(u8, r.match_id, match.items)) {
                match.clearRetainingCapacity();
                try match.appendSlice(a, r.match_id);
                seen.clearRetainingCapacity();
            }
            if (std.mem.findScalar(u32, seen.items, r.champion) != null) continue;
            try seen.append(a, r.champion);
            (try banned.getOrPutValue(a, r.champion, 0)).value_ptr.* += 1;
        }
    }

    var list: std.ArrayList(Champ) = .empty;
    var q = try db.prepare("SELECT id, key, name, ddragon_version FROM champions ORDER BY name");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) {
        const r = q.row(struct {
            id: u32,
            key: []const u8,
            name: []const u8,
            ddragon_version: []const u8,
        });
        const id = r.id;
        const c = site.stats.index(id) orelse continue;
        const name = try a.dupe(u8, r.name);
        const slug = root.ui.champ.slug(try a.alloc(u8, name.len), name);
        // /champions/<role> is the role's list (ui/urls.zig)
        if (std.meta.stringToEnum(root.ui.role.Role, slug) != null) return error.ChampionSlugIsRole;
        try list.append(a, .{
            .c = c,
            .id = id,
            .key = try a.dupe(u8, r.key),
            .name = name,
            .slug = slug,
            .banned = banned.get(id) orelse 0,
            .games = site.stats.champGames(c),
        });
        if (site.ddragon_version.len == 0) site.ddragon_version = try a.dupe(u8, r.ddragon_version);
    }
    site.champs = try list.toOwnedSlice(a);
    try indexChamps(site);
}

/// by_c and by_slug from champs
pub fn indexChamps(site: *Site) !void {
    const a = site.arena;
    site.by_c = try a.alloc(?usize, site.stats.n);
    @memset(site.by_c, null);
    for (site.champs, 0..) |ch, i| site.by_c[ch.c] = i;
    for (site.champs, 0..) |ch, i| try site.by_slug.put(a, ch.slug, i);
}

pub fn championsJson(site: *const Site) ![]const u8 {
    var aw: Writer.Allocating = .init(site.arena);
    const w = &aw.writer;
    try w.print("{{\"patch\":\"{s}\",\"games\":{d},\"ddragon\":\"{s}\",\"champions\":[", .{
        site.patch, site.games, site.ddragon_version,
    });
    for (site.champs, 0..) |ch, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"key\":", .{ch.id});
        try std.json.Stringify.value(ch.key, .{}, w);
        try w.writeAll(",\"name\":");
        try std.json.Stringify.value(ch.name, .{}, w);
        try w.print(",\"slug\":\"{s}\",\"games\":[", .{ch.slug});
        for (Role.all, 0..) |r, j| {
            if (j > 0) try w.writeByte(',');
            try w.print("{d}", .{site.stats.champRole(r, ch.c).games});
        }
        try w.writeAll("]}");
    }
    try w.writeAll("]}\n");
    return aw.written();
}
