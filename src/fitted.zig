//! The draft model the site and app score with: additive v2 without its damage mix
//! (src/additive.zig; the mix needs seat stats the box doesn't keep), fitted on a stats
//! file's own played games and written into it (core.statsfile version 2), where
//! core.score reads one value per term. `meiolol eval` scores the same fit
//! ("additive v2, no damage mix"). The side intercept is fitted but not shipped:
//! suggestions are side-free. Pair cells on fewer than pair_floor games are shipped as 0
//! (they hold ~nothing after shrinkage, and zeros keep the download small).
//! With kit classes (off by default; docs/plan/data-and-model.md "Ship A4"), pair
//! cells borrow strength from parents (additive.Parents, docs/model.md "Pair cells that
//! borrow strength (A4)"): the floor applies to a cell's own part, and every cell of the
//! dense tables gets its parents, seen in its slot or not

const std = @import("std");
const core = @import("core");
const additive = @import("additive.zig");

const statsfile = core.statsfile;
const log = std.log.scoped(.fitted);
const n_role = additive.n_role;

/// Shorter games are left out of the fit, as eval and the lab do
pub const min_duration_s = 900;
/// The lab's draft export's (lab/draft.zig default_pair_floor)
pub const pair_floor = 20;

pub const Fit = struct {
    games: []additive.GameIn,
    p: additive.Problem,
    f: additive.Fit,

    /// Owns `games`. Cells under pair_floor are 0 after the fit, as shipped; with
    /// `classes`, their parents stay
    pub fn init(gpa: std.mem.Allocator, games: []additive.GameIn, classes: ?[]const additive.KitClass) !Fit {
        var p = try additive.build(gpa, .logistic, additive.Variant.mains().matchupGroups(), games);
        errdefer p.deinit(gpa);
        if (classes) |c| try p.addParents(gpa, c);
        const f = try additive.fit(gpa, &p, .{}, null, null);
        for (p.param_start[additive.g_ally]..p.n_params()) |j| {
            if (p.count[j] < pair_floor) f.theta[j] = 0;
        }
        if (p.parents) |*x| log.info("pair parents: {d} kit, {d} pair; {d} parent steps halved", .{ x.n_kit, x.group.len - x.n_kit, f.parent_halvings });
        return .{ .games = games, .p = p, .f = f };
    }

    pub fn deinit(fit: *Fit, gpa: std.mem.Allocator) void {
        fit.f.deinit(gpa);
        fit.p.deinit(gpa);
        gpa.free(fit.games);
    }

    /// Blue's logit, with the platform's side term
    pub fn logit(fit: *const Fit, teams: [2][n_role]u32, platform: u8) f64 {
        return additive.predict(&fit.p, &fit.f, &.{ .teams = teams, .platform = platform, .y = 0 });
    }

    /// Writes the fit into b.fitted: each pair oriented both ways, so a term is one read.
    /// Champions the builder doesn't know are left out
    pub fn attach(fit: *const Fit, gpa: std.mem.Allocator, b: *statsfile.Builder) !void {
        const n = b.ids.len;
        const out = try gpa.alloc(f32, statsfile.fittedLen(n));
        errdefer gpa.free(out);
        @memset(out, 0);
        const ally = out[statsfile.fittedAllyAt(n)..];
        const enemy = out[statsfile.fittedEnemyAt(n)..];
        const p = &fit.p;
        for (0..p.n_params()) |j| {
            const cl = additive.cellOf(p, j);
            if (cl.group < additive.g_main) continue;
            const theta: f32 = @floatCast(fit.f.theta[j]);
            const a = b.index.get(cl.a) orelse continue;
            if (cl.group < additive.g_ally) {
                out[(cl.group - additive.g_main) * n + a] = theta;
                continue;
            }
            const c = b.index.get(cl.b) orelse continue;
            const g = additive.groupRoles(cl.group);
            const at = statsfile.fittedPair;
            if (g.ally) {
                ally[at(n, g.r, g.q, a, c)] = theta;
                ally[at(n, g.q, g.r, c, a)] = theta;
            } else {
                // From the r side; a lane cell is the lower champion id's side (cl.a)
                enemy[at(n, g.r, g.q, a, c)] = theta;
                enemy[at(n, g.q, g.r, c, a)] = -theta;
            }
        }
        if (p.parents) |*pa| {
            const at = statsfile.fittedPair;
            for (additive.g_ally..additive.g_offset) |grp| {
                if (!p.variant.has(grp)) continue;
                const g = additive.groupRoles(grp);
                const same = !g.ally and g.r == g.q;
                for (b.ids, 0..) |ida, a| for (b.ids, 0..) |idc, c| {
                    // A same-role cell is the lower id's side (cl.a above)
                    if (ida == idc or (same and ida > idc)) continue;
                    const v: f32 = @floatCast(pa.value(fit.f.parent, grp, ida, idc));
                    if (g.ally) {
                        ally[at(n, g.r, g.q, a, c)] += v;
                        ally[at(n, g.q, g.r, c, a)] += v;
                    } else {
                        enemy[at(n, g.r, g.q, a, c)] += v;
                        enemy[at(n, g.q, g.r, c, a)] -= v;
                    }
                };
            }
        }
        if (b.fitted) |old| gpa.free(old);
        b.fitted = out;
    }
};

