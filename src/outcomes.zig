//! `meiolol outcomes`: do allies and the enemy team shift a champion's early numbers
//! (gold at 14, lane gold difference, CS at 10, deaths before 15, first finished item)
//! beyond its own base rate and lane matchup? A win is one noisy bit; these are much
//! less noisy, so team effects may show at volumes where win rates can't.
//! docs/model.md "Shared protocol, 2026-10-12" defines rows, outcomes and the split.
//!
//! Models are additive in groups of effects, each fitted in turn on the residual of the
//! others (backfitting) and shrunk toward 0 with a prior strength from the method of
//! moments per group and role (as lanegold.zig). Outcomes are standardised per role on
//! train. Scored on the newest test-platform games against the champion-role train
//! mean, paired per game (a game's ten rows share a game state).

const std = @import("std");
const store = @import("store");
const core = @import("core");
const timeline = @import("riot/timeline.zig");
const stats = @import("stats.zig");
const ddragon = @import("ddragon.zig");
const eval = @import("eval.zig");
const Date = @import("date.zig").Date;
const Role = core.Role;
const Io = std.Io;

pub const Outcome = enum { gold14, lanediff14, cs10, deaths15, first_item };
const n_out = @typeInfo(Outcome).@"enum".field_names.len;

pub const Options = struct {
    test_share: f64 = 0.2,
    test_platform: []const u8 = "EUW1",
    passes: u32 = 12,
    /// One TSV per model of every test row's prediction (docs/model.md protocol)
    preds_dir: ?[]const u8 = null,
};

/// Finished items for first-item timing, per patch (patchKey)
pub const Legendaries = std.AutoHashMapUnmanaged(u32, []const u32);

const minute_ms = 60_000;

/// One participant of a game with a timeline that reached minute 15
const Row = struct {
    game: u32,
    slot: u8,
    role: u8,
    platform: u8,
    champ: u16,
    ally: [Role.count]u16,
    enemy: [Role.count]u16,
    /// NaN: missing (no finished item by the game's end)
    y: [n_out]f32,
};

/// Per game: blue and red, by role
const GameOutcomes = struct {
    match_id: []const u8,
    slot: [2][Role.count]u8,
    y: [2][Role.count][n_out]f32,
};

const Map = std.AutoHashMapUnmanaged(u64, GameOutcomes);

/// Champion classes: the first of Data Dragon's tags
const classes = [_][]const u8{ "Assassin", "Fighter", "Mage", "Marksman", "Support", "Tank" };
const n_class: u32 = classes.len;

const Group = enum {
    platform,
    /// own champion in its role
    champ,
    /// own champion against the lane opponent
    lane,
    /// the other half of the bot lane (bottom and support), whoever we play
    duo_enemy,
    duo_ally,
    /// junglers, for laners
    jungle_enemy,
    jungle_ally,
    /// everyone else on each team
    rest_enemy,
    rest_ally,
    /// own class x count of each class on the enemy team (centred)
    class_class,
    /// own champion x count of each class on the enemy team (centred)
    class,
    /// own champion x enemy champion in each other role
    pair,
};
const n_group = @typeInfo(Group).@"enum".field_names.len;
const max_terms = @max(Role.count - 1, n_class);

/// How another role relates to ours, for the team groups
const Relation = enum { duo, jungle, rest };

fn relation(role: usize, other: usize) Relation {
    const bot = @backingInt(Role.bottom);
    const sup = @backingInt(Role.utility);
    if ((role == bot and other == sup) or (role == sup and other == bot)) return .duo;
    if (other == @backingInt(Role.jungle)) return .jungle;
    return .rest;
}

/// after: the model this one adds to, for the step's own gain (null: the baseline)
const Model = struct { label: []const u8, file: []const u8, groups: []const Group, after: ?usize };

const team_groups: []const Group = &.{
    .platform,     .champ,       .lane,       .duo_enemy, .duo_ally,
    .jungle_enemy, .jungle_ally, .rest_enemy, .rest_ally,
};
const models = [_]Model{
    .{ .label = "platform + champion", .file = "3c-platchamp", .groups = team_groups[0..2], .after = null },
    .{ .label = "+ lane opponent", .file = "3c-lane", .groups = team_groups[0..3], .after = 0 },
    .{ .label = "+ bot lane partners", .file = "3c-duo", .groups = team_groups[0..5], .after = 1 },
    .{ .label = "+ junglers", .file = "3c-jungle", .groups = team_groups[0..7], .after = 2 },
    .{ .label = "+ rest of both teams", .file = "3c-team", .groups = team_groups, .after = 3 },
    .{ .label = "+ own class x enemy classes", .file = "3c-classclass", .groups = team_groups ++ &[_]Group{.class_class}, .after = 4 },
    .{ .label = "+ own champion x enemy classes", .file = "3c-class", .groups = team_groups ++ &[_]Group{ .class_class, .class }, .after = 5 },
    .{ .label = "+ own champion x enemy champion", .file = "3c-pair", .groups = team_groups ++ &[_]Group{.pair}, .after = 4 },
};

