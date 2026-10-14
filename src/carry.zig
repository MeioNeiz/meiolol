//! `meiolol carry`: which champions carry (their own lead turns into wins), which barely
//! move the game, and whose seat decides games. Rows: every player at minutes 10-30 of
//! games reaching 15:00 and still going, and at the draft (minute 0). Log-odds of the
//! player's team winning, on top of a logistic baseline of the whole team state at that
//! minute (objectives.zig's held objectives, gold split by role, then kills minus deaths
//! and share of team damage by role); per champion-role a shift and slopes on the seat's
//! own lead over its lane opponent in gold, kills minus deaths and damage share, each
//! shrunk toward 0 by a method-of-moments prior per role (as scaling.zig). Skill: at the
//! draft, slopes on log1p(earlier games on the champion). Spread: how far from a coin
//! flip the champion's games stand at each minute. Like with like (same team state, same
//! minute) but descriptive: a seat's lead also says how well its player plays. Use-time:
//! post-game lessons and aggregate facts. Blocks as the lab's (`--cuts`: compcheck
//! --folds 5 and dev-val), test only with --final.

const std = @import("std");
const store = @import("store");
const core = @import("core");
const stats = @import("stats.zig");
const analysis = @import("analysis.zig");
const eval = @import("eval.zig");
const logreg = @import("logreg.zig");
const objectives = @import("objectives.zig");
const par = @import("par.zig");
const timeline = @import("riot/timeline.zig");
const Date = @import("date.zig").Date;
const Role = core.Role;
const Io = std.Io;

pub const n_folds = 5;

pub const Options = struct {
    test_share: f64 = eval.test_share,
    /// Region filter: dev-val and test scored on this platform only (eval.split)
    test_platform: ?[]const u8 = null,
    passes: u32 = 8,
    /// Block starts of the 5 folds, the dev cut, the test cut (ms; harness.Cuts); all 0:
    /// from eval.split's cuts, as the lab's
    cuts: [n_folds + 2]i64 = @splat(0),
    /// TSV of every type x role x state term by minute (every train game's fit)
    type_table: ?[]const u8 = null,
    /// Also fit on every train game and score the test games: one look per model
    final: bool = false,
    /// TSV of every champion-role's terms by minute, fitted on every train game
    table: ?[]const u8 = null,
    /// TSV of each champion-role's leverage, scaling and skill fitted before each fold's
    /// block and the dev cut (meiolol-c1's comp screen joins it per fold)
    fold_table: ?[]const u8 = null,
    plant: ?Plant = null,
    /// With final: test games (stats.matchKey) an earlier snapshot's looks saw; the test
    /// rows are also reported without them (SNAP/test-exclude.tsv, lab/looks.zig)
    exclude: ?*const std.AutoHashMapUnmanaged(u64, void) = null,
};

/// Winners redrawn from the baseline plus a planted slope per champion-role, normal with
/// sd `sd` (win pp per the measure's unit), so recovery and the smallest detectable
/// spread can be read off
pub const Plant = struct { cov: Cov, sd: f64, seed: u64 = 1 };

/// A term's covariate: a shift, or the seat's own side minus its lane opponent's
pub const Cov = enum {
    one,
    /// gold, thousands
    lane,
    /// kills minus deaths
    kd,
    /// share of the team's damage to champions so far
    dmg,
    /// log1p(earlier games on the champion), the seat's own
    exp,
    /// the team's: gold lead (thousands), XP lead (thousands), towers taken, dragons,
    /// baron buffs held, each own side minus the enemy's
    team,
    xp,
    towers,
    dragons,
    baron,

    /// Reported unit, in the covariate's units
    fn unit(c: Cov) f64 {
        return if (c == .dmg) 0.1 else 1;
    }

    fn unitName(c: Cov) []const u8 {
        return switch (c) {
            .one => "",
            .lane => "1000 gold",
            .kd => "kill minus death",
            .dmg => "10 points of damage share",
            .exp => "log1p game",
            .team => "1000 team gold",
            .xp => "1000 team XP",
            .towers => "tower",
            .dragons => "dragon",
            .baron => "baron",
        };
    }
};

const minute_ms = 60_000;
/// 0: the draft (skill only)
const minutes = [_]u8{0} ++ objectives.minutes;
const n_min = minutes.len;
/// Champion-roles shown in the markdown need this many fit rows
const shown_games = 500;
const pp = 25.0;

// Row.x layout, own side minus the enemy's: gold by role, gold curve, XP, held
// objectives, kills minus deaths by role, damage share by role
const x_gold = 0;
const x_curve = Role.count;
const x_xp = x_curve + 1;
const x_held = x_xp + 1;
const n_held = objectives.held.len;
const x_kd = x_held + n_held;
const x_dmg = x_kd + Role.count;
const n_x = x_dmg + Role.count;

/// One player at one minute
const Row = struct {
    game: u32,
    side: u1,
    role: u8,
    champ: u16,
    won: bool,
    exp: f32,
    x: [n_x]f32,
};

fn covariate(c: Cov, r: Row) f64 {
    return switch (c) {
        .one => 1,
        .lane => r.x[x_gold + r.role],
        .kd => r.x[x_kd + r.role],
        .dmg => r.x[x_dmg + r.role],
        .exp => r.exp,
        .team => blk: {
            var g: f64 = 0;
            for (r.x[x_gold..][0..Role.count]) |v| g += v;
            break :blk g;
        },
        .xp => r.x[x_xp],
        .towers => r.x[x_held + heldIndex(.towers)],
        .dragons => r.x[x_held + heldIndex(.dragons)],
        .baron => r.x[x_held + heldIndex(.baron)],
    };
}

fn heldIndex(comptime f: objectives.Feat) usize {
    return comptime std.mem.indexOfScalar(objectives.Feat, objectives.held, f).?;
}

/// Champion types: the first of Data Dragon's tags (as outcomes.zig's classes), then
/// "other" for champions without one
pub const types = [_][]const u8{ "Assassin", "Fighter", "Mage", "Marksman", "Support", "Tank", "other" };
const n_types = types.len;

fn championTypes(arena: std.mem.Allocator, db: store.Db, ids: []const u32) ![]u8 {
    const out = try arena.alloc(u8, ids.len);
    @memset(out, n_types - 1);
    var q = try db.prepare("SELECT tags FROM champions WHERE id = ?");
    defer q.deinit();
    for (ids, out) |id, *c| {
        try q.bind(.{@as(i64, id)});
        if (!try q.step() or q.isNull(0)) continue;
        var it = std.mem.splitScalar(u8, q.bytes(0), ',');
        const first = it.next() orelse continue;
        for (types[0 .. n_types - 1], 0..) |name, k| {
            if (std.mem.eql(u8, name, first)) c.* = @intCast(k);
        }
    }
    return out;
}

fn cellOf(champs: usize, r: Row) usize {
    return @as(usize, r.role) * champs + r.champ;
}

const Game = struct {
    match_id: []const u8,
    slot: [2][Role.count]u8,
    /// blue minus red (null: ended by then; the draft's is all 0)
    states: [n_min]?[n_x]f32,
};

const Map = std.AutoHashMapUnmanaged(u64, Game);
/// Earlier ranked solo games on the champion, by match and participant slot
const ExpMap = std.AutoHashMapUnmanaged(u64, [10]u16);

fn loadExp(gpa: std.mem.Allocator, db: store.Db, platforms: []const []const u8) !ExpMap {
    const platform_json = try std.json.Stringify.valueAlloc(gpa, platforms, .{});
    defer gpa.free(platform_json);
    var q = try db.prepare(
        \\SELECT pa.match_id, pa.slot, ROW_NUMBER() OVER (PARTITION BY pa.puuid, pa.champion_id
        \\  ORDER BY m.game_start, pa.match_id) - 1
        \\FROM participants pa JOIN matches m USING (match_id)
        \\WHERE m.queue_id = ? AND m.remake = 0 AND m.platform IN (SELECT value FROM json_each(?))
    );
    defer q.deinit();
    try q.bind(.{ stats.ranked_solo, platform_json });
    var map: ExpMap = .empty;
    errdefer map.deinit(gpa);
    while (try q.step()) {
        const slot = q.int(1);
        if (slot < 0 or slot >= 10) continue;
        const gop = try map.getOrPut(gpa, stats.matchKey(q.bytes(0)));
        if (!gop.found_existing) gop.value_ptr.* = @splat(0);
        gop.value_ptr[@intCast(slot)] = @intCast(@min(q.int(2), std.math.maxInt(u16)));
    }
    return map;
}

