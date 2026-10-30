//! A Daily Draft puzzle (src/daily.zig JSON) as its page's data (ui/dailydata.zig,
//! daily/<n>.bin). Candidates come from the review: the hidden seat's top picks with
//! their reasons, and the played one; every other seat the model's top and the played
//! one, without reasons. Ranked puzzles have no turns, so their bans go per side
const std = @import("std");
const daily = @import("../daily.zig");
const core = @import("core");
const leaguepedia = @import("../leaguepedia.zig");
const ui = @import("ui");
const root = @import("root.zig");
const dd = ui.dailydata;
const Champ = ui.champ.Champ;
const Site = root.Site;
const File = root.File;
const log = std.log.scoped(.site);

/// The waterfall's start, an even game: a pick's win chance is this plus its terms and
/// rest. The puzzle has no per-role average to start from
const base = 50;

comptime {
    std.debug.assert(@backingInt(dd.Side.blue) == 0 and @backingInt(dd.Side.red) == 1);
    for (leaguepedia.order, dd.pro_sides) |c, side| std.debug.assert(c.side == @backingInt(side));
}

/// daily/<n>.bin beside each daily/<n>.json in `daily_files`; none without Learn's facts
/// (the damage mix: a cached part would keep it wrong). A puzzle that doesn't parse (made
/// before a field it needs) or names a champion the site doesn't know gets none: the page
/// says so
pub fn files(site: *const Site, daily_files: []const File, out: *std.ArrayList(File)) !void {
    if (site.learn == null) return log.info("daily page data: no Learn facts", .{});
    const ctx: SiteCtx = .{ .site = site, .ranges = try loadRanges(site) };
    try filesWith(site.arena, daily_files, out, ctx, siteChamp, siteMagic, siteRanged);
}

const SiteCtx = struct {
    site: *const Site,
    ranges: Ranges,
};

/// Ranged or melee by champion id
const Ranges = std.AutoHashMapUnmanaged(u32, bool);

/// Champions whose attack range changes with a form or a level (Gnar's mini form is
/// ranged, Kayle's turns at 6), and Lillia (325, between the two):
/// Data Dragon's one number would guess, so no hint
const no_range = [_][]const u8{ "Elise", "Gnar", "Jayce", "Kayle", "Lillia", "Nidalee" };

/// From the site's Data Dragon version in Options.ddragon_dir (championFull.json, as
/// patchnotes caches it); empty without it, and the hint hides
fn loadRanges(site: *const Site) !Ranges {
    const dir = site.opts.ddragon_dir orelse return .empty;
    if (site.ddragon_version.len == 0) return .empty;
    const path = try std.fs.path.join(site.arena, &.{ dir, site.ddragon_version, "championFull.json" });
    const body = std.Io.Dir.cwd().readFileAlloc(site.io, path, site.arena, .limited(1 << 26)) catch |err| {
        log.info("daily range hint: {s}: {t}", .{ path, err });
        return .empty;
    };
    return rangesOf(site.arena, body) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            log.warn("daily range hint: {s}: {t}", .{ path, err });
            return .empty;
        },
    };
}

/// Data Dragon 16.20: melee attack ranges 125 to 225, ranged from 300 (Rakan)
fn rangesOf(a: std.mem.Allocator, champion_full: []const u8) !Ranges {
    const Entry = struct {
        id: []const u8 = "",
        key: []const u8 = "",
        stats: struct { attackrange: ?f64 = null } = .{},
    };
    const doc = try std.json.parseFromSliceLeaky(struct { data: std.json.ArrayHashMap(Entry) }, a, champion_full, .{ .ignore_unknown_fields = true });
    var out: Ranges = .empty;
    for (doc.data.map.values()) |e| {
        if (for (no_range) |n| {
            if (std.mem.eql(u8, n, e.id)) break true;
        } else false) continue;
        const range = e.stats.attackrange orelse continue;
        const id = std.fmt.parseInt(u32, e.key, 10) catch continue;
        try out.put(a, id, range > 250);
    }
    return out;
}

