//! The Draft tester's set net as ui.wasm reads it: draft-setnet.bin, the lab's seeds
//! (draftfile.SetNet, lab/setnet.zig writeExport) encoded with data.zig (testerbin.zig).
//! Each seed is a correction on the Comp model's blue logit before its temperature:
//! (f(blue, red) - f(red, blue)) / 2 + c[platform] + a * base, f from each team's five
//! slot units. It has no terms of its own, so its part is broken down by swapping: a pick
//! for its role's average (zero profile, the role's embedding row), or one profile trait
//! zeroed across a team. The parts overlap and don't add up; the seeds' spread is the range
const std = @import("std");
const data = @import("data.zig");
const tree = @import("tree.zig");
const ds = @import("core").draftscore;
const card = @import("card.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

const n_role = ds.n_role;

const W = struct {
    const title = plain("Set net");
    const lab = plain("Lab, not confirmed · each line is for its team; they overlap");
    const line = Phrase("Set net ×{n:int}: blue {p:rate} (seeds {lo:rate} to {hi:rate}), {d:points} on the Comp model");
    const what = plain("Swapped out");
    const side = plain("Team");
    const pp = plain("For that team");
    const seeds = plain("Seeds");
    const range = Phrase("{lo:points} to {hi:points}");
    const pick = Phrase("{n:text} for an average {r:text}");
    const trait = Phrase("Team {t:text}");
    const identity = plain("Every pick's own learnt row");
    const blue = plain("Blue");
    const red = plain("Red");
    const ok = Phrase("✓ {file:text}: {s:int} seeds, {n:int} reference games match");
    const bad = Phrase("✗ {file:text}: {n:int} reference games, worst {gap:text} off");
    const base_off = Phrase("{file:text}: fitted on another Comp model ({n:int} games, worst {gap:text} off), not shown");
    const failed = Phrase("{file:text}: not found");
    const damaged = Phrase("{file:text}: damaged");
    const loading = Phrase("{file:text}: …");
};

const roles = [n_role][]const u8{ "top", "jungle", "mid", "bot", "support" };

/// Words for a team high in profile feature f (lab/setnet.zig Feature)
const traits = std.StaticStringMap([]const u8).initComptime(.{
    .{ "magic", "magic damage share" },
    .{ "true_dmg", "true damage share" },
    .{ "dmg", "damage dealt" },
    .{ "tank", "damage mitigated" },
    .{ "taken", "damage taken" },
    .{ "armour", "armour over magic resist" },
    .{ "cc", "crowd control time" },
    .{ "immob", "immobilisations" },
    .{ "ally", "heals and shields on allies" },
    .{ "heal", "self-healing" },
    .{ "range", "attack range" },
    .{ "buildings", "damage to buildings" },
});

pub const Layout = struct { in: u32, rin: u32, c: u32, a: u32, b1: u32, cb: u32, e: u32, w1: u32, v: u32, out: u32, len: u32 };

/// A champion-role's embedding row
pub const Id = struct { champion: u32, role: u8, id: u32 };

/// A champion-role's z profile, n_prof long
pub const Profile = struct { champion: u32, role: u8, z: []const f32 };

/// The exporter's own logit for a game, given its base's
pub const Ref = struct { teams: [2][n_role]u32, platform: u8, offset: f32, logit: f32 };

pub const Net = struct {
    seed: u32,
    phi: u32,
    rho: u32,
    emb: u32,
    n_prof: u32,
    cross: bool,
    /// EUW1's c intercept: the Comp model scores on EUW1
    euw: u8,
    layout: Layout,
    params: []const f32,
    ids: []const Id,
    profiles: []const Profile,
    refs: []const Ref,
};

pub const Model = struct {
    candidate: []const u8,
    /// Games the nets were fitted on, and the newest (yyyy-mm-dd)
    fit_games: u32,
    fit_newest: []const u8,
    /// Profile features, in z order
    features: []const []const u8,
    nets: []const Net,
    /// The Comp model of the same export against the first seed's EUW1 reference offsets
    /// (testerbin.zig): the page shows the net only on the base it was fitted on
    base_games: u32 = 0,
    base_worst: f32 = 0,

    pub fn encode(m: Model, a: std.mem.Allocator, out: *std.ArrayList(u8)) !void {
        try data.encode(a, Model, m, out);
    }

    pub fn decode(a: std.mem.Allocator, bytes: []const u8) data.Error!Model {
        return data.decode(a, Model, bytes);
    }
};

const max_units = 256;
const max_in = 512;

/// How a forward pass departs from the draft: one trait zeroed across a side, or every
/// pick's embedding row swapped for its role's
pub const Edit = union(enum) { none, trait: struct { side: u1, f: u32 }, roles };

/// Lookups scan the lists: ten slots a pass, and no hash map code in ui.wasm
pub const Scorer = struct {
    n: *const Net,

    /// Checks the shape as draftfile.SetNet.parse does: a damaged file can't index out of
    /// the params
    pub fn init(n: *const Net) !Scorer {
        const l = n.layout;
        const n_ids = if (n.emb > 0) (l.w1 -| l.e) / n.emb else 0;
        const ok = l.len == n.params.len and l.in == n.n_prof + n_role + n.emb and
            l.rin == n.phi * @as(u32, if (n.cross) 2 else 1) and n.phi <= max_units and l.in <= max_in and
            l.c < l.a and n.euw < l.a - l.c and l.a < l.b1 and l.b1 + n.phi <= l.cb and l.cb + n.rho <= l.e and
            l.w1 + n.phi * l.in <= l.v and l.v + n.rho * l.rin <= l.out and l.out + n.rho <= l.len and
            (n.emb == 0 or n_ids >= n_role);
        if (!ok) return error.BadShape;
        for (n.ids) |x| if (x.role >= n_role or (n.emb > 0 and x.id >= n_ids)) return error.BadShape;
        for (n.profiles) |x| if (x.role >= n_role or x.z.len != n.n_prof) return error.BadShape;
        for (n.refs) |r| if (r.platform >= l.a - l.c) return error.BadShape;
        return .{ .n = n };
    }

    fn idOf(s: *const Scorer, champion: u32, r: usize) ?u32 {
        for (s.n.ids) |x| if (x.champion == champion and x.role == r) return x.id;
        return null;
    }

    fn profileOf(s: *const Scorer, champion: u32, r: usize) ?[]const f32 {
        for (s.n.profiles) |x| if (x.champion == champion and x.role == r) return x.z;
        return null;
    }

    /// Blue's logit for teams (0 empty) on platform index plat, given the base's blue
    /// logit; draftfile.SetNet.logit with an edit
    pub fn logit(s: *const Scorer, teams: [2][n_role]u32, plat: u8, base: f64, edit: Edit) f64 {
        const n = s.n;
        const p = n.params;
        const l = n.layout;
        var t: [2][max_units]f64 = @splat(@splat(0));
        var x: [max_in]f64 = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            const id = teams[side][r];
            const z: []const f32 = if (id != 0) s.profileOf(id, r) orelse &.{} else &.{};
            for (x[0..n.n_prof], 0..) |*o, i| o.* = if (z.len > 0) z[i] else 0;
            switch (edit) {
                .trait => |e| if (e.side == side and e.f < n.n_prof) {
                    x[e.f] = 0;
                },
                else => {},
            }
            for (x[n.n_prof..][0..n_role], 0..) |*o, i| o.* = @floatFromInt(@intFromBool(i == r));
            const emb_row: usize = if (id != 0 and edit != .roles) s.idOf(id, r) orelse r else r;
            for (x[n.n_prof + n_role ..][0..n.emb], p[l.e + emb_row * n.emb ..][0..n.emb]) |*o, e| o.* = e;
            for (t[side][0..n.phi], 0..) |*o, j| {
                var u: f64 = p[l.b1 + j];
                for (x[0..l.in], p[l.w1 + j * l.in ..][0..l.in]) |xi, w| u += w * xi;
                o.* += @max(u, 0) / n_role;
            }
        };
        var fs: [2]f64 = undefined;
        for (&fs, 0..) |*out, o| {
            var rin: [2 * max_units]f64 = undefined;
            @memcpy(rin[0..n.phi], t[o][0..n.phi]);
            if (n.cross) @memcpy(rin[n.phi..][0..n.phi], t[1 - o][0..n.phi]);
            out.* = 0;
            for (0..n.rho) |j| {
                var u: f64 = p[l.cb + j];
                for (rin[0..l.rin], p[l.v + j * l.rin ..][0..l.rin]) |ri, w| u += w * ri;
                if (u > 0) out.* += p[l.out + j] * u;
            }
        }
        return (fs[0] - fs[1]) / 2 + p[l.c + plat] + p[l.a] * base;
    }

    /// The reference games: max |logit diff|
    pub fn check(s: *const Scorer) f64 {
        var worst: f64 = 0;
        for (s.n.refs) |r| {
            const d = @abs(s.logit(r.teams, r.platform, r.offset, .none) - r.logit);
            if (!(d <= worst)) worst = if (std.math.isNan(d)) std.math.inf(f64) else d;
        }
        return worst;
    }
};

