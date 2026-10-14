//! `meiolol-lab draft`: a win model as a draft tester, and its export for the admin page's
//! draft board (docs/model.md "Draft model file"): the compiled-in candidate's, or with
//! --model additive the shrunk additive model (lab/additive.zig, effects' "full", v2).
//! Fits once on every played game in the snapshot. Scores come from the exported
//! parameters through Scorer, the reference the page's JS must match; an empty slot counts
//! as its role's average pick on the newest patch.

const std = @import("std");
const api = @import("api");
const core = @import("core");
const cand = @import("cand");
const store = @import("store");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");
const additive = @import("additive.zig");
const addinputs = @import("addinputs.zig");

const Io = std.Io;

pub const usage =
    \\  draft SNAP [DRAFT]              rank champions for an open slot with the compiled-in
    \\                                  candidate's win model (-Dcand); without DRAFT, reads
    \\                                  drafts line by line. DRAFT: --role mid [--side red]
    \\                                  [--ally top=Darius,jungle=Lee Sin] [--enemy mid=Ahri,
    \\                                  Jinx] [--ban Yasuo] [--top 10] [--min-games 100]
    \\  draft SNAP --export DIR [--temperature T]
    \\                                  write DIR/draft-model.json and DIR/draft-ref.json for
    \\                                  the admin draft board (docs/model.md); T scales every
    \\                                  logit (calibration, default_temperature)
    \\  draft SNAP --model additive [--pair-floor N] ...
    \\                                  either of the above with the additive model (pairs
    \\                                  and damage mix; needs seat stats, ignores -Dcand);
    \\                                  pair cells on fewer than N fit games are left out
    \\                                  (default_pair_floor)
    \\
;

const n_role = 5;
const default_min_games = 100;
const z95 = 1.96;
/// Shown chances are sigmoid(T * logit): win-ratings is over-confident on held-out games.
/// One temperature fitted on its preds on win-comp's 5 forward folds of snap-20261012T2055Z
/// (44,353 games): 0.80 +- 0.11 (netcheck f1 runs and effects eff-d agree; the top tenth
/// said 58.6% and won 55.8%). Refit when the shipped model or the snapshot changes
pub const default_temperature = 0.80;
/// The additive model's: fitted on effects' v2 "full" preds on the 5 forward folds of
/// snap-20261013T2253Z (run 20261014T041809Z-e53v2-V0, 134,375 games): 1.01 +- 0.03,
/// folds 0.96-1.10, dev-val 1.14 +- 0.05; the top tenth said 61.1% and won 61.2%
pub const default_temperature_additive = 1.01;
/// Pair cells on fewer fit games are left out of the export (0, the prior mean): heavily
/// shrunk, so they barely move a draft (the export prints by how much), and they are most
/// of the cells
pub const default_pair_floor = 20;

const ModelKind = enum { cand, additive };

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