fn filesWith(
    a: std.mem.Allocator,
    daily_files: []const File,
    out: *std.ArrayList(File),
    ctx: anytype,
    champ: fn (@TypeOf(ctx), u32) anyerror!Champ,
    magic: fn (@TypeOf(ctx), u32) ?f32,
    ranged: fn (@TypeOf(ctx), u32) ?bool,
) !void {
    for (daily_files) |f| {
        const n = puzzleName(f.path) orelse continue;
        const opts: std.json.ParseOptions = .{ .ignore_unknown_fields = true };
        const p = std.json.parseFromSliceLeaky(daily.Puzzle, a, f.data, opts) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => {
                log.info("{s}: no page data: {t}", .{ f.path, err });
                continue;
            },
        };
        const d = puzzle(a, p, ctx, champ, magic, ranged) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {
                log.info("{s}: no page data: {t}", .{ f.path, err });
                continue;
            },
        };
        if (!d.valid()) {
            log.warn("{s}: page data fails its check", .{f.path});
            continue;
        }
        try out.append(a, .{ .path = try a.print("daily/{s}.bin", .{n}), .data = try dd.encode(a, d) });
    }
}

/// "7" for "daily/7.json"; null for the index or any other file
fn puzzleName(path: []const u8) ?[]const u8 {
    const prefix = "daily/";
    const suffix = ".json";
    if (!std.mem.startsWith(u8, path, prefix) or !std.mem.endsWith(u8, path, suffix)) return null;
    const n = path[prefix.len .. path.len - suffix.len];
    if (n.len == 0) return null;
    for (n) |c| if (!std.ascii.isDigit(c)) return null;
    return n;
}

fn siteChamp(ctx: SiteCtx, id: u32) anyerror!Champ {
    const site = ctx.site;
    const ch = for (site.champs) |c| {
        if (c.id == id) break c;
    } else return error.UnknownChampion;
    return .{ .name = ch.name, .src = try site.icon(ch) };
}

fn siteRanged(ctx: SiteCtx, id: u32) ?bool {
    return ctx.ranges.get(id);
}

fn siteMagic(ctx: SiteCtx, id: u32) ?f32 {
    const site = ctx.site;
    const facts = site.learn orelse return null;
    const i = site.stats.index(id) orelse return null;
    if (i >= facts.champs.len) return null;
    return facts.champs[i].magic;
}

