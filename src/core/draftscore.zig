//! The draft model tester's scorer (docs/model.md "Draft model file"): exported
//! parameters in, blue's win chance out. std only, so the backend, the lab and ui.wasm
//! (the private Draft tester) score with the same code. draftfile.zig writes the files

const std = @import("std");

pub const n_role = 5;
pub const z95 = 1.96;

fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

/// A champion-role's key in Scorer.terms (draftfile.Champions' too)
pub fn termKey(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

/// A champion-role's exported parameters: cand.Term, and p from a comp candidate
pub const Term = struct {
    champion: u32,
    role: u8,
    games: u32,
    b: f32,
    sd: f32,
    u: []const f32 = &.{},
    v: []const f32 = &.{},
    s: []const f32 = &.{},
    /// Profile, z-scored within the role; empty without comp terms
    p: []const f32 = &.{},
    /// The profile in raw units, every stat of win-comp's Feature order (raw_len), for
    /// team terms; empty without them
    raw: []const f32 = &.{},
};

pub const Stat = struct { name: []const u8, label: []const u8 };

/// Nonlinear within-team term on f, the team's damage-weighted magic share
/// (sum raw.dmg * raw.magic / sum raw.dmg over the five slots, 0.5 without damage):
/// mix w (f - centre)^2, ad_heavy w min(f - centre, 0)^2, ap_heavy w max(f - centre, 0)^2.
/// Blue's logit adds the term of blue's team minus red's; sd 0 when not exported
pub const TeamTerm = struct { kind: []const u8, stat: u32, centre: f32 = 0, weight: f32, sd: f32 = 0 };

pub const TeamKind = enum { mix, ad_heavy, ap_heavy };

/// win-comp's Feature order: magic share of damage first, damage per minute third
pub const raw_len = 12;
pub const raw_magic = 0;
pub const raw_dmg = 2;

pub fn magicShare(sl: *const [n_role]Slot) f64 {
    var num: f64 = 0;
    var den: f64 = 0;
    for (sl) |x| {
        num += @as(f64, x.raw[raw_dmg]) * x.raw[raw_magic];
        den += x.raw[raw_dmg];
    }
    return if (den > 0) num / den else 0.5;
}

pub fn teamForm(kind: TeamKind, f: f64, centre: f64) f64 {
    const d = f - centre;
    return switch (kind) {
        .mix => d * d,
        .ad_heavy => @min(d, 0) * @min(d, 0),
        .ap_heavy => @max(d, 0) * @max(d, 0),
    };
}

/// Comp terms on team-summed profiles P: P_b'S P_b - P_r'S P_r + P_b'A P_r
pub const Comp = struct {
    stats: []const Stat,
    /// k x k row-major: S symmetric (within team), A antisymmetric (blue x red)
    S: []const f32,
    A: []const f32,
    /// Laplace sd of each entry, same layout
    S_sd: []const f32,
    A_sd: []const f32,
    team: []const TeamTerm = &.{},
    /// Profile prior per role (5 x k), already inside every b: shown, not scored
    beta: []const f32 = &.{},
};

pub const max_k = 64;
/// Factor length a file may ask for; vecs are 3 * dim
pub const max_dim = 1024;

/// The candidate's exported model as the scorer reads it (cand.Export, and comp if any)
pub const Params = struct {
    kind: []const u8,
    dim: u32,
    /// Blue side's intercept by platform index
    intercept: []const f32,
    w: [25]f32,
    z: [25]f32,
    terms: []const Term,
    comp: ?Comp = null,
    pairs: ?Pairs = null,
    /// Multiplies the whole logit (and the interval's half-width)
    temperature: f64 = 1,
};

/// Pair cells (the additive model's, src/additive.zig v2, and the shipped model's duos and
/// matchups, draftmodel.zig): one cell per pair of champions,
/// allies in roles r < q, or a matchup of blue's role r against red's role q (r <= q; red's
/// r against blue's q is the same cell negated; a same-role matchup one cell per unordered
/// pair, a < b, for a facing b). Cells on fewer than min_games fit games are left out (0)
pub const Pairs = struct {
    min_games: u32,
    groups: []const PairGroup,
    cells: []const PairCell,
};

pub const PairGroup = struct {
    name: []const u8,
    /// "ally" or "matchup"
    kind: []const u8,
    r: u8,
    q: u8,
    /// The block's sd (logit): the spread of true effects of this kind of pair
    sd: f32,
    /// Cells in the fit, and in the export
    fitted: u32,
    shipped: u32,
};

/// Written as [group, a, b, theta, games]: most of the file
pub const PairCell = struct {
    /// Index into Pairs.groups
    group: u32,
    a: u32,
    b: u32,
    theta: f64,
    games: u32,

    pub fn jsonStringify(c: *const PairCell, jw: anytype) !void {
        try jw.beginArray();
        try jw.write(c.group);
        try jw.write(c.a);
        try jw.write(c.b);
        try jw.write(c.theta);
        try jw.write(c.games);
        try jw.endArray();
    }

    pub fn jsonParse(a: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !PairCell {
        const t = try std.json.innerParse(struct { u32, u32, u32, f64, u32 }, a, source, options);
        return .{ .group = t[0], .a = t[1], .b = t[2], .theta = t[3], .games = t[4] };
    }
};

pub fn pairKey(group: usize, a: u32, b: u32) u64 {
    return @as(u64, group) << 48 | @as(u64, a) << 24 | b;
}

/// One slot's parameters: a champion-role's term, or its role's average pick (sd 0)
pub const Slot = struct {
    b: f64,
    sd: f64,
    u: []const f32,
    v: []const f32,
    s: []const f32,
    p: []const f32,
    raw: []const f32,
};

/// The reference scorer (docs/model.md "Draft model file"), from exported parameters only
pub const Scorer = struct {
    e: Params,
    platform: u8,
    terms: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    average: [n_role]Slot,
    /// Profile length, 0 without comp terms
    k: usize = 0,
    /// comp.team's kinds, parsed
    kinds: []const TeamKind = &.{},
    /// Index into pairs.cells by pairKey
    cells: std.AutoHashMapUnmanaged(u64, u32) = .empty,

    /// champs: patchShare(champion, role) f64, the role averages' weights
    pub fn init(arena: std.mem.Allocator, e: Params, platform: u8, champs: anytype) !Scorer {
        var sc: Scorer = .{ .e = e, .platform = platform, .average = undefined };
        // Parameters can come from a downloaded file (ui.wasm): every index and length
        // the scoring loops rely on is checked here
        if (platform >= e.intercept.len) return error.NoIntercept;
        if (e.dim > max_dim) return error.BadTerm;
        for (e.terms) |t| {
            if (t.role >= n_role or t.u.len != e.dim or t.v.len != e.dim) return error.BadTerm;
            if (t.s.len != e.dim and t.s.len != 0) return error.BadTerm;
        }
        if (e.comp) |c| {
            sc.k = c.stats.len;
            if (sc.k > max_k or c.S.len != sc.k * sc.k or c.A.len != sc.k * sc.k) return error.BadCompShape;
            for (e.terms) |t| if (t.p.len != sc.k) return error.BadCompShape;
            const kinds = try arena.alloc(TeamKind, c.team.len);
            for (kinds, c.team) |*kd, t| kd.* = std.meta.stringToEnum(TeamKind, t.kind) orelse return error.UnknownTeamTerm;
            sc.kinds = kinds;
            if (kinds.len > 0) for (e.terms) |t| if (t.raw.len != raw_len) return error.BadCompShape;
        } else for (e.terms) |t| if (t.p.len != 0) return error.BadCompShape;
        if (e.pairs) |pr| {
            for (pr.groups) |g| if (g.r >= n_role or g.q >= n_role or (!std.mem.eql(u8, g.kind, "ally") and !std.mem.eql(u8, g.kind, "matchup"))) return error.BadPairGroup;
            for (pr.cells, 0..) |c, i| {
                if (c.group >= pr.groups.len) return error.BadPairGroup;
                try sc.cells.put(arena, pairKey(c.group, c.a, c.b), @intCast(i));
            }
        }
        const n_raw: usize = if (sc.kinds.len > 0) raw_len else 0;
        for (e.terms, 0..) |t, i| try sc.terms.put(arena, termKey(t.champion, t.role), @intCast(i));
        // Role average: play-rate-weighted mean of b and the vectors on the newest patch
        for (&sc.average, 0..) |*avg, r| {
            const vecs = try arena.alloc(f32, 3 * e.dim + sc.k + n_raw);
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
                if (t.s.len > 0) for (vecs[2 * e.dim .. 3 * e.dim], t.s) |*x, y| {
                    x.* += @floatCast(share * y);
                };
                for (vecs[3 * e.dim ..][0..sc.k], t.p) |*x, y| x.* += @floatCast(share * y);
                for (vecs[3 * e.dim + sc.k ..], t.raw[0..n_raw]) |*x, y| x.* += @floatCast(share * y);
            }
            const inv = if (total > 0) 1 / total else 0;
            for (vecs) |*x| x.* = @floatCast(x.* * inv);
            avg.* = .{
                .b = b * inv,
                .sd = 0,
                .u = vecs[0..e.dim],
                .v = vecs[e.dim .. 2 * e.dim],
                .s = if (std.mem.eql(u8, e.kind, "full")) vecs[2 * e.dim .. 3 * e.dim] else &.{},
                .p = vecs[3 * e.dim ..][0..sc.k],
                .raw = vecs[3 * e.dim + sc.k ..],
            };
        }
        return sc;
    }

    pub fn slot(sc: *const Scorer, champion: u32, role: usize) Slot {
        const i = sc.terms.get(termKey(champion, role)) orelse return sc.average[role];
        const t = sc.e.terms[i];
        return .{ .b = t.b, .sd = t.sd, .u = t.u, .v = t.v, .s = t.s, .p = t.p, .raw = t.raw };
    }

    fn dot(a: []const f32, b: []const f32) f64 {
        if (a.len == 0 or b.len == 0) return 0;
        var s: f64 = 0;
        for (a, b) |x, y| s += @as(f64, x) * y;
        return s;
    }

    /// Blue's win chance and 95% interval; 0 is an empty slot
    pub fn blue(sc: *const Scorer, teams: [2][n_role]u32) Chance {
        const x = sc.logit(teams);
        const t = sc.e.temperature;
        return .{ .p = sigmoid(t * x.l), .lo = sigmoid(t * (x.l - x.half)), .hi = sigmoid(t * (x.l + x.half)) };
    }

    /// Blue's logit before the temperature, and its 95% half-width
    fn logit(sc: *const Scorer, teams: [2][n_role]u32) struct { l: f64, half: f64 } {
        var sl: [2][n_role]Slot = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            sl[side][r] = sc.slot(teams[side][r], r);
        };
        var l: f64 = sc.e.intercept[sc.platform] + sc.compLogit(&sl) + sc.pairLogit(teams);
        var v: f64 = 0;
        for (0..n_role) |r| {
            l += sl[0][r].b - sl[1][r].b;
            v += sl[0][r].sd * sl[0][r].sd + sl[1][r].sd * sl[1][r].sd;
        }
        for (0..n_role) |ri| for (0..n_role) |rj| {
            const w = sc.e.w[ri * n_role + rj];
            if (w != 0) l += w * (dot(sl[0][ri].u, sl[1][rj].v) - dot(sl[1][ri].u, sl[0][rj].v));
            const z = sc.e.z[ri * n_role + rj];
            if (z != 0 and ri < rj) l += z * (dot(sl[0][ri].s, sl[0][rj].s) - dot(sl[1][ri].s, sl[1][rj].s));
        };
        return .{ .l = l, .half = z95 * @sqrt(v) };
    }

    /// The comp terms' part of blue's logit, 0 without them
    pub fn compLogit(sc: *const Scorer, sl: *const [2][n_role]Slot) f64 {
        const c = sc.e.comp orelse return 0;
        const k = sc.k;
        var P: [2][max_k]f64 = @splat(@splat(0));
        for (0..2) |side| for (sl[side]) |x| for (P[side][0..k], x.p) |*y, q| {
            y.* += q;
        };
        var out: f64 = 0;
        for (0..k) |i| for (0..k) |j| {
            out += c.S[i * k + j] * (P[0][i] * P[0][j] - P[1][i] * P[1][j]);
            out += c.A[i * k + j] * P[0][i] * P[1][j];
        };
        if (sc.kinds.len > 0) {
            const f = [2]f64{ magicShare(&sl[0]), magicShare(&sl[1]) };
            for (c.team, sc.kinds) |t, kind| out += t.weight * (teamForm(kind, f[0], t.centre) - teamForm(kind, f[1], t.centre));
        }
        return out;
    }

    /// The pair cells' part of blue's logit, 0 without them; an empty slot touches no cell
    /// (the prior mean)
    pub fn pairLogit(sc: *const Scorer, t: [2][n_role]u32) f64 {
        const pr = sc.e.pairs orelse return 0;
        var out: f64 = 0;
        for (pr.groups, 0..) |g, gi| {
            const r = g.r;
            const q = g.q;
            if (std.mem.eql(u8, g.kind, "ally")) {
                out += sc.cell(gi, t[0][r], t[0][q]) - sc.cell(gi, t[1][r], t[1][q]);
            } else if (r != q) {
                out += sc.cell(gi, t[0][r], t[1][q]) - sc.cell(gi, t[1][r], t[0][q]);
            } else {
                const a = t[0][r];
                const b = t[1][r];
                if (a == b) continue;
                const x = sc.cell(gi, @min(a, b), @max(a, b));
                out += if (a < b) x else -x;
            }
        }
        return out;
    }

    pub fn cell(sc: *const Scorer, group: usize, a: u32, b: u32) f64 {
        const c = sc.cellOf(group, a, b) orelse return 0;
        return c.theta;
    }

    pub fn cellOf(sc: *const Scorer, group: usize, a: u32, b: u32) ?PairCell {
        if (a == 0 or b == 0) return null;
        const pr = sc.e.pairs orelse return null;
        const i = sc.cells.get(pairKey(group, a, b)) orelse return null;
        return pr.cells[i];
    }

    /// The comp part for whole teams, by side (0 blue) and role
    pub fn compOf(sc: *const Scorer, teams: [2][n_role]u32) f64 {
        var sl: [2][n_role]Slot = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            sl[side][r] = sc.slot(teams[side][r], r);
        };
        return sc.compLogit(&sl);
    }

    /// The change `id` in seat (side, r) makes to its side's chance over the role's average
    /// pick, split into the parts that test as real (docs/learned.md "Win"): its strength,
    /// the bot duo, the lane matchup, bot against support. Every other part (other pairs,
    /// factor and comp terms) is the rest. Parts are logit terms times the secant slope
    /// over the whole change, so parts and rest sum to the change exactly
    pub fn why(sc: *const Scorer, teams: [2][n_role]u32, side: u1, r: usize, id: u32) Why {
        var t = teams;
        t[side][r] = 0;
        const c0 = sc.blue(t);
        const x0 = sc.logit(t).l;
        t[side][r] = id;
        const c1 = sc.blue(t);
        const x1 = sc.logit(t).l;
        var w: Why = .{ .empty = if (side == 0) c0 else c0.flip(), .with = if (side == 0) c1 else c1.flip() };
        const d = w.with.p - w.empty.p;
        const temp = sc.e.temperature;
        // The side's logit moves by dl; no @log (its table costs ui.wasm 4 KB)
        const dl = temp * (if (side == 0) x1 - x0 else x0 - x1);
        const slope = if (@abs(dl) > 1e-9) d / dl else w.with.p * (1 - w.with.p);
        const k = 100 * slope * temp;
        const games = if (sc.terms.get(termKey(id, r))) |i| sc.e.terms[i].games else 0;
        w.add(.{ .kind = .base, .other = id, .role = @intCast(r), .pp = k * (sc.slot(id, r).b - sc.average[r].b), .games = games });
        const mine = t[side];
        const theirs = t[1 - side];
        if (sc.e.pairs) |pr| for (pr.groups, 0..) |g, gi| {
            if (g.r != r and g.q != r) continue;
            const ally = std.mem.eql(u8, g.kind, "ally");
            const bot = g.r != g.q and g.r >= 3 and g.q >= 3;
            if (!bot and (ally or g.r != g.q)) continue;
            const o: u8 = if (g.r == r) g.q else g.r;
            var sign: f64 = 1;
            const c = if (ally)
                (if (g.r == r) sc.cellOf(gi, id, mine[o]) else sc.cellOf(gi, mine[o], id))
            else if (g.r != g.q)
                (if (g.r == r) sc.cellOf(gi, id, theirs[o]) else blk: {
                    sign = -1;
                    break :blk sc.cellOf(gi, theirs[o], id);
                })
            else blk: {
                const e = theirs[o];
                if (e == id) continue;
                if (e < id) sign = -1;
                break :blk sc.cellOf(gi, @min(id, e), @max(id, e));
            };
            const x = c orelse continue;
            w.add(.{ .kind = if (ally) .ally else .enemy, .other = if (ally) mine[o] else theirs[o], .role = o, .pp = k * sign * x.theta, .games = x.games });
        };
        w.rest = 100 * d;
        for (w.parts()) |x| w.rest -= x.pp;
        return w;
    }
};

