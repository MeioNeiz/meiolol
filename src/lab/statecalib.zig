//! `meiolol-lab state-calib OUT LEGENDARIES DB...`: Your games' win chance by minute
//! (statemodel.chancesOf on the shipped model, the call api/game.zig blueChances makes)
//! and winchance.blue (its fallback)
//! for the games of one queue in backup segments or a snapshot's meiolol.db, for a
//! calibration check (docs/model.md "Win chance by minute on later patches").
//! OUT is a TSV: match, platform, patch, duration_s, minute, p_richc, p_wc, blue_win;
//! with --ranks also rank_known (seats with a rank at game start, store.rankstart: the
//! site's rule) and rank_mean (their mean packed rank, 0 Challenger I .. 23 Platinum IV),
//! which needs a snapshot's ranks and rank_history. --model scores a stateship.py file
//! instead of the shipped one (a refit's check).
//! LEGENDARIES is a snapshot's legendaries.tsv (patch, item); a patch missing there uses
//! the newest patch it has

const std = @import("std");
const store = @import("store");
const timeline = @import("../riot/timeline.zig");
const livestate = @import("../livestate.zig");
const statemodel = @import("../statemodel.zig");
const winchance = @import("../winchance.zig");
const stats = @import("../stats.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const usage =
    \\  state-calib OUT LEGENDARIES DB... [--queue Q] [--patch P]... [--every N]
    \\                                  [--after MS] [--before MS] [--timelines DB]
    \\                                  [--model FILE] [--ranks]
    \\                                  shipped win chance (or FILE's, a stateship.py
    \\                                  model) and winchance by minute for queue Q (420)
    \\                                  games on the patches (16.21 and 16.22) in backup
    \\                                  segments, or a snapshot's meiolol.db with
    \\                                  --timelines its timeline.db; one game in N by
    \\                                  match key, MS < game_start < MS; --ranks adds
    \\                                  the seats' rank at game start (a snapshot):
    \\                                  OUT TSV (lab/statecalib.zig)
    \\
;

const Legs = struct {
    by_patch: std.StringHashMapUnmanaged(std.ArrayList(u32)) = .empty,
    newest: []const u8 = "",

    /// text: legendaries.tsv, kept
    fn parse(a: Allocator, text: []const u8) !Legs {
        var l: Legs = .{};
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        while (lines.next()) |line| {
            var cols = std.mem.tokenizeScalar(u8, line, '\t');
            const patch = cols.next() orelse continue;
            const item = std.fmt.parseInt(u32, cols.next() orelse continue, 10) catch continue;
            const e = try l.by_patch.getOrPut(a, patch);
            if (!e.found_existing) e.value_ptr.* = .empty;
            try e.value_ptr.append(a, item);
            if (stats.patchKey(patch) > stats.patchKey(l.newest)) l.newest = patch;
        }
        var it = l.by_patch.valueIterator();
        while (it.next()) |v| std.mem.sort(u32, v.items, {}, std.sort.asc(u32));
        return l;
    }

    fn items(l: *const Legs, patch: []const u8) livestate.Items {
        const v = l.by_patch.getPtr(patch) orelse l.by_patch.getPtr(l.newest).?;
        return .sorted(@ptrCast(&v.items));
    }
};

pub fn main(gpa: Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 3) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var every: u64 = 1;
    var after: i64 = 0;
    var before: i64 = std.math.maxInt(i64);
    var ranks = false;
    var model = statemodel.shipped();
    var queue: i64 = 420;
    var timelines: ?[]const u8 = null;
    var patches: std.ArrayList([]const u8) = .empty;
    var segs: std.ArrayList([]const u8) = .empty;
    var i: usize = 2;
    while (i < argv.len) : (i += 1) {
        const flag = argv[i];
        if (!std.mem.startsWith(u8, flag, "--")) {
            try segs.append(arena, flag);
            continue;
        }
        if (std.mem.eql(u8, flag, "--ranks")) {
            ranks = true;
            continue;
        }
        i += 1;
        if (i == argv.len) {
            std.debug.print("{s} needs a value\n", .{flag});
            return 2;
        }
        if (std.mem.eql(u8, flag, "--every")) {
            every = try std.fmt.parseInt(u64, argv[i], 10);
        } else if (std.mem.eql(u8, flag, "--after")) {
            after = try std.fmt.parseInt(i64, argv[i], 10);
        } else if (std.mem.eql(u8, flag, "--before")) {
            before = try std.fmt.parseInt(i64, argv[i], 10);
        } else if (std.mem.eql(u8, flag, "--model")) {
            model = try statemodel.Model.parse(try Io.Dir.cwd().readFileAlloc(io, argv[i], arena, .limited(64 << 20)));
            std.log.info("state-calib: model {s}: {s} ({s}), {d} games", .{ argv[i], model.snapshot, model.run, model.training_games });
        } else if (std.mem.eql(u8, flag, "--queue")) {
            queue = try std.fmt.parseInt(i64, argv[i], 10);
        } else if (std.mem.eql(u8, flag, "--patch")) {
            try patches.append(arena, argv[i]);
        } else if (std.mem.eql(u8, flag, "--timelines")) {
            timelines = argv[i];
        } else {
            std.debug.print("unknown flag {s}\n", .{flag});
            return 2;
        }
    }
    if (patches.items.len == 0) try patches.appendSlice(arena, &.{ "16.21", "16.22" });
    const legs = try Legs.parse(arena, try Io.Dir.cwd().readFileAlloc(io, argv[1], arena, .limited(16 << 20)));

    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    const w = &out.writer;
    try w.writeAll("match\tplatform\tpatch\tduration_s\tminute\tp_richc\tp_wc\tblue_win");
    try w.writeAll(if (ranks) "\trank_known\trank_mean\n" else "\n");
    var games: usize = 0;
    var unmapped: usize = 0;
    var tl_arena: std.heap.ArenaAllocator = .init(gpa);
    defer tl_arena.deinit();
    for (segs.items) |seg| {
        const db = try store.sqlite.Db.openReadOnly(try arena.dupeSentinel(u8, seg, 0));
        defer db.close();
        if (timelines) |path| try db.run("ATTACH DATABASE ? AS tl", .{path});
        var q = try db.prepare(
            \\SELECT m.match_id, m.platform, m.patch, m.duration_s, m.winning_team, t.data,
            \\  m.game_start
            \\FROM matches m JOIN timelines t USING (match_id)
            \\WHERE m.queue_id = ? AND m.remake = 0
            \\  AND m.winning_team IN (100, 200) AND m.game_start > ? AND m.game_start < ?
        );
        defer q.deinit();
        // The PUUID (a snapshot's hash) is read only for --ranks, and only to key the lookup
        var pq = try db.prepare(if (ranks)
            "SELECT slot, team_id, position, champion_id, puuid FROM participants WHERE match_id = ? ORDER BY slot"
        else
            "SELECT slot, team_id, position, champion_id FROM participants WHERE match_id = ? ORDER BY slot");
        defer pq.deinit();
        var lookup: ?store.rankstart.Lookup = if (ranks) try store.rankstart.Lookup.init(db) else null;
        defer if (lookup) |*l| l.deinit();
        try q.bind(.{ queue, after, before });
        while (try q.step()) {
            const id = q.bytes(0);
            if (stats.matchKey(id) % every != 0) continue;
            const patch = q.bytes(2);
            for (patches.items) |p| {
                if (std.mem.eql(u8, p, patch)) break;
            } else continue;
            _ = tl_arena.reset(.retain_capacity);
            const ta = tl_arena.allocator();
            var players: statemodel.Players = .{ .teams = @splat(0), .positions = @splat(""), .champions = @splat(0) };
            var rank_known: u32 = 0;
            var rank_sum: f64 = 0;
            const day = @divFloor(q.int(6), std.time.ms_per_day);
            pq.reset();
            try pq.bind(.{id});
            while (try pq.step()) {
                const slot: usize = @intCast(pq.int(0));
                if (slot >= 10) continue;
                players.teams[slot] = pq.int(1);
                players.positions[slot] = try ta.dupe(u8, pq.bytes(2));
                players.champions[slot] = @intCast(pq.int(3));
                if (lookup) |*l| {
                    const puuid = pq.bytes(4);
                    if (puuid.len == 0) continue;
                    const rank = try l.rankStart(store.schema.puuidKey(puuid), day) orelse continue;
                    rank_known += 1;
                    rank_sum += @floatFromInt(rank);
                }
            }
            const t = try timeline.decode(ta, try store.raw.decompress(ta, q.bytes(5)));
            // Null where Your games falls back to winchance: not richc's game
            const p = try statemodel.chancesOf(ta, model, players, t, q.bytes(1), legs.items(patch)) orelse {
                unmapped += 1;
                continue;
            };
            const blue_win: u8 = if (q.int(4) == 100) 1 else 0;
            for (p, 0..) |pr, m| {
                const wc = winchance.blue(t, @intCast(m)) orelse std.math.nan(f64);
                try w.print("{s}\t{s}\t{s}\t{d}\t{d}\t{d:.5}\t{d:.5}\t{d}", .{
                    id, q.bytes(1), patch, q.int(3), m, pr, wc, blue_win,
                });
                if (ranks) try w.print("\t{d}\t{d:.2}", .{ rank_known, if (rank_known > 0) rank_sum / @as(f64, @floatFromInt(rank_known)) else std.math.nan(f64) });
                try w.writeByte('\n');
            }
            games += 1;
        }
        std.log.info("state-calib: {s} done, {d} games so far", .{ seg, games });
    }
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = argv[0], .data = out.written() });
    std.log.info("state-calib: {d} games, {d} without five roles a side -> {s}", .{ games, unmapped, argv[0] });
    return 0;
}

const testing = std.testing;

test "legendaries: a patch's own set, else the newest patch's" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const legs = try Legs.parse(arena, "16.9\t3031\n16.21\t6672\n16.21\t3078\n");
    try testing.expectEqualStrings("16.21", legs.newest);
    const old = legs.items("16.9");
    try testing.expect(old.legendary(old.ctx, 3031) and !old.legendary(old.ctx, 3078));
    const next = legs.items("16.22");
    try testing.expect(next.legendary(next.ctx, 3078) and next.legendary(next.ctx, 6672) and !next.legendary(next.ctx, 3031));
}
