//! `meiolol-lab compcheck SNAP`: model-free cross-check of team composition effects on
//! win (comp features campaign, docs/model.md). The compiled-in candidate must be
//! win-ratings (-Dcand=src/lab/cand/win-ratings): its dev predictions are the offset, so
//! the check asks what ratings misses, from the same build and on the same rows as any
//! candidate's dev run. Each dev game gives two team units (observed win minus predicted
//! chance, opposite signs), binned by the team's composition; profiles are per-minute
//! means of seat stats over the dev phase's visible games only (older than every scored
//! game), never a scored game's own stats. Means and contrasts with 95% intervals
//! clustered by game. Positive control first: a champion-role's training lift removed
//! from the offset must reappear in the bin of teams that have it.
//! Writes compcheck.tsv (one line per team unit) in the working directory

const std = @import("std");
const api = @import("api");
const cand = @import("cand");
const rows = @import("rows.zig");
const protocol = @import("protocol.zig");
const harness = @import("harness.zig");
const seatstats = @import("seatstats.zig");

const Io = std.Io;
const Stat = seatstats.SeatStat;

pub const usage =
    \\  compcheck SNAP [--folds K]      dev only, built with -Dcand=src/lab/cand/win-ratings:
    \\                                  observed minus win-ratings' predicted win by team
    \\                                  composition (profiles from dev's training games),
    \\                                  intervals clustered by game (lab/compcheck.zig);
    \\                                  --folds: win-comp's forward-chaining folds instead
    \\
;

/// Profile rows a champion-role needs before it stands alone; below, the champion's
/// all-role profile, then the role's
const min_profile_rows = 30;
/// A champion-role is frontline when its damage taken plus mitigated per minute is in
/// the top share of picks
const frontline_share = 0.2;
/// Positive control: champion-roles with this many training rows, and this many dev teams
const control_min_train = 2000;
const control_min_dev = 300;
/// Pseudo-games at 50% in the control's training lift (harness's win prior)
const control_prior = 1000;

const role_names = [_][]const u8{ "top", "jungle", "middle", "bottom", "utility" };

/// Per-minute rates of a profile
const Profile = struct {
    phys: f64,
    magic: f64,
    true_dmg: f64,
    /// Taken (all types) plus self-mitigated
    tank: f64,
    /// Mitigated / (mitigated + taken), as win-comp's frontline
    mitigated_share: f64,
    cc: f64,
    immob: f64,
    heal_shield_allies: f64,
    buildings: f64,
    /// Mean armour minus MR at the end (base at level 15 plus items held), not a rate
    armour_lean: f64,
};

const Acc = struct {
    rows: u32 = 0,
    sum: [seatstats.count]f64 = @splat(0),
    minutes: [seatstats.count]f64 = @splat(0),
    n: [seatstats.count]f64 = @splat(0),

    fn add(a: *Acc, s: seatstats.Stats) void {
        const m = s[at(.minutes)];
        if (std.math.isNan(m) or m <= 0) return;
        a.rows += 1;
        for (s, &a.sum, &a.minutes, &a.n) |v, *sum, *mins, *n| if (!std.math.isNan(v)) {
            sum.* += v;
            mins.* += m;
            n.* += 1;
        };
    }

    fn rate(a: Acc, s: Stat) f64 {
        const m = a.minutes[at(s)];
        return if (m > 0) a.sum[at(s)] / m else 0;
    }

    fn mean(a: Acc, s: Stat) f64 {
        const n = a.n[at(s)];
        return if (n > 0) a.sum[at(s)] / n else 0;
    }

    fn profile(a: Acc) Profile {
        return .{
            .phys = a.rate(.dmg_phys),
            .magic = a.rate(.dmg_magic),
            .true_dmg = a.rate(.dmg_true),
            .tank = a.rate(.taken_phys) + a.rate(.taken_magic) + a.rate(.taken_true) + a.rate(.mitigated),
            .mitigated_share = blk: {
                const taken = a.rate(.taken_phys) + a.rate(.taken_magic) + a.rate(.taken_true);
                const mit = a.rate(.mitigated);
                break :blk if (mit + taken > 0) mit / (mit + taken) else 0;
            },
            .cc = a.rate(.cc_time),
            .immob = a.rate(.immobilisations),
            .heal_shield_allies = a.rate(.heal_allies) + a.rate(.shield_allies),
            .buildings = a.rate(.dmg_buildings),
            .armour_lean = a.mean(.armor_end) - a.mean(.mr_end),
        };
    }
};

fn at(s: Stat) usize {
    return @backingInt(s);
}

fn cellKey(champion: u32, role: usize) u64 {
    return (@as(u64, champion) << 3) | role;
}

const Profiles = struct {
    cells: std.AutoHashMapUnmanaged(u64, Acc) = .empty,
    champs: std.AutoHashMapUnmanaged(u32, Acc) = .empty,
    roles: [5]Acc = @splat(.{}),
    /// Lookups that fell back to the champion's or the role's profile
    fallback_champ: usize = 0,
    fallback_role: usize = 0,

    fn deinit(p: *Profiles, gpa: std.mem.Allocator) void {
        p.cells.deinit(gpa);
        p.champs.deinit(gpa);
    }

    fn get(p: *Profiles, champion: u32, role: usize) Profile {
        if (p.cells.get(cellKey(champion, role))) |a| if (a.rows >= min_profile_rows) return a.profile();
        if (p.champs.get(champion)) |a| if (a.rows >= min_profile_rows) {
            p.fallback_champ += 1;
            return a.profile();
        };
        p.fallback_role += 1;
        return p.roles[role].profile();
    }
};

/// One team in one dev game
const Unit = struct {
    game: u32,
    side: u1,
    y: f64,
    /// win-ratings' chance for this team
    p: f64,
    magic_share: f64,
    phys_share: f64,
    frontline: u8,
    /// The team's highest mitigated share
    best_mitigated: f64,
    /// Sum of the team's champion-roles' training lifts (log-odds) minus the enemy's
    lift_diff: f64,
    cc: f64,
    enemy_magic_share: f64,
    enemy_frontline: u8,
    /// Sum over the team of armour lean minus its role's mean
    armour_lean: f64,
};

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    const folds: u8 = switch (argv.len) {
        1 => 0,
        3 => if (std.mem.eql(u8, argv[1], "--folds")) std.fmt.parseInt(u8, argv[2], 10) catch 0 else 0,
        else => 0,
    };
    if (argv.len != 1 and folds == 0) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    if (!@hasDecl(cand, "name") or !std.mem.eql(u8, cand.name, "win-ratings")) {
        std.debug.print("compcheck: build with -Dcand=src/lab/cand/win-ratings (its dev predictions are the offset)\n", .{});
        return 2;
    }
    const snap = argv[0];
    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    const players = try harness.gamePlayers(gpa, &data);
    defer gpa.free(players);
    const ids = protocol.platformIds();
    const eu: u8 = for (ids, 0..) |id, i| {
        if (std.mem.eql(u8, id, protocol.test_platform)) break @intCast(i);
    } else return error.TestPlatformNotScanned;
    const c = try harness.cuts(gpa, &data, eu);

    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    var units: std.ArrayList(Unit) = .empty;
    defer units.deinit(gpa);
    var wins: Wins = .empty;
    defer wins.deinit(gpa);
    if (folds == 0) {
        try w.print("# compcheck, dev (scored: EUW1 dev-val; profiles: visible games before the dev cut)\n\n", .{});
        try addUnits(gpa, &data, players, c, .{ .before = c.dev }, &units, &wins, w);
    } else {
        // foldAblation's blocks (win-comp): the newest half of dev's visible games, every
        // platform, in `folds` blocks by start; each fitted on the games before it
        var starts: std.ArrayList(i64) = .empty;
        defer starts.deinit(gpa);
        for (data.games) |g| if (harness.visible(.dev, c, g)) try starts.append(gpa, g.start);
        std.mem.sort(i64, starts.items, {}, std.sort.asc(i64));
        try w.print("# compcheck, {d} forward-chaining folds over the newest half of dev's visible games (every platform; offset and profiles refitted per fold on older games)\n\n", .{folds});
        for (0..folds) |f| {
            const quantile = struct {
                fn q(xs: []const i64, x: f64) i64 {
                    if (x >= 1) return c_dev_sentinel;
                    return xs[@intFromFloat(@as(f64, @floatFromInt(xs.len)) * x)];
                }
            }.q;
            const fi: f64 = @floatFromInt(f);
            const k: f64 = @floatFromInt(folds);
            const lo = quantile(starts.items, 0.5 + 0.5 * fi / k);
            const hi = @min(quantile(starts.items, 0.5 + 0.5 * (fi + 1) / k), c.dev);
            wins.clearRetainingCapacity();
            try w.print("fold {d}: ", .{f + 1});
            try addUnits(gpa, &data, players, c, .{ .before = lo, .block = .{ lo, hi } }, &units, &wins, w);
        }
    }
    try analyse(gpa, arena, io, &data, units.items, if (folds == 0) &wins else null, w);
    try w.flush();
    return 0;
}