fn share(d: i32, total: f32) f32 {
    return if (total > 0) @as(f32, @floatFromInt(d)) / total else 1.0 / @as(f32, Role.count);
}

/// The state at `minute`, blue minus red; null once the game has ended
fn snapAt(t: timeline.Timeline, pid: analysis.Pids, minute: u8) ?[n_x]f32 {
    const s = objectives.stateAt(t, minute) orelse return null;
    const f = t.frames[minute];
    var x: [n_x]f32 = @splat(0);
    x[x_curve] = s[@backingInt(objectives.Feat.gold_curve)];
    x[x_xp] = s[@backingInt(objectives.Feat.xp)];
    for (objectives.held, x[x_held..][0..n_held]) |feat, *v| v.* = s[@backingInt(feat)];
    // by participant id; killer 0 is a tower or minion
    var kd: [11]f32 = @splat(0);
    for (t.events) |e| {
        if (e.t_ms >= f.t_ms) break;
        switch (e.data) {
            .champion_kill => |k| {
                if (k.killer >= 1 and k.killer <= 10) kd[k.killer] += 1;
                if (k.victim >= 1 and k.victim <= 10) kd[k.victim] -= 1;
            },
            else => {},
        }
    }
    var dmg: [2]f32 = @splat(0);
    for (pid, &dmg) |team, *d| for (team) |p| {
        d.* += @floatFromInt(f.get(p, .damage_to_champions));
    };
    for (0..Role.count) |ri| {
        const b = pid[0][ri];
        const r = pid[1][ri];
        x[x_gold + ri] = @as(f32, @floatFromInt(f.get(b, .total_gold) - f.get(r, .total_gold))) / 1000;
        x[x_kd + ri] = kd[b] - kd[r];
        x[x_dmg + ri] = share(f.get(b, .damage_to_champions), dmg[0]) - share(f.get(r, .damage_to_champions), dmg[1]);
    }
    return x;
}

fn load(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
) !Map {
    var games: analysis.TimelineGames = try .init(gpa, db, chosen, platforms);
    defer games.deinit();
    var map: Map = .empty;
    errdefer map.deinit(gpa);
    while (try games.next()) |game| {
        const t = game.t;
        if (t.participants != 10 or t.frames.len < 16 or t.frames[15].t_ms < 15 * minute_ms) continue;
        const pid = try games.pids(game) orelse continue;
        var g: Game = .{ .match_id = try arena.dupe(u8, game.match_id), .slot = undefined, .states = undefined };
        for (0..2) |side| for (0..Role.count) |ri| {
            g.slot[side][ri] = pid[side][ri] - 1;
        };
        for (minutes, &g.states) |m, *st| st.* = if (m == 0) @splat(0) else snapAt(t, pid, m);
        try map.put(gpa, stats.matchKey(game.match_id), g);
    }
    return map;
}

/// The logistic baselines: what each knows of the team state
const Base = enum {
    /// win rate
    none,
    /// team gold, curve, XP, held objectives
    team,
    /// gold by role instead of the team's
    roles,
    /// roles, kills minus deaths and damage share by role
    full,
    /// draft: a slope on the seat's experience per role
    draft_exp,

    fn dims(b: Base) usize {
        return switch (b) {
            .none => 1,
            .team => 2 + (x_kd - x_curve),
            .roles => 1 + x_kd,
            .full => 1 + n_x,
            .draft_exp => 1 + Role.count,
        };
    }

    /// Dense features into `v` (dims long)
    fn features(b: Base, r: Row, v: []f64) void {
        @memset(v, 0);
        v[0] = 1;
        switch (b) {
            .none => {},
            .team => {
                var g: f64 = 0;
                for (r.x[x_gold..][0..Role.count]) |x| g += x;
                v[1] = g;
                for (r.x[x_curve..x_kd], v[2..]) |x, *o| o.* = x;
            },
            .roles => for (r.x[0..x_kd], v[1..]) |x, *o| {
                o.* = x;
            },
            .full => for (r.x, v[1..]) |x, *o| {
                o.* = x;
            },
            .draft_exp => v[1 + r.role] = r.exp,
        }
    }
};

const max_dims = 1 + n_x;

fn yOf(r: Row) f64 {
    return @floatFromInt(@intFromBool(r.won));
}

/// L2-penalised logistic regression by Newton steps (intercept unpenalised); weights
/// and, with `se`, standard errors clustered by game (sandwich, as logreg's)
fn fitBase(gpa: std.mem.Allocator, b: Base, rows: []const Row, se: ?[]f64) ![]f64 {
    const d = b.dims();
    const w = try gpa.alloc(f64, d);
    errdefer gpa.free(w);
    @memset(w, 0);
    var hess: [max_dims * max_dims]f64 = undefined;
    var grad: [max_dims]f64 = undefined;
    var v: [max_dims]f64 = undefined;
    var prev: f64 = std.math.inf(f64);
    for (0..30) |_| {
        @memset(hess[0 .. d * d], 0);
        @memset(grad[0..d], 0);
        var loss: f64 = 0;
        for (rows) |r| {
            b.features(r, v[0..d]);
            const p = logreg.sigmoid(dot(v[0..d], w));
            const y = yOf(r);
            loss += analysis.logLoss(p, y);
            const g = p - y;
            const h = p * (1 - p);
            for (0..d) |i| {
                if (v[i] == 0) continue;
                grad[i] += g * v[i];
                for (0..i + 1) |j| hess[i * d + j] += h * v[i] * v[j];
            }
        }
        for (1..d) |i| {
            grad[i] += w[i];
            hess[i * d + i] += 1;
            loss += 0.5 * w[i] * w[i];
        }
        for (0..d) |i| {
            if (hess[i * d + i] == 0) hess[i * d + i] = 1;
            for (0..i) |j| hess[j * d + i] = hess[i * d + j];
        }
        try solve(hess[0 .. d * d], d, grad[0..d]);
        for (w, grad[0..d]) |*wi, gi| wi.* -= gi;
        if (prev - loss < 1e-9 * @max(1, @abs(loss))) break;
        prev = loss;
    }
    if (se) |out| try sandwich(b, rows, w, out);
    return w;
}

fn dot(a: []const f64, b: []const f64) f64 {
    var s: f64 = 0;
    for (a, b) |x, y| s += x * y;
    return s;
}

/// Gaussian elimination with partial pivoting; `a` is destroyed, `x` becomes a^-1 x
fn solve(a: []f64, d: usize, x: []f64) !void {
    for (0..d) |c| {
        var best = c;
        for (c + 1..d) |r| if (@abs(a[r * d + c]) > @abs(a[best * d + c])) {
            best = r;
        };
        if (a[best * d + c] == 0) return error.Singular;
        if (best != c) {
            for (0..d) |k| std.mem.swap(f64, &a[c * d + k], &a[best * d + k]);
            std.mem.swap(f64, &x[c], &x[best]);
        }
        for (c + 1..d) |r| {
            const f = a[r * d + c] / a[c * d + c];
            if (f == 0) continue;
            for (c..d) |k| a[r * d + k] -= f * a[c * d + k];
            x[r] -= f * x[c];
        }
    }
    var i = d;
    while (i > 0) {
        i -= 1;
        var s = x[i];
        for (i + 1..d) |k| s -= a[i * d + k] * x[k];
        x[i] = s / a[i * d + i];
    }
}