/// A named part's kind: the pick's own strength, a duo, a matchup (core.score's, so the
/// tester and Daily word them alike)
pub const Kind = @import("score.zig").Reason.Kind;

pub const Part = struct {
    kind: Kind,
    /// The other champion; the pick itself for base
    other: u32,
    /// The other champion's role
    role: u8,
    /// Points of the pick's side's win chance
    pp: f64,
    /// The champion-role's games for base, the pair cell's otherwise
    games: u32,
};

pub const max_parts = 6;

pub const Why = struct {
    /// The side's chance with the role's average pick in the seat, and with the pick
    empty: Chance,
    with: Chance,
    buf: [max_parts]Part = undefined,
    n: u8 = 0,
    /// Every part not named, points
    rest: f64 = 0,

    fn add(w: *Why, p: Part) void {
        if (w.n == max_parts) return;
        w.buf[w.n] = p;
        w.n += 1;
    }

    pub fn parts(w: *const Why) []const Part {
        return w.buf[0..w.n];
    }

    /// Points over the role's average pick: the parts and the rest
    pub fn total(w: *const Why) f64 {
        return 100 * (w.with.p - w.empty.p);
    }

    /// What the draft adds: the total less the pick's own strength
    pub fn fit(w: *const Why) f64 {
        var f = w.total();
        for (w.parts()) |x| if (x.kind == .base) {
            f -= x.pp;
        };
        return f;
    }
};