/// Later than any game: the last fold runs to the dev cut
const c_dev_sentinel = std.math.maxInt(i64);

const Wins = std.AutoHashMapUnmanaged(u64, [2]f64);

/// Profiles, lifts and the offset from games before `before`; scored: dev-val (block
/// null, harness.score as exp run does) or every visible game in [block[0], block[1])
const Source = struct {
    before: i64,
    block: ?[2]i64 = null,
};

fn addUnits(
    gpa: std.mem.Allocator,
    d: *const rows.Data,
    players: []const harness.Players,
    c: harness.Cuts,
    src: Source,
    units: *std.ArrayList(Unit),
    wins: *Wins,
    w: *Io.Writer,
) !void {
    // The training side: visible as dev's are, before src.before
    const fit_cuts: harness.Cuts = .{ .dev = src.before, .select = src.before, .eu = c.eu };
    var prof: Profiles = .{};
    defer prof.deinit(gpa);
    var visible_rows: usize = 0;
    var with_stats: usize = 0;
    for (d.rows) |r| {
        if (!harness.visible(.dev, fit_cuts, d.games[r.game])) continue;
        visible_rows += 1;
        const role: usize = @backingInt(r.role);
        const cell = try prof.cells.getOrPutValue(gpa, cellKey(r.champion, role), .{});
        const before = cell.value_ptr.rows;
        cell.value_ptr.add(r.stats);
        if (cell.value_ptr.rows > before) {
            with_stats += 1;
            (try prof.champs.getOrPutValue(gpa, r.champion, .{})).value_ptr.add(r.stats);
            prof.roles[role].add(r.stats);
        }
        const wr = try wins.getOrPutValue(gpa, cellKey(r.champion, role), .{ 0, 0 });
        wr.value_ptr[0] += r.y[api.outcomeIndex(.win)];
        wr.value_ptr[1] += 1;
    }
    try w.print("training rows {d}, with seat stats {d} ({d:.1}%)\n", .{
        visible_rows, with_stats, pct(with_stats, visible_rows),
    });
    if (with_stats == 0) return error.NoSeatStats;

    // Frontline threshold: top share of visible picks by their champion-role's tankiness
    var tanks: std.ArrayList(f64) = .empty;
    defer tanks.deinit(gpa);
    for (d.rows) |r| {
        if (!harness.visible(.dev, fit_cuts, d.games[r.game])) continue;
        try tanks.append(gpa, prof.get(r.champion, @backingInt(r.role)).tank);
    }
    std.mem.sort(f64, tanks.items, {}, std.sort.asc(f64));
    const tank_cut = tanks.items[@intFromFloat(@as(f64, @floatFromInt(tanks.items.len)) * (1 - frontline_share))];
    prof.fallback_champ = 0;
    prof.fallback_role = 0;
    var role_lean: [5]f64 = undefined;
    for (&role_lean, prof.roles) |*l, a| l.* = a.profile().armour_lean;

    // The offset: win-ratings' chance for blue per scored game (mean of its rows)
    const blue_sum = try gpa.alloc(f64, d.games.len);
    defer gpa.free(blue_sum);
    const blue_n = try gpa.alloc(f64, d.games.len);
    defer gpa.free(blue_n);
    @memset(blue_sum, 0);
    @memset(blue_n, 0);
    try offset(gpa, d, players, c, src, blue_sum, blue_n);

    const first = units.items.len;
    for (d.games, 0..) |g, gi| {
        if (blue_n[gi] == 0) continue;
        const pb = blue_sum[gi] / blue_n[gi];
        var feats: [2]struct { phys: f64, magic: f64, front: u8, cc: f64, lean: f64, best_mit: f64, lift: f64 } = undefined;
        for (&feats, g.teams) |*f, team| {
            var phys: f64 = 0;
            var magic: f64 = 0;
            var true_dmg: f64 = 0;
            f.* = .{ .phys = 0, .magic = 0, .front = 0, .cc = 0, .lean = 0, .best_mit = 0, .lift = 0 };
            for (team, 0..) |champ, role| {
                const p = prof.get(champ, role);
                phys += p.phys;
                magic += p.magic;
                true_dmg += p.true_dmg;
                f.cc += p.cc;
                f.lean += p.armour_lean - role_lean[role];
                if (p.tank >= tank_cut) f.front += 1;
                f.best_mit = @max(f.best_mit, p.mitigated_share);
                f.lift += liftOf(wins, champ, role);
            }
            f.magic = magic / (phys + magic + true_dmg);
            f.phys = phys / (phys + magic + true_dmg);
        }
        for (0..2) |s| {
            const side: u1 = @intCast(s);
            const y: f64 = if (g.winner == side) 1 else 0;
            try units.append(gpa, .{
                .game = @intCast(gi),
                .side = side,
                .y = y,
                .p = if (side == 0) pb else 1 - pb,
                .magic_share = feats[s].magic,
                .phys_share = feats[s].phys,
                .frontline = feats[s].front,
                .best_mitigated = feats[s].best_mit,
                .lift_diff = feats[s].lift - feats[1 - s].lift,
                .cc = feats[s].cc,
                .enemy_magic_share = feats[1 - s].magic,
                .enemy_frontline = feats[1 - s].front,
                .armour_lean = feats[s].lean,
            });
        }
    }
    const added = units.items.len - first;
    try w.print("scored games {d}; profile fallbacks: champion {d}, role {d} of {d} picks; frontline: taken + mitigated >= {d:.0}/min (top {d:.0}% of picks)\n", .{
        added / 2, prof.fallback_champ, prof.fallback_role, added * 5, tank_cut, frontline_share * 100,
    });
}