/// Clustered standard errors: diag of H^-1 M H^-1, M summing each game's score outer
/// product (rows of a game adjacent)
fn sandwich(b: Base, rows: []const Row, w: []const f64, out: []f64) !void {
    const d = b.dims();
    var hess: [max_dims * max_dims]f64 = @splat(0);
    var meat: [max_dims * max_dims]f64 = @splat(0);
    var score: [max_dims]f64 = @splat(0);
    var v: [max_dims]f64 = undefined;
    var i: usize = 0;
    while (i < rows.len) {
        const g = rows[i].game;
        @memset(score[0..d], 0);
        while (i < rows.len and rows[i].game == g) : (i += 1) {
            const r = rows[i];
            b.features(r, v[0..d]);
            const p = logreg.sigmoid(dot(v[0..d], w));
            for (0..d) |a| {
                score[a] += (p - yOf(r)) * v[a];
                for (0..d) |c| hess[a * d + c] += p * (1 - p) * v[a] * v[c];
            }
        }
        for (0..d) |a| for (0..d) |c| {
            meat[a * d + c] += score[a] * score[c];
        };
    }
    for (1..d) |a| hess[a * d + a] += 1;
    for (0..d) |a| if (hess[a * d + a] == 0) {
        hess[a * d + a] = 1;
    };
    // column k of H^-1, then (H^-1 M H^-1)_kk = h_k' M h_k
    for (0..d) |k| {
        var h: [max_dims]f64 = @splat(0);
        h[k] = 1;
        var a: [max_dims * max_dims]f64 = undefined;
        @memcpy(a[0 .. d * d], hess[0 .. d * d]);
        try solve(a[0 .. d * d], d, h[0..d]);
        var s: f64 = 0;
        for (0..d) |x| for (0..d) |y| {
            s += h[x] * meat[x * d + y] * h[y];
        };
        out[k] = @sqrt(@max(s, 0));
    }
}

fn baseEta(gpa: std.mem.Allocator, b: Base, w: []const f64, rows: []const Row) ![]f64 {
    const eta = try gpa.alloc(f64, rows.len);
    var v: [max_dims]f64 = undefined;
    for (eta, rows) |*e, r| {
        b.features(r, v[0..b.dims()]);
        e.* = dot(v[0..b.dims()], w);
    }
    return eta;
}

/// Log-odds effects per champion-role cell (or champion type x role, with `type_of`),
/// times the covariate, by Newton steps on the whole model's working residual (IRLS);
/// champion cells shrunk by a method-of-moments prior per role, type cells (few, each
/// with thousands of rows) by a fixed ridge of 1
const Term = struct {
    cov: Cov,
    /// champion index -> type; null: champion cells
    type_of: ?[]const u8 = null,
    per_role: usize,
    b: []f64,
    /// unshrunk estimate given the other terms (sum x z / sum w x^2)
    raw: []f64,
    sxx: []f64,
    n: []f64,
    tau: [Role.count]f64 = @splat(0),
    /// upper 95% bound on tau (every-train fit only)
    bound: [Role.count]?f64 = @splat(null),

    fn init(gpa: std.mem.Allocator, spec: Spec, champs: usize, type_of: []const u8) !Term {
        const per_role = if (spec.by_type) n_types else champs;
        const cells = Role.count * per_role;
        const t: Term = .{
            .cov = spec.cov,
            .type_of = if (spec.by_type) type_of else null,
            .per_role = per_role,
            .b = try gpa.alloc(f64, cells),
            .raw = try gpa.alloc(f64, cells),
            .sxx = try gpa.alloc(f64, cells),
            .n = try gpa.alloc(f64, cells),
        };
        @memset(t.b, 0);
        @memset(t.raw, 0);
        return t;
    }

    fn deinit(t: Term, gpa: std.mem.Allocator) void {
        gpa.free(t.b);
        gpa.free(t.raw);
        gpa.free(t.sxx);
        gpa.free(t.n);
    }

    fn cell(t: Term, r: Row) usize {
        const k: usize = if (t.type_of) |m| m[r.champ] else r.champ;
        return @as(usize, r.role) * t.per_role + k;
    }

    /// Posterior sd (0 when off for the cell's role)
    fn sd(t: Term, c: usize) f64 {
        if (t.type_of != null) return 1 / @sqrt(t.sxx[c] + ridge);
        const tau = t.tau[c / t.per_role];
        if (tau == 0) return 0;
        return 1 / @sqrt(t.sxx[c] + 1 / (tau * tau));
    }

    fn update(t: *Term, gpa: std.mem.Allocator, rows: []const Row, eta: []f64) !void {
        const sxr = try gpa.alloc(f64, t.b.len);
        defer gpa.free(sxr);
        @memset(sxr, 0);
        @memset(t.sxx, 0);
        @memset(t.n, 0);
        for (rows, eta) |r, e| {
            const c = t.cell(r);
            const x = covariate(t.cov, r);
            const p = logreg.sigmoid(e);
            const wx2 = p * (1 - p) * x * x;
            sxr[c] += x * (yOf(r) - p) + t.b[c] * wx2;
            t.sxx[c] += wx2;
            t.n[c] += 1;
        }
        const old = try gpa.dupe(f64, t.b);
        defer gpa.free(old);
        const k = t.per_role;
        for (0..Role.count) |ri| {
            const lo = ri * k;
            const xr = sxr[lo..][0..k];
            const xx = t.sxx[lo..][0..k];
            const prior: analysis.Prior = if (t.type_of != null)
                .{ .k = ridge, .tau2 = 1 / ridge }
            else
                .estimate(xr, xx, t.n[lo..][0..k], 1);
            t.tau[ri] = @sqrt(prior.tau2);
            for (t.b[lo..][0..k], t.raw[lo..][0..k], xr, xx) |*b, *raw, r, x| {
                b.* = prior.effect(r, x);
                raw.* = if (x > 0) r / x else 0;
            }
        }
        for (rows, eta) |r, *e| {
            const c = t.cell(r);
            e.* += (t.b[c] - old[c]) * covariate(t.cov, r);
        }
    }

    fn bounds(t: *Term, gpa: std.mem.Allocator, rows: []const Row, eta: []const f64, n_games: usize) !void {
        if (t.type_of != null) return;
        const parts = try gpa.alloc(analysis.Part, rows.len);
        defer gpa.free(parts);
        for (parts, rows, eta) |*part, r, e| {
            const c = t.cell(r);
            const x = covariate(t.cov, r);
            const p = logreg.sigmoid(e);
            const wx2 = p * (1 - p) * x * x;
            part.* = .{ .game = r.game, .cell = @intCast(c), .xr = x * (yOf(r) - p) + t.b[c] * wx2, .xx = wx2 };
        }
        t.bound = try analysis.spreadBounds(gpa, parts, n_games, t.per_role, true, 1);
    }

    fn predict(t: Term, r: Row) f64 {
        return t.b[t.cell(r)] * covariate(t.cov, r);
    }
};

/// Prior strength of type cells, in IRLS information units
const ridge = 1.0;

const Spec = struct { cov: Cov, by_type: bool = false };

/// The in-game models in nesting order (draft: none, draft_exp, +shift, +exp slope)
const game_models = [_][]const u8{
    "team state",                 "gold by role",                   "+ kills, damage by role", "+ champion shift",
    "+ champion x own gold lead", "+ champion x own kills, damage", "+ type x own gold lead",  "+ type x team gold lead",
    "+ type x XP lead",           "+ type x towers",                "+ type x dragons",        "+ type x baron",
};
const draft_models = [_][]const u8{ "win rate", "+ experience slope by role", "+ champion shift", "+ champion x experience" };
const n_models = game_models.len;
/// Terms: shift, lane, kd, dmg (in game); shift, exp (draft)
const game_terms = [_]Spec{
    .{ .cov = .one },                      .{ .cov = .lane },                   .{ .cov = .kd },                  .{ .cov = .dmg },
    .{ .cov = .lane, .by_type = true },    .{ .cov = .team, .by_type = true },  .{ .cov = .xp, .by_type = true }, .{ .cov = .towers, .by_type = true },
    .{ .cov = .dragons, .by_type = true }, .{ .cov = .baron, .by_type = true },
};
const draft_terms = [_]Spec{ .{ .cov = .one }, .{ .cov = .exp } };
/// The type terms' first index in game_terms
const first_type = 4;
/// How many terms each model past the bases holds
const game_steps = [_]usize{ 1, 2, 4, 5, 6, 7, 8, 9, 10 };
const draft_steps = [_]usize{ 1, 2 };

/// Gaussian shift per champion-role on how decided its games stand (|team chance - 50|,
/// pp, from the team-state baseline)
const Decided = struct {
    mean: [Role.count]f64 = @splat(0),
    tau: [Role.count]f64 = @splat(0),
    b: []f64 = &.{},
    sd: []f64 = &.{},
};

fn decidedOf(e: f64) f64 {
    return @abs(logreg.sigmoid(e) - 0.5) * 100;
}