/// Collects a scan's played games for a Fit
pub const Games = struct {
    gpa: std.mem.Allocator,
    list: std.ArrayList(additive.GameIn) = .empty,
    /// Set: pair cells borrow strength (Fit.init)
    classes: ?[]const additive.KitClass = null,

    pub fn add(g: *Games, teams: [2][n_role]u32, winner: u1, platform: u8, duration_s: u32) !void {
        if (duration_s < min_duration_s) return;
        if (platform >= additive.n_platforms) return error.TooManyPlatforms;
        try g.list.append(g.gpa, .{ .teams = teams, .platform = platform, .y = if (winner == 0) 1 else 0 });
    }

    /// Fits and writes into `b`; no played games leave it without a fitted section
    pub fn attachTo(g: *Games, b: *statsfile.Builder) !void {
        if (g.list.items.len == 0) return;
        var fit: Fit = try .init(g.gpa, try g.list.toOwnedSlice(g.gpa), g.classes);
        defer fit.deinit(g.gpa);
        try fit.attach(g.gpa, b);
    }

    pub fn deinit(g: *Games) void {
        g.list.deinit(g.gpa);
    }
};

const testing = std.testing;

test "the stats file's fitted terms score drafts as the fit, less the side term" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(11);
    const rnd = rng.random();
    var champs: [12]statsfile.Champion = undefined;
    var names: [12][2]u8 = undefined;
    for (&champs, &names, 0..) |*c, *nm, i| {
        nm.* = .{ 'A' + @as(u8, @intCast(i)), 0 };
        c.* = .{ .id = @intCast(3 * i + 1), .name = nm[0..1] };
    }
    var b: statsfile.Builder = try .init(gpa, &champs);
    defer b.deinit();
    var games: Games = .{ .gpa = gpa };
    defer games.deinit();
    for (0..3000) |_| {
        var teams: [2][n_role]u32 = undefined;
        var pick: [12]u32 = undefined;
        for (&pick, champs) |*x, c| x.* = c.id;
        rnd.shuffle(u32, &pick);
        for (0..2) |s| for (0..n_role) |r| {
            teams[s][r] = pick[s * n_role + r];
        };
        // Champion 1 strong, 4 with 7 a strong duo
        var x: f64 = 0;
        for (0..2) |s| {
            const sign: f64 = if (s == 0) 1 else -1;
            for (teams[s]) |id| if (id == 1) {
                x += sign * 0.6;
            };
            if (std.mem.findScalar(u32, &teams[s], 4) != null and std.mem.findScalar(u32, &teams[s], 7) != null) x += sign * 0.5;
        }
        const winner: u1 = if (rnd.float(f64) < 1 / (1 + @exp(-x))) 0 else 1;
        b.addGame(teams, winner);
        try games.add(teams, winner, @intCast(rnd.uintLessThan(u8, 3)), 1800);
    }
    try games.add(games.list.items[0].teams, 0, 0, 600);
    try testing.expectEqual(3000, games.list.items.len);

    var fit: Fit = try .init(gpa, try gpa.dupe(additive.GameIn, games.list.items), null);
    defer fit.deinit(gpa);
    try fit.attach(gpa, &b);
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "16.20");
    var st: statsfile.Stats = try .parse(gpa, aw.written());
    defer st.deinit(gpa);

    for (games.list.items[0..200]) |g| {
        const want = fit.logit(g.teams, g.platform) - fit.f.theta[g.platform];
        const p = core.score.draftWin(&st, .{}, g.teams);
        try testing.expectApproxEqAbs(1 / (1 + @exp(-want)), p, 1e-3);
    }
    const one = st.index(1).?;
    var strong: f64 = 0;
    for (core.Role.all) |r| strong = @max(strong, st.fittedBase(r, one).?);
    try testing.expect(strong > 0.2);
}

