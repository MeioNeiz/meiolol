//! PlayerBar: the Your games page's head card (your-games.md "Structure"): rank badge,
//! Riot ID, rank line, the shown games' record, KDA and streak, the last 20 as a
//! ResultStrip; the page's buttons at the end and its bands (tabs, filter row) under it.
//! The badge is the tier's letters until rank emblems ship (plan "Data needed")
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const strip = @import("strip.zig");
const resultstrip = @import("resultstrip.zig");
const champ = @import("champ.zig");
const yl = @import("yourlist.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "PlayerBar";
pub const scope = .{".c-player"};

pub const Opts = struct {
    /// The games the figures cover, newest first (the filtered list); null: all of them
    games: ?[]const yl.Game = null,
    /// Buttons at the end of the identity row (check for new games, the menu)
    end: []const N = &.{},
    /// Bands under it, in the same card: Tabs, the filter row
    bands: []const N = &.{},
};

const W = struct {
    pub const record = plain("Record");
    pub const kda = plain("KDA");
    pub const streak = plain("Streak");
    pub const last = phrase.Phrase("Last {n:int}");
    pub const wl = phrase.Phrase("{w:int}–{l:int}");
    pub const rate = phrase.Phrase("{p:pct}");
    pub const ratio = phrase.Phrase("{r:dec}");
    pub const won = phrase.Phrase("{n:int}W");
    pub const lost = phrase.Phrase("{n:int}L");
    pub const tag = phrase.Phrase("#{t:text}");
    pub const ranked = phrase.Phrase("{t:text} {d:text}");
    pub const lp = phrase.Phrase("{r:text} · {lp:int} LP");
    pub const unranked = plain("Unranked");
};

const Tier = struct { riot: []const u8, name: tree.Text, short: []const u8, divisions: bool = true };

const tiers = [_]Tier{
    .{ .riot = "IRON", .name = plain("Iron"), .short = "I" },
    .{ .riot = "BRONZE", .name = plain("Bronze"), .short = "B" },
    .{ .riot = "SILVER", .name = plain("Silver"), .short = "S" },
    .{ .riot = "GOLD", .name = plain("Gold"), .short = "G" },
    .{ .riot = "PLATINUM", .name = plain("Platinum"), .short = "P" },
    .{ .riot = "EMERALD", .name = plain("Emerald"), .short = "E" },
    .{ .riot = "DIAMOND", .name = plain("Diamond"), .short = "D" },
    .{ .riot = "MASTER", .name = plain("Master"), .short = "M", .divisions = false },
    .{ .riot = "GRANDMASTER", .name = plain("Grandmaster"), .short = "GM", .divisions = false },
    .{ .riot = "CHALLENGER", .name = plain("Challenger"), .short = "C", .divisions = false },
};

fn tierOf(riot: ?[]const u8) ?Tier {
    const t = riot orelse return null;
    for (tiers) |x| if (std.mem.eql(u8, x.riot, t)) return x;
    return null;
}

/// "II" -> 2; 0 for anything else
fn division(d: ?[]const u8) u8 {
    const romans = [_][]const u8{ "I", "II", "III", "IV" };
    for (romans, 1..) |r, i| if (d != null and std.mem.eql(u8, d.?, r)) return @intCast(i);
    return 0;
}

/// "Gold II", "Master", "Unranked"
pub fn rankName(h: *H, p: yl.Player) tree.Text {
    const t = tierOf(p.tier) orelse return W.unranked;
    if (!t.divisions or division(p.division) == 0) return t.name;
    return W.ranked.with(h, .{ .t = t.name.s, .d = p.division orelse "" });
}

fn badge(h: *H, p: yl.Player) N {
    const t = tierOf(p.tier) orelse return h.span(.{ .class = "emb", .data_none = true, .aria_hidden = true }, .{"–"});
    const d = division(p.division);
    return h.span(.{ .class = "emb", .data_tier = t.riot, .title = rankName(h, p), .aria_hidden = true }, .{
        t.short,
        if (t.divisions and d > 0) h.fmt("{d}", .{d}) else null,
    });
}

pub fn view(h: *H, l: *const yl.List, o: Opts) N {
    const p = l.player;
    const games = o.games orelse l.games;
    const t = yl.totals(games, .{});
    const rank = rankName(h, p);
    var items: [3]strip.Item = undefined;
    var n: usize = 0;
    if (t.games > 0) {
        items[n] = .{
            .label = W.record,
            .value = W.wl.with(h, .{ .w = t.wins, .l = t.losses() }),
            .ctx = W.rate.with(h, .{ .p = @as(u32, t.wins) * 100 / t.games }),
            .answer = true,
        };
        items[n + 1] = .{ .label = W.kda, .value = W.ratio.with(h, .{ .r = t.kda() }) };
        n += 2;
    }
    const run = yl.streak(games) orelse yl.Streak{ .win = false, .n = 0 };
    if (run.n >= 2) {
        items[n] = .{ .label = W.streak, .value = if (run.win) W.won.with(h, .{ .n = run.n }) else W.lost.with(h, .{ .n = run.n }) };
        n += 1;
    }
    const form = resultstrip.view(h, l.champs, games, .{ .s = .l });
    return h.section(.{ .class = "c-player" }, .{
        h.div(.{ .class = "who" }, .{
            badge(h, p),
            h.div(.{ .class = "id" }, .{
                h.el(.h1, .{}, .{ p.name, if (p.tag.len > 0) h.span(.{ .class = "tag" }, .{W.tag.with(h, .{ .t = p.tag })}) else null }),
                h.div(.{ .class = "rank" }, .{if (p.lp != null and tierOf(p.tier) != null) W.lp.with(h, .{ .r = rank.s, .lp = p.lp.? }) else rank}),
            }),
            if (n > 0) strip.view(h, items[0..n]) else null,
            if (t.games > 0) h.div(.{ .class = "form" }, .{
                h.span(.{ .class = "lab" }, .{W.last.with(h, .{ .n = @min(t.games, 20) })}),
                form,
            }) else null,
            if (o.end.len > 0) h.div(.{ .class = "end" }, .{o.end}) else null,
        }),
        o.bands,
    });
}

pub const css =
    \\@layer components {
    \\  .c-player { container-type: inline-size; background: var(--panel); border: 1px solid var(--line);
    \\    border-radius: var(--r-l); overflow: hidden; }
    \\  .c-player > .who { display: flex; flex-wrap: wrap; align-items: flex-end; gap: var(--sp-3) var(--sp-6);
    \\    padding: var(--sp-4); position: relative; }
    \\  .c-player > :not(.who) { border-top: 1px solid var(--line); }
    \\  .c-player .emb { flex: none; width: 56px; height: 56px; border-radius: 50%; display: grid; place-items: center;
    \\    align-self: center; font-size: var(--fs-l); font-weight: var(--w-b); color: var(--t1);
    \\    background: var(--ctl-bg); box-shadow: inset 0 0 0 4px var(--line); }
    \\  .c-player .emb[data-none] { color: var(--faint); }
    \\  .c-player .id { align-self: center; min-width: 0; }
    \\  .c-player h1 { margin: 0; font-size: var(--fs-xl); line-height: 1.15; overflow-wrap: anywhere; }
    \\  .c-player h1 > .tag { margin-left: 4px; font-size: var(--fs-l); font-weight: var(--w-r); color: var(--faint); }
    \\  .c-player .rank { font-size: var(--fs-s); color: var(--muted); }
    \\  .c-player .form { display: flex; flex-direction: column; gap: 4px; }
    \\  .c-player .form > .lab { font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-player > .who > .end { margin-left: auto; align-self: flex-start; display: flex; gap: var(--sp-2); }
    \\  @container (max-width: 640px) {
    \\    .c-player .emb { width: 44px; height: 44px; font-size: var(--fs-s); }
    \\    .c-player > .who > .end { position: absolute; top: var(--sp-3); right: var(--sp-3); }
    \\    .c-player > .who > .id { padding-right: 88px; }
    \\    .c-player .c-strip { flex-basis: 100%; }
    \\    .c-player .form { flex-basis: 100%; flex-direction: row; align-items: center; gap: var(--sp-3); }
    \\    .c-player .form > .c-form { height: 20px; }
    \\  }
    \\}
    \\
;

const demo = struct {
    const champs = [_]champ.Champ{ .{ .name = "Aurelion Sol", .src = "" }, .{ .name = "Karthus", .src = "" } };
    const games = blk: {
        const results = "wwwwwlwlllwwwlwwlwwwlwlw";
        var gs: [results.len]yl.Game = undefined;
        for (&gs, results, 0..) |*x, r, i| x.* = .{
            .start_ms = 0,
            .dur = 1800,
            .patch = "",
            .queue = .solo,
            .champ = i % 2,
            .win = r == 'w',
            .k = 7,
            .d = 4,
            .a = 9 + i % 5,
        };
        break :blk gs;
    };
    const ranked: yl.List = .{
        .player = .{ .name = "MeioNeiz", .tag = "EUW", .tier = "PLATINUM", .division = "II", .lp = 2 },
        .champs = &champs,
        .games = &games,
    };
    const unranked: yl.List = .{ .player = .{ .name = "A very long summoner name", .tag = "1234" }, .champs = &champs, .games = games[5..8] };
    const empty: yl.List = .{ .player = .{ .name = "Nobody", .tag = "EUW", .tier = "MASTER", .lp = 120 }, .champs = &champs, .games = &.{} };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const end = h.button(.{ .type = "button", .class = "c-btn" }, .{"⋯"});
    g.addFill("ranked, 5 wins in a row", view(h, &demo.ranked, .{ .end = &.{end} }));
    g.addFill("unranked, a long name, 3 games", view(h, &demo.unranked, .{ .end = &.{end} }));
    g.addFill("master, no games yet", view(h, &demo.empty, .{}));
}

const testing = std.testing;

test "rank words and the figures the games make" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    try testing.expectEqualStrings("Platinum II", rankName(&h, demo.ranked.player).s);
    try testing.expectEqualStrings("Master", rankName(&h, demo.empty.player).s);
    try testing.expectEqualStrings("Unranked", rankName(&h, demo.unranked.player).s);
    try testing.expectEqualStrings("Unranked", rankName(&h, .{ .name = "x", .tier = "WOOD" }).s);

    const n = view(&h, &demo.ranked, .{});
    var buf: std.Io.Writer.Allocating = .init(arena.allocator());
    try t.textOf(n, &buf.writer);
    const s = buf.written();
    try testing.expect(std.mem.find(u8, s, "Platinum II · 2 LP") != null);
    try testing.expect(std.mem.find(u8, s, "16–8") != null);
    try testing.expect(std.mem.find(u8, s, "66%") != null);
    try testing.expect(std.mem.find(u8, s, "5W") != null);
    try testing.expect(std.mem.find(u8, s, "Last 20") != null);
    try testing.expectEqual(20, t.count(n, "data-r"));

    // No games: no figures, no form
    const e = view(&h, &demo.empty, .{});
    try testing.expectEqual(null, t.find(e, "class", "c-strip"));
    try testing.expectEqual(null, t.find(e, "class", "form"));
    try testing.expect(!h.oom);
}
