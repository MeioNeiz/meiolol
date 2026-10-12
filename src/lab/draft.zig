//! `meiolol-lab draft`: the compiled-in candidate's win model as a draft tester, and its
//! export for the admin page's draft board (docs/model.md "Draft model file"). Fits once
//! on every game in the snapshot. Scores come from the exported parameters through
//! Scorer, the reference the page's JS must match; an empty slot counts as its role's
//! average pick on the newest patch.

const std = @import("std");
const api = @import("api");
const core = @import("core");
const cand = @import("cand");
const store = @import("store");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");

const Io = std.Io;

pub const usage =
    \\  draft SNAP [DRAFT]              rank champions for an open slot with the compiled-in
    \\                                  candidate's win model (-Dcand); without DRAFT, reads
    \\                                  drafts line by line. DRAFT: --role mid [--side red]
    \\                                  [--ally top=Darius,jungle=Lee Sin] [--enemy mid=Ahri,
    \\                                  Jinx] [--ban Yasuo] [--top 10] [--min-games 100]
    \\  draft SNAP --export DIR         write DIR/draft-model.json and DIR/draft-ref.json for
    \\                                  the admin draft board (docs/model.md)
    \\
;

const n_role = 5;
const default_min_games = 100;
const z95 = 1.96;

const Champions = struct {
    names: std.AutoHashMapUnmanaged(u32, []const u8) = .empty,
    /// Training games per champion and role, every patch
    games: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    /// Games per champion and role on the newest patch, and that patch's games
    patch_games: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    patch_total: u32 = 0,
    patch: u32 = 0,

    fn key(champion: u32, role: usize) u64 {
        return (@as(u64, champion) << 3) | role;
    }

    fn gamesIn(c: *const Champions, champion: u32, role: usize) u32 {
        return c.games.get(key(champion, role)) orelse 0;
    }

    fn patchShare(c: *const Champions, champion: u32, role: usize) f64 {
        const n = c.patch_games.get(key(champion, role)) orelse 0;
        return @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(@max(c.patch_total, 1)));
    }

    fn name(c: *const Champions, champion: u32) []const u8 {
        return c.names.get(champion) orelse "?";
    }

    /// Case, spaces and punctuation ignored; a unique prefix will do
    fn find(c: *const Champions, text: []const u8) ?u32 {
        var want_buf: [32]u8 = undefined;
        const want = fold(&want_buf, text);
        if (want.len == 0) return null;
        var found: ?u32 = null;
        var it = c.names.iterator();
        while (it.next()) |e| {
            var buf: [32]u8 = undefined;
            const have = fold(&buf, e.value_ptr.*);
            if (std.mem.eql(u8, have, want)) return e.key_ptr.*;
            if (std.mem.startsWith(u8, have, want)) {
                if (found != null) return null;
                found = e.key_ptr.*;
            }
        }
        return found;
    }

    fn fold(buf: []u8, s: []const u8) []const u8 {
        var n: usize = 0;
        for (s) |ch| if (std.ascii.isAlphanumeric(ch) and n < buf.len) {
            buf[n] = std.ascii.toLower(ch);
            n += 1;
        };
        return buf[0..n];
    }
};

/// One slot's parameters: a champion-role's term, or its role's average pick (sd 0)
const Slot = struct {
    b: f64,
    sd: f64,
    u: []const f32,
    v: []const f32,
    s: []const f32,
};

