//! `meiolol-lab eventvalue SNAP`: what an in-game event is worth, in win chance points
//! and gold, from the win-chance-by-minute state model (winchance.zig). Per game-minute
//! (frame m to m+1, both inside the game): the change in blue's win chance and in blue's
//! gold lead, regressed on the events of that minute (SNAP/events.tsv, meiolol-lab
//! events) counted +1 blue, -1 red, by minute band, so events in the same fight share
//! credit. Intervals: game bootstrap. Gold equivalent: an event's win points over what
//! 1000 gold of lead was worth in the same game-minutes (the model's slope there).
//! Cause or being ahead: the state model is fitted on games where the team taking an
//! objective is usually already ahead in ways the state misses, so its credit can be part
//! signal. Check: after the event, does the taking team win as often as the model says
//! (results minus the next frame's chance), for steals (a near coin flip: the other team
//! set it up) against normal takes, contested against not, and on test games. Realised
//! share = 1 + that excess / the model's credit for the objective (its weight alone).
//! Dragon elements are assigned by the game, so their differences are causal as given.
//! --preds FILE: another model's chances instead (meiolol-state's preds-wcd.tsv: match_id,
//! minute, block, one column per model), e.g. one with draft terms, which winchance lacks.
//! Then 1000 gold is what the model gives a gold lead change in minutes with no event (by
//! band), the XP that came with the farm included: under winchance that is ~1.3x its gold
//! weight alone at 10-14 min, so gold equivalents aren't comparable across the two modes.
//! A take's credit is the regression's value for its kind. Minutes whose next frame has
//! no pred (the game's last) are dropped.
//! Writes DIR/eventvalue.tsv, DIR/realised.tsv

const std = @import("std");
const store = @import("store");
const timeline = @import("../riot/timeline.zig");
const objectives = @import("../objectives.zig");
const winchance = @import("../winchance.zig");
const weights = @import("../winchance_weights.zig");
const stats = @import("../stats.zig");
const par = @import("../par.zig");
const events = @import("events.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const usage =
    \\  eventvalue SNAP [--out DIR] [--boot N] [--preds FILE --col NAME --block B]
    \\                                  win chance points and gold per in-game event
    \\                                  (towers, dragons by element, grubs, herald,
    \\                                  baron, inhibitors, kills), per minute band, from
    \\                                  the state model; steals and contested takes as a
    \\                                  cause-or-ahead check (lab/eventvalue.zig; needs
    \\                                  SNAP/events.tsv); --preds: chances per game-minute
    \\                                  from FILE's column NAME, rows of block B (e.g.
    \\                                  cf), not winchance
    \\
;

const Kind = enum(u8) {
    tower_outer,
    tower_inner,
    tower_base,
    tower_nexus,
    inhibitor,
    infernal,
    ocean,
    mountain,
    cloud,
    hextech,
    chemtech,
    elder,
    grub,
    herald,
    baron,
    atakhan,
    kill,
    /// On top of `kill`
    first_blood,
    /// On top of their monster, when the killer stole it
    dragon_steal,
    baron_steal,
    herald_steal,
};
const n_kind = @typeInfo(Kind).@"enum".field_names.len;
/// Regression columns: intercept, then each kind
const n_x = 1 + n_kind;

const bands = [_][2]u8{ .{ 1, 10 }, .{ 10, 15 }, .{ 15, 20 }, .{ 20, 25 }, .{ 25, 30 }, .{ 30, 41 } };
const n_band = bands.len;

fn bandOf(m: u8) ?usize {
    for (bands, 0..) |b, i| if (m >= b[0] and m < b[1]) return i;
    return null;
}

fn kindOf(kind: []const u8, subtype: []const u8) ?Kind {
    const eql = std.mem.eql;
    if (eql(u8, kind, "kill")) return .kill;
    if (eql(u8, kind, "inhibitor")) return .inhibitor;
    if (eql(u8, kind, "tower")) {
        if (eql(u8, subtype, "OUTER_TURRET")) return .tower_outer;
        if (eql(u8, subtype, "INNER_TURRET")) return .tower_inner;
        if (eql(u8, subtype, "BASE_TURRET")) return .tower_base;
        if (eql(u8, subtype, "NEXUS_TURRET")) return .tower_nexus;
        return null;
    }
    if (!eql(u8, kind, "monster")) return null;
    const table = [_]struct { []const u8, Kind }{
        .{ "FIRE_DRAGON", .infernal }, .{ "WATER_DRAGON", .ocean },     .{ "EARTH_DRAGON", .mountain },
        .{ "AIR_DRAGON", .cloud },     .{ "HEXTECH_DRAGON", .hextech }, .{ "CHEMTECH_DRAGON", .chemtech },
        .{ "ELDER_DRAGON", .elder },   .{ "HORDE", .grub },             .{ "RIFTHERALD", .herald },
        .{ "BARON_NASHOR", .baron },   .{ "ATAKHAN", .atakhan },
    };
    for (table) |t| if (eql(u8, subtype, t[0])) return t[1];
    return null;
}

