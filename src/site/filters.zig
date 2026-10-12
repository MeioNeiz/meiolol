//! Champion page filters: per champion, games, wins and gold at 14 against the lane
//! opponent, split by region, the player's rank, patch, role and opponent, as one JSON
//! file (data/filters/<slug>.json), plus data/filters.json with the role totals every
//! champion shares (for pick rates). The page's filter bar (static/filters.js) sums the
//! slices picked. Counts add up, so any mix of filters needs neither a server nor a page
//! per combination. Lane curve estimates don't add up: each view's are listed as they
//! are, for the filters that match a view

const std = @import("std");
const store = @import("store");
const core = @import("core");
const root = @import("root.zig");
const html = @import("html.zig");
const stats = @import("../stats.zig");

const Role = core.Role;
const Bracket = core.curvesfile.Bracket;
const Writer = std.Io.Writer;

/// Ladder tiers, lowest first; a player off the ladder when the game was stored (tier
/// NULL) gets index tiers.len, counted only under "All ranks"
pub const tiers = [_][]const u8{
    "IRON", "BRONZE", "SILVER", "GOLD", "PLATINUM", "EMERALD", "DIAMOND", "MASTER", "GRANDMASTER", "CHALLENGER",
};

/// Rank filters a curves bracket matches: all ranks, and Diamond+ (the high bracket)
const curve_ranks = [_]struct { Bracket, []const u8 }{ .{ .all, "" }, .{ .high, "6" } };

comptime {
    std.debug.assert(std.mem.eql(u8, tiers[6], "DIAMOND") and Bracket.ofRank(6) == .high and Bracket.ofRank(5) != .high);
}

/// Where the games of a slice were played and when
const Slice = struct {
    platform: u8,
    patch: u8,
    /// Started within the 30-day window (the rest is the current patch from before it)
    recent: bool,
};

