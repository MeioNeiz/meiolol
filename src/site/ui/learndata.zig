//! Learn's data (docs/plan/ui/learn.md): chapters of puzzles, each a setup drawn as UI
//! (the numbers the player needs live here, never in the question), a short question,
//! the answer (a guess on a slider or a pick), what the reveal adds, one line why and the
//! takeaway. The page is rendered on request, so it rides in the island root's data-bin
//! (ui.data), as the matchup page's. Progress (stars per puzzle) stays in the browser:
//! `Progress` reads and writes it as a short string for localStorage
const std = @import("std");
const role = @import("role.zig");
const guess = @import("guess.zig");

pub const Role = role.Role;

pub const Data = struct {
    /// Data Dragon version for champion icons
    ddragon: []const u8,
    chapters: []const Chapter,
    /// The chapter a first visit lands on (1: chapter 0 is one tap away); today's five
    /// come from it and the four after
    start: u8 = 1,
};

pub const Chapter = struct {
    /// A question: "Does knowing your champion matter?"
    title: []const u8,
    puzzles: []const Puzzle,
};

/// A champion: Data Dragon key and name
pub const Champ = struct { key: []const u8, name: []const u8 };

/// A win rate row (RateRows), or a bar of the reveal
pub const Rate = struct {
    label: []const u8,
    sub: []const u8 = "",
    v: f32,
    games: u32,
};

pub const Setup = union(enum) {
    /// RateRows; row `ask` is the asked one: its rate is the answer, hidden until then
    rates: struct { rows: []const Rate, ask: u8 },
    /// One champion and the options against it, each with a figure ("48%")
    duel: Duel,
    /// Example tiles: a group's name and its champions (chapter 0's roles)
    tiles: []const Tile,
    /// Champions and short figures as Chips ("+850 gold at 14")
    chips: Chips,
    /// A few big figures, each with what it counts ("+1,000 gold", "you, at 14 min")
    facts: []const Fact,
    /// A real game's draft with one seat open (chapter ends)
    draft: Draft,
};

/// Seats in role order. The open seat's champion is the game's own pick, not shown
pub const Draft = struct {
    role: Role,
    us: [5]Champ,
    them: [5]Champ,
    /// Each seat's magic share of its damage, %, us then them; the open seat's is the right
    /// pick's, shown once revealed
    magic: [2][5]?u8 = @splat(@splat(null)),
};

pub const Fact = struct { v: []const u8, label: []const u8 };

pub const Duel = struct { who: Champ, role: Role, label: []const u8, vs: []const Figure };
pub const Chips = struct { champs: []const Champ, chips: []const []const u8 };

pub const Figure = struct { champ: Champ, text: []const u8 };
pub const Tile = struct {
    title: []const u8,
    role: ?Role = null,
    champs: []const Champ,
    /// Between the champions, so the tile reads as one phrase ("beats", "+")
    sep: []const u8 = "",
};

pub const Answer = union(enum) {
    guess: Guess,
    pick: Pick,
};

pub const Guess = struct {
    lo: f32,
    hi: f32,
    step: f32 = 0.5,
    unit: guess.Unit = .rate,
    real: f32,
    /// Three stars within this, two within 2.5 times, one within 5
    tol: f32 = 1,
};

pub const Pick = struct {
    choices: []const Choice,
    right: u8,
};

pub const Choice = struct {
    text: []const u8,
    champ: ?Champ = null,
    role: ?Role = null,
    /// Shown on reveal: its number ("54%", "92.7%") and games
    shown: []const u8 = "",
    games: u32 = 0,
    /// The reveal's reasons in words ("Good into Ahri"), no numbers (why.md)
    why: []const Why = &.{},
};

pub const Why = struct { text: []const u8, up: bool };

pub const Puzzle = struct {
    id: []const u8,
    /// At most 12 words, no numbers
    q: []const u8,
    /// A word of `q` with a Toggletip ("counter") and its note
    term: ?Term = null,
    /// Under the question before the answer: what the setup counts
    ctx: []const u8 = "",
    setup: Setup,
    answer: Answer,
    /// What the reveal shows beyond the setup (all the mastery bands)
    reveal: []const Rate = &.{},
    /// At most 20 words
    why: []const u8,
    tip: []const u8,
    games: u32,
    /// The games' source, in the games Toggletip
    from: []const u8,
};