fn isDragon(k: Kind) bool {
    return @backingInt(k) >= @backingInt(Kind.infernal) and @backingInt(k) <= @backingInt(Kind.chemtech);
}

/// The state model's feature an objective changes (its credit beyond gold)
fn heldFeat(k: Kind) ?objectives.Feat {
    return switch (k) {
        .tower_outer, .tower_inner, .tower_base, .tower_nexus => .towers,
        .inhibitor => .inhibs_down,
        .elder => .elder,
        .grub => .grubs,
        .herald => .herald,
        .baron => .baron,
        else => if (isDragon(k)) .dragons else null,
    };
}

/// One event of events.tsv
const Ev = struct {
    minute: u8,
    kind: Kind,
    /// +1 blue took it, -1 red
    sign: i8,
    /// 1 stolen, 0 not, -1 unknown
    steal: i8,
    first_blood: bool,
    /// Both teams had a kill within 30 s
    contested: bool,
};

const GameEvents = struct {
    is_test: bool,
    /// Blue won
    blue_won: bool,
    evs: []const Ev,
};

fn loadEvents(gpa: Allocator, arena: Allocator, io: Io, snap: []const u8, out: *std.AutoHashMapUnmanaged(u64, GameEvents)) !void {
    const path = try std.fs.path.join(arena, &.{ snap, events.file_name });
    var file = try Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var rbuf: [1 << 20]u8 = undefined;
    var fr = file.reader(io, &rbuf);
    const r = &fr.interface;
    _ = r.takeDelimiter('\n') catch |e| return fr.err orelse e;
    var cur_key: u64 = 0;
    var cur: std.ArrayList(Ev) = .empty;
    var cur_game: GameEvents = undefined;
    while (r.takeDelimiter('\n') catch |e| return fr.err orelse e) |line| {
        var f = std.mem.splitScalar(u8, line, '\t');
        const id = f.next() orelse continue;
        const is_test = std.mem.eql(u8, f.next() orelse continue, "1");
        const winner = f.next() orelse continue;
        _ = f.next(); // duration_s
        _ = f.next(); // t_ms
        const minute = std.fmt.parseInt(u8, f.next() orelse continue, 10) catch continue;
        const kind_s = f.next() orelse continue;
        const subtype = f.next() orelse continue;
        _ = f.next(); // lane
        const team = f.next() orelse continue;
        _ = f.next(); // killer
        _ = f.next(); // killer_role
        _ = f.next(); // victim_role
        const fb = std.mem.eql(u8, f.next() orelse continue, "1");
        _ = f.next(); // bounty
        const steal_s = f.next() orelse continue;
        const near_b = std.fmt.parseInt(u16, f.next() orelse continue, 10) catch 0;
        const near_r = std.fmt.parseInt(u16, f.next() orelse continue, 10) catch 0;
        const key = stats.matchKey(id);
        if (key != cur_key) {
            if (cur_key != 0) {
                cur_game.evs = try cur.toOwnedSlice(arena);
                try out.put(gpa, cur_key, cur_game);
            }
            cur_key = key;
            cur_game = .{ .is_test = is_test, .blue_won = std.mem.eql(u8, winner, "100"), .evs = &.{} };
        }
        const kind = kindOf(kind_s, subtype) orelse continue;
        const sign: i8 = if (std.mem.eql(u8, team, "100")) 1 else if (std.mem.eql(u8, team, "200")) -1 else continue;
        try cur.append(arena, .{
            .minute = minute,
            .kind = kind,
            .sign = sign,
            .steal = if (std.mem.eql(u8, steal_s, "1")) 1 else if (std.mem.eql(u8, steal_s, "0")) 0 else -1,
            .first_blood = fb,
            .contested = near_b > 0 and near_r > 0,
        });
    }
    if (cur_key != 0) {
        cur_game.evs = try cur.toOwnedSlice(arena);
        try out.put(gpa, cur_key, cur_game);
    }
}

/// Last frame with a pred in --preds files
const max_minute = 40;
/// Per game, blue's chance at frames 0..max_minute from --preds (nan where none)
const Preds = std.AutoHashMapUnmanaged(u64, *[max_minute + 1]f32);

