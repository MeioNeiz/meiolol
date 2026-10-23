//! The home page (index.html)

const std = @import("std");
const html = @import("html.zig");
const patch_page = @import("patch.zig");

const Writer = std.Io.Writer;
const tpl = html.tpl;

const root = @import("root.zig");
const Site = root.Site;

/// The home page: the lookup, and a game review of the example player's that steps
/// through its biggest moments (static/home.js, from data/your-example.json). Not a
/// stats page, so no region or period switches
pub fn writeIndex(site: *const Site, w: *Writer) !void {
    var p = try site.page(
        "meiolol: game review for League of Legends",
        "Look yourself up: every recent game reviewed like a chess game. Your team's win chance minute by minute, the moments that moved it, what each death cost, and your lane against the typical game at your rank. Free, no sign-up.",
        "index.html",
        .home,
    );
    p.counterparts = null;
    try html.head(w, p);
    const up = site.view.up();
    try tpl.render(w,
        \\<section class="home-top"><div>
        \\<p class="wordmark">{logo}<span>meiolol</span></p>
        \\<h1>Game review for<br>League of Legends</h1>
        \\<p class="lead">Type your Riot ID and meiolol reviews your recent games, the way
        \\chess.com reviews a chess game: your team's chance to win at every minute, the
        \\minute the game turned, what each of your deaths cost, and how your lane went
        \\against players at your rank in the same matchup.</p>
        \\<form class="search" action="{your}" method="get" role="search"{submit}>
        \\<input name="id" placeholder="Riot ID, like Name#EUW" aria-label="Riot ID, as Name#TAG" autocomplete="off" spellcheck="false" required>
        \\<button type="submit">Review my games</button>
        \\</form>
        \\<ol class="steps">
        \\<li><b>1</b><span>Enter your Riot ID</span></li>
        \\<li><b>2</b><span>We fetch your last 60 days of games from Riot</span></li>
        \\<li><b>3</b><span>Open any game for its review</span></li>
        \\</ol>
        \\<p class="sub-links"><a href="{example}">See an example review →</a><a href="{method}">How the numbers are made</a><a href="{download}">Coming: a champ select helper for Windows</a></p>
        \\<p class="fine">Free, no sign-up. Solo/duo, flex, draft and Swiftplay games. Each lane
        \\measured against ranked games in EUW on that game's patch.</p>
        \\</div>
        \\<div id="demo" class="panel demo" hidden>
        \\<div class="panel-h"><b>Example: one real game, reviewed</b><span class="live"><i></i>playing through its key moments</span></div>
        \\</div>
        \\</section>
        \\<section class="home-sec">
        \\<h2>In every review</h2>
        \\<p>Built from Riot's minute-by-minute timeline of the game. Win chance as in
        \\Platinum+ games; your lane against games in the same matchup at your rank.</p>
        \\<div class="three">
        \\<div class="panel feat"><h3><span class="badge c-turn">★</span>The turning minute</h3><p>The one minute that moved your team's win chance most, and what happened in it.</p><div class="viz" id="v-turn" hidden></div></div>
        \\<div class="panel feat"><h3><span class="badge c-cost">✕</span>What each death cost</h3><p>Who killed you, the gold they got, what the enemy took next, and the win chance it cost.</p><div class="viz" hidden><ul class="mini-list" id="v-death"></ul></div></div>
        \\<div class="panel feat"><h3><span class="badge c-gain">↑</span>Your lane against typical</h3><p>Gold, level 6 and first item against the typical game in the same matchup and rank.</p><div class="viz" hidden><ul class="mini-list" id="v-lane"></ul></div></div>
        \\</div>
        \\</section>
        \\<section class="home-sec" hidden>
        \\<h2>Your record book</h2>
        \\<p>Highlights across your recent games. These are the example player's.</p>
        \\<div class="hls" id="home-hls"></div>
        \\</section>
        \\<section class="home-sec">
        \\<h2>Between games</h2>
        \\<div class="three go">
        \\<a class="panel" href="{daily}"><span class="ic"><svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="#f5c451" stroke-width="1.6" aria-hidden="true"><rect x="2" y="3" width="14" height="13" rx="2"/><path d="M2 7h14M6 1.5v3M12 1.5v3"/></svg></span><span><b>Daily Draft</b><span>One real ranked draft a day. Guess who won.</span></span><span class="arrow">→</span></a>
        \\<a class="panel" href="{learn}"><span class="ic"><svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="#3ccf91" stroke-width="1.6" aria-hidden="true"><path d="M2 4.5 9 2l7 2.5L9 7z"/><path d="M5 6v4.5c0 1.4 1.8 2.5 4 2.5s4-1.1 4-2.5V6"/></svg></span><span><b>Learn the draft</b><span>Five short lessons, then practice drafts.</span></span><span class="arrow">→</span></a>
        \\<a class="panel" href="champions.html"><span class="ic"><svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="#6aa1ff" stroke-width="1.6" aria-hidden="true"><path d="M3 15V9M7 15V4M11 15V7M15 15V2"/></svg></span><span><b>Champions</b><span>Win rates, matchups and lane curves.</span></span><span class="arrow">→</span></a>
        \\</div>
        \\{patch_day}</section>
        \\<script src="{review_js}" defer></script>
        \\<script src="{home_js}" data-root="{up}" defer></script>
        \\
    , .{
        .your = html.Link{ .root = up, .path = "your.html" },
        .submit = tpl.trusted(html.lookup_submit),
        .logo = tpl.trusted(html.logo),
        .example = html.Link{ .root = up, .path = "your.html#example" },
        .method = html.Link{ .root = up, .path = "method.html" },
        .download = html.Link{ .root = up, .path = "download.html" },
        .daily = html.Link{ .root = up, .path = "daily.html" },
        .learn = html.Link{ .root = up, .path = "learn.html" },
        .patch_day = tpl.when(site.opts.prev_patch != null, tpl.t(
            \\<p class="muted">New patch: <a href="{href}">what changed in {cur} since {prev}</a>.</p>
            \\
        , .{ .href = html.Link{ .root = up, .path = "patch/" ++ patch_page.path }, .cur = site.patch, .prev = site.opts.prev_patch orelse "" })),
        .review_js = html.Link{ .root = up, .path = "review.js" },
        .home_js = html.Link{ .root = up, .path = "home.js" },
        .up = up,
    });
    try html.foot(w, p);
}
