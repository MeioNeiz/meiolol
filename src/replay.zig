//! `meiolol eval --replay`: the lane card on held-out picks, from the pool and mastery the
//! app would have seen (DATA/mastery_pre.tsv and mastery_pre_pool.tsv, a snapshot's
//! pre-game fetches; docs/model.md "Pool and expertise replay"). Same time split as eval.
//!
//! Fits lanecard.Expertise on train, own seat only (all the app knows), then reports:
//! - log loss of each known seat's team result, draft alone vs draft + own expertise,
//!   paired by game: decides beta
//! - how often the champion picked is among the card's options, expertise off and on,
//!   with the other nine known (as eval's pick metric) and blind
//! - win rate by whether the pick was shown (descriptive: comfort picks confound it)

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const eval = @import("eval.zig");
const logreg = @import("logreg.zig");
const lanecard = @import("lanecard.zig");
const analysis = @import("analysis.zig");
const par = @import("par.zig");
const Date = @import("date.zig").Date;
const score = core.score;
const Role = core.Role;
const Game = stats.Row;
const Io = std.Io;

const unknown = std.math.maxInt(u32);

/// One game's ten participants by slot (0-4 blue): champion 0 and points unknown without a
/// pre-game fetch; pool only on test games
const Seats = struct {
    champion: [10]u32 = @splat(0),
    points: [10]u32 = @splat(unknown),
    /// Points on every champion in the same fetch
    total: [10]u32 = @splat(0),
    pool: [10][]const lanecard.Mastery = @splat(&.{}),
};

const Map = std.AutoHashMapUnmanaged(u64, Seats);

/// Expertise features after the draft's: none, one beta, a beta per role, d1's bands,
/// one beta beside the player's total points (how much more they win on this champion
/// than on their others: what ranking a pool needs)
const Variant = enum {
    none,
    one,
    role,
    bands,
    within,

    fn width(v: Variant) u32 {
        return switch (v) {
            .none => 0,
            .one => 1,
            .role => Role.count,
            .bands => band_edges.len - 1,
            .within => 2,
        };
    }

    fn label(v: Variant) []const u8 {
        return switch (v) {
            .none => "draft alone",
            .one => "+ log points, one beta",
            .role => "+ log points, beta per role",
            .bands => "+ points bands (<10k, 10-30k, 30-100k, 100-300k, 300k+)",
            .within => "+ log points, one beta, beside log total points",
        };
    }
};

/// docs/learned.md's mastery bands (meiolol-d1, 20 Oct)
const band_edges = [_]u32{ 0, 10_000, 30_000, 100_000, 300_000 };

/// const, side, then the four draft terms from the seat's side
const draft_width = 6;
const l2 = 1;