test "with kit classes, the stats file carries each pair's parents in every slot" {
    const gpa = testing.allocator;
    var rng: std.Random.DefaultPrng = .init(12);
    const rnd = rng.random();
    var champs: [12]statsfile.Champion = undefined;
    var names: [12][2]u8 = undefined;
    var classes: [12]additive.KitClass = undefined;
    for (&champs, &names, &classes, 0..) |*c, *nm, *k, i| {
        nm.* = .{ 'A' + @as(u8, @intCast(i)), 0 };
        c.* = .{ .id = @intCast(3 * i + 1), .name = nm[0..1] };
        k.* = .{ .id = c.id, .class = @intCast(i % 3) };
    }
    var b: statsfile.Builder = try .init(gpa, &champs);
    defer b.deinit();
    var games: Games = .{ .gpa = gpa, .classes = &classes };
    defer games.deinit();
    for (0..4000) |_| {
        var teams: [2][n_role]u32 = undefined;
        var pick: [12]u32 = undefined;
        for (&pick, champs) |*x, c| x.* = c.id;
        rnd.shuffle(u32, &pick);
        for (0..2) |s| for (0..n_role) |r| {
            teams[s][r] = pick[s * n_role + r];
        };
        // Champion 4 beats 7 wherever they meet
        var x: f64 = 0;
        const b4 = std.mem.findScalar(u32, &teams[0], 4) != null;
        const r7 = std.mem.findScalar(u32, &teams[1], 7) != null;
        const r4 = std.mem.findScalar(u32, &teams[1], 4) != null;
        const b7 = std.mem.findScalar(u32, &teams[0], 7) != null;
        if (b4 and r7) x += 0.6;
        if (r4 and b7) x -= 0.6;
        const winner: u1 = if (rnd.float(f64) < 1 / (1 + @exp(-x))) 0 else 1;
        b.addGame(teams, winner);
        try games.add(teams, winner, 0, 1800);
    }
    var fit: Fit = try .init(gpa, try gpa.dupe(additive.GameIn, games.list.items), &classes);
    defer fit.deinit(gpa);
    try testing.expect(fit.p.parents != null);
    try fit.attach(gpa, &b);
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try b.write(&aw.writer, "16.20");
    var st: statsfile.Stats = try .parse(gpa, aw.written());
    defer st.deinit(gpa);
    for (games.list.items[0..200]) |g| {
        const want = fit.logit(g.teams, g.platform) - fit.f.theta[g.platform];
        try testing.expectApproxEqAbs(1 / (1 + @exp(-want)), core.score.draftWin(&st, .{}, g.teams), 1e-3);
    }
    // The counter in a slot pair as thin as any (top against support)
    const teams: [2][n_role]u32 = .{ .{ 4, 1, 10, 13, 16 }, .{ 19, 22, 25, 28, 7 } };
    const want = fit.logit(teams, 0) - fit.f.theta[0];
    try testing.expectApproxEqAbs(1 / (1 + @exp(-want)), core.score.draftWin(&st, .{}, teams), 1e-3);
    try testing.expect(want > 0.1);
}
