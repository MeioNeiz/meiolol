//! The admin Draft tester's lane model file (docs/model.md "Lane model file"): its shapes,
//! the reference scorer the page's JS must match, and the writer of lane-model.json and
//! lane-ref.json. Shared by `meiolol-lab lane --export` (lab/lane.zig) and the box's
//! `meiolol lane-model` (lanemodel.zig); both fit src/lab/cand/team2. Champion-only inputs;
//! admin only

const std = @import("std");
const store = @import("store");

const Io = std.Io;

pub const n_role = 5;
pub const n_lane = 4;
const z95 = 1.96;
/// Every lane pair with a training game: thin pairs' shrunk cells are small but real (the
/// lane embeddings' gain over 3c-team was all in matchups under ~100 games)
pub const min_pair_games = 1;
/// team2's lane_outcomes, in this order everywhere
pub const outcomes = [n_lane][]const u8{ "gold14", "lanediff14", "cs10", "deaths15" };
pub const units = [n_lane][]const u8{ "gold", "gold", "CS", "deaths" };

/// One champion-role term (enemy 0) or lane pair cell, in the outcome's units; sd is the
/// shrunk estimate's posterior, sigma/sqrt(n+k); n training rows (gold14's)
pub const Term = struct {
    champion: u32,
    enemy: u32 = 0,
    role: u8,
    n: u32,
    b: [n_lane]f64,
    sd: [n_lane]f64,
};

/// team2's LaneExport: value = intercept + others + champ(you) + enemy(opponent) +
/// pair(you, opponent), a missing term counting 0
pub const Export = struct {
    patch: u32,
    /// Role mean plus the platform's and the newest patch's offsets, per outcome and role
    intercept: [n_lane][n_role]f64,
    /// The other eight slots at their average
    others: [n_lane][n_role]f64,
    /// Typical game-to-game spread around the expectation (residual sd)
    spread: [n_lane][n_role]f64,
    champ: []const Term,
    /// The lane opponent's own effect, for the player in that role
    enemy: []const Term,
    pairs: []const Term,
};

/// team2's exportLane result as the file's, every number to 0.01 of its unit: the file is
/// what the page scores with, so the reference scorer reads the same rounded values
pub fn rounded(arena: std.mem.Allocator, ex: anytype) !Export {
    var out: Export = .{ .patch = ex.patch, .intercept = ex.intercept, .others = ex.others, .spread = ex.spread, .champ = &.{}, .enemy = &.{}, .pairs = &.{} };
    for ([_]*[n_lane][n_role]f64{ &out.intercept, &out.others, &out.spread }) |a| for (a) |*row| for (row) |*x| {
        x.* = round2(x.*);
    };
    for ([_]*[]const Term{ &out.champ, &out.enemy, &out.pairs }, [_]@TypeOf(ex.champ){ ex.champ, ex.enemy, ex.pairs }) |terms, from| {
        const copy = try arena.alloc(Term, from.len);
        for (copy, from) |*t, f| {
            t.* = .{ .champion = f.champion, .enemy = f.enemy, .role = f.role, .n = f.n, .b = f.b, .sd = f.sd };
            for (&t.b, &t.sd) |*b, *sd| {
                b.* = round2(b.*);
                sd.* = round2(sd.*);
            }
        }
        terms.* = copy;
    }
    return out;
}

fn round2(x: f64) f64 {
    return @round(x * 100) / 100;
}

/// The reference scorer, from exported parameters only: what the page's JS must match
pub const Scorer = struct {
    ex: Export,
    champ: std.AutoHashMapUnmanaged(u64, Term) = .empty,
    enemy: std.AutoHashMapUnmanaged(u64, Term) = .empty,
    pairs: std.AutoHashMapUnmanaged(u64, Term) = .empty,

    pub fn key(role: u8, champion: u32, enemy: u32) u64 {
        return (@as(u64, champion) << 32) | (@as(u64, enemy) << 3) | role;
    }

    pub fn init(arena: std.mem.Allocator, ex: Export) !Scorer {
        var s: Scorer = .{ .ex = ex };
        for (ex.champ) |t| try s.champ.put(arena, key(t.role, t.champion, 0), t);
        for (ex.enemy) |t| try s.enemy.put(arena, key(t.role, t.champion, 0), t);
        for (ex.pairs) |t| try s.pairs.put(arena, key(t.role, t.champion, t.enemy), t);
        return s;
    }

    pub const Value = struct {
        value: [n_lane]f64,
        lo: [n_lane]f64,
        hi: [n_lane]f64,
        champ_games: u32,
        pair_games: u32,
    };

    /// docs/model.md "Lane model file": intercept + others + champ + enemy + pair, a
    /// missing term 0; the interval from the three terms' sds, as independent
    pub fn value(s: *const Scorer, role: u8, champion: u32, enemy: u32, with_others: bool) Value {
        const terms = [_]?Term{
            s.champ.get(key(role, champion, 0)),
            s.enemy.get(key(role, enemy, 0)),
            s.pairs.get(key(role, champion, enemy)),
        };
        var v: Value = .{ .value = undefined, .lo = undefined, .hi = undefined, .champ_games = if (terms[0]) |t| t.n else 0, .pair_games = if (terms[2]) |t| t.n else 0 };
        for (0..n_lane) |oi| {
            var x = s.ex.intercept[oi][role] + if (with_others) s.ex.others[oi][role] else 0;
            var vr: f64 = 0;
            for (terms) |maybe| if (maybe) |t| {
                x += t.b[oi];
                vr += t.sd[oi] * t.sd[oi];
            };
            v.value[oi] = x;
            v.lo[oi] = x - z95 * @sqrt(vr);
            v.hi[oi] = x + z95 * @sqrt(vr);
        }
        return v;
    }
};