/// The reference scorer (docs/model.md "Draft model file"), from exported parameters only
const Scorer = struct {
    e: cand.Export,
    platform: u8,
    terms: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    average: [n_role]Slot,

    fn init(arena: std.mem.Allocator, e: cand.Export, platform: u8, champs: *const Champions) !Scorer {
        var sc: Scorer = .{ .e = e, .platform = platform, .average = undefined };
        for (e.terms, 0..) |t, i| try sc.terms.put(arena, Champions.key(t.champion, t.role), @intCast(i));
        // Role average: play-rate-weighted mean of b and the vectors on the newest patch
        for (&sc.average, 0..) |*avg, r| {
            const vecs = try arena.alloc(f32, 3 * e.dim);
            @memset(vecs, 0);
            var b: f64 = 0;
            var total: f64 = 0;
            for (e.terms) |t| {
                if (t.role != r) continue;
                const share = champs.patchShare(t.champion, r);
                if (share == 0) continue;
                b += share * t.b;
                total += share;
                for (vecs[0..e.dim], t.u) |*x, y| x.* += @floatCast(share * y);
                for (vecs[e.dim .. 2 * e.dim], t.v) |*x, y| x.* += @floatCast(share * y);
                for (vecs[2 * e.dim ..], t.s) |*x, y| x.* += @floatCast(share * y);
            }
            const inv = if (total > 0) 1 / total else 0;
            for (vecs) |*x| x.* = @floatCast(x.* * inv);
            avg.* = .{
                .b = b * inv,
                .sd = 0,
                .u = vecs[0..e.dim],
                .v = vecs[e.dim .. 2 * e.dim],
                .s = if (std.mem.eql(u8, e.kind, "full")) vecs[2 * e.dim ..] else &.{},
            };
        }
        return sc;
    }

    fn slot(sc: *const Scorer, champion: u32, role: usize) Slot {
        const i = sc.terms.get(Champions.key(champion, role)) orelse return sc.average[role];
        const t = sc.e.terms[i];
        return .{ .b = t.b, .sd = t.sd, .u = t.u, .v = t.v, .s = t.s };
    }

    fn dot(a: []const f32, b: []const f32) f64 {
        if (a.len == 0 or b.len == 0) return 0;
        var s: f64 = 0;
        for (a, b) |x, y| s += @as(f64, x) * y;
        return s;
    }

    /// Blue's win chance and 95% interval; 0 is an empty slot
    fn blue(sc: *const Scorer, teams: [2][n_role]u32) Chance {
        var sl: [2][n_role]Slot = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            sl[side][r] = sc.slot(teams[side][r], r);
        };
        var logit: f64 = sc.e.intercept[sc.platform];
        var v: f64 = 0;
        for (0..n_role) |r| {
            logit += sl[0][r].b - sl[1][r].b;
            v += sl[0][r].sd * sl[0][r].sd + sl[1][r].sd * sl[1][r].sd;
        }
        for (0..n_role) |ri| for (0..n_role) |rj| {
            const w = sc.e.w[ri * n_role + rj];
            if (w != 0) logit += w * (dot(sl[0][ri].u, sl[1][rj].v) - dot(sl[1][ri].u, sl[0][rj].v));
            const z = sc.e.z[ri * n_role + rj];
            if (z != 0 and ri < rj) logit += z * (dot(sl[0][ri].s, sl[0][rj].s) - dot(sl[1][ri].s, sl[1][rj].s));
        };
        const half = z95 * @sqrt(v);
        return .{ .p = sigmoid(logit), .lo = sigmoid(logit - half), .hi = sigmoid(logit + half) };
    }
};

const Chance = struct {
    p: f64,
    lo: f64,
    hi: f64,

    /// The other side's view
    fn flip(c: Chance) Chance {
        return .{ .p = 1 - c.p, .lo = 1 - c.hi, .hi = 1 - c.lo };
    }
};

fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

const Draft = struct {
    role: usize,
    side: u1 = 0,
    /// By "mine" (0) and "theirs" and role; 0 open
    teams: [2][n_role]u32 = @splat(@splat(0)),
    bans: []const u32 = &.{},
    top: usize = 10,
    min_games: u32 = default_min_games,

    /// By game side, 0 blue
    fn bySide(d: *const Draft) [2][n_role]u32 {
        var t: [2][n_role]u32 = undefined;
        t[d.side] = d.teams[0];
        t[1 - d.side] = d.teams[1];
        return t;
    }
};

const Option = struct {
    champion: u32,
    games: u32,
    /// The user's team's chance with this champion in the slot
    win: f64,
    lo: f64,
    hi: f64,
    /// win minus the chance with the slot empty (its role's average pick)
    change: f64,
};

const Ranking = struct {
    options: []Option,
    /// Play-count-weighted mean of the options' chances
    average: f64,
    empty: f64,
};