fn offset(
    gpa: std.mem.Allocator,
    d: *const rows.Data,
    players: []const harness.Players,
    c: harness.Cuts,
    src: Source,
    blue_sum: []f64,
    blue_n: []f64,
) !void {
    const k = api.outcomeIndex(.win);
    const block = src.block orelse {
        var scores = try harness.score(cand, gpa, d, players, c, .dev, .{});
        defer scores.deinit(gpa);
        for (scores.row, scores.cand) |ri, pred| {
            const r = d.rows[ri];
            blue_sum[r.game] += if (r.side == 0) pred[k] else 1 - pred[k];
            blue_n[r.game] += 1;
        }
        return;
    };
    // As harness.score: the same seeds, the same query
    const fit_cuts: harness.Cuts = .{ .dev = src.before, .select = src.before, .eu = c.eu };
    var v = try harness.buildTrain(gpa, d, players, .dev, fit_cuts, 1, false);
    defer v.deinit();
    const n_seeds: u64 = if (@hasDecl(cand, "seeded") and cand.seeded) 3 else 1;
    const sum = try gpa.alloc(f64, d.rows.len);
    defer gpa.free(sum);
    @memset(sum, 0);
    for (1..n_seeds + 1) |seed| {
        var m = try cand.fit(gpa, &v.train, .{ .seed = seed });
        defer cand.deinit(&m, gpa);
        for (d.rows, sum) |r, *acc| {
            const g = d.games[r.game];
            if (!inBlock(c, block, g)) continue;
            const q = harness.query(cand.scope, g, players[r.game], r, false);
            acc.* += cand.predict(&m, &q)[k];
        }
    }
    for (d.rows, sum) |r, acc| {
        if (!inBlock(c, block, d.games[r.game])) continue;
        const p = acc / @as(f64, @floatFromInt(n_seeds));
        blue_sum[r.game] += if (r.side == 0) p else 1 - p;
        blue_n[r.game] += 1;
    }
}

