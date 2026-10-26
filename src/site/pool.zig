//! Pool on the site: the pool.html skeleton that static/pool.js fills from
//! data/pool.json (src/pool.zig), and the "also play" section of each champion page.
//! Several options with their numbers and n, never "the best pick" (docs/concept.md).

const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const pool = @import("../pool.zig");
const learning = @import("../learning.zig");
const learning_page = @import("learning.zig");
const scope = @import("scope.zig");

const Writer = std.Io.Writer;
const Site = root.Site;

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