fn rank(arena: std.mem.Allocator, sc: *const Scorer, champs: *const Champions, d: *const Draft) !Ranking {
    var teams = d.bySide();
    const empty = mine(sc.blue(teams), d.side).p;
    var options: std.ArrayList(Option) = .empty;
    var it = champs.names.keyIterator();
    while (it.next()) |id| {
        const games = champs.gamesIn(id.*, d.role);
        if (games < d.min_games or taken(d, id.*)) continue;
        teams[d.side][d.role] = id.*;
        const c = mine(sc.blue(teams), d.side);
        try options.append(arena, .{ .champion = id.*, .games = games, .win = c.p, .lo = c.lo, .hi = c.hi, .change = c.p - empty });
    }
    std.mem.sort(Option, options.items, {}, struct {
        fn f(_: void, a: Option, b: Option) bool {
            return a.win > b.win or (a.win == b.win and a.champion < b.champion);
        }
    }.f);
    var sum: f64 = 0;
    var n: f64 = 0;
    for (options.items) |o| {
        sum += o.win * @as(f64, @floatFromInt(o.games));
        n += @floatFromInt(o.games);
    }
    return .{ .options = options.items, .average = if (n > 0) sum / n else empty, .empty = empty };
}

fn mine(blue: Chance, side: u1) Chance {
    return if (side == 0) blue else blue.flip();
}

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    if (!@hasDecl(cand, "exportModel")) {
        std.debug.print("draft: the candidate has no exportModel (src/lab/cand/win-ratings has)\n", .{});
        return 2;
    }
    const snap = argv[0];
    var out_buf: [16 * 1024]u8 = undefined;
    var out_file = Io.File.stdout().writer(io, &out_buf);
    const w = &out_file.interface;
    defer w.flush() catch {};

    // Unused here, but the packed rows only load when they match
    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const eu = euIndex();
    var champs = try loadChampions(gpa, arena, snap, &data);
    var m = try fitAll(gpa, &data);
    defer cand.deinit(&m, gpa);
    const sc = try Scorer.init(arena, try cand.exportModel(&m, arena), eu, &champs);
    try w.print("win model fitted on {d} games; --min-games guards against thin samples\n", .{data.games.len});

    if (argv.len == 3 and std.mem.eql(u8, argv[1], "--export")) {
        try exportFiles(gpa, arena, io, snap, &data, &m, &sc, &champs, argv[2], w);
        return 0;
    }
    if (argv.len > 1) {
        try run(arena, &sc, &champs, argv[1..], w);
        return 0;
    }
    var in_buf: [4096]u8 = undefined;
    var in_file = Io.File.stdin().reader(io, &in_buf);
    while (true) {
        try w.writeAll("draft> ");
        try w.flush();
        const line = try in_file.interface.takeDelimiter('\n') orelse break;
        const args = try splitFlags(arena, line);
        if (args.len == 0) continue;
        run(arena, &sc, &champs, args, w) catch |err| try w.print("{t}\n", .{err});
    }
    return 0;
}

fn euIndex() u8 {
    for (protocol.platformIds(), 0..) |id, i| if (std.mem.eql(u8, id, protocol.test_platform)) return @intCast(i);
    unreachable;
}

/// "--role mid --ally top=Lee Sin" -> ["--role", "mid", "--ally", "top=Lee Sin"]: values
/// may hold spaces, so split only before "--"
fn splitFlags(arena: std.mem.Allocator, line: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = std.mem.tokenizeSequence(u8, line, "--");
    while (it.next()) |part| {
        const p = std.mem.trim(u8, part, " \t\r");
        if (p.len == 0) continue;
        const sp = std.mem.indexOfAny(u8, p, " \t") orelse p.len;
        try out.append(arena, try std.fmt.allocPrint(arena, "--{s}", .{p[0..sp]}));
        if (sp < p.len) try out.append(arena, std.mem.trim(u8, p[sp..], " \t\"'"));
    }
    return out.items;
}