fn fitDecided(gpa: std.mem.Allocator, champs: usize, rows: []const Row, eta: []const f64) !Decided {
    var d: Decided = .{ .b = try gpa.alloc(f64, Role.count * champs), .sd = try gpa.alloc(f64, Role.count * champs) };
    var n: [Role.count]f64 = @splat(0);
    var ss: [Role.count]f64 = @splat(0);
    for (rows, eta) |r, e| {
        d.mean[r.role] += decidedOf(e);
        n[r.role] += 1;
    }
    for (&d.mean, n) |*m, k| m.* /= @max(k, 1);
    const sxr = try gpa.alloc(f64, d.b.len);
    defer gpa.free(sxr);
    const cn = try gpa.alloc(f64, d.b.len);
    defer gpa.free(cn);
    @memset(sxr, 0);
    @memset(cn, 0);
    for (rows, eta) |r, e| {
        const res = decidedOf(e) - d.mean[r.role];
        ss[r.role] += res * res;
        sxr[cellOf(champs, r)] += res;
        cn[cellOf(champs, r)] += 1;
    }
    for (0..Role.count) |ri| {
        const lo = ri * champs;
        const sigma2 = ss[ri] / @max(n[ri], 1);
        const prior: analysis.Prior = .estimate(sxr[lo..][0..champs], cn[lo..][0..champs], null, sigma2);
        d.tau[ri] = @sqrt(prior.tau2);
        for (d.b[lo..][0..champs], d.sd[lo..][0..champs], sxr[lo..][0..champs], cn[lo..][0..champs]) |*b, *s, xr, k| {
            b.* = prior.effect(xr, k);
            s.* = if (prior.tau2 > 0 and k > 0) @sqrt(1 / (k / sigma2 + 1 / prior.tau2)) else 0;
        }
    }
    return d;
}

/// A scored block: fit on train games started before `fit_before`, score train games
/// in [lo, hi) (the region's only for dev-val, with one) or the test games; no scoring for `all`
const Block = struct {
    label: []const u8,
    fit_before: i64,
    lo: i64 = 0,
    hi: i64 = 0,
    region_only: bool = false,
    is_test: bool = false,
    scored: bool = true,
};

/// Per minute: rows (train in start order, then test), what each game's index means
const Minute = struct {
    train: std.ArrayList(Row) = .empty,
    tests: std.ArrayList(Row) = .empty,
    truth: []f64 = &.{},
};

const GameInfo = struct { start: i64, platform: u8, excluded: bool = false };

const Job = struct {
    mi: usize,
    bi: usize,
    fit_rows: usize = 0,
    scored: []Row = &.{},
    /// per scored row and model
    loss: [n_models][]f64 = @splat(&.{}),
    sq: [2][]f64 = @splat(&.{}),
    terms: []Term = &.{},
    /// team, roles, full (in game); draft_exp at the draft
    w: [3][]f64 = @splat(&.{}),
    se: [3][]f64 = @splat(&.{}),
    /// sd of each state feature over fit rows
    x_sd: [n_x]f64 = @splat(0),
    decided: Decided = .{},
};

const Ctx = struct {
    gpa: std.mem.Allocator,
    at: *const [n_min]Minute,
    blocks: []const Block,
    games: []const GameInfo,
    region: ?u8,
    champs: usize,
    type_of: []const u8,
    passes: u32,
    jobs: []Job,

    fn one(c: Ctx, i: usize) anyerror!void {
        const j = &c.jobs[i];
        const blk = c.blocks[j.bi];
        const m = &c.at[j.mi];
        const gpa = c.gpa;
        const train = m.train.items;
        var n_fit: usize = 0;
        while (n_fit < train.len and c.games[train[n_fit].game].start < blk.fit_before) n_fit += 1;
        const fit = train[0..n_fit];
        j.fit_rows = n_fit;
        if (fit.len == 0) return error.TooFewGames;
        if (blk.scored) {
            var list: std.ArrayList(Row) = .empty;
            errdefer list.deinit(gpa);
            for (if (blk.is_test) m.tests.items else train) |r| {
                const g = c.games[r.game];
                if (!blk.is_test and (g.start < blk.lo or g.start >= blk.hi)) continue;
                if (blk.region_only) if (c.region) |p| if (g.platform != p) continue;
                try list.append(gpa, r);
            }
            j.scored = try list.toOwnedSlice(gpa);
        }
        const draft = minutes[j.mi] == 0;
        const specs: []const Spec = if (draft) &draft_terms else &game_terms;
        const steps: []const usize = if (draft) &draft_steps else &game_steps;
        const bases: []const Base = if (draft) &.{ .none, .draft_exp } else &.{ .team, .roles, .full };
        const all = !blk.scored;
        for (bases, 0..) |b, k| {
            if (all) j.se[k] = try gpa.alloc(f64, b.dims());
            j.w[k] = try fitBase(gpa, b, fit, if (all) j.se[k] else null);
        }
        if (!draft) for (0..n_x) |xi| {
            var s: f64 = 0;
            var s2: f64 = 0;
            for (fit) |r| {
                s += r.x[xi];
                s2 += r.x[xi] * r.x[xi];
            }
            const n: f64 = @floatFromInt(fit.len);
            j.x_sd[xi] = @sqrt(@max(s2 / n - (s / n) * (s / n), 0));
        };
        const last = bases[bases.len - 1];
        const eta_fit = try baseEta(gpa, last, j.w[bases.len - 1], fit);
        defer gpa.free(eta_fit);
        const base_eta_fit = try gpa.dupe(f64, eta_fit);
        defer gpa.free(base_eta_fit);
        if (!draft) {
            const team_eta = try baseEta(gpa, .team, j.w[0], fit);
            defer gpa.free(team_eta);
            j.decided = try fitDecided(gpa, c.champs, fit, team_eta);
        }

        for (j.loss[0..bases.len], j.w[0..bases.len], bases) |*l, w, b| {
            l.* = try gpa.alloc(f64, j.scored.len);
            for (l.*, j.scored) |*x, r| {
                var v: [max_dims]f64 = undefined;
                b.features(r, v[0..b.dims()]);
                x.* = analysis.logLoss(logreg.sigmoid(dot(v[0..b.dims()], w)), yOf(r));
            }
        }
        const base_score = try baseEta(gpa, last, j.w[bases.len - 1], j.scored);
        defer gpa.free(base_score);
        if (!draft) {
            const team_score = try baseEta(gpa, .team, j.w[0], j.scored);
            defer gpa.free(team_score);
            for (&j.sq) |*s| s.* = try gpa.alloc(f64, j.scored.len);
            for (j.scored, team_score, j.sq[0], j.sq[1]) |r, e, *s0, *s1| {
                const y = decidedOf(e);
                const res = y - j.decided.mean[r.role];
                s0.* = res * res;
                const r1 = res - j.decided.b[cellOf(c.champs, r)];
                s1.* = r1 * r1;
            }
        }

        // nested term fits, each from the base afresh
        for (steps, 0..) |n_terms, si| {
            const terms = try gpa.alloc(Term, n_terms);
            for (terms, specs[0..n_terms]) |*t, spec| t.* = try .init(gpa, spec, c.champs, c.type_of);
            @memcpy(eta_fit, base_eta_fit);
            for (0..c.passes) |_| for (terms) |*t| try t.update(gpa, fit, eta_fit);
            const l = try gpa.alloc(f64, j.scored.len);
            for (l, j.scored, base_score) |*x, r, e0| {
                var e = e0;
                for (terms) |t| e += t.predict(r);
                x.* = analysis.logLoss(logreg.sigmoid(e), yOf(r));
            }
            j.loss[bases.len + si] = l;
            if (si + 1 < steps.len) {
                for (terms) |t| t.deinit(gpa);
                gpa.free(terms);
            } else {
                if (all) for (terms) |*t| try t.bounds(gpa, fit, eta_fit, c.games.len);
                j.terms = terms;
            }
        }
    }
};

