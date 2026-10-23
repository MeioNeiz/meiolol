//! How hard champions are to pick up (src/learning.zig): a section on each champion page
//! and a table on the pool page. Games on every row; thin rows greyed out.

const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const matchup = @import("matchup.zig");
const tierlist = @import("tierlist.zig");
const learning = @import("../learning.zig");

const Writer = std.Io.Writer;
const Site = root.Site;
const Champ = root.Champ;
const Learning = learning.Learning;

/// "Under 10k", "10k-30k", "300k+"
fn binLabel(buf: []u8, i: usize) []const u8 {
    const lo = learning.bins[i] / 1000;
    if (i == 0) return std.mem.print(buf, "Under {d}k", .{learning.bins[1] / 1000}) catch "";
    if (i + 1 == learning.bin_count) return std.mem.print(buf, "{d}k+", .{lo}) catch "";
    return std.mem.print(buf, "{d}k-{d}k", .{ lo, learning.bins[i + 1] / 1000 }) catch "";
}

fn pct(x: f64) f64 {
    return 100 * x;
}

const new_text = "under 30k mastery points on it";
const practised_text = "100k+";

/// `period`: "last 30 days", "patch 16.21"
fn footnote(w: *Writer, l: *const Learning, period: []const u8) !void {
    try tpl.render(w, "<p class=\"muted\">From {games} ranked solo games in every region we crawl, {period}, where we know the player's mastery " ++
        "points on the champion at the time: their mastery, looked up after the game, when no later game on " ++
        "that champion came before the lookup. Practised players are often better players overall, so every " ++
        "champion shows a gap ({mean:.1} points on average); a champion is harder or easier to pick up only " ++
        "when its gap is clearly bigger or smaller than that, by more than chance in its games could give. " ++
        "Gold is the laner's total gold minus their lane opponent's at {minute} minutes.</p>\n", .{
        .games = root.Thousands{ .n = l.games },
        .period = period,
        .mean = l.mean_pp,
        .minute = learning.gold_minute,
    });
}

/// Champion page: results by mastery points on `ch` in `period`'s games
pub fn section(site: *const Site, w: *Writer, l: *const Learning, ch: Champ, period: html.Period) !void {
    if (l.games == 0) return;
    const c = l.get(ch.id) orelse return;
    try tpl.renderPart(w, "<h2>How hard {name} is to pick up {chip}</h2>\n<p>", .{ .name = ch.name, .chip = chip(site, period) });
    if (c.gap) |g| {
        try tpl.renderPart(w, "Players new to {name} ({new_text}) win {new:.1}%, practised ones ({practised_text}) {practised:.1}%. ", .{
            .name = ch.name,
            .new_text = new_text,
            .practised_text = practised_text,
            .new = pct(g.new.winRate()),
            .practised = pct(g.practised.winRate()),
        });
        const args = .{ .pp = g.pp, .mean = l.mean_pp };
        switch (g.kind) {
            .harder => try tpl.render(w, "That gap of {pp:.1} points is bigger than most champions' ({mean:.1} on average): expect a rough start.", args),
            .easier => try tpl.render(w, "That gap of {pp:.1} points is smaller than most champions' ({mean:.1} on average): players do nearly as well from the start.", args),
            .usual => try tpl.render(w, "That gap of {pp:.1} points is about the usual one ({mean:.1} on average).", args),
        }
    } else {
        const b = c.bins;
        var new: u32 = 0;
        var practised: u32 = 0;
        for (b[0..learning.new_bins]) |x| new += x.games;
        for (b[learning.practised_from..]) |x| practised += x.games;
        try tpl.render(w, "More data needed to say how hard {name} is to pick up: it takes 200+ games each from players new to it and practised on it ({new} and {practised} so far).", .{
            .name = ch.name,
            .new = new,
            .practised = practised,
        });
    }
    try tpl.renderPart(w,
        \\</p>
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>Mastery points on {name}</th><th class="num">Win rate</th><th class="num">Gold at {minute} vs lane</th><th class="num">Games</th></tr></thead>
        \\<tbody>
        \\
    , .{ .name = ch.name, .minute = learning.gold_minute });
    var buf: [24]u8 = undefined;
    for (c.bins, 0..) |b, i| {
        const gold = if (b.gold()) |g| tpl.t("<span title=\"{n} games with a timeline\">{sign}{g:.0}</span>", .{
            .n = b.gold_games,
            .sign = if (g >= 0) "+" else "",
            .g = g,
        }) else null;
        try tpl.render(w,
            \\<tr{thin}><td>{bin}</td><td class="num">{dash}{rate}</td><td class="num">{gold}{none}</td><td class="num">{games}</td></tr>
            \\
        , .{
            .thin = tpl.flag(b.games < l.thin_games, "class=\"thin\""),
            .bin = binLabel(&buf, i),
            .dash = tpl.when(b.games == 0, "-"),
            .rate = tpl.when(b.games > 0, tpl.call(tierlist.wrText, .{ b.winRate(), b.games })),
            .gold = gold,
            .none = tpl.when(gold == null, "-"),
            .games = root.Thousands{ .n = b.games },
        });
    }
    try w.writeAll("</tbody></table></div>\n");
    try footnote(w, l, site.periodText(period));
}