pub const Term = struct { word: []const u8, note: []const u8 };

/// Today's puzzle of `c`: the one whose id hashes lowest with the date, so a puzzle added or
/// dropped by a rebuild moves no other day's pick
pub fn pickOf(date: []const u8, c: Chapter) u8 {
    var best: u8 = 0;
    var low: u32 = std.math.maxInt(u32);
    for (c.puzzles, 0..) |z, i| {
        var f: std.hash.Fnv1a_32 = .init();
        f.update(date);
        f.update(z.id);
        if (f.final() < low) {
            low = f.final();
            best = @intCast(i);
        }
    }
    return best;
}

/// Stars per puzzle id, as "id:n" joined by commas ("know:2,newcomer:3"). Two more kinds of
/// id: "@2026-10-30.2", slot 2 of that day's five (its first try), and "end-<title>", a
/// chapter's end reached (generated puzzles change with the data, so "every
/// puzzle done" alone would lock a finished chapter again)
pub const Progress = struct {
    /// One list, not ids and stars apart: each append is code in ui-learn.wasm
    all: std.ArrayList(Entry) = .empty,

    pub const Entry = struct { id: []const u8, n: u2 };

    pub fn parse(a: std.mem.Allocator, s: []const u8) !Progress {
        var p: Progress = .{};
        var it = std.mem.splitScalar(u8, s, ',');
        // By hand, not tokenize and parseInt: ui-learn's bytes
        while (it.next()) |e| {
            if (e.len < 3 or e[e.len - 2] != ':' or e[e.len - 1] < '0' or e[e.len - 1] > '3') continue;
            try p.set(a, try a.dupe(u8, e[0 .. e.len - 2]), @intCast(e[e.len - 1] - '0'));
        }
        return p;
    }

    pub fn get(p: *const Progress, id: []const u8) ?u2 {
        for (p.all.items) |e| if (std.mem.eql(u8, e.id, id)) return e.n;
        return null;
    }

    /// Keeps the best try
    pub fn set(p: *Progress, a: std.mem.Allocator, id: []const u8, n: u2) !void {
        for (p.all.items) |*e| if (std.mem.eql(u8, e.id, id)) {
            e.n = @max(e.n, n);
            return;
        };
        try p.all.append(a, .{ .id = id, .n = n });
    }

    /// Day marks kept: the newest 30 days' five
    pub const keep_marks = 150;

    /// Drops the oldest day marks past `keep_marks`
    pub fn write(p: *const Progress, w: *std.Io.Writer) !void {
        var marks: usize = 0;
        for (p.all.items) |e| marks += @intFromBool(isMark(e.id));
        var drop = marks -| keep_marks;
        var first = true;
        for (p.all.items) |e| {
            if (drop > 0 and isMark(e.id)) {
                drop -= 1;
                continue;
            }
            if (!first) try w.writeByte(',');
            first = false;
            try w.writeAll(e.id);
            try w.writeAll(&.{ ':', '0' + @as(u8, e.n) });
        }
    }

    fn isMark(id: []const u8) bool {
        return id.len > 0 and id[0] == '@';
    }

    /// Slot `slot` of `date`'s five
    pub fn mark(buf: *[40]u8, date: []const u8, slot: u8) []const u8 {
        return idOf(buf, &.{ "@", date, ".", &.{'0' + slot} });
    }

    /// `c`'s end reached
    pub fn endOf(buf: *[40]u8, c: Chapter) []const u8 {
        return idOf(buf, &.{ "end-", c.title });
    }

    /// `parts` joined without the list's own separators, cut to fit
    fn idOf(buf: *[40]u8, parts: []const []const u8) []const u8 {
        var n: usize = 0;
        for (parts) |x| for (x) |b| if (b != ',' and b != ':' and n < buf.len) {
            buf[n] = b;
            n += 1;
        };
        return buf[0..n];
    }

    /// Played to its end, or every puzzle of this data done: its slot in the day's five opens
    pub fn finished(p: *const Progress, c: Chapter) bool {
        var buf: [40]u8 = undefined;
        return p.get(endOf(&buf, c)) != null or p.chapter(c).done == c.puzzles.len;
    }

    /// Puzzles done and stars won in `c`
    pub fn chapter(p: *const Progress, c: Chapter) struct { done: u8, stars: u8 } {
        var d: u8 = 0;
        var s: u8 = 0;
        for (c.puzzles) |z| if (p.get(z.id)) |n| {
            d += 1;
            s += n;
        };
        return .{ .done = d, .stars = s };
    }
};

