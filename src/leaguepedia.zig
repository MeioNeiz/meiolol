//! Pro games for Daily Draft from Leaguepedia's Cargo API (CC BY-SA 3.0): one query joins
//! ScoreboardGames, PicksAndBansS7, Tournaments and ScoreboardPlayers, 10 rows a game.
//! `parse` keeps champions, draft order, result and the players' lines and drops players,
//! teams, events and dates: nothing that names who played reaches a Game.
//! Facts the parse leans on (research/questions/leaguepedia-daily-fetch.md): ScoreboardGames
//! Team1 and Side 1 are blue; PicksAndBansS7 Team1/Team2 are the series' teams, Team1 on
//! red when SwitchedSides is 1; Patch is text ("26.20", Riot's 16.20)
const std = @import("std");
const Allocator = std.mem.Allocator;
const core = @import("core");
const Role = core.Role;

pub const Line = struct {
    kills: u32,
    deaths: u32,
    assists: u32,
    cs: u32,
    gold: u32,
    /// To champions
    damage: u32,
};

pub const Turn = struct {
    /// Null: a ban not made ("None", "Loss of Ban", "Missing Data")
    champ: ?[]const u8,
    /// 0 blue, 1 red
    side: u1,
};

pub const Game = struct {
    /// Hash of Leaguepedia's GameId, to skip a game already used; the id itself names the
    /// event
    key: u64,
    /// Riot's numbering, "16.20"
    patch: []const u8,
    minutes: u32,
    /// 0 blue, 1 red
    winner: u1,
    /// [blue, red], by role; Leaguepedia's names
    champs: [2][5][]const u8,
    lines: [2][5]Line,
    /// The 20 turns in draft order
    turns: [20]Turn,
};

/// Each turn's side and which of its PicksAndBansS7 cells: bans B1 R1 B2 R2 B3 R3, picks
/// B1 R1 R2 B2 B3 R3, bans R4 B4 R5 B5, picks R4 B4 B5 R5
pub const order = blk: {
    const Cell = struct { side: u1, ban: bool, n: u8 };
    const b = 0;
    const r = 1;
    break :blk [20]Cell{
        .{ .side = b, .ban = true, .n = 1 },  .{ .side = r, .ban = true, .n = 1 },
        .{ .side = b, .ban = true, .n = 2 },  .{ .side = r, .ban = true, .n = 2 },
        .{ .side = b, .ban = true, .n = 3 },  .{ .side = r, .ban = true, .n = 3 },
        .{ .side = b, .ban = false, .n = 1 }, .{ .side = r, .ban = false, .n = 1 },
        .{ .side = r, .ban = false, .n = 2 }, .{ .side = b, .ban = false, .n = 2 },
        .{ .side = b, .ban = false, .n = 3 }, .{ .side = r, .ban = false, .n = 3 },
        .{ .side = r, .ban = true, .n = 4 },  .{ .side = b, .ban = true, .n = 4 },
        .{ .side = r, .ban = true, .n = 5 },  .{ .side = b, .ban = true, .n = 5 },
        .{ .side = r, .ban = false, .n = 4 }, .{ .side = b, .ban = false, .n = 4 },
        .{ .side = b, .ban = false, .n = 5 }, .{ .side = r, .ban = false, .n = 5 },
    };
};

/// The query's fields, aliased so each row's keys are plain names
pub const fields = "SG.GameId,SG.Team1,SG.WinTeam,SG.Gamelength_Number=Minutes,SG.Patch," ++
    "PB.Team1=PBTeam1,PB.SwitchedSides," ++ cells ++
    "SP.Side,SP.Role,SP.Champion,SP.Kills,SP.Deaths,SP.Assists,SP.CS,SP.Gold,SP.DamageToChampions";

/// "Team1Pick3" as cell_names[0][0][2]: [PB team][ban][n - 1]
const cell_names = blk: {
    var names: [2][2][5][]const u8 = undefined;
    for (0..2) |t| for (0..2) |k| for (0..5) |n| {
        names[t][k][n] = std.fmt.comptimePrint("Team{d}{s}{d}", .{ t + 1, if (k == 1) "Ban" else "Pick", n + 1 });
    };
    break :blk names;
};

const cells = blk: {
    var s: []const u8 = "";
    for (1..3) |t| for ([_][]const u8{ "Ban", "Pick" }) |k| for (1..6) |n| {
        s = s ++ std.fmt.comptimePrint("PB.Team{d}{s}{d},", .{ t, k, n });
    };
    break :blk s;
};