/// Every region's games (src/learning.zig), any rank
fn chip(site: *const Site, period: html.Period) root.scope.Chip {
    return site.chip(site.regionDim(.all), site.periodDim(period), .plat);
}

fn champCell(w: *Writer, site: *const Site, ch: Champ) !void {
    try site.champBox(w, ch, site.view.up());
}

fn kindText(w: *Writer, k: learning.Kind) !void {
    try w.writeAll(switch (k) {
        .harder => "<b>Harder</b>",
        .usual => "Usual",
        .easier => "<b>Easier</b>",
    });
}

/// Pool page: every champion with a gap, biggest (pulled toward the average) first
pub fn table(site: *const Site, w: *Writer, l: *const Learning) !void {
    try tpl.render(w, "<h2 id=\"pick-up\">How hard champions are to pick up {chip}</h2>\n", .{ .chip = chip(site, site.view.period) });
    var list: std.ArrayList(learning.Champion) = .empty;
    for (l.champions) |c| if (c.gap != null) try list.append(site.arena, c);
    if (list.items.len == 0) {
        try tpl.render(w,
            \\<p class="note">More data needed: no champion has 200+ games each from players new to it and practised on it yet ({games} games so far).</p>
            \\
        , .{ .games = root.Thousands{ .n = l.games } });
        return;
    }
    std.mem.sort(learning.Champion, list.items, {}, struct {
        fn f(_: void, a: learning.Champion, b: learning.Champion) bool {
            return a.gap.?.pulled > b.gap.?.pulled;
        }
    }.f);
    try tpl.renderPart(w,
        \\<p class="muted">Win rate of players new to each champion ({new_text}) and of practised ones ({practised_text}). Harder: a bigger gap between them than most champions have, so expect a rough start; easier: a smaller one.</p>
        \\<div class="tl-wrap"><table class="tl" id="pick-up-table" data-sortable>
        \\<thead><tr><th class="l" data-sort="text">Champion</th><th class="l" data-sort="num">Pick up</th><th data-sort="num">New</th><th data-sort="num">Practised</th><th data-sort="num" aria-sort="descending" title="Practised minus new, in points; sorts pulled toward the average by its games">Gap</th><th data-sort="num">Games</th></tr></thead>
        \\<tbody>
        \\
    , .{ .new_text = new_text, .practised_text = practised_text });
    for (list.items) |c| {
        const ch = matchup.champ(site, c.id) orelse continue;
        const g = c.gap.?;
        try tpl.render(w,
            \\<tr class="bx"><td class="l" data-v="{name}">{champ}</td><td class="l" data-v="{kind_v}">{kind}</td><td data-v="{new:.4}">{new_wr}</td><td data-v="{practised:.4}">{practised_wr}</td><td data-v="{pulled:.2}">{sign}{pp:.1}</td><td class="dim" data-v="{games}">{count}</td></tr>
            \\
        , .{
            .name = ch.name,
            .champ = tpl.call(champCell, .{ site, ch }),
            .kind_v = @as(u8, switch (g.kind) {
                .harder => 2,
                .usual => 1,
                .easier => 0,
            }),
            .kind = tpl.call(kindText, .{g.kind}),
            .new = g.new.winRate(),
            .new_wr = tpl.call(tierlist.wrText, .{ g.new.winRate(), g.new.games }),
            .practised = g.practised.winRate(),
            .practised_wr = tpl.call(tierlist.wrText, .{ g.practised.winRate(), g.practised.games }),
            .pulled = g.pulled,
            .sign = if (g.pp >= 0) "+" else "",
            .pp = g.pp,
            .games = g.new.games + g.practised.games,
            .count = root.Thousands{ .n = g.new.games + g.practised.games },
        });
    }
    try w.writeAll("</tbody></table></div>\n");
    try tpl.render(w, "<script src=\"{up}table.js\" defer></script>\n", .{ .up = site.view.up() });
    try footnote(w, l, site.period());
}