fn inBlock(c: harness.Cuts, block: [2]i64, g: rows.Game) bool {
    return harness.visible(.dev, c, g) and g.start >= block[0] and g.start < block[1];
}

fn analyse(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: Io,
    d: *const rows.Data,
    unit_list: []const Unit,
    plumbing: ?*const Wins,
    w: *Io.Writer,
) !void {
    const n_units = unit_list.len;
    const units: struct { items: []const Unit } = .{ .items = unit_list };
    try w.print("\nteam units {d} ({d} games)\n\n", .{ n_units, n_units / 2 });
    try writeUnits(io, d, unit_list);

    const resid = try gpa.alloc(f64, n_units);
    defer gpa.free(resid);
    for (resid, units.items) |*r, u| r.* = u.y - u.p;
    const in_a = try gpa.alloc(bool, n_units);
    defer gpa.free(in_a);
    const in_b = try gpa.alloc(bool, n_units);
    defer gpa.free(in_b);
    const group = try gpa.alloc(?u1, n_units);
    defer gpa.free(group);
    const raw = try gpa.alloc(f64, n_units);
    defer gpa.free(raw);
    for (raw, units.items) |*r, u| r.* = u.y - 0.5;
    const res: Res = .{ .model = resid, .raw = raw };

    try strengthControl(gpa, arena, units.items, resid, in_a, w);
    if (plumbing) |wins| try control(gpa, d, wins, units.items, resid, in_a, w);

    // H1: team magic share of damage
    {
        const edges = [_]f64{ 0, 0.2, 0.4, 0.6, 2 };
        try w.writeAll("## Team magic share of damage to champions\n\n");
        try tableHead(w, "magic share");
        for (0..4) |b| {
            for (in_a, units.items) |*a, u| a.* = u.magic_share >= edges[b] and u.magic_share < edges[b + 1];
            try binRow(w, try std.fmt.allocPrint(arena, "{d:.0}-{d:.0}%", .{ edges[b] * 100, @min(edges[b + 1], 1) * 100 }), units.items, res, in_a);
        }
        for (in_a, in_b, units.items) |*a, *b, u| {
            a.* = u.magic_share < 0.2 or u.magic_share >= 0.6;
            b.* = !a.*;
        }
        try contrastLine(w, "lopsided (<20% or 60%+) minus balanced", units.items, res, in_a, in_b);
        try w.writeAll("\n");
    }
    // H1b: physical share in iTero's bins (research: about -9 pp under 20% AD and -6 pp
    // over 80%, unadjusted)
    {
        const edges = [_]f64{ 0, 0.2, 0.8, 2 };
        const names = [_][]const u8{ "<20%", "20-80%", "80%+" };
        try w.writeAll("## Team physical share of damage to champions (iTero's bins)\n\n");
        try tableHead(w, "physical share");
        for (0..3) |b| {
            for (in_a, units.items) |*a, u| a.* = u.phys_share >= edges[b] and u.phys_share < edges[b + 1];
            try binRow(w, names[b], units.items, res, in_a);
        }
        for (in_a, in_b, units.items) |*a, *b, u| {
            a.* = u.phys_share < 0.2 or u.phys_share >= 0.8;
            b.* = !a.*;
        }
        try contrastLine(w, "lopsided (<20% or 80%+) minus 20-80%", units.items, res, in_a, in_b);
        try w.writeAll("\n");
    }
    // H2: frontline count
    {
        try w.writeAll("## Frontline champions in the team\n\n");
        try tableHead(w, "frontline");
        for (0..4) |b| {
            for (in_a, units.items) |*a, u| a.* = if (b == 3) u.frontline >= 3 else u.frontline == b;
            try binRow(w, try std.fmt.allocPrint(arena, "{d}{s}", .{ b, if (b == 3) "+" else "" }), units.items, res, in_a);
        }
        for (in_a, in_b, units.items) |*a, *b, u| {
            a.* = u.frontline == 0;
            b.* = u.frontline > 0;
        }
        try contrastLine(w, "none minus some", units.items, res, in_a, in_b);
        try w.writeAll("\n");
    }
    // H2b: win-comp's frontline form, the team's best mitigated share, quartiles
    {
        const q = try quantiles(4, "best_mitigated", gpa, units.items);
        try w.writeAll("## Team's best mitigated share (damage mitigated / (mitigated + taken))\n\n");
        try tableHead(w, "best mitigated quartile");
        const edges = [_]f64{ -1, q[0], q[1], q[2], 2 };
        for (0..4) |b| {
            for (in_a, units.items) |*a, u| a.* = u.best_mitigated > edges[b] and u.best_mitigated <= edges[b + 1];
            try binRow(w, try std.fmt.allocPrint(arena, "Q{d} ({d:.2}-{d:.2})", .{ b + 1, @max(edges[b], 0), @min(edges[b + 1], 1) }), units.items, res, in_a);
        }
        for (in_a, in_b, units.items) |*a, *b, u| {
            a.* = u.best_mitigated <= q[0];
            b.* = u.best_mitigated > q[0];
        }
        try contrastLine(w, "lowest quartile minus the rest", units.items, res, in_a, in_b);
        try w.writeAll("\n");
    }
    // H3: team CC, quartiles of the dev teams (a draft feature, no outcome in it)
    {
        const q = try quantiles(4, "cc", gpa, units.items);
        try w.writeAll("## Team crowd control (time CCing others per minute, summed)\n\n");
        try tableHead(w, "CC quartile");
        const edges = [_]f64{ -1, q[0], q[1], q[2], std.math.inf(f64) };
        for (0..4) |b| {
            for (in_a, units.items) |*a, u| a.* = u.cc > edges[b] and u.cc <= edges[b + 1];
            try binRow(w, try std.fmt.allocPrint(arena, "Q{d} ({d:.1}-{d:.1})", .{ b + 1, @max(edges[b], 0), @min(edges[b + 1], 999) }), units.items, res, in_a);
        }
        for (in_a, in_b, units.items) |*a, *b, u| {
            a.* = u.cc <= q[0];
            b.* = u.cc > q[0];
        }
        try contrastLine(w, "lowest quartile minus the rest", units.items, res, in_a, in_b);
        try w.writeAll("\n");
    }
    // H4: cross-team, frontline into magic damage
    {
        try w.writeAll("## Frontline count x enemy magic share (cross-team)\n\n");
        try tableHead(w, "frontline, enemy magic");
        const groups = [_][]const u8{ "0-1", "2+" };
        const edges = [_]f64{ 0, 0.3, 0.5, 2 };
        const names = [_][]const u8{ "<30%", "30-50%", "50%+" };
        for (0..2) |fg| for (0..3) |eb| {
            for (in_a, units.items) |*a, u| a.* = (u.frontline >= 2) == (fg == 1) and u.enemy_magic_share >= edges[eb] and u.enemy_magic_share < edges[eb + 1];
            try binRow(w, try std.fmt.allocPrint(arena, "{s}, {s}", .{ groups[fg], names[eb] }), units.items, res, in_a);
        };
        for (group, units.items) |*gr, u| gr.* = @intFromBool(u.frontline >= 2);
        const dd = interaction(units.items, resid, group);
        try w.print("\n2+ frontline's edge into 50%+ magic minus into <30%: {d:.2} ± {d:.2} pp\n\n", .{ dd.est * 100, dd.half * 100 });
    }
    // H5: armour-leaning teams into magic damage (lean vs each role's mean, terciles)
    {
        const q = try quantiles(3, "armour_lean", gpa, units.items);
        try w.print("## Team armour lean x enemy magic share (cross-team; lean terciles at {d:.1} and {d:.1})\n\n", .{ q[0], q[1] });
        try tableHead(w, "armour lean, enemy magic");
        const groups = [_][]const u8{ "MR-leaning", "middle", "armour-leaning" };
        const edges = [_]f64{ 0, 0.3, 0.5, 2 };
        const names = [_][]const u8{ "<30%", "30-50%", "50%+" };
        for (0..3) |lg| for (0..3) |eb| {
            for (in_a, units.items) |*a, u| {
                const t: usize = if (u.armour_lean <= q[0]) 0 else if (u.armour_lean <= q[1]) 1 else 2;
                a.* = t == lg and u.enemy_magic_share >= edges[eb] and u.enemy_magic_share < edges[eb + 1];
            }
            try binRow(w, try std.fmt.allocPrint(arena, "{s}, {s}", .{ groups[lg], names[eb] }), units.items, res, in_a);
        };
        for (group, units.items) |*gr, u| gr.* = if (u.armour_lean > q[1]) 1 else if (u.armour_lean <= q[0]) 0 else null;
        const dd = interaction(units.items, resid, group);
        try w.print("\narmour-leaning minus MR-leaning, into 50%+ magic minus into <30%: {d:.2} ± {d:.2} pp\n\n", .{ dd.est * 100, dd.half * 100 });
    }
}