fn loadChampions(gpa: std.mem.Allocator, arena: std.mem.Allocator, snap: []const u8, d: *const rows.Data) !Champions {
    var c: Champions = .{};
    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    var q = try db.prepare("SELECT id, name FROM champions");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) try c.names.put(arena, @intCast(q.int(0)), try arena.dupe(u8, q.bytes(1)));
    for (d.games) |g| c.patch = @max(c.patch, g.patch);
    for (d.games) |g| {
        if (g.patch != c.patch) continue;
        c.patch_total += 1;
        for (g.teams) |t| for (t, 0..) |ch, r| {
            const e = try c.patch_games.getOrPut(arena, Champions.key(ch, r));
            if (!e.found_existing) e.value_ptr.* = 0;
            e.value_ptr.* += 1;
        };
    }
    // Each patch game has two of every role
    c.patch_total *= 2;
    for (d.rows) |r| {
        const e = try c.games.getOrPut(arena, Champions.key(r.champion, @backingInt(r.role)));
        if (!e.found_existing) e.value_ptr.* = 0;
        e.value_ptr.* += 1;
    }
    return c;
}

fn trainOf(a: std.mem.Allocator, d: *const rows.Data) !api.Train {
    const ranks = try harness.gameRanks(a, d);
    const games = try a.alloc(api.Game, d.games.len);
    for (games, d.games, ranks) |*o, g, rk| o.* = .{ .start = g.start, .patch = g.patch, .platform = g.platform, .teams = g.teams, .ranks = rk };
    const out = try a.alloc(api.Row, d.rows.len);
    for (out, d.rows) |*o, r| o.* = .{
        .game = r.game,
        .side = r.side,
        .role = @fromBackingInt(@backingInt(r.role)),
        .champion = r.champion,
        .rank = r.rank,
        .y = r.y,
    };
    return .{ .games = games, .rows = out };
}

/// A tool, not an evaluation: every game, test games included
fn fitAll(gpa: std.mem.Allocator, d: *const rows.Data) !cand.Model {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const t = try trainOf(arena_state.allocator(), d);
    return cand.fit(gpa, &t, .{});
}

fn run(arena: std.mem.Allocator, sc: *const Scorer, champs: *const Champions, args: []const []const u8, w: *Io.Writer) !void {
    defer w.flush() catch {};
    const d = try parseDraft(arena, champs, args, w) orelse return;
    const r = try rank(arena, sc, champs, &d);
    if (r.options.len == 0) {
        try w.print("no free champion has {d}+ games in {s}\n", .{ d.min_games, roleLabel(d.role) });
        return;
    }
    try printDraft(champs, &d, w);
    try w.print("best {s} picks (your team's win chance and 95% interval; change vs an average pick, {d:.1}%):\n", .{ roleLabel(d.role), 100 * r.average });
    for (r.options[0..@min(d.top, r.options.len)], 1..) |o, i| {
        const pp = 100 * (o.win - r.average);
        try w.print("{d:>3}. {s:<16} {d:>5.1}%  ({d:.1}-{d:.1})  {s}{d:.1} pp  {d} games\n", .{
            i, champs.name(o.champion), 100 * o.win, 100 * o.lo, 100 * o.hi, if (pp >= 0) "+" else "", pp, o.games,
        });
    }
    try w.print("worst: ", .{});
    const tail = r.options[r.options.len - @min(3, r.options.len) ..];
    for (tail, 0..) |o, i| try w.print("{s}{s} {d:.1}%", .{ if (i > 0) ", " else "", champs.name(o.champion), 100 * o.win });
    try w.writeAll("\n\n");
}

fn taken(d: *const Draft, champion: u32) bool {
    for (d.teams) |t| for (t) |c| if (c == champion) return true;
    for (d.bans) |b| if (b == champion) return true;
    return false;
}

fn roleLabel(r: usize) []const u8 {
    return @as(core.Role, @fromBackingInt(@as(u3, @intCast(r)))).label();
}

fn printDraft(champs: *const Champions, d: *const Draft, w: *Io.Writer) !void {
    try w.print("you: {s}, {s} side\n", .{ roleLabel(d.role), if (d.side == 0) "blue" else "red" });
    for ([_][]const u8{ "allies ", "enemies" }, d.teams) |label, t| {
        try w.print("  {s}", .{label});
        for (t, 0..) |c, r| try w.print("  {s}={s}", .{ roleLabel(r), if (c == 0) "-" else champs.name(c) });
        try w.writeAll("\n");
    }
}