pub fn run(
    gpa: std.mem.Allocator,
    io: Io,
    db: store.Db,
    data_dir: []const u8,
    patches: []const []const u8,
    platforms: []const []const u8,
    opts: eval.Options,
    w: *Io.Writer,
) !void {
    const champs = try stats.champions(gpa, db);
    defer stats.freeChampions(gpa, champs);
    var list: analysis.GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    _ = try stats.scan(gpa, io, db, patches, platforms, 0, &list);
    var parts = try eval.split(gpa, list.items.items, platforms, opts);
    defer parts.deinit(gpa);
    const train = parts.train;
    const tests = parts.tests;

    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var test_keys: std.AutoHashMapUnmanaged(u64, void) = .empty;
    defer test_keys.deinit(gpa);
    for (tests) |g| try test_keys.put(gpa, g.id, {});
    var map: Map = .empty;
    defer map.deinit(gpa);
    try loadPoints(gpa, io, data_dir, &map);
    try loadPools(arena, io, data_dir, &map, &test_keys);

    try w.print("# meiolol eval --replay\n\nPool and expertise replay (docs/model.md). Train: " ++
        "oldest {d} games ({f} to {f}). Test: newest {d} ({f} to {f}). Seats with a " ++
        "pre-game mastery fetch only.\n\n", .{
        train.len, Date.fromMs(train[0].start), Date.fromMs(train[train.len - 1].start),
        tests.len, Date.fromMs(tests[0].start), Date.fromMs(tests[tests.len - 1].start),
    });

    const oof = try eval.oofTerms(gpa, io, champs, train, opts.folds);
    defer gpa.free(oof);
    var full: eval.Model = try .build(gpa, champs, train, null);
    defer full.deinit(gpa);
    const eb = score.empiricalPriors(&full.stats, eval.eb_min_games).apply(eval.unweighted);

    var train_rows: [std.enums.values(Variant).len]std.ArrayList(logreg.Row) = @splat(.empty);
    defer for (&train_rows) |*r| r.deinit(gpa);
    for (train, oof) |g, t| {
        const s = map.get(g.id) orelse continue;
        for (0..10) |slot| {
            const seat = seatOf(g, s, slot) orelse continue;
            for (std.enums.values(Variant), &train_rows) |v, *rows| try rows.append(gpa, row(v, t, g, seat));
        }
    }

    var test_seats: std.ArrayList(TestSeat) = .empty;
    defer test_seats.deinit(gpa);
    for (tests, 0..) |g, gi| {
        const s = map.get(g.id) orelse continue;
        for (0..10) |slot| {
            const seat = seatOf(g, s, slot) orelse continue;
            try test_seats.append(gpa, .{ .game = @intCast(gi), .seat = seat, .pool = s.pool[slot] });
        }
    }
    const terms = try gpa.alloc(score.DraftTerms, tests.len);
    defer gpa.free(terms);
    for (tests, terms) |g, *t| t.* = score.draftTerms(&full.stats, eb, g.teams);

    try w.print("## Log loss, own seat\n\n{d} train seats, {d} test seats in {d} test games. " ++
        "Each seat's team result from the draft's terms (out-of-fold on train, empirical-Bayes " ++
        "priors) and that player's pre-game points on their champion; ± paired by game.\n\n", .{
        train_rows[0].items.len, test_seats.items.len, countGames(test_seats.items),
    });
    try w.writeAll("| model | log loss | vs draft alone | 10k to 300k (pp, even game) |\n" ++
        "| --- | --- | --- | --- |\n");
    var fitted: lanecard.Expertise = .{ .beta = @splat(0) };
    var base_p: []f64 = &.{};
    defer gpa.free(base_p);
    for (std.enums.values(Variant), &train_rows) |v, rows| {
        const d = draft_width + v.width();
        const wts = try logreg.fit(gpa, d, rows.items, l2);
        defer gpa.free(wts);
        const p = try gpa.alloc(f64, test_seats.items.len);
        for (test_seats.items, p) |ts, *q| {
            const g = tests[ts.game];
            q.* = logreg.sigmoid(row(v, terms[ts.game], g, ts.seat).dot(wts));
        }
        var ll: f64 = 0;
        for (test_seats.items, p) |ts, q| ll += analysis.logLoss(q, ts.seat.won(tests[ts.game]));
        ll /= @floatFromInt(p.len);
        try w.print("| {s} | {d:.5} |", .{ v.label(), ll });
        if (v == .none) {
            base_p = p;
            try w.writeAll(" | |\n");
            continue;
        }
        defer gpa.free(p);
        const diff = paired(test_seats.items, tests, p, base_p);
        try w.print(" {s}{d:.5} ± {d:.5} |", .{ if (diff.mean >= 0) "+" else "", diff.mean, diff.half_width });
        const ex = wts[draft_width..];
        switch (v) {
            .none => unreachable,
            .one => try gap(w, .{ .beta = @splat(ex[0]) }, &.{.top}),
            .role => try gap(w, .{ .beta = ex[0..Role.count].* }, &Role.all),
            .within => {
                fitted = .{ .beta = @splat(ex[0]) };
                try gap(w, fitted, &.{.top});
                try w.print(" (total points: {d:.4} a tenfold)", .{ex[1]});
            },
            .bands => for (ex) |b| try w.print(" {d:.1}", .{100 * (logreg.sigmoid(b) - 0.5)}),
        }
        try w.writeAll(" |\n");
    }
    try w.writeAll("\nThe card's term, from the last row (lanecard.Expertise.beta, top jungle mid bot " ++
        "support): .{ ");
    for (fitted.beta, 0..) |b, i| try w.print("{s}{d:.4}", .{ if (i == 0) "" else ", ", b });
    try w.writeAll(" }\n");

    try w.writeAll("\n## Pick among the card's options\n\nThe lane card (current model, " ++
        "train stats, no curves) for each test seat with a pool, from its pre-game top " ++
        "15 by points; hit: the champion picked is among the options shown. ± paired by " ++
        "game.\n\n| draft known | seats | pick in pool | hit, draft only | hit, + expertise | " ++
        "difference | win rate, hit / missed (+ expertise) |\n" ++
        "| --- | --- | --- | --- | --- | --- | --- |\n");
    for ([_]bool{ true, false }) |known| {
        const hits = try gpa.alloc(Hit, test_seats.items.len);
        defer gpa.free(hits);
        try par.forEach(io, test_seats.items.len, Replay{
            .gpa = gpa,
            .stats = &full.stats,
            .tests = tests,
            .seats = test_seats.items,
            .known = known,
            .expertise = fitted,
            .hits = hits,
        }, Replay.one);
        try hitRow(w, known, test_seats.items, tests, hits);
    }
}

