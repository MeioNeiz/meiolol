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

/// A game's rank (gameTier) where it was played: ban rates by rank, as the ban order
/// doesn't say reliably which player banned
const GameKey = struct { slice: Slice, tier: u8 };
const Games = std.AutoArrayHashMapUnmanaged(GameKey, u32);
const BanKey = struct { game: GameKey, champion: u32 };
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

/// The games' matches; make reads each one's players and bans by primary key. A join
/// ordered by match_id walks every match ever stored: with +match_id the start and patch
/// indexes find the matches and only those are sorted. The order fixes the first-seen
/// order of patches and the maps, so the files' byte order
const games_sql =
    \\SELECT match_id, winning_team, game_start, patch, platform
    \\FROM matches
    \\WHERE queue_id = ? AND platform IN (SELECT value FROM json_each(?))
    \\  AND remake = 0 AND winning_team IS NOT NULL
    \\  AND (game_start >= ? OR patch IN (SELECT value FROM json_each(?)))
    \\ORDER BY +match_id
;

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
    var games: Games = .empty;
    var bans: Bans = .empty;
    var patches: std.ArrayList([]const u8) = .empty;

    const platform_json = try std.json.Stringify.valueAlloc(a, opts.all_platforms, .{});
    const patch_json = try std.json.Stringify.valueAlloc(a, opts.patches, .{});
    var q = try db.prepare(games_sql);
    defer q.deinit();
    try q.bind(.{ stats.ranked_solo, platform_json, opts.since_ms, patch_json });
    var pq = try db.prepare(
        \\SELECT team_id, position, champion_id, tier,
        \\  CASE WHEN gold15 IS NULL THEN NULL ELSE gold14 END
        \\FROM participants WHERE match_id = ? ORDER BY slot
    );
    defer pq.deinit();
    var bq = try db.prepare("SELECT champion_id FROM bans WHERE match_id = ? ORDER BY team_id, pick_turn");
    defer bq.deinit();

    var players: [10]Player = undefined;
    while (try q.step()) {
        const m = q.row(struct {
            match_id: []const u8,
            winner: i64,
            start: i64,
            patch: []const u8,
            platform: []const u8,
        });
        var n: usize = 0;
        var rows: usize = 0;
        var bad = false;
        try pq.bind(.{m.match_id});
        while (try pq.step()) : (rows += 1) {
            const r = pq.row(struct {
                team: i64,
                position: ?[]const u8,
                champion: i64,
                tier: ?[]const u8,
                gold14: ?i64,
            });
            if (n == 10) {
                bad = true;
                continue;
            }
            const team: u1 = switch (r.team) {
                100 => 0,
                200 => 1,
                else => {
                    bad = true;
                    continue;
                },
            };
            const role = Role.fromLcu(r.position orelse "") orelse {
                bad = true;
                continue;
            };
            if (r.champion <= 0 or r.champion > std.math.maxInt(u16)) bad = true;
            for (players[0..n]) |p| {
                if (p.team == team and p.role == role) bad = true;
            }
            players[n] = .{
                .team = team,
                .role = role,
                .champion = @intCast(std.math.clamp(r.champion, 0, std.math.maxInt(u16))),
                .tier = @intCast(if (r.tier) |t| indexOf(&tiers, t) orelse tiers.len else tiers.len),
                .gold14 = r.gold14,
            };
            n += 1;
        }
        if (rows == 0) continue;
        const slice: Slice = .{
            .recent = m.start >= opts.since_ms,
            .platform = @intCast(indexOf(opts.all_platforms, m.platform) orelse 0),
            .patch = try patchIndex(a, &patches, m.patch),
        };
        if (bad or n < 10) continue;
        const winner = winnerSide(m.winner) orelse continue;
        const gk: GameKey = .{ .slice = slice, .tier = gameTier(&players) };
        (try games.getOrPutValue(a, gk, 0)).value_ptr.* += 1;
        for (players) |p| {
            const sl = try slots.getOrPutValue(a, .{ .slice = slice, .tier = p.tier, .role = p.role }, 0);
            sl.value_ptr.* += 1;
            const c = &cells[index_of[p.champion] orelse continue];
            const opp = opponent(&players, p) orelse continue;
            const e = try c.getOrPutValue(a, .{
                .slice = slice,
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
        // Once per game: both teams may ban the same champion
        var banned: [10]u32 = undefined;
        var nb: usize = 0;
        try bq.bind(.{m.match_id});
        while (try bq.step()) {
            const champion = bq.row(struct { champion: u32 }).champion;
            if (std.mem.indexOfScalar(u32, banned[0..nb], champion) != null or nb == banned.len) continue;
            banned[nb] = champion;
            nb += 1;
            (try bans.getOrPutValue(a, .{ .game = gk, .champion = champion }, 0)).value_ptr.* += 1;
        }
    }

    const sorted = try a.dupe([]const u8, patches.items);
    std.mem.sort([]const u8, sorted, {}, struct {
        fn f(_: void, x: []const u8, y: []const u8) bool {
            return stats.patchKey(x) > stats.patchKey(y);
        }
    }.f);

    const files = try a.alloc(root.File, site.champs.len + 1);
    {
        var aw: Writer.Allocating = .init(a);
        try writeMeta(&aw.writer, opts, patches.items, sorted, &slots, &games);
        files[0] = .{ .path = "data/filters.json", .data = aw.written() };
    }
    for (site.champs, cells, files[1..]) |ch, *c, *f| {
        var aw: Writer.Allocating = .init(a);
        try writeChampion(site, &aw.writer, opts, patches.items, ch, c, &bans);
        f.* = .{ .path = try a.print("data/filters/{s}.json", .{ch.slug}), .data = aw.written() };
    }
    return .{ .files = files, .patches = sorted, .current = opts.patches };
}

/// Median ladder tier of the game's players (lower middle); tiers.len when none is on
/// the ladder
fn gameTier(players: *const [10]Player) u8 {
    var ranked: [10]u8 = undefined;
    var n: usize = 0;
    for (players) |p| if (p.tier < tiers.len) {
        ranked[n] = p.tier;
        n += 1;
    };
    if (n == 0) return tiers.len;
    std.mem.sort(u8, ranked[0..n], {}, std.sort.asc(u8));
    return ranked[(n - 1) / 2];
}

fn writeMeta(w: *Writer, opts: root.Options, patches: []const []const u8, sorted: []const []const u8, slots: *const Slots, games: *const Games) !void {
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
            k.slice.platform, k.slice.patch, @intFromBool(k.slice.recent), k.tier, @backingInt(k.role), e.value_ptr.*,
        });
    }
    // Games by their rank (gameTier), for ban rates: platform, patch, recent, tier, games
    try w.writeAll("],\"games\":[");
    first = true;
    var git = games.iterator();
    while (git.next()) |e| {
        if (!first) try w.writeByte(',');
        first = false;
        const k = e.key_ptr.*;
        try w.print("[{d},{d},{d},{d},{d}]", .{ k.slice.platform, k.slice.patch, @intFromBool(k.slice.recent), k.tier, e.value_ptr.* });
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
            k.slice.platform, k.slice.patch, @intFromBool(k.slice.recent), k.tier,     @backingInt(k.role), k.opponent,
            v.games,          v.wins,        v.gold_n,                     v.gold_sum, v.gold_sq,
        });
    }
    // Platform, patch, recent, the game's rank (gameTier), games banned in
    try w.writeAll("],\"bans\":[");
    first = true;
    var bit = bans.iterator();
    while (bit.next()) |e| {
        const k = e.key_ptr.*;
        if (k.champion != ch.id) continue;
        if (!first) try w.writeByte(',');
        first = false;
        const g = k.game;
        try w.print("[{d},{d},{d},{d},{d}]", .{ g.slice.platform, g.slice.patch, @intFromBool(g.slice.recent), g.tier, e.value_ptr.* });
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
            .patch => if (opts.patches.len == 1) try site.arena.print("patch:{s}", .{opts.patches[0]}) else continue,
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
                try w.print("[{d},{d},{d},{d}]", .{ @backingInt(r), other.id, e.mean, e.se });
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

test "games come from the start and patch indexes, not a walk of every match" {
    const db = try store.schema.memory();
    defer db.close();
    var q = try db.prepare("EXPLAIN QUERY PLAN " ++ games_sql);
    defer q.deinit();
    var plan: std.ArrayList(u8) = .empty;
    defer plan.deinit(std.testing.allocator);
    while (try q.step()) try plan.appendSlice(std.testing.allocator, q.bytes(3));
    for ([_][]const u8{ "USING INDEX matches_start", "USING INDEX matches_patch" }) |want| {
        if (std.mem.indexOf(u8, plan.items, want) == null) {
            std.debug.print("plan: {s}\n", .{plan.items});
            return error.TestUnexpectedResult;
        }
    }
}

test "a game's rows, slots and bans, once per game" {
    const gpa = std.testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const db = try store.schema.memory();
    defer db.close();
    // EUW1_1: champions 1-5 (Gold, blue, won) against 6-10 (Platinum, the support off
    // the ladder), top laners' gold at 14 500 and 300; both teams ban 11. EUW1_2: nine
    // players, left out
    try db.exec(
        \\INSERT INTO matches VALUES ('EUW1_1', 'riot', 'EUW1', 420, '16.20', '16.20.1', 1000, 1800, 100, 0),
        \\  ('EUW1_2', 'riot', 'EUW1', 420, '16.20', '16.20.1', 1000, 1800, 100, 0);
        \\INSERT INTO bans VALUES ('EUW1_1', 100, 1, 11), ('EUW1_1', 200, 6, 11), ('EUW1_2', 100, 1, 11);
    );
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for ([_][]const u8{ "EUW1_1", "EUW1_2" }, [_]usize{ 10, 9 }) |id, players| {
        for (0..players) |slot| {
            const blue = slot < 5;
            const tier: ?[]const u8 = if (slot == 9) null else if (blue) "GOLD" else "PLATINUM";
            const gold14: ?i64 = switch (slot) {
                0 => 500,
                5 => 300,
                else => null,
            };
            try db.run(
                \\INSERT INTO participants (match_id, slot, team_id, champion_id, position, win, tier, gold14, gold15)
                \\VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            , .{ id, slot, @as(i64, if (blue) 100 else 200), slot + 1, positions[slot % 5], @intFromBool(blue), tier, gold14, gold14 });
        }
    }
    var champs: [11]root.Champ = undefined;
    for (&champs, 0..) |*ch, i| {
        const slug = try a.print("c{d}", .{i + 1});
        ch.* = .{ .c = i, .id = @intCast(i + 1), .key = slug, .name = slug, .slug = slug, .banned = 0, .games = 0 };
    }
    const no_curves: [html.View.count]?core.curvesfile.Curves = @splat(null);
    const opts: root.Options = .{
        .out_dir = "",
        .patches = &.{"16.20"},
        .since_ms = 0,
        .all_platforms = &.{"EUW1"},
        .contact = "",
        .updated = "",
    };
    var site: root.Site = undefined;
    site.arena = a;
    site.champs = &champs;
    site.view_curves = &no_curves;
    const made = try make(&site, db, opts);
    try std.testing.expectEqual(champs.len + 1, made.files.len);
    const file = struct {
        fn f(files: []const root.File, path: []const u8) []const u8 {
            for (files) |x| if (std.mem.eql(u8, x.path, path)) return x.data;
            return "";
        }
    }.f;
    const head = "{\"platforms\":[\"EUW1\"],\"patches\":[\"16.20\"],";
    // Platform, patch, recent, tier, role, opponent, games, wins, gold n, sum, squares
    try std.testing.expectEqualStrings(head ++ "\"rows\":[[0,0,1,3,0,6,1,1,1,200,40000]],\"bans\":[],\"gold\":{}}\n", file(made.files, "data/filters/c1.json"));
    try std.testing.expectEqualStrings(head ++ "\"rows\":[[0,0,1,4,0,1,1,0,1,-200,40000]],\"bans\":[],\"gold\":{}}\n", file(made.files, "data/filters/c6.json"));
    try std.testing.expectEqualStrings(head ++ "\"rows\":[[0,0,1,10,4,5,1,0,0,0,0]],\"bans\":[],\"gold\":{}}\n", file(made.files, "data/filters/c10.json"));
    // Banned by both teams: one game, of Gold rank (the players' lower median)
    try std.testing.expectEqualStrings(head ++ "\"rows\":[],\"bans\":[[0,0,1,3,1]],\"gold\":{}}\n", file(made.files, "data/filters/c11.json"));
    const meta = file(made.files, "data/filters.json");
    for ([_][]const u8{
        "\"roles\":[\"top\",\"jungle\",\"mid\",\"bot\",\"support\"]",
        "\"slots\":[[0,0,1,3,0,1],[0,0,1,3,1,1],[0,0,1,3,2,1],[0,0,1,3,3,1],[0,0,1,3,4,1]," ++
            "[0,0,1,4,0,1],[0,0,1,4,1,1],[0,0,1,4,2,1],[0,0,1,4,3,1],[0,0,1,10,4,1]]",
        "\"games\":[[0,0,1,3,1]]}",
    }) |want| if (std.mem.indexOf(u8, meta, want) == null) {
        std.debug.print("data/filters.json lacks {s}:\n{s}\n", .{ want, meta });
        return error.TestUnexpectedResult;
    };
}