pub fn puzzle(
    a: std.mem.Allocator,
    p: daily.Puzzle,
    ctx: anytype,
    champ: fn (@TypeOf(ctx), u32) anyerror!Champ,
    /// Magic share of a champion's damage to champions, 0..1; null unsampled
    magic: fn (@TypeOf(ctx), u32) ?f32,
    /// The champion's basic attack is ranged; null where it changes or is unknown
    ranged: fn (@TypeOf(ctx), u32) ?bool,
) !dd.Puzzle {
    var ids: Ids = .{ .a = a };
    var seats: [2][5]dd.Seat = undefined;
    for (0..2) |t| for (0..5) |r| {
        const id = p.teams[t][r];
        const pl: daily.Player = if (p.players) |ps| ps[t][r] else .{};
        const rs: ?daily.Seat = if (p.review) |rv| rv.seats[t][r] else null;
        var cands: std.ArrayList(dd.Cand) = .empty;
        // The hidden seat's come from the review's picks (hiddenCands)
        const hidden = t == p.hidden_team and r == @backingInt(p.hidden_role);
        if (rs) |x| if (!hidden) {
            if (x.top != id) try cands.append(a, try plain(&ids, x.top, 1, x.top_win));
            try cands.append(a, try plain(&ids, id, x.rank, x.win));
        };
        seats[t][r] = .{
            .champ = try ids.at(id),
            .magic = magic(ctx, id),
            .kills = clamp16(pl.kills),
            .deaths = clamp16(pl.deaths),
            .assists = clamp16(pl.assists),
            .cs = clamp16(pl.cs),
            .gold = pl.gold,
            .damage = pl.damage,
            .base = base,
            .rank = if (rs) |x| clamp16(x.rank) else null,
            .of = if (rs) |x| clamp16(x.of) else 0,
            .cands = try cands.toOwnedSlice(a),
        };
    };
    const ht = p.hidden_team;
    const hr = @backingInt(p.hidden_role);
    if (p.review) |rv| seats[ht][hr].cands = try hiddenCands(a, &ids, p, rv);

    var turns: []dd.Turn = &.{};
    var bans: [2][]const u16 = .{ &.{}, &.{} };
    if (p.turns) |ts| {
        turns = try a.alloc(dd.Turn, ts.len);
        for (turns, ts) |*x, t| x.* = .{
            .champ = if (t.id) |id| try ids.at(id) else null,
            .side = @fromBackingInt(@intCast(t.side)),
        };
    } else for (0..2) |t| {
        const b = try a.alloc(u16, p.bans[t].len);
        for (b, p.bans[t]) |*x, id| x.* = try ids.at(id);
        bans[t] = b;
    }
    const options = try a.alloc(u16, p.options.len);
    for (options, p.options) |*x, o| x.* = try ids.at(o.id);
    var lanes: [5]?f32 = undefined;
    for (&lanes, p.lanes) |*x, l| x.* = if (l.win) |w| @floatCast(w) else null;

    const champs = try a.alloc(Champ, ids.ids.items.len);
    for (champs, ids.ids.items) |*c, id| c.* = try champ(ctx, id);
    const paper: ?dd.Paper = if (p.review) |rv| .{
        .blue = @floatCast(rv.blue_win),
        .low = @floatCast(rv.blue_low),
        .high = @floatCast(rv.blue_high),
        .edges = .{ @floatCast(rv.edge.champions), @floatCast(rv.edge.teammates), @floatCast(rv.edge.lanes), @floatCast(rv.edge.matchups) },
    } else null;
    return .{
        .n = p.n,
        .patch = p.patch,
        .champs = champs,
        .seats = seats,
        .turns = turns,
        .bans = bans,
        .hidden_side = @fromBackingInt(@intCast(p.hidden_team)),
        .hidden_role = uiRole(p.hidden_role),
        .options = options,
        .hint = try hintFor(a, p, ctx, magic, ranged),
        .lanes = lanes,
        .result = .{
            .winner = @fromBackingInt(@intCast(p.winner)),
            .secs = std.math.mul(u32, p.minutes, 60) catch std.math.maxInt(u32),
            .kills = .{ clamp16(p.kills[0]), clamp16(p.kills[1]) },
            .gold = p.gold,
        },
        .paper = paper,
    };
}

const Ids = struct {
    a: std.mem.Allocator,
    ids: std.ArrayList(u32) = .empty,

    fn at(x: *Ids, id: u32) !u16 {
        if (std.mem.findScalar(u32, x.ids.items, id)) |i| return @intCast(i);
        try x.ids.append(x.a, id);
        return @intCast(x.ids.items.len - 1);
    }
};

fn plain(ids: *Ids, id: u32, rank: u32, win: f64) !dd.Cand {
    return .{ .champ = try ids.at(id), .rank = clamp16(rank), .win = @floatCast(win), .terms = &.{}, .rest = @floatCast(win - base) };
}

/// The review's top picks with their reasons as terms, then the options not among them
/// at their ranks (the guess placed: what should have been picked of what was offered),
/// best first. Reviews from before the ranks add only the played one (its win chance the
/// seat's). A pick from before win chances were kept is left out; the others keep the
/// model's rank, so the shown ranks can skip one
fn hiddenCands(a: std.mem.Allocator, ids: *Ids, p: daily.Puzzle, rv: daily.Review) ![]const dd.Cand {
    var out: std.ArrayList(dd.Cand) = .empty;
    for (rv.picks, 1..) |o, rank| {
        const win = o.win orelse continue;
        try out.append(a, try cand(a, ids, o, @intCast(rank), win));
    }
    const s = rv.seats[p.hidden_team][@backingInt(p.hidden_role)];
    const ranked = rv.ranks.len == p.options.len;
    for (p.options, 0..) |o, i| {
        if (inPicks(rv.picks, o.id)) continue;
        if (o.id == p.played) {
            try out.append(a, try cand(a, ids, o, s.rank, s.win));
        } else if (ranked) {
            try out.append(a, try cand(a, ids, o, rv.ranks[i], o.win orelse continue));
        }
    }
    std.sort.insertion(dd.Cand, out.items, {}, byRank);
    return out.toOwnedSlice(a);
}

