//! LobbyForm: the desktop app's panel before champ select (home, lobby, queue, match
//! found; docs/plan/ui/app-phases.md): your last games as a win/loss strip with the
//! record and average KDA, a line on the run you are on, the champions going well
//! lately, then your mastery top. The player's own games only, from the League client;
//! static HTML under the island (src/shell/lobby.zig builds it)
const std = @import("std");
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const kda = @import("kda.zig");
const resultstrip = @import("resultstrip.zig");
const yl = @import("yourlist.zig");
const phrase = @import("phrase.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "LobbyForm";
pub const scope = .{".c-lobby"};

pub const Game = struct {
    /// `Lobby.champs` index
    champ: u16,
    win: bool,
};

pub const Best = struct {
    champ: champ.Champ,
    games: u16,
    wins: u16,
    /// Per game, rounded
    kda: kda.Kda,
};

pub const Top = struct { champ: champ.Champ, points: u32 };

pub const Lobby = struct {
    champs: []const champ.Champ = &.{},
    /// Newest first
    games: []const Game = &.{},
    wins: u16 = 0,
    /// Per game, rounded
    kda: kda.Kda = .{ .k = 0, .d = 0, .a = 0 },
    /// The run of results in a few words ("4 wins in a row"); "" none
    run: []const u8 = "",
    best: []const Best = &.{},
    top: []const Top = &.{},
};

pub fn view(h: *H, l: Lobby) N {
    return h.section(.{ .class = "c-lobby" }, .{
        if (l.games.len > 0) form(h, l) else null,
        if (l.best.len > 0) h.h3(.{}, .{W.best}) else null,
        if (l.best.len > 0) best(h, l.best) else null,
        if (l.top.len > 0) h.h3(.{}, .{W.top}) else null,
        if (l.top.len > 0) top(h, l.top) else null,
        h.p(.{ .class = "note" }, .{W.source}),
    });
}

fn form(h: *H, l: Lobby) N {
    const games = h.mem.alloc(yl.Game, l.games.len) catch {
        h.oom = true;
        return .none;
    };
    for (games, l.games) |*g, x| g.* = .{ .start_ms = 0, .dur = 0, .patch = "", .queue = .other, .champ = x.champ, .win = x.win, .k = 0, .d = 0, .a = 0 };
    const n: u32 = @intCast(l.games.len);
    return h.div(.{ .class = "form" }, .{
        h.h3(.{}, .{W.form.with(h, .{ .n = n })}),
        h.div(.{ .class = "row" }, .{
            resultstrip.view(h, l.champs, games, .{ .n = @intCast(@min(n, 255)), .s = .l }),
            h.span(.{ .class = "rec" }, .{W.record.with(h, .{ .w = @as(u32, l.wins), .l = n - l.wins, .p = 100 * @as(u32, l.wins) / @max(n, 1) })}),
            kda.view(h, l.kda, .{ .ratio = true }),
        }),
        if (l.run.len > 0) h.p(.{ .class = "run" }, .{l.run}) else null,
    });
}

fn best(h: *H, rows: []const Best) N {
    var list = h.list();
    for (rows, 0..) |b, i| list.add(h.li(.{ .key = i }, .{
        champ.view(h, b.champ, .{ .px = .@"32", .named = false }),
        h.span(.{ .class = "who" }, .{
            b.champ.name,
            h.small(.{}, .{W.won.with(h, .{ .w = @as(u32, b.wins), .n = @as(u32, b.games) })}),
        }),
        kda.view(h, b.kda, .{ .ratio = true }),
    }));
    return h.ul(.{ .class = "best" }, .{list.done()});
}

fn top(h: *H, rows: []const Top) N {
    var list = h.list();
    for (rows, 0..) |t, i| list.add(h.li(.{ .key = i, .title = t.champ.name }, .{
        champ.view(h, t.champ, .{ .px = .@"32", .named = false }),
        h.small(.{}, .{W.points.with(h, .{ .p = t.points })}),
    }));
    return h.ul(.{ .class = "top" }, .{list.done()});
}

const W = struct {
    const form = phrase.Phrase("Your last {n:int} games");
    const record = phrase.Phrase("{w:int} W {l:int} L · {p:pct}");
    const best = plain("Going well lately");
    const won = phrase.Phrase("{w:int} of {n:int} won");
    const top = plain("Most mastery");
    const points = phrase.Phrase("{p:kilo}");
    const source = plain("Your own Summoner's Rift games, from your League client.");
};

pub const css =
    \\@layer components {
    \\  .c-lobby { display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; }
    \\  .c-lobby h3 { margin: var(--sp-2) 0 0; font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-lobby .form { display: flex; flex-direction: column; gap: var(--sp-2); padding: var(--sp-2) var(--sp-3);
    \\    border-radius: var(--r-s); background: var(--panel-2); }
    \\  .c-lobby .form h3 { margin: 0; }
    \\  .c-lobby .row { display: flex; flex-wrap: wrap; align-items: flex-end; gap: var(--sp-3); }
    \\  .c-lobby .rec { font-size: var(--fs-m); font-weight: var(--w-b); font-variant-numeric: tabular-nums; }
    \\  .c-lobby .run { margin: 0; font-size: var(--fs-s); }
    \\  .c-lobby ul { list-style: none; margin: 0; padding: 0; }
    \\  .c-lobby .best { display: flex; flex-direction: column; gap: 4px; max-width: 360px; }
    \\  .c-lobby .best li { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-lobby .who { display: flex; flex-direction: column; flex: 1; min-width: 0; font-size: var(--fs-s); }
    \\  .c-lobby .who > small { font-size: var(--fs-xs); color: var(--t2); font-variant-numeric: tabular-nums; }
    \\  .c-lobby .top { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
    \\  .c-lobby .top li { display: flex; flex-direction: column; align-items: center; gap: 2px; }
    \\  .c-lobby .top small { font-size: var(--fs-xs); color: var(--t2); font-variant-numeric: tabular-nums; }
    \\  .c-lobby .note { margin: 0; font-size: var(--fs-xs); color: var(--faint); }
    \\}
    \\
;

const demo = champ.demo;

const demo_champs = [_]champ.Champ{ demo("Ahri", "Ahri"), demo("Syndra", "Syndra"), demo("Orianna", "Orianna") };

pub const sample: Lobby = .{
    .champs = &demo_champs,
    .games = &.{
        .{ .champ = 0, .win = true },  .{ .champ = 0, .win = true },  .{ .champ = 1, .win = true },
        .{ .champ = 2, .win = false }, .{ .champ = 0, .win = false }, .{ .champ = 0, .win = true },
        .{ .champ = 1, .win = true },  .{ .champ = 0, .win = false }, .{ .champ = 2, .win = true },
        .{ .champ = 0, .win = true },
    },
    .wins = 7,
    .kda = .{ .k = 7, .d = 4, .a = 9 },
    .run = "On a roll: 3 wins in a row",
    .best = &.{
        .{ .champ = demo("Ahri", "Ahri"), .games = 5, .wins = 4, .kda = .{ .k = 8, .d = 3, .a = 9 } },
        .{ .champ = demo("Syndra", "Syndra"), .games = 2, .wins = 2, .kda = .{ .k = 9, .d = 3, .a = 6 } },
    },
    .top = &.{
        .{ .champ = demo("Ahri", "Ahri"), .points = 212_000 },
        .{ .champ = demo("Orianna", "Orianna"), .points = 64_000 },
        .{ .champ = demo("Syndra", "Syndra"), .points = 41_000 },
    },
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("ten games, best and mastery", view(h, sample));
    g.add("mastery only (no games yet)", view(h, .{ .top = sample.top }));
}

const testing = std.testing;

test "form, best and mastery; parts without data left out" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const full = try render(a, sample);
    try testing.expectEqual(10, std.mem.count(u8, full, "data-r="));
    try testing.expectEqual(3, std.mem.count(u8, full, "<h3"));
    try testing.expect(std.mem.find(u8, full, "7 W 3 L · 70%") != null);
    try testing.expect(std.mem.find(u8, full, "4 of 5 won") != null);
    try testing.expect(std.mem.find(u8, full, "212k") != null);
    const bare = try render(a, .{ .top = sample.top });
    try testing.expectEqual(0, std.mem.count(u8, bare, "data-r="));
    try testing.expectEqual(1, std.mem.count(u8, bare, "<h3"));
}

fn render(a: std.mem.Allocator, l: Lobby) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const root = view(&h, l);
    try testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, root, &out.writer);
    return out.written();
}