fn parseDraft(arena: std.mem.Allocator, champs: *const Champions, args: []const []const u8, w: *Io.Writer) !?Draft {
    var d: Draft = .{ .role = n_role };
    var bans: std.ArrayList(u32) = .empty;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const flag = args[i];
        if (i + 1 >= args.len) {
            try w.print("{s} needs a value\n", .{flag});
            return null;
        }
        i += 1;
        const v = args[i];
        if (std.mem.eql(u8, flag, "--role")) {
            const r = core.Role.parse(v) orelse {
                try w.print("unknown role {s}\n", .{v});
                return null;
            };
            d.role = @backingInt(r);
        } else if (std.mem.eql(u8, flag, "--side")) {
            d.side = if (std.mem.eql(u8, v, "red")) 1 else 0;
        } else if (std.mem.eql(u8, flag, "--top")) {
            d.top = std.fmt.parseInt(usize, v, 10) catch 10;
        } else if (std.mem.eql(u8, flag, "--min-games")) {
            d.min_games = std.fmt.parseInt(u32, v, 10) catch default_min_games;
        } else if (std.mem.eql(u8, flag, "--ally") or std.mem.eql(u8, flag, "--enemy")) {
            const team: usize = if (std.mem.eql(u8, flag, "--ally")) 0 else 1;
            var it = std.mem.splitScalar(u8, v, ',');
            while (it.next()) |raw| {
                var item = std.mem.trim(u8, raw, " \t\"'");
                if (item.len == 0) continue;
                var role: ?usize = null;
                if (std.mem.indexOfScalar(u8, item, '=')) |eq| {
                    const rn = std.mem.trim(u8, item[0..eq], " \t");
                    role = if (core.Role.parse(rn)) |r| @backingInt(r) else {
                        try w.print("unknown role {s}\n", .{rn});
                        return null;
                    };
                    item = std.mem.trim(u8, item[eq + 1 ..], " \t\"'");
                }
                const c = champs.find(item) orelse {
                    try w.print("no single champion matches \"{s}\"\n", .{item});
                    return null;
                };
                d.teams[team][role orelse mainRole(champs, &d, team, c)] = c;
            }
        } else if (std.mem.eql(u8, flag, "--ban")) {
            var it = std.mem.splitScalar(u8, v, ',');
            while (it.next()) |raw| {
                const item = std.mem.trim(u8, raw, " \t\"'");
                if (item.len == 0) continue;
                const c = champs.find(item) orelse {
                    try w.print("no single champion matches \"{s}\"\n", .{item});
                    return null;
                };
                try bans.append(arena, c);
            }
        } else {
            try w.print("unknown option {s}\n", .{flag});
            return null;
        }
    }
    d.bans = bans.items;
    if (d.role == n_role) {
        try w.writeAll("--role is required\n");
        return null;
    }
    if (d.teams[0][d.role] != 0) {
        try w.print("your slot ({s}) is already picked\n", .{roleLabel(d.role)});
        return null;
    }
    return d;
}

/// A pick without a role goes to the open slot where that champion is played most
fn mainRole(champs: *const Champions, d: *const Draft, team: usize, c: u32) usize {
    var best: usize = 0;
    var most: i64 = -1;
    for (0..n_role) |r| {
        if (d.teams[team][r] != 0 or (team == 0 and r == d.role)) continue;
        const g: i64 = champs.gamesIn(c, r);
        if (g > most) {
            most = g;
            best = r;
        }
    }
    return best;
}

// ---------- export (docs/model.md "Draft model file") ----------

const Dev = struct {
    what: []const u8,
    games: usize,
    log_loss: f64,
    baseline_log_loss: f64,
    coin_log_loss: f64 = @log(2.0),
    accuracy: f64,
    auc: f64,
};