/// The fullest additive model, the baseline interaction models must beat
const team_model = 4;

const Term = struct { cell: u32, x: f32 };

/// Cell layouts, role first so a cell's role is cell / perRole
const Space = struct {
    champs: u32,
    platforms: u32,
    class_of: []const ?u8,
    /// [role][class]: mean count on the enemy team, train
    class_mean: [Role.count][n_class]f32 = @splat(@splat(0)),

    fn perRole(s: Space, g: Group) u32 {
        const c = s.champs;
        return switch (g) {
            .platform => s.platforms,
            .champ => c,
            .lane => c * c,
            .duo_enemy, .duo_ally, .jungle_enemy, .jungle_ally, .rest_enemy, .rest_ally => Role.count * c,
            .class_class => n_class * n_class,
            .class => c * n_class,
            .pair => c * Role.count * c,
        };
    }

    fn terms(s: Space, g: Group, r: Row, out: *[max_terms]Term) usize {
        const c = s.champs;
        const role: u32 = r.role;
        const own = role * c + r.champ;
        var n: usize = 0;
        switch (g) {
            .platform => out[0] = .{ .cell = role * s.platforms + r.platform, .x = 1 },
            .champ => out[0] = .{ .cell = own, .x = 1 },
            .lane => out[0] = .{ .cell = own * c + r.enemy[role], .x = 1 },
            .duo_enemy, .duo_ally, .jungle_enemy, .jungle_ally, .rest_enemy, .rest_ally => {
                const want: Relation = switch (g) {
                    .duo_enemy, .duo_ally => .duo,
                    .jungle_enemy, .jungle_ally => .jungle,
                    else => .rest,
                };
                const enemy = g == .duo_enemy or g == .jungle_enemy or g == .rest_enemy;
                const side = if (enemy) r.enemy else r.ally;
                for (0..Role.count) |o| {
                    if (o == role or relation(role, o) != want) continue;
                    out[n] = .{ .cell = (role * Role.count + @as(u32, @intCast(o))) * c + side[o], .x = 1 };
                    n += 1;
                }
                return n;
            },
            .class_class, .class => {
                const base = if (g == .class) own else role * n_class + (s.class_of[r.champ] orelse return 0);
                const count = s.enemyClasses(r);
                for (0..n_class) |k| out[k] = .{
                    .cell = base * n_class + @as(u32, @intCast(k)),
                    .x = count[k] - s.class_mean[role][k],
                };
                return n_class;
            },
            .pair => {
                for (0..Role.count) |o| {
                    if (o == role) continue;
                    out[n] = .{ .cell = (own * Role.count + @as(u32, @intCast(o))) * c + r.enemy[o], .x = 1 };
                    n += 1;
                }
                return n;
            },
        }
        return 1;
    }

    fn enemyClasses(s: Space, r: Row) [n_class]f32 {
        var count: [n_class]f32 = @splat(0);
        for (r.enemy) |e| if (s.class_of[e]) |k| {
            count[k] += 1;
        };
        return count;
    }
};

/// Cells with fewer (x-weighted) games are left out of the spread estimates
const eb_min_games = 10;
/// Fewer cells in a role and the group is off for it (effects 0)
const eb_min_cells = 20;

/// Shrunk effects of some groups for one outcome
const Fit = struct {
    effects: [n_group]?[]f32 = @splat(null),
    /// [group][role]: prior strength in games (inf: off) and spread of true effects
    /// (standard deviations of the outcome)
    k: [n_group][Role.count]f64 = @splat(@splat(0)),
    tau: [n_group][Role.count]f64 = @splat(@splat(0)),

    fn deinit(f: *Fit, gpa: std.mem.Allocator) void {
        for (f.effects) |e| if (e) |x| gpa.free(x);
    }

    fn predict(f: *const Fit, s: Space, r: Row) f32 {
        var sum: f32 = 0;
        var buf: [max_terms]Term = undefined;
        for (f.effects, 0..) |e, gi| if (e) |b| {
            const n = s.terms(@fromBackingInt(@intCast(gi)), r, &buf);
            for (buf[0..n]) |t| sum += t.x * b[t.cell];
        };
        return sum;
    }
};