/// The page's forward pass against the export's: refs are f32, the old page's tolerance
pub const ref_tol = 1e-4;
/// Largest |logit diff| between the Comp model and the base the nets were fitted on: the
/// export leaves out pair cells on fewer than 20 games, which moves a few drafts slightly
pub const base_tol = 0.05;

pub const Check = struct {
    games: u32,
    worst: f64,
    /// The Comp model against the nets' fitted base on the EUW1 reference games
    base_games: u32 = 0,
    base_worst: f64 = 0,

    pub fn ok(c: Check) bool {
        return c.games > 0 and c.worst <= ref_tol;
    }

    pub fn sameBase(c: Check) bool {
        return c.base_games > 0 and c.base_worst <= base_tol;
    }
};

/// On the private site, beside the Comp model it corrects
pub const file = "/private/lab/draft-setnet.bin";

/// `failed`: not fetched (no lab net is usual); `bad`: fetched, didn't decode or score
pub const Load = union(enum) { none, loading, failed, bad, ready: *const Loaded };

pub const Loaded = struct {
    m: Model,
    sc: []Scorer,
    check: Check,

    /// In place: the scorers point into `l.m`. Decoded slices point into `bytes`
    pub fn init(l: *Loaded, a: std.mem.Allocator, bytes: []const u8) !void {
        l.m = try Model.decode(a, bytes);
        if (l.m.nets.len == 0 or l.m.nets.len > max_seeds or l.m.features.len > max_features) return error.BadShape;
        l.sc = try a.alloc(Scorer, l.m.nets.len);
        l.check = .{ .games = @intCast(l.m.nets[0].refs.len), .worst = 0, .base_games = l.m.base_games, .base_worst = l.m.base_worst };
        for (l.sc, l.m.nets) |*s, *n| {
            s.* = try .init(n);
            l.check.worst = @max(l.check.worst, s.check());
        }
    }

    /// Ready for the page: the forward pass matches and the Comp model is its base
    pub fn shown(l: *const Loaded) bool {
        return l.check.ok() and l.check.sameBase();
    }

    fn chances(l: *const Loaded, out: []f64, teams: [2][n_role]u32, base: f64, edit: Edit) []f64 {
        for (out[0..l.sc.len], l.sc) |*o, *s| o.* = sigmoid(s.logit(teams, s.n.euw, base, edit));
        return out[0..l.sc.len];
    }

    pub fn score(l: *const Loaded, teams: [2][n_role]u32, base: f64) Range {
        var buf: [max_seeds]f64 = undefined;
        return .of(l.chances(&buf, teams, base, .none), null);
    }

    /// The net's part (net minus base, points for blue) and what it comes from: each pick
    /// against its role's average, each team's traits zeroed one at a time, and every
    /// pick's own embedding row. Parts are points for their own side
    pub fn explain(l: *const Loaded, teams: [2][n_role]u32, base: f64) Explain {
        var full_buf: [max_seeds]f64 = undefined;
        var buf: [max_seeds]f64 = undefined;
        const full = l.chances(&full_buf, teams, base, .none);
        var x: Explain = .{ .net = undefined, .parts = undefined, .identity = null };
        for (0..2) |side| for (0..n_role) |r| {
            const id = teams[side][r];
            if (id == 0) continue;
            var u = teams;
            u[side][r] = 0;
            x.parts[x.n] = .{ .side = @intCast(side), .what = .{ .pick = .{ .champion = id, .role = @intCast(r) } }, .r = .of(l.chances(&buf, u, base, .none), .{ .full = full, .side = @intCast(side) }) };
            x.n += 1;
        };
        for (0..l.m.features.len) |f| for (0..2) |side| {
            const e: Edit = .{ .trait = .{ .side = @intCast(side), .f = @intCast(f) } };
            x.parts[x.n] = .{ .side = @intCast(side), .what = .{ .trait = @intCast(f) }, .r = .of(l.chances(&buf, teams, base, e), .{ .full = full, .side = @intCast(side) }) };
            x.n += 1;
        };
        var bases: [max_seeds]f64 = @splat(sigmoid(base));
        x.net = .of(bases[0..full.len], .{ .full = full, .side = 0 });
        if (l.m.nets[0].emb > 0) x.identity = .of(l.chances(&buf, teams, base, .roles), .{ .full = full, .side = 0 });
        return x;
    }
};