/// The candidate refitted on dev's visible games, scored on dev-val (lab-agent.md
/// "Splits"): log loss per row, accuracy and AUC per game on blue's chance
fn devScore(gpa: std.mem.Allocator, d: *const rows.Data, eu: u8) !Dev {
    const ranks = try harness.gameRanks(gpa, d);
    defer gpa.free(ranks);
    const c = try harness.cuts(gpa, d, eu);
    var s = try harness.score(cand, gpa, d, ranks, c, .dev, .{});
    defer s.deinit(gpa);
    const k = api.outcomeIndex(.win);
    const la = try s.losses(gpa, d, k, null, .cand);
    defer gpa.free(la);
    const lb = try s.losses(gpa, d, k, null, .base);
    defer gpa.free(lb);
    const p = harness.paired(s.game, la, lb, null);

    const Point = struct { p: f64, y: bool };
    var points: std.ArrayList(Point) = .empty;
    defer points.deinit(gpa);
    var last: ?u32 = null;
    for (s.row, s.game, s.cand) |ri, g, pred| {
        const r = d.rows[ri];
        if (r.side != 0 or last == g) continue;
        last = g;
        try points.append(gpa, .{ .p = pred[k], .y = d.games[g].winner == 0 });
    }
    var hits: f64 = 0;
    for (points.items) |pt| {
        if ((pt.p > 0.5) == pt.y) hits += 1;
    }
    std.mem.sort(Point, points.items, {}, struct {
        fn f(_: void, a: Point, b: Point) bool {
            return a.p < b.p;
        }
    }.f);
    var pos: f64 = 0;
    var rank_sum: f64 = 0;
    for (points.items, 1..) |pt, i| if (pt.y) {
        pos += 1;
        rank_sum += @floatFromInt(i);
    };
    const n: f64 = @floatFromInt(points.items.len);
    return .{
        .what = "fitted on the games older than dev-val, scored on dev-val: the newest 20-40% of non-test EUW1 games (docs/lab-agent.md Splits); log loss per player row of the team's win, accuracy and AUC per game on blue's chance",
        .games = points.items.len,
        .log_loss = p.a,
        .baseline_log_loss = p.b,
        .accuracy = hits / n,
        .auc = (rank_sum - pos * (pos + 1) / 2) / (pos * (n - pos)),
    };
}

const ChampionOut = struct { id: u32, name: []const u8, alias: []const u8 };
const CellOut = struct { champion: u32, role: u8, games: u32, patch_games: u32, patch_share: f64 };

const ModelFile = struct {
    format: []const u8 = "meiolol-draft-model",
    version: u32 = 1,
    meta: struct {
        name: []const u8,
        run: []const u8,
        snapshot: []const u8,
        newest_game: []const u8,
        training_games: usize,
        patch: []const u8,
        platform: []const u8,
        dev: Dev,
    },
    roles: [n_role][]const u8 = .{ "top", "jungle", "middle", "bottom", "utility" },
    has_pairs: bool,
    min_games: u32 = default_min_games,
    champions: []const ChampionOut,
    cells: []const CellOut,
    average: [n_role]AverageOut,
    model: struct { kind: []const u8, dim: u32, intercept: f64, w: [25]f32, z: [25]f32, terms: []const cand.Term },
};

const AverageOut = struct { b: f64, u: []const f32, v: []const f32, s: []const f32 };

const RefDraft = struct {
    label: []const u8,
    /// By side (0 blue) and role; 0 empty
    teams: [2][n_role]u32,
    blue: Chance,
};

const RefSlot = struct {
    label: []const u8,
    role: u8,
    side: u1,
    teams: [2][n_role]u32,
    bans: []const u32,
    min_games: u32,
    empty: f64,
    average: f64,
    options: []const Option,
};

const RefFile = struct {
    format: []const u8 = "meiolol-draft-ref",
    version: u32 = 1,
    tolerance: f64 = 1e-9,
    drafts: []const RefDraft,
    slots: []const RefSlot,
};