fn pct(a: usize, b: usize) f64 {
    return if (b == 0) 0 else 100 * @as(f64, @floatFromInt(a)) / @as(f64, @floatFromInt(b));
}

fn quantiles(comptime n: usize, comptime field: []const u8, gpa: std.mem.Allocator, units: []const Unit) ![n - 1]f64 {
    const xs = try gpa.alloc(f64, units.len);
    defer gpa.free(xs);
    for (xs, units) |*x, u| x.* = @field(u, field);
    std.mem.sort(f64, xs, {}, std.sort.asc(f64));
    var q: [n - 1]f64 = undefined;
    for (&q, 1..) |*v, i| v.* = xs[xs.len * i / n];
    return q;
}

const Est = struct { n: usize = 0, mean_p: f64 = 0, est: f64 = 0, half: f64 = std.math.inf(f64) };

/// Mean of resid over a (b null), or mean over a minus mean over b; 95% interval
/// clustered by game (sandwich over each game's summed influence)
fn contrast(units: []const Unit, resid: []const f64, a: []const bool, b: ?[]const bool) Est {
    var na: f64 = 0;
    var nb: f64 = 0;
    var sa: f64 = 0;
    var sb: f64 = 0;
    var sp: f64 = 0;
    for (resid, a, 0..) |r, ia, i| {
        if (ia) {
            na += 1;
            sa += r;
            sp += units[i].p;
        }
        if (b) |bb| if (bb[i]) {
            nb += 1;
            sb += r;
        };
    }
    if (na < 2 or (b != null and nb < 2)) return .{ .n = @intFromFloat(na) };
    const ma = sa / na;
    const mb = if (nb > 0) sb / nb else 0;
    var ss: f64 = 0;
    var groups: f64 = 0;
    var i: usize = 0;
    while (i < units.len) {
        const g = units[i].game;
        var sum: f64 = 0;
        var any = false;
        while (i < units.len and units[i].game == g) : (i += 1) {
            if (a[i]) {
                sum += (resid[i] - ma) / na;
                any = true;
            }
            if (b) |bb| if (bb[i]) {
                sum -= (resid[i] - mb) / nb;
                any = true;
            };
        }
        if (!any) continue;
        ss += sum * sum;
        groups += 1;
    }
    const half = if (groups > 1) 1.96 * @sqrt(groups / (groups - 1) * ss) else std.math.inf(f64);
    return .{ .n = @intFromFloat(na), .mean_p = sp / na, .est = ma - mb, .half = half };
}

