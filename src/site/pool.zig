//! Pool on the site: the pool.html skeleton that static/pool.js fills from
//! data/pool.json (src/pool.zig), and the "also play" section of each champion page.
//! Several options with their numbers and n, never "the best pick" (docs/concept.md).

const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const matchup = @import("matchup.zig");
const pool = @import("../pool.zig");
const learning = @import("../learning.zig");
const learning_page = @import("learning.zig");
const scope = @import("scope.zig");

const Writer = std.Io.Writer;
const Site = root.Site;
const Champ = root.Champ;

/// On a champion page; the pool page shows the full list
const also_shown = 6;

/// A pool's period as a scope chip: games over every patch, or lifetime mastery
pub fn periodDim(p: *const pool.Pool) scope.Dim {
    return switch (p.source) {
        .games => .every_patch,
        .mastery => .{ .key = "every", .text = "All time" },
    };
}

pub fn sourceText(p: *const pool.Pool) []const u8 {
    return switch (p.source) {
        .games => "their ranked solo games in our sample, every patch",
        .mastery => "their champion mastery, all time",
    };
}

/// With the learning-curve table under the picker (site/learning.zig)
pub fn writePage(site: *const Site, w: *Writer, p: *const pool.Pool, l: *const learning.Learning) !void {
    const pg = try site.page(
        "Champion pool | meiolol",
        "Pick the champions you main: what their players also play, how hard each champion is to pick up, and which do well where your main struggles.",
        "pool.html",
        .pool,
    );
    try html.head(w, pg);
    try tpl.render(w,
        \\<h1>Champion pool</h1>
        \\<p class="lead">Looking for a second champion? Pick the one you main, or up to
        \\three: see what else their players play, how hard each is to pick up, and which do
        \\well where your main struggles or when it is banned. Several options with the
        \\numbers behind each; the choice is yours. <a href="#pick-up">How hard every
        \\champion is to pick up</a>.</p>
        \\<p id="status" class="note">Loading…</p>
        \\<form id="pool" class="pool-form" autocomplete="off" onsubmit="return false">
        \\<datalist id="champions"></datalist>
        \\<label><span>Main</span><input data-main list="champions" placeholder="Champion"></label>
        \\<label><span>Also</span><input data-main list="champions" placeholder="Champion (optional)"></label>
        \\<label><span>Also</span><input data-main list="champions" placeholder="Champion (optional)"></label>
        \\</form>
        \\<div id="results" data-to-site="{up}" data-query="{query}"></div>
        \\<p class="muted">{chip} A player's main is their most played champion, from {source}
        \\({players} players {in} so far); they play another when it has at least a tenth of their
        \\main's games or points. "59% (28%)": 59% of the main's players play it, 28% of other players do.
        \\Listed are those played most beyond their usual share (small groups count for less),
        \\from {min} players per main. Lane numbers are points of win chance beyond what the two
        \\champions' own win rates predict, {in} {when}, shown from 1 point either way (most
        \\matchups are closer to even).
        \\<a href="{up}method.html">Method</a>.</p>
        \\<script src="pool.js" defer></script>
        \\
    , .{
        .chip = site.chip(site.regionDim(site.view.region), periodDim(p), .plat),
        .up = site.view.up(),
        .query = site.view.query(),
        .source = sourceText(p),
        .players = root.Thousands{ .n = p.players },
        .min = p.min_players,
        .in = site.view.region.in(),
        .when = site.when,
    });
    try learning_page.table(site, w, l);
    try html.foot(w, pg);
}

/// Champion page: who mains `ch` in `region` and what else they play; `l` marks those
/// harder or easier to pick up
pub fn section(site: *const Site, w: *Writer, p: *const pool.Pool, l: *const learning.Learning, ch: Champ, region: html.Region) !void {
    if (p.players == 0) return;
    const m: pool.Main = for (p.mains) |m| {
        if (m.id == ch.id) break m;
    } else .{ .id = ch.id, .players = 0, .one_tricks = 0 };
    try tpl.render(w, "<h2>Players who main {name} also play {chip}</h2>\n", .{
        .name = ch.name,
        .chip = site.chip(site.regionDim(region), periodDim(p), .plat),
    });
    if (m.players < p.min_players) {
        try tpl.render(w,
            \\<p class="note">Not enough players yet: {players} {in} with {name} as their most played champion so far; lists start at {min}.</p>
            \\
        , .{ .players = m.players, .in = region.in(), .name = ch.name, .min = p.min_players });
        return;
    }
    try tpl.render(w,
        \\<p class="muted">{players} players {in} main {name}, from {source}: the share of them who play each champion (of other players in brackets), those played most beyond their usual share first.</p>
        \\
    , .{ .players = m.players, .in = region.in(), .name = ch.name, .source = sourceText(p) });
    try w.writeAll("<div class=\"card\"><ul class=\"also\">\n");
    if (m.also.len == 0) try w.writeAll("<li class=\"muted\">No champion stands out yet</li>\n");
    for (m.also[0..@min(m.also.len, also_shown)]) |a| {
        const other = matchup.champ(site, a.id) orelse continue;
        try tpl.render(w,
            \\<li class="bx"><span>{champ}</span><span class="num" title="{together} of {players} players">{share:.0}% <span class="muted">({base:.0}%)</span>{kind}</span></li>
            \\
        , .{
            .champ = tpl.call(champCell, .{ site, other }),
            .together = a.together,
            .players = m.players,
            .share = 100 * @as(f64, @floatFromInt(a.together)) / @as(f64, @floatFromInt(m.players)),
            .base = 100 * a.base,
            .kind = if (kindNote(l, a.id)) |k| tpl.t(" <span class=\"role\">{k}</span>", .{ .k = k }) else null,
        });
    }
    try tpl.renderPart(w,
        \\</ul></div>
        \\<p><a href="../pool.html#{slug}">{name}'s pool: options for its hard lanes and when it is banned</a></p>
        \\
    , .{ .slug = ch.slug, .name = ch.name });
}

/// "harder to pick up" when the champion's gap stands out (learning.zig)
fn kindNote(l: *const learning.Learning, id: u32) ?[]const u8 {
    const g = (l.get(id) orelse return null).gap orelse return null;
    return switch (g.kind) {
        .harder => "harder to pick up",
        .easier => "easier to pick up",
        .usual => null,
    };
}

fn champCell(w: *Writer, site: *const Site, other: Champ) !void {
    try site.champBox(w, other, "../");
}