pub fn ch(comptime key: []const u8, comptime n: []const u8) Champ {
    return .{ .key = key, .name = n };
}

/// The gallery's and tests' Learn: chapter 0's role puzzle, chapter 1 as live
pub const demo: Data = .{
    .ddragon = "16.21.1",
    .chapters = &.{
        .{ .title = "The basics", .puzzles = &.{.{
            .id = "role-leesin",
            .q = "Which role is Lee Sin?",
            .setup = .{ .tiles = &.{
                .{ .title = "Top", .role = .top, .champs = &.{ ch("Garen", "Garen"), ch("Darius", "Darius"), ch("Sett", "Sett") } },
                .{ .title = "Jungle", .role = .jungle, .champs = &.{ ch("Viego", "Viego"), ch("Kayn", "Kayn"), ch("Khazix", "Kha'Zix") } },
                .{ .title = "Mid", .role = .mid, .champs = &.{ ch("Ahri", "Ahri"), ch("Orianna", "Orianna"), ch("Yasuo", "Yasuo") } },
                .{ .title = "Bot", .role = .bot, .champs = &.{ ch("Kaisa", "Kai'Sa"), ch("Jhin", "Jhin"), ch("Jinx", "Jinx") } },
                .{ .title = "Support", .role = .support, .champs = &.{ ch("Thresh", "Thresh"), ch("Nami", "Nami"), ch("Lulu", "Lulu") } },
            } },
            .answer = .{ .pick = .{ .right = 1, .choices = &.{
                .{ .text = "Top", .role = .top, .shown = "2.7%", .games = 758 },
                .{ .text = "Jungle", .role = .jungle, .shown = "92.7%", .games = 25_861 },
                .{ .text = "Mid", .role = .mid, .shown = "1.4%", .games = 403 },
                .{ .text = "Bot", .role = .bot, .shown = "0.3%", .games = 76 },
                .{ .text = "Support", .role = .support, .shown = "2.9%", .games = 798 },
            } } },
            .why = "Lee Sin is played in the jungle in 9 games of 10.",
            .tip = "Each champion has a usual role: start there.",
            .games = 27_896,
            .from = "Lee Sin's games by role, last 30 days",
        }} },
        .{ .title = "Does knowing your champion matter?", .puzzles = &.{
            .{
                .id = "know",
                .q = "How often do mains win?",
                .ctx = "Mastery points on the champion, before the game",
                .setup = .{ .rates = .{ .ask = 1, .rows = &.{
                    .{ .label = "New", .sub = "under 10k", .v = 47.7, .games = 207_598 },
                    .{ .label = "Main", .sub = "300k+", .v = 51.7, .games = 508_609 },
                } } },
                .answer = .{ .guess = .{ .lo = 40, .hi = 60, .real = 51.7 } },
                .reveal = &.{
                    .{ .label = "<10k", .sub = "New", .v = 47.7, .games = 207_598 },
                    .{ .label = "10-30k", .v = 48.7, .games = 262_918 },
                    .{ .label = "30-100k", .v = 49.5, .games = 486_889 },
                    .{ .label = "100-300k", .v = 50.6, .games = 457_460 },
                    .{ .label = "300k+", .sub = "Main", .v = 51.7, .games = 508_609 },
                },
                .why = "New to main: +4 points. A typical top lane counter is 2.5.",
                .tip = "Counter-pick with a champion you already know.",
                .games = 508_609,
                .from = "Ranked solo, Platinum IV and up, every region, by mastery points on the champion before the game",
            },
            .{
                .id = "counter-top",
                .q = "Which is a real counter?",
                .term = .{ .word = "counter", .note = "Wins more against this champion than against everyone else." },
                .setup = .{ .duel = .{ .who = ch("Yone", "Yone"), .role = .top, .label = "wins against", .vs = &.{
                    .{ .champ = ch("Garen", "Garen"), .text = "48%" },
                    .{ .champ = ch("Jax", "Jax"), .text = "46%" },
                    .{ .champ = ch("Malphite", "Malphite"), .text = "48%" },
                } } },
                .answer = .{ .pick = .{ .right = 1, .choices = &.{
                    .{ .text = "Garen", .champ = ch("Garen", "Garen"), .shown = "+1", .games = 3_889 },
                    .{ .text = "Jax", .champ = ch("Jax", "Jax"), .shown = "+5", .games = 4_994 },
                    .{ .text = "Malphite", .champ = ch("Malphite", "Malphite"), .shown = "0", .games = 4_788 },
                } } },
                .reveal = &.{
                    .{ .label = "Garen", .sub = "into Yone", .v = 52, .games = 3_889 },
                    .{ .label = "Garen", .sub = "vs everyone", .v = 51, .games = 61_204 },
                    .{ .label = "Jax", .sub = "into Yone", .v = 54, .games = 4_994 },
                    .{ .label = "Jax", .sub = "vs everyone", .v = 49, .games = 70_118 },
                    .{ .label = "Malphite", .sub = "into Yone", .v = 52, .games = 4_788 },
                    .{ .label = "Malphite", .sub = "vs everyone", .v = 52, .games = 58_930 },
                },
                .why = "Jax wins 49% against everyone, 54% against Yone.",
                .tip = "Before calling it a counter, check the enemy's win rate against everyone.",
                .games = 13_671,
                .from = "Ranked solo, every region, all ranks, last 30 days; top lane games only",
            },
        } },
    },
};

