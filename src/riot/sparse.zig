//! `--timelines-sparse N`: a match the timeline sample skips gets one anyway while a
//! lane of it is rare, under N timelines so far in its every-region cell (role, champion
//! pair, the game's rank bracket as core.curvesfile.Bracket) on the newest patch. Off by
//! default: replayed over 16.20 (docs/data.md) it keeps 91% of the skipped games at N
//! 200, as nearly every game has one rare lane; `--timelines-sparse-from DIAMOND` with
//! `--timelines 35` costs flat 50%'s calls and keeps Diamond+ full coverage

const std = @import("std");
const tiers = @import("store").schema.tiers;

const positions = @import("core").Role.positions;

/// One game's lanes and ranks, filled a participant at a time
pub const Game = struct {
    /// Champion per position, per team (blue, red); 0 unknown
    champions: [2][positions.len]u16 = @splat(@splat(0)),
    ranks: [10]u8 = undefined,
    n_ranks: usize = 0,

    pub fn rankTier(g: *Game, tier: []const u8) void {
        const r = rankOf(tier) orelse return;
        if (g.n_ranks == g.ranks.len) return;
        g.ranks[g.n_ranks] = r;
        g.n_ranks += 1;
    }

    pub fn lane(g: *Game, team: i64, position: ?[]const u8, champion: i64) void {
        const side: usize = switch (team) {
            100 => 0,
            200 => 1,
            else => return,
        };
        const pos = position orelse return;
        for (positions, 0..) |name, i| {
            if (std.mem.eql(u8, name, pos)) g.champions[side][i] = std.math.cast(u16, champion) orelse 0;
        }
    }

    /// Median rank index (as curvesfile.medianRank), null under five known
    pub fn rank(g: *const Game) ?u8 {
        if (g.n_ranks < 5) return null;
        var r = g.ranks;
        std.mem.sort(u8, r[0..g.n_ranks], {}, std.sort.asc(u8));
        return r[g.n_ranks / 2];
    }

    /// 0 every game, 1 Iron-Silver, 2 Gold-Emerald, 3 Diamond+
    fn bracket(g: *const Game) u2 {
        const r = g.rank() orelse return 0;
        return if (r < 3) 1 else if (r < 6) 2 else 3;
    }

    /// Cell keys of the lanes with both champions known
    fn keys(g: *const Game, b: u2, out: *[positions.len]u32) []u32 {
        var n: usize = 0;
        for (0..positions.len) |i| {
            const x = g.champions[0][i];
            const y = g.champions[1][i];
            if (x == 0 or y == 0) continue;
            out[n] = key(@intCast(i), @min(x, y), @max(x, y), b);
            n += 1;
        }
        return out[0..n];
    }
};

/// Lowest first, as core.curvesfile.tiers (Iron 0); store's run highest first
pub fn rankOf(tier: []const u8) ?u8 {
    for (tiers, 0..) |name, i| {
        if (std.mem.eql(u8, name, tier)) return @intCast(tiers.len - 1 - i);
    }
    return null;
}

fn key(role: u3, a: u16, b: u16, bracket: u2) u32 {
    // Champion ids fit 13 bits (store/draft.zig)
    return @as(u32, role) << 28 | @as(u32, a & 0x1fff) << 15 | @as(u32, b & 0x1fff) << 2 | bracket;
}

/// Timelines so far per cell, of `patch` only (Patches.code)
pub const Cells = struct {
    counts: std.AutoHashMapUnmanaged(u32, u32) = .empty,
    patch: u32 = 0,

    pub fn deinit(c: *Cells, gpa: std.mem.Allocator) void {
        c.counts.deinit(gpa);
    }

    /// Whether a game of `patch` counts: a newer patch starts the counts again
    pub fn current(c: *Cells, patch: u32) bool {
        if (patch > c.patch) {
            c.counts.clearRetainingCapacity();
            c.patch = patch;
        }
        return patch == c.patch;
    }

    /// A lane under `below` timelines in its cell for the game's bracket
    pub fn rare(c: *const Cells, g: *const Game, below: u32) bool {
        var buf: [positions.len]u32 = undefined;
        for (g.keys(g.bracket(), &buf)) |k| {
            if ((c.counts.get(k) orelse 0) < below) return true;
        }
        return false;
    }

    /// A timeline for the game: its bracket's cells and every game's
    pub fn add(c: *Cells, gpa: std.mem.Allocator, g: *const Game) !void {
        const b = g.bracket();
        var buf: [positions.len]u32 = undefined;
        for ([_]u2{ 0, b }, 0..) |br, i| {
            if (i == 1 and b == 0) break;
            for (g.keys(br, &buf)) |k| {
                const e = try c.counts.getOrPut(gpa, k);
                e.value_ptr.* = if (e.found_existing) e.value_ptr.* + 1 else 1;
            }
        }
    }
};

test "a game is rare while one lane's cell has fewer timelines than the threshold" {
    const gpa = std.testing.allocator;
    var cells: Cells = .{};
    defer cells.deinit(gpa);
    try std.testing.expect(cells.current(16020));
    var g: Game = .{};
    for (0..10) |slot| {
        const team: i64 = if (slot < 5) 100 else 200;
        g.lane(team, positions[slot % 5], @intCast(slot + 1));
        g.rankTier("DIAMOND");
    }
    try std.testing.expectEqual(@as(?u8, 6), g.rank());
    try std.testing.expect(cells.rare(&g, 2));
    try cells.add(gpa, &g);
    try std.testing.expect(cells.rare(&g, 2));
    try cells.add(gpa, &g);
    try std.testing.expect(!cells.rare(&g, 2));
    // Both cells: Diamond+ and every game, five lanes each
    try std.testing.expectEqual(@as(u32, 10), cells.counts.count());

    // The same lanes at Gold: their bracket's cells are empty
    var gold = g;
    gold.n_ranks = 0;
    for (0..10) |_| gold.rankTier("GOLD");
    try std.testing.expect(cells.rare(&gold, 2));
    // No known ranks: the every-game cell, already full
    var unranked = g;
    unranked.n_ranks = 0;
    try std.testing.expect(!cells.rare(&unranked, 2));

    try std.testing.expect(!cells.current(16019));
    try std.testing.expect(cells.current(16021));
    try std.testing.expect(cells.rare(&g, 1));
}