fn exportFiles(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: Io,
    snap: []const u8,
    d: *const rows.Data,
    m: *const cand.Model,
    sc: *const Scorer,
    champs: *const Champions,
    dir: []const u8,
    w: *Io.Writer,
) !void {
    // The scorer must agree with the candidate on drafts it saw whole
    var worst: f64 = 0;
    var newest = d.games[0];
    for (d.games) |g| if (g.start > newest.start) {
        newest = g;
    };
    var checked: usize = 0;
    for (d.games) |g| {
        if (!g.is_test or checked == 500) continue;
        checked += 1;
        const q: api.Query = .{ .start = g.start, .patch = g.patch, .platform = sc.platform, .side = 0, .role = .top, .champion = g.teams[0][0], .rank = null, .teams = g.teams, .ranks = null };
        const want: f64 = cand.predict(m, &q)[api.outcomeIndex(.win)];
        worst = @max(worst, @abs(sc.blue(g.teams).p - want));
    }
    try w.print("scorer vs candidate on {d} test games: max |diff| {e}\n", .{ checked, worst });
    if (worst > 1e-4) return error.ScorerDisagrees;

    try w.print("dev score (refits on dev's games)...\n", .{});
    try w.flush();
    const dev = try devScore(gpa, d, sc.platform);
    try w.print("dev: log loss {d:.5} (champion baseline {d:.5}), accuracy {d:.4}, AUC {d:.4} on {d} games\n", .{ dev.log_loss, dev.baseline_log_loss, dev.accuracy, dev.auc, dev.games });

    var champions: std.ArrayList(ChampionOut) = .empty;
    var nit = champs.names.iterator();
    while (nit.next()) |e| {
        const buf = try arena.alloc(u8, 32);
        try champions.append(arena, .{ .id = e.key_ptr.*, .name = e.value_ptr.*, .alias = Champions.fold(buf, e.value_ptr.*) });
    }
    std.mem.sort(ChampionOut, champions.items, {}, struct {
        fn f(_: void, a: ChampionOut, b: ChampionOut) bool {
            return std.mem.lessThan(u8, a.name, b.name);
        }
    }.f);
    var cells: std.ArrayList(CellOut) = .empty;
    for (champions.items) |ch| for (0..n_role) |r| {
        const games = champs.gamesIn(ch.id, r);
        const patch_games = champs.patch_games.get(Champions.key(ch.id, r)) orelse 0;
        if (games == 0 and patch_games == 0) continue;
        try cells.append(arena, .{ .champion = ch.id, .role = @intCast(r), .games = games, .patch_games = patch_games, .patch_share = champs.patchShare(ch.id, r) });
    };
    var average: [n_role]AverageOut = undefined;
    for (&average, sc.average) |*o, a| o.* = .{ .b = a.b, .u = a.u, .v = a.v, .s = a.s };
    const e = sc.e;
    const model: ModelFile = .{
        .meta = .{
            .name = try std.fmt.allocPrint(arena, "{s} ({s})", .{ if (@hasDecl(cand, "name")) cand.name else "candidate", e.kind }),
            .run = std.fs.path.basename(dir),
            .snapshot = std.fs.path.basename(snap),
            .newest_game = try dayOf(arena, newest.start),
            .training_games = d.games.len,
            .patch = try std.fmt.allocPrint(arena, "{d}.{d}", .{ champs.patch / 1000, champs.patch % 1000 }),
            .platform = protocol.test_platform,
            .dev = dev,
        },
        .has_pairs = !std.mem.eql(u8, e.kind, "ratings") and !std.mem.eql(u8, e.kind, "rates"),
        .champions = champions.items,
        .cells = cells.items,
        .average = average,
        .model = .{ .kind = e.kind, .dim = e.dim, .intercept = e.intercept[sc.platform], .w = e.w, .z = e.z, .terms = e.terms },
    };

    // References: real test games whole and partly open, an empty board, two slot queries
    var drafts: std.ArrayList(RefDraft) = .empty;
    var slots: std.ArrayList(RefSlot) = .empty;
    var shown: usize = 0;
    for (d.games) |g| {
        if (!g.is_test or shown == 3) continue;
        shown += 1;
        try drafts.append(arena, .{ .label = "full test game", .teams = g.teams, .blue = sc.blue(g.teams) });
        var part = g.teams;
        part[0][2] = 0;
        part[1][3] = 0;
        part[1][4] = 0;
        try drafts.append(arena, .{ .label = "blue middle, red bottom and utility empty", .teams = part, .blue = sc.blue(part) });
        if (shown == 1) {
            const bans = [_]u32{ g.teams[1][3], firstOther(champs, &g.teams) };
            for ([_]u1{ 0, 1 }) |side| {
                var dr: Draft = .{ .role = 2, .side = side, .bans = try arena.dupe(u32, &bans) };
                dr.teams[0] = part[side];
                dr.teams[1] = part[1 - side];
                dr.teams[0][2] = 0;
                const r = try rank(arena, sc, champs, &dr);
                try slots.append(arena, .{
                    .label = if (side == 0) "blue middle to fill" else "red middle to fill",
                    .role = 2,
                    .side = side,
                    .teams = dr.bySide(),
                    .bans = dr.bans,
                    .min_games = dr.min_games,
                    .empty = r.empty,
                    .average = r.average,
                    .options = r.options,
                });
            }
        }
    }
    try drafts.append(arena, .{ .label = "empty board", .teams = @splat(@splat(0)), .blue = sc.blue(@splat(@splat(0))) });

    try Io.Dir.cwd().createDirPath(io, dir);
    const model_json = try std.json.Stringify.valueAlloc(arena, model, .{});
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "draft-model.json" }), .data = model_json });
    const ref_json = try std.json.Stringify.valueAlloc(arena, RefFile{ .drafts = drafts.items, .slots = slots.items }, .{ .whitespace = .indent_1 });
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "draft-ref.json" }), .data = ref_json });
    try w.print("wrote {s}/draft-model.json ({d} KB) and draft-ref.json ({d} KB)\n", .{ dir, model_json.len / 1024, ref_json.len / 1024 });
}