/// Redraws every train game's winner at minute index `mi` from the baseline fitted on
/// all train rows plus a planted slope per champion-role (returned, log-odds per unit)
fn plantWinners(gpa: std.mem.Allocator, m: *Minute, draft: bool, champs: usize, p: Plant) ![]f64 {
    const rows = m.train.items;
    const base: Base = if (draft) .none else .full;
    const w = try fitBase(gpa, base, rows, null);
    defer gpa.free(w);
    const eta = try baseEta(gpa, base, w, rows);
    defer gpa.free(eta);
    var prng: std.Random.DefaultPrng = .init(p.seed);
    const rand = prng.random();
    const truth = try gpa.alloc(f64, Role.count * champs);
    for (truth) |*t| t.* = rand.floatNorm(f64) * p.sd / pp / p.cov.unit();
    var i: usize = 0;
    while (i < rows.len) {
        const g = rows[i].game;
        var j = i;
        var logit: f64 = 0;
        var base_set = false;
        while (j < rows.len and rows[j].game == g) : (j += 1) {
            const r = rows[j];
            const sign: f64 = if (r.side == 0) 1 else -1;
            if (r.side == 0 and !base_set) {
                logit += eta[j];
                base_set = true;
            }
            logit += sign * truth[cellOf(champs, r)] * covariate(p.cov, r);
        }
        const blue = rand.float(f64) < logreg.sigmoid(logit);
        for (rows[i..j]) |*r| r.won = (r.side == 0) == blue;
        i = j;
    }
    return truth;
}

const Shown = struct { cell: usize, key: f64 };

fn byKey(_: void, a: Shown, b: Shown) bool {
    return a.key > b.key;
}

