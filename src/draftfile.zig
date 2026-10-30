//! The admin Draft tester's model file (docs/model.md "Draft model file"): its shapes
//! (the scorer: core/draftscore.zig), and the writer of draft-model.json and
//! draft-ref.json. Shared by `meiolol-lab draft --export` (lab/draft.zig) and the box's
//! `meiolol draft-model` (draftmodel.zig). An empty slot counts as its role's average pick
//! on the share patch (Champions.countShares).

const std = @import("std");
const Date = @import("date.zig").Date;
const ds = @import("core").draftscore;
const sigmoid = @import("logreg.zig").sigmoid;

const Io = std.Io;

pub const n_role = ds.n_role;
pub const default_min_games = 100;
pub const z95 = ds.z95;
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

    pub const key = ds.termKey;

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

pub const Term = ds.Term;
pub const Stat = ds.Stat;
pub const TeamTerm = ds.TeamTerm;
pub const TeamKind = ds.TeamKind;
pub const raw_len = ds.raw_len;
pub const raw_magic = ds.raw_magic;
pub const raw_dmg = ds.raw_dmg;
pub const magicShare = ds.magicShare;
pub const teamForm = ds.teamForm;
pub const Comp = ds.Comp;
pub const max_k = ds.max_k;
pub const Params = ds.Params;
pub const Pairs = ds.Pairs;
pub const PairGroup = ds.PairGroup;
pub const PairCell = ds.PairCell;
pub const pairKey = ds.pairKey;
pub const Slot = ds.Slot;
pub const Scorer = ds.Scorer;
pub const Chance = ds.Chance;

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
            .newest_game = try arena.print("{f}", .{Date.fromMs(src.newest_start)}),
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
            .label = try arena.print("blue jungle to fill into {s}", .{red.label}),
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
        try drafts.append(arena, refDraft(try arena.print("Rammus jungle into {s}", .{red.label}), sc, d.bySide()));
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

/// setnet-s<seed>.json (format meiolol-setnet, version 1; lab/setnet.zig writeExport):
/// one seed's set net, a correction on a base model's blue logit. fit_newest and
/// platforms are absent from files before 23 Oct (0 and empty)
pub const SetNetFile = struct {
    format: []const u8,
    version: u32,
    candidate: []const u8 = "",
    seed: u32 = 0,
    fit_games: usize = 0,
    /// Unix ms of the newest game the net or its profiles saw
    fit_newest: i64 = 0,
    /// Platform ids in the order of the c intercepts
    platforms: []const []const u8 = &.{},
    phi: usize,
    rho: usize,
    emb: usize,
    cross: bool,
    n_prof: usize,
    features: []const []const u8 = &.{},
    layout: struct { in: usize, rin: usize, c: usize, a: usize, b1: usize, cb: usize, e: usize, w1: usize, v: usize, out: usize, len: usize },
    params: []const f32,
    ids: []const struct { champion: u32, role: u8, id: u32 },
    profiles: []const struct { champion: u32, role: u8, z: []const f32 },
    refs: []const struct { teams: [2][n_role]u32, platform: u8, offset: f32, logit: f32 },
};

