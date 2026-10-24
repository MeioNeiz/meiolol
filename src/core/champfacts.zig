//! Champion facts file (champ-facts.tsv) for the desktop's comp view (src/comp.zig):
//! each champion's damage split and the team damage mix tally (Learn's, src/learn.zig),
//! and each champion-role's early or late lean (`meiolol lean`, src/lean.zig). The
//! site's shared view writes it as data/champ-facts.tsv; the web loop lists it in the
//! desktop manifest. One fact per line, its kind first, tab separated:
//!   meiolol-champs VERSION PATCH         the header; PATCH is the damage split's
//!   damage CHAMPION MAGIC                magic share of damage to champions, 0..1
//!   mix BUCKET GAMES WINS                teams by damage mix (mix_bounds)
//!   lean CHAMPION ROLE GAMES GOLD GOLD_SD WIN_PP WIN_SD    as lean.tsv's rows
//! Readers skip kinds they don't know, so a new kind needs no version bump; a changed
//! kind does.

const std = @import("std");
const Role = @import("roles.zig").Role;
const Counts = @import("statsfile.zig").Counts;

pub const magic = "meiolol-champs";
pub const version: u32 = 1;
/// Far above the ~170 champions times five roles; bounds what a damaged file allocates
const max_rows = 4096;

/// Team damage mix buckets by the team's average magic share: mostly physical below the
/// first, mostly magic from the second
pub const mix_bounds = [_]f64{ 0.3, 0.7 };
pub const mixes = mix_bounds.len + 1;

pub fn mixBucket(share: f64) usize {
    var b: usize = 0;
    while (b < mix_bounds.len and share >= mix_bounds[b]) b += 1;
    return b;
}

/// lean.zig's minutes: team gold lead at the first, wins from an even game at the second
pub const gold_minute = 14;
pub const win_minute = 20;
/// Fewer fit games still going at win_minute and the champion-role says nothing
pub const lean_min_games = 200;
/// An effect is clear this many posterior sds from 0
pub const clear_z = 2.0;

pub const Lean = enum { early, late, none };

/// One champion-role's lean, in display units
pub const LeanRow = struct {
    champion: u32,
    role: Role,
    /// Fit games still going at win_minute
    games: u32,
    /// Team gold lead at gold_minute against the role's average pick, ± its sd
    gold: f64,
    gold_sd: f64,
    /// Win pp from an even game at win_minute against the role's average pick (log-odds
    /// x 25: the change at 50%), ± its sd
    win: f64,
    win_sd: f64,

    pub fn goldClear(r: LeanRow) bool {
        return clear(r.gold, r.gold_sd, r.games);
    }

    pub fn winClear(r: LeanRow) bool {
        return clear(r.win, r.win_sd, r.games);
    }

    pub fn enough(r: LeanRow) bool {
        return r.games >= lean_min_games;
    }

    /// Early: ahead at gold_minute and wins less from even; late: the other way round
    pub fn lean(r: LeanRow) Lean {
        if (!r.goldClear() or !r.winClear()) return .none;
        if (r.gold > 0 and r.win < 0) return .early;
        if (r.gold < 0 and r.win > 0) return .late;
        return .none;
    }
};

fn clear(b: f64, sd: f64, n: u32) bool {
    return n >= lean_min_games and sd > 0 and @abs(b) >= clear_z * sd;
}

pub const Damage = struct { champion: u32, magic: f32 };