pub const Chance = struct {
    p: f64,
    lo: f64,
    hi: f64,

    /// The other side's view
    pub fn flip(c: Chance) Chance {
        return .{ .p = 1 - c.p, .lo = 1 - c.hi, .hi = 1 - c.lo };
    }
};

test "scorer: parameters a file got wrong are refused, not indexed" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const None = struct {
        fn patchShare(_: *const @This(), _: u32, _: usize) f64 {
            return 1;
        }
    };
    const one = [_]f32{0};
    const base: Params = .{ .kind = "ratings", .dim = 0, .intercept = &one, .w = @splat(0), .z = @splat(0), .terms = &.{} };
    try std.testing.expectError(error.NoIntercept, Scorer.init(a, base, 1, &None{}));
    var p = base;
    p.terms = &.{.{ .champion = 1, .role = 5, .games = 1, .b = 0, .sd = 0 }};
    try std.testing.expectError(error.BadTerm, Scorer.init(a, p, 0, &None{}));
    p.dim = 1;
    p.terms = &.{.{ .champion = 1, .role = 0, .games = 1, .b = 0, .sd = 0, .u = &one }};
    try std.testing.expectError(error.BadTerm, Scorer.init(a, p, 0, &None{}));
    p.terms = &.{.{ .champion = 1, .role = 0, .games = 1, .b = 0, .sd = 0, .u = &one, .v = &one }};
    _ = try Scorer.init(a, p, 0, &None{});
    p.pairs = .{ .min_games = 0, .groups = &.{}, .cells = &.{.{ .group = 0, .a = 1, .b = 2, .theta = 0, .games = 1 }} };
    try std.testing.expectError(error.BadPairGroup, Scorer.init(a, p, 0, &None{}));
    p.pairs = null;
    // A profile without comp terms to read it with
    p.terms = &.{.{ .champion = 1, .role = 0, .games = 1, .b = 0, .sd = 0, .u = &one, .v = &one, .p = &one }};
    try std.testing.expectError(error.BadCompShape, Scorer.init(a, p, 0, &None{}));
    p.dim = max_dim + 1;
    p.terms = &.{};
    try std.testing.expectError(error.BadTerm, Scorer.init(a, p, 0, &None{}));
    p.dim = 0;
    const stats = [_]Stat{.{ .name = "magic", .label = "Magic" }};
    p.comp = .{ .stats = &stats, .S = &.{}, .A = &one, .S_sd = &.{}, .A_sd = &.{} };
    try std.testing.expectError(error.BadCompShape, Scorer.init(a, p, 0, &None{}));
    p.comp = .{ .stats = &stats, .S = &one, .A = &one, .S_sd = &.{}, .A_sd = &.{}, .team = &.{.{ .kind = "balanced", .stat = 0, .weight = 1 }} };
    try std.testing.expectError(error.UnknownTeamTerm, Scorer.init(a, p, 0, &None{}));
}

