//! Champion page filters (prototype, Options.filter_champions): per champion, games,
//! wins and gold at 14 against the lane opponent, split by region, the player's rank,
//! patch, role and opponent, as one JSON file (data/filters/<slug>.json at the site
//! root). The page's filter bar (static/filters.js) sums the slices picked. Counts add
//! up, so any mix of filters needs neither a server nor a page per combination

const std = @import("std");
const store = @import("store");
const core = @import("core");
const root = @import("root.zig");
const stats = @import("../stats.zig");

const Role = core.Role;
const Writer = std.Io.Writer;

/// Ladder tiers, lowest first; a player off the ladder when the game was stored (tier
/// NULL) gets index tiers.len, counted only under "All ranks"
pub const tiers = [_][]const u8{
    "IRON", "BRONZE", "SILVER", "GOLD", "PLATINUM", "EMERALD", "DIAMOND", "MASTER", "GRANDMASTER", "CHALLENGER",
};

const Key = struct {
    platform: u8,
    tier: u8,
    patch: u8,
    /// Started within the 30-day window (the rest is the current patch from before it)
    recent: bool,
    role: Role,
    opponent: u16,
};

const Cell = struct {
    games: u32 = 0,
    wins: u32 = 0,
    /// Games with both players' gold at 14 and a frame after it (as learning.goldMap),
    /// the difference's sum and sum of squares, for its mean and standard error
    gold_n: u32 = 0,
    gold_sum: i64 = 0,
    gold_sq: i64 = 0,
};

const Cells = std.AutoArrayHashMapUnmanaged(Key, Cell);

const Player = struct {
    team: u1,
    role: Role,
    champion: u16,
    tier: u8,
    gold14: ?i64,
};

/// The games of the 30-day and current-patch views on every platform, valid as for
/// stats.scan (ten players, one per team and role, a winner)
pub fn write(site: *const root.Site, db: store.Db, opts: root.Options) !void {
    const a = site.arena;
    var wanted: std.ArrayList(root.Champ) = .empty;
    for (opts.filter_champions) |slug| {
        for (site.champs) |ch| if (std.mem.eql(u8, ch.slug, slug)) try wanted.append(a, ch);
    }
    if (wanted.items.len == 0) return;
    const cells = try a.alloc(Cells, wanted.items.len);
    @memset(cells, .empty);
    var patches: std.ArrayList([]const u8) = .empty;

    const platform_json = try std.json.Stringify.valueAlloc(a, opts.all_platforms, .{});
    const patch_json = try std.json.Stringify.valueAlloc(a, opts.patches, .{});
    var q = try db.prepare(
        \\SELECT m.match_id, m.winning_team, m.game_start, m.patch, m.platform,
        \\  p.team_id, p.position, p.champion_id, p.tier,
        \\  CASE WHEN p.gold15 IS NULL THEN NULL ELSE p.gold14 END
        \\FROM matches m JOIN participants p USING (match_id)
        \\WHERE m.queue_id = ? AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
        \\  AND (m.game_start >= ? OR m.patch IN (SELECT value FROM json_each(?)))
        \\ORDER BY m.match_id
    );
    defer q.deinit();
    try q.bind(.{ stats.ranked_solo, platform_json, opts.since_ms, patch_json });

    var current: std.ArrayList(u8) = .empty;
    var players: [10]Player = undefined;
    var n: usize = 0;
    var bad = false;
    var game: struct { winner: i64 = 0, recent: bool = false, platform: u8 = 0, patch: u8 = 0 } = .{};
    while (true) {
        const more = try q.step();
        if (!more or !std.mem.eql(u8, q.bytes(0), current.items)) {
            if (current.items.len > 0 and !bad and n == 10) {
                if (winnerSide(game.winner)) |winner| {
                    for (players) |p| for (wanted.items, cells) |ch, *c| {
                        if (p.champion != ch.id) continue;
                        const opp = opponent(&players, p) orelse continue;
                        const e = try c.getOrPutValue(a, .{
                            .platform = game.platform,
                            .tier = p.tier,
                            .patch = game.patch,
                            .recent = game.recent,
                            .role = p.role,
                            .opponent = opp.champion,
                        }, .{});
                        e.value_ptr.games += 1;
                        if (p.team == winner) e.value_ptr.wins += 1;
                        if (p.gold14 != null and opp.gold14 != null) {
                            const d = p.gold14.? - opp.gold14.?;
                            e.value_ptr.gold_n += 1;
                            e.value_ptr.gold_sum += d;
                            e.value_ptr.gold_sq += d * d;
                        }
                    };
                }
            }
            if (!more) break;
            current.clearRetainingCapacity();
            try current.appendSlice(a, q.bytes(0));
            n = 0;
            bad = false;
            game = .{
                .winner = q.int(1),
                .recent = q.int(2) >= opts.since_ms,
                .platform = @intCast(indexOf(opts.all_platforms, q.bytes(4)) orelse 0),
                .patch = try patchIndex(a, &patches, q.bytes(3)),
            };
        }
        if (n == 10) {
            bad = true;
            continue;
        }
        const team: u1 = switch (q.int(5)) {
            100 => 0,
            200 => 1,
            else => {
                bad = true;
                continue;
            },
        };
        const role = Role.fromLcu(if (q.isNull(6)) "" else q.bytes(6)) orelse {
            bad = true;
            continue;
        };
        const champion = q.int(7);
        if (champion <= 0 or champion > std.math.maxInt(u16)) bad = true;
        for (players[0..n]) |p| {
            if (p.team == team and p.role == role) bad = true;
        }
        players[n] = .{
            .team = team,
            .role = role,
            .champion = @intCast(std.math.clamp(champion, 0, std.math.maxInt(u16))),
            .tier = @intCast(if (q.isNull(8)) tiers.len else indexOf(&tiers, q.bytes(8)) orelse tiers.len),
            .gold14 = if (q.isNull(9)) null else q.int(9),
        };
        n += 1;
    }

    for (wanted.items, cells) |ch, *c| {
        var aw: Writer.Allocating = .init(a);
        try writeJson(a, &aw.writer, opts, patches.items, c);
        const path = try std.fmt.allocPrint(a, "data/filters/{s}.json", .{ch.slug});
        try site.writeShared(path, aw.written());
    }
}

