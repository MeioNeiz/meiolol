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

/// Under about a third magic reads as AD, over two thirds as AP
pub fn dmgOf(magic: ?f32) ?Dmg {
    const x = magic orelse return null;
    return if (x < 0.35) .ad else if (x > 0.65) .ap else .mixed;
}

/// The hidden champion's trait that splits the options, and which options share it
pub const Hint = struct {
    kind: enum(u2) { melee, ranged, ad, ap },
    /// A bit per option, display order; options whose trait is unknown are set too
    fits: u8,
};

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
    /// Up to six (four on ranked puzzles), in display order; the played one among them
    options: []const u16,
    /// Null when no trait splits the options
    hint: ?Hint = null,
    /// Blue's win chance from each lane alone, %, by role
    lanes: [5]?f32,
    result: Result,
    /// Null until the model can read the draft
    paper: ?Paper = null,

    /// Every index names a champion, a whole order follows the pro draft's sides and ends
    /// on the played pick, the options are distinct and hold the played pick, and every
    /// number is finite; check a decoded file before use
    pub fn valid(p: *const Puzzle) bool {
        const n = p.champs.len;
        if (p.turns.len != 0 and p.turns.len != 20) return false;
        if (p.options.len == 0 or p.options.len > 6) return false;
        for (p.turns, 0..) |t, i| {
            if (t.side != pro_sides[i]) return false;
            if (t.champ) |c| if (c >= n) return false;
        }
        if (p.turns.len == 20 and p.turns[19].champ != played(p)) return false;
        for (p.bans) |side| for (side) |c| if (c >= n) return false;
        for (p.options, 0..) |c, i| {
            if (c >= n) return false;
            if (std.mem.findScalar(u16, p.options[i + 1 ..], c) != null) return false;
        }
        for (p.lanes) |l| if (l) |x| if (!std.math.isFinite(x)) return false;
        if (p.paper) |pp| {
            for ([_]f32{ pp.blue, pp.low, pp.high } ++ pp.edges) |x| if (!std.math.isFinite(x)) return false;
        }
        for (p.seats) |side| for (side) |st| {
            if (st.champ >= n or !std.math.isFinite(st.base)) return false;
            if (st.magic) |m| if (!(m >= 0 and m <= 1)) return false;
            for (st.cands) |c| {
                if (c.champ >= n or !c.finite()) return false;
                for (c.terms) |t| {
                    if (t.other) |o| if (o >= n) return false;
                    if (!std.math.isFinite(t.pp)) return false;
                }
            }
        };
        return std.mem.findScalar(u16, p.options, played(p)) != null;
    }
};

/// Each turn's side in a pro draft: bans B R B R B R, picks B R R B B R, bans R B R B,
/// picks R B B R (src/leaguepedia.zig order)
pub const pro_sides = blk: {
    const b: Side = .blue;
    const r: Side = .red;
    break :blk [20]Side{ b, r, b, r, b, r, b, r, r, b, b, r, r, b, r, b, r, b, b, r };
};

pub const Turn = struct {
    /// Null: a skipped ban
    champ: ?u16,
    side: Side,
};

pub const Seat = struct {
    champ: u16,
    /// Magic share of the champion's damage to champions, 0..1; null unsampled
    magic: ?f32,
    kills: u16,
    deaths: u16,
    assists: u16,
    cs: u16,
    gold: u32,
    /// To champions
    damage: u32,
    /// Total gold at 14 minutes; null without a timeline (pro games)
    gold14: ?u32 = null,
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
    /// 95% range of win, %; null when unknown
    low: ?f32 = null,
    high: ?f32 = null,
    terms: []const Term,
    /// Every term not named, summed, points
    rest: f32,

    fn finite(c: Cand) bool {
        const ok = std.math.isFinite;
        return ok(c.win) and ok(c.rest) and ok(c.low orelse 0) and ok(c.high orelse 0);
    }
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
    /// Null when the source doesn't have them
    towers: ?[2]u8 = null,
    dragons: ?[2]u8 = null,
    barons: ?[2]u8 = null,
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
            seat(0, 0.08, 51.0, 4, 5400),
            seat(1, 0.21, 50.0, 2, 5100),
            seat(2, 0.93, 50.0, 6, 4800),
            seat(3, 0.04, 50.0, 1, 5900),
            seat(4, 0.47, 50.0, 3, 3800),
        },
        .{
            .{ .champ = 5, .magic = 0.12, .kills = 1, .deaths = 3, .assists = 1, .cs = 429, .gold = 16200, .damage = 21000, .gold14 = 5000, .base = 47.5, .rank = 3, .of = 31, .cands = &.{
                .{ .champ = 10, .rank = 1, .win = 49.9, .low = 48.5, .high = 51.3, .terms = &.{}, .rest = 0 },
                .{ .champ = 11, .rank = 2, .win = 49.4, .low = 48.0, .high = 50.8, .terms = &.{}, .rest = 0 },
                .{ .champ = 5, .rank = 3, .win = 48.9, .low = 47.6, .high = 50.2, .rest = 0.1, .terms = &.{
                    .{ .kind = .strength, .other = null, .pp = 0.6, .games = 4100 },
                    .{ .kind = .into, .other = 0, .pp = 0.9, .games = 1200 },
                    .{ .kind = .with, .other = 6, .pp = 0.2, .games = 880 },
                    .{ .kind = .into, .other = 2, .pp = -0.4, .games = 2300 },
                } },
            } },
            seat(6, 0.1, 50.0, 5, 5200),
            seat(7, 0.96, 50.0, 9, 5300),
            seat(8, 0.03, 50.0, 2, 5000),
            seat(9, 0.81, 50.0, 7, 4300),
        },
    },
    .turns = &.{},
    .hidden_side = .red,
    .hidden_role = .top,
    .options = &.{ 5, 11, 10 },
    .hint = .{ .kind = .ad, .fits = 0b011 },
    .lanes = .{ 51.4, 50.1, 49.1, 50.9, 51.3 },
    .result = .{ .winner = .blue, .secs = 2491, .kills = .{ 10, 8 }, .gold = .{ 84300, 79300 }, .towers = .{ 9, 6 }, .dragons = .{ 2, 4 }, .barons = .{ 1, 1 } },
    .paper = .{ .blue = 51.1, .low = 48.9, .high = 53.3, .edges = .{ 1.2, 0.3, -0.6, 0.2 } },
};