const Seat = struct {
    side: u1,
    role: Role,
    champion: u32,
    points: u32,
    total: u32 = 0,

    fn won(s: Seat, g: Game) f64 {
        return if (g.winner == s.side) 1 else 0;
    }
};

const TestSeat = struct { game: u32, seat: Seat, pool: []const lanecard.Mastery };

/// Slot `slot` of `g` with known points, placed by its champion in the game's teams
fn seatOf(g: Game, s: Seats, slot: usize) ?Seat {
    if (s.points[slot] == unknown or s.champion[slot] == 0) return null;
    const side: u1 = @intCast(slot / 5);
    for (Role.all) |r| if (g.teams[side][@backingInt(r)] == s.champion[slot]) return .{
        .side = side,
        .role = r,
        .champion = s.champion[slot],
        .points = s.points[slot],
        .total = s.total[slot],
    };
    return null;
}

fn row(v: Variant, t: score.DraftTerms, g: Game, seat: Seat) logreg.Row {
    const sgn: f64 = if (seat.side == 0) 1 else -1;
    var r: logreg.Row = .{ .y = seat.won(g) };
    r.add(0, 1);
    r.add(1, sgn);
    r.add(2, sgn * t.base);
    r.add(3, sgn * t.duo);
    r.add(4, sgn * t.lane);
    r.add(5, sgn * t.matchup);
    const f = lanecard.Expertise.feature(seat.points);
    switch (v) {
        .none => {},
        .one => r.add(draft_width, f),
        .role => r.add(draft_width + @as(u32, @backingInt(seat.role)), f),
        .bands => {
            var b: u32 = band_edges.len - 1;
            while (seat.points < band_edges[b]) b -= 1;
            if (b > 0) r.add(draft_width + b - 1, 1);
        },
        .within => {
            r.add(draft_width, f);
            r.add(draft_width + 1, lanecard.Expertise.feature(seat.total));
        },
    }
    return r;
}

/// "pp from 10k to 300k points" for each of `roles`, in an even game
fn gap(w: *Io.Writer, e: lanecard.Expertise, roles: []const Role) !void {
    for (roles) |r| {
        const d = e.logit(r, 300_000) - e.logit(r, 10_000);
        try w.print(" {d:.1}", .{100 * (logreg.sigmoid(d) - 0.5)});
    }
}

fn countGames(seats: []const TestSeat) usize {
    var n: usize = 0;
    for (seats, 0..) |s, i| n += @intFromBool(i == 0 or seats[i - 1].game != s.game);
    return n;
}

/// Mean per-seat log loss of `a` minus `b`, interval from per-game sums (seats of a game
/// are consecutive)
fn paired(seats: []const TestSeat, tests: []const Game, a: []const f64, b: []const f64) analysis.Gain {
    var sums: analysis.PairedSums = .{};
    var i: usize = 0;
    while (i < seats.len) {
        var d: f64 = 0;
        var j = i;
        while (j < seats.len and seats[j].game == seats[i].game) : (j += 1) {
            const y = seats[j].seat.won(tests[seats[j].game]);
            d += analysis.logLoss(a[j], y) - analysis.logLoss(b[j], y);
        }
        sums.add(d, @floatFromInt(j - i));
        i = j;
    }
    return sums.gain();
}

const Hit = struct { in_pool: bool, off: bool, on: bool };

