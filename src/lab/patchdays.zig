//! `meiolol-lab patchdays SNAP`: docs/plan/patch-transfer.md PT2-PT3. The latest patch's
//! games scored day by day since it went live on their platform (harness.PatchDays), day d
//! by fits on every game before it, for the ratings arms on additive v2's terms (no damage
//! mix, as shipped: src/fitted.zig):
//!   A0 latest patch only; A1 pooled, no patch term (the bar); A2 pooled plus a
//!   champion-role offset on latest-patch games (additive's offset groups, variance per
//!   role estimated, or --offset-sd); A3 A2 with the changed champions' offsets' variance
//!   x --changed-scale (--changed FILE); A4 latest only, L2 prior centred on a fit of the
//!   older patches (variances estimated on the jump); A7:a pooled, latest-patch games
//!   weighted a against 1 (scaled so weights sum to the games); C A2 with the latest
//!   flag on a hashed share of fit games, as many as A2 has: a control that must gain
//!   nothing.
//! Writes OUT/preds.tsv (per scored game: match id, platform, day, bucket, any changed
//! champion, blue won, each arm's blue chance), OUT/curve.tsv (per arm, bucket and subset:
//! loss and the paired difference to A1) and OUT/days.tsv; prints the curve.
//! `patchdays changed OLD NEW`: champions whose Data Dragon championFull.json differs
//! (stats, spells' cooldown, cost, range, effectBurn and tooltip, passive text), the
//! --changed list

const std = @import("std");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");
const looks = @import("looks.zig");
const stats = @import("../stats.zig");
const A = @import("../additive.zig");
const par = @import("../par.zig");
const sigmoid = @import("../logreg.zig").sigmoid;

const Io = std.Io;
const PatchDays = harness.PatchDays;

pub const usage =
    \\  patchdays SNAP [--latest 16.21] [--arms A0,A1,A2,A3,A4,A7:3,A7:10,C]
    \\                                  [--changed FILE] [--changed-scale 16]
    \\                                  [--offset-sd LOGIT] [--threads 4] [--out DIR]
    \\                                  [--final]
    \\                                  the latest patch (default the newest) scored day
    \\                                  by day since it went live on each platform, each
    \\                                  day fitted on every game before it, for the
    \\                                  ratings arms on additive v2 (PT2-PT3,
    \\                                  docs/plan/patch-transfer.md); FILE: champion ids
    \\                                  in column 1 (patchdays changed); dev skips test
    \\                                  games, --final fits and scores them (a test look)
    \\  patchdays changed OLD NEW       champions whose Data Dragon championFull.json
    \\                                  differs: id, name, changed|new
    \\
;

pub const Kind = enum { a0, a1, a2, a3, a4, a7, c };

pub const Arm = struct {
    kind: Kind,
    /// A7's weight on latest-patch games
    a: f32 = 1,

    pub fn parse(s: []const u8) !Arm {
        if (std.mem.startsWith(u8, s, "A7:")) return .{ .kind = .a7, .a = try std.fmt.parseFloat(f32, s[3..]) };
        if (s.len == 0) return error.BadArm;
        var lower: [4]u8 = undefined;
        if (s.len > lower.len) return error.BadArm;
        return .{ .kind = std.meta.stringToEnum(Kind, std.ascii.lowerString(&lower, s)) orelse return error.BadArm };
    }

    pub fn name(arm: Arm, buf: []u8) []const u8 {
        return switch (arm.kind) {
            .a7 => std.mem.print(buf, "A7x{d}", .{arm.a}) catch unreachable,
            .c => "C",
            else => |k| std.mem.print(buf, "A{c}", .{@tagName(k)[1]}) catch unreachable,
        };
    }
};

pub const Options = struct {
    latest: ?u32 = null,
    arms: []const Arm = &.{ .{ .kind = .a0 }, .{ .kind = .a1 }, .{ .kind = .a2 }, .{ .kind = .a3 }, .{ .kind = .a4 }, .{ .kind = .a7, .a = 3 }, .{ .kind = .a7, .a = 10 }, .{ .kind = .c } },
    changed: ?[]const u8 = null,
    /// docs/model.md "Patch 16.21's first day": changed champions moved 1.92 pp RMS, the
    /// rest 0.50, so a variance ratio near 16
    changed_scale: f64 = 16,
    offset_sd: ?f64 = null,
    threads: u32 = 4,
    out: []const u8 = ".",
    phase: harness.Phase = .dev,
};

