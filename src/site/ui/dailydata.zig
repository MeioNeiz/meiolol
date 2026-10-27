//! Daily Draft's data for its page (ui.data binary, data/daily/<n>.bin): one pro game's
//! draft in order with the last pick hidden, the six options, the game's lines and how the
//! model reads every seat (its top five and the played pick, each with its terms). No
//! player, team, event or date: public file (Leaguepedia data stripped at fetch).
//! Words for terms are made on the page from kind and champion, so the file holds numbers
const std = @import("std");
const champ = @import("champ.zig");
const role = @import("role.zig");
const data = @import("data.zig");

pub const Side = enum(u1) { blue, red };

pub const Dmg = enum(u2) { ad, ap, mixed };

pub const Puzzle = struct {
    n: u32,
    /// The game's patch ("26.20")
    patch: []const u8,
    /// Every champion the puzzle names; seats, turns and options index it
    champs: []const champ.Champ,
    /// [blue, red], by role.Role.all
    seats: [2][5]Seat,
    /// The 20 turns in draft order; empty when the order is unknown (old ranked puzzles)
    turns: []const Turn,
    /// Each side's bans when `turns` is empty
    bans: [2][]const u16 = .{ &.{}, &.{} },
    hidden_side: Side,
    hidden_role: role.Role,
    /// Six, in display order; the played one among them
    options: []const u16,
    /// Hint: the hidden champion is ranged
    ranged: bool,
    /// Blue's win chance from each lane alone, %, by role
    lanes: [5]?f32,
    result: Result,
    paper: Paper,

    /// Every index names a champion, the order is whole or absent and the played pick is
    /// among the options; check a decoded file before use
    pub fn valid(p: *const Puzzle) bool {
        const n = p.champs.len;
        if (p.turns.len != 0 and p.turns.len != 20) return false;
        if (p.options.len == 0 or p.options.len > 6) return false;
        for (p.turns) |t| if (t.champ) |c| if (c >= n) return false;
        for (p.bans) |side| for (side) |c| if (c >= n) return false;
        for (p.options) |c| if (c >= n) return false;
        for (p.seats) |side| for (side) |st| {
            if (st.champ >= n) return false;
            for (st.cands) |c| {
                if (c.champ >= n) return false;
                for (c.terms) |t| if (t.other) |o| if (o >= n) return false;
            }
        };
        return std.mem.findScalar(u16, p.options, played(p)) != null;
    }
};

pub const Turn = struct {
    /// Null: a skipped ban
    champ: ?u16,
    side: Side,
};

pub const Seat = struct {
    champ: u16,
    dmg: Dmg,
    kills: u16,
    deaths: u16,
    assists: u16,
    cs: u16,
    gold: u32,
    /// To champions
    damage: u32,
    /// The role's average win chance, %: the waterfall's start
    base: f32,
    /// The played pick's place among the seat's options and how many there were; null
    /// when the model can't rate it
    rank: ?u16,
    of: u16,
    /// The model's top five and the played pick (its rank may be past five)
    cands: []const Cand,
};

pub const Cand = struct {
    champ: u16,
    rank: u16,
    /// The seat's team's win chance with it, %
    win: f32,
    /// 95% range of win, %
    low: f32,
    high: f32,
    terms: []const Term,
    /// Every term not named, summed, points
    rest: f32,
};

pub const Kind = enum(u8) { strength, into, with };

pub const Term = struct {
    kind: Kind,
    /// The other champion for into and with
    other: ?u16,
    pp: f32,
    games: u32,
};

pub const Result = struct {
    winner: Side,
    secs: u32,
    kills: [2]u16,
    gold: [2]u32,
    towers: [2]u8,
    dragons: [2]u8,
    barons: [2]u8,
};

pub const Paper = struct {
    /// Blue's draft win chance, %, and its 95% range
    blue: f32,
    low: f32,
    high: f32,
    /// Blue's edge by kind of term, points: champions, teammates, lanes, matchups
    edges: [4]f32,
};

pub fn played(p: *const Puzzle) u16 {
    return p.seats[@backingInt(p.hidden_side)][@backingInt(p.hidden_role)].champ;
}

pub fn encode(a: std.mem.Allocator, p: Puzzle) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    try data.encode(a, Puzzle, p, &out);
    return out.toOwnedSlice(a);
}