fn fit(
    gpa: std.mem.Allocator,
    s: Space,
    rows: []const Row,
    z: []const f32,
    groups: []const Group,
    passes: u32,
) !Fit {
    var f: Fit = .{};
    errdefer f.deinit(gpa);
    const res = try gpa.alloc(f32, rows.len);
    defer gpa.free(res);
    @memcpy(res, z);
    for (groups) |g| {
        const b = try gpa.alloc(f32, Role.count * s.perRole(g));
        @memset(b, 0);
        f.effects[@backingInt(g)] = b;
    }
    var sxr: std.ArrayList(f64) = .empty;
    defer sxr.deinit(gpa);
    var sxx: std.ArrayList(f64) = .empty;
    defer sxx.deinit(gpa);
    var old: std.ArrayList(f32) = .empty;
    defer old.deinit(gpa);
    var buf: [max_terms]Term = undefined;

    for (0..passes) |_| for (groups) |g| {
        const gi = @backingInt(g);
        const b = f.effects[gi].?;
        const per_role = s.perRole(g);
        try sxr.resize(gpa, b.len);
        try sxx.resize(gpa, b.len);
        @memset(sxr.items, 0);
        @memset(sxx.items, 0);
        var sum_sq: f64 = 0;
        var n_rows: f64 = 0;
        for (rows, res) |r, e| {
            if (std.math.isNan(e)) continue;
            sum_sq += e * e;
            n_rows += 1;
            const n = s.terms(g, r, &buf);
            for (buf[0..n]) |t| {
                sxr.items[t.cell] += t.x * (e + t.x * b[t.cell]);
                sxx.items[t.cell] += t.x * t.x;
            }
        }
        const sigma2 = sum_sq / @max(n_rows, 1);
        try old.resize(gpa, b.len);
        @memcpy(old.items, b);
        for (0..Role.count) |ri| {
            const lo = ri * per_role;
            const k: f64 = if (g == .platform) 1 else blk: {
                var cells: f64 = 0;
                var excess: f64 = 0;
                for (sxr.items[lo..][0..per_role], sxx.items[lo..][0..per_role]) |xr, xx| {
                    if (xx < eb_min_games) continue;
                    const est = xr / xx;
                    cells += 1;
                    excess += est * est - sigma2 / xx;
                }
                if (cells < eb_min_cells or excess <= 0) break :blk std.math.inf(f64);
                break :blk sigma2 / (excess / cells);
            };
            f.k[gi][ri] = k;
            f.tau[gi][ri] = if (std.math.isInf(k)) 0 else @sqrt(sigma2 / k);
            for (b[lo..][0..per_role], sxr.items[lo..][0..per_role], sxx.items[lo..][0..per_role]) |*x, xr, xx| {
                x.* = if (std.math.isInf(k) or xx == 0) 0 else @floatCast(xr / (xx + k));
            }
        }
        for (rows, res) |r, *e| {
            if (std.math.isNan(e.*)) continue;
            const n = s.terms(g, r, &buf);
            for (buf[0..n]) |t| e.* -= t.x * (b[t.cell] - old.items[t.cell]);
        }
    };
    return f;
}

