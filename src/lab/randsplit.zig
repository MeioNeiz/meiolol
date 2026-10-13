//! LoLDraftAI's evaluation on our data, beside our time split (research question
//! draft-predictor-methods C5, C6, C17; docs/model.md "Neural draft models"): a seeded
//! random 90/10 split of the non-test games, and its 15-minute filters.
//! `meiolol-lab ldai-filter SNAP` writes SNAP/ldai_filter.tsv: match_id, then why the game
//! is dropped (ok when kept). Its prepare_data.py drops a game where any player has, at
//! 15:00, under 2400 total gold, over 10 deaths, under 25 CS (not support) or under level
//! 4, which also drops every game shorter than 15:00. Read at frame 15 of the compact
//! timeline: gold total_gold, CS minions + jungle minions, deaths the champion kills of
//! the player up to that frame. Its extraction code isn't in our copy, so CS with jungle
//! minions and deaths by frame time are our reading of creepScore and deaths_at_900000.
//! A game of 15:00 or more without a timeline reaching 15:00 can't be judged: no_timeline,
//! dropped as LoLDraftAI drops a game missing its columns.
//! The random split never touches our test set and never replaces our protocol: dev only.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("../stats.zig");
const timeline = @import("../riot/timeline.zig");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");

const Io = std.Io;

pub const usage =
    \\  ldai-filter SNAP                write SNAP/ldai_filter.tsv: LoLDraftAI's 15-minute
    \\                                  filters per game (lab/randsplit.zig)
    \\
;

pub const file_name = "ldai_filter.tsv";

/// LoLDraftAI's share of games held out
pub const test_share = 0.1;

/// Whether a non-test game is in the random split's held-out tenth for this seed. Test
/// games are never in either half
pub fn inTest(g: rows.Game, seed: u32) bool {
    if (g.is_test) return false;
    const h = std.hash.Wyhash.hash(seed, g.match_id);
    return @as(f64, @floatFromInt(h >> 11)) / @as(f64, 1 << 53) < test_share;
}

pub const Reason = enum { ok, short, no_timeline, gold, deaths, cs, level };

pub const min_gold = 2400;
pub const max_deaths = 10;
pub const min_cs = 25;
pub const min_level = 4;

/// One player at 15:00
pub const At15 = struct { gold: i32, deaths: i32, cs: i32, level: i32, support: bool };

/// LoLDraftAI's order: gold, then deaths, CS and level
pub fn judge(players: *const [10]At15) Reason {
    for (players) |p| if (p.gold < min_gold) return .gold;
    for (players) |p| if (p.deaths > max_deaths) return .deaths;
    for (players) |p| if (!p.support and p.cs < min_cs) return .cs;
    for (players) |p| if (p.level < min_level) return .level;
    return .ok;
}

/// SNAP/ldai_filter.tsv by match key; a game without a line is dropped
pub const Filter = struct {
    keep_ids: std.AutoHashMapUnmanaged(u64, void) = .empty,

    pub fn deinit(f: *Filter, gpa: std.mem.Allocator) void {
        f.keep_ids.deinit(gpa);
    }

    pub fn keep(f: *const Filter, g: rows.Game) bool {
        return f.keep_ids.contains(stats.matchKey(g.match_id));
    }
};

pub fn loadFilter(gpa: std.mem.Allocator, io: Io, snap: []const u8) !Filter {
    const path = try std.fs.path.join(gpa, &.{ snap, file_name });
    defer gpa.free(path);
    const text = Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(256 << 20)) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("{s} missing: run meiolol-lab ldai-filter SNAP first\n", .{path});
            return err;
        },
        else => return err,
    };
    defer gpa.free(text);
    var f: Filter = .{};
    errdefer f.deinit(gpa);
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    _ = lines.next();
    while (lines.next()) |line| {
        var cols = std.mem.tokenizeScalar(u8, line, '\t');
        const id = cols.next() orelse continue;
        if (std.mem.eql(u8, cols.next() orelse continue, "ok")) try f.keep_ids.put(gpa, stats.matchKey(id), {});
    }
    return f;
}