fn colIndex(header: []const u8, name: []const u8) ?usize {
    var it = std.mem.splitScalar(u8, header, '\t');
    var i: usize = 0;
    while (it.next()) |h| : (i += 1) if (std.mem.eql(u8, h, name)) return i;
    return null;
}

fn loadPreds(gpa: Allocator, arena: Allocator, io: Io, path: []const u8, col: []const u8, block: []const u8, out: *Preds) !void {
    var file = try Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var rbuf: [1 << 20]u8 = undefined;
    var fr = file.reader(io, &rbuf);
    const r = &fr.interface;
    const header = (r.takeDelimiter('\n') catch |e| return fr.err orelse e) orelse return error.EmptyPreds;
    const ci = [4]usize{
        colIndex(header, "match_id") orelse return error.NoMatchId,
        colIndex(header, "minute") orelse return error.NoMinute,
        colIndex(header, "block") orelse return error.NoBlock,
        colIndex(header, col) orelse {
            std.debug.print("eventvalue: no column {s} in {s}\n", .{ col, path });
            return error.NoPredColumn;
        },
    };
    while (r.takeDelimiter('\n') catch |e| return fr.err orelse e) |line| {
        var f: [4][]const u8 = undefined;
        var it = std.mem.splitScalar(u8, line, '\t');
        var i: usize = 0;
        while (it.next()) |x| : (i += 1) for (ci, 0..) |c, k| if (c == i) {
            f[k] = x;
        };
        if (i <= std.mem.max(usize, &ci)) continue;
        if (!std.mem.eql(u8, f[2], block)) continue;
        const m = std.fmt.parseInt(u8, f[1], 10) catch continue;
        if (m > max_minute) continue;
        const gop = try out.getOrPut(gpa, stats.matchKey(f[0]));
        if (!gop.found_existing) {
            gop.value_ptr.* = try arena.create([max_minute + 1]f32);
            gop.value_ptr.*.* = @splat(std.math.nan(f32));
        }
        gop.value_ptr.*[m] = std.fmt.parseFloat(f32, f[3]) catch std.math.nan(f32);
    }
}

/// pp of blue's chance per 1000 gold of lead change, per band, from the minutes with no
/// event (farming): the model's own gold value when it has no single gold weight
fn quietSlope(rows: []const Row) [n_band]f64 {
    var sx: [n_band]f64 = @splat(0);
    var sy: [n_band]f64 = @splat(0);
    var sxx: [n_band]f64 = @splat(0);
    var sxy: [n_band]f64 = @splat(0);
    var n: [n_band]f64 = @splat(0);
    for (rows) |r| {
        if (!std.mem.allEqual(i8, &r.x, 0)) continue;
        const x: f64 = r.dgold / 1000;
        const y: f64 = r.dp;
        sx[r.band] += x;
        sy[r.band] += y;
        sxx[r.band] += x * x;
        sxy[r.band] += x * y;
        n[r.band] += 1;
    }
    var out: [n_band]f64 = undefined;
    for (&out, 0..) |*o, b| {
        const vx = sxx[b] - sx[b] * sx[b] / n[b];
        o.* = if (n[b] > 1 and vx > 0) (sxy[b] - sx[b] * sy[b] / n[b]) / vx else std.math.nan(f64);
    }
    return out;
}

/// One game-minute: the change from frame m to m+1 and that minute's events
const Row = struct {
    game: u32,
    band: u8,
    /// Blue's win chance change, pp; blue's gold lead change, gold
    dp: f32,
    dgold: f32,
    /// pp per 1000 gold of lead at frame m
    marg: f32,
    x: [n_kind]i8,
};

/// One objective take for the realised-value check
const Take = struct {
    game: u32,
    band: u8,
    kind: Kind,
    /// Taking team's chance at frame m and m+1, the model's credit at m+1 (pp, its held
    /// weight alone), and the result
    p0: f32,
    p1: f32,
    credit: f32,
    won: bool,
    steal: i8,
    contested: bool,
    is_test: bool,
};

fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

fn logitAt(minute: u8, s: objectives.State) f64 {
    const w = weights.w[@min(minute, weights.w.len) - 1];
    var x = w[0];
    for (winchance.feats, w[1..]) |f, b| x += b * s[@backingInt(f)];
    return x;
}

fn weightOf(minute: u8, feat: objectives.Feat) f64 {
    const w = weights.w[@min(minute, weights.w.len) - 1];
    for (winchance.feats, 0..) |f, i| if (f == feat) return w[1 + i];
    unreachable;
}

/// pp of blue's chance per 1000 gold of lead at this state (the curve term included)
fn marginal(minute: u8, s: objectives.State) f64 {
    const g = s[@backingInt(objectives.Feat.gold)];
    const slope = weightOf(minute, .gold) + weightOf(minute, .gold_curve) * 2 * @abs(g) / 10;
    const p = sigmoid(logitAt(minute, s));
    return 100 * slope * p * (1 - p);
}