pub fn run(
    gpa: std.mem.Allocator,
    io: Io,
    db: store.Db,
    patches: []const []const u8,
    platforms: []const []const u8,
    legendaries: *const Legendaries,
    opts: Options,
    w: *Io.Writer,
) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var list: GameList = .{ .gpa = gpa };
    defer list.items.deinit(gpa);
    _ = try stats.scan(gpa, db, patches, platforms, 0, &list);
    const games = list.items.items;
    var split = try eval.split(gpa, games, platforms, .{ .test_share = opts.test_share, .test_platform = opts.test_platform });
    defer split.deinit(gpa);
    const cutoff = split.tests[0].start;

    var map = try load(gpa, arena, db, patches, platforms, legendaries);
    defer map.deinit(gpa);

    // Dense champion index over the games
    var index: std.AutoHashMapUnmanaged(u32, u16) = .empty;
    defer index.deinit(gpa);
    var ids: std.ArrayList(u32) = .empty;
    defer ids.deinit(gpa);
    for (games) |g| for (g.teams) |team| for (team) |id| {
        const e = try index.getOrPut(gpa, id);
        if (!e.found_existing) {
            e.value_ptr.* = @intCast(ids.items.len);
            try ids.append(gpa, id);
        }
    };
    const class_of = try championClasses(arena, db, ids.items);

    var train: std.ArrayList(Row) = .empty;
    defer train.deinit(gpa);
    var tests: std.ArrayList(Row) = .empty;
    defer tests.deinit(gpa);
    var test_ids: std.ArrayList([]const u8) = .empty;
    defer test_ids.deinit(gpa);
    var train_games: usize = 0;
    for ([_][]const stats.Row{ split.train, split.tests }, [_]bool{ false, true }) |part, is_test| for (part) |g| {
        const o = map.get(g.id) orelse continue;
        const out = if (is_test) &tests else &train;
        if (is_test) try test_ids.append(gpa, o.match_id) else train_games += 1;
        var team: [2][Role.count]u16 = undefined;
        for (0..2) |side| for (0..Role.count) |ri| {
            team[side][ri] = index.get(g.teams[side][ri]).?;
        };
        for (0..2) |side| for (0..Role.count) |ri| try out.append(gpa, .{
            .game = @intCast(if (is_test) test_ids.items.len - 1 else train_games - 1),
            .slot = o.slot[side][ri],
            .role = @intCast(ri),
            .platform = g.platform,
            .champ = team[side][ri],
            .ally = team[side],
            .enemy = team[1 - side],
            .y = o.y[side][ri],
        });
    };
    if (train.items.len == 0 or tests.items.len == 0) return error.TooFewGames;

    var space: Space = .{
        .champs = @intCast(ids.items.len),
        .platforms = @intCast(platforms.len),
        .class_of = class_of,
    };
    {
        var per_role: [Role.count]f32 = @splat(0);
        for (train.items) |r| {
            per_role[r.role] += 1;
            for (r.enemy) |e| if (class_of[e]) |k| {
                space.class_mean[r.role][k] += 1;
            };
        }
        for (&space.class_mean, per_role) |*m, n| for (m) |*x| {
            x.* /= @max(n, 1);
        };
    }

    try w.print("# meiolol outcomes\n\nTrain: {d} games with a timeline to minute 15, every " ++
        "scanned platform, started before {f} ({d}). Test: {d} {s} games from then. " ++
        "Champions: {d}.\n", .{
        train_games,        Date.fromMs(cutoff), cutoff, test_ids.items.len,
        opts.test_platform, ids.items.len,
    });

    var files: [models.len + 1]?Io.File = @splat(null);
    var bufs: [models.len + 1][16 * 1024]u8 = undefined;
    var writers: [models.len + 1]Io.File.Writer = undefined;
    defer for (files) |f| if (f) |x| x.close(io);
    if (opts.preds_dir) |dir| {
        const cwd = Io.Dir.cwd();
        try cwd.createDirPath(io, dir);
        for (0..models.len + 1) |i| {
            const name = if (i == 0) "base-champrole" else models[i - 1].file;
            const path = try std.fmt.allocPrint(arena, "{s}/{s}.tsv", .{ dir, name });
            files[i] = try cwd.createFile(io, path, .{});
            writers[i] = files[i].?.writer(io, &bufs[i]);
            try writers[i].interface.writeAll("match_id\tslot\toutcome\ty\tpred\n");
        }
    }

    const z = try gpa.alloc(f32, train.items.len);
    defer gpa.free(z);
    const err_base = try gpa.alloc(f64, tests.items.len);
    defer gpa.free(err_base);
    var err_models: [models.len][]f64 = undefined;
    for (&err_models) |*e| e.* = try arena.alloc(f64, tests.items.len);
    for (0..n_out) |oi| {
        const outcome: Outcome = @fromBackingInt(@intCast(oi));
        // Standardise per role on train
        var sum: [Role.count]f64 = @splat(0);
        var sum_sq: [Role.count]f64 = @splat(0);
        var count: [Role.count]f64 = @splat(0);
        var missing: [Role.count]f64 = @splat(0);
        for (train.items) |r| {
            const y = r.y[oi];
            if (std.math.isNan(y)) {
                missing[r.role] += 1;
                continue;
            }
            sum[r.role] += y;
            sum_sq[r.role] += y * y;
            count[r.role] += 1;
        }
        var mean: [Role.count]f64 = undefined;
        var sd: [Role.count]f64 = undefined;
        for (0..Role.count) |ri| {
            mean[ri] = sum[ri] / @max(count[ri], 1);
            sd[ri] = @sqrt(@max(sum_sq[ri] / @max(count[ri], 1) - mean[ri] * mean[ri], 1e-9));
        }
        for (train.items, z) |r, *x| {
            x.* = @floatCast((r.y[oi] - mean[r.role]) / sd[r.role]);
        }

        // Baseline: champion-role train mean, role mean for an unseen champion
        const base_sum = try gpa.alloc(f64, Role.count * space.champs);
        defer gpa.free(base_sum);
        const base_n = try gpa.alloc(f64, Role.count * space.champs);
        defer gpa.free(base_n);
        @memset(base_sum, 0);
        @memset(base_n, 0);
        for (train.items, z) |r, x| {
            if (std.math.isNan(x)) continue;
            base_sum[r.role * space.champs + r.champ] += x;
            base_n[r.role * space.champs + r.champ] += 1;
        }
        const Base = struct {
            sum: []const f64,
            n: []const f64,
            champs: u32,
            fn get(b: @This(), r: Row) f64 {
                const i = r.role * b.champs + r.champ;
                return if (b.n[i] > 0) b.sum[i] / b.n[i] else 0;
            }
        };
        const base: Base = .{ .sum = base_sum, .n = base_n, .champs = space.champs };

        try w.print("\n## {t}\n\nRole mean (sd) on train:", .{outcome});
        for (Role.all) |r| {
            const ri = @backingInt(r);
            try w.print(" {t} {d:.1} ({d:.1})", .{ r, mean[ri], sd[ri] });
        }
        try w.writeAll(".");
        if (outcome == .first_item) {
            try w.writeAll(" No finished item by the game's end (left out):");
            for (Role.all) |r| {
                const ri = @backingInt(r);
                try w.print(" {t} {d:.1}%", .{ r, 100 * missing[ri] / @max(missing[ri] + count[ri], 1) });
            }
            try w.writeAll(".");
        }
        try w.writeAll("\n\nTest MSE in role sds squared; gain = share of the baseline's MSE " ++
            "removed, ± 95% interval over games.\n\n| model | test MSE | gain vs " ++
            "champion-role mean | step's own gain |\n| --- | --- | --- | --- |\n");

        for (tests.items, err_base) |r, *e| {
            const y = r.y[oi];
            if (std.math.isNan(y)) {
                e.* = std.math.nan(f64);
                continue;
            }
            const zt = (y - mean[r.role]) / sd[r.role];
            const d = zt - base.get(r);
            e.* = d * d;
        }
        const base_mse = nanMean(err_base);
        try w.print("| champion-role mean | {d:.4} | - | - |\n", .{base_mse});
        if (opts.preds_dir != null) {
            for (tests.items) |r| try predLine(&writers[0].interface, test_ids.items[r.game], r, outcome, mean, sd, base.get(r));
        }

        var fits: [models.len]Fit = undefined;
        var n_fits: usize = 0;
        defer for (fits[0..n_fits]) |*f| f.deinit(gpa);
        for (models, 0..) |m, mi| {
            fits[mi] = try fit(gpa, space, train.items, z, m.groups, opts.passes);
            n_fits += 1;
            const err_model = err_models[mi];
            for (tests.items, err_model) |r, *e| {
                if (std.math.isNan(r.y[oi])) {
                    e.* = std.math.nan(f64);
                    continue;
                }
                const zt = (r.y[oi] - mean[r.role]) / sd[r.role];
                const d = zt - fits[mi].predict(space, r);
                e.* = d * d;
            }
            const gain = pairedGain(tests.items, err_base, err_model, base_mse);
            const before = if (m.after) |a| err_models[a] else err_base;
            const step = pairedGain(tests.items, before, err_model, base_mse);
            try w.print("| {s} | {d:.4} | {d:.2}% ± {d:.2} | {d:.2}% ± {d:.2} |\n", .{
                m.label,         nanMean(err_model),    100 * gain.mean, 100 * gain.half_width,
                100 * step.mean, 100 * step.half_width,
            });
            if (opts.preds_dir != null) {
                const pw = &writers[mi + 1].interface;
                for (tests.items) |r| try predLine(pw, test_ids.items[r.game], r, outcome, mean, sd, fits[mi].predict(space, r));
            }
        }

        try w.print("\nTest RMSE in outcome units by role, champion-role mean -> {s}:", .{models[team_model].label});
        for (Role.all) |role| {
            const ri = @backingInt(role);
            var sums: [2]f64 = @splat(0);
            var n: f64 = 0;
            for (tests.items, err_base, err_models[team_model]) |r, b, m| {
                if (r.role != ri or std.math.isNan(b)) continue;
                sums[0] += b;
                sums[1] += m;
                n += 1;
            }
            try w.print(" {t} {d:.1} -> {d:.1}", .{
                role, sd[ri] * @sqrt(sums[0] / @max(n, 1)), sd[ri] * @sqrt(sums[1] / @max(n, 1)),
            });
        }
        try w.writeAll(".\n");

        // Spread of true effects, from the fullest fits
        try w.writeAll("\nSpread of true effects (sd, outcome units) and prior strength " ++
            "(games), by role:\n\n| group |");
        for (Role.all) |r| try w.print(" {t} |", .{r});
        try w.writeAll("\n| --- |");
        for (Role.all) |_| try w.writeAll(" --- |");
        try w.writeAll("\n");
        const shown = [_]struct { Group, usize }{
            .{ .champ, 4 },        .{ .lane, 4 },        .{ .duo_enemy, 4 },  .{ .duo_ally, 4 },
            .{ .jungle_enemy, 4 }, .{ .jungle_ally, 4 }, .{ .rest_enemy, 4 }, .{ .rest_ally, 4 },
            .{ .class_class, 5 },  .{ .class, 6 },       .{ .pair, 7 },
        };
        for (shown) |sh| {
            const gi = @backingInt(sh[0]);
            try w.print("| {t} |", .{sh[0]});
            for (0..Role.count) |ri| {
                const k = fits[sh[1]].k[gi][ri];
                if (std.math.isInf(k)) {
                    try w.writeAll(" off |");
                } else try w.print(" {d:.2} ({d:.0}) |", .{ fits[sh[1]].tau[gi][ri] * sd[ri], k });
            }
            try w.writeAll("\n");
        }
    }
    for (files, &writers) |f, *x| if (f != null) try x.interface.flush();
}