const max_seeds = 16;
const max_features = 16;

/// Seeds' mean and spread: chances, or with `from` points of `from.full` minus these for
/// `from.side`
pub const Range = struct {
    p: f64,
    lo: f64,
    hi: f64,

    const From = struct { full: []const f64, side: u1 };

    fn of(xs: []const f64, from: ?From) Range {
        var r: Range = .{ .p = 0, .lo = std.math.inf(f64), .hi = -std.math.inf(f64) };
        for (xs, 0..) |x, k| {
            const v = if (from) |f| @as(f64, if (f.side == 0) 100 else -100) * (f.full[k] - x) else x;
            r.p += v / @as(f64, @floatFromInt(xs.len));
            r.lo = @min(r.lo, v);
            r.hi = @max(r.hi, v);
        }
        return r;
    }
};

pub const Part = struct {
    side: u1,
    what: union(enum) { pick: struct { champion: u32, role: u8 }, trait: u32 },
    r: Range,
};

pub const Explain = struct {
    /// The net's part of blue's chance, points
    net: Range,
    /// Picks, then traits by feature and side
    parts: [2 * n_role + 2 * max_features]Part,
    n: usize = 0,
    identity: ?Range,
};

fn sigmoid(x: f64) f64 {
    return 1 / (1 + @exp(-x));
}