const Data = struct {
    rows: []Row,
    takes: []Take,
    n_games: u32,
};

fn collect(gpa: Allocator, arena: Allocator, snap: []const u8, evs: *const std.AutoHashMapUnmanaged(u64, GameEvents), preds: ?*const Preds) !Data {
    var out_rows: std.ArrayList(Row) = .empty;
    var takes: std.ArrayList(Take) = .empty;
    const db = try store.sqlite.Db.openReadOnly(try std.fs.path.joinZ(arena, &.{ snap, "timeline.db" }));
    defer db.close();
    var q = try db.prepare("SELECT match_id, data FROM timelines");
    defer q.deinit();
    try q.bind(.{});
    var tl_arena: std.heap.ArenaAllocator = .init(gpa);
    defer tl_arena.deinit();
    var n_games: u32 = 0;
    while (try q.step()) {
        const key = stats.matchKey(q.bytes(0));
        const ge = evs.get(key) orelse continue;
        const gp: ?*[max_minute + 1]f32 = if (preds) |p| p.get(key) orelse continue else null;
        _ = tl_arena.reset(.retain_capacity);
        const ta = tl_arena.allocator();
        const raw = try store.raw.decompress(ta, q.bytes(1));
        const t = timeline.decode(ta, raw) catch continue;
        if (t.participants != 10 or t.frames.len < 3) continue;
        const gi = n_games;
        n_games += 1;
        var m: u8 = 1;
        var ei: usize = 0;
        while (m < 60) : (m += 1) {
            const s0 = objectives.stateAt(t, m) orelse break;
            const s1 = objectives.stateAt(t, m + 1) orelse break;
            const band = bandOf(m) orelse break;
            var p0 = sigmoid(logitAt(m, s0));
            const l1 = logitAt(m + 1, s1);
            var p1 = sigmoid(l1);
            if (gp) |g| {
                if (m + 1 > max_minute or std.math.isNan(g[m]) or std.math.isNan(g[m + 1])) break;
                p0 = g[m];
                p1 = g[m + 1];
            }
            var row: Row = .{
                .game = gi,
                .band = @intCast(band),
                .dp = @floatCast(100 * (p1 - p0)),
                .dgold = 1000 * (s1[@backingInt(objectives.Feat.gold)] - s0[@backingInt(objectives.Feat.gold)]),
                .marg = @floatCast(marginal(m, s0)),
                .x = @splat(0),
            };
            while (ei < ge.evs.len and ge.evs[ei].minute < m) ei += 1;
            var j = ei;
            while (j < ge.evs.len and ge.evs[j].minute == m) : (j += 1) {
                const e = ge.evs[j];
                row.x[@backingInt(e.kind)] +|= e.sign;
                if (e.kind == .kill and e.first_blood) row.x[@backingInt(Kind.first_blood)] +|= e.sign;
                if (e.steal == 1) {
                    const extra: ?Kind = if (isDragon(e.kind)) .dragon_steal else switch (e.kind) {
                        .baron => .baron_steal,
                        .herald => .herald_steal,
                        else => null,
                    };
                    if (extra) |k| row.x[@backingInt(k)] +|= e.sign;
                }
                if (heldFeat(e.kind)) |feat| {
                    const blue = e.sign > 0;
                    const w = weightOf(m + 1, feat);
                    // Blue's chance at m+1 without this one objective, by its weight
                    const without = sigmoid(l1 - @as(f64, @floatFromInt(e.sign)) * w);
                    const p0t = if (blue) p0 else 1 - p0;
                    const p1t = if (blue) p1 else 1 - p1;
                    const credit = if (blue) p1 - without else without - p1;
                    try takes.append(arena, .{
                        .game = gi,
                        .band = @intCast(band),
                        .kind = e.kind,
                        .p0 = @floatCast(p0t),
                        .p1 = @floatCast(p1t),
                        .credit = @floatCast(credit),
                        .won = ge.blue_won == blue,
                        .steal = e.steal,
                        .contested = e.contested,
                        .is_test = ge.is_test,
                    });
                }
            }
            try out_rows.append(arena, row);
        }
    }
    return .{ .rows = out_rows.items, .takes = takes.items, .n_games = n_games };
}