fn inPicks(picks: []const daily.Option, id: u32) bool {
    for (picks) |o| if (o.id == id and o.win != null) return true;
    return false;
}

fn byRank(_: void, x: dd.Cand, y: dd.Cand) bool {
    return x.rank < y.rank;
}

fn cand(a: std.mem.Allocator, ids: *Ids, o: daily.Option, rank: u32, win: f64) !dd.Cand {
    const terms = try a.alloc(dd.Term, o.reasons.len);
    var rest = win - base;
    for (terms, o.reasons) |*t, r| {
        t.* = .{
            .kind = switch (r.kind) {
                .base => .strength,
                .ally => .with,
                .enemy => .into,
            },
            .other = if (r.kind == .base) null else try ids.at(r.id),
            .pp = @floatCast(r.pp),
            .games = r.games,
        };
        rest -= r.pp;
    }
    return .{ .champ = try ids.at(o.id), .rank = clamp16(rank), .win = @floatCast(win), .terms = terms, .rest = @floatCast(rest) };
}

fn uiRole(r: core.Role) ui.role.Role {
    return switch (r) {
        .top => .top,
        .jungle => .jungle,
        .middle => .mid,
        .bottom => .bot,
        .utility => .support,
    };
}

fn clamp16(x: u32) u16 {
    return @intCast(@min(x, std.math.maxInt(u16)));
}

const Traits = struct { ranged: ?bool, dmg: ?dd.Dmg };

fn hintFor(
    a: std.mem.Allocator,
    p: daily.Puzzle,
    ctx: anytype,
    magic: fn (@TypeOf(ctx), u32) ?f32,
    ranged: fn (@TypeOf(ctx), u32) ?bool,
) !?dd.Hint {
    const opts = try a.alloc(Traits, p.options.len);
    for (opts, p.options) |*t, o| t.* = .{ .ranged = ranged(ctx, o.id), .dmg = dd.dmgOf(magic(ctx, o.id)) };
    return hintOf(.{ .ranged = ranged(ctx, p.played), .dmg = dd.dmgOf(magic(ctx, p.played)) }, opts);
}

/// The played pick's trait that leaves the fewest options, two at least (one would be
/// the answer), range before damage on a tie; null when none splits them. An option
/// whose trait is unknown stays in, so the hint never rules one out wrongly
fn hintOf(played: Traits, options: []const Traits) ?dd.Hint {
    if (options.len > 8) return null;
    var best: ?dd.Hint = null;
    var left: usize = options.len;
    if (played.ranged) |r| {
        var fits: u8 = 0;
        for (options, 0..) |o, i| if ((o.ranged orelse r) == r) {
            fits |= @as(u8, 1) << @intCast(i);
        };
        const n = @popCount(fits);
        if (n >= 2 and n < left) {
            best = .{ .kind = if (r) .ranged else .melee, .fits = fits };
            left = n;
        }
    }
    if (played.dmg) |d| if (d != .mixed) {
        var fits: u8 = 0;
        for (options, 0..) |o, i| if ((o.dmg orelse d) == d) {
            fits |= @as(u8, 1) << @intCast(i);
        };
        const n = @popCount(fits);
        if (n >= 2 and n < left) best = .{ .kind = if (d == .ad) .ad else .ap, .fits = fits };
    };
    return best;
}

const testing = std.testing;

const Fake = struct {
    fn champ(_: Fake, id: u32) anyerror!Champ {
        if (id == 0 or id > names.len) return error.UnknownChampion;
        return .{ .name = names[id - 1], .src = "" };
    }
    fn magic(_: Fake, id: u32) ?f32 {
        return if (id == 3) 0.9 else if (id == 1) 0.1 else null;
    }
    fn ranged(_: Fake, id: u32) ?bool {
        return if (id == 8) true else null;
    }
    const names = [_][]const u8{ "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M" };
};