pub fn main(gpa: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len != 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const snap = argv[0];
    var legendaries: std.AutoHashMapUnmanaged(u64, void) = .empty;
    var d = try rows.load(gpa, snap, &legendaries);
    defer d.deinit();

    // Supports by game and participant (slot 0-9 is participant 1-10)
    var index: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer index.deinit(gpa);
    for (d.games, 0..) |g, gi| try index.put(gpa, stats.matchKey(g.match_id), @intCast(gi));
    const support = try gpa.alloc([10]bool, d.games.len);
    defer gpa.free(support);
    @memset(support, @splat(false));
    for (d.rows) |r| support[r.game][r.slot] = r.role == core.Role.utility;

    const reasons = try gpa.alloc(Reason, d.games.len);
    defer gpa.free(reasons);
    for (d.games, reasons) |g, *r| r.* = if (g.duration_s < 900) .short else .no_timeline;

    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    var tl_arena: std.heap.ArenaAllocator = .init(gpa);
    defer tl_arena.deinit();
    var q = try db.prepare("SELECT match_id, data FROM timeline.timelines");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) {
        const gi = index.get(stats.matchKey(q.bytes(0))) orelse continue;
        if (reasons[gi] == .short) continue;
        _ = tl_arena.reset(.retain_capacity);
        const ta = tl_arena.allocator();
        const raw = store.raw.decompress(ta, q.bytes(1)) catch continue;
        const t = timeline.decode(ta, raw) catch continue;
        if (!protocol.reached15Timeline(t)) continue;
        reasons[gi] = judge(&at15(t, &support[gi]));
    }

    var counts: [std.enums.values(Reason).len]usize = @splat(0);
    var tests: [2]usize = @splat(0);
    const path = try std.fs.path.join(gpa, &.{ snap, file_name });
    defer gpa.free(path);
    var file = try Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    const w = &fw.interface;
    try w.writeAll("match_id\treason\n");
    for (d.games, reasons) |g, r| {
        try w.print("{s}\t{t}\n", .{ g.match_id, r });
        counts[@backingInt(r)] += 1;
        if (r == .ok) tests[@intFromBool(g.is_test)] += 1;
    }
    try w.flush();
    std.debug.print("wrote {s}: {d} games\n", .{ path, d.games.len });
    for (std.enums.values(Reason), counts) |r, n| {
        std.debug.print("  {t}: {d} ({d:.1}%)\n", .{ r, n, 100 * @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(d.games.len)) });
    }
    std.debug.print("  kept: {d} non-test, {d} test (never scored by the random split)\n", .{ tests[0], tests[1] });
    return 0;
}

/// Every player at frame 15; deaths are champion kills of them up to that frame's time
fn at15(t: timeline.Timeline, support: *const [10]bool) [10]At15 {
    const f = t.frames[15];
    var out: [10]At15 = undefined;
    for (&out, 0..) |*p, i| {
        const pid: u8 = @intCast(i + 1);
        p.* = .{
            .gold = f.get(pid, .total_gold),
            .deaths = 0,
            .cs = f.get(pid, .minions) + f.get(pid, .jungle_minions),
            .level = f.get(pid, .level),
            .support = support[i],
        };
    }
    for (t.events) |e| switch (e.data) {
        .champion_kill => |k| if (e.t_ms <= f.t_ms and k.victim >= 1 and k.victim <= 10) {
            out[k.victim - 1].deaths += 1;
        },
        else => {},
    };
    return out;
}

test "ldai filter: LoLDraftAI's thresholds, support exempt from CS" {
    var p: [10]At15 = @splat(.{ .gold = 5000, .deaths = 2, .cs = 100, .level = 9, .support = false });
    try std.testing.expectEqual(Reason.ok, judge(&p));
    p[4].support = true;
    p[4].cs = 10;
    try std.testing.expectEqual(Reason.ok, judge(&p));
    p[2].cs = 24;
    try std.testing.expectEqual(Reason.cs, judge(&p));
    p[2].cs = 25;
    p[7].deaths = 11;
    try std.testing.expectEqual(Reason.deaths, judge(&p));
    p[7].deaths = 10;
    p[1].level = 3;
    try std.testing.expectEqual(Reason.level, judge(&p));
    p[1].gold = 2399;
    try std.testing.expectEqual(Reason.gold, judge(&p));
}

test "random split: about a tenth of non-test games, none of the test set, seeded" {
    var held: [2]usize = @splat(0);
    var buf: [32]u8 = undefined;
    for (0..20_000) |i| {
        const id = try std.fmt.bufPrint(&buf, "EUW1_{d}", .{7_000_000_000 + i});
        const g: rows.Game = .{ .match_id = id, .start = 0, .patch = 0, .platform = 0, .is_test = false, .teams = undefined, .winner = 0 };
        held[0] += @intFromBool(inTest(g, 1));
        held[1] += @intFromBool(inTest(g, 1) and inTest(g, 2));
        var t = g;
        t.is_test = true;
        try std.testing.expect(!inTest(t, 1));
    }
    try std.testing.expect(held[0] > 1800 and held[0] < 2200);
    // Seeds draw different tenths: about 1% in both
    try std.testing.expect(held[1] > 100 and held[1] < 300);
}