pub fn parseOptions(arena: std.mem.Allocator, argv: []const []const u8) !Options {
    var o: Options = .{};
    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const k = argv[i];
        if (std.mem.eql(u8, k, "--final")) {
            o.phase = .final;
            continue;
        }
        if (i + 1 >= argv.len) return error.MissingValue;
        i += 1;
        const v = argv[i];
        if (std.mem.eql(u8, k, "--latest")) o.latest = stats.patchKey(v) //
        else if (std.mem.eql(u8, k, "--changed")) o.changed = v //
        else if (std.mem.eql(u8, k, "--changed-scale")) o.changed_scale = try std.fmt.parseFloat(f64, v) //
        else if (std.mem.eql(u8, k, "--offset-sd")) o.offset_sd = try std.fmt.parseFloat(f64, v) //
        else if (std.mem.eql(u8, k, "--threads")) o.threads = try std.fmt.parseInt(u32, v, 10) //
        else if (std.mem.eql(u8, k, "--out")) o.out = v //
        else if (std.mem.eql(u8, k, "--arms")) {
            var list: std.ArrayList(Arm) = .empty;
            var it = std.mem.tokenizeScalar(u8, v, ',');
            while (it.next()) |s| try list.append(arena, try Arm.parse(s));
            o.arms = list.items;
        } else return error.UnknownOption;
    }
    if (o.threads == 0) return error.BadThreads;
    for (o.arms) |a| if (a.kind == .a3 and o.changed == null) return error.A3NeedsChanged;
    return o;
}

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len == 3 and std.mem.eql(u8, argv[0], "changed")) return changedMain(gpa, io, argv[1], argv[2]);
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const opts = parseOptions(arena, argv[1..]) catch |e| {
        std.debug.print("patchdays: {t}\nusage:\n{s}", .{ e, usage });
        return 2;
    };
    const snap = argv[0];
    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;
    if (opts.phase == .final) _ = try looks.record(gpa, io, Io.Dir.cwd(), snap, "patchdays", argv, w);
    var data = try rows.loadSnap(gpa, io, snap);
    defer data.deinit();
    std.debug.assert(protocol.platformIds().len <= A.n_platforms);
    const changed = if (opts.changed) |path| try loadChanged(arena, io, path) else ChampSet{};

    try Io.Dir.cwd().createDirPath(io, opts.out);
    var dir = try Io.Dir.cwd().openDir(io, opts.out, .{});
    defer dir.close(io);
    var r = try run(gpa, arena, io, &data, &changed, opts);
    defer r.deinit(gpa);
    try writeFiles(io, dir, &data, &r, &changed, opts);
    try report(w, &data, &r, &changed, opts);
    try w.flush();
    return 0;
}

pub const ChampSet = std.AutoHashMapUnmanaged(u32, void);

/// Champion ids in column 1, one a line; lines starting with # or a non-number skipped
fn loadChanged(arena: std.mem.Allocator, io: Io, path: []const u8) !ChampSet {
    const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20));
    var set: ChampSet = .empty;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        var cols = std.mem.tokenizeAny(u8, line, "\t ");
        const id = std.fmt.parseInt(u32, cols.next() orelse continue, 10) catch continue;
        try set.put(arena, id, {});
    }
    return set;
}

/// Scored games and every arm's blue chance on them, with per-day facts
pub const Result = struct {
    pd: PatchDays,
    /// Indices into data.games, by day then start order of data.games
    scored: []u32,
    /// Days with scored games, ascending
    days: []u16,
    /// [arm][scored index]
    preds: [][]f32,
    /// [day index]
    fit_games: []u32,
    latest_fit: []u32,
    /// [arm][day index]: the offset groups' sd (A2, A3, C) or A4's mean champion-strength
    /// sd of the jump, logit; NaN otherwise
    sd: [][]f64,
    /// Latest-patch games left out as test games (dev)
    held_out: usize,

    pub fn deinit(r: *Result, gpa: std.mem.Allocator) void {
        r.pd.deinit(gpa);
        gpa.free(r.scored);
        gpa.free(r.days);
        for (r.preds) |p| gpa.free(p);
        gpa.free(r.preds);
        gpa.free(r.fit_games);
        gpa.free(r.latest_fit);
        for (r.sd) |s| gpa.free(s);
        gpa.free(r.sd);
    }
};

fn blueWon(g: rows.Game) f32 {
    return if (g.winner == 0) 1 else 0;
}

fn hasAny(set: *const ChampSet, g: rows.Game) bool {
    for (g.teams) |t| for (t) |c| {
        if (set.contains(c)) return true;
    };
    return false;
}

/// C's latest flag: a fixed hash of the game below `share`
fn hashed(g: rows.Game, share: f64) bool {
    var h = std.hash.Wyhash.init(0xc0c0);
    h.update(std.mem.asBytes(&g.start));
    h.update(std.mem.asBytes(&g.platform));
    const u: f64 = @floatFromInt(h.final() >> 11);
    return u / @as(f64, 1 << 53) < share;
}

/// A fit's cells by key, for A4's prior
const KeyTheta = std.AutoHashMapUnmanaged(u64, f64);

const Shared = struct {
    gpa: std.mem.Allocator,
    d: *const rows.Data,
    pd: *const PatchDays,
    changed: *const ChampSet,
    opts: Options,
    r: *Result,
    /// [day index] the older patches' fit before that day (A4), null until fitted
    old: []?*const KeyTheta,
};

fn variant() A.Variant {
    return A.Variant.mains().matchupGroups().withOffsets();
}

fn cfgFor(opts: Options) A.Config {
    return .{ .offset_sigma2 = if (opts.offset_sd) |s| s * s else null };
}

