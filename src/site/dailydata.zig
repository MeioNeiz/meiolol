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

/// The waterfall's start: a pick's win chance is this plus its terms and rest
const base = 50;

comptime {
    std.debug.assert(@backingInt(dd.Side.blue) == 0 and @backingInt(dd.Side.red) == 1);
    for (leaguepedia.order, dd.pro_sides) |c, side| std.debug.assert(c.side == @backingInt(side));
}

/// daily/<n>.bin beside each daily/<n>.json in `daily_files`. A puzzle that doesn't
/// parse (made before a field it needs) gets none
pub fn files(site: *const Site, daily_files: []const File, out: *std.ArrayList(File)) !void {
    const a = site.arena;
    for (daily_files) |f| {
        const n = puzzleName(f.path) orelse continue;
        const p = std.json.parseFromSliceLeaky(daily.Puzzle, a, f.data, .{ .ignore_unknown_fields = true }) catch |err| {
            log.info("{s}: no page data: {t}", .{ f.path, err });
            continue;
        };
        const d = try puzzle(a, p, site, siteChamp, siteMagic);
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

fn siteChamp(site: *const Site, id: u32) anyerror!Champ {
    const ch = for (site.champs) |c| {
        if (c.id == id) break c;
    } else return error.UnknownChampion;
    return .{ .name = ch.name, .src = try site.icon(ch) };
}

fn siteMagic(site: *const Site, id: u32) ?f32 {
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
) !dd.Puzzle {
    var ids: Ids = .{ .a = a };
    var seats: [2][5]dd.Seat = undefined;
    for (0..2) |t| for (0..5) |r| {
        const id = p.teams[t][r];
        const pl: daily.Player = if (p.players) |ps| ps[t][r] else .{};
        const rs: ?daily.Seat = if (p.review) |rv| rv.seats[t][r] else null;
        var cands: std.ArrayList(dd.Cand) = .empty;
        if (rs) |x| {
            if (x.top != id) try cands.append(a, try plain(&ids, x.top, 1, x.top_win));
            try cands.append(a, try plain(&ids, id, x.rank, x.win));
        }
        seats[t][r] = .{
            .champ = try ids.at(id),
            .dmg = dmgOf(magic(ctx, id)),
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
        .lanes = lanes,
        .result = .{
            .winner = @fromBackingInt(@intCast(p.winner)),
            .secs = p.minutes * 60,
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

/// The review's top picks with their reasons as terms, then the played one where it is
/// not among them (its reasons from the options). Picks from before win chances were
/// kept are left out
fn hiddenCands(a: std.mem.Allocator, ids: *Ids, p: daily.Puzzle, rv: daily.Review) ![]const dd.Cand {
    var out: std.ArrayList(dd.Cand) = .empty;
    var has_played = false;
    for (rv.picks, 1..) |o, rank| {
        const c = try cand(a, ids, o, @intCast(rank)) orelse continue;
        try out.append(a, c);
        has_played = has_played or o.id == p.played;
    }
    if (!has_played) {
        const s = rv.seats[p.hidden_team][@backingInt(p.hidden_role)];
        for (p.options) |o| if (o.id == p.played) {
            var c = try cand(a, ids, o, s.rank) orelse try plain(ids, o.id, s.rank, s.win);
            c.win = @floatCast(s.win);
            try out.append(a, c);
        };
    }
    return out.toOwnedSlice(a);
}

fn cand(a: std.mem.Allocator, ids: *Ids, o: daily.Option, rank: u32) !?dd.Cand {
    const win = o.win orelse return null;
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

fn dmgOf(m: ?f32) dd.Dmg {
    const x = m orelse return .mixed;
    return if (x < 0.35) .ad else if (x > 0.65) .ap else .mixed;
}

const testing = std.testing;

const Fake = struct {
    fn champ(_: Fake, id: u32) anyerror!Champ {
        return .{ .name = names[id - 1], .src = "" };
    }
    fn magic(_: Fake, id: u32) ?f32 {
        return if (id == 3) 0.9 else if (id == 1) 0.1 else null;
    }
    const names = [_][]const u8{ "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M" };
};

fn reason(kind: @FieldType(daily.Reason, "kind"), id: u32, pp: f64) daily.Reason {
    return .{ .kind = kind, .id = id, .role = .middle, .pp = pp, .games = 900 };
}

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
        .options = &.{
            .{ .id = 12, .games = 50, .reasons = &.{} },
            .{ .id = 8, .games = 80, .reasons = &.{reason(.enemy, 3, 1.5)}, .win = 49 },
        },
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
    const bare = try puzzle(a, testPuzzle(null, null), Fake{}, Fake.champ, Fake.magic);
    try testing.expect(bare.valid());
    try testing.expect(bare.paper == null);
    try testing.expectEqual(ui.role.Role.mid, bare.hidden_role);
    try testing.expectEqual(@as(usize, 0), bare.turns.len);
    try testing.expectEqualStrings("K", bare.champs[bare.bans[0][0]].name);
    try testing.expectEqual(@as(usize, 0), bare.seats[1][2].cands.len);
    try testing.expectEqual(dd.Dmg.ap, bare.seats[0][2].dmg);
    try testing.expectEqual(dd.Dmg.ad, bare.seats[0][0].dmg);
    try testing.expectEqual(dd.Dmg.mixed, bare.seats[0][1].dmg);

    const p = try puzzle(a, testPuzzle(null, test_review), Fake{}, Fake.champ, Fake.magic);
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
    // Another seat: the model's top, then the played one, no reasons
    const other = p.seats[0][0].cands;
    try testing.expectEqual(@as(usize, 2), other.len);
    try testing.expectEqual(@as(u16, 1), other[0].rank);
    try testing.expectApproxEqAbs(@as(f32, -2), other[1].rest, 1e-4);
    try testing.expectEqual(@as(?u16, 2), p.seats[0][0].rank);

    const back = try dd.decode(a, try dd.encode(a, p));
    try testing.expect(back.valid());
    try testing.expectEqualStrings("H", back.champs[dd.played(&back)].name);
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
    const p = try puzzle(a, testPuzzle(&turns, test_review), Fake{}, Fake.champ, Fake.magic);
    try testing.expect(p.valid());
    try testing.expectEqual(@as(usize, 20), p.turns.len);
    try testing.expect(p.turns[3].champ == null);
    try testing.expectEqual(dd.Side.red, p.turns[19].side);
    try testing.expectEqualStrings("H", p.champs[p.turns[19].champ.?].name);
    try testing.expectEqual(@as(usize, 0), p.bans[0].len);
    try testing.expectEqual(@as(usize, 2), p.options.len);
}