/// A champion-role's exported parameters: cand.Term, and p from a comp candidate
const Term = struct {
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

const Stat = struct { name: []const u8, label: []const u8 };

/// Nonlinear within-team term on f, the team's damage-weighted magic share
/// (sum raw.dmg * raw.magic / sum raw.dmg over the five slots, 0.5 without damage):
/// mix w (f - centre)^2, ad_heavy w min(f - centre, 0)^2, ap_heavy w max(f - centre, 0)^2.
/// Blue's logit adds the term of blue's team minus red's; sd 0 when not exported
const TeamTerm = struct { kind: []const u8, stat: u32, centre: f32 = 0, weight: f32, sd: f32 = 0 };

const TeamKind = enum { mix, ad_heavy, ap_heavy };

/// win-comp's Feature order: magic share of damage first, damage per minute third
const raw_len = 12;
const raw_magic = 0;
const raw_dmg = 2;

fn magicShare(sl: *const [n_role]Slot) f64 {
    var num: f64 = 0;
    var den: f64 = 0;
    for (sl) |x| {
        num += @as(f64, x.raw[raw_dmg]) * x.raw[raw_magic];
        den += x.raw[raw_dmg];
    }
    return if (den > 0) num / den else 0.5;
}

fn teamForm(kind: TeamKind, f: f64, centre: f64) f64 {
    const d = f - centre;
    return switch (kind) {
        .mix => d * d,
        .ad_heavy => @min(d, 0) * @min(d, 0),
        .ap_heavy => @max(d, 0) * @max(d, 0),
    };
}

/// Comp terms on team-summed profiles P: P_b'S P_b - P_r'S P_r + P_b'A P_r
const Comp = struct {
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

const max_k = 64;

/// The candidate's exported model as the scorer reads it (cand.Export, and comp if any)
const Params = struct {
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

/// The additive model's pair cells (lab/additive.zig, v2): one cell per pair of champions,
/// allies in roles r < q, or a matchup of blue's role r against red's role q (r <= q; red's
/// r against blue's q is the same cell negated; a same-role matchup one cell per unordered
/// pair, a < b, for a facing b). Cells on fewer than min_games fit games are left out (0)
const Pairs = struct {
    min_games: u32,
    groups: []const PairGroup,
    cells: []const PairCell,
};

const PairGroup = struct {
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
const PairCell = struct {
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

fn pairKey(group: usize, a: u32, b: u32) u64 {
    return @as(u64, group) << 48 | @as(u64, a) << 24 | b;
}

fn paramsOf(arena: std.mem.Allocator, e: anytype) !Params {
    const terms = try arena.alloc(Term, e.terms.len);
    for (terms, e.terms) |*t, x| {
        t.* = .{ .champion = x.champion, .role = x.role, .games = x.games, .b = x.b, .sd = x.sd, .u = x.u, .v = x.v, .s = x.s };
        if (@hasField(@TypeOf(x), "p")) t.p = x.p;
        if (@hasField(@TypeOf(x), "raw")) t.raw = x.raw;
    }
    var out: Params = .{ .kind = e.kind, .dim = e.dim, .intercept = e.intercept, .w = e.w, .z = e.z, .terms = terms };
    if (@hasField(@TypeOf(e), "comp")) if (e.comp) |c| {
        const stats = try arena.alloc(Stat, c.stats.len);
        for (stats, c.stats) |*st, x| st.* = .{ .name = x.name, .label = x.label };
        const team = try arena.alloc(TeamTerm, c.team.len);
        for (team, c.team) |*tt, x| {
            tt.* = .{ .kind = x.kind, .stat = x.stat, .centre = x.centre, .weight = x.weight };
            if (@hasField(@TypeOf(x), "sd")) tt.sd = x.sd;
        }
        out.comp = .{ .stats = stats, .S = c.S, .A = c.A, .S_sd = c.S_sd, .A_sd = c.A_sd, .team = team, .beta = c.beta };
    };
    return out;
}

/// One slot's parameters: a champion-role's term, or its role's average pick (sd 0)
const Slot = struct {
    b: f64,
    sd: f64,
    u: []const f32,
    v: []const f32,
    s: []const f32,
    p: []const f32,
    raw: []const f32,
};

/// The reference scorer (docs/model.md "Draft model file"), from exported parameters only
const Scorer = struct {
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

    fn init(arena: std.mem.Allocator, e: Params, platform: u8, champs: *const Champions) !Scorer {
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

    fn slot(sc: *const Scorer, champion: u32, role: usize) Slot {
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
    fn blue(sc: *const Scorer, teams: [2][n_role]u32) Chance {
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
    fn compLogit(sc: *const Scorer, sl: *const [2][n_role]Slot) f64 {
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
    fn pairLogit(sc: *const Scorer, t: [2][n_role]u32) f64 {
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

    fn cell(sc: *const Scorer, group: usize, a: u32, b: u32) f64 {
        if (a == 0 or b == 0) return 0;
        return sc.cells.get(pairKey(group, a, b)) orelse 0;
    }

    /// The comp part for whole teams, by side (0 blue) and role
    fn compOf(sc: *const Scorer, teams: [2][n_role]u32) f64 {
        var sl: [2][n_role]Slot = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            sl[side][r] = sc.slot(teams[side][r], r);
        };
        return sc.compLogit(&sl);
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
    const snap = argv[0];
    // --model and --pair-floor may sit anywhere after SNAP
    var model: ModelKind = .cand;
    var floor: u32 = default_pair_floor;
    var rest: std.ArrayList([]const u8) = .empty;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const flag = argv[i];
        if (i + 1 < argv.len and std.mem.eql(u8, flag, "--model")) {
            i += 1;
            model = std.meta.stringToEnum(ModelKind, argv[i]) orelse {
                std.debug.print("draft: --model cand|additive\n", .{});
                return 2;
            };
        } else if (i + 1 < argv.len and std.mem.eql(u8, flag, "--pair-floor")) {
            i += 1;
            floor = try std.fmt.parseInt(u32, argv[i], 10);
        } else try rest.append(arena, flag);
    }
    const args = rest.items;
    const export_mode = args.len >= 2 and std.mem.eql(u8, args[0], "--export");
    var temperature: f64 = if (model == .additive) default_temperature_additive else default_temperature;
    if (export_mode and args.len == 4 and std.mem.eql(u8, args[2], "--temperature")) {
        temperature = try std.fmt.parseFloat(f64, args[3]);
    } else if (export_mode and args.len != 2) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
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

    var cm: ?cand.Model = null;
    defer if (cm) |*m| cand.deinit(m, gpa);
    var af: ?AddFit = null;
    defer if (af) |*a| a.deinit(gpa);
    var params: Params = undefined;
    var training_games = data.games.len;
    switch (model) {
        .cand => if (comptime !@hasDecl(cand, "exportModel")) {
            std.debug.print("draft: the candidate has no exportModel (src/lab/cand/win-ratings has); or --model additive\n", .{});
            return 2;
        } else {
            cm = try fitAll(gpa, &data);
            params = try paramsOf(arena, try cand.exportModel(&cm.?, arena));
        },
        .additive => {
            const played = try arena.alloc(bool, data.games.len);
            for (data.games, played) |g, *x| x.* = harness.played(g);
            af = try fitAdditive(gpa, arena, &data, try addinputs.inputs(arena, &data), played, addinputs.fullVariant(true, 1));
            params = try paramsOfAdditive(arena, &af.?.p, &af.?.f, &af.?.mix, floor);
            training_games = af.?.p.games.len;
        },
    }
    params.temperature = temperature;
    const sc = try Scorer.init(arena, params, eu, &champs);
    try w.print("win model ({s}) fitted on {d} games; --min-games guards against thin samples; chances at temperature {d}\n", .{ params.kind, training_games, params.temperature });

    if (export_mode) {
        // The scorer must agree with the model it came from on drafts it saw whole
        const worst = if (cm) |*m| try checkCand(m, &sc, &data, w) else try checkAdditive(arena, &af.?, &sc, &data, floor, w);
        if (worst > 1e-4) return error.ScorerDisagrees;
        try w.print("dev score (refits on dev's games)...\n", .{});
        try w.flush();
        const dev = if (cm != null) try devScore(gpa, &data) else try devAdditive(gpa, arena, &data, af.?.in);
        try w.print("dev: log loss {d:.5} (baseline {d:.5}), accuracy {d:.4}, AUC {d:.4} on {d} games\n", .{ dev.log_loss, dev.baseline_log_loss, dev.accuracy, dev.auc, dev.games });
        try exportFiles(arena, io, snap, &data, &sc, &champs, args[1], dev, training_games, w);
        return 0;
    }
    if (args.len > 0) {
        try run(arena, &sc, &champs, args, w);
        return 0;
    }
    var in_buf: [4096]u8 = undefined;
    var in_file = Io.File.stdin().reader(io, &in_buf);
    while (true) {
        try w.writeAll("draft> ");
        try w.flush();
        const line = try in_file.interface.takeDelimiter('\n') orelse break;
        const line_args = try splitFlags(arena, line);
        if (line_args.len == 0) continue;
        run(arena, &sc, &champs, line_args, w) catch |err| try w.print("{t}\n", .{err});
    }
    return 0;
}

fn euIndex() u8 {
    for (protocol.platformIds(), 0..) |id, i| if (std.mem.eql(u8, id, protocol.home_platform)) return @intCast(i);
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

/// Games over before 15:00 left out, as the harness fits (docs/model.md "Rows")
fn trainOf(a: std.mem.Allocator, d: *const rows.Data) !api.Train {
    const players = try harness.gamePlayers(a, d);
    const index = try a.alloc(u32, d.games.len);
    var games: std.ArrayList(api.Game) = .empty;
    for (d.games, players, index) |g, pl, *ix| {
        if (g.duration_s < harness.min_duration_s) continue;
        ix.* = @intCast(games.items.len);
        try games.append(a, .{ .start = g.start, .patch = g.patch, .platform = g.platform, .teams = g.teams, .ranks = pl.ranks, .exp = pl.exp });
    }
    var out: std.ArrayList(api.Row) = .empty;
    for (d.rows) |r| {
        if (d.games[r.game].duration_s < harness.min_duration_s) continue;
        try out.append(a, .{
            .game = index[r.game],
            .side = r.side,
            .role = @fromBackingInt(@backingInt(r.role)),
            .champion = r.champion,
            .rank = r.rank_start,
            .exp = harness.experience(r),
            .y = r.y,
            .stats = r.stats,
        });
    }
    return .{ .games = games.items, .rows = out.items };
}

/// A tool, not an evaluation: every game that lasted 15:00, test games included
fn fitAll(gpa: std.mem.Allocator, d: *const rows.Data) !cand.Model {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const t = try trainOf(arena_state.allocator(), d);
    return harness.fit(cand, gpa, &t, .{});
}

/// The additive model fitted on the games in `fit`, its damage mix from their rows
const AddFit = struct {
    in: addinputs.Inputs,
    mix: addinputs.Mix,
    p: additive.Problem,
    f: additive.Fit,

    fn deinit(a: *AddFit, gpa: std.mem.Allocator) void {
        a.mix.deinit(gpa);
        a.p.deinit(gpa);
        a.f.deinit(gpa);
    }

    /// Blue's logit for game gi on `platform`'s side term, the mix from every fit row
    fn logit(a: *const AddFit, d: *const rows.Data, gi: usize, platform: u8, f: *const additive.Fit) f64 {
        var g = addinputs.gameIn(d, gi, 0, a.mix.diff(d, a.in, gi, false));
        g.platform = platform;
        return additive.predict(&a.p, f, &g);
    }
};

/// As effects fits a block: fit games see their own rows left out of the mix
fn fitAdditive(gpa: std.mem.Allocator, arena: std.mem.Allocator, d: *const rows.Data, in: addinputs.Inputs, fit: []const bool, variant: additive.Variant) !AddFit {
    var mix = try addinputs.Mix.init(gpa, d, fit, in.win);
    errdefer mix.deinit(gpa);
    var games: std.ArrayList(additive.GameIn) = .empty;
    for (fit, 0..) |f, gi| if (f) try games.append(arena, addinputs.gameIn(d, gi, in.win[gi], mix.diff(d, in, gi, true)));
    var p = try additive.build(gpa, .logistic, variant, games.items);
    errdefer p.deinit(gpa);
    const f = try additive.fit(gpa, &p, .{}, null, null);
    return .{ .in = in, .mix = mix, .p = p, .f = f };
}

/// Rounding keeps the file small; the scorer and the export check use the rounded values
fn round5(x: f64) f64 {
    return @round(x * 1e5) / 1e5;
}

/// The additive model as Params: champion strength as terms (sd from the posterior
/// curvature), the damage mix as comp's one team term (raw holds each champion-role's mix
/// profile: magic share at raw_magic, damage per minute at raw_dmg), pair cells on
/// floor+ games. mix null: no comp (tests)
fn paramsOfAdditive(arena: std.mem.Allocator, p: *const additive.Problem, f: *const additive.Fit, mix: ?*const addinputs.Mix, floor: u32) !Params {
    const A = additive;
    const intercept = try arena.alloc(f32, A.n_platforms);
    for (intercept, f.theta[0..A.n_platforms]) |*x, y| x.* = @floatCast(y);
    var terms: std.ArrayList(Term) = .empty;
    for (p.param_start[A.g_main]..p.param_start[A.g_ally]) |j| {
        const cl = A.cellOf(p, j);
        const role = cl.group - A.g_main;
        var t: Term = .{ .champion = cl.a, .role = @intCast(role), .games = p.count[j], .b = @floatCast(f.theta[j]), .sd = @floatCast(1 / @sqrt(f.h[j])) };
        if (mix) |m| {
            const prof = m.profile(cl.a, role, null);
            const raw = try arena.alloc(f32, raw_len);
            @memset(raw, 0);
            raw[raw_magic] = @floatCast(prof[0]);
            raw[raw_dmg] = @floatCast(prof[1]);
            t.raw = raw;
        }
        try terms.append(arena, t);
    }
    var groups: std.ArrayList(PairGroup) = .empty;
    var cells: std.ArrayList(PairCell) = .empty;
    var nbuf: [64]u8 = undefined;
    for (A.g_ally..A.n_groups) |g| {
        const lo = p.param_start[g];
        const hi = p.param_start[g + 1];
        if (hi == lo) continue;
        const gr = A.groupRoles(g);
        const gi: u32 = @intCast(groups.items.len);
        var shipped: u32 = 0;
        for (lo..hi) |j| {
            if (p.count[j] < floor) continue;
            const cl = A.cellOf(p, j);
            try cells.append(arena, .{ .group = gi, .a = cl.a, .b = cl.b, .theta = round5(f.theta[j]), .games = p.count[j] });
            shipped += 1;
        }
        try groups.append(arena, .{
            .name = try arena.dupe(u8, A.groupName(&nbuf, g)),
            .kind = if (gr.ally) "ally" else "matchup",
            .r = @intCast(gr.r),
            .q = @intCast(gr.q),
            .sd = @floatCast(@sqrt(f.sigma2[g])),
            .fitted = @intCast(hi - lo),
            .shipped = shipped,
        });
    }
    var out: Params = .{ .kind = "additive", .dim = 0, .intercept = intercept, .w = @splat(0), .z = @splat(0), .terms = terms.items };
    out.pairs = .{ .min_games = floor, .groups = groups.items, .cells = cells.items };
    if (mix != null) {
        const j = A.n_platforms;
        const team = try arena.alloc(TeamTerm, 1);
        team[0] = .{ .kind = "mix", .stat = 0, .centre = 0.5, .weight = @floatCast(f.theta[j]), .sd = @floatCast(1 / @sqrt(f.h[j])) };
        out.comp = .{ .stats = &.{}, .S = &.{}, .A = &.{}, .S_sd = &.{}, .A_sd = &.{}, .team = team };
    }
    return out;
}

/// The fit as exported: pair cells below the floor 0, the rest rounded as in the file
fn shippedFit(arena: std.mem.Allocator, p: *const additive.Problem, f: *const additive.Fit, floor: u32) !additive.Fit {
    var out = f.*;
    out.theta = try arena.dupe(f64, f.theta);
    for (p.param_start[additive.g_ally]..p.n_params()) |j| {
        out.theta[j] = if (p.count[j] < floor) 0 else round5(f.theta[j]);
    }
    return out;
}

/// The scorer against the additive model it came from (as exported) on 500 test games,
/// and what the pair floor moves on every fit game
fn checkAdditive(arena: std.mem.Allocator, af: *const AddFit, sc: *const Scorer, d: *const rows.Data, floor: u32, w: *Io.Writer) !f64 {
    const fs = try shippedFit(arena, &af.p, &af.f, floor);
    var worst: f64 = 0;
    var checked: usize = 0;
    var moved: f64 = 0;
    var moved_max: f64 = 0;
    var n: usize = 0;
    for (d.games, 0..) |g, gi| {
        if (!harness.played(g)) continue;
        const shipped = af.logit(d, gi, sc.platform, &fs);
        const x = @abs(af.logit(d, gi, sc.platform, &af.f) - shipped);
        moved += x;
        moved_max = @max(moved_max, x);
        n += 1;
        if (!g.is_test or checked == 500) continue;
        checked += 1;
        worst = @max(worst, @abs(sc.blue(g.teams).p - sigmoid(sc.e.temperature * shipped)));
    }
    var fitted: usize = 0;
    var shipped: usize = 0;
    for (sc.e.pairs.?.groups) |g| {
        fitted += g.fitted;
        shipped += g.shipped;
    }
    try w.print("pair floor {d} games: {d} of {d} pair cells exported; blue's logit moves {d:.5} on average (max {d:.4}) on {d} played games\n", .{ floor, shipped, fitted, moved / @as(f64, @floatFromInt(@max(n, 1))), moved_max, n });
    try w.print("scorer vs the additive model on {d} test games: max |diff| {e}\n", .{ checked, worst });
    return worst;
}

/// The candidate's own predict through the same temperature, on 500 test games
fn checkCand(m: *const cand.Model, sc: *const Scorer, d: *const rows.Data, w: *Io.Writer) !f64 {
    var worst: f64 = 0;
    var checked: usize = 0;
    for (d.games) |g| {
        if (!g.is_test or checked == 500) continue;
        checked += 1;
        const q: api.Query = .{ .start = g.start, .patch = g.patch, .platform = sc.platform, .side = 0, .role = .top, .champion = g.teams[0][0], .rank = null, .teams = g.teams, .ranks = null, .exp = .{}, .exps = null };
        const raw: f64 = cand.predict(m, &q)[api.outcomeIndex(.win)];
        const want = sigmoid(sc.e.temperature * @log(raw / (1 - raw)));
        worst = @max(worst, @abs(sc.blue(g.teams).p - want));
    }
    try w.print("scorer vs candidate on {d} test games: max |diff| {e}\n", .{ checked, worst });
    return worst;
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
fn devScore(gpa: std.mem.Allocator, d: *const rows.Data) !Dev {
    const players = try harness.gamePlayers(gpa, d);
    defer gpa.free(players);
    const c = try harness.cuts(gpa, d);
    var s = try harness.score(cand, gpa, d, players, c, .dev, .{});
    defer s.deinit(gpa);
    const k = api.outcomeIndex(.win);
    const la = try s.losses(gpa, d, k, null, .cand);
    defer gpa.free(la);
    const lb = try s.losses(gpa, d, k, null, .base);
    defer gpa.free(lb);
    const p = harness.paired(s.game, la, lb, null);

    var points: std.ArrayList(Point) = .empty;
    defer points.deinit(gpa);
    var last: ?u32 = null;
    for (s.row, s.game, s.cand) |ri, g, pred| {
        const r = d.rows[ri];
        if (r.side != 0 or last == g) continue;
        last = g;
        try points.append(gpa, .{ .p = pred[k], .y = d.games[g].winner == 0 });
    }
    const aa = accuracyAuc(points.items);
    return .{
        .what = "fitted on the games older than dev-val, scored on dev-val: the 10% of played games before the test cut, every platform (docs/lab-agent.md Splits); log loss per player row of the team's win (baseline: champion averages), accuracy and AUC per game on blue's chance",
        .games = points.items.len,
        .log_loss = p.a,
        .baseline_log_loss = p.b,
        .accuracy = aa[0],
        .auc = aa[1],
    };
}

const Point = struct { p: f64, y: bool };

/// Accuracy and AUC of blue's chance; sorts points
fn accuracyAuc(points: []Point) [2]f64 {
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

/// The additive model refitted on dev's visible games, scored on dev-val per game; the
/// baseline is champion strength alone (no pairs, no mix)
fn devAdditive(gpa: std.mem.Allocator, arena: std.mem.Allocator, d: *const rows.Data, in: addinputs.Inputs) !Dev {
    const c = try harness.cuts(gpa, d);
    const fit = try arena.alloc(bool, d.games.len);
    for (d.games, fit) |g, *x| x.* = harness.visible(.dev, c, g);
    var full = try fitAdditive(gpa, arena, d, in, fit, addinputs.fullVariant(true, 1));
    defer full.deinit(gpa);
    var base = try fitAdditive(gpa, arena, d, in, fit, additive.Variant.mains());
    defer base.deinit(gpa);
    var points: std.ArrayList(Point) = .empty;
    var la: f64 = 0;
    var lb: f64 = 0;
    for (d.games, 0..) |g, gi| {
        if (!harness.scored(.dev, c, g)) continue;
        const y = g.winner == 0;
        const pa = sigmoid(full.logit(d, gi, g.platform, &full.f));
        const pb = sigmoid(base.logit(d, gi, g.platform, &base.f));
        la -= @log(if (y) pa else 1 - pa);
        lb -= @log(if (y) pb else 1 - pb);
        try points.append(arena, .{ .p = pa, .y = y });
    }
    const n: f64 = @floatFromInt(@max(points.items.len, 1));
    const aa = accuracyAuc(points.items);
    return .{
        .what = "fitted on the games older than dev-val, scored on dev-val: the 10% of played games before the test cut, every platform (docs/lab-agent.md Splits); log loss per game of blue's win (baseline: champion strength alone), accuracy and AUC per game on blue's chance",
        .games = points.items.len,
        .log_loss = la / n,
        .baseline_log_loss = lb / n,
        .accuracy = aa[0],
        .auc = aa[1],
    };
}

const ChampionOut = struct { id: u32, name: []const u8, alias: []const u8 };
const CellOut = struct { champion: u32, role: u8, games: u32, patch_games: u32, patch_share: f64 };

const ModelFile = struct {
    format: []const u8 = "meiolol-draft-model",
    version: u32 = 4,
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
    model: struct { kind: []const u8, dim: u32, intercept: f64, w: [25]f32, z: [25]f32, terms: []const Term, comp: ?Comp, pairs: ?Pairs, temperature: f64 },
};

const AverageOut = struct { b: f64, u: []const f32, v: []const f32, s: []const f32, p: []const f32, raw: []const f32 };

const RefDraft = struct {
    label: []const u8,
    /// By side (0 blue) and role; 0 empty
    teams: [2][n_role]u32,
    blue: Chance,
    /// The comp terms' part of blue's logit
    comp: f64,
    /// The pair cells' part
    pairs: f64,
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
    arena: std.mem.Allocator,
    io: Io,
    snap: []const u8,
    d: *const rows.Data,
    sc: *const Scorer,
    champs: *const Champions,
    dir: []const u8,
    dev: Dev,
    training_games: usize,
    w: *Io.Writer,
) !void {
    var newest = d.games[0];
    for (d.games) |g| if (g.start > newest.start) {
        newest = g;
    };
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
            .name = if (std.mem.eql(u8, e.kind, "additive")) "additive v2: champion strength, ally pairs, matchups, damage mix" else try std.fmt.allocPrint(arena, "{s} ({s})", .{ if (@hasDecl(cand, "name")) cand.name else "candidate", e.kind }),
            .run = std.fs.path.basename(dir),
            .snapshot = std.fs.path.basename(snap),
            .newest_game = try dayOf(arena, newest.start),
            .training_games = training_games,
            .patch = try std.fmt.allocPrint(arena, "{d}.{d}", .{ champs.patch / 1000, champs.patch % 1000 }),
            .platform = protocol.home_platform,
            .dev = dev,
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
    var shown: usize = 0;
    for (d.games) |g| {
        if (!g.is_test or shown == 3) continue;
        shown += 1;
        try drafts.append(arena, refDraft("full test game", sc, g.teams));
        var part = g.teams;
        part[0][2] = 0;
        part[1][3] = 0;
        part[1][4] = 0;
        try drafts.append(arena, refDraft("blue middle, red bottom and utility empty", sc, part));
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

fn refDraft(label: []const u8, sc: *const Scorer, teams: [2][n_role]u32) RefDraft {
    return .{ .label = label, .teams = teams, .blue = sc.blue(teams), .comp = sc.compOf(teams), .pairs = sc.pairLogit(teams) };
}

/// Rammus jungle into a full AP and a full AD red team, alone and as blue's jungle slot
/// query: the comp terms' check (any model scores them)
fn compRefs(arena: std.mem.Allocator, sc: *const Scorer, champs: *const Champions, drafts: *std.ArrayList(RefDraft), slots: *std.ArrayList(RefSlot)) !void {
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
fn noTerms(sc: *const Scorer, champs: *const Champions) [2][n_role]u32 {
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

test "scorer: comp terms on team-summed profiles" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var champs: Champions = .{ .patch_total = 4 };
    try champs.patch_games.put(arena, Champions.key(1, 0), 2);
    try champs.patch_games.put(arena, Champions.key(2, 0), 2);
    // As a comp candidate exports them: p on its terms, comp beside them
    const CandTerm = struct { champion: u32, role: u8, games: u32, b: f32, sd: f32, u: []const f32 = &.{}, v: []const f32 = &.{}, s: []const f32 = &.{}, p: []const f32 };
    const zero: [4]f32 = @splat(0);
    var intercept: [256]f32 = @splat(0);
    intercept[6] = 0.04;
    const e = .{
        .kind = "comp",
        .dim = @as(u32, 0),
        .intercept = @as([]const f32, &intercept),
        .w = @as([25]f32, @splat(0)),
        .z = @as([25]f32, @splat(0)),
        .terms = &[_]CandTerm{
            .{ .champion = 1, .role = 0, .games = 400, .b = 0.2, .sd = 0.1, .p = &.{ 1, 0 } },
            .{ .champion = 2, .role = 0, .games = 400, .b = -0.1, .sd = 0.1, .p = &.{ 0, 1 } },
        },
        .comp = @as(?struct { stats: []const Stat, S: []const f32, A: []const f32, S_sd: []const f32, A_sd: []const f32, team: []const TeamTerm, beta: []const f32 }, .{
            .stats = &.{ .{ .name = "magic", .label = "magic damage" }, .{ .name = "armour", .label = "armour lean" } },
            .S = &.{ 0.5, 0.1, 0.1, -0.2 },
            .A = &.{ 0, 0.3, -0.3, 0 },
            .S_sd = &zero,
            .A_sd = &zero,
            .team = &.{},
            .beta = &.{},
        }),
    };
    const sc = try Scorer.init(arena, try paramsOf(arena, e), 6, &champs);
    var teams: [2][n_role]u32 = @splat(@splat(0));
    teams[0][0] = 1;
    teams[1][0] = 2;
    // P_b (1, 0), P_r (0, 1): S 0.5 - (-0.2), A 0.3; other roles have no terms, profile 0
    try std.testing.expectApproxEqAbs(1.0, sc.compOf(teams), 1e-6);
    try std.testing.expectApproxEqAbs(sigmoid(0.34 + 1.0), sc.blue(teams).p, 1e-6);
    // Red top empty: the role average, P_r (0.5, 0.5): S 0.5 - 0.125, A 0.15
    teams[1][0] = 0;
    try std.testing.expectApproxEqAbs(0.525, sc.compOf(teams), 1e-6);
    try std.testing.expectApproxEqAbs(sigmoid(0.04 + 0.2 - 0.05 + 0.525), sc.blue(teams).p, 1e-6);
    // Sides swapped: A antisymmetric and S's sign flips, so the comp part flips
    try std.testing.expectApproxEqAbs(-0.525, sc.compOf(.{ teams[1], teams[0] }), 1e-6);
}

test "scorer: additive pair cells and strength reproduce additive.predict" {
    const gpa = std.testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const A = additive;
    var rng: std.Random.DefaultPrng = .init(5);
    const rnd = rng.random();
    // 6 champions per role, ids shared across roles so mirrors and cross-role pairs occur
    const games = try arena.alloc(A.GameIn, 3000);
    for (games) |*g| {
        g.* = .{ .teams = undefined, .platform = 0, .y = @floatFromInt(rnd.uintLessThan(u8, 2)) };
        for (0..2) |side| for (0..n_role) |r| {
            g.teams[side][r] = 1 + rnd.uintLessThan(u32, 6);
        };
    }
    var p = try A.build(gpa, .logistic, addinputs.fullVariant(true, 0), games);
    defer p.deinit(gpa);
    var f = try A.fit(gpa, &p, .{ .outer = 2 }, null, null);
    defer f.deinit(gpa);
    // Random outcomes shrink every cell to ~0: give them sizes so a wrong sign shows
    for (A.n_platforms..p.n_params()) |j| f.theta[j] = rnd.floatNorm(f64) * 0.1;
    const champs: Champions = .{ .patch_total = 1 };
    const sc = try Scorer.init(arena, try paramsOfAdditive(arena, &p, &f, null, 0), 0, &champs);
    const fs = try shippedFit(arena, &p, &f, 0);
    for (games[0..200]) |*g| {
        const c = sc.blue(g.teams);
        try std.testing.expectApproxEqAbs(A.predict(&p, &fs, g), @log(c.p / (1 - c.p)), 1e-5);
    }
    // An empty slot touches no cell; an empty board has no pair part
    try std.testing.expectEqual(0, sc.pairLogit(@splat(@splat(0))));
    var t = games[0].teams;
    for (&t[1]) |*x| x.* = 0;
    var ally: f64 = 0;
    for (sc.e.pairs.?.groups, 0..) |g, gi| {
        if (std.mem.eql(u8, g.kind, "ally")) ally += sc.cell(gi, t[0][g.r], t[0][g.q]);
    }
    try std.testing.expectApproxEqAbs(ally, sc.pairLogit(t), 1e-12);
}

test "flags split before --, values keep spaces" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const got = try splitFlags(arena.allocator(), "--role mid --ally top=Darius,jungle=Lee Sin --side red");
    try std.testing.expectEqual(@as(usize, 6), got.len);
    try std.testing.expectEqualStrings("top=Darius,jungle=Lee Sin", got[3]);
    try std.testing.expectEqualStrings("red", got[5]);
}
