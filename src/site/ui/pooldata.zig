//! Pool page data: one file per champion and view (data/pool/<slug>.bin, ui.data
//! encoded), read by the pool island. The champion as a main in its most played role:
//! its hard and good lanes, every champion playing that role against those lanes, and
//! what its players also play. The page works out coverage and what to add from it
const std = @import("std");
const role = @import("role.zig");
const Role = role.Role;

/// Lanes closer to even than this, in tenths of a point, cover nothing (pool.Options)
pub const min_pp: i16 = 10;
/// Pairs with fewer games say nothing either way (pool.Options.min_pair_games)
pub const min_games: u32 = 30;

/// A lane matchup from the main's side: points vs usual in tenths
pub const Lane = struct { id: u16, pp: i16, games: u32 };

/// A champion's matchup against one enemy lane (hard then good, as File's)
pub const Cell = struct { pp: i16, games: u32 };

pub const Col = struct {
    id: u16,
    /// Main's players who also play it
    together: u32,
};

pub const Also = struct {
    id: u16,
    together: u32,
    /// Lift over the usual play rate, hundredths
    lift: u16,
};

pub const File = struct {
    id: u16,
    role: Role,
    players: u32,
    one_tricks: u32,
    /// Worst first
    hard: []const Lane,
    /// Best first
    good: []const Lane,
    /// Every champion playing the role with enough games
    cols: []const Col,
    /// cols.len rows of hard.len + good.len cells
    cells: []const Cell,
    /// Any role, highest lift first; empty under the minimum players
    also: []const Also,

    /// Lane bits fit a u8 and every cell is there; check a decoded file before use
    pub fn valid(f: *const File) bool {
        return f.hard.len <= 8 and f.good.len <= 8 and f.cells.len == f.cols.len * f.lanes();
    }

    pub fn lanes(f: *const File) usize {
        return f.hard.len + f.good.len;
    }

    pub fn col(f: *const File, id: u16) ?usize {
        for (f.cols, 0..) |c, i| if (c.id == id) return i;
        return null;
    }

    /// Column `c` against hard lane `k` (or good lane k - hard.len); null when thin
    pub fn cell(f: *const File, c: usize, k: usize) ?Cell {
        const x = f.cells[c * f.lanes() + k];
        return if (x.games < min_games) null else x;
    }

    fn covers(f: *const File, c: usize, k: usize) bool {
        const x = f.cell(c, k) orelse return false;
        return x.pp >= min_pp;
    }

    /// Bit per hard lane some champion of `pool` covers
    pub fn covered(f: *const File, pool: []const u16) u8 {
        var bits: u8 = 0;
        for (pool) |id| {
            const c = f.col(id) orelse continue;
            for (0..f.hard.len) |k| if (f.covers(c, k)) {
                bits |= @as(u8, 1) << @intCast(k);
            };
        }
        return bits;
    }

    pub const Why = enum { hard, banned, also };

    pub const Option = struct {
        col: usize,
        /// Hard (or good) lanes it covers, by bit
        lanes: u8,
        /// Hard lanes the pool covers with it
        with: u8,
        score: i32,
    };

    /// Up to out.len champions to add, best first (product rule: 3-5 with reasons).
    /// hard: the hard lanes it covers that the pool doesn't, then lanes in all;
    /// banned: the main's good lanes it is also good into; also: its players' lift
    pub fn options(f: *const File, pool: []const u16, why: Why, out: []Option) []Option {
        const have = f.covered(pool);
        var n: usize = 0;
        for (f.cols, 0..) |c, i| {
            if (std.mem.findScalar(u16, pool, c.id) != null) continue;
            var o: Option = .{ .col = i, .lanes = 0, .with = have, .score = 0 };
            const from: usize, const to: usize = if (why == .banned) .{ f.hard.len, f.lanes() } else .{ 0, f.hard.len };
            var sum: i32 = 0;
            for (from..to) |k| if (f.covers(i, k)) {
                o.lanes |= @as(u8, 1) << @intCast(k - from);
                sum += f.cell(i, k).?.pp;
            };
            if (why != .banned) o.with = have | o.lanes;
            o.score = switch (why) {
                .hard => if (o.with == have) continue else 10_000 * @as(i32, @popCount(o.with)) + 1_000 * @as(i32, @popCount(o.lanes)) + sum,
                .banned => if (o.lanes == 0) continue else 1_000 * @as(i32, @popCount(o.lanes)) + sum,
                .also => @as(i32, @intCast(f.liftOf(c.id) orelse continue)),
            };
            var pos = n;
            while (pos > 0 and out[pos - 1].score < o.score) pos -= 1;
            if (pos >= out.len) continue;
            if (n == out.len) n -= 1;
            @memmove(out[pos + 1 .. n + 1], out[pos..n]);
            out[pos] = o;
            n += 1;
        }
        return out[0..n];
    }

    fn liftOf(f: *const File, id: u16) ?u16 {
        for (f.also) |a| if (a.id == id) return a.lift;
        return null;
    }
};