/// Some champion not in the game, for a ban
fn firstOther(champs: *const Champions, teams: *const [2][n_role]u32) u32 {
    var it = champs.names.keyIterator();
    outer: while (it.next()) |id| {
        for (teams) |t| for (t) |c| if (c == id.*) continue :outer;
        if (champs.gamesIn(id.*, 2) >= default_min_games) return id.*;
    }
    return 0;
}

fn dayOf(arena: std.mem.Allocator, ms: i64) ![]const u8 {
    const es: std.time.epoch.EpochSeconds = .{ .secs = @intCast(@divFloor(ms, 1000)) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.allocPrint(arena, "{d}-{d:0>2}-{d:0>2}", .{ yd.year, md.month.numeric(), md.day_index + 1 });
}

test "scorer: the documented formula on known parameters" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var champs: Champions = .{ .patch_total = 4 };
    // Role top: champion 1 (b 0.2) and 2 (b -0.1), each half the patch's top games
    try champs.patch_games.put(arena, Champions.key(1, 0), 2);
    try champs.patch_games.put(arena, Champions.key(2, 0), 2);
    const terms = [_]cand.Term{
        .{ .champion = 1, .role = 0, .games = 400, .b = 0.2, .sd = 0.1, .u = &.{}, .v = &.{}, .s = &.{} },
        .{ .champion = 2, .role = 0, .games = 400, .b = -0.1, .sd = 0.1, .u = &.{}, .v = &.{}, .s = &.{} },
    };
    var intercept: [256]f32 = @splat(0);
    intercept[6] = 0.04;
    const sc = try Scorer.init(arena, .{ .kind = "ratings", .dim = 0, .intercept = &intercept, .w = @splat(0), .z = @splat(0), .terms = &terms }, 6, &champs);
    var teams: [2][n_role]u32 = @splat(@splat(0));
    teams[0][0] = 1;
    teams[1][0] = 2;
    // logit 0.04 + 0.2 - (-0.1) = 0.34; interval 0.34 -/+ 1.96 * sqrt(0.01 + 0.01)
    const c = sc.blue(teams);
    try std.testing.expectApproxEqAbs(sigmoid(0.34), c.p, 1e-6);
    try std.testing.expectApproxEqAbs(sigmoid(0.34 - 1.96 * @sqrt(0.02)), c.lo, 1e-6);
    // An empty top slot is the role average, b 0.05, with no sd
    teams[1][0] = 0;
    try std.testing.expectApproxEqAbs(sigmoid(0.04 + 0.2 - 0.05), sc.blue(teams).p, 1e-6);
}

test "flags split before --, values keep spaces" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const got = try splitFlags(arena.allocator(), "--role mid --ally top=Darius,jungle=Lee Sin --side red");
    try std.testing.expectEqual(@as(usize, 6), got.len);
    try std.testing.expectEqualStrings("top=Darius,jungle=Lee Sin", got[3]);
    try std.testing.expectEqualStrings("red", got[5]);
}