/// The line under the win split: the seeds' chance for blue and how far it moves the
/// Comp model's
pub fn line(h: *H, l: *const Loaded, comp: *const ds.Scorer, teams: [2][n_role]u32) N {
    const base = comp.rawLogit(teams);
    const s = l.score(teams, base);
    return h.p(.{ .class = "wait" }, .{W.line.with(h, .{
        .n = l.sc.len,
        .p = 100 * s.p,
        .lo = 100 * s.lo,
        .hi = 100 * s.hi,
        .d = 100 * (s.p - sigmoid(base)),
    })});
}

/// What the net's part comes from, largest first: picks and team traits over 0.1 points,
/// at most `rows`, then the champion-specific part
/// head: testerpage.Head, for champion names
pub fn breakdown(h: *H, l: *const Loaded, comp: *const ds.Scorer, teams: [2][n_role]u32, head: anytype, rows: usize) N {
    const x = l.explain(teams, comp.rawLogit(teams));
    var body = h.list();
    // The largest left each time: a few rows, no sort code in ui.wasm
    var used: [x.parts.len]bool = @splat(false);
    for (0..rows) |_| {
        var best: ?usize = null;
        for (x.parts[0..x.n], 0..) |pt, i| {
            if (!used[i] and @abs(pt.r.p) >= 0.1 and (best == null or @abs(pt.r.p) > @abs(x.parts[best.?].r.p))) best = i;
        }
        const i = best orelse break;
        used[i] = true;
        const pt = x.parts[i];
        const what: tree.Text = switch (pt.what) {
            .pick => |pk| W.pick.with(h, .{ .n = nameOf(head, pk.champion), .r = roles[pk.role] }),
            .trait => |f| W.trait.with(h, .{ .t = traits.get(l.m.features[f]) orelse l.m.features[f] }),
        };
        body.add(row(h, i, what, if (pt.side == 0) W.blue else W.red, pt.r));
    }
    if (x.identity) |r| body.add(row(h, x.parts.len, W.identity, W.blue, r));
    return card.view(h, .{ .flush = true, .label = W.title }, &.{
        card.head(h, W.title, W.lab, &.{}),
        h.table(.{ .class = "c-table" }, .{
            h.thead(.{}, .{h.tr(.{}, .{
                h.th(.{ .class = "l" }, .{W.what}),
                h.th(.{}, .{W.side}),
                h.th(.{ .data_answer = true }, .{W.pp}),
                h.th(.{}, .{W.seeds}),
            })}),
            h.tbody(.{}, .{body.done()}),
        }),
    });
}