fn writeJson(a: std.mem.Allocator, w: *Writer, opts: root.Options, patches: []const []const u8, cells: *const Cells) !void {
    try w.writeAll("{\"platforms\":");
    try std.json.Stringify.value(opts.all_platforms, .{}, w);
    try w.writeAll(",\"tiers\":");
    try std.json.Stringify.value(tiers, .{}, w);
    // Newest first, so the bar lists the current patch first
    const sorted = try a.dupe([]const u8, patches);
    std.mem.sort([]const u8, sorted, {}, struct {
        fn f(_: void, x: []const u8, y: []const u8) bool {
            return stats.patchKey(x) > stats.patchKey(y);
        }
    }.f);
    try w.writeAll(",\"patches\":");
    try std.json.Stringify.value(patches, .{}, w);
    try w.writeAll(",\"order\":[");
    for (sorted, 0..) |p, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{d}", .{indexOf(patches, p).?});
    }
    try w.writeAll("],\"current\":");
    try std.json.Stringify.value(opts.patches, .{}, w);
    try w.writeAll(",\"roles\":[");
    for (Role.all, 0..) |r, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("\"{s}\"", .{root.roleSlug(r)});
    }
    // One array per slice: platform, tier, patch, recent, role, opponent, games, wins,
    // gold n, gold sum, gold sum of squares
    try w.writeAll("],\"rows\":[");
    var it = cells.iterator();
    var first = true;
    while (it.next()) |e| {
        if (!first) try w.writeByte(',');
        first = false;
        const k = e.key_ptr.*;
        const v = e.value_ptr.*;
        try w.print("[{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}]", .{
            k.platform, k.tier, k.patch,  @intFromBool(k.recent), @intFromEnum(k.role), k.opponent,
            v.games,    v.wins, v.gold_n, v.gold_sum,             v.gold_sq,
        });
    }
    try w.writeAll("]}\n");
}

fn winnerSide(winning_team: i64) ?u1 {
    return switch (winning_team) {
        100 => 0,
        200 => 1,
        else => null,
    };
}

fn opponent(players: *const [10]Player, p: Player) ?Player {
    for (players) |o| if (o.team != p.team and o.role == p.role) return o;
    return null;
}

fn indexOf(list: []const []const u8, s: []const u8) ?usize {
    for (list, 0..) |x, i| if (std.mem.eql(u8, x, s)) return i;
    return null;
}

fn patchIndex(a: std.mem.Allocator, patches: *std.ArrayList([]const u8), patch: []const u8) !u8 {
    if (indexOf(patches.items, patch)) |i| return @intCast(i);
    if (patches.items.len == std.math.maxInt(u8)) return error.TooManyPatches;
    try patches.append(a, try a.dupe(u8, patch));
    return @intCast(patches.items.len - 1);
}