const Replay = struct {
    gpa: std.mem.Allocator,
    stats: *const core.Stats,
    tests: []const Game,
    seats: []const TestSeat,
    known: bool,
    expertise: lanecard.Expertise,
    hits: []Hit,

    fn one(c: Replay, i: usize) !void {
        const ts = c.seats[i];
        if (ts.pool.len == 0) {
            c.hits[i] = .{ .in_pool = false, .off = false, .on = false };
            return;
        }
        const g = c.tests[ts.game];
        var allies: [4]score.Pick = undefined;
        var n_allies: usize = 0;
        var enemies: [5]score.Pick = undefined;
        for (Role.all, &enemies) |r, *e| {
            e.* = .{ .champion = g.teams[1 - ts.seat.side][@backingInt(r)], .role = r };
            if (r == ts.seat.role) continue;
            allies[n_allies] = .{ .champion = g.teams[ts.seat.side][@backingInt(r)], .role = r };
            n_allies += 1;
        }
        var arena_state: std.heap.ArenaAllocator = .init(c.gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        var in: lanecard.Input = .{
            .stats = c.stats,
            .curves = null,
            .role = ts.seat.role,
            .allies = if (c.known) &allies else &.{},
            .enemies = if (c.known) &enemies else &.{},
            .mastery = ts.pool,
            .expertise = null,
        };
        const off = try lanecard.build(arena, in);
        in.expertise = c.expertise;
        const on = try lanecard.build(arena, in);
        c.hits[i] = .{
            .in_pool = for (ts.pool) |m| {
                if (m.champion == ts.seat.champion) break true;
            } else false,
            .off = shown(off, ts.seat.champion),
            .on = shown(on, ts.seat.champion),
        };
    }
};

fn shown(card: lanecard.Card, champion: u32) bool {
    for (card.options) |o| if (o.champion == champion) return true;
    return false;
}

fn hitRow(w: *Io.Writer, known: bool, seats: []const TestSeat, tests: []const Game, hits: []const Hit) !void {
    var n: f64 = 0;
    var pool: f64 = 0;
    var off: f64 = 0;
    var on: f64 = 0;
    var won: [2]f64 = @splat(0);
    var count: [2]f64 = @splat(0);
    var sums: analysis.PairedSums = .{};
    var i: usize = 0;
    while (i < seats.len) {
        var d: f64 = 0;
        var rows: f64 = 0;
        var j = i;
        while (j < seats.len and seats[j].game == seats[i].game) : (j += 1) {
            if (seats[j].pool.len == 0) continue;
            const h = hits[j];
            rows += 1;
            pool += @floatFromInt(@intFromBool(h.in_pool));
            off += @floatFromInt(@intFromBool(h.off));
            on += @floatFromInt(@intFromBool(h.on));
            d += @as(f64, @floatFromInt(@intFromBool(h.on))) - @as(f64, @floatFromInt(@intFromBool(h.off)));
            const k = @intFromBool(h.on);
            count[k] += 1;
            won[k] += seats[j].seat.won(tests[seats[j].game]);
        }
        if (rows > 0) sums.add(d, rows);
        n += rows;
        i = j;
    }
    const diff = sums.gain();
    try w.print("| {s} | {d} | {d:.1}% | {d:.1}% | {d:.1}% | {s}{d:.2} ± {d:.2} pp | {d:.1}% / {d:.1}% |\n", .{
        if (known) "other nine" else "blind",
        @as(u64, @trunc(n)),
        100 * pool / n,
        100 * off / n,
        100 * on / n,
        if (diff.mean >= 0) "+" else "",
        100 * diff.mean,
        100 * diff.half_width,
        100 * won[1] / @max(count[1], 1),
        100 * won[0] / @max(count[0], 1),
    });
}

/// mastery_pre.tsv: points on the game's champion per (match, slot)
fn loadPoints(gpa: std.mem.Allocator, io: Io, data_dir: []const u8, map: *Map) !void {
    const Fill = struct {
        gpa: std.mem.Allocator,
        map: *Map,

        fn line(c: @This(), l: []const u8) !void {
            var f = std.mem.splitScalar(u8, l, '\t');
            const key = stats.matchKey(f.first());
            const slot = try field(u8, f.next());
            _ = f.next(); // fetched_at
            _ = f.next(); // level
            const points = try field(u32, f.next());
            _ = f.next(); // last_play
            _ = f.next(); // champions
            const total = try field(u64, f.next());
            if (slot >= 10) return error.BadMasteryLine;
            const gop = try c.map.getOrPut(c.gpa, key);
            if (!gop.found_existing) gop.value_ptr.* = .{};
            gop.value_ptr.points[slot] = points;
            gop.value_ptr.total[slot] = @intCast(@min(total, std.math.maxInt(u32)));
        }
    };
    try eachLine(io, data_dir, "mastery_pre.tsv", Fill{ .gpa = gpa, .map = map }, Fill.line);
}

/// mastery_pre_pool.tsv: each seat's champion, and its pool on test games
fn loadPools(
    arena: std.mem.Allocator,
    io: Io,
    data_dir: []const u8,
    map: *Map,
    test_keys: *const std.AutoHashMapUnmanaged(u64, void),
) !void {
    const Fill = struct {
        arena: std.mem.Allocator,
        map: *Map,
        test_keys: *const std.AutoHashMapUnmanaged(u64, void),

        fn line(c: @This(), l: []const u8) !void {
            var f = std.mem.splitScalar(u8, l, '\t');
            const key = stats.matchKey(f.first());
            const slot = try field(u8, f.next());
            const champion = try field(u32, f.next());
            if (slot >= 10) return error.BadMasteryLine;
            const s = c.map.getPtr(key) orelse return;
            s.champion[slot] = champion;
            if (!c.test_keys.contains(key)) return;
            var pool: std.ArrayList(lanecard.Mastery) = .empty;
            var it = std.mem.splitScalar(u8, f.next() orelse "", ',');
            while (it.next()) |e| {
                if (e.len == 0) continue;
                const colon = std.mem.findScalar(u8, e, ':') orelse return error.BadMasteryLine;
                try pool.append(c.arena, .{
                    .champion = try field(u32, e[0..colon]),
                    .points = try field(u32, e[colon + 1 ..]),
                });
            }
            s.pool[slot] = pool.items;
        }
    };
    try eachLine(io, data_dir, "mastery_pre_pool.tsv", Fill{
        .arena = arena,
        .map = map,
        .test_keys = test_keys,
    }, Fill.line);
}

fn field(comptime T: type, text: ?[]const u8) !T {
    return std.fmt.parseInt(T, text orelse return error.BadMasteryLine, 10) catch error.BadMasteryLine;
}

/// Each line of DIR/NAME after its header
fn eachLine(io: Io, dir: []const u8, name: []const u8, ctx: anytype, comptime body: anytype) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.mem.print(&path_buf, "{s}/{s}", .{ dir, name });
    var file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
        std.log.err("{s}: {t} (meiolol-lab mastery-pre writes it into a snapshot)", .{ path, err });
        return err;
    };
    defer file.close(io);
    var rbuf: [64 * 1024]u8 = undefined;
    var fr = file.reader(io, &rbuf);
    const r = &fr.interface;
    _ = r.takeDelimiter('\n') catch |e| return fr.err orelse e;
    while (r.takeDelimiter('\n') catch |e| return fr.err orelse e) |line| {
        if (line.len > 0) try body(ctx, line);
    }
}