/// OLS per band of y (0 dp, 1 dgold) on the intercept and kinds, games weighted by
/// `gw`; kinds never seen in a band get 0 (a tiny ridge keeps them solvable)
fn solve(d: Data, gw: ?[]const f32, which: u1, out: *[n_band][n_x]f64) void {
    var xtx: [n_band][n_x][n_x]f64 = @splat(@splat(@splat(0)));
    var xty: [n_band][n_x]f64 = @splat(@splat(0));
    for (d.rows) |r| {
        const w: f64 = if (gw) |g| g[r.game] else 1;
        if (w == 0) continue;
        const y: f64 = if (which == 0) r.dp else r.dgold;
        var idx: [n_x]u8 = undefined;
        var val: [n_x]f64 = undefined;
        var n: usize = 1;
        idx[0] = 0;
        val[0] = 1;
        for (r.x, 0..) |x, k| if (x != 0) {
            idx[n] = @intCast(k + 1);
            val[n] = @floatFromInt(x);
            n += 1;
        };
        const b = r.band;
        for (0..n) |a| {
            xty[b][idx[a]] += w * val[a] * y;
            for (0..n) |c| xtx[b][idx[a]][idx[c]] += w * val[a] * val[c];
        }
    }
    for (0..n_band) |b| {
        for (0..n_x) |i| xtx[b][i][i] += 1e-6;
        out[b] = cholSolve(xtx[b], xty[b]);
    }
}

fn cholSolve(a_in: [n_x][n_x]f64, b_in: [n_x]f64) [n_x]f64 {
    var a = a_in;
    var b = b_in;
    for (0..n_x) |j| {
        var s = a[j][j];
        for (0..j) |k| s -= a[j][k] * a[j][k];
        a[j][j] = @sqrt(@max(s, 1e-12));
        for (j + 1..n_x) |i| {
            var t = a[i][j];
            for (0..j) |k| t -= a[i][k] * a[j][k];
            a[i][j] = t / a[j][j];
        }
    }
    for (0..n_x) |i| {
        var t = b[i];
        for (0..i) |k| t -= a[i][k] * b[k];
        b[i] = t / a[i][i];
    }
    var i = n_x;
    while (i > 0) {
        i -= 1;
        var t = b[i];
        for (i + 1..n_x) |k| t -= a[k][i] * b[k];
        b[i] = t / a[i][i];
    }
    return b;
}

fn poisson1(r: std.Random) f32 {
    const l = @exp(-1.0);
    var k: f32 = 0;
    var p: f64 = 1;
    while (true) {
        p *= r.float(f64);
        if (p <= l) return k;
        k += 1;
    }
}

const Realised = struct {
    n: u32 = 0,
    /// Means: result, chance at m and m+1, credit
    won: f64 = 0,
    p0: f64 = 0,
    p1: f64 = 0,
    credit: f64 = 0,

    fn share(r: Realised) f64 {
        return 1 + (r.won - r.p1) / r.credit;
    }
};

const Group = enum { all, normal, steal, contested, uncontested, behind, test_games };
const n_group = @typeInfo(Group).@"enum".field_names.len;
/// Kinds reported in realised.tsv
const real_kinds = [_][]const u8{ "dragon", "elder", "baron", "herald", "grub", "tower", "inhibitor" };

fn realKind(k: Kind) ?usize {
    if (isDragon(k)) return 0;
    return switch (k) {
        .elder => 1,
        .baron => 2,
        .herald => 3,
        .grub => 4,
        .tower_outer, .tower_inner, .tower_base, .tower_nexus => 5,
        .inhibitor => 6,
        else => null,
    };
}

fn inGroup(t: Take, g: Group) bool {
    return switch (g) {
        .all => true,
        .normal => t.steal == 0,
        .steal => t.steal == 1,
        .contested => t.contested,
        .uncontested => !t.contested,
        .behind => t.p0 < 0.5,
        .test_games => t.is_test,
    };
}

fn realised(d: Data, gw: ?[]const f32, out: *[real_kinds.len][n_group]Realised) void {
    out.* = @splat(@splat(.{}));
    var wsum: [real_kinds.len][n_group]f64 = @splat(@splat(0));
    for (d.takes) |t| {
        const k = realKind(t.kind) orelse continue;
        const w: f64 = if (gw) |g| g[t.game] else 1;
        if (w == 0) continue;
        for (std.enums.values(Group), 0..) |g, gi| {
            if (!inGroup(t, g)) continue;
            const o = &out[k][gi];
            o.n += 1;
            o.won += w * @as(f64, @floatFromInt(@intFromBool(t.won)));
            o.p0 += w * t.p0;
            o.p1 += w * t.p1;
            o.credit += w * t.credit;
            wsum[k][gi] += w;
        }
    }
    for (out, wsum) |*row, ws| for (row, ws) |*o, w| if (w > 0) {
        o.won /= w;
        o.p0 /= w;
        o.p1 /= w;
        o.credit /= w;
    };
}