fn predLine(
    w: *Io.Writer,
    match_id: []const u8,
    r: Row,
    outcome: Outcome,
    mean: [Role.count]f64,
    sd: [Role.count]f64,
    pred_z: f64,
) !void {
    const y = r.y[@backingInt(outcome)];
    if (std.math.isNan(y)) return;
    try w.print("{s}\t{d}\t{t}\t{d}\t{d:.3}\n", .{
        match_id, r.slot, outcome, y, mean[r.role] + sd[r.role] * pred_z,
    });
}

fn nanMean(xs: []const f64) f64 {
    var sum: f64 = 0;
    var n: f64 = 0;
    for (xs) |x| if (!std.math.isNan(x)) {
        sum += x;
        n += 1;
    };
    return sum / @max(n, 1);
}

const Gain = struct { mean: f64, half_width: f64 };

/// (base - model) squared error over every row, as a share of the baseline's MSE; the
/// interval treats games as independent (rows within a game are not)
fn pairedGain(rows: []const Row, base: []const f64, model: []const f64, base_mse: f64) Gain {
    var n_rows: f64 = 0;
    var total: f64 = 0;
    var sum_sq: f64 = 0;
    var n_games: f64 = 0;
    var i: usize = 0;
    while (i < rows.len) {
        var d: f64 = 0;
        const g = rows[i].game;
        while (i < rows.len and rows[i].game == g) : (i += 1) {
            if (std.math.isNan(base[i])) continue;
            d += base[i] - model[i];
            n_rows += 1;
        }
        total += d;
        sum_sq += d * d;
        n_games += 1;
    }
    const mean_d = total / n_games;
    const var_d = sum_sq / n_games - mean_d * mean_d;
    const se = @sqrt(n_games * var_d) / n_rows;
    return .{ .mean = total / n_rows / base_mse, .half_width = 1.96 * se / base_mse };
}