const testing = std.testing;

test "seat placed by its champion, rows from the seat's side" {
    const g: Game = .{
        .id = 1,
        .start = 0,
        .patch = 0,
        .platform = 0,
        .teams = .{ .{ 1, 2, 3, 4, 5 }, .{ 6, 7, 8, 9, 10 } },
        .winner = 1,
    };
    var s: Seats = .{};
    s.champion[7] = 9;
    s.points[7] = 120_000;
    s.champion[0] = 3;
    try testing.expectEqual(null, seatOf(g, s, 0));
    const seat = seatOf(g, s, 7).?;
    try testing.expectEqual(1, seat.side);
    try testing.expectEqual(Role.bottom, seat.role);
    try testing.expectEqual(1, seat.won(g));

    const r = row(.role, .{ .base = 0.2, .lane = -0.1 }, g, seat);
    try testing.expectEqual(1, r.y);
    var w: [draft_width + Role.count]f64 = @splat(0);
    w[2] = 1;
    try testing.expectApproxEqAbs(-0.2, r.dot(&w), 1e-12);
    w = @splat(0);
    w[draft_width + @as(u32, @backingInt(Role.bottom))] = 1;
    try testing.expectApproxEqAbs(lanecard.Expertise.feature(120_000), r.dot(&w), 1e-12);
    const b = row(.bands, .{}, g, seat);
    try testing.expectEqual(draft_width + 2, b.feats[b.n - 1].i);
}
