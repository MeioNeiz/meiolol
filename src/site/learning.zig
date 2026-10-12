//! Learning curves on the site (src/learning.zig): a section on each champion page and
//! a table of how long champions take to learn on the pool page. n on every row; thin
//! rows greyed out as "more data needed".

const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const matchup = @import("matchup.zig");
const learning = @import("../learning.zig");

const Writer = std.Io.Writer;
const Site = root.Site;
const Champ = root.Champ;
const Learning = learning.Learning;
const esc = html.esc;

/// "1-5", "6-20", "51+"
fn binLabel(buf: []u8, i: usize) []const u8 {
    const lo = learning.bins[i];
    if (i + 1 == learning.bin_count) return std.fmt.bufPrint(buf, "{d}+", .{lo}) catch "";
    return std.fmt.bufPrint(buf, "{d}-{d}", .{ lo, learning.bins[i + 1] - 1 }) catch "";
}

fn pct(x: f64) f64 {
    return 100 * x;
}

const footnote =
    "<p class=\"muted\">From the ranked histories of {d} players in our data. A game's " ++
    "number counts only the games we have, so early rows include some players coming " ++
    "back to a champion: the real gap is, if anything, bigger. Gold is the laner's total " ++
    "gold minus their lane opponent's at {d} minutes.</p>\n";

/// Champion page: results by games on `ch`
pub fn section(w: *Writer, l: *const Learning, ch: Champ) !void {
    if (l.players == 0) return;
    const c = l.get(ch.id) orelse return;
    var buf: [16]u8 = undefined;
    try w.print("<h2>How long {f} takes to learn</h2>\n<p>", .{esc(ch.name)});
    if (c.reach) |r| {
        if (r == 0) {
            try w.print("Players do about as well on {f} from their first games as later ({d:.1}% usual win rate).", .{ esc(ch.name), pct(c.usual) });
        } else {
            try w.print("Players reach {f}'s usual win rate ({d:.1}%) around their games {s} on it.", .{ esc(ch.name), pct(c.usual), binLabel(&buf, r) });
        }
    } else {
        try w.print("More data needed to say when players reach {f}'s usual win rate: every row needs 400+ games.", .{esc(ch.name)});
    }
    try w.print(
        \\</p>
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>Games on {f}</th><th class="num">Win rate</th><th class="num">Gold at {d} vs lane</th><th class="num">Games</th></tr></thead>
        \\<tbody>
        \\
    , .{ esc(ch.name), learning.gold_minute });
    for (c.bins, 0..) |b, i| {
        try w.print("<tr{s}><td>{s}</td><td class=\"num\">", .{
            if (b.games < l.thin_games) " class=\"thin\"" else "", binLabel(&buf, i),
        });
        if (b.games == 0) try w.writeAll("-") else try w.print("{d:.1}%", .{pct(b.winRate())});
        try w.writeAll("</td><td class=\"num\">");
        if (b.gold()) |g| {
            try w.print("<span title=\"{d} games with a timeline\">{s}{d:.0}</span>", .{ b.gold_games, if (g >= 0) "+" else "", g });
        } else try w.writeAll("-");
        try w.print("</td><td class=\"num\">{d}</td></tr>\n", .{b.games});
    }
    try w.writeAll("</tbody></table></div>\n");
    try w.print(footnote, .{ l.players, learning.gold_minute });
}

/// Pool page: champions with a learning point, quickest first
pub fn table(site: *const Site, w: *Writer, l: *const Learning) !void {
    try w.writeAll("<h2>How long champions take to learn</h2>\n");
    var list: std.ArrayList(learning.Champion) = .empty;
    for (l.champions) |c| if (c.reach != null) try list.append(site.arena, c);
    if (list.items.len == 0) {
        try w.print(
            "<p class=\"note\">More data needed: no champion has 400+ games in every range of games played on it yet ({d} players' histories so far).</p>\n",
            .{l.players},
        );
        return;
    }
    std.mem.sort(learning.Champion, list.items, {}, struct {
        fn f(_: void, a: learning.Champion, b: learning.Champion) bool {
            if (a.reach.? != b.reach.?) return a.reach.? < b.reach.?;
            return a.bins[0].winRate() - a.usual > b.bins[0].winRate() - b.usual;
        }
    }.f);
    var buf: [16]u8 = undefined;
    try w.writeAll(
        \\<p class="muted">When players reach a champion's usual win rate, by their games on
        \\it. Several champions can sit in the same range; within one, the smaller first-games
        \\gap comes first.</p>
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>Champion</th><th>Usual win rate by games</th><th class="num">First 5 games</th><th class="num">Usual</th><th class="num">Games</th></tr></thead>
        \\<tbody>
        \\
    );
    for (list.items) |c| {
        const ch = matchup.champ(site, c.id) orelse continue;
        try w.writeAll("<tr><td>");
        try site.champLink(w, ch, site.view.up());
        var games: u32 = 0;
        for (c.bins) |b| games += b.games;
        try w.print("</td><td>{s}</td><td class=\"num\">{d:.1}%</td><td class=\"num\">{d:.1}%</td><td class=\"num\">{d}</td></tr>\n", .{
            if (c.reach.? == 0) "from the start" else binLabel(&buf, c.reach.?),
            pct(c.bins[0].winRate()),
            pct(c.usual),
            games,
        });
    }
    try w.writeAll("</tbody></table></div>\n");
    try w.print(footnote, .{ l.players, learning.gold_minute });
}