/// The set net's reference forward pass, the one ui/testersetnet.zig must match:
/// logit = (f(blue, red) - f(red, blue)) / 2 + c[platform] + a * base. A slot's input is
/// its champion-role's z profile (zeros without one), its role one-hot and the
/// embedding row of its id (the role's row 0..4 without one), as for an average pick
pub const SetNet = struct {
    f: SetNetFile,
    ids: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    profiles: std.AutoHashMapUnmanaged(u64, []const f32) = .empty,
    n_platforms: usize,

    pub fn parse(arena: std.mem.Allocator, json: []const u8) !SetNet {
        return init(arena, try std.json.parseFromSliceLeaky(SetNetFile, arena, json, .{ .ignore_unknown_fields = true }));
    }

    pub fn init(arena: std.mem.Allocator, f: SetNetFile) !SetNet {
        if (!std.mem.eql(u8, f.format, "meiolol-setnet") or f.version != 1) return error.NotSetNet;
        const l = f.layout;
        const n_ids = if (f.emb > 0) (l.w1 - l.e) / f.emb else 0;
        const ok = l.len == f.params.len and l.in == f.n_prof + n_role + f.emb and
            l.rin == f.phi * @as(usize, if (f.cross) 2 else 1) and f.phi <= max_units and l.in <= max_in and
            l.c < l.a and f.platforms.len <= l.a - l.c and l.a < l.b1 and l.b1 + f.phi <= l.cb and l.cb + f.rho <= l.e and
            l.w1 + f.phi * l.in <= l.v and l.v + f.rho * l.rin <= l.out and l.out + f.rho <= l.len and
            (f.emb == 0 or n_ids >= n_role);
        if (!ok) return error.BadSetNetShape;
        var n: SetNet = .{ .f = f, .n_platforms = l.a - l.c };
        for (f.ids) |x| {
            if (x.role >= n_role or (f.emb > 0 and x.id >= n_ids)) return error.BadSetNetShape;
            try n.ids.put(arena, Champions.key(x.champion, x.role), x.id);
        }
        for (f.profiles) |x| {
            if (x.role >= n_role or x.z.len != f.n_prof) return error.BadSetNetShape;
            try n.profiles.put(arena, Champions.key(x.champion, x.role), x.z);
        }
        for (f.refs) |r| if (r.platform >= n.n_platforms) return error.BadSetNetShape;
        return n;
    }

    /// Index of a platform id among the c intercepts; null when the file has no list or
    /// not that platform
    pub fn platform(n: *const SetNet, id: []const u8) ?u8 {
        for (n.f.platforms, 0..) |p, i| if (std.mem.eql(u8, p, id)) return @intCast(i);
        return null;
    }

    /// Blue's logit for teams (0 empty) on a platform index (below n_platforms), given the
    /// base's blue logit
    pub fn logit(n: *const SetNet, teams: [2][n_role]u32, plat: u8, base: f64) f64 {
        const f = &n.f;
        const p = f.params;
        const l = f.layout;
        var t: [2][max_units]f64 = @splat(@splat(0));
        var x: [max_in]f64 = undefined;
        for (0..2) |side| for (0..n_role) |r| {
            const id = teams[side][r];
            const k = Champions.key(id, r);
            const z: []const f32 = if (id != 0) n.profiles.get(k) orelse &.{} else &.{};
            for (x[0..f.n_prof], 0..) |*o, i| o.* = if (z.len > 0) z[i] else 0;
            for (x[f.n_prof..][0..n_role], 0..) |*o, i| o.* = @floatFromInt(@intFromBool(i == r));
            const row: usize = if (id != 0) n.ids.get(k) orelse r else r;
            for (x[f.n_prof + n_role ..][0..f.emb], p[l.e + row * f.emb ..][0..f.emb]) |*o, e| o.* = e;
            for (t[side][0..f.phi], 0..) |*o, j| {
                var s: f64 = p[l.b1 + j];
                for (x[0..l.in], p[l.w1 + j * l.in ..][0..l.in]) |xi, w| s += w * xi;
                o.* += @max(s, 0) / n_role;
            }
        };
        var fs: [2]f64 = undefined;
        for (&fs, 0..) |*out, o| {
            var rin: [2 * max_units]f64 = undefined;
            @memcpy(rin[0..f.phi], t[o][0..f.phi]);
            if (f.cross) @memcpy(rin[f.phi..][0..f.phi], t[1 - o][0..f.phi]);
            out.* = 0;
            for (0..f.rho) |j| {
                var s: f64 = p[l.cb + j];
                for (rin[0..l.rin], p[l.v + j * l.rin ..][0..l.rin]) |ri, w| s += w * ri;
                if (s > 0) out.* += p[l.out + j] * s;
            }
        }
        return (fs[0] - fs[1]) / 2 + p[l.c + plat] + p[l.a] * base;
    }

    /// The file's reference games through logit: max |logit diff|
    pub fn checkRefs(n: *const SetNet) f64 {
        var worst: f64 = 0;
        for (n.f.refs) |r| worst = @max(worst, @abs(n.logit(r.teams, r.platform, r.offset) - r.logit));
        return worst;
    }
};