fn reason(kind: @FieldType(daily.Reason, "kind"), id: u32, pp: f64) daily.Reason {
    return .{ .kind = kind, .id = id, .role = .middle, .pp = pp, .games = 900 };
}

// File scope: built inside testPuzzle they would be stack temporaries
const test_options = [_]daily.Option{
    .{ .id = 12, .games = 50, .reasons = &.{} },
    .{ .id = 8, .games = 80, .reasons = &.{reason(.enemy, 3, 1.5)}, .win = 49 },
};

fn testPuzzle(turns: ?[]const daily.Turn, review: ?daily.Review) daily.Puzzle {
    return .{
        .n = 7,
        .date = "2026-10-17",
        .patch = "16.20",
        .tier = null,
        .games = 1000,
        .teams = .{ .{ 1, 2, 3, 4, 5 }, .{ 6, 7, 8, 9, 10 } },
        .bans = .{ &.{11}, &.{} },
        .hidden_team = 1,
        .hidden_role = .middle,
        .played = 8,
        .options = &test_options,
        .winner = 0,
        .minutes = 31,
        .kills = .{ 20, 12 },
        .gold = .{ 60000, 52000 },
        .lanes = @splat(.{ .pp = 0, .games = 0 }),
        .players = null,
        .review = review,
        .turns = turns,
    };
}

const test_review: daily.Review = .{
    .blue_win = 52.5,
    .blue_low = 50.1,
    .blue_high = 54.9,
    .edge = .{ .champions = 1, .teammates = 0.5, .lanes = 0.6, .matchups = 0.4 },
    .seats = @splat(@splat(.{ .rank = 2, .of = 30, .win = 48, .top = 13, .top_win = 49.5, .range = 1 })),
    .picks = &.{
        .{ .id = 13, .games = 400, .reasons = &.{ reason(.base, 13, 0.8), reason(.ally, 7, -0.3) }, .win = 51 },
        .{ .id = 12, .games = 50, .reasons = &.{} },
    },
};

test "a ranked puzzle: bans per side, the played pick's reasons from its option, no paper without a review" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const bare = try puzzle(a, testPuzzle(null, null), Fake{}, Fake.champ, Fake.magic, Fake.ranged);
    try testing.expect(bare.valid());
    try testing.expect(bare.paper == null);
    try testing.expectEqual(ui.role.Role.mid, bare.hidden_role);
    try testing.expectEqual(@as(usize, 0), bare.turns.len);
    try testing.expectEqualStrings("K", bare.champs[bare.bans[0][0]].name);
    try testing.expectEqual(@as(usize, 0), bare.seats[1][2].cands.len);
    try testing.expectEqual(@as(?f32, 0.9), bare.seats[0][2].magic);
    try testing.expectEqual(@as(?f32, 0.1), bare.seats[0][0].magic);
    try testing.expectEqual(null, bare.seats[0][1].magic);

    const p = try puzzle(a, testPuzzle(null, test_review), Fake{}, Fake.champ, Fake.magic, Fake.ranged);
    try testing.expect(p.valid());
    try testing.expectApproxEqAbs(@as(f32, 52.5), p.paper.?.blue, 1e-4);
    // The top pick with its two reasons; the second pick has no win chance (left out);
    // then the played one, ranked as the seat says, its win chance the seat's
    const hidden = p.seats[1][2].cands;
    try testing.expectEqual(@as(usize, 2), hidden.len);
    try testing.expectEqualStrings("M", p.champs[hidden[0].champ].name);
    try testing.expectEqual(dd.Kind.strength, hidden[0].terms[0].kind);
    try testing.expect(hidden[0].terms[0].other == null);
    try testing.expectEqualStrings("G", p.champs[hidden[0].terms[1].other.?].name);
    try testing.expectApproxEqAbs(@as(f32, 0.5), hidden[0].rest, 1e-4);
    try testing.expectEqualStrings("H", p.champs[hidden[1].champ].name);
    try testing.expectEqual(@as(u16, 2), hidden[1].rank);
    try testing.expectEqual(dd.Kind.into, hidden[1].terms[0].kind);
    try testing.expectApproxEqAbs(@as(f32, 48), hidden[1].win, 1e-4);
    for (hidden) |c| {
        var sum: f32 = base + c.rest;
        for (c.terms) |t| sum += t.pp;
        try testing.expectApproxEqAbs(c.win, sum, 1e-4);
    }
    // Every champion in the table is named somewhere (none left from the hidden seat)
    for (0..p.champs.len) |i| try testing.expect(named(&p, @intCast(i)));
    // Another seat: the model's top, then the played one, no reasons
    const other = p.seats[0][0].cands;
    try testing.expectEqual(@as(usize, 2), other.len);
    try testing.expectEqual(@as(u16, 1), other[0].rank);
    try testing.expectApproxEqAbs(@as(f32, -2), other[1].rest, 1e-4);
    try testing.expectEqual(@as(?u16, 2), p.seats[0][0].rank);

    const back = try dd.decode(a, try dd.encode(a, p));
    try testing.expect(back.valid());
    try testing.expectEqualStrings("H", back.champs[dd.played(&back)].name);
    // Two options, so no trait can leave two and rule one out
    try testing.expect(back.hint == null);
}