fn nameOf(head: anytype, id: u32) []const u8 {
    for (head.champs) |c| if (c.id == id) return c.name;
    return "?";
}

fn row(h: *H, key: usize, what: tree.Text, side: tree.Text, r: Range) N {
    return h.tr(.{ .key = key }, .{
        h.td(.{ .class = "l" }, .{what}),
        h.td(.{}, .{side}),
        h.td(.{}, .{phrase.num(h, .points, r.p)}),
        h.td(.{}, .{W.range.with(h, .{ .lo = r.lo, .hi = r.hi })}),
    });
}

/// The tester's Files line for the set net
pub fn fileLine(h: *H, load: Load) tree.Text {
    return switch (load) {
        .ready => |l| if (!l.check.ok())
            W.bad.with(h, .{ .file = file, .n = l.check.games, .gap = gap(h, l.check.worst) })
        else if (!l.check.sameBase())
            W.base_off.with(h, .{ .file = file, .n = l.check.base_games, .gap = gap(h, l.check.base_worst) })
        else
            W.ok.with(h, .{ .file = file, .s = l.sc.len, .n = l.check.games }),
        .failed => W.failed.with(h, .{ .file = file }),
        .bad => W.damaged.with(h, .{ .file = file }),
        .none, .loading => W.loading.with(h, .{ .file = file }),
    };
}

/// Four decimals through ui/fmt.zig: std's float formatter is KBs of ui.wasm
fn gap(h: *H, x: f64) []const u8 {
    if (!std.math.isFinite(x)) return "?";
    var w: std.Io.Writer.Allocating = .init(h.mem);
    fmt.fixed(&w.writer, x, 4, false) catch {
        h.oom = true;
        return "?";
    };
    return w.written();
}

const testing = std.testing;

/// Two profile features, two embedding columns, two units each layer, cross; EUW1 second
pub fn testNet(params: []const f32, refs: []const Ref) Net {
    return .{
        .seed = 1,
        .phi = 2,
        .rho = 2,
        .emb = 2,
        .n_prof = 2,
        .cross = true,
        .euw = 1,
        .layout = .{ .in = 9, .rin = 4, .c = 0, .a = 2, .b1 = 3, .cb = 5, .e = 7, .w1 = 19, .v = 37, .out = 45, .len = 47 },
        .params = params,
        .ids = &.{ .{ .champion = 10, .role = 0, .id = 5 }, .{ .champion = 20, .role = 3, .id = 5 } },
        .profiles = &.{ .{ .champion = 10, .role = 0, .z = &.{ 1, -0.5 } }, .{ .champion = 20, .role = 3, .z = &.{ 0.3, 2 } } },
        .refs = refs,
    };
}

