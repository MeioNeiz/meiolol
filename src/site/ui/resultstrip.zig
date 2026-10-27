//! ResultStrip: recent form as a tick per game, oldest on the left; a win full height in
//! --us, a loss shorter in --them (your-games.md, the player bar's "Last 20"). Remakes
//! count in no record, so they get no tick
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const yl = @import("yourlist.zig");
const Gallery = @import("gallery.zig").Gallery;
const H = tree.H;
const N = tree.N;

pub const name = "ResultStrip";
pub const scope = .{".c-form"};

pub const Opts = struct {
    /// Ticks at most: the newest games
    n: u8 = 20,
    /// Height: s 16 (a teaser), m 22, l 26 (the player bar)
    s: enum { s, m, l } = .m,
};

const W = struct {
    pub const win = phrase.Phrase("Win · {c:text}");
    pub const loss = phrase.Phrase("Loss · {c:text}");
    pub const read = phrase.Phrase("Last {n:int} games: {w:int} wins, {l:int} losses");
};

/// `games` newest first (yl.List.games, filtered or not); `champs` their List.champs
pub fn view(h: *H, champs: []const champ.Champ, games: []const yl.Game, o: Opts) N {
    var picked: [255]*const yl.Game = undefined;
    var n: usize = 0;
    for (games) |*g| {
        if (n == o.n) break;
        if (g.remake) continue;
        picked[n] = g;
        n += 1;
    }
    const ticks = h.mem.alloc(N, n) catch {
        h.oom = true;
        return .none;
    };
    var wins: u16 = 0;
    for (picked[0..n], 0..) |g, i| {
        if (g.win) wins += 1;
        const c = if (g.champ < champs.len) champs[g.champ].name else "";
        // Oldest first: the newest game sits on the right
        ticks[n - 1 - i] = h.el(.i, .{
            .data_r = if (g.win) "w" else "l",
            .title = if (g.win) W.win.with(h, .{ .c = c }) else W.loss.with(h, .{ .c = c }),
        }, .{});
    }
    return h.span(.{
        .class = "c-form",
        .role = "img",
        .aria_label = W.read.with(h, .{ .n = n, .w = wins, .l = n - wins }),
        .data_s = if (o.s == .m) null else o.s,
    }, .{ticks});
}

pub const css =
    \\@layer components {
    \\  .c-form { display: inline-flex; align-items: flex-end; gap: 2px; height: 22px; vertical-align: bottom; }
    \\  .c-form[data-s="l"] { height: 26px; }
    \\  .c-form[data-s="s"] { height: 16px; }
    \\  .c-form > i { width: 5px; border-radius: 1px; height: 100%; background: var(--us); }
    \\  .c-form > i[data-r="l"] { height: 55%; background: var(--them); }
    \\}
    \\
;

/// Newest first: w w l w l l l w w w, a remake, w l w w w l w w w
const demo_games = blk: {
    const results = "wwlwlllwwwrwlwwwlwww";
    var games: [results.len]yl.Game = undefined;
    for (&games, results, 0..) |*x, r, i| x.* = .{
        .start_ms = 0,
        .dur = 1800,
        .patch = "",
        .queue = .solo,
        .champ = i % 2,
        .win = r == 'w',
        .remake = r == 'r',
        .k = 0,
        .d = 0,
        .a = 0,
    };
    break :blk games;
};

const demo_champs = [_]champ.Champ{ .{ .name = "Aurelion Sol", .src = "" }, .{ .name = "Karthus", .src = "" } };

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("last 20, a remake skipped", view(h, &demo_champs, &demo_games, .{}));
    g.add("the player bar's", view(h, &demo_champs, &demo_games, .{ .s = .l }));
    g.add("a teaser's 8", view(h, &demo_champs, &demo_games, .{ .n = 8, .s = .s }));
    g.add("three games", view(h, &demo_champs, demo_games[0..3], .{}));
}

const testing = std.testing;

test "newest on the right, remakes left out, at most n" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const four = view(&h, &demo_champs, &demo_games, .{ .n = 4 });
    try testing.expectEqual(4, t.count(four, "data-r"));
    try testing.expectEqualStrings("Last 4 games: 3 wins, 1 losses", t.attr(four, "aria-label").?);
    // Oldest first: the fourth newest (a win), then the loss, then two wins
    const kids = t.kidsOf(four);
    try testing.expectEqualStrings("w", t.attr(kids[0], "data-r").?);
    try testing.expectEqualStrings("l", t.attr(kids[1], "data-r").?);
    try testing.expectEqualStrings("Loss · Aurelion Sol", t.attr(kids[1], "title").?);
    try testing.expectEqualStrings("w", t.attr(kids[3], "data-r").?);
    try testing.expectEqual(19, t.count(view(&h, &demo_champs, &demo_games, .{}), "data-r"));
    try testing.expect(!h.oom);
}
