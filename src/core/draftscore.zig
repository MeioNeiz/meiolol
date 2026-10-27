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
    /// pairs.cells by pairKey
    cells: std.AutoHashMapUnmanaged(u64, f64) = .empty,

    /// champs: patchShare(champion, role) f64, the role averages' weights
    pub fn init(arena: std.mem.Allocator, e: Params, platform: u8, champs: anytype) !Scorer {
        var sc: Scorer = .{ .e = e, .platform = platform, .average = undefined };
        // Parameters can come from a downloaded file (ui.wasm): every index and length
        // the scoring loops rely on is checked here
        if (platform >= e.intercept.len) return error.NoIntercept;
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
        }
        if (e.pairs) |pr| {
            for (pr.groups) |g| if (g.r >= n_role or g.q >= n_role or (!std.mem.eql(u8, g.kind, "ally") and !std.mem.eql(u8, g.kind, "matchup"))) return error.BadPairGroup;
            for (pr.cells) |c| {
                if (c.group >= pr.groups.len) return error.BadPairGroup;
                try sc.cells.put(arena, pairKey(c.group, c.a, c.b), c.theta);
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
        var sl: [2][n_role]Slot = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            sl[side][r] = sc.slot(teams[side][r], r);
        };
        var logit: f64 = sc.e.intercept[sc.platform] + sc.compLogit(&sl) + sc.pairLogit(teams);
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
        const t = sc.e.temperature;
        const half = z95 * @sqrt(v);
        return .{ .p = sigmoid(t * logit), .lo = sigmoid(t * (logit - half)), .hi = sigmoid(t * (logit + half)) };
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
        if (a == 0 or b == 0) return 0;
        return sc.cells.get(pairKey(group, a, b)) orelse 0;
    }

    /// The comp part for whole teams, by side (0 blue) and role
    pub fn compOf(sc: *const Scorer, teams: [2][n_role]u32) f64 {
        var sl: [2][n_role]Slot = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            sl[side][r] = sc.slot(teams[side][r], r);
        };
        return sc.compLogit(&sl);
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
}
