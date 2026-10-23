//! The admin Draft tester's model file (docs/model.md "Draft model file"): its shapes,
//! the reference scorer the page's JS must match, and the writer of draft-model.json and
//! draft-ref.json. Shared by `meiolol-lab draft --export` (lab/draft.zig) and the box's
//! `meiolol draft-model` (draftmodel.zig). An empty slot counts as its role's average pick
//! on the share patch (Champions.countShares).

const std = @import("std");

const Io = std.Io;

pub const n_role = 5;
pub const default_min_games = 100;
pub const z95 = 1.96;
/// Play shares come from the newest patch with this many games (every platform): a patch's
/// first hours hold a few thousand, too few for the picker's 1%-of-the-role cut
pub const min_share_games = 20_000;

pub const Champions = struct {
    names: std.AutoHashMapUnmanaged(u32, []const u8) = .empty,
    /// Training games per champion and role, every patch
    games: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    /// Games per champion and role on the share patch, and that patch's games
    patch_games: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    /// Two a game (each role twice)
    patch_total: u32 = 0,
    /// Share patch (stats.patchKey)
    patch: u32 = 0,
    /// Training games' patches
    oldest_patch: u32 = 0,
    newest_patch: u32 = 0,

    pub fn key(champion: u32, role: usize) u64 {
        return (@as(u64, champion) << 3) | role;
    }

    pub fn gamesIn(c: *const Champions, champion: u32, role: usize) u32 {
        return c.games.get(key(champion, role)) orelse 0;
    }

    pub fn patchShare(c: *const Champions, champion: u32, role: usize) f64 {
        const n = c.patch_games.get(key(champion, role)) orelse 0;
        return @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(@max(c.patch_total, 1)));
    }

    /// Training patches and play shares from `games` (each with .patch, a stats.patchKey,
    /// and .teams by side and role): shares from the newest patch with min_share_games,
    /// else the newest
    pub fn countShares(c: *Champions, arena: std.mem.Allocator, games: anytype) !void {
        var per: std.AutoArrayHashMapUnmanaged(u32, u32) = .empty;
        for (games) |g| {
            const e = try per.getOrPut(arena, g.patch);
            if (!e.found_existing) e.value_ptr.* = 0;
            e.value_ptr.* += 1;
        }
        var full: u32 = 0;
        for (per.keys(), per.values()) |p, n| {
            c.oldest_patch = if (c.oldest_patch == 0) p else @min(c.oldest_patch, p);
            c.newest_patch = @max(c.newest_patch, p);
            if (n >= min_share_games) full = @max(full, p);
        }
        c.patch = if (full != 0) full else c.newest_patch;
        for (games) |g| {
            if (g.patch != c.patch) continue;
            c.patch_total += 2;
            for (g.teams) |t| for (t, 0..) |ch, r| {
                const e = try c.patch_games.getOrPut(arena, key(ch, r));
                if (!e.found_existing) e.value_ptr.* = 0;
                e.value_ptr.* += 1;
            };
        }
    }

    pub fn name(c: *const Champions, champion: u32) []const u8 {
        return c.names.get(champion) orelse "?";
    }

    /// Case, spaces and punctuation ignored; a unique prefix will do
    pub fn find(c: *const Champions, text: []const u8) ?u32 {
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

    pub fn fold(buf: []u8, s: []const u8) []const u8 {
        var n: usize = 0;
        for (s) |ch| if (std.ascii.isAlphanumeric(ch) and n < buf.len) {
            buf[n] = std.ascii.toLower(ch);
            n += 1;
        };
        return buf[0..n];
    }
};

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

    pub fn init(arena: std.mem.Allocator, e: Params, platform: u8, champs: *const Champions) !Scorer {
        var sc: Scorer = .{ .e = e, .platform = platform, .average = undefined };
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
        for (e.terms, 0..) |t, i| try sc.terms.put(arena, Champions.key(t.champion, t.role), @intCast(i));
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
                for (vecs[2 * e.dim .. 3 * e.dim], t.s) |*x, y| x.* += @floatCast(share * y);
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
        const i = sc.terms.get(Champions.key(champion, role)) orelse return sc.average[role];
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

pub fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

pub const Draft = struct {
    role: usize,
    side: u1 = 0,
    /// By "mine" (0) and "theirs" and role; 0 open
    teams: [2][n_role]u32 = @splat(@splat(0)),
    bans: []const u32 = &.{},
    top: usize = 10,
    min_games: u32 = default_min_games,

    /// By game side, 0 blue
    pub fn bySide(d: *const Draft) [2][n_role]u32 {
        var t: [2][n_role]u32 = undefined;
        t[d.side] = d.teams[0];
        t[1 - d.side] = d.teams[1];
        return t;
    }
};

pub const Option = struct {
    champion: u32,
    games: u32,
    /// The user's team's chance with this champion in the slot
    win: f64,
    lo: f64,
    hi: f64,
    /// win minus the chance with the slot empty (its role's average pick)
    change: f64,
};

pub const Ranking = struct {
    options: []Option,
    /// Play-count-weighted mean of the options' chances
    average: f64,
    empty: f64,
};

pub fn rank(arena: std.mem.Allocator, sc: *const Scorer, champs: *const Champions, d: *const Draft) !Ranking {
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

pub fn mine(blue: Chance, side: u1) Chance {
    return if (side == 0) blue else blue.flip();
}

pub fn taken(d: *const Draft, champion: u32) bool {
    for (d.teams) |t| for (t) |c| if (c == champion) return true;
    for (d.bans) |b| if (b == champion) return true;
    return false;
}

pub const Dev = struct {
    what: []const u8,
    games: usize,
    log_loss: f64,
    baseline_log_loss: f64,
    coin_log_loss: f64 = @log(2.0),
    accuracy: f64,
    auc: f64,
};

pub const Point = struct { p: f64, y: bool };

/// Accuracy and AUC of blue's chance; sorts points
pub fn accuracyAuc(points: []Point) [2]f64 {
    var hits: f64 = 0;
    for (points) |pt| {
        if ((pt.p > 0.5) == pt.y) hits += 1;
    }
    std.mem.sort(Point, points, {}, struct {
        fn f(_: void, a: Point, b: Point) bool {
            return a.p < b.p;
        }
    }.f);
    var pos: f64 = 0;
    var rank_sum: f64 = 0;
    for (points, 1..) |pt, i| if (pt.y) {
        pos += 1;
        rank_sum += @floatFromInt(i);
    };
    const n: f64 = @floatFromInt(points.len);
    return .{ hits / n, (rank_sum - pos * (pos + 1) / 2) / (pos * (n - pos)) };
}

pub const ChampionOut = struct { id: u32, name: []const u8, alias: []const u8 };
pub const CellOut = struct { champion: u32, role: u8, games: u32, patch_games: u32, patch_share: f64 };

pub const ModelFile = struct {
    format: []const u8 = "meiolol-draft-model",
    version: u32 = 4,
    meta: struct {
        name: []const u8,
        run: []const u8,
        snapshot: []const u8,
        newest_game: []const u8,
        training_games: usize,
        /// Play shares' patch, its games, and the training games' first and last
        patch: []const u8,
        patch_games: u32,
        oldest_patch: []const u8,
        newest_patch: []const u8,
        platform: []const u8,
        dev: Dev,
    },
    roles: [n_role][]const u8 = .{ "top", "jungle", "middle", "bottom", "utility" },
    has_pairs: bool,
    min_games: u32 = default_min_games,
    champions: []const ChampionOut,
    cells: []const CellOut,
    average: [n_role]AverageOut,
    model: struct { kind: []const u8, dim: u32, intercept: f64, w: [25]f32, z: [25]f32, terms: []const Term, comp: ?Comp, pairs: ?Pairs, temperature: f64 },
};

pub const AverageOut = struct { b: f64, u: []const f32, v: []const f32, s: []const f32, p: []const f32, raw: []const f32 };

pub const RefDraft = struct {
    label: []const u8,
    /// By side (0 blue) and role; 0 empty
    teams: [2][n_role]u32,
    blue: Chance,
    /// The comp terms' part of blue's logit
    comp: f64,
    /// The pair cells' part
    pairs: f64,
};

pub const RefSlot = struct {
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

pub const RefFile = struct {
    format: []const u8 = "meiolol-draft-ref",
    version: u32 = 1,
    tolerance: f64 = 1e-9,
    drafts: []const RefDraft,
    slots: []const RefSlot,
};

/// Where a file's model came from (its meta) and the held-out games its references score
pub const Source = struct {
    name: []const u8,
    run: []const u8,
    snapshot: []const u8,
    /// Unix ms
    newest_start: i64,
    training_games: usize,
    platform: []const u8,
    dev: Dev,
    /// Test games' teams by side and role; the first three are references
    tests: []const [2][n_role]u32,
};

/// DIR/draft-model.json and DIR/draft-ref.json
pub fn exportFiles(
    arena: std.mem.Allocator,
    io: Io,
    sc: *const Scorer,
    champs: *const Champions,
    src: Source,
    dir: []const u8,
    w: *Io.Writer,
) !void {
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
    for (&average, sc.average) |*o, a| o.* = .{ .b = a.b, .u = a.u, .v = a.v, .s = a.s, .p = a.p, .raw = a.raw };
    const e = sc.e;
    const model: ModelFile = .{
        .meta = .{
            .name = src.name,
            .run = src.run,
            .snapshot = src.snapshot,
            .newest_game = try dayOf(arena, src.newest_start),
            .training_games = src.training_games,
            .patch = try patchLabel(arena, champs.patch),
            .patch_games = champs.patch_total / 2,
            .oldest_patch = try patchLabel(arena, champs.oldest_patch),
            .newest_patch = try patchLabel(arena, champs.newest_patch),
            .platform = src.platform,
            .dev = src.dev,
        },
        .has_pairs = !std.mem.eql(u8, e.kind, "ratings") and !std.mem.eql(u8, e.kind, "rates"),
        .champions = champions.items,
        .cells = cells.items,
        .average = average,
        .model = .{ .kind = e.kind, .dim = e.dim, .intercept = e.intercept[sc.platform], .w = e.w, .z = e.z, .terms = e.terms, .comp = e.comp, .pairs = e.pairs, .temperature = e.temperature },
    };

    // References: real test games whole and partly open, an empty board, two slot queries
    var drafts: std.ArrayList(RefDraft) = .empty;
    var slots: std.ArrayList(RefSlot) = .empty;
    for (src.tests[0..@min(src.tests.len, 3)], 0..) |teams, shown| {
        try drafts.append(arena, refDraft("full test game", sc, teams));
        var part = teams;
        part[0][2] = 0;
        part[1][3] = 0;
        part[1][4] = 0;
        try drafts.append(arena, refDraft("blue middle, red bottom and utility empty", sc, part));
        if (shown == 0) {
            const bans = [_]u32{ teams[1][3], firstOther(champs, &teams) };
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
    try drafts.append(arena, refDraft("empty board", sc, @splat(@splat(0))));
    try drafts.append(arena, refDraft("every slot a champion with no term in its role", sc, noTerms(sc, champs)));
    try compRefs(arena, sc, champs, &drafts, &slots);

    try Io.Dir.cwd().createDirPath(io, dir);
    const model_json = try std.json.Stringify.valueAlloc(arena, model, .{});
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "draft-model.json" }), .data = model_json });
    const ref_json = try std.json.Stringify.valueAlloc(arena, RefFile{ .drafts = drafts.items, .slots = slots.items }, .{ .whitespace = .indent_1 });
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "draft-ref.json" }), .data = ref_json });
    try w.print("wrote {s}/draft-model.json ({d} KB) and draft-ref.json ({d} KB)\n", .{ dir, model_json.len / 1024, ref_json.len / 1024 });
}