/// Outcomes of every game on `chosen` patches and `platforms` whose timeline reaches
/// minute 15, keyed by stats.matchKey
fn load(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    db: store.Db,
    chosen: []const []const u8,
    platforms: []const []const u8,
    legendaries: *const Legendaries,
) !Map {
    const patch_json = try std.json.Stringify.valueAlloc(arena, chosen, .{});
    const platform_json = try std.json.Stringify.valueAlloc(arena, platforms, .{});
    var q = try db.prepare(
        \\SELECT m.match_id, t.data, m.patch
        \\FROM matches m JOIN timeline.timelines t USING (match_id)
        \\WHERE m.patch IN (SELECT value FROM json_each(?)) AND m.queue_id = ?
        \\  AND m.platform IN (SELECT value FROM json_each(?))
        \\  AND m.remake = 0 AND m.winning_team IS NOT NULL
    );
    defer q.deinit();
    try q.bind(.{ patch_json, stats.ranked_solo, platform_json });
    var players = try db.prepare("SELECT slot, team_id, position FROM participants WHERE match_id = ?");
    defer players.deinit();

    var map: Map = .empty;
    errdefer map.deinit(gpa);
    var scratch_state: std.heap.ArenaAllocator = .init(gpa);
    defer scratch_state.deinit();
    while (try q.step()) {
        _ = scratch_state.reset(.retain_capacity);
        const scratch = scratch_state.allocator();
        const t = timeline.decode(scratch, store.raw.decompress(scratch, q.bytes(1)) catch continue) catch continue;
        if (t.frames.len < 16 or t.frames[15].t_ms < 15 * minute_ms) continue;
        const finished = legendaries.get(stats.patchKey(q.bytes(2))) orelse &.{};

        try players.bind(.{q.bytes(0)});
        var pid: [2][Role.count]u8 = @splat(@splat(0));
        while (try players.step()) {
            const side: usize = switch (players.int(1)) {
                100 => 0,
                200 => 1,
                else => continue,
            };
            const r = Role.fromLcu(if (players.isNull(2)) "" else players.bytes(2)) orelse continue;
            const slot = players.int(0);
            if (slot < 0 or slot >= t.participants) continue;
            pid[side][@backingInt(r)] = @intCast(slot + 1);
        }
        if (std.mem.indexOfScalar(u8, std.mem.asBytes(&pid), 0) != null) continue;

        const n = timeline.max_participants;
        var deaths: [n]u8 = @splat(0);
        var first_ms: [n]i64 = @splat(-1);
        var first_item: [n]u32 = @splat(0);
        // An undo cancels the first item only while it is p's latest purchase
        var first_is_last: [n]bool = @splat(false);
        for (t.events) |e| switch (e.data) {
            .champion_kill => |k| if (e.t_ms < 15 * minute_ms and k.victim >= 1 and k.victim <= n) {
                deaths[k.victim - 1] += 1;
            },
            .item_purchased => |b| if (b.participant >= 1 and b.participant <= n) {
                const p = b.participant - 1;
                first_is_last[p] = false;
                if (first_item[p] == 0 and std.sort.binarySearch(u32, finished, b.item, orderU32) != null) {
                    first_item[p] = b.item;
                    first_ms[p] = e.t_ms;
                    first_is_last[p] = true;
                }
            },
            .item_undo => |u| if (u.participant >= 1 and u.participant <= n) {
                const p = u.participant - 1;
                if (first_is_last[p] and u.after == 0 and u.before == first_item[p]) {
                    first_item[p] = 0;
                    first_ms[p] = -1;
                    first_is_last[p] = false;
                }
            },
            else => {},
        };

        var o: GameOutcomes = .{ .match_id = try arena.dupe(u8, q.bytes(0)), .slot = undefined, .y = undefined };
        const f10 = t.frames[10];
        const f14 = t.frames[14];
        for (0..2) |side| for (0..Role.count) |ri| {
            const p = pid[side][ri];
            const opp = pid[1 - side][ri];
            const gold = f14.get(p, .total_gold);
            o.slot[side][ri] = p - 1;
            o.y[side][ri] = .{
                @floatFromInt(gold),
                @floatFromInt(gold - f14.get(opp, .total_gold)),
                @floatFromInt(f10.get(p, .minions) + f10.get(p, .jungle_minions)),
                @floatFromInt(deaths[p - 1]),
                if (first_ms[p - 1] < 0) std.math.nan(f32) else @floatCast(@as(f64, @floatFromInt(first_ms[p - 1])) / minute_ms),
            };
        };
        try map.put(gpa, stats.matchKey(q.bytes(0)), o);
    }
    return map;
}