fn quantiles(arena: Allocator, xs: []const f64) ![2]f64 {
    const s = try arena.dupe(f64, xs);
    var n: usize = 0;
    for (s) |x| if (!std.math.isNan(x)) {
        s[n] = x;
        n += 1;
    };
    if (n == 0) return .{ std.math.nan(f64), std.math.nan(f64) };
    std.mem.sort(f64, s[0..n], {}, std.sort.asc(f64));
    const lo = s[@intFromFloat(@as(f64, @floatFromInt(n - 1)) * 0.025)];
    const hi = s[@intFromFloat(@as(f64, @floatFromInt(n - 1)) * 0.975)];
    return .{ lo, hi };
}

pub fn main(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const snap = argv[0];
    var out_dir: []const u8 = ".";
    var boot: u32 = 200;
    var preds_path: ?[]const u8 = null;
    var col: []const u8 = "p_wcd";
    var block: []const u8 = "cf";
    var i: usize = 1;
    while (i + 1 < argv.len) : (i += 2) {
        if (std.mem.eql(u8, argv[i], "--out")) {
            out_dir = argv[i + 1];
        } else if (std.mem.eql(u8, argv[i], "--boot")) {
            boot = try std.fmt.parseInt(u32, argv[i + 1], 10);
        } else if (std.mem.eql(u8, argv[i], "--preds")) {
            preds_path = argv[i + 1];
        } else if (std.mem.eql(u8, argv[i], "--col")) {
            col = argv[i + 1];
        } else if (std.mem.eql(u8, argv[i], "--block")) {
            block = argv[i + 1];
        } else {
            std.debug.print("eventvalue: unknown {s}\nusage:\n{s}", .{ argv[i], usage });
            return 2;
        }
    }
    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;

    var evs: std.AutoHashMapUnmanaged(u64, GameEvents) = .empty;
    defer evs.deinit(gpa);
    try loadEvents(gpa, arena, io, snap, &evs);
    var preds: Preds = .empty;
    defer preds.deinit(gpa);
    if (preds_path) |pp| try loadPreds(gpa, arena, io, pp, col, block, &preds);
    const d = try collect(gpa, arena, snap, &evs, if (preds_path != null) &preds else null);
    try w.print("# eventvalue: {d} games with events and a timeline, {d} game-minutes, {d} objective takes; {d} bootstrap reps\n", .{ d.n_games, d.rows.len, d.takes.len, boot });
    if (preds_path) |pp| {
        try w.print("# chances: {s} column {s}, block {s} ({d} games in the file)\n", .{ pp, col, block, preds.count() });
    } else try w.writeAll("# chances: winchance's state model (no draft terms)\n");
    const quiet = quietSlope(d.rows);
    try w.writeAll("# pp per 1000 gold of lead change in minutes with no event, by band:");
    for (quiet) |q| try w.print(" {d:.2}", .{q});
    try w.writeAll(if (preds_path != null) " (the gold unit)\n\n" else " (winchance's slope is the gold unit)\n\n");
    try w.flush();
    if (preds_path != null) for (d.rows) |*r| {
        r.marg = @floatCast(quiet[r.band]);
    };

    var est: [2][n_band][n_x]f64 = undefined;
    solve(d, null, 0, &est[0]);
    solve(d, null, 1, &est[1]);
    // Without the model's weights, a take's credit is what the regression gives its kind
    if (preds_path != null) for (d.takes) |*t| {
        t.credit = @floatCast(est[0][t.band][1 + @backingInt(t.kind)] / 100);
    };
    var real: [real_kinds.len][n_group]Realised = undefined;
    realised(d, null, &real);

    // Bootstrap over games: Poisson weights
    const reps = try arena.alloc([2][n_band][n_x]f64, boot);
    const real_reps = try arena.alloc([real_kinds.len][n_group]Realised, boot);
    const Ctx = struct {
        gpa: Allocator,
        d: Data,
        reps: [][2][n_band][n_x]f64,
        real_reps: [][real_kinds.len][n_group]Realised,
        fn one(x: @This(), r: usize) !void {
            const gw = try x.gpa.alloc(f32, x.d.n_games);
            defer x.gpa.free(gw);
            var rng: std.Random.DefaultPrng = .init(0xe7e7 +% r);
            for (gw) |*v| v.* = poisson1(rng.random());
            solve(x.d, gw, 0, &x.reps[r][0]);
            solve(x.d, gw, 1, &x.reps[r][1]);
            realised(x.d, gw, &x.real_reps[r]);
        }
    };
    try par.forEach(io, boot, Ctx{ .gpa = gpa, .d = d, .reps = reps, .real_reps = real_reps }, Ctx.one);

    // Mean marginal (pp per 1000 gold) and starting chance over the rows with each kind
    var marg: [n_band][n_kind]f64 = @splat(@splat(0));
    var cnt: [n_band][n_kind]f64 = @splat(@splat(0));
    for (d.rows) |r| for (r.x, 0..) |x, k| if (x != 0) {
        const n: f64 = @floatFromInt(@abs(x));
        marg[r.band][k] += n * r.marg;
        cnt[r.band][k] += n;
    };

    try Io.Dir.cwd().createDirPath(io, out_dir);
    var dir = try Io.Dir.cwd().openDir(io, out_dir, .{});
    defer dir.close(io);
    var ef = try dir.createFile(io, "eventvalue.tsv", .{});
    defer ef.close(io);
    var ebuf: [16 * 1024]u8 = undefined;
    var ew = ef.writer(io, &ebuf);
    try ew.interface.writeAll("minutes\tevent\tevents\twin_pp\twin_lo\twin_hi\tgold\tgold_lo\tgold_hi\tgold_equiv\tgold_equiv_lo\tgold_equiv_hi\tpp_per_1000\n");
    const xs = try arena.alloc(f64, boot);
    for (0..n_band) |b| {
        try w.print("minutes {d}-{d}: event, events, win pp [95%], gold [95%], gold equivalent of the win pp [95%]\n", .{ bands[b][0], bands[b][1] - 1 });
        for (0..n_kind) |k| {
            if (cnt[b][k] < 30) continue;
            const mg = marg[b][k] / cnt[b][k];
            var ci: [3][2]f64 = undefined;
            for (0..3) |c| {
                for (reps, xs) |r, *x| x.* = switch (c) {
                    0 => r[0][b][k + 1],
                    1 => r[1][b][k + 1],
                    else => r[0][b][k + 1] / mg * 1000,
                };
                ci[c] = try quantiles(arena, xs);
            }
            const pp = est[0][b][k + 1];
            const gold = est[1][b][k + 1];
            const name = @tagName(@as(Kind, @fromBackingInt(@as(u8, @intCast(k)))));
            try w.print("  {s:<14} {d:>8.0}  {d:>6.2} [{d:.2}, {d:.2}]  {d:>6.0} [{d:.0}, {d:.0}]  {d:>6.0} [{d:.0}, {d:.0}]\n", .{ name, cnt[b][k], pp, ci[0][0], ci[0][1], gold, ci[1][0], ci[1][1], pp / mg * 1000, ci[2][0], ci[2][1] });
            try ew.interface.print("{d}-{d}\t{s}\t{d:.0}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.1}\t{d:.1}\t{d:.1}\t{d:.1}\t{d:.1}\t{d:.1}\t{d:.3}\n", .{ bands[b][0], bands[b][1] - 1, name, cnt[b][k], pp, ci[0][0], ci[0][1], gold, ci[1][0], ci[1][1], pp / mg * 1000, ci[2][0], ci[2][1], mg });
        }
        try w.flush();
    }
    try ew.interface.flush();

    var rf = try dir.createFile(io, "realised.tsv", .{});
    defer rf.close(io);
    var rbuf: [16 * 1024]u8 = undefined;
    var rw = rf.writer(io, &rbuf);
    try rw.interface.writeAll("objective\tgroup\ttakes\twon\tchance_before\tchance_after\tcredit_pp\texcess_pp\texcess_lo\texcess_hi\trealised_share\tshare_lo\tshare_hi\n");
    try w.writeAll("\nCause or ahead: taking team's results after the take vs the model (pp); realised share of the model's credit [95%]\n");
    for (real_kinds, 0..) |name, k| {
        for (std.enums.values(Group), 0..) |g, gi| {
            const r = real[k][gi];
            if (r.n < 30) continue;
            for (real_reps, xs) |rr, *x| x.* = 100 * (rr[k][gi].won - rr[k][gi].p1);
            const ex = try quantiles(arena, xs);
            for (real_reps, xs) |rr, *x| x.* = rr[k][gi].share();
            const sh = try quantiles(arena, xs);
            try w.print("  {s:<10} {s:<12} {d:>7}  won {d:.3} before {d:.3} after {d:.3}  credit {d:.2}  excess {d:.2} [{d:.2}, {d:.2}]  share {d:.2} [{d:.2}, {d:.2}]\n", .{ name, @tagName(g), r.n, r.won, r.p0, r.p1, 100 * r.credit, 100 * (r.won - r.p1), ex[0], ex[1], r.share(), sh[0], sh[1] });
            try rw.interface.print("{s}\t{s}\t{d}\t{d:.4}\t{d:.4}\t{d:.4}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\n", .{ name, @tagName(g), r.n, r.won, r.p0, r.p1, 100 * r.credit, 100 * (r.won - r.p1), ex[0], ex[1], r.share(), sh[0], sh[1] });
        }
    }
    try rw.interface.flush();
    try w.flush();
    return 0;
}