pub fn refDraft(label: []const u8, sc: *const Scorer, teams: [2][n_role]u32) RefDraft {
    return .{ .label = label, .teams = teams, .blue = sc.blue(teams), .comp = sc.compOf(teams), .pairs = sc.pairLogit(teams) };
}

/// Rammus jungle into a full AP and a full AD red team, alone and as blue's jungle slot
/// query: the comp terms' check (any model scores them)
pub fn compRefs(arena: std.mem.Allocator, sc: *const Scorer, champs: *const Champions, drafts: *std.ArrayList(RefDraft), slots: *std.ArrayList(RefSlot)) !void {
    const reds = [_]struct { label: []const u8, names: [n_role][]const u8 }{
        .{ .label = "5 AP", .names = .{ "Kennen", "Elise", "Syndra", "Ziggs", "Lux" } },
        .{ .label = "5 AD", .names = .{ "Darius", "Kha'Zix", "Zed", "Jinx", "Pyke" } },
    };
    const rammus = champs.find("Rammus") orelse return;
    for (reds) |red| {
        var d: Draft = .{ .role = 1 };
        for (red.names, &d.teams[1]) |n, *c| c.* = champs.find(n) orelse return;
        const r = try rank(arena, sc, champs, &d);
        try slots.append(arena, .{
            .label = try std.fmt.allocPrint(arena, "blue jungle to fill into {s}", .{red.label}),
            .role = 1,
            .side = 0,
            .teams = d.bySide(),
            .bans = &.{},
            .min_games = d.min_games,
            .empty = r.empty,
            .average = r.average,
            .options = r.options,
        });
        d.teams[0][1] = rammus;
        try drafts.append(arena, refDraft(try std.fmt.allocPrint(arena, "Rammus jungle into {s}", .{red.label}), sc, d.bySide()));
    }
}