/// The older patches' fit for day index di, as cells by key
fn fitOld(s: *const Shared, di: usize) !*KeyTheta {
    const gpa = s.gpa;
    var games: std.ArrayList(A.GameIn) = .empty;
    defer games.deinit(gpa);
    for (s.d.games) |g| {
        if (g.patch == s.pd.latest or !s.pd.fits(s.opts.phase, s.r.days[di], g)) continue;
        try games.append(gpa, .{ .teams = g.teams, .platform = g.platform, .y = blueWon(g) });
    }
    var p = try A.build(gpa, .logistic, variant(), games.items);
    defer p.deinit(gpa);
    var f = try A.fit(gpa, &p, cfgFor(s.opts), null, null);
    defer f.deinit(gpa);
    const out = try gpa.create(KeyTheta);
    out.* = .empty;
    errdefer gpa.destroy(out);
    try out.ensureTotalCapacity(gpa, @intCast(p.n_params()));
    for (p.key_of, f.theta) |k, t| out.putAssumeCapacity(k, t);
    return out;
}

fn task(s: *const Shared, i: usize) !void {
    const gpa = s.gpa;
    const n_days = s.r.days.len;
    // Latest days first: the biggest fits start early
    const di = n_days - 1 - i / s.opts.arms.len;
    const ai = i % s.opts.arms.len;
    const arm = s.opts.arms[ai];
    const day = s.r.days[di];
    const latest = s.pd.latest;
    const share = @as(f64, @floatFromInt(s.r.latest_fit[di])) / @as(f64, @floatFromInt(@max(s.r.fit_games[di], 1)));
    // A7's weights sum to the fit games, so the variances see as many games as there are
    const unit: f32 = @floatCast(1 / (1 + (arm.a - 1) * share));

    var games: std.ArrayList(A.GameIn) = .empty;
    defer games.deinit(gpa);
    for (s.d.games) |g| {
        if (!s.pd.fits(s.opts.phase, day, g)) continue;
        const is_latest = g.patch == latest;
        var in: A.GameIn = .{ .teams = g.teams, .platform = g.platform, .y = blueWon(g) };
        switch (arm.kind) {
            .a0 => if (!is_latest) continue,
            .a1 => {},
            .a2, .a3 => in.offset = is_latest,
            .c => in.offset = hashed(g, share),
            .a7 => in.weight = if (is_latest) arm.a * unit else unit,
            // Old games carry no weight, only their cells, which then sit at the prior
            // (before any latest-patch game: the old fit itself)
            .a4 => in.weight = if (is_latest) 1 else 0,
        }
        try games.append(gpa, in);
    }
    var p = try A.build(gpa, .logistic, variant(), games.items);
    defer p.deinit(gpa);
    var cfg = cfgFor(s.opts);
    const np = p.n_params();
    const mean: ?[]f64 = if (arm.kind == .a4) try gpa.alloc(f64, np) else null;
    defer if (mean) |m| gpa.free(m);
    if (mean) |m| {
        const old = s.old[di].?;
        for (m, p.key_of) |*x, k| x.* = old.get(k) orelse 0;
        cfg.prior_mean = m;
    }
    const scale: ?[]f64 = if (arm.kind == .a3) try gpa.alloc(f64, np) else null;
    defer if (scale) |sc| gpa.free(sc);
    if (scale) |sc| {
        @memset(sc, 1);
        for (p.param_start[A.g_offset]..np) |j| {
            if (s.changed.contains(A.cellOf(&p, j).a)) sc[j] = s.opts.changed_scale;
        }
        cfg.prior_scale = sc;
    }
    var f = try A.fit(gpa, &p, cfg, null, null);
    defer f.deinit(gpa);

    const sd = &s.r.sd[ai][di];
    sd.* = std.math.nan(f64);
    switch (arm.kind) {
        .a2, .a3, .c => sd.* = meanSd(&p, &f, A.g_offset, A.n_groups),
        .a4 => sd.* = meanSd(&p, &f, A.g_main, A.g_ally),
        else => {},
    }
    for (s.r.scored, s.r.preds[ai]) |gi, *out| {
        const g = s.d.games[gi];
        if (s.pd.day[gi].? != day) continue;
        const in: A.GameIn = .{ .teams = g.teams, .platform = g.platform, .y = 0, .offset = true };
        out.* = @floatCast(sigmoid(A.predict(&p, &f, &in)));
    }
}

/// Root mean of the groups' variances over the groups with cells
fn meanSd(p: *const A.Problem, f: *const A.Fit, lo: usize, hi: usize) f64 {
    var s: f64 = 0;
    var n: f64 = 0;
    for (lo..hi) |g| if (p.param_start[g + 1] > p.param_start[g]) {
        s += f.sigma2[g];
        n += 1;
    };
    return if (n > 0) @sqrt(s / n) else std.math.nan(f64);
}