pub const ChampionOut = struct { id: u32, name: []const u8, alias: []const u8 };

/// Per outcome: a refit on dev's games scored on dev-val, typical miss in the unit and
/// the share of the champion-role baseline's error removed, with its 95% half-width
pub const DevOut = struct {
    outcome: []const u8,
    unit: []const u8,
    rows: usize,
    err_base: f64,
    err_cand: f64,
    removed_pct: f64,
    removed_half: f64,
};

pub const Meta = struct {
    name: []const u8,
    run: []const u8,
    snapshot: []const u8,
    newest_game: []const u8,
    training_games: usize,
    /// Patch whose offset the scorer adds (the newest), and the training games' first
    /// and last (patchRange)
    patch: []const u8,
    oldest_patch: []const u8,
    newest_patch: []const u8,
    platform: []const u8,
    dev: []const DevOut,
};

pub const ModelFile = struct {
    format: []const u8 = "meiolol-lane-model",
    version: u32 = 1,
    meta: Meta,
    roles: [n_role][]const u8 = .{ "top", "jungle", "middle", "bottom", "utility" },
    outcomes: [n_lane][]const u8 = outcomes,
    units: [n_lane][]const u8 = units,
    min_pair_games: u32 = min_pair_games,
    champions: []const ChampionOut,
    intercept: [n_lane][n_role]f64,
    others: [n_lane][n_role]f64,
    spread: [n_lane][n_role]f64,
    champ: []const Term,
    enemy: []const Term,
    pair_columns: [4 + 2 * n_lane][]const u8 = pair_columns,
    /// Arrays in pair_columns order, to keep the file small
    pairs: []const PairRow,
};

pub const PairRow = struct { u32, u32, u8, u32, f64, f64, f64, f64, f64, f64, f64, f64 };

const pair_columns = blk: {
    var out: [4 + 2 * n_lane][]const u8 = undefined;
    out[0..4].* = .{ "champion", "enemy", "role", "n" };
    for (outcomes, 0..) |o, i| {
        out[4 + i] = "b_" ++ o;
        out[4 + n_lane + i] = "sd_" ++ o;
    }
    break :blk out;
};

fn pairRows(arena: std.mem.Allocator, terms: []const Term) ![]const PairRow {
    comptime std.debug.assert(n_lane == 4);
    const out = try arena.alloc(PairRow, terms.len);
    for (out, terms) |*o, t| o.* = .{ t.champion, t.enemy, t.role, t.n, t.b[0], t.b[1], t.b[2], t.b[3], t.sd[0], t.sd[1], t.sd[2], t.sd[3] };
    return out;
}

pub const Ref = struct {
    label: []const u8,
    role: u8,
    champion: u32,
    enemy: u32,
    value: [n_lane]f64,
    lo: [n_lane]f64,
    hi: [n_lane]f64,
    champ_games: u32,
    pair_games: u32,
};

pub const RefFile = struct {
    format: []const u8 = "meiolol-lane-ref",
    what: []const u8 = "Scorer.value with others: intercept + others + champ + enemy + pair per outcome; lo/hi = value -/+ 1.96 sqrt(sum of the present terms' sd^2)",
    refs: []const Ref,
};

fn ref(sc: *const Scorer, label: []const u8, role: u8, champion: u32, enemy: u32) Ref {
    var v = sc.value(role, champion, enemy, true);
    for ([_]*[n_lane]f64{ &v.value, &v.lo, &v.hi }) |a| for (a) |*x| {
        x.* = round2(x.*);
    };
    return .{ .label = label, .role = role, .champion = champion, .enemy = enemy, .value = v.value, .lo = v.lo, .hi = v.hi, .champ_games = v.champ_games, .pair_games = v.pair_games };
}