const testing = std.testing;

test "progress keeps the best try and round-trips" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = try Progress.parse(a, "know:2,bad,x:9,counter-top:1");
    try testing.expectEqual(@as(?u2, 2), p.get("know"));
    try testing.expectEqual(@as(?u2, null), p.get("x"));
    try p.set(a, "know", 1);
    try p.set(a, "counter-top", 3);
    try testing.expectEqual(@as(?u2, 2), p.get("know"));
    var out: std.Io.Writer.Allocating = .init(a);
    try p.write(&out.writer);
    try testing.expectEqualStrings("know:2,counter-top:3", out.written());
    const c = p.chapter(demo.chapters[1]);
    try testing.expectEqual(@as(u8, 2), c.done);
    try testing.expectEqual(@as(u8, 5), c.stars);
}

test "day marks: the oldest dropped past keep_marks; a chapter's end opens its slot" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p: Progress = .{};
    var buf: [40]u8 = undefined;
    try p.set(a, try a.dupe(u8, Progress.mark(&buf, "2026-01-01", 0)), 1);
    try p.set(a, "know", 3);
    for (0..Progress.keep_marks) |i| try p.set(a, try std.fmt.allocPrint(a, "@x.{d}", .{i}), 2);
    var out: std.Io.Writer.Allocating = .init(a);
    try p.write(&out.writer);
    try testing.expect(std.mem.startsWith(u8, out.written(), "know:3,@x.0:2,"));
    const q = try Progress.parse(a, out.written());
    try testing.expectEqual(Progress.keep_marks + 1, q.all.items.len);
    try testing.expect(!p.finished(demo.chapters[1]));
    try p.set(a, Progress.endOf(&buf, demo.chapters[1]), 0);
    try testing.expect(p.finished(demo.chapters[1]));
    try testing.expect(p.finished(demo.chapters[0]) == false);
}

test "a day's pick holds when another puzzle is added" {
    const c = demo.chapters[1];
    const i = pickOf("2026-10-30", c);
    var more: [3]Puzzle = .{ c.puzzles[0], c.puzzles[1], c.puzzles[1] };
    more[2].id = "new-one";
    const j = pickOf("2026-10-30", .{ .title = c.title, .puzzles = &more });
    try testing.expect(j == i or j == 2);
}

test "the demo round-trips through ui.data" {
    const data = @import("data.zig");
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var b: std.ArrayList(u8) = .empty;
    try data.encode(arena.allocator(), Data, demo, &b);
    const d = try data.decode(arena.allocator(), Data, b.items);
    try testing.expectEqualStrings("Which is a real counter?", d.chapters[1].puzzles[1].q);
    try testing.expectEqual(@as(u8, 1), d.chapters[1].puzzles[0].setup.rates.ask);
}