const testing = std.testing;

test "event regression splits credit between events of one minute" {
    // Two kinds, dp = 3 per tower and 1 per kill, gold 300 and 100, every row a mix
    const gpa = testing.allocator;
    var rs: std.ArrayList(Row) = .empty;
    defer rs.deinit(gpa);
    var rng: std.Random.DefaultPrng = .init(5);
    const r = rng.random();
    for (0..4000) |gi| {
        var row: Row = .{ .game = @intCast(gi), .band = 2, .dp = 0, .dgold = 0, .marg = 5, .x = @splat(0) };
        const tw: i8 = @as(i8, r.intRangeAtMost(i8, -1, 1));
        const kl: i8 = @as(i8, r.intRangeAtMost(i8, -2, 2));
        row.x[@backingInt(Kind.tower_outer)] = tw;
        row.x[@backingInt(Kind.kill)] = kl;
        row.dp = @floatCast(3 * @as(f64, @floatFromInt(tw)) + @as(f64, @floatFromInt(kl)) + 0.5 * r.floatNorm(f64));
        row.dgold = @floatCast(300 * @as(f64, @floatFromInt(tw)) + 100 * @as(f64, @floatFromInt(kl)));
        try rs.append(gpa, row);
    }
    var est: [n_band][n_x]f64 = undefined;
    solve(.{ .rows = rs.items, .takes = &.{}, .n_games = 4000 }, null, 0, &est);
    try testing.expectApproxEqAbs(3.0, est[2][1 + @backingInt(Kind.tower_outer)], 0.05);
    try testing.expectApproxEqAbs(1.0, est[2][1 + @backingInt(Kind.kill)], 0.05);
    solve(.{ .rows = rs.items, .takes = &.{}, .n_games = 4000 }, null, 1, &est);
    try testing.expectApproxEqAbs(300.0, est[2][1 + @backingInt(Kind.tower_outer)], 1e-3);
}