/// The games in a cargoquery answer, newest first as asked. A game whose rows don't make
/// a whole draft (10 players, one per side and role, picks matching the scoreboard, a
/// patch as text) is left out, not an error
pub fn parse(a: Allocator, body: []const u8) ![]Game {
    const doc = try std.json.parseFromSliceLeaky(std.json.Value, a, body, .{});
    if (doc != .object) return error.BadAnswer;
    if (doc.object.get("error")) |e| {
        const code = if (e == .object) str(e.object.get("code")) orelse "" else "";
        return if (std.mem.eql(u8, code, "ratelimited")) error.RateLimited else error.BadAnswer;
    }
    const rows = doc.object.get("cargoquery") orelse return error.BadAnswer;
    if (rows != .array) return error.BadAnswer;

    var games: std.ArrayList(Game) = .empty;
    var i: usize = 0;
    while (i < rows.array.items.len) {
        const id = str(field(rows.array.items[i], "GameId")) orelse "";
        var end = i + 1;
        while (end < rows.array.items.len and std.mem.eql(u8, str(field(rows.array.items[end], "GameId")) orelse "", id)) end += 1;
        if (id.len > 0) if (try game(a, id, rows.array.items[i..end])) |g| try games.append(a, g);
        i = end;
    }
    return games.items;
}

fn game(a: Allocator, id: []const u8, rows: []const std.json.Value) !?Game {
    if (rows.len != 10) return null;
    var g: Game = undefined;
    g.key = std.hash.Wyhash.hash(0, id);
    const first = rows[0];
    g.patch = try riotPatch(a, str(field(first, "Patch")) orelse return null) orelse return null;
    const minutes = num(field(first, "Minutes")) orelse return null;
    if (!(minutes > 0 and minutes < 200)) return null;
    g.minutes = @intFromFloat(@round(minutes));
    const blue = str(field(first, "Team1")) orelse return null;
    const win = str(field(first, "WinTeam")) orelse return null;
    g.winner = if (std.mem.eql(u8, win, blue)) 0 else 1;

    var seen: [2][5]bool = @splat(@splat(false));
    for (rows) |row| {
        const side = num(field(row, "Side")) orelse return null;
        if (side != 1 and side != 2) return null;
        const s: u1 = if (side == 1) 0 else 1;
        const r = role(str(field(row, "Role")) orelse return null) orelse return null;
        if (seen[s][@backingInt(r)]) return null;
        seen[s][@backingInt(r)] = true;
        g.champs[s][@backingInt(r)] = str(field(row, "Champion")) orelse return null;
        g.lines[s][@backingInt(r)] = .{
            .kills = count(field(row, "Kills")) orelse return null,
            .deaths = count(field(row, "Deaths")) orelse return null,
            .assists = count(field(row, "Assists")) orelse return null,
            .cs = count(field(row, "CS")) orelse return null,
            .gold = count(field(row, "Gold")) orelse return null,
            .damage = count(field(row, "DamageToChampions")) orelse return null,
        };
    }

    // PB Team1 on red when the series' sides were switched
    const switched = (num(field(first, "SwitchedSides")) orelse 0) == 1;
    for (order, &g.turns) |c, *t| {
        const pb_team: usize = if ((c.side == 1) == switched) 0 else 1;
        const champ = str(field(first, cell_names[pb_team][@intFromBool(c.ban)][c.n - 1]));
        t.side = c.side;
        if (c.ban) {
            t.champ = if (champ) |x| if (isBan(x)) x else null else null;
            continue;
        }
        const pick = champ orelse return null;
        if (!picked(g.champs[c.side], pick)) return null;
        t.champ = pick;
    }
    return g;
}

fn picked(side: [5][]const u8, champ: []const u8) bool {
    for (side) |c| if (std.mem.eql(u8, c, champ)) return true;
    return false;
}

fn isBan(name: []const u8) bool {
    const none = [_][]const u8{ "", "None", "Loss of Ban", "Missing Data" };
    for (none) |n| if (std.mem.eql(u8, name, n)) return false;
    return true;
}

/// Leaguepedia's "26.20" as Riot's "16.20"; null for anything else
fn riotPatch(a: Allocator, p: []const u8) !?[]const u8 {
    const dot = std.mem.findScalar(u8, p, '.') orelse return null;
    const major = std.fmt.parseInt(u32, p[0..dot], 10) catch return null;
    const minor = std.fmt.parseInt(u32, p[dot + 1 ..], 10) catch return null;
    if (major < 20 or p.len - dot - 1 != 2) return null;
    return try a.print("{d}.{d}", .{ major - 10, minor });
}