test "the hidden seat: each option at its rank, best first, after the top picks" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const opts = [_]daily.Option{
        .{ .id = 12, .games = 50, .reasons = &.{reason(.base, 12, -0.5)}, .win = 46 },
        test_options[1],
    };
    var rv = test_review;
    rv.ranks = &.{ 9, 2 };
    var raw = testPuzzle(null, rv);
    raw.options = &opts;
    const p = try puzzle(a, raw, Fake{}, Fake.champ, Fake.magic, Fake.ranged);
    try testing.expect(p.valid());
    const hidden = p.seats[1][2].cands;
    try testing.expectEqual(@as(usize, 3), hidden.len);
    for (hidden, [_][]const u8{ "M", "H", "L" }, [_]u16{ 1, 2, 9 }) |c, nm, rank| {
        try testing.expectEqualStrings(nm, p.champs[c.champ].name);
        try testing.expectEqual(rank, c.rank);
    }
    try testing.expectApproxEqAbs(@as(f32, 46), hidden[2].win, 1e-4);
}

fn named(p: *const dd.Puzzle, i: u16) bool {
    if (std.mem.findScalar(u16, p.options, i) != null) return true;
    for (p.bans) |b| if (std.mem.findScalar(u16, b, i) != null) return true;
    for (p.turns) |t| if (t.champ == i) return true;
    for (p.seats) |side| for (side) |st| {
        if (st.champ == i) return true;
        for (st.cands) |c| {
            if (c.champ == i) return true;
            for (c.terms) |t| if (t.other == i) return true;
        }
    };
    return false;
}

test "files: a bin per numbered puzzle that converts; an unknown champion or bad JSON skips it" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var unknown = testPuzzle(null, test_review);
    unknown.n = 8;
    unknown.teams[0][0] = 99;
    const in = [_]File{
        .{ .path = "daily/7.json", .data = try std.json.Stringify.valueAlloc(a, testPuzzle(null, test_review), .{}) },
        .{ .path = "daily/8.json", .data = try std.json.Stringify.valueAlloc(a, unknown, .{}) },
        .{ .path = "daily/9.json", .data = "{" },
        .{ .path = "daily/index.json", .data = "[]" },
    };
    var out: std.ArrayList(File) = .empty;
    try filesWith(a, &in, &out, Fake{}, Fake.champ, Fake.magic, Fake.ranged);
    try testing.expectEqual(@as(usize, 1), out.items.len);
    try testing.expectEqualStrings("daily/7.bin", out.items[0].path);
    const back = try dd.decode(a, out.items[0].data);
    try testing.expect(back.valid());
    try testing.expectEqual(@as(u32, 7), back.n);
}