test "why: strength, bot duo, lane and bot-support matchups named, the rest summed, all adding up" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const Even = struct {
        fn patchShare(_: *const @This(), _: u32, _: usize) f64 {
            return 1;
        }
    };
    const t = struct {
        fn term(c: u32, r: u8, b: f32) Term {
            return .{ .champion = c, .role = r, .games = 100 * c, .b = b, .sd = 0.05 };
        }
    }.term;
    const terms = [_]Term{ t(10, 0, 0.1), t(11, 0, -0.1), t(20, 2, 0.2), t(21, 2, 0), t(30, 3, 0.3), t(31, 3, -0.3), t(40, 4, 0), t(41, 4, 0.2) };
    const g = struct {
        fn group(kind: []const u8, r: u8, q: u8) PairGroup {
            return .{ .name = "", .kind = kind, .r = r, .q = q, .sd = 0.1, .fitted = 1, .shipped = 1 };
        }
    }.group;
    const groups = [_]PairGroup{ g("ally", 3, 4), g("ally", 0, 1), g("matchup", 2, 2), g("matchup", 3, 4), g("matchup", 0, 2) };
    const cells = [_]PairCell{
        .{ .group = 0, .a = 30, .b = 40, .theta = 0.5, .games = 900 },
        .{ .group = 2, .a = 20, .b = 21, .theta = 0.4, .games = 800 },
        .{ .group = 3, .a = 30, .b = 41, .theta = 0.2, .games = 700 },
        .{ .group = 4, .a = 10, .b = 21, .theta = 0.3, .games = 600 },
    };
    const p: Params = .{ .kind = "ratings", .dim = 0, .intercept = &.{0.02}, .w = @splat(0), .z = @splat(0), .terms = &terms, .pairs = .{ .min_games = 0, .groups = &groups, .cells = &cells }, .temperature = 0.9 };
    const sc = try Scorer.init(a, p, 0, &Even{});
    const teams: [2][n_role]u32 = .{ .{ 10, 0, 20, 30, 40 }, .{ 0, 0, 21, 31, 41 } };
    const eps = 1e-9;
    for (0..2) |side| for (0..n_role) |r| {
        const id = teams[side][r];
        if (id == 0) continue;
        const w = sc.why(teams, @intCast(side), r, id);
        var sum = w.rest;
        for (w.parts()) |x| sum += x.pp;
        try std.testing.expectApproxEqAbs(w.total(), sum, eps);
        try std.testing.expectEqual(Kind.base, w.parts()[0].kind);
        try std.testing.expectEqual(100 * id, w.parts()[0].games);
    };
    // Blue mid: strength and the lane, nothing left over (no factors, no comp)
    var w = sc.why(teams, 0, 2, 20);
    try std.testing.expectEqual(2, w.n);
    try std.testing.expectEqual(Part{ .kind = .enemy, .other = 21, .role = 2, .pp = w.parts()[1].pp, .games = 800 }, w.parts()[1]);
    try std.testing.expect(w.parts()[1].pp > 0);
    try std.testing.expectApproxEqAbs(0, w.rest, eps);
    // Red's view of the same lane: hurt by it
    w = sc.why(teams, 1, 2, 21);
    try std.testing.expect(w.parts()[1].pp < 0);
    // Blue top: top against their mid isn't named, so it is all rest
    w = sc.why(teams, 0, 0, 10);
    try std.testing.expectEqual(1, w.n);
    try std.testing.expect(w.rest > 0);
    // Blue support: the duo with its bot; red's support isn't its matchup
    w = sc.why(teams, 0, 4, 40);
    try std.testing.expectEqual(2, w.n);
    try std.testing.expectEqual(Kind.ally, w.parts()[1].kind);
    try std.testing.expectEqual(30, w.parts()[1].other);
    // Red support: into blue's bot, a loss; Fit leaves its strength out
    w = sc.why(teams, 1, 4, 41);
    try std.testing.expectEqual(2, w.n);
    try std.testing.expectEqual(Kind.enemy, w.parts()[1].kind);
    try std.testing.expectEqual(30, w.parts()[1].other);
    try std.testing.expect(w.parts()[1].pp < 0);
    try std.testing.expectApproxEqAbs(w.total() - w.parts()[0].pp, w.fit(), eps);
    // An empty seat's average: no change, nothing named but its zero strength
    w = sc.why(teams, 1, 0, 0);
    try std.testing.expectApproxEqAbs(0, w.total(), eps);
}