pub fn decode(a: std.mem.Allocator, bytes: []const u8) data.Error!Puzzle {
    return data.decode(a, Puzzle, bytes);
}

const demo = champ.demo;

/// Daily #11 (the mock's game), terms on one seat only
pub const sample: Puzzle = .{
    .n = 11,
    .patch = "26.20",
    .champs = &.{
        demo("KSante", "K'Sante"),  demo("JarvanIV", "Jarvan IV"), demo("Viktor", "Viktor"),
        demo("Kalista", "Kalista"), demo("Renata", "Renata"),      demo("Jayce", "Jayce"),
        demo("Vi", "Vi"),           demo("Anivia", "Anivia"),      demo("Caitlyn", "Caitlyn"),
        demo("Neeko", "Neeko"),     demo("Gnar", "Gnar"),          demo("Ambessa", "Ambessa"),
    },
    .seats = .{
        .{
            seat(0, .ad, 51.0, 4),
            seat(1, .ad, 50.0, 2),
            seat(2, .ap, 50.0, 6),
            seat(3, .ad, 50.0, 1),
            seat(4, .mixed, 50.0, 3),
        },
        .{
            .{ .champ = 5, .dmg = .ad, .kills = 1, .deaths = 3, .assists = 1, .cs = 429, .gold = 16200, .damage = 21000, .base = 47.5, .rank = 3, .of = 31, .cands = &.{
                .{ .champ = 10, .rank = 1, .win = 49.9, .low = 48.5, .high = 51.3, .terms = &.{}, .rest = 0 },
                .{ .champ = 11, .rank = 2, .win = 49.4, .low = 48.0, .high = 50.8, .terms = &.{}, .rest = 0 },
                .{ .champ = 5, .rank = 3, .win = 48.9, .low = 47.6, .high = 50.2, .rest = 0.1, .terms = &.{
                    .{ .kind = .strength, .other = null, .pp = 0.6, .games = 4100 },
                    .{ .kind = .into, .other = 0, .pp = 0.9, .games = 1200 },
                    .{ .kind = .with, .other = 6, .pp = 0.2, .games = 880 },
                    .{ .kind = .into, .other = 2, .pp = -0.4, .games = 2300 },
                } },
            } },
            seat(6, .ad, 50.0, 5),
            seat(7, .ap, 50.0, 9),
            seat(8, .ad, 50.0, 2),
            seat(9, .ap, 50.0, 7),
        },
    },
    .turns = &.{},
    .hidden_side = .red,
    .hidden_role = .top,
    .options = &.{ 5, 11, 10 },
    .ranged = false,
    .lanes = .{ 51.4, 50.1, 49.1, 50.9, 51.3 },
    .result = .{ .winner = .blue, .secs = 2491, .kills = .{ 10, 8 }, .gold = .{ 84300, 79300 }, .towers = .{ 9, 6 }, .dragons = .{ 2, 4 }, .barons = .{ 1, 1 } },
    .paper = .{ .blue = 51.1, .low = 48.9, .high = 53.3, .edges = .{ 1.2, 0.3, -0.6, 0.2 } },
};

fn seat(c: u16, d: Dmg, base: f32, rank: u16) Seat {
    return .{ .champ = c, .dmg = d, .kills = 2, .deaths = 2, .assists = 4, .cs = 300, .gold = 15000, .damage = 12000, .base = base, .rank = rank, .of = 30, .cands = &.{} };
}

test "a puzzle survives the binary file" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const bytes = try encode(a, sample);
    const back = try decode(a, bytes);
    try std.testing.expectEqual(@as(u16, 5), played(&back));
    try std.testing.expectEqual(@as(usize, 4), back.seats[1][0].cands[2].terms.len);
    try std.testing.expectEqualStrings("Anivia", back.champs[7].name);
    try std.testing.expect(back.valid());
}

test "valid: an index past the champions or the played pick missing from the options fails" {
    var p = sample;
    try std.testing.expect(p.valid());
    p.options = &.{ 11, 10 };
    try std.testing.expect(!p.valid());
    p = sample;
    p.bans = .{ &.{12}, &.{} };
    try std.testing.expect(!p.valid());
    p = sample;
    p.turns = &.{.{ .champ = 0, .side = .blue }};
    try std.testing.expect(!p.valid());
}