test "rangesOf: melee up to 250, ranged past it, champions whose range changes left out" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const r = try rangesOf(arena.allocator(),
        \\{"type":"champion","data":{
        \\"Aatrox":{"id":"Aatrox","key":"266","name":"Aatrox","stats":{"hp":650,"attackrange":175}},
        \\"Fiora":{"id":"Fiora","key":"114","stats":{"attackrange":150}},
        \\"Rakan":{"id":"Rakan","key":"497","stats":{"attackrange":300}},
        \\"Jinx":{"id":"Jinx","key":"222","stats":{"attackrange":525}},
        \\"Gnar":{"id":"Gnar","key":"150","stats":{"attackrange":175}},
        \\"Jayce":{"id":"Jayce","key":"126","stats":{"attackrange":125}},
        \\"Darius":{"key":"122","stats":{"hp":652}}}}
    );
    try testing.expectEqual(@as(?bool, false), r.get(266));
    try testing.expectEqual(@as(?bool, false), r.get(114));
    try testing.expectEqual(@as(?bool, true), r.get(497));
    try testing.expectEqual(@as(?bool, true), r.get(222));
    try testing.expectEqual(null, r.get(150));
    try testing.expectEqual(null, r.get(126));
    try testing.expectEqual(null, r.get(122));
}

test "hintOf: the trait leaving the fewest, two at least; unknown options stay in" {
    const mel: Traits = .{ .ranged = false, .dmg = .ad };
    const adc: Traits = .{ .ranged = true, .dmg = .ad };
    const mage: Traits = .{ .ranged = true, .dmg = .ap };
    const odd: Traits = .{ .ranged = null, .dmg = null };
    // All ranged: range says nothing, damage leaves the two AP
    var h = hintOf(mage, &.{ adc, mage, adc, mage, adc, adc }).?;
    try testing.expect(h.kind == .ap);
    try testing.expectEqual(@as(u8, 0b001010), h.fits);
    // Melee leaves two (one unknown), AD would leave four
    h = hintOf(mel, &.{ adc, mel, adc, odd, adc, mage }).?;
    try testing.expect(h.kind == .melee);
    try testing.expectEqual(@as(u8, 0b001010), h.fits);
    // A tie keeps range
    h = hintOf(mel, &.{ mel, mel, mage, mage }).?;
    try testing.expect(h.kind == .melee);
    // One left would be the answer; all alike rules none out
    try testing.expect(hintOf(mel, &.{ mel, mage, mage, mage }) == null);
    try testing.expect(hintOf(adc, &.{ adc, adc, adc, adc }) == null);
    try testing.expect(hintOf(.{ .ranged = null, .dmg = .mixed }, &.{ mel, adc, mage, odd }) == null);
}

test "puzzleName: numbered puzzles only" {
    try testing.expectEqualStrings("12", puzzleName("daily/12.json").?);
    for ([_][]const u8{ "daily/index.json", "daily/.json", "daily/12.bin", "learn/12.json" }) |p|
        try testing.expectEqual(null, puzzleName(p));
}

test "a pro puzzle keeps its 20 turns, a skipped ban as none, and no bans apart" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var turns: [20]daily.Turn = undefined;
    for (&turns, leaguepedia.order, 0..) |*t, c, i| t.* = .{ .id = @intCast(i % 10 + 1), .side = c.side };
    turns[3].id = null;
    turns[19] = .{ .id = 8, .side = 1 };
    const p = try puzzle(a, testPuzzle(&turns, test_review), Fake{}, Fake.champ, Fake.magic, Fake.ranged);
    try testing.expect(p.valid());
    try testing.expectEqual(@as(usize, 20), p.turns.len);
    try testing.expect(p.turns[3].champ == null);
    try testing.expectEqual(dd.Side.red, p.turns[19].side);
    try testing.expectEqualStrings("H", p.champs[p.turns[19].champ.?].name);
    try testing.expectEqual(@as(usize, 0), p.bans[0].len);
    try testing.expectEqual(@as(usize, 2), p.options.len);
}