const testing = std.testing;

/// Darius top: hard into 10, 11; good into 20. Cols: Darius 1, Garen 2, Jax 3, Mundo 4
pub const demo: File = .{
    .id = 1,
    .role = .top,
    .players = 400,
    .one_tricks = 120,
    .hard = &.{ .{ .id = 10, .pp = -26, .games = 900 }, .{ .id = 11, .pp = -17, .games = 700 } },
    .good = &.{.{ .id = 20, .pp = 21, .games = 800 }},
    .cols = &.{ .{ .id = 1, .together = 400 }, .{ .id = 2, .together = 196 }, .{ .id = 3, .together = 80 }, .{ .id = 4, .together = 12 } },
    .cells = &.{
        .{ .pp = -26, .games = 900 }, .{ .pp = -17, .games = 700 }, .{ .pp = 21, .games = 800 },
        .{ .pp = 15, .games = 300 },  .{ .pp = 3, .games = 200 },   .{ .pp = 12, .games = 400 },
        .{ .pp = 25, .games = 120 },  .{ .pp = 18, .games = 90 },   .{ .pp = -5, .games = 100 },
        .{ .pp = 30, .games = 20 },   .{ .pp = 11, .games = 60 },   .{ .pp = 14, .games = 50 },
    },
    .also = &.{ .{ .id = 2, .together = 196, .lift = 310 }, .{ .id = 3, .together = 80, .lift = 140 } },
};

test "coverage and options: weak lanes, when banned, also played" {
    const f = demo;
    try testing.expect(f.valid());
    var short = demo;
    short.cells = demo.cells[1..];
    try testing.expect(!short.valid());
    try testing.expectEqual(@as(u8, 0), f.covered(&.{1}));
    try testing.expectEqual(@as(u8, 0b01), f.covered(&.{ 1, 2 }));
    // Mundo's +3.0 into 10 is thin (20 games): only 11
    try testing.expectEqual(@as(u8, 0b10), f.covered(&.{ 1, 4 }));

    var buf: [5]File.Option = undefined;
    const hard = f.options(&.{1}, .hard, &buf);
    try testing.expectEqual(3, hard.len);
    try testing.expectEqual(@as(u16, 3), f.cols[hard[0].col].id); // Jax covers both
    try testing.expectEqual(@as(u8, 0b11), hard[0].with);

    const banned = f.options(&.{1}, .banned, &buf);
    try testing.expectEqual(2, banned.len);
    try testing.expectEqual(@as(u16, 4), f.cols[banned[0].col].id); // +1.4 over Garen's +1.2

    const also = f.options(&.{1}, .also, &buf);
    try testing.expectEqual(2, also.len);
    try testing.expectEqual(@as(u16, 2), f.cols[also[0].col].id);
}