pub fn run(
    gpa: std.mem.Allocator,
    io: Io,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    opts: Options,
    w: *Io.Writer,
) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var split = try analysis.heldOut(gpa, db, patches, platforms, opts.test_share, opts.test_platform);
    defer split.deinit();
    var map = try load(gpa, arena, db, patches, platforms);
    defer map.deinit(gpa);
    var exp = try loadExp(gpa, db, platforms);
    defer exp.deinit(gpa);
    const region: ?u8 = if (opts.test_platform) |tp| for (platforms, 0..) |p, i| {
        if (std.mem.eql(u8, p, tp)) break @intCast(i);
    } else return error.Usage else null;

    var champ_index: analysis.DenseIndex = .{};
    defer champ_index.deinit(gpa);
    var games: std.ArrayList(GameInfo) = .empty;
    defer games.deinit(gpa);
    var at: [n_min]Minute = @splat(.{});
    defer for (&at) |*m| {
        m.train.deinit(gpa);
        m.tests.deinit(gpa);
        gpa.free(m.truth);
    };
    var n_games: [2]u32 = @splat(0);
    var exp_known: usize = 0;
    for (split.parts(), [_]bool{ false, true }) |part, is_test| for (part) |g| {
        const gm = map.get(g.id) orelse continue;
        const game: u32 = @intCast(games.items.len);
        try games.append(gpa, .{
            .start = g.start,
            .platform = g.platform,
            .excluded = if (opts.exclude) |e| e.contains(g.id) else false,
        });
        n_games[@intFromBool(is_test)] += 1;
        const earlier: [10]u16 = exp.get(g.id) orelse @splat(0);
        for (0..2) |side| for (0..Role.count) |ri| {
            const champ = try champ_index.get(gpa, g.teams[side][ri]);
            const sign: f32 = if (side == 0) 1 else -1;
            const e = earlier[gm.slot[side][ri]];
            exp_known += @intFromBool(e > 0);
            for (gm.states, &at) |st, *m| {
                const x = st orelse continue;
                var own: [n_x]f32 = undefined;
                for (&own, x) |*o, v| o.* = sign * v;
                try (if (is_test) &m.tests else &m.train).append(gpa, .{
                    .game = game,
                    .side = @intCast(side),
                    .role = @intCast(ri),
                    .champ = champ,
                    .won = g.winner == side,
                    .exp = @floatCast(std.math.log1p(@as(f64, @floatFromInt(e)))),
                    .x = own,
                });
            }
        };
    };
    if (at[0].train.items.len == 0 or at[0].tests.items.len == 0) return error.TooFewGames;
    const champs = champ_index.ids.items.len;
    const type_of = try championTypes(arena, db, champ_index.ids.items);
    const cells = Role.count * champs;

    if (opts.plant) |p| for (&at, minutes) |*m, minute| {
        if ((minute == 0) != (p.cov == .exp)) continue;
        m.truth = try plantWinners(gpa, m, minute == 0, champs, p);
    };

    const c = if (opts.cuts[n_folds] != 0) opts.cuts else labCuts(split.split.cuts);
    var blocks: std.ArrayList(Block) = .empty;
    defer blocks.deinit(gpa);
    for (0..n_folds) |f| try blocks.append(gpa, .{
        .label = try std.fmt.allocPrint(arena, "{d}", .{f + 1}),
        .fit_before = c[f],
        .lo = c[f],
        .hi = c[f + 1],
    });
    try blocks.append(gpa, .{ .label = "dev", .fit_before = c[n_folds], .lo = c[n_folds], .hi = c[n_folds + 1], .region_only = true });
    try blocks.append(gpa, .{ .label = "all", .fit_before = std.math.maxInt(i64), .scored = false });
    if (opts.final) try blocks.append(gpa, .{ .label = "test", .fit_before = std.math.maxInt(i64), .is_test = true });
    const all_block = n_folds + 1;

    const jobs = try gpa.alloc(Job, n_min * blocks.items.len);
    defer gpa.free(jobs);
    for (jobs, 0..) |*j, i| j.* = .{ .mi = i / blocks.items.len, .bi = i % blocks.items.len };
    defer for (jobs) |j| {
        gpa.free(j.scored);
        for (j.loss) |l| gpa.free(l);
        for (j.sq) |s| gpa.free(s);
        for (j.terms) |t| t.deinit(gpa);
        gpa.free(j.terms);
        for (j.w) |x| gpa.free(x);
        for (j.se) |x| gpa.free(x);
        gpa.free(j.decided.b);
        gpa.free(j.decided.sd);
    };
    try par.forEach(io, jobs.len, Ctx{
        .gpa = gpa,
        .at = &at,
        .blocks = blocks.items,
        .games = games.items,
        .region = region,
        .champs = champs,
        .type_of = type_of,
        .passes = opts.passes,
        .jobs = jobs,
    }, Ctx.one);
    const job = struct {
        fn get(js: []Job, n_blocks: usize, mi: usize, bi: usize) *Job {
            return &js[mi * n_blocks + bi];
        }
    }.get;
    const nb = blocks.items.len;

    var name = try db.prepare("SELECT name FROM champions WHERE id = ?");
    defer name.deinit();
    const names = try arena.alloc([]const u8, champs);
    for (names, champ_index.ids.items) |*n, id| {
        try name.bind(.{@as(i64, id)});
        n.* = if (try name.step()) try arena.dupe(u8, name.bytes(0)) else try std.fmt.allocPrint(arena, "#{d}", .{id});
    }

    try w.print("# meiolol carry\n\nTrain: {d} games reaching 15:00, every scanned platform, before " ++
        "{f}; test: {d} {s} games from then{s}. Rows: ten per game and minute while it is going " ++
        "(minute 0: the draft). Earlier games on the champion known (1+) for {d:.1}% of " ++
        "player-games. Blocks: folds 1-5 fit on train games before the block, score every " ++
        "platform's games in it; dev fits before the dev cut and scores dev-val.\n", .{
        n_games[0],                                                Date.fromMs(split.cutoff),                                                                          n_games[1], opts.test_platform orelse "every platform's",
        if (opts.final) " (scored: --final)" else " (not scored)", 100 * @as(f64, @floatFromInt(exp_known)) / @as(f64, @floatFromInt(10 * (n_games[0] + n_games[1]))),
    });
    try w.print("\nCuts (--cuts):", .{});
    for (c, 0..) |x, i| try w.print("{s}{d}", .{ if (i == 0) " " else ",", x });
    try w.writeAll("\n");
    if (opts.plant) |p| try w.print("\nPLANTED: winners redrawn from the state baseline plus a " ++
        "champion-role slope on {t}, sd {d} pp per {s} (seed {d}); real outcomes unused.\n", .{ p.cov, p.sd, p.cov.unitName(), p.seed });

    // Gains: pooled over folds 1-5 (every row once), fold sign count, dev-val
    try w.writeAll("\n## Held-out gains\n\nLog loss of the player's team winning, nats per row; " ++
        "gain = the step's drop in it, ± 95% clustered by game; [k/5]: folds where the step " ++
        "helped. Each step adds to the one above it.\n\n| minute | step | folds 1-5 | [k/5] | dev-val |" ++
        "\n| --- | --- | --- | --- | --- |\n");
    for (minutes, 0..) |minute, mi| {
        const labels: []const []const u8 = if (minute == 0) &draft_models else &game_models;
        // the champion slope step, also by role
        const slope_step: usize = if (minute == 0) 3 else 4;
        for (1..labels.len) |k| {
            const roles: []const ?u8 = if (k == slope_step) &.{ null, 0, 1, 2, 3, 4 } else &.{null};
            for (roles) |role| {
                var sums: analysis.PairedSums = .{};
                var better: usize = 0;
                for (0..n_folds) |f| {
                    const j = job(jobs, nb, mi, f);
                    var one: analysis.PairedSums = .{};
                    addGames(&one, j.scored, j.loss[k - 1], j.loss[k], role);
                    better += @intFromBool(one.gain().mean > 0);
                    addGames(&sums, j.scored, j.loss[k - 1], j.loss[k], role);
                }
                const g = sums.gain();
                const dj = job(jobs, nb, mi, n_folds);
                var dev: analysis.PairedSums = .{};
                addGames(&dev, dj.scored, dj.loss[k - 1], dj.loss[k], role);
                const d = dev.gain();
                try w.print("| {d} | {s}", .{ minute, labels[k] });
                if (role) |r| try w.print(", {t} rows", .{@as(Role, @fromBackingInt(@intCast(r)))});
                try w.print(" | {d:.5} ± {d:.5} | {d}/5 | {d:.5} ± {d:.5} |\n", .{ g.mean, g.half_width, better, d.mean, d.half_width });
            }
        }
        if (minute != 0) {
            var sums: analysis.PairedSums = .{};
            var better: usize = 0;
            for (0..n_folds) |f| {
                const j = job(jobs, nb, mi, f);
                better += @intFromBool(analysis.pairedGain(j.scored, j.sq[0], j.sq[1]).mean > 0);
                addGames(&sums, j.scored, j.sq[0], j.sq[1], null);
            }
            const g = sums.gain();
            const dj = job(jobs, nb, mi, n_folds);
            const d = analysis.pairedGain(dj.scored, dj.sq[0], dj.sq[1]);
            try w.print("| {d} | decided: champion vs role mean (MSE, pp^2) | {d:.3} ± {d:.3} | {d}/5 | {d:.3} ± {d:.3} |\n", .{ minute, g.mean, g.half_width, better, d.mean, d.half_width });
        }
        // The test, then the test minus test-exclude.tsv's games, from the same fits
        if (opts.final) for ([_]?[]const GameInfo{ null, if (opts.exclude != null) games.items else null }, 0..) |skip, pass| {
            if (pass == 1 and skip == null) continue;
            const tj = job(jobs, nb, mi, nb - 1);
            for (1..labels.len) |k| {
                const roles: []const ?u8 = if (k == slope_step) &.{ null, 0, 1, 2, 3, 4 } else &.{null};
                for (roles) |role| {
                    var t: analysis.PairedSums = .{};
                    addKept(&t, tj.scored, tj.loss[k - 1], tj.loss[k], role, skip);
                    const g = t.gain();
                    try w.print("| {d} | TEST{s} {s}", .{ minute, if (pass == 1) " minus test-exclude" else "", labels[k] });
                    if (role) |r| try w.print(", {t} rows", .{@as(Role, @fromBackingInt(@intCast(r)))});
                    try w.print(" | {d:.5} ± {d:.5} | | |\n", .{ g.mean, g.half_width });
                }
            }
        };
    }

    // Whose seat decides: the every-train fit's weights by role
    try w.writeAll("\n## Whose seat decides\n\nEvery train game, team state held fixed: win pp in " ++
        "an even game (log-odds x 25) per unit of each role's lead (own minus lane opponent), " ++
        "± 95% clustered by game; per sd: times the lead's spread at that minute. Gold: the " ++
        "gold-by-role baseline; kills minus deaths and damage share: the full one (beyond gold)." ++
        "\n\n| minute | role | per 1000 gold | per sd of gold lead (sd) | per kill minus death | per 10 points damage share | per sd of damage share |\n| --- | --- | --- | --- | --- | --- | --- |\n");
    for (minutes[1..], 1..) |minute, mi| {
        const j = job(jobs, nb, mi, all_block);
        for (Role.all, 0..) |role, ri| {
            const g = 1 + x_gold + ri;
            const k = 1 + x_kd + ri;
            const d = 1 + x_dmg + ri;
            try w.print("| {d} | {t} | {d:.2} ± {d:.2} | {d:.2} ({d:.2}k) | {d:.2} ± {d:.2} | {d:.2} ± {d:.2} | {d:.2} |\n", .{
                minute,                               role,                         pp * j.w[1][g],                      1.96 * pp * j.se[1][g],
                pp * j.w[1][g] * j.x_sd[x_gold + ri], j.x_sd[x_gold + ri],          pp * j.w[2][k],                      1.96 * pp * j.se[2][k],
                pp * 0.1 * j.w[2][d],                 1.96 * pp * 0.1 * j.se[2][d], pp * j.w[2][d] * j.x_sd[x_dmg + ri],
            });
        }
    }

    // Spreads of champion terms by role and minute
    try w.writeAll("\n## Spread across champions in a role\n\nsd of true effects (shrinkage " ++
        "estimate, cut at 0) [upper 95% bound, analysis.spreadBounds] in win pp per unit, " ++
        "every train game; decided: sd of the champion's shift in pp of distance from a coin flip.\n\n" ++
        "| minute | role | shift | x own gold lead (per 1000) | x kills minus deaths | x damage share (per 10 points) | x experience (per log1p game) | decided |\n" ++
        "| --- | --- | --- | --- | --- | --- | --- | --- |\n");
    for (minutes, 0..) |minute, mi| {
        const j = job(jobs, nb, mi, all_block);
        for (Role.all, 0..) |role, ri| {
            try w.print("| {d} | {t} |", .{ minute, role });
            const order = [_]Cov{ .one, .lane, .kd, .dmg, .exp };
            for (order) |cov| {
                const t = for (j.terms) |*t| {
                    if (t.cov == cov and t.type_of == null) break t;
                } else null;
                if (t) |x| {
                    try w.print(" {d:.2}", .{pp * cov.unit() * x.tau[ri]});
                    if (x.bound[ri]) |b| try w.print(" [{d:.2}]", .{pp * cov.unit() * b});
                    try w.writeAll(" |");
                } else try w.writeAll(" - |");
            }
            if (minute == 0) try w.writeAll(" - |\n") else try w.print(" {d:.2} |\n", .{j.decided.tau[ri]});
        }
    }

    if (opts.plant) |p| {
        try w.print("\n## Planted recovery ({t}, sd {d} pp)\n\nEvery train game's fit against " ++
            "the truth over champion-roles with {d}+ rows: correlation, fitted spread by role.\n\n" ++
            "| minute | correlation | cells | fitted sd by role (pp) |\n| --- | --- | --- | --- |\n", .{ p.cov, p.sd, shown_games });
        for (minutes, 0..) |minute, mi| {
            if (at[mi].truth.len == 0) continue;
            const j = job(jobs, nb, mi, all_block);
            const t = for (j.terms) |*t| {
                if (t.cov == p.cov and t.type_of == null) break t;
            } else continue;
            var sx: f64 = 0;
            var sy: f64 = 0;
            var sxx: f64 = 0;
            var syy: f64 = 0;
            var sxy: f64 = 0;
            var n: f64 = 0;
            for (0..cells) |cell| if (t.n[cell] >= shown_games) {
                const x = t.b[cell];
                const y = at[mi].truth[cell];
                sx += x;
                sy += y;
                sxx += x * x;
                syy += y * y;
                sxy += x * y;
                n += 1;
            };
            const cov_xy = sxy / n - sx / n * sy / n;
            const corr = cov_xy / @sqrt(@max((sxx / n - sx / n * sx / n) * (syy / n - sy / n * sy / n), 1e-30));
            try w.print("| {d} | {d:.2} | {d} |", .{ minute, corr, n });
            for (t.tau) |tau| try w.print(" {d:.2}", .{pp * p.cov.unit() * tau});
            try w.writeAll(" |\n");
        }
    }

    try typeReport(w, jobs, nb, all_block);
    try lessons(w, arena, jobs, nb, all_block, champs, names);
    if (opts.type_table) |path| {
        const f = try Io.Dir.cwd().createFile(io, path, .{});
        defer f.close(io);
        var buf: [16 * 1024]u8 = undefined;
        var fw = f.writer(io, &buf);
        const out = &fw.interface;
        try out.writeAll("minute\trole\ttype\tfit_rows");
        for (game_terms[first_type..]) |spec| try out.print("\t{t}\t{t}_sd", .{ spec.cov, spec.cov });
        try out.writeAll("\n");
        for (minutes[1..], 1..) |minute, mi| {
            const j = job(jobs, nb, mi, all_block);
            const ts = j.terms[first_type..];
            for (0..Role.count * n_types) |cell| {
                if (ts[0].n[cell] == 0) continue;
                try out.print("{d}\t{t}\t{s}\t{d}", .{ minute, @as(Role, @fromBackingInt(@intCast(cell / n_types))), types[cell % n_types], ts[0].n[cell] });
                for (ts) |t| try out.print("\t{d:.3}\t{d:.3}", .{ pp * t.b[cell], pp * t.sd(cell) });
                try out.writeAll("\n");
            }
        }
        try out.flush();
    }

    if (opts.table) |path| {
        const f = try Io.Dir.cwd().createFile(io, path, .{});
        defer f.close(io);
        var buf: [16 * 1024]u8 = undefined;
        var fw = f.writer(io, &buf);
        const out = &fw.interface;
        try out.writeAll("champion\tchampion_id\trole\tminute\tfit_rows\trole_slope\tshift\tshift_sd\tlane\tlane_sd\tlane_raw\tlane_raw_se\tkd\tkd_sd\tdmg\tdmg_sd\texp\texp_sd\tdecided\tdecided_sd\n");
        for (minutes, 0..) |minute, mi| {
            const j = job(jobs, nb, mi, all_block);
            for (0..cells) |cell| {
                const t0 = j.terms[0];
                if (t0.n[cell] == 0) continue;
                const ri = cell / champs;
                try out.print("{s}\t{d}\t{t}\t{d}\t{d}", .{ names[cell % champs], champ_index.ids.items[cell % champs], @as(Role, @fromBackingInt(@intCast(ri))), minute, t0.n[cell] });
                if (minute == 0) try out.print("\t{d:.3}", .{pp * j.w[1][1 + ri]}) else try out.print("\t{d:.3}", .{pp * j.w[2][1 + x_gold + ri]});
                for ([_]Cov{ .one, .lane }) |cov| try termCols(out, j.terms, cov, cell, true);
                for ([_]Cov{ .kd, .dmg, .exp }) |cov| try termCols(out, j.terms, cov, cell, false);
                if (minute == 0) try out.writeAll("\tnan\tnan\n") else try out.print("\t{d:.3}\t{d:.3}\n", .{ j.decided.b[cell], j.decided.sd[cell] });
            }
        }
        try out.flush();
    }

    if (opts.fold_table) |path| {
        const f = try Io.Dir.cwd().createFile(io, path, .{});
        defer f.close(io);
        var buf: [16 * 1024]u8 = undefined;
        var fw = f.writer(io, &buf);
        const out = &fw.interface;
        try out.writeAll("# leverage<m>: win pp per 1000 own gold lead over the lane opponent at minute m, team state held fixed (role slope + shrunk champion term); scaling: champion shift beyond the state at 25 minus at 10 (pp); skill_slope: win pp per log1p earlier games on the champion (role slope + shrunk champion term); each fitted on train games before the fold's block (dev: before the dev cut)\n");
        try out.writeAll("fold\tchampion\trole\trows\tleverage10\tleverage15\tleverage20\tleverage25\tscaling\tskill_slope\n");
        for (blocks.items[0 .. n_folds + 1], 0..) |b, bi| for (0..cells) |cell| {
            const d = job(jobs, nb, 0, bi);
            const rows = d.terms[0].n[cell];
            if (rows == 0) continue;
            const ri = cell / champs;
            try out.print("{s}\t{d}\t{t}\t{d}", .{ b.label, champ_index.ids.items[cell % champs], @as(Role, @fromBackingInt(@intCast(ri))), rows });
            var shift: [n_min]f64 = @splat(std.math.nan(f64));
            for (minutes, 0..) |minute, mi| {
                if (minute == 0 or minute == 30) continue;
                const j = job(jobs, nb, mi, bi);
                if (j.terms[0].n[cell] == 0) {
                    try out.writeAll("\tnan");
                    continue;
                }
                try out.print("\t{d:.3}", .{pp * (j.w[2][1 + x_gold + ri] + j.terms[1].b[cell])});
                shift[mi] = pp * j.terms[0].b[cell];
            }
            try out.print("\t{d:.3}\t{d:.3}\n", .{ shift[mi_of(25)] - shift[mi_of(10)], pp * (d.w[1][1 + ri] + d.terms[1].b[cell]) });
        };
        try out.flush();
    }
}