pub fn run(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, d: *const rows.Data, changed: *const ChampSet, opts: Options) !Result {
    var pd = try PatchDays.init(gpa, d, opts.phase, opts.latest);
    errdefer pd.deinit(gpa);
    var held_out: usize = 0;
    for (d.games) |g| held_out += @intFromBool(g.patch == pd.latest and harness.played(g) and opts.phase == .dev and g.is_test);
    var scored: std.ArrayList(u32) = .empty;
    errdefer scored.deinit(gpa);
    var days: std.ArrayList(u16) = .empty;
    errdefer days.deinit(gpa);
    for (pd.cut, 0..) |c, day| {
        if (c == std.math.maxInt(i64)) continue;
        try days.append(gpa, @intCast(day));
        for (pd.day, 0..) |x, gi| if (x != null and x.? == day) try scored.append(gpa, @intCast(gi));
    }
    const nd = days.items.len;
    const fit_games = try gpa.alloc(u32, nd);
    errdefer gpa.free(fit_games);
    const latest_fit = try gpa.alloc(u32, nd);
    errdefer gpa.free(latest_fit);
    for (days.items, fit_games, latest_fit) |day, *n, *nl| {
        n.* = 0;
        nl.* = 0;
        for (d.games) |g| if (pd.fits(opts.phase, day, g)) {
            n.* += 1;
            nl.* += @intFromBool(g.patch == pd.latest);
        };
    }
    const preds = try gpa.alloc([]f32, opts.arms.len);
    for (preds) |*p| {
        p.* = try gpa.alloc(f32, scored.items.len);
        @memset(p.*, std.math.nan(f32));
    }
    const sd = try gpa.alloc([]f64, opts.arms.len);
    for (sd) |*s| s.* = try gpa.alloc(f64, nd);
    var r: Result = .{
        .pd = pd,
        .scored = try scored.toOwnedSlice(gpa),
        .days = try days.toOwnedSlice(gpa),
        .preds = preds,
        .fit_games = fit_games,
        .latest_fit = latest_fit,
        .sd = sd,
        .held_out = held_out,
    };
    var shared: Shared = .{ .gpa = gpa, .d = d, .pd = &r.pd, .changed = changed, .opts = opts, .r = &r, .old = try arena.alloc(?*const KeyTheta, nd) };
    @memset(shared.old, null);
    var a4 = false;
    for (opts.arms) |a| a4 = a4 or a.kind == .a4;
    var fitted: []*KeyTheta = &.{};
    defer for (fitted) |t| {
        t.deinit(gpa);
        gpa.destroy(t);
    };
    if (a4) {
        // Days nest, so days with as many old-patch fit games share one old fit
        var olds: std.ArrayList(usize) = .empty;
        var last: ?u32 = null;
        for (fit_games, latest_fit, 0..) |n, nl, di| if (last != n - nl) {
            try olds.append(arena, di);
            last = n - nl;
        };
        const slots = try arena.alloc(*KeyTheta, olds.items.len);
        const Old = struct {
            s: *const Shared,
            at: []const usize,
            out: []*KeyTheta,
            fn one(x: @This(), k: usize) !void {
                x.out[k] = try fitOld(x.s, x.at[k]);
            }
        };
        try par.forEachUpTo(io, olds.items.len, opts.threads, Old{ .s = &shared, .at = olds.items, .out = slots }, Old.one);
        fitted = slots;
        for (olds.items, fitted) |di, t| shared.old[di] = t;
        var cur: ?*const KeyTheta = null;
        for (shared.old) |*o| {
            if (o.* != null) cur = o.* else o.* = cur;
        }
    }
    try par.forEachUpTo(io, nd * opts.arms.len, opts.threads, &shared, task);
    return r;
}

/// Mean loss and the paired difference to a reference over a set of games
pub const Stat = struct {
    n: usize = 0,
    loss: f64 = 0,
    diff: f64 = 0,
    half: f64 = std.math.inf(f64),
};

fn logLoss(y: f32, p: f32) f64 {
    const q = std.math.clamp(@as(f64, p), 1e-6, 1 - 1e-6);
    return -(y * @log(q) + (1 - y) * @log(1 - q));
}

/// Over scored games where keep(index) holds
fn stat(d: *const rows.Data, r: *const Result, arm: usize, ref: usize, ctx: anytype, comptime keep: fn (@TypeOf(ctx), usize) bool) Stat {
    var n: f64 = 0;
    var sl: f64 = 0;
    var sd: f64 = 0;
    var sd2: f64 = 0;
    for (r.scored, 0..) |gi, i| {
        if (!keep(ctx, i)) continue;
        const y = blueWon(d.games[gi]);
        const l = logLoss(y, r.preds[arm][i]);
        const x = l - logLoss(y, r.preds[ref][i]);
        n += 1;
        sl += l;
        sd += x;
        sd2 += x * x;
    }
    if (n < 2) return .{ .n = @intFromFloat(n) };
    const m = sd / n;
    const v = (sd2 - n * m * m) / (n - 1);
    return .{ .n = @intFromFloat(n), .loss = sl / n, .diff = m, .half = 1.96 * @sqrt(@max(v, 0) / n) };
}

/// changed: games with a changed champion; euw1: the home platform's (PT6: EUW1 decides)
pub const Subset = enum { all, changed, euw1 };

/// Which scored games a figure covers
pub const Filter = struct {
    changed: ?*const ChampSet = null,
    platform: ?u8 = null,

    pub fn of(sub: Subset, changed: *const ChampSet) Filter {
        return switch (sub) {
            .all => .{},
            .changed => .{ .changed = changed },
            .euw1 => .{ .platform = homePlatform() },
        };
    }
};