/// Each slot the lowest-id champion without a term in that role, a different one per
/// slot: scored as the role average, as an empty slot, but reached through a champion id
pub fn noTerms(sc: *const Scorer, champs: *const Champions) [2][n_role]u32 {
    var teams: [2][n_role]u32 = @splat(@splat(0));
    var after: u32 = 0;
    for (0..2) |side| for (0..n_role) |r| {
        var best: u32 = std.math.maxInt(u32);
        var it = champs.names.keyIterator();
        while (it.next()) |id| {
            if (id.* > after and id.* < best and !sc.terms.contains(Champions.key(id.*, r))) best = id.*;
        }
        teams[side][r] = best;
        after = best;
    };
    return teams;
}

/// Some champion not in the game, for a ban
pub fn firstOther(champs: *const Champions, teams: *const [2][n_role]u32) u32 {
    var it = champs.names.keyIterator();
    outer: while (it.next()) |id| {
        for (teams) |t| for (t) |c| if (c == id.*) continue :outer;
        if (champs.gamesIn(id.*, 2) >= default_min_games) return id.*;
    }
    return 0;
}

/// stats.patchKey back to "16.21"
pub fn patchLabel(arena: std.mem.Allocator, key: u32) ![]const u8 {
    return std.fmt.allocPrint(arena, "{d}.{d}", .{ key / 1000, key % 1000 });
}