/// Difference in differences: (group 1 minus group 0) into 50%+ enemy magic, minus the
/// same into <30%; group null leaves a unit out. Each cell's mean residual, influence
/// summed per game
fn interaction(units: []const Unit, resid: []const f64, group: []const ?u1) Est {
    const Cell = struct { n: f64 = 0, s: f64 = 0 };
    var cells: [2][2]Cell = @splat(@splat(.{}));
    const sign = [2][2]f64{ .{ -1, 1 }, .{ 1, -1 } };
    const Ctx = struct {
        fn cellOf(u: Unit, gr: ?u1) ?[2]usize {
            const fg: usize = gr orelse return null;
            if (u.enemy_magic_share >= 0.5) return .{ 0, fg };
            if (u.enemy_magic_share < 0.3) return .{ 1, fg };
            return null;
        }
    };
    for (units, resid, group) |u, r, gr| if (Ctx.cellOf(u, gr)) |ce| {
        cells[ce[0]][ce[1]].n += 1;
        cells[ce[0]][ce[1]].s += r;
    };
    var est: f64 = 0;
    for (cells, sign) |row, sr| for (row, sr) |ce, s| {
        if (ce.n < 2) return .{};
        est += s * ce.s / ce.n;
    };
    var ss: f64 = 0;
    var groups: f64 = 0;
    var i: usize = 0;
    while (i < units.len) {
        const g = units[i].game;
        var sum: f64 = 0;
        while (i < units.len and units[i].game == g) : (i += 1) if (Ctx.cellOf(units[i], group[i])) |ce| {
            const cell = cells[ce[0]][ce[1]];
            sum += sign[ce[0]][ce[1]] * (resid[i] - cell.s / cell.n) / cell.n;
        };
        ss += sum * sum;
        groups += 1;
    }
    return .{ .n = units.len, .est = est, .half = 1.96 * @sqrt(groups / (groups - 1) * ss) };
}