fn homePlatform() u8 {
    for (protocol.platformIds(), 0..) |id, i| if (std.mem.eql(u8, id, protocol.home_platform)) return @intCast(i);
    unreachable;
}

const Sel = struct {
    d: *const rows.Data,
    r: *const Result,
    f: Filter = .{},
    /// Days whose bucket is this (null: any)
    bucket: ?usize = null,
    day: ?u16 = null,

    fn keep(s: Sel, i: usize) bool {
        const gi = s.r.scored[i];
        const v = s.r.pd.day[gi].?;
        if (s.day) |x| if (v != x) return false;
        if (s.bucket) |b| if (PatchDays.bucket(v) != b) return false;
        if (s.f.changed) |c| if (!hasAny(c, s.d.games[gi])) return false;
        if (s.f.platform) |p| if (s.d.games[gi].platform != p) return false;
        return true;
    }
};

pub fn refArm(opts: Options) usize {
    for (opts.arms, 0..) |a, i| if (a.kind == .a1) return i;
    return 0;
}

/// Days weighted equally: the mean of per-day differences, its variance the sum of theirs
pub fn patchMean(d: *const rows.Data, r: *const Result, arm: usize, ref: usize, f: Filter) Stat {
    var out: Stat = .{};
    var v: f64 = 0;
    var k: f64 = 0;
    for (r.days) |day| {
        const s = stat(d, r, arm, ref, Sel{ .d = d, .r = r, .f = f, .day = day }, Sel.keep);
        if (s.n < 2) continue;
        out.n += s.n;
        out.loss += s.loss;
        out.diff += s.diff;
        v += (s.half / 1.96) * (s.half / 1.96);
        k += 1;
    }
    if (k == 0) return .{};
    out.loss /= k;
    out.diff /= k;
    out.half = 1.96 * @sqrt(v) / k;
    return out;
}

fn writeFiles(io: Io, dir: Io.Dir, d: *const rows.Data, r: *const Result, changed: *const ChampSet, opts: Options) !void {
    var nbuf: [16]u8 = undefined;
    {
        var file = try dir.createFile(io, "preds.tsv", .{});
        defer file.close(io);
        var buf: [64 * 1024]u8 = undefined;
        var fw = file.writer(io, &buf);
        const w = &fw.interface;
        try w.writeAll("match_id\tplatform\tday\tbucket\tchanged\ty");
        for (opts.arms) |a| try w.print("\t{s}", .{a.name(&nbuf)});
        try w.writeAll("\n");
        const ids = protocol.platformIds();
        for (r.scored, 0..) |gi, i| {
            const g = d.games[gi];
            const v = r.pd.day[gi].?;
            try w.print("{s}\t{s}\t{d}\t{s}\t{d}\t{d}", .{ g.match_id, if (g.platform < ids.len) ids[g.platform] else "?", v, PatchDays.buckets[PatchDays.bucket(v)], @intFromBool(hasAny(changed, g)), blueWon(g) });
            for (r.preds) |p| try w.print("\t{d:.5}", .{p[i]});
            try w.writeAll("\n");
        }
        try w.flush();
    }
    const ref = refArm(opts);
    {
        var file = try dir.createFile(io, "curve.tsv", .{});
        defer file.close(io);
        var buf: [16 * 1024]u8 = undefined;
        var fw = file.writer(io, &buf);
        const w = &fw.interface;
        try w.print("arm\tbucket\tsubset\tgames\tloss\tdiff_vs_{s}\thalf\n", .{opts.arms[ref].name(&nbuf)});
        for (opts.arms, 0..) |a, ai| for (std.enums.values(Subset)) |sub| {
            const f = Filter.of(sub, changed);
            for (PatchDays.buckets, 0..) |bn, b| {
                const s = stat(d, r, ai, ref, Sel{ .d = d, .r = r, .f = f, .bucket = b }, Sel.keep);
                try w.print("{s}\t{s}\t{t}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\n", .{ a.name(&nbuf), bn, sub, s.n, s.loss, s.diff, s.half });
            }
            const s = patchMean(d, r, ai, ref, f);
            try w.print("{s}\tpatch\t{t}\t{d}\t{d:.6}\t{d:.6}\t{d:.6}\n", .{ a.name(&nbuf), sub, s.n, s.loss, s.diff, s.half });
        };
        try w.flush();
    }
    {
        var file = try dir.createFile(io, "days.tsv", .{});
        defer file.close(io);
        var buf: [16 * 1024]u8 = undefined;
        var fw = file.writer(io, &buf);
        const w = &fw.interface;
        try w.writeAll("day\tcut_ms\tfit_games\tlatest_fit\tscored\tarm\tloss\tdiff\thalf\tsd\n");
        for (r.days, 0..) |day, di| for (opts.arms, 0..) |a, ai| {
            const s = stat(d, r, ai, ref, Sel{ .d = d, .r = r, .day = day }, Sel.keep);
            try w.print("{d}\t{d}\t{d}\t{d}\t{d}\t{s}\t{d:.6}\t{d:.6}\t{d:.6}\t{d:.4}\n", .{ day, r.pd.cut[day], r.fit_games[di], r.latest_fit[di], s.n, a.name(&nbuf), s.loss, s.diff, s.half, r.sd[ai][di] });
        };
        try w.flush();
    }
}