fn orderU32(a: u32, b: u32) std.math.Order {
    return std.math.order(a, b);
}

/// class_of[champion index]: index into `classes` of its first Data Dragon tag
fn championClasses(arena: std.mem.Allocator, db: store.Db, ids: []const u32) ![]?u8 {
    const out = try arena.alloc(?u8, ids.len);
    @memset(out, null);
    var q = try db.prepare("SELECT tags FROM champions WHERE id = ?");
    defer q.deinit();
    for (ids, out) |id, *c| {
        try q.bind(.{@as(i64, id)});
        if (!try q.step() or q.isNull(0)) continue;
        var it = std.mem.splitScalar(u8, q.bytes(0), ',');
        const first = it.next() orelse continue;
        for (classes, 0..) |name, k| {
            if (std.mem.eql(u8, name, first)) c.* = @intCast(k);
        }
    }
    return out;
}

const GameList = struct {
    gpa: std.mem.Allocator,
    items: std.ArrayList(stats.Row) = .empty,

    pub fn add(l: *GameList, g: stats.Row) !void {
        try l.items.append(l.gpa, g);
    }
};

/// Finished items per patch from `path` (lines "16.20<TAB>3078"), fetching patches the
/// file lacks from Data Dragon and appending them, so later runs need no network
pub fn loadLegendaries(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    io: Io,
    path: []const u8,
    patches: []const []const u8,
) !Legendaries {
    var lists: std.AutoArrayHashMapUnmanaged(u32, std.ArrayList(u32)) = .empty;
    const cwd = Io.Dir.cwd();
    if (cwd.readFileAlloc(io, path, arena, .limited(16 << 20))) |text| {
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        while (lines.next()) |line| {
            var it = std.mem.splitScalar(u8, line, '\t');
            const patch = stats.patchKey(it.next() orelse continue);
            const item = std.fmt.parseInt(u32, it.next() orelse continue, 10) catch continue;
            const e = try lists.getOrPut(arena, patch);
            if (!e.found_existing) e.value_ptr.* = .empty;
            try e.value_ptr.append(arena, item);
        }
    } else |err| if (err != error.FileNotFound) return err;

    var appended: std.ArrayList(u8) = .empty;
    for (patches) |p| {
        if (lists.contains(stats.patchKey(p))) continue;
        const items = try ddragon.legendaries(gpa, io, p);
        defer gpa.free(items);
        var l: std.ArrayList(u32) = .empty;
        try l.appendSlice(arena, items);
        try lists.put(arena, stats.patchKey(p), l);
        for (items) |item| try appended.print(arena, "{s}\t{d}\n", .{ p, item });
    }
    if (appended.items.len > 0) {
        const file = try cwd.createFile(io, path, .{ .truncate = false });
        defer file.close(io);
        var buf: [4096]u8 = undefined;
        var fw = file.writer(io, &buf);
        try fw.seekTo(try file.length(io));
        try fw.interface.writeAll(appended.items);
        try fw.interface.flush();
    }

    var out: Legendaries = .empty;
    var it = lists.iterator();
    while (it.next()) |e| {
        std.mem.sort(u32, e.value_ptr.items, {}, std.sort.asc(u32));
        try out.put(arena, e.key_ptr.*, e.value_ptr.items);
    }
    return out;
}

const testing = std.testing;