/// Per team unit: observed minus win-ratings' chance, and observed minus 50% (raw)
const Res = struct { model: []const f64, raw: []const f64 };

fn tableHead(w: *Io.Writer, label: []const u8) !void {
    try w.print("| {s} | teams | predicted | observed | observed - 50%, pp | observed - predicted, pp |\n| --- | --- | --- | --- | --- | --- |\n", .{label});
}

fn binRow(w: *Io.Writer, label: []const u8, units: []const Unit, res: Res, a: []const bool) !void {
    const e = contrast(units, res.model, a, null);
    if (e.n < 2) {
        try w.print("| {s} | {d} | | | | |\n", .{ label, e.n });
        return;
    }
    const raw = contrast(units, res.raw, a, null);
    try w.print("| {s} | {d} | {d:.1}% | {d:.1}% | {d:.2} ± {d:.2} | {d:.2} ± {d:.2} |\n", .{
        label,          e.n,         e.mean_p * 100, 50 + raw.est * 100, raw.est * 100,
        raw.half * 100, e.est * 100, e.half * 100,
    });
}

fn contrastLine(w: *Io.Writer, label: []const u8, units: []const Unit, res: Res, a: []const bool, b: []const bool) !void {
    const e = contrast(units, res.model, a, b);
    const raw = contrast(units, res.raw, a, b);
    try w.print("\n{s}: {d:.2} ± {d:.2} pp raw, {d:.2} ± {d:.2} pp after win-ratings\n", .{ label, raw.est * 100, raw.half * 100, e.est * 100, e.half * 100 });
}

/// The check must find an effect taken out of the offset: for the champion-roles with
/// the largest training lifts (shrunk log-odds over 50%), teams with one, residual with
/// the offset as is (should be ~0) and with the lift removed from that team's logit
/// (should come back as about the lift)
/// A champion-role's training win rate as log-odds over 50%, shrunk by control_prior
fn liftOf(wins: *const std.AutoHashMapUnmanaged(u64, [2]f64), champion: u32, role: usize) f64 {
    const e = wins.get(cellKey(champion, role)) orelse return 0;
    const rate = (e[0] + 0.5 * control_prior) / (e[1] + control_prior);
    return @log(rate / (1 - rate));
}

/// A real effect the check must find: with a coin as the offset, dev teams binned by
/// their champions' summed training lifts minus the enemy's should win about what the
/// lifts say; with win-ratings as the offset the gradient should be gone
fn strengthControl(gpa: std.mem.Allocator, arena: std.mem.Allocator, units: []const Unit, resid: []const f64, in_a: []bool, w: *Io.Writer) !void {
    const coin = try gpa.alloc(f64, units.len);
    defer gpa.free(coin);
    for (coin, units) |*c, u| c.* = u.y - 0.5;
    const q = try quantiles(4, "lift_diff", gpa, units);
    const edges = [_]f64{ -std.math.inf(f64), q[0], q[1], q[2], std.math.inf(f64) };
    try w.writeAll("## Positive control: champion strength from training, found on dev\n\n");
    try w.writeAll("| lift difference quartile | teams | lifts say | observed | observed - 50%, pp | observed - win-ratings, pp |\n| --- | --- | --- | --- | --- | --- |\n");
    for (0..4) |b| {
        var said: f64 = 0;
        var n: f64 = 0;
        for (in_a, units) |*a, u| {
            a.* = u.lift_diff > edges[b] and u.lift_diff <= edges[b + 1];
            if (a.*) {
                said += 1 / (1 + @exp(-u.lift_diff));
                n += 1;
            }
        }
        const vs_coin = contrast(units, coin, in_a, null);
        const vs_ratings = contrast(units, resid, in_a, null);
        try w.print("| Q{d} ({s}) | {d} | {d:.1}% | {d:.1}% | {d:.2} ± {d:.2} | {d:.2} ± {d:.2} |\n", .{
            b + 1,                  try std.fmt.allocPrint(arena, "{d:.2} to {d:.2}", .{ @max(edges[b], -9), @min(edges[b + 1], 9) }),
            vs_coin.n,              100 * said / n,
            50 + vs_coin.est * 100, vs_coin.est * 100,
            vs_coin.half * 100,     vs_ratings.est * 100,
            vs_ratings.half * 100,
        });
    }
    try w.writeAll("\n");
}