fn report(w: *Io.Writer, d: *const rows.Data, r: *const Result, changed: *const ChampSet, opts: Options) !void {
    var nbuf: [16]u8 = undefined;
    const ref = refArm(opts);
    try w.print("# patchdays: latest patch {d}.{d}, {t}, {d} scored games on {d} days", .{ r.pd.latest / 1000, r.pd.latest % 1000, opts.phase, r.scored.len, r.days.len });
    if (r.held_out > 0) try w.print(" ({d} more held out as test games)", .{r.held_out});
    try w.print("; changed champions {d}, scale {d}; offset sd {s}\n\n", .{ changed.count(), opts.changed_scale, if (opts.offset_sd != null) "fixed" else "estimated" });
    try w.writeAll("| day | fit games | latest-patch fit games | scored |\n| --- | --- | --- | --- |\n");
    for (r.days, 0..) |day, di| {
        var n: usize = 0;
        for (r.scored) |gi| n += @intFromBool(r.pd.day[gi].? == day);
        try w.print("| {d} | {d} | {d} | {d} |\n", .{ day, r.fit_games[di], r.latest_fit[di], n });
    }
    for (std.enums.values(Subset)) |sub| {
        const f = Filter.of(sub, changed);
        if (sub == .changed and changed.count() == 0) continue;
        const what = switch (sub) {
            .all => "all",
            .changed => "changed-champion",
            .euw1 => protocol.home_platform,
        };
        try w.print("\nMilli-nats a game vs {s} ({s}: its log loss), 95% paired; {s} games\n\n| arm |", .{ opts.arms[ref].name(&nbuf), opts.arms[ref].name(&nbuf), what });
        for (PatchDays.buckets) |b| try w.print(" day {s} |", .{b});
        try w.writeAll(" patch (days equal) |\n| --- |");
        for (0..PatchDays.buckets.len + 1) |_| try w.writeAll(" --- |");
        try w.writeAll("\n| games |");
        for (0..PatchDays.buckets.len) |b| try w.print(" {d} |", .{stat(d, r, ref, ref, Sel{ .d = d, .r = r, .f = f, .bucket = b }, Sel.keep).n});
        try w.print(" {d} |\n", .{patchMean(d, r, ref, ref, f).n});
        for (opts.arms, 0..) |a, ai| {
            try w.print("| {s} |", .{a.name(&nbuf)});
            for (0..PatchDays.buckets.len) |b| {
                const s = stat(d, r, ai, ref, Sel{ .d = d, .r = r, .f = f, .bucket = b }, Sel.keep);
                try cell(w, s, ai == ref);
            }
            try cell(w, patchMean(d, r, ai, ref, f), ai == ref);
            try w.writeAll("\n");
        }
    }
    for (opts.arms, 0..) |a, ai| if (a.kind == .a0) {
        try w.writeAll("\nA0 vs A1 by day:");
        var caught: ?u16 = null;
        for (r.days) |day| {
            const s = stat(d, r, ai, ref, Sel{ .d = d, .r = r, .day = day }, Sel.keep);
            try w.print(" {d}: {d:.2} ± {d:.2};", .{ day, s.diff * 1000, s.half * 1000 });
            if (caught == null and s.diff - s.half <= 0) caught = day;
        }
        if (caught) |c| try w.print("\nA0 first within its interval of A1 (or better) on day {d}\n", .{c}) else try w.writeAll("\nA0 never catches A1 here\n");
    };
}

fn cell(w: *Io.Writer, s: Stat, is_ref: bool) !void {
    if (s.n < 2) return w.writeAll(" - |");
    if (is_ref) return w.print(" {d:.5} |", .{s.loss});
    try w.print(" {s}{d:.2} ± {d:.2} |", .{ if (s.diff >= 0) "+" else "", s.diff * 1000, s.half * 1000 });
}

/// `patchdays changed OLD NEW`
fn changedMain(gpa: std.mem.Allocator, io: Io, old_path: []const u8, new_path: []const u8) !u8 {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const old = try loadChampions(arena, io, old_path);
    const new = try loadChampions(arena, io, new_path);
    var buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    const list = try changedList(arena, old, new);
    for (list) |c| try w.print("{s}\t{s}\t{s}\n", .{ c.key, c.name, if (c.new) "new" else "changed" });
    try w.flush();
    return 0;
}

fn loadChampions(arena: std.mem.Allocator, io: Io, path: []const u8) !std.json.ObjectMap {
    const text = try Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20));
    const v = try std.json.parseFromSliceLeaky(std.json.Value, arena, text, .{});
    if (v != .object) return error.NotChampionFull;
    const data = v.object.get("data") orelse return error.NotChampionFull;
    if (data != .object) return error.NotChampionFull;
    return data.object;
}

pub const Changed = struct { key: []const u8, name: []const u8, new: bool };