fn seat(c: u16, magic: f32, base: f32, rank: u16, gold14: u32) Seat {
    return .{ .champ = c, .magic = magic, .kills = 2, .deaths = 2, .assists = 4, .cs = 300, .gold = 15000, .damage = 12000, .gold14 = gold14, .base = base, .rank = rank, .of = 30, .cands = &.{} };
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
    p = sample;
    p.options = &.{ 5, 11, 5 };
    try std.testing.expect(!p.valid());
    p = sample;
    p.paper.?.blue = std.math.nan(f32);
    try std.testing.expect(!p.valid());
    p = sample;
    p.lanes[2] = std.math.inf(f32);
    try std.testing.expect(!p.valid());
    p = sample;
    p.seats[0][3].magic = 1.5;
    try std.testing.expect(!p.valid());
}

test "dmgOf: a third and two thirds magic are mixed, past them AD or AP" {
    try std.testing.expectEqual(Dmg.ad, dmgOf(0.34).?);
    try std.testing.expectEqual(Dmg.mixed, dmgOf(0.35).?);
    try std.testing.expectEqual(Dmg.mixed, dmgOf(0.65).?);
    try std.testing.expectEqual(Dmg.ap, dmgOf(0.66).?);
    try std.testing.expectEqual(null, dmgOf(null));
}

/// A pro draft for `sample`: red's last pick its played top, one ban not made
pub const pro_turns = blk: {
    var t: [20]Turn = undefined;
    for (&t, pro_sides, 0..) |*x, side, i| x.* = .{ .champ = @intCast(i % 12), .side = side };
    t[13].champ = null;
    t[19].champ = 5;
    break :blk t;
};

test "a pro puzzle survives the binary file: 20 turns with a ban not made, bans, no rank, nulls" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = sample;
    p.turns = &pro_turns;
    p.bans = .{ &.{ 0, 1 }, &.{2} };
    p.seats[0][1].rank = null;
    p.paper = null;
    p.lanes[1] = null;
    p.result.towers = null;
    p.hint = .{ .kind = .ap, .fits = 0b101 };
    try std.testing.expect(p.valid());
    const back = try decode(a, try encode(a, p));
    try std.testing.expect(back.valid());
    try std.testing.expectEqual(@as(usize, 20), back.turns.len);
    try std.testing.expectEqual(@as(?u16, null), back.turns[13].champ);
    try std.testing.expectEqual(Side.red, back.turns[19].side);
    try std.testing.expectEqual(@as(usize, 2), back.bans[0].len);
    try std.testing.expectEqual(@as(?u16, null), back.seats[0][1].rank);
    try std.testing.expect(back.paper == null and back.lanes[1] == null);
    try std.testing.expect(back.result.towers == null and back.result.dragons != null);
    try std.testing.expectEqual(@as(u8, 0b101), back.hint.?.fits);
    try std.testing.expectEqual(@as(?f32, 48.5), back.seats[1][0].cands[0].low);

    var bad = p;
    var swapped = pro_turns;
    swapped[0].side = .red;
    bad.turns = &swapped;
    try std.testing.expect(!bad.valid());
    var other_last = pro_turns;
    other_last[19].champ = 11;
    bad.turns = &other_last;
    try std.testing.expect(!bad.valid());
}