const max_units = 256;
const max_in = 512;

/// stats.patchKey back to "16.21"
pub fn patchLabel(arena: std.mem.Allocator, key: u32) ![]const u8 {
    return arena.print("{d}.{d}", .{ key / 1000, key % 1000 });
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

test "set net file: the documented forward pass on a hand-sized net" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // One profile trait, phi 1, rho 1, no embedding, within-team only: u = relu(z),
    // t = sum u / 5, f = 0.5 relu(t); platform c [0.1, 0.2], offset weight 0.9
    const json =
        \\{"format":"meiolol-setnet","version":1,"seed":1,"fit_newest":5,"platforms":["NA1","EUW1"],
        \\"phi":1,"rho":1,"emb":0,"cross":false,"n_prof":1,"features":["magic"],
        \\"layout":{"in":6,"rin":1,"c":0,"a":2,"b1":3,"cb":4,"e":5,"w1":5,"v":11,"out":12,"len":13},
        \\"params":[0.1,0.2,0.9,0,0,1,0,0,0,0,0,1,0.5],"ids":[],
        \\"profiles":[{"champion":7,"role":0,"z":[2]},{"champion":8,"role":0,"z":[-1]}],
        \\"refs":[{"teams":[[7,0,0,0,0],[8,0,0,0,0]],"platform":1,"offset":0.5,"logit":0.75}]}
    ;
    const n: SetNet = try .parse(arena, json);
    try std.testing.expectEqual(@as(?u8, 1), n.platform("EUW1"));
    try std.testing.expectEqual(@as(?u8, null), n.platform("KR"));
    try std.testing.expect(n.checkRefs() < 1e-6);
    var teams: [2][n_role]u32 = .{ .{ 7, 0, 0, 0, 0 }, .{ 8, 0, 0, 0, 0 } };
    // f(blue) 0.5 * 2 / 5 = 0.2, f(red) 0: 0.1 + 0.2 + 0.9 * 0.5
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), n.logit(teams, 1, 0.5), 1e-6);
    // Teams and base swapped: everything flips but the platform intercept
    std.mem.swap([n_role]u32, &teams[0], &teams[1]);
    try std.testing.expectApproxEqAbs(@as(f64, 2 * 0.2 - 0.75), n.logit(teams, 1, -0.5), 1e-6);
    // An empty slot and a champion with no profile in the role are average picks (zero
    // profile): 0.1 + 0.1 + 0.9 * 0.5 on platform 0
    try std.testing.expectApproxEqAbs(@as(f64, 0.65), n.logit(.{ .{ 7, 0, 0, 0, 0 }, .{ 0, 0, 0, 0, 0 } }, 0, 0.5), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.65), n.logit(.{ .{ 7, 0, 0, 0, 0 }, .{ 9, 0, 0, 0, 0 } }, 0, 0.5), 1e-6);
    try std.testing.expectError(error.NotSetNet, SetNet.parse(arena, "{\"format\":\"meiolol-draft-model\",\"version\":1,\"phi\":1,\"rho\":1,\"emb\":0,\"cross\":false,\"n_prof\":1,\"layout\":{\"in\":6,\"rin\":1,\"c\":0,\"a\":2,\"b1\":3,\"cb\":4,\"e\":5,\"w1\":5,\"v\":11,\"out\":12,\"len\":13},\"params\":[],\"ids\":[],\"profiles\":[],\"refs\":[]}"));
}