pub fn testParams() [47]f32 {
    var p: [47]f32 = undefined;
    for (&p, 0..) |*x, i| x.* = @floatCast(@sin(@as(f64, @floatFromInt(i)) * 1.7) * 0.8);
    return p;
}

test "set net: edits, the parts' signs, encoded and back" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const params = testParams();
    const nets = [_]Net{ testNet(&params, &.{}), testNet(&params, &.{}) };
    var out: std.ArrayList(u8) = .empty;
    try (Model{ .candidate = "win-additive", .fit_games = 10, .fit_newest = "2026-10-18", .features = &.{ "magic", "cc" }, .nets = &nets }).encode(a, &out);
    var l: Loaded = undefined;
    try l.init(a, out.items);
    try testing.expectEqual(2, l.sc.len);
    const s = &l.sc[0];
    var teams: [2][n_role]u32 = @splat(@splat(0));
    teams[0][0] = 10;
    teams[1][3] = 20;
    const full = s.logit(teams, 1, 0.2, .none);
    // An empty or unknown seat is the role's average: profile zero, the role's row
    var gone = teams;
    gone[0][0] = 0;
    var unknown = teams;
    unknown[0][0] = 99;
    try testing.expectEqual(s.logit(gone, 1, 0.2, .none), s.logit(unknown, 1, 0.2, .none));
    try testing.expect(full != s.logit(gone, 1, 0.2, .none));
    // Zeroing a trait of a team without profiles changes nothing
    var no_red = teams;
    no_red[1][3] = 0;
    try testing.expectEqual(s.logit(no_red, 1, 0.2, .none), s.logit(no_red, 1, 0.2, .{ .trait = .{ .side = 1, .f = 1 } }));
    // The base enters through a, the platform through c
    try testing.expectApproxEqAbs(params[2] * 0.5, s.logit(teams, 1, 0.7, .none) - s.logit(teams, 1, 0.2, .none), 1e-9);
    try testing.expectApproxEqAbs(params[1] - params[0], s.logit(teams, 1, 0.2, .none) - s.logit(teams, 0, 0.2, .none), 1e-9);

    // Same seeds: no spread. A red pick's part is red's points: blue's with its sign flipped
    const x = l.explain(teams, 0.2);
    try testing.expectEqual(x.net.lo, x.net.hi);
    try testing.expectApproxEqAbs(100 * (sigmoid(full) - sigmoid(0.2)), x.net.p, 1e-9);
    for (x.parts[0..x.n]) |pt| switch (pt.what) {
        .pick => |pk| if (pk.champion == 20) {
            try testing.expectEqual(1, pt.side);
            try testing.expectApproxEqAbs(-100 * (sigmoid(full) - sigmoid(s.logit(no_red, 1, 0.2, .none))), pt.r.p, 1e-9);
        },
        .trait => {},
    };
    try testing.expectEqual(2 + 2 * 2, x.n);
    try testing.expect(x.identity != null);
}

test "set net: a reference off the forward pass fails the check; a bad shape is refused" {
    const params = testParams();
    var teams: [2][n_role]u32 = @splat(@splat(0));
    teams[0][0] = 10;
    const s0 = try Scorer.init(&testNet(&params, &.{}));
    var refs = [_]Ref{.{ .teams = teams, .platform = 1, .offset = 0.1, .logit = @floatCast(s0.logit(teams, 1, 0.1, .none)) }};
    const n = testNet(&params, &refs);
    const s = try Scorer.init(&n);
    try testing.expect(s.check() <= ref_tol);
    refs[0].logit += 0.01;
    try testing.expect(s.check() > ref_tol);
    var bad = testNet(params[0..46], &.{});
    try testing.expectError(error.BadShape, Scorer.init(&bad));
    bad = testNet(&params, &.{});
    bad.euw = 2;
    try testing.expectError(error.BadShape, Scorer.init(&bad));
}