test "eventvalue quiet slope: gold value from minutes with no event" {
    var rows: [300]Row = undefined;
    for (&rows, 0..) |*r, k| {
        const g: f32 = @floatFromInt(@as(i32, @intCast(k % 7)) - 3);
        r.* = .{ .game = 0, .band = @intCast(k % 2), .dp = 2.5 * g + 0.1, .dgold = 1000 * g, .marg = 0, .x = @splat(0) };
        // Minutes with an event don't count
        if (k % 5 == 0) {
            r.x[@backingInt(Kind.kill)] = 1;
            r.dp += 9;
        }
    }
    const q = quietSlope(&rows);
    try testing.expectApproxEqAbs(2.5, q[0], 1e-6);
    try testing.expectApproxEqAbs(2.5, q[1], 1e-6);
    try testing.expect(std.math.isNan(q[2]));
}

test "eventvalue preds file: block and column by header" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "p.tsv", .data = "match_id\tminute\tblock\tp_wc\tp_wcd\n" ++
        "EUW1_1\t1\tcf\t0.5\t0.6\n" ++
        "EUW1_1\t2\tcf\t0.55\t0.65\n" ++
        "EUW1_1\t2\t3\t0.1\t0.2\n" ++
        "EUW1_2\t41\tcf\t0.5\t0.5\n" });
    const path = try tmp.dir.realPathFileAlloc(io, "p.tsv", testing.allocator);
    defer testing.allocator.free(path);
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var preds: Preds = .empty;
    defer preds.deinit(testing.allocator);
    try loadPreds(testing.allocator, arena.allocator(), io, path, "p_wcd", "cf", &preds);
    try testing.expectEqual(1, preds.count());
    const g = preds.get(stats.matchKey("EUW1_1")).?;
    try testing.expectEqual(0.6, g[1]);
    try testing.expectEqual(0.65, g[2]);
    try testing.expect(std.math.isNan(g[3]));
}

test "kinds from events.tsv" {
    try testing.expectEqual(Kind.mountain, kindOf("monster", "EARTH_DRAGON").?);
    try testing.expectEqual(Kind.tower_base, kindOf("tower", "BASE_TURRET").?);
    try testing.expectEqual(@as(?Kind, null), kindOf("ward", "-"));
    try testing.expectEqual(objectives.Feat.dragons, heldFeat(.chemtech).?);
}