/// The lab's blocks (harness.Cuts): the 5 fold starts, the dev cut, the test cut
fn labCuts(e: eval.Cuts) [n_folds + 2]i64 {
    var c: [n_folds + 2]i64 = undefined;
    @memcpy(c[0..n_folds], e.bounds[0..n_folds]);
    c[n_folds] = e.dev;
    c[n_folds + 1] = e.test_;
    return c;
}

fn mi_of(minute: u8) usize {
    return std.mem.indexOfScalar(u8, &minutes, minute).?;
}

/// Adds a block's per-game paired sums (rows sorted by game) to pooled sums; with
/// `role`, only that role's rows
fn addGames(s: *analysis.PairedSums, rows: []const Row, before: []const f64, after: []const f64, role: ?u8) void {
    addKept(s, rows, before, after, role, null);
}

/// addGames without the games `skip` marks excluded
fn addKept(s: *analysis.PairedSums, rows: []const Row, before: []const f64, after: []const f64, role: ?u8, skip: ?[]const GameInfo) void {
    var i: usize = 0;
    while (i < rows.len) {
        var d: f64 = 0;
        var n: f64 = 0;
        const g = rows[i].game;
        while (i < rows.len and rows[i].game == g) : (i += 1) {
            if (role) |r| if (rows[i].role != r) continue;
            if (skip) |gs| if (gs[g].excluded) continue;
            d += before[i] - after[i];
            n += 1;
        }
        if (n > 0) s.add(d, n);
    }
}

/// Type x role terms at 15 and 25 from every train game's fit: win pp per unit, beyond
/// the baseline's weight for everyone, ± 95%
fn typeReport(w: *Io.Writer, jobs: []Job, nb: usize, all_block: usize) !void {
    try w.print("\n## Win conditions by champion type ({d}+ rows, every train game)\n\nWin pp " ++
        "in an even game per unit, beyond the baseline's weight for every team (± 95%, ridge " ++
        "1): own gold lead per 1000, team gold lead per 1000, XP lead per 1000, per tower, " ++
        "per dragon, per baron buff held. Type: the champion's first Data Dragon tag.\n", .{shown_games});
    for ([_]u8{ 15, 25 }) |minute| {
        const j = &jobs[mi_of(minute) * nb + all_block];
        const ts = j.terms[first_type..];
        try w.print("\n### Minute {d}\n\n| role | type | rows | own gold | team gold | XP | towers | dragons | baron |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n", .{minute});
        for (Role.all, 0..) |role, ri| for (types, 0..) |name, k| {
            const cell = ri * n_types + k;
            if (ts[0].n[cell] < shown_games) continue;
            try w.print("| {t} | {s} | {d} |", .{ role, name, ts[0].n[cell] });
            for (ts) |t| {
                const b = pp * t.b[cell];
                const h = 1.96 * pp * t.sd(cell);
                try w.print(" {s}{d:.2} ± {d:.2}{s} |", .{ if (b >= 0) "+" else "", b, h, if (@abs(b) > h) " *" else "" });
            }
            try w.writeAll("\n");
        };
    }
}

fn termCols(out: *Io.Writer, terms: []const Term, cov: Cov, cell: usize, raw: bool) !void {
    const t = for (terms) |*t| {
        if (t.cov == cov and t.type_of == null) break t;
    } else {
        try out.writeAll(if (raw and cov == .lane) "\tnan\tnan\tnan\tnan" else "\tnan\tnan");
        return;
    };
    const u = pp * cov.unit();
    try out.print("\t{d:.3}\t{d:.3}", .{ u * t.b[cell], u * t.sd(cell) });
    if (raw and cov == .lane) {
        const se = if (t.sxx[cell] > 0) 1 / @sqrt(t.sxx[cell]) else std.math.inf(f64);
        try out.print("\t{d:.3}\t{d:.3}", .{ u * t.raw[cell], u * se });
    }
}

