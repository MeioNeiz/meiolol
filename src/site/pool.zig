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

const Writer = std.Io.Writer;
const Site = root.Site;
const Champ = root.Champ;

/// On a champion page; the pool page shows the full list
const also_shown = 6;

pub fn sourceText(p: *const pool.Pool) []const u8 {
    return switch (p.source) {
        .games => "their ranked solo games in our sample",
        .mastery => "their champion mastery",
    };
}

/// With the learning-curve table under the picker (site/learning.zig)
pub fn writePage(site: *const Site, w: *Writer, p: *const pool.Pool, l: *const learning.Learning) !void {
    const pg = site.page(
        "Champion pool | meiolol",
        "Pick the champions you main: what their players also play, which of those do well into your hard lanes, and what they play when your main is banned.",
        "pool.html",
        .pool,
    );
    try html.head(w, pg);
    try tpl.render(w,
        \\<h1>Champion pool</h1>
        \\<p class="lead">Pick the champion you main, or up to three. See what players who
        \\main them also play, which of those champions do well into your main's hard lanes,
        \\and what they play when it is banned. Several options with the numbers behind
        \\each; the choice is yours.</p>
        \\<p id="status" class="note">Loading…</p>
        \\<form id="pool" class="pool-form" autocomplete="off" onsubmit="return false">
        \\<datalist id="champions"></datalist>
        \\<label><span>Main</span><input data-main list="champions" placeholder="Champion"></label>
        \\<label><span>Also</span><input data-main list="champions" placeholder="Champion (optional)"></label>
        \\<label><span>Also</span><input data-main list="champions" placeholder="Champion (optional)"></label>
        \\</form>
        \\<div id="results" data-to-site="{up}" data-query="{query}"></div>
        \\<p class="muted">A player's main is their most played champion, from {source}
        \\({players} players so far). "×2.4" means players who main that champion play this one
        \\2.4 times as often as other players do; small groups are pulled toward ×1. Lists
        \\start at {min} players per main. Lane numbers are percentage points of win chance
        \\beyond what the two champions' own win rates predict, {in} {when}.
        \\<a href="{up}method.html">Method</a>.</p>
        \\<script src="pool.js" defer></script>
        \\
    , .{
        .up = site.view.up(),
        .query = site.view.query(),
        .source = sourceText(p),
        .players = try root.thousands(site.arena, p.players),
        .min = p.min_players,
        .in = site.view.region.in(),
        .when = site.when,
    });
    try learning_page.table(site, w, l);
    try html.foot(w, pg);
}

/// Champion page: who mains `ch` and what else they play
pub fn section(site: *const Site, w: *Writer, p: *const pool.Pool, ch: Champ) !void {
    if (p.players == 0) return;
    const m: pool.Main = for (p.mains) |m| {
        if (m.id == ch.id) break m;
    } else .{ .id = ch.id, .players = 0, .one_tricks = 0 };
    try tpl.render(w, "<h2>Players who main {name} also play</h2>\n", .{ .name = ch.name });
    if (m.players < p.min_players) {
        try tpl.render(w,
            \\<p class="note">Not enough players yet: {players} with {name} as their most played champion so far; lists start at {min}.</p>
            \\
        , .{ .players = m.players, .name = ch.name, .min = p.min_players });
        return;
    }
    try tpl.render(w,
        \\<p class="muted">{players} players main {name}, from {source}; ×2 means twice as often as other players.</p>
        \\
    , .{ .players = m.players, .name = ch.name, .source = sourceText(p) });
    try w.writeAll("<div class=\"card\"><ul class=\"also\">\n");
    if (m.also.len == 0) try w.writeAll("<li class=\"muted\">No champion stands out yet</li>\n");
    for (m.also[0..@min(m.also.len, also_shown)]) |a| {
        const other = matchup.champ(site, a.id) orelse continue;
        try tpl.render(w,
            \\<li class="bx"><span>{champ}</span><span class="num" title="{together} of {players} players">×{lift:.1}</span></li>
            \\
        , .{
            .champ = tpl.call(champCell, .{ site, other }),
            .together = a.together,
            .players = m.players,
            .lift = a.lift,
        });
    }
    try tpl.renderPart(w,
        \\</ul></div>
        \\<p><a href="../pool.html#{slug}">{name}'s pool: options for hard lanes and when it is banned</a></p>
        \\
    , .{ .slug = ch.slug, .name = ch.name });
}

fn champCell(w: *Writer, site: *const Site, other: Champ) !void {
    try site.champBox(w, other, "../");
}
