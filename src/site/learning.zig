//! Learning curves on the site (src/learning.zig): a section on each champion page and
//! a table of how long champions take to learn on the pool page. n on every row; thin
//! rows greyed out as "more data needed".

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

/// "1-5", "6-20", "51+"
fn binLabel(buf: []u8, i: usize) []const u8 {
    const lo = learning.bins[i];
    if (i + 1 == learning.bin_count) return std.mem.print(buf, "{d}+", .{lo}) catch "";
    return std.mem.print(buf, "{d}-{d}", .{ lo, learning.bins[i + 1] - 1 }) catch "";
}

fn pct(x: f64) f64 {
    return 100 * x;
}

fn footnote(w: *Writer, players: u32) !void {
    try tpl.render(w, "<p class=\"muted\">From the ranked histories of {players} players in our data. A game's " ++
        "number counts only the games we have, so early rows include some players coming " ++
        "back to a champion: the real gap is, if anything, bigger. Gold is the laner's total " ++
        "gold minus their lane opponent's at {minute} minutes.</p>\n", .{ .players = players, .minute = learning.gold_minute });
}

/// Champion page: results by games on `ch`
pub fn section(w: *Writer, l: *const Learning, ch: Champ) !void {
    if (l.players == 0) return;
    const c = l.get(ch.id) orelse return;
    var buf: [16]u8 = undefined;
    try tpl.renderPart(w, "<h2>How long {name} takes to learn</h2>\n<p>", .{ .name = ch.name });
    if (c.reach) |r| {
        if (r == 0) {
            try tpl.render(w, "Players do about as well on {name} from their first games as later ({usual:.1}% usual win rate).", .{
                .name = ch.name,
                .usual = pct(c.usual),
            });
        } else {
            try tpl.render(w, "Players reach {name}'s usual win rate ({usual:.1}%) around their games {bin} on it.", .{
                .name = ch.name,
                .usual = pct(c.usual),
                .bin = binLabel(&buf, r),
            });
        }
    } else {
        try tpl.render(w, "More data needed to say when players reach {name}'s usual win rate: every row needs 400+ games.", .{
            .name = ch.name,
        });
    }
    try tpl.renderPart(w,
        \\</p>
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>Games on {name}</th><th class="num">Win rate</th><th class="num">Gold at {minute} vs lane</th><th class="num">Games</th></tr></thead>
        \\<tbody>
        \\
    , .{ .name = ch.name, .minute = learning.gold_minute });
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
            .games = b.games,
        });
    }
    try w.writeAll("</tbody></table></div>\n");
    try footnote(w, l.players);
}

fn champCell(w: *Writer, site: *const Site, ch: Champ) !void {
    try site.champBox(w, ch, site.view.up());
}

/// Pool page: champions with a learning point, quickest first
pub fn table(site: *const Site, w: *Writer, l: *const Learning) !void {
    try w.writeAll("<h2>How long champions take to learn</h2>\n");
    var list: std.ArrayList(learning.Champion) = .empty;
    for (l.champions) |c| if (c.reach != null) try list.append(site.arena, c);
    if (list.items.len == 0) {
        try tpl.render(w,
            \\<p class="note">More data needed: no champion has 400+ games in every range of games played on it yet ({players} players' histories so far).</p>
            \\
        , .{ .players = l.players });
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
        var games: u32 = 0;
        for (c.bins) |b| games += b.games;
        try tpl.render(w,
            \\<tr class="bx"><td>{champ}</td><td>{reach}</td><td class="num">{first}</td><td class="num">{usual}</td><td class="num">{games}</td></tr>
            \\
        , .{
            .champ = tpl.call(champCell, .{ site, ch }),
            .reach = if (c.reach.? == 0) "from the start" else binLabel(&buf, c.reach.?),
            .first = tpl.call(tierlist.wrText, .{ c.bins[0].winRate(), c.bins[0].games }),
            .usual = tpl.call(tierlist.wrText, .{ c.usual, games }),
            .games = games,
        });
    }
    try w.writeAll("</tbody></table></div>\n");
    try footnote(w, l.players);
}