/// Per role at 15 and 25: champions whose own gold lead counts most and least (role slope
/// + shrunk term, ± 95%), and the most and least decided games
fn lessons(w: *Io.Writer, arena: std.mem.Allocator, jobs: []Job, nb: usize, all_block: usize, champs: usize, names: []const []const u8) !void {
    try w.print("\n## Champions ({d}+ rows, every train game)\n\nLeverage: win pp per 1000 " ++
        "of the champion's own gold lead over its lane opponent, team state held fixed (role " ++
        "slope + shrunk champion term ± 95% of the term); raw: unshrunk ± 95%. Decided: pp " ++
        "further from a coin flip than the role's games.\n", .{shown_games});
    for ([_]u8{ 15, 25 }) |minute| {
        const j = &jobs[mi_of(minute) * nb + all_block];
        const lane = j.terms[1];
        try w.print("\n### Minute {d}\n\n| role | role slope | most leverage | least leverage | most decided | least decided |\n| --- | --- | --- | --- | --- | --- |\n", .{minute});
        for (Role.all, 0..) |role, ri| {
            const base = j.w[2][1 + x_gold + ri];
            var list: std.ArrayList(Shown) = .empty;
            var dec: std.ArrayList(Shown) = .empty;
            for (ri * champs..(ri + 1) * champs) |cell| if (lane.n[cell] >= shown_games) {
                try list.append(arena, .{ .cell = cell, .key = lane.b[cell] });
                try dec.append(arena, .{ .cell = cell, .key = j.decided.b[cell] });
            };
            std.mem.sort(Shown, list.items, {}, byKey);
            std.mem.sort(Shown, dec.items, {}, byKey);
            try w.print("| {t} | {d:.1} |", .{ role, pp * base });
            for ([_]bool{ true, false }) |top| {
                const k = @min(3, list.items.len);
                const pick = if (top) list.items[0..k] else list.items[list.items.len - k ..];
                for (pick, 0..) |s, i| {
                    const se = if (lane.sxx[s.cell] > 0) 1 / @sqrt(lane.sxx[s.cell]) else 0;
                    try w.print("{s}{s} {d:.1} ± {d:.1} (raw {d:.1} ± {d:.1})", .{
                        if (i == 0) " " else ", ",
                        names[s.cell % champs],
                        pp * (base + lane.b[s.cell]),
                        1.96 * pp * lane.sd(s.cell),
                        pp * (base + lane.raw[s.cell]),
                        1.96 * pp * se,
                    });
                }
                try w.writeAll(" |");
            }
            for ([_]bool{ true, false }) |top| {
                const k = @min(3, dec.items.len);
                const pick = if (top) dec.items[0..k] else dec.items[dec.items.len - k ..];
                for (pick, 0..) |s, i| try w.print("{s}{s} {s}{d:.1} ± {d:.1}", .{
                    if (i == 0) " " else ", ", names[s.cell % champs], if (j.decided.b[s.cell] >= 0) "+" else "", j.decided.b[s.cell], 1.96 * j.decided.sd[s.cell],
                });
                try w.writeAll(" |");
            }
            try w.writeAll("\n");
        }
    }
}

const testing = std.testing;

test "planted lane slopes are recovered by the shrunk term" {
    const gpa = testing.allocator;
    const champs = 30;
    const n_games = 6000;
    var prng: std.Random.DefaultPrng = .init(7);
    const rand = prng.random();
    var truth: [Role.count * champs]f64 = undefined;
    for (&truth) |*t| t.* = rand.floatNorm(f64) * 0.3;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(gpa);
    for (0..n_games) |g| {
        var x: [n_x]f32 = @splat(0);
        for (x[x_gold..][0..Role.count]) |*v| v.* = @floatCast(rand.floatNorm(f64));
        var picks: [2][Role.count]u16 = undefined;
        var logit: f64 = 0.4 * (x[0] + x[1] + x[2] + x[3] + x[4]);
        for (0..2) |side| for (0..Role.count) |ri| {
            picks[side][ri] = rand.uintLessThan(u16, champs);
            const sign: f64 = if (side == 0) 1 else -1;
            const own = sign * x[x_gold + ri];
            logit += sign * truth[ri * champs + picks[side][ri]] * own;
        };
        const blue = rand.float(f64) < logreg.sigmoid(logit);
        for (0..2) |side| for (0..Role.count) |ri| {
            const sign: f32 = if (side == 0) 1 else -1;
            var own: [n_x]f32 = undefined;
            for (&own, x) |*o, v| o.* = sign * v;
            try rows.append(gpa, .{ .game = @intCast(g), .side = @intCast(side), .role = @intCast(ri), .champ = picks[side][ri], .won = (side == 0) == blue, .exp = 0, .x = own });
        };
    }
    const wt = try fitBase(gpa, .roles, rows.items, null);
    defer gpa.free(wt);
    {
        // clustered errors match logreg's on the same fit
        const lr = try gpa.alloc(logreg.Row, rows.items.len);
        defer gpa.free(lr);
        const cluster = try gpa.alloc(u32, rows.items.len);
        defer gpa.free(cluster);
        for (lr, cluster, rows.items) |*o, *cl, r| {
            var v: [max_dims]f64 = undefined;
            Base.roles.features(r, v[0..Base.roles.dims()]);
            o.* = .{ .y = yOf(r) };
            for (v[0..Base.roles.dims()], 0..) |x, k| o.add(@intCast(k), x);
            cl.* = r.game;
        }
        const want = try logreg.clusteredStdErrors(gpa, Base.roles.dims(), lr, cluster, wt, 1);
        defer gpa.free(want);
        var got: [max_dims]f64 = undefined;
        try sandwich(.roles, rows.items, wt, got[0..Base.roles.dims()]);
        for (want[0..6], got[0..6]) |a, b| try testing.expectApproxEqRel(a, b, 1e-6);
    }
    const eta = try baseEta(gpa, .roles, wt, rows.items);
    defer gpa.free(eta);
    var t = try Term.init(gpa, .{ .cov = .lane }, champs, &.{});
    defer t.deinit(gpa);
    for (0..8) |_| try t.update(gpa, rows.items, eta);
    var sxy: f64 = 0;
    var sxx: f64 = 0;
    var syy: f64 = 0;
    for (t.b, truth) |b, y| {
        sxy += b * y;
        sxx += b * b;
        syy += y * y;
    }
    try testing.expect(sxy / @sqrt(sxx * syy) > 0.6);
    for (t.tau) |tau| try testing.expect(tau > 0.1 and tau < 0.6);
}

test "solve" {
    var a = [_]f64{ 4, 1, 1, 3 };
    var x = [_]f64{ 1, 2 };
    try solve(&a, 2, &x);
    try testing.expectApproxEqAbs(1.0 / 11.0, x[0], 1e-12);
    try testing.expectApproxEqAbs(7.0 / 11.0, x[1], 1e-12);
}

test "addKept leaves excluded games out of the test sums" {
    const games = [_]GameInfo{ .{ .start = 0, .platform = 0 }, .{ .start = 1, .platform = 0, .excluded = true }, .{ .start = 2, .platform = 0 } };
    var rows: [6]Row = undefined;
    for (&rows, 0..) |*r, i| r.* = .{ .game = @intCast(i / 2), .side = 0, .role = @intCast(i % 2), .champ = 0, .won = true, .exp = 0, .x = @splat(0) };
    const before = [_]f64{ 0.7, 0.6, 0.9, 0.8, 0.5, 0.7 };
    const after = [_]f64{ 0.6, 0.6, 0.5, 0.4, 0.6, 0.5 };
    var all: analysis.PairedSums = .{};
    addGames(&all, &rows, &before, &after, null);
    try testing.expectEqual(3, all.games);
    var kept: analysis.PairedSums = .{};
    addKept(&kept, &rows, &before, &after, null, &games);
    try testing.expectEqual(2, kept.games);
    try testing.expectEqual(4, kept.rows);
    try testing.expectApproxEqAbs(0.1 + 0.0 - 0.1 + 0.2, kept.total, 1e-12);
}