fn control(
    gpa: std.mem.Allocator,
    d: *const rows.Data,
    wins: *const std.AutoHashMapUnmanaged(u64, [2]f64),
    units: []const Unit,
    resid: []const f64,
    in_a: []bool,
    w: *Io.Writer,
) !void {
    const Cand = struct { key: u64, lift: f64, n: f64 };
    var cands: std.ArrayList(Cand) = .empty;
    defer cands.deinit(gpa);
    var it = wins.iterator();
    while (it.next()) |e| {
        const n = e.value_ptr[1];
        if (n < control_min_train) continue;
        const rate = (e.value_ptr[0] + 0.5 * control_prior) / (n + control_prior);
        try cands.append(gpa, .{ .key = e.key_ptr.*, .lift = @log(rate / (1 - rate)), .n = n });
    }
    std.mem.sort(Cand, cands.items, {}, struct {
        fn lt(_: void, a: Cand, b: Cand) bool {
            return @abs(a.lift) > @abs(b.lift);
        }
    }.lt);

    const shifted = try gpa.alloc(f64, units.len);
    defer gpa.free(shifted);
    try w.writeAll("## Plumbing check: a champion-role's training lift removed from the offset (found minus as is should equal it)\n\n");
    try w.writeAll("| champion-role | train rows | lift removed, pp | dev teams | as is, pp | lift removed, found, pp |\n| --- | --- | --- | --- | --- | --- |\n");
    var shown: usize = 0;
    for (cands.items) |ca| {
        if (shown == 6) break;
        const champion: u32 = @intCast(ca.key >> 3);
        const role: usize = @intCast(ca.key & 7);
        var dev_teams: usize = 0;
        for (in_a, units) |*a, u| {
            a.* = d.games[u.game].teams[u.side][role] == champion;
            if (a.*) dev_teams += 1;
        }
        if (dev_teams < control_min_dev) continue;
        shown += 1;
        // Blue's logit loses the lift where blue has it and gains it where red has it
        for (shifted, units) |*s, u| {
            const team_has = d.games[u.game].teams[u.side][role] == champion;
            const enemy_has = d.games[u.game].teams[1 - u.side][role] == champion;
            const shift: f64 = (if (team_has) ca.lift else 0) - (if (enemy_has) ca.lift else 0);
            const l = @log(u.p / (1 - u.p)) - shift;
            s.* = u.y - 1 / (1 + @exp(-l));
        }
        const as_is = contrast(units, resid, in_a, null);
        const found = contrast(units, shifted, in_a, null);
        const removed_pp = (1 / (1 + @exp(-ca.lift)) - 0.5) * 100;
        try w.print("| {d} {s} | {d:.0} | {d:.2} | {d} | {d:.2} ± {d:.2} | {d:.2} ± {d:.2} |\n", .{
            champion,        role_names[role], ca.n,            removed_pp,       dev_teams,
            as_is.est * 100, as_is.half * 100, found.est * 100, found.half * 100,
        });
    }
    try w.writeAll("\n");
}

fn writeUnits(io: Io, d: *const rows.Data, units: []const Unit) !void {
    var file = try Io.Dir.cwd().createFile(io, "compcheck.tsv", .{});
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    const w = &fw.interface;
    try w.writeAll("match_id\tside\ty\tpred\tmagic_share\tfrontline\tcc\tenemy_magic_share\tenemy_frontline\tarmour_lean\n");
    for (units) |u| try w.print("{s}\t{d}\t{d}\t{d:.4}\t{d:.4}\t{d}\t{d:.3}\t{d:.4}\t{d}\t{d:.2}\n", .{
        d.games[u.game].match_id, u.side, u.y, u.p, u.magic_share, u.frontline, u.cc, u.enemy_magic_share, u.enemy_frontline, u.armour_lean,
    });
    try w.flush();
}

test "contrast: clustered by game, two teams per game" {
    // Three games; game residuals are opposite by team, as for real units
    var units: [6]Unit = undefined;
    const r = [_]f64{ 0.4, -0.4, -0.6, 0.6, 0.3, -0.3 };
    for (&units, 0..) |*u, i| u.* = .{
        .game = @intCast(i / 2),
        .side = @intCast(i % 2),
        .y = 0,
        .p = 0.5,
        .magic_share = 0,
        .phys_share = 0,
        .frontline = 0,
        .cc = 0,
        .enemy_magic_share = 0,
        .enemy_frontline = 0,
        .armour_lean = 0,
        .best_mitigated = 0,
        .lift_diff = 0,
    };
    const a = [_]bool{ true, false, true, false, true, false };
    const one = contrast(&units, &r, &a, null);
    try std.testing.expectApproxEqAbs(@as(f64, 0.1 / 3.0), one.est, 1e-12);
    // One unit per game: per-game influence (r - mean) / 3, G / (G - 1) correction
    const m = 0.1 / 3.0;
    var ss: f64 = 0;
    for ([_]f64{ 0.4, -0.6, 0.3 }) |x| ss += (x - m) * (x - m) / 9;
    try std.testing.expectApproxEqAbs(1.96 * @sqrt(1.5 * ss), one.half, 1e-12);
    // Blue minus red: both units of a game move together, so the game is one cluster
    const b = [_]bool{ false, true, false, true, false, true };
    const diff = contrast(&units, &r, &a, &b);
    try std.testing.expectApproxEqAbs(2 * m, diff.est, 1e-12);
    try std.testing.expectApproxEqAbs(2 * one.half, diff.half, 1e-12);
}