pub const Facts = struct {
    patch: []const u8 = "",
    damage: []const Damage = &.{},
    mix: [mixes]Counts = @splat(.{ .games = 0, .wins = 0 }),
    lean: []const LeanRow = &.{},

    /// Magic share of the champion's damage to champions; null when unsampled
    pub fn magicOf(f: *const Facts, champion: u32) ?f32 {
        for (f.damage) |d| if (d.champion == champion) return d.magic;
        return null;
    }

    pub fn leanOf(f: *const Facts, champion: u32, role: Role) ?LeanRow {
        for (f.lean) |r| if (r.champion == champion and r.role == role) return r;
        return null;
    }

    /// Allocates in `arena`; the patch borrows `bytes`
    pub fn parse(arena: std.mem.Allocator, bytes: []const u8) !Facts {
        var lines = std.mem.tokenizeScalar(u8, bytes, '\n');
        var head = std.mem.splitScalar(u8, lines.next() orelse return error.BadFacts, '\t');
        if (!std.mem.eql(u8, head.next() orelse "", magic)) return error.BadFacts;
        if (try int(u32, head.next()) != version) return error.UnsupportedVersion;
        var f: Facts = .{ .patch = head.next() orelse "" };
        var damage: std.ArrayList(Damage) = .empty;
        var lean: std.ArrayList(LeanRow) = .empty;
        while (lines.next()) |line| {
            if (damage.items.len + lean.items.len >= max_rows) return error.BadFacts;
            var it = std.mem.splitScalar(u8, line, '\t');
            const kind = it.next() orelse continue;
            if (std.mem.eql(u8, kind, "damage")) {
                const champion = try int(u32, it.next());
                const m = try float(it.next());
                if (!(m >= 0 and m <= 1)) return error.BadFacts;
                try damage.append(arena, .{ .champion = champion, .magic = @floatCast(m) });
            } else if (std.mem.eql(u8, kind, "mix")) {
                const b = try int(usize, it.next());
                if (b >= mixes) return error.BadFacts;
                f.mix[b] = .{ .games = try int(u32, it.next()), .wins = try int(u32, it.next()) };
                if (f.mix[b].wins > f.mix[b].games) return error.BadFacts;
            } else if (std.mem.eql(u8, kind, "lean")) {
                try lean.append(arena, .{
                    .champion = try int(u32, it.next()),
                    .role = std.meta.stringToEnum(Role, it.next() orelse "") orelse return error.BadFacts,
                    .games = try int(u32, it.next()),
                    .gold = try finite(it.next()),
                    .gold_sd = try finite(it.next()),
                    .win = try finite(it.next()),
                    .win_sd = try finite(it.next()),
                });
            }
        }
        f.damage = damage.items;
        f.lean = lean.items;
        return f;
    }

    fn int(comptime T: type, s: ?[]const u8) !T {
        return std.fmt.parseInt(T, s orelse return error.BadFacts, 10) catch error.BadFacts;
    }

    fn float(s: ?[]const u8) !f64 {
        return std.fmt.parseFloat(f64, s orelse return error.BadFacts) catch error.BadFacts;
    }

    fn finite(s: ?[]const u8) !f64 {
        const x = try float(s);
        return if (std.math.isFinite(x)) x else error.BadFacts;
    }
};

/// `magic` indexed as `ids` (null: unsampled)
pub fn write(w: *std.Io.Writer, patch: []const u8, ids: []const u32, magic_share: []const ?f32, mix: [mixes]Counts, lean: []const LeanRow) !void {
    try w.print("{s}\t{d}\t{s}\n", .{ magic, version, patch });
    for (ids, magic_share) |id, m| if (m) |x| try w.print("damage\t{d}\t{d:.3}\n", .{ id, x });
    for (mix, 0..) |m, b| try w.print("mix\t{d}\t{d}\t{d}\n", .{ b, m.games, m.wins });
    for (lean) |r| try w.print("lean\t{d}\t{t}\t{d}\t{d:.0}\t{d:.0}\t{d:.2}\t{d:.2}\n", .{ r.champion, r.role, r.games, r.gold, r.gold_sd, r.win, r.win_sd });
}

const testing = std.testing;

test "facts file round trip, unknown kinds skipped" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const rows = [_]LeanRow{.{ .champion = 119, .role = .bottom, .games = 900, .gold = 900, .gold_sd = 100, .win = -8, .win_sd = 1.5 }};
    var aw: std.Io.Writer.Allocating = .init(arena);
    try write(&aw.writer, "16.21", &.{ 1, 2, 3 }, &.{ 0.9, null, 0.05 }, .{ .{ .games = 10, .wins = 4 }, .{ .games = 20, .wins = 10 }, .{ .games = 5, .wins = 2 } }, &rows);
    try aw.writer.writeAll("someday\t1\t2\n");
    const f = try Facts.parse(arena, aw.written());
    try testing.expectEqualStrings("16.21", f.patch);
    try testing.expectApproxEqAbs(0.9, f.magicOf(1).?, 1e-6);
    try testing.expectEqual(null, f.magicOf(2));
    try testing.expectEqual(20, f.mix[1].games);
    try testing.expectEqual(Lean.early, f.leanOf(119, .bottom).?.lean());
    try testing.expectEqual(null, f.leanOf(119, .top));
    try testing.expectError(error.BadFacts, Facts.parse(arena, "meiolol-champs\t1\t16.21\ndamage\t1\t1.5\n"));
    try testing.expectError(error.UnsupportedVersion, Facts.parse(arena, "meiolol-champs\t2\t16.21\n"));
}

fn fuzzParse(valid: []const u8, s: *testing.Smith) !void {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const f = Facts.parse(arena, try @import("fuzz.zig").mutate(s, arena, valid)) catch return;
    for (f.lean) |r| _ = r.lean();
}

test "fuzz: a damaged facts file is parsed or refused" {
    const valid: []const u8 = "meiolol-champs\t1\t16.21\ndamage\t1\t0.900\nmix\t0\t10\t4\nlean\t119\tbottom\t900\t900\t100\t-8.00\t1.50\n";
    try testing.fuzz(valid, fuzzParse, .{});
}