pub fn dayOf(arena: std.mem.Allocator, ms: i64) ![]const u8 {
    const es: std.time.epoch.EpochSeconds = .{ .secs = @intCast(@divFloor(ms, 1000)) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.allocPrint(arena, "{d}-{d:0>2}-{d:0>2}", .{ yd.year, md.month.numeric(), md.day_index + 1 });
}

test "play shares: the newest patch with enough games, else the newest" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const G = struct { patch: u32, teams: [2][n_role]u32 };
    const teams: [2][n_role]u32 = .{ .{ 1, 2, 3, 4, 5 }, .{ 6, 7, 8, 9, 10 } };
    const games = try arena.alloc(G, min_share_games + 5);
    for (games, 0..) |*g, i| g.* = .{ .patch = if (i < 3) 16021 else if (i < 5) 16019 else 16020, .teams = teams };
    var c: Champions = .{};
    try c.countShares(arena, games);
    try std.testing.expectEqual(16020, c.patch);
    try std.testing.expectEqual(16019, c.oldest_patch);
    try std.testing.expectEqual(16021, c.newest_patch);
    try std.testing.expectEqual(2 * min_share_games, c.patch_total);
    var few: Champions = .{};
    try few.countShares(arena, games[0..5]);
    try std.testing.expectEqual(16021, few.patch);
    try std.testing.expectEqual(6, few.patch_total);
}

test "scorer: the documented formula on known parameters" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var champs: Champions = .{ .patch_total = 4 };
    // Role top: champion 1 (b 0.2) and 2 (b -0.1), each half the patch's top games
    try champs.patch_games.put(arena, Champions.key(1, 0), 2);
    try champs.patch_games.put(arena, Champions.key(2, 0), 2);
    const terms = [_]Term{
        .{ .champion = 1, .role = 0, .games = 400, .b = 0.2, .sd = 0.1 },
        .{ .champion = 2, .role = 0, .games = 400, .b = -0.1, .sd = 0.1 },
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

test "scorer: temperature scales the logit and the interval, 1 changes nothing" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var champs: Champions = .{ .patch_total = 4 };
    try champs.patch_games.put(arena, Champions.key(1, 0), 2);
    try champs.patch_games.put(arena, Champions.key(2, 0), 2);
    const terms = [_]Term{
        .{ .champion = 1, .role = 0, .games = 400, .b = 0.2, .sd = 0.1 },
        .{ .champion = 2, .role = 0, .games = 400, .b = -0.1, .sd = 0.1 },
    };
    var intercept: [256]f32 = @splat(0);
    intercept[6] = 0.04;
    var teams: [2][n_role]u32 = @splat(@splat(0));
    teams[0][0] = 1;
    teams[1][0] = 2;
    const base: Params = .{ .kind = "ratings", .dim = 0, .intercept = &intercept, .w = @splat(0), .z = @splat(0), .terms = &terms };
    var hot = base;
    hot.temperature = 0.8;
    const one = (try Scorer.init(arena, base, 6, &champs)).blue(teams);
    const c = (try Scorer.init(arena, hot, 6, &champs)).blue(teams);
    // logit 0.34 as in the formula test; 0.8 of it, and of the interval's ends
    try std.testing.expectApproxEqAbs(sigmoid(0.34), one.p, 1e-6);
    try std.testing.expectApproxEqAbs(sigmoid(0.8 * 0.34), c.p, 1e-6);
    try std.testing.expectApproxEqAbs(sigmoid(0.8 * (0.34 + 1.96 * @sqrt(0.02))), c.hi, 1e-6);
    try std.testing.expect(c.p < one.p and c.p > 0.5);
}