/// Champions of `new` that `old` lacks or whose stats, spells' numbers and texts or
/// passive text differ, by name
pub fn changedList(arena: std.mem.Allocator, old: std.json.ObjectMap, new: std.json.ObjectMap) ![]Changed {
    var out: std.ArrayList(Changed) = .empty;
    var it = new.iterator();
    while (it.next()) |e| {
        const c = e.value_ptr.*;
        if (c != .object) continue;
        const key = if (c.object.get("key")) |k| (if (k == .string) k.string else "?") else "?";
        const o = old.get(e.key_ptr.*) orelse {
            try out.append(arena, .{ .key = key, .name = e.key_ptr.*, .new = true });
            continue;
        };
        if (!sameKit(o, c)) try out.append(arena, .{ .key = key, .name = e.key_ptr.*, .new = false });
    }
    std.mem.sort(Changed, out.items, {}, struct {
        fn lt(_: void, a: Changed, b: Changed) bool {
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.lt);
    return out.items;
}

fn field(v: std.json.Value, name: []const u8) ?std.json.Value {
    return if (v == .object) v.object.get(name) else null;
}

fn sameField(a: std.json.Value, b: std.json.Value, name: []const u8) bool {
    const x = field(a, name);
    const y = field(b, name);
    if (x == null or y == null) return x == null and y == null;
    return eql(x.?, y.?);
}

fn sameKit(a: std.json.Value, b: std.json.Value) bool {
    if (!sameField(a, b, "stats")) return false;
    const pa = field(a, "passive");
    const pb = field(b, "passive");
    if ((pa == null) != (pb == null)) return false;
    if (pa != null and !sameField(pa.?, pb.?, "description")) return false;
    const sa = field(a, "spells") orelse return field(b, "spells") == null;
    const sb = field(b, "spells") orelse return false;
    if (sa != .array or sb != .array) return eql(sa, sb);
    if (sa.array.items.len != sb.array.items.len) return false;
    for (sa.array.items, sb.array.items) |x, y| {
        for ([_][]const u8{ "cooldown", "cost", "range", "effectBurn", "tooltip" }) |f| {
            if (!sameField(x, y, f)) return false;
        }
    }
    return true;
}

fn eql(a: std.json.Value, b: std.json.Value) bool {
    if (num(a)) |x| if (num(b)) |y| return x == y;
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
    return switch (a) {
        .null => true,
        .bool => |x| x == b.bool,
        .string => |x| std.mem.eql(u8, x, b.string),
        .array => |x| blk: {
            if (x.items.len != b.array.items.len) break :blk false;
            for (x.items, b.array.items) |p, q| if (!eql(p, q)) break :blk false;
            break :blk true;
        },
        .object => |x| blk: {
            if (x.count() != b.object.count()) break :blk false;
            var it = x.iterator();
            while (it.next()) |e| {
                const other = b.object.get(e.key_ptr.*) orelse break :blk false;
                if (!eql(e.value_ptr.*, other)) break :blk false;
            }
            break :blk true;
        },
        .integer, .float, .number_string => false,
    };
}

fn num(v: std.json.Value) ?f64 {
    return switch (v) {
        .integer => |x| @floatFromInt(x),
        .float => |x| x,
        .number_string => |s| std.fmt.parseFloat(f64, s) catch null,
        else => null,
    };
}

/// n games a minute apart over 3 platforms, 10 champions a role; from minute `from` on
/// patch 16.21, where top champion 1 gains `jump` logit
fn fixture(gpa: std.mem.Allocator, n: usize, from: usize, jump: f64) !rows.Data {
    var data: rows.Data = .{ .arena = .init(gpa), .games = &.{}, .rows = &.{} };
    errdefer data.deinit();
    const games = try data.arena.allocator().alloc(rows.Game, n);
    var rng: std.Random.DefaultPrng = .init(77);
    const rnd = rng.random();
    var mains: [5][10]f64 = undefined;
    for (&mains) |*m| for (m) |*x| {
        x.* = rnd.floatNorm(f64) * 0.3;
    };
    for (games, 0..) |*g, i| {
        const latest = i >= from;
        g.* = .{ .match_id = "", .start = @intCast(i * 60_000), .patch = if (latest) 16021 else 16020, .platform = @intCast(i % 3), .is_test = false, .teams = undefined, .winner = 0, .duration_s = 1800 };
        var eta: f64 = 0;
        for (0..2) |s| for (0..5) |r| {
            const c = rnd.uintLessThan(u32, 10);
            g.teams[s][r] = @intCast(1 + r * 100 + c);
            const sign: f64 = if (s == 0) 1 else -1;
            eta += sign * mains[r][c];
            if (latest and r == 0 and c == 0) eta += sign * jump;
        };
        g.winner = if (rnd.float(f64) < sigmoid(eta)) 0 else 1;
    }
    data.games = games;
    return data;
}

test "patchdays: arms on a planted jump; latest-only knows nothing on day 0, the control gains nothing" {
    const gpa = std.testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var data = try fixture(gpa, 12_000, 6_000, 0.8);
    defer data.deinit();
    var changed: ChampSet = .empty;
    try changed.put(arena, 1, {});
    const opts = try parseOptions(arena, &.{ "--arms", "A0,A1,A2,A3,A4,A7:5,C", "--changed", "x", "--threads", "2" });
    var r = try run(gpa, arena, std.testing.io, &data, &changed, opts);
    defer r.deinit(gpa);
    try std.testing.expectEqual(16021, r.pd.latest);
    try std.testing.expectEqual(6000, r.scored.len);
    try std.testing.expectEqual(0, r.days[0]);
    for (r.preds) |p| for (p) |x| try std.testing.expect(!std.math.isNan(x));
    // Day 0: nothing of the patch fitted yet. A0 is a coin, A4 the old fit, which is A1's
    for (r.scored, 0..) |gi, i| if (r.pd.day[gi].? == 0) {
        try std.testing.expectEqual(0.5, r.preds[0][i]);
        try std.testing.expectApproxEqAbs(r.preds[1][i], r.preds[4][i], 1e-4);
        try std.testing.expectApproxEqAbs(r.preds[1][i], r.preds[6][i], 1e-6);
    };
    const ref = refArm(opts);
    try std.testing.expectEqual(1, ref);
    // On the changed champion's games every patch-aware arm beats pooled over the patch
    for ([_]usize{ 2, 3, 4, 5 }) |ai| {
        const s = patchMean(&data, &r, ai, ref, .{ .changed = &changed });
        try std.testing.expect(s.diff + s.half < 0);
    }
    // The looser prior for the changed champion helps there
    try std.testing.expect(patchMean(&data, &r, 3, ref, .{ .changed = &changed }).diff < patchMean(&data, &r, 2, ref, .{ .changed = &changed }).diff);
    // Shuffled patch flags: no gain (its offsets shrink to ~0); the real jump's is bigger
    const c = patchMean(&data, &r, 6, ref, .{});
    try std.testing.expect(@abs(c.diff) < 0.0005);
    try std.testing.expect(patchMean(&data, &r, 2, ref, .{}).diff < c.diff - 0.002);
    // One platform's figures cover its games alone
    var on_one: usize = 0;
    for (r.scored) |gi| on_one += @intFromBool(data.games[gi].platform == 1);
    try std.testing.expect(on_one > 0);
    try std.testing.expectEqual(on_one, patchMean(&data, &r, 2, ref, .{ .platform = 1 }).n);
    try std.testing.expectEqualStrings(protocol.home_platform, protocol.platformIds()[Filter.of(.euw1, &changed).platform.?]);
}

test "patchdays: arms and options parse" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const o = try parseOptions(arena, &.{ "--arms", "A1,a4,A7:2.5,C", "--latest", "16.21", "--final" });
    try std.testing.expectEqual(4, o.arms.len);
    try std.testing.expectEqual(Kind.a4, o.arms[1].kind);
    try std.testing.expectEqual(2.5, o.arms[2].a);
    try std.testing.expectEqual(16021, o.latest.?);
    try std.testing.expectEqual(harness.Phase.final, o.phase);
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("A7x2.5", o.arms[2].name(&buf));
    try std.testing.expectEqualStrings("A4", o.arms[1].name(&buf));
    try std.testing.expectError(error.A3NeedsChanged, parseOptions(arena, &.{ "--arms", "A3" }));
    try std.testing.expectError(error.BadArm, parseOptions(arena, &.{ "--arms", "A9" }));
}

test "patchdays changed: stats, spell numbers and passive text count, other fields don't" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const old_text =
        \\{"data":{"Ahri":{"key":"103","stats":{"hp":590},"spells":[{"cooldown":[7,7],"cost":[60],"range":[880],"effectBurn":[null,"40"],"tooltip":"a"}],"passive":{"description":"p"},"lore":"x"},
        \\"Annie":{"key":"1","stats":{"hp":560},"spells":[{"cooldown":[4],"cost":[60],"range":[625],"effectBurn":[null],"tooltip":"t"}],"passive":{"description":"q"}},
        \\"Ashe":{"key":"22","stats":{"hp":610},"spells":[],"passive":{"description":"r"}}}}
    ;
    const new_text =
        \\{"data":{"Ahri":{"key":"103","stats":{"hp":590.0},"spells":[{"cooldown":[7,7],"cost":[60],"range":[880],"effectBurn":[null,"40"],"tooltip":"a"}],"passive":{"description":"p"},"lore":"new lore"},
        \\"Annie":{"key":"1","stats":{"hp":560},"spells":[{"cooldown":[3.5],"cost":[60],"range":[625],"effectBurn":[null],"tooltip":"t"}],"passive":{"description":"q"}},
        \\"Ashe":{"key":"22","stats":{"hp":610},"spells":[],"passive":{"description":"r2"}},
        \\"Zaahen":{"key":"904","stats":{},"spells":[],"passive":{"description":""}}}}
    ;
    const old = (try std.json.parseFromSliceLeaky(std.json.Value, arena, old_text, .{})).object.get("data").?.object;
    const new = (try std.json.parseFromSliceLeaky(std.json.Value, arena, new_text, .{})).object.get("data").?.object;
    const list = try changedList(arena, old, new);
    try std.testing.expectEqual(3, list.len);
    try std.testing.expectEqualStrings("Annie", list[0].name);
    try std.testing.expectEqualStrings("1", list[0].key);
    try std.testing.expectEqualStrings("Ashe", list[1].name);
    try std.testing.expect(list[2].new and std.mem.eql(u8, list[2].name, "Zaahen"));
}