fn role(r: []const u8) ?Role {
    const names = [_]struct { []const u8, Role }{
        .{ "Top", .top }, .{ "Jungle", .jungle }, .{ "Mid", .middle }, .{ "Bot", .bottom }, .{ "Support", .utility },
    };
    for (names) |n| if (std.mem.eql(u8, r, n[0])) return n[1];
    return null;
}

fn field(row: std.json.Value, name: []const u8) ?std.json.Value {
    if (row != .object) return null;
    const t = row.object.get("title") orelse return null;
    if (t != .object) return null;
    return t.object.get(name);
}

fn str(v: ?std.json.Value) ?[]const u8 {
    const x = v orelse return null;
    return switch (x) {
        .string => |s| s,
        else => null,
    };
}

/// api.php sends numbers as strings, CargoExport as numbers: both read
fn num(v: ?std.json.Value) ?f64 {
    const x = v orelse return null;
    return switch (x) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        .string, .number_string => |s| std.fmt.parseFloat(f64, s) catch null,
        else => null,
    };
}

fn count(v: ?std.json.Value) ?u32 {
    const x = num(v) orelse return null;
    if (!(x >= 0 and x < 1e9)) return null;
    return @intFromFloat(x);
}

const testing = std.testing;

test "the fixture's two games: sides, switched series, draft order, a missing ban" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const games = try parse(a, @embedFile("testdata/leaguepedia-cargo.json"));
    try testing.expectEqual(2, games.len);

    const g = games[0];
    try testing.expectEqualStrings("16.20", g.patch);
    try testing.expectEqual(32, g.minutes);
    try testing.expectEqual(0, g.winner);
    try testing.expectEqualStrings("Camille", g.champs[0][@backingInt(Role.top)]);
    try testing.expectEqualStrings("K'Sante", g.champs[1][@backingInt(Role.top)]);
    try testing.expectEqual(13371, g.lines[0][@backingInt(Role.top)].damage);
    try testing.expectEqualStrings("Wukong", g.turns[0].champ.?);
    try testing.expectEqualStrings("Cassiopeia", g.turns[1].champ.?);
    try testing.expectEqualStrings("Ezreal", g.turns[6].champ.?);
    try testing.expectEqualStrings("Milio", g.turns[8].champ.?);
    try testing.expectEqual(1, g.turns[19].side);
    try testing.expectEqualStrings("Tristana", g.turns[19].champ.?);

    // PB Team1 played red: its picks are red's turns, the winner from ScoreboardGames
    const s = games[1];
    try testing.expectEqual(0, s.winner);
    try testing.expectEqualStrings("Cassiopeia", s.turns[0].champ.?);
    try testing.expectEqualStrings("Nocturne", s.turns[1].champ.?);
    try testing.expectEqualStrings("Alistar", s.turns[19].champ.?);
    try testing.expectEqualStrings("Renata Glasc", s.champs[0][@backingInt(Role.utility)]);
    try testing.expect(s.turns[14].champ == null);
    try testing.expect(s.key != g.key);
}

test "an error answer, a short game, a pick off the scoreboard and a number patch" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectError(error.RateLimited, parse(a, "{\"error\":{\"code\":\"ratelimited\",\"info\":\"x\"}}"));
    try testing.expectError(error.BadAnswer, parse(a, "[]"));

    const body = @embedFile("testdata/leaguepedia-cargo.json");
    const nine = try std.mem.replaceOwned(u8, a, body, "\"Role\": \"Support\"", "\"Role\": \"Coach\"");
    try testing.expectEqual(0, (try parse(a, nine)).len);
    const off = try std.mem.replaceOwned(u8, a, body, "\"Team2Pick5\": \"Tristana\"", "\"Team2Pick5\": \"Teemo\"");
    try testing.expectEqual(1, (try parse(a, off)).len);
    const float = try std.mem.replaceOwned(u8, a, body, "\"Patch\": \"26.20\"", "\"Patch\": 26.2");
    try testing.expectEqual(0, (try parse(a, float)).len);
    try testing.expectEqual(null, try riotPatch(a, "26.2"));
    try testing.expectEqualStrings("16.9", (try riotPatch(a, "26.09")).?);
}