test "outcomes from a real timeline" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const json = try store.raw.decompress(arena, @embedFile("riot/testdata/timeline.json.gz"));
    const t = try timeline.fromJson(arena, json);
    const blob = try store.raw.compress(arena, try timeline.encode(arena, t));

    const db = try store.schema.memory();
    defer db.close();
    try db.run("INSERT INTO matches VALUES ('EUW1_1','t','EUW1',420,'16.20','',0,1600,100,0)", .{});
    try db.run("INSERT INTO timeline.timelines VALUES ('EUW1_1',26,0,?)", .{store.Blob{ .bytes = blob }});
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for (0..10) |slot| {
        try db.run(
            \\INSERT INTO participants (match_id, slot, team_id, champion_id, position, win)
            \\VALUES ('EUW1_1',?,?,?,?,0)
        , .{ slot, @as(i64, if (slot < 5) 100 else 200), slot + 1, positions[slot % 5] });
    }

    // Every item the fixture's mid laner bought counts as finished, so their first
    // item is their first purchase not undone
    var finished: std.ArrayList(u32) = .empty;
    var first_mid: ?i64 = null;
    for (t.events) |e| switch (e.data) {
        .item_purchased => |b| if (b.participant == 3) {
            try finished.append(arena, b.item);
            if (first_mid == null) first_mid = e.t_ms;
        },
        else => {},
    };
    std.mem.sort(u32, finished.items, {}, std.sort.asc(u32));
    var legendaries: Legendaries = .empty;
    defer legendaries.deinit(gpa);
    try legendaries.put(gpa, stats.patchKey("16.20"), finished.items);

    var map = try load(gpa, arena, db, &.{"16.20"}, &.{"EUW1"}, &legendaries);
    defer map.deinit(gpa);
    try testing.expectEqual(1, map.count());
    const o = map.get(stats.matchKey("EUW1_1")).?;
    const mid = @backingInt(Role.middle);
    try testing.expectEqual(2, o.slot[0][mid]);

    // Mid: participant 3 (blue) against 8 (red)
    const gold: f32 = @floatFromInt(t.frames[14].get(3, .total_gold));
    const theirs: f32 = @floatFromInt(t.frames[14].get(8, .total_gold));
    const cs: f32 = @floatFromInt(t.frames[10].get(3, .minions) + t.frames[10].get(3, .jungle_minions));
    var deaths: f32 = 0;
    for (t.events) |e| switch (e.data) {
        .champion_kill => |k| if (k.victim == 3 and e.t_ms < 15 * minute_ms) {
            deaths += 1;
        },
        else => {},
    };
    const y = o.y[0][mid];
    try testing.expectEqual(gold, y[@backingInt(Outcome.gold14)]);
    try testing.expectEqual(gold - theirs, y[@backingInt(Outcome.lanediff14)]);
    try testing.expectEqual(-(gold - theirs), o.y[1][mid][@backingInt(Outcome.lanediff14)]);
    try testing.expectEqual(cs, y[@backingInt(Outcome.cs10)]);
    try testing.expectEqual(deaths, y[@backingInt(Outcome.deaths15)]);
    try testing.expect(deaths > 0);
    try testing.expectEqual(@as(f32, @floatCast(@as(f64, @floatFromInt(first_mid.?)) / minute_ms)), y[@backingInt(Outcome.first_item)]);
}

test "an undone first item gives way to the next purchase" {
    const gpa = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const frames = try arena.alloc(timeline.Frame, 17);
    for (frames, 0..) |*f, i| f.* = .{ .t_ms = @intCast(i * minute_ms) };
    const events = [_]timeline.Event{
        .{ .t_ms = 600_000, .data = .{ .item_purchased = .{ .participant = 1, .item = 3078 } } },
        .{ .t_ms = 601_000, .data = .{ .item_undo = .{ .participant = 1, .before = 3078, .after = 0, .gold = 3300 } } },
        .{ .t_ms = 660_000, .data = .{ .item_purchased = .{ .participant = 1, .item = 3153 } } },
        // An undo of a later purchase leaves the first item alone
        .{ .t_ms = 700_000, .data = .{ .item_purchased = .{ .participant = 1, .item = 1001 } } },
        .{ .t_ms = 701_000, .data = .{ .item_undo = .{ .participant = 1, .before = 1001, .after = 0, .gold = 300 } } },
    };
    const blob = try store.raw.compress(arena, try timeline.encode(arena, .{ .participants = 10, .frames = frames, .events = &events }));

    const db = try store.schema.memory();
    defer db.close();
    try db.run("INSERT INTO matches VALUES ('EUW1_1','t','EUW1',420,'16.20','',0,1600,100,0)", .{});
    try db.run("INSERT INTO timeline.timelines VALUES ('EUW1_1',17,0,?)", .{store.Blob{ .bytes = blob }});
    const positions = [_][]const u8{ "TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY" };
    for (0..10) |slot| {
        try db.run(
            \\INSERT INTO participants (match_id, slot, team_id, champion_id, position, win)
            \\VALUES ('EUW1_1',?,?,?,?,0)
        , .{ slot, @as(i64, if (slot < 5) 100 else 200), slot + 1, positions[slot % 5] });
    }
    var legendaries: Legendaries = .empty;
    defer legendaries.deinit(gpa);
    try legendaries.put(gpa, stats.patchKey("16.20"), &.{ 3078, 3153 });
    var map = try load(gpa, arena, db, &.{"16.20"}, &.{"EUW1"}, &legendaries);
    defer map.deinit(gpa);
    const y = map.get(stats.matchKey("EUW1_1")).?.y[0][@backingInt(Role.top)];
    try testing.expectEqual(11, y[@backingInt(Outcome.first_item)]);
    // No finished item: missing, not 0
    const jungle = map.get(stats.matchKey("EUW1_1")).?.y[0][@backingInt(Role.jungle)];
    try testing.expect(std.math.isNan(jungle[@backingInt(Outcome.first_item)]));
}