test "scorer: a champion with no term in its role scores as the empty slot" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var champs: Champions = .{ .patch_total = 4 };
    for (1..13) |id| try champs.names.put(arena, @intCast(id), "x");
    try champs.patch_games.put(arena, Champions.key(1, 0), 2);
    try champs.patch_games.put(arena, Champions.key(2, 0), 2);
    const terms = [_]Term{
        .{ .champion = 1, .role = 0, .games = 400, .b = 0.2, .sd = 0.1, .p = &.{ 1, 0 } },
        .{ .champion = 2, .role = 0, .games = 400, .b = -0.1, .sd = 0.1, .p = &.{ 0, 1 } },
    };
    const zero: [4]f32 = @splat(0);
    var intercept: [256]f32 = @splat(0);
    intercept[6] = 0.04;
    const sc = try Scorer.init(arena, .{
        .kind = "comp",
        .dim = 0,
        .intercept = &intercept,
        .w = @splat(0),
        .z = @splat(0),
        .terms = &terms,
        .comp = .{ .stats = &.{ .{ .name = "a", .label = "a" }, .{ .name = "b", .label = "b" } }, .S = &.{ 0.5, 0.1, 0.1, -0.2 }, .A = &.{ 0, 0.3, -0.3, 0 }, .S_sd = &zero, .A_sd = &zero },
    }, 6, &champs);
    const teams = noTerms(&sc, &champs);
    // Blue top skips 1 and 2, which have top terms; then one new id per slot
    try std.testing.expectEqual(@as(u32, 3), teams[0][0]);
    try std.testing.expectEqual(@as(u32, 12), teams[1][4]);
    try std.testing.expectEqual(sc.blue(@splat(@splat(0))), sc.blue(teams));
    try std.testing.expectEqual(sc.compOf(@splat(@splat(0))), sc.compOf(teams));
}

test "scorer: team term on the damage-weighted magic share" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var champs: Champions = .{ .patch_total = 4 };
    try champs.patch_games.put(arena, Champions.key(1, 0), 2);
    try champs.patch_games.put(arena, Champions.key(2, 0), 2);
    var raw1: [raw_len]f32 = @splat(0);
    raw1[raw_magic] = 0.8;
    raw1[raw_dmg] = 10;
    var raw2: [raw_len]f32 = @splat(0);
    raw2[raw_magic] = 0.1;
    raw2[raw_dmg] = 20;
    const terms = [_]Term{
        .{ .champion = 1, .role = 0, .games = 400, .b = 0, .sd = 0.1, .p = &.{0}, .raw = &raw1 },
        .{ .champion = 2, .role = 0, .games = 400, .b = 0, .sd = 0.1, .p = &.{0}, .raw = &raw2 },
    };
    var intercept: [256]f32 = @splat(0);
    const sc = try Scorer.init(arena, .{
        .kind = "comp",
        .dim = 0,
        .intercept = &intercept,
        .w = @splat(0),
        .z = @splat(0),
        .terms = &terms,
        .comp = .{
            .stats = &.{.{ .name = "magic", .label = "magic" }},
            .S = &.{0},
            .A = &.{0},
            .S_sd = &.{0},
            .A_sd = &.{0},
            .team = &.{.{ .kind = "mix", .stat = 0, .centre = 0.5, .weight = -2 }},
        },
    }, 6, &champs);
    var teams: [2][n_role]u32 = @splat(@splat(0));
    teams[0][0] = 1;
    teams[1][0] = 2;
    // Only top slots deal damage: blue 0.8 magic, red 0.1; -2 (0.3^2 - 0.4^2)
    try std.testing.expectApproxEqAbs(0.14, sc.compOf(teams), 1e-6);
    // Red top empty: the role average, magic 0.45 on damage 15
    teams[1][0] = 0;
    try std.testing.expectApproxEqAbs(-2 * (0.09 - 0.0025), sc.compOf(teams), 1e-6);
}