const Key = struct {
    slice: Slice,
    tier: u8,
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

/// Players in a role, of every champion: pick rates' denominators
const SlotKey = struct { slice: Slice, tier: u8, role: Role };
const Slots = std.AutoArrayHashMapUnmanaged(SlotKey, u32);

const BanKey = struct { slice: Slice, champion: u32 };
const Bans = std.AutoArrayHashMapUnmanaged(BanKey, u32);

const Player = struct {
    team: u1,
    role: Role,
    champion: u16,
    tier: u8,
    gold14: ?i64,
};

pub const Made = struct {
    files: []const root.File = &.{},
    /// Patches with games, newest first: the period choices
    patches: []const []const u8 = &.{},
    /// Of the patch views
    current: []const []const u8 = &.{},
};

/// The games of the 30-day and current-patch views on every platform, valid as for
/// stats.scan (ten players, one per team and role, a winner), for every champion
pub fn make(site: *const root.Site, db: store.Db, opts: root.Options) !Made {
    const a = site.arena;
    const index_of = try a.alloc(?u16, std.math.maxInt(u16) + 1);
    @memset(index_of, null);
    for (site.champs, 0..) |ch, i| {
        if (ch.id <= std.math.maxInt(u16)) index_of[ch.id] = @intCast(i);
    }
    const cells = try a.alloc(Cells, site.champs.len);
    @memset(cells, .empty);
    var slots: Slots = .empty;
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
    var game: struct { winner: i64 = 0, slice: Slice = undefined } = .{};
    while (true) {
        const more = try q.step();
        if (!more or !std.mem.eql(u8, q.bytes(0), current.items)) {
            if (current.items.len > 0 and !bad and n == 10) if (winnerSide(game.winner)) |winner| {
                for (players) |p| {
                    const s = try slots.getOrPutValue(a, .{ .slice = game.slice, .tier = p.tier, .role = p.role }, 0);
                    s.value_ptr.* += 1;
                    const c = &cells[index_of[p.champion] orelse continue];
                    const opp = opponent(&players, p) orelse continue;
                    const e = try c.getOrPutValue(a, .{
                        .slice = game.slice,
                        .tier = p.tier,
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
                }
            };
            if (!more) break;
            current.clearRetainingCapacity();
            try current.appendSlice(a, q.bytes(0));
            n = 0;
            bad = false;
            game = .{
                .winner = q.int(1),
                .slice = .{
                    .recent = q.int(2) >= opts.since_ms,
                    .platform = @intCast(indexOf(opts.all_platforms, q.bytes(4)) orelse 0),
                    .patch = try patchIndex(a, &patches, q.bytes(3)),
                },
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

    const bans = try countBans(a, db, opts, platform_json, patch_json, &patches);
    const sorted = try a.dupe([]const u8, patches.items);
    std.mem.sort([]const u8, sorted, {}, struct {
        fn f(_: void, x: []const u8, y: []const u8) bool {
            return stats.patchKey(x) > stats.patchKey(y);
        }
    }.f);

    const files = try a.alloc(root.File, site.champs.len + 1);
    {
        var aw: Writer.Allocating = .init(a);
        try writeMeta(&aw.writer, opts, patches.items, sorted, &slots);
        files[0] = .{ .path = "data/filters.json", .data = aw.written() };
    }
    for (site.champs, cells, files[1..]) |ch, *c, *f| {
        var aw: Writer.Allocating = .init(a);
        try writeChampion(site, &aw.writer, opts, patches.items, ch, c, &bans);
        f.* = .{ .path = try std.fmt.allocPrint(a, "data/filters/{s}.json", .{ch.slug}), .data = aw.written() };
    }
    return .{ .files = files, .patches = sorted, .current = opts.patches };
}

/// Bans by champion in the games make counts (by match: rank doesn't apply)
fn countBans(a: std.mem.Allocator, db: store.Db, opts: root.Options, platform_json: []const u8, patch_json: []const u8, patches: *std.ArrayList([]const u8)) !Bans {
    var bans: Bans = .empty;
    var q = try db.prepare(
        \\SELECT m.platform, m.patch, m.game_start >= ?, b.champion_id, count(DISTINCT b.match_id)
        \\FROM bans b JOIN matches m USING (match_id)
        \\WHERE m.queue_id = ? AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
        \\  AND (m.game_start >= ? OR m.patch IN (SELECT value FROM json_each(?)))
        \\GROUP BY 1, 2, 3, 4
    );
    defer q.deinit();
    try q.bind(.{ opts.since_ms, stats.ranked_solo, platform_json, opts.since_ms, patch_json });
    while (try q.step()) {
        const slice: Slice = .{
            .platform = @intCast(indexOf(opts.all_platforms, q.bytes(0)) orelse continue),
            .patch = try patchIndex(a, patches, q.bytes(1)),
            .recent = q.int(2) != 0,
        };
        try bans.put(a, .{ .slice = slice, .champion = @intCast(q.int(3)) }, @intCast(q.int(4)));
    }
    return bans;
}

fn writeMeta(w: *Writer, opts: root.Options, patches: []const []const u8, sorted: []const []const u8, slots: *const Slots) !void {
    try w.writeAll("{\"platforms\":");
    try std.json.Stringify.value(opts.all_platforms, .{}, w);
    try w.writeAll(",\"tiers\":");
    try std.json.Stringify.value(tiers, .{}, w);
    try w.writeAll(",\"patches\":");
    try std.json.Stringify.value(patches, .{}, w);
    try w.writeAll(",\"newest\":");
    try std.json.Stringify.value(sorted, .{}, w);
    try w.writeAll(",\"current\":");
    try std.json.Stringify.value(opts.patches, .{}, w);
    try w.writeAll(",\"roles\":[");
    for (Role.all, 0..) |r, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("\"{s}\"", .{root.roleSlug(r)});
    }
    // Players per role: platform, patch, recent, tier, role, players
    try w.writeAll("],\"slots\":[");
    var it = slots.iterator();
    var first = true;
    while (it.next()) |e| {
        if (!first) try w.writeByte(',');
        first = false;
        const k = e.key_ptr.*;
        try w.print("[{d},{d},{d},{d},{d},{d}]", .{
            k.slice.platform, k.slice.patch, @intFromBool(k.slice.recent), k.tier, @intFromEnum(k.role), e.value_ptr.*,
        });
    }
    try w.writeAll("]}\n");
}

fn writeChampion(site: *const root.Site, w: *Writer, opts: root.Options, patches: []const []const u8, ch: root.Champ, cells: *const Cells, bans: *const Bans) !void {
    // Platforms and patches by index, as in data/filters.json, repeated so a cached copy
    // of either file can't misread the other
    try w.writeAll("{\"platforms\":");
    try std.json.Stringify.value(opts.all_platforms, .{}, w);
    try w.writeAll(",\"patches\":");
    try std.json.Stringify.value(patches, .{}, w);
    // One array per slice: platform, patch, recent, tier, role, opponent, games, wins,
    // gold n, gold sum, gold sum of squares
    try w.writeAll(",\"rows\":[");
    var it = cells.iterator();
    var first = true;
    while (it.next()) |e| {
        if (!first) try w.writeByte(',');
        first = false;
        const k = e.key_ptr.*;
        const v = e.value_ptr.*;
        try w.print("[{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}]", .{
            k.slice.platform, k.slice.patch, @intFromBool(k.slice.recent), k.tier,     @intFromEnum(k.role), k.opponent,
            v.games,          v.wins,        v.gold_n,                     v.gold_sum, v.gold_sq,
        });
    }
    // Platform, patch, recent, games banned in
    try w.writeAll("],\"bans\":[");
    first = true;
    var bit = bans.iterator();
    while (bit.next()) |e| {
        const k = e.key_ptr.*;
        if (k.champion != ch.id) continue;
        if (!first) try w.writeByte(',');
        first = false;
        try w.print("[{d},{d},{d},{d}]", .{ k.slice.platform, k.slice.patch, @intFromBool(k.slice.recent), e.value_ptr.* });
    }
    // Each view's lane curve gold at 14 per role and opponent: mean and standard error,
    // keyed "region|period|rank" as the filter bar's values. An all-ranks entry also
    // means the view has that matchup's page
    try w.writeAll("],\"gold\":{");
    first = true;
    for (html.View.all, site.view_curves) |v, *maybe| {
        const curves = if (maybe.*) |*c| c else continue;
        const period = switch (v.period) {
            .days30 => "days30",
            .patch => if (opts.patches.len == 1) try std.fmt.allocPrint(site.arena, "patch:{s}", .{opts.patches[0]}) else continue,
        };
        const region = switch (v.region) {
            .euw => opts.platforms[0],
            .all => "all",
        };
        for (curve_ranks) |cr| {
            if (!first) try w.writeByte(',');
            first = false;
            try w.print("\"{s}|{s}|{s}\":[", .{ region, period, cr[1] });
            var n: usize = 0;
            for (Role.all) |r| for (site.champs) |other| {
                const view = curves.get(r, cr[0], ch.id, other.id) orelse continue;
                const e = view.estimate(.gold, core.curvesfile.lane_minute - 1);
                if (n > 0) try w.writeByte(',');
                n += 1;
                try w.print("[{d},{d},{d},{d}]", .{ @intFromEnum(r), other.id, e.mean, e.se });
            };
            try w.writeByte(']');
        }
    }
    try w.writeAll("}}\n");
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