/// Every champion in the champions table, by name
pub fn championList(arena: std.mem.Allocator, db: store.Db) ![]const ChampionOut {
    var out: std.ArrayList(ChampionOut) = .empty;
    var q = try db.prepare("SELECT id, name FROM champions ORDER BY name");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) {
        const name = try arena.dupe(u8, q.bytes(1));
        var alias: std.ArrayList(u8) = .empty;
        for (name) |ch| if (std.ascii.isAlphanumeric(ch)) try alias.append(arena, std.ascii.toLower(ch));
        try out.append(arena, .{ .id = @intCast(q.int(0)), .name = name, .alias = alias.items });
    }
    return out.items;
}

/// stats.patchKey back to "16.21"
pub fn patchLabel(arena: std.mem.Allocator, key: u32) ![]const u8 {
    return arena.print("{d}.{d}", .{ key / 1000, key % 1000 });
}

/// Oldest and newest of `games`' patches (each .patch, a stats.patchKey) as labels
pub fn patchRange(arena: std.mem.Allocator, games: anytype) ![2][]const u8 {
    var lo: u32 = std.math.maxInt(u32);
    var hi: u32 = 0;
    for (games) |g| {
        lo = @min(lo, g.patch);
        hi = @max(hi, g.patch);
    }
    if (hi == 0) lo = 0;
    return .{ try patchLabel(arena, lo), try patchLabel(arena, hi) };
}

/// DIR/lane-model.json and DIR/lane-ref.json. References: per role the 4 most played
/// pairs, one of their champions into an opponent with no pair cell, and an unknown champion
pub fn write(arena: std.mem.Allocator, io: Io, sc: *const Scorer, meta: Meta, champions: []const ChampionOut, dir: []const u8, w: *Io.Writer) !void {
    const ex = sc.ex;
    const model: ModelFile = .{
        .meta = meta,
        .champions = champions,
        .intercept = ex.intercept,
        .others = ex.others,
        .spread = ex.spread,
        .champ = ex.champ,
        .enemy = ex.enemy,
        .pairs = try pairRows(arena, ex.pairs),
    };
    var refs: std.ArrayList(Ref) = .empty;
    for (0..n_role) |r| {
        var top: [4]?Term = @splat(null);
        for (ex.pairs) |p| {
            if (p.role != r) continue;
            var cur: Term = p;
            for (&top) |*slot| {
                if (slot.* == null) {
                    slot.* = cur;
                    break;
                }
                if (cur.n > slot.*.?.n) std.mem.swap(Term, &cur, &slot.*.?);
            }
        }
        const role: u8 = @intCast(r);
        for (top) |maybe| if (maybe) |p| try refs.append(arena, ref(sc, "most played pair", role, p.champion, p.enemy));
        if (top[0]) |p| {
            const no_pair = for (ex.enemy) |e| {
                if (e.role == role and sc.pairs.get(Scorer.key(role, p.champion, e.champion)) == null and e.champion != p.champion) break e.champion;
            } else 0;
            try refs.append(arena, ref(sc, "no pair cell: champion and opponent terms only", role, p.champion, no_pair));
            try refs.append(arena, ref(sc, "unknown champion (id 0)", role, 0, p.enemy));
        }
    }

    try Io.Dir.cwd().createDirPath(io, dir);
    const model_json = try std.json.Stringify.valueAlloc(arena, model, .{});
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "lane-model.json" }), .data = model_json });
    const ref_json = try std.json.Stringify.valueAlloc(arena, RefFile{ .refs = refs.items }, .{ .whitespace = .indent_1 });
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "lane-ref.json" }), .data = ref_json });
    try w.print("wrote {s}/lane-model.json ({d} KB) and lane-ref.json ({d} KB)\n", .{ dir, model_json.len / 1024, ref_json.len / 1024 });
}

test "lane scorer: the documented formula on known parameters" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var ex: Export = .{ .patch = 16020, .intercept = @splat(@splat(5000)), .others = @splat(@splat(10)), .spread = @splat(@splat(800)), .champ = &.{}, .enemy = &.{}, .pairs = &.{} };
    const b: [n_lane]f64 = @splat(100);
    const sd: [n_lane]f64 = @splat(30);
    ex.champ = &.{.{ .champion = 1, .role = 0, .n = 500, .b = b, .sd = sd }};
    ex.enemy = &.{.{ .champion = 2, .role = 0, .n = 400, .b = b, .sd = sd }};
    ex.pairs = &.{.{ .champion = 1, .enemy = 2, .role = 0, .n = 50, .b = b, .sd = sd }};
    const sc = try Scorer.init(arena, ex);
    const v = sc.value(0, 1, 2, true);
    try std.testing.expectApproxEqAbs(@as(f64, 5310), v.value[0], 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 5310 - z95 * @sqrt(3 * 900.0)), v.lo[0], 1e-9);
    try std.testing.expectEqual(@as(u32, 50), v.pair_games);
    // No pair cell, unknown opponent: champion term only
    const u = sc.value(0, 1, 99, false);
    try std.testing.expectApproxEqAbs(@as(f64, 5100), u.value[0], 1e-9);
}
