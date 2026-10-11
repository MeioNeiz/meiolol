//! Fixed text pages. Wording follows docs/production-key.md and docs/concept.md
//! ("Application wording"): champion and aggregate data, facts not advice, never a
//! single "best pick"; no other players' names; no auto actions.

const std = @import("std");
const Writer = std.Io.Writer;
const html = @import("html.zig");
const esc = html.esc;

pub const Info = struct {
    contact: []const u8,
    /// "11 October 2026"
    updated: []const u8,
};

pub fn method(w: *Writer, info: Info) Writer.Error!void {
    _ = info;
    try w.writeAll(
        \\<div class="prose">
        \\<h1>Method</h1>
        \\<p class="lead">meiolol helps players understand how lane matchups unfold and compare
        \\their own lane with the typical curve. Everything here is champion and aggregate
        \\data from ranked games. It never shows other players and never names a "best
        \\pick".</p>
        \\<h2>The data</h2>
        \\<ul>
        \\<li>Ranked Solo/Duo games collected through the official Riot Games API, players
        \\chosen at random from every rank tier rather than only the top of the ladder.</li>
        \\<li>Only complete games: no remakes, a winner, all ten positions known.</li>
        \\<li>Each game's match timeline: every player's gold, experience and CS once a
        \\minute, plus kills, level ups and item purchases. Timelines are stored once per
        \\match, compactly, and never fetched twice.</li>
        \\<li>Grouped per patch and updated daily. Nothing identifying a player is
        \\published.</li>
        \\</ul>
        \\<h2>Lane curves</h2>
        \\<ul>
        \\<li><b>Matchup</b>: the two players in the same position on opposite teams (top
        \\against top, and so on).</li>
        \\<li><b>Curves</b>: for each minute from 1 to 25, the difference between the two in
        \\gold, experience and CS (lane minions plus jungle monsters). The line is the median
        \\game; the band is the middle half of games (25th to 75th percentile), so you see
        \\how much games vary, not only the typical one.</li>
        \\<li><b>Games still going</b>: later minutes count only games that lasted that long,
        \\which tilts them toward closer games. Charts stop when fewer than 10 games
        \\remain.</li>
        \\<li><b>Leads at 14 minutes</b>: who is ahead in gold at 14 minutes, and how often
        \\each side then wins the game. Winning lane and winning the game often
        \\disagree.</li>
        \\<li><b>Kills</b>: the share of games where each laner took part in killing the
        \\other, before 6 minutes, from 6 to 14 and after 14.</li>
        \\<li><b>Timings</b>: median time to level 6 and to the first finished item (2,200
        \\gold or more, building into nothing, boots excluded).</li>
        \\<li><b>Rank</b>: the median visible rank tier of the game's players when the game
        \\was collected, in three brackets (Iron to Silver, Gold to Emerald, Diamond and
        \\above). Never hidden matchmaking rating.</li>
        \\<li><b>Sample size</b>: every chart states patch, rank and the number of games. A
        \\matchup needs 20 games for a page, and anything under 200 games is greyed out as
        \\"more data needed": thin curves still move as games come in.</li>
        \\</ul>
        \\<h2>Champion statistics</h2>
        \\<ul>
        \\<li><b>Win, pick and ban rate</b>: games won with the champion in that role, share
        \\of games with it in that role, share of games where it was banned.</li>
        \\<li><b>Lane opponents and teammates</b>: how much better or worse a pairing does
        \\than the two champions' own win rates predict, in percentage points. Pairs with
        \\few games are pulled toward zero until the data supports them.</li>
        \\</ul>
        \\<h2>Daily Draft</h2>
        \\<p>One complete ranked game a day, the same for everyone, with every player
        \\identity removed: no names, Riot IDs, match ids or dates. One champion is hidden
        \\among four that were plausible in that draft; the reveal shows what was played,
        \\who won and what this patch's numbers say about the lanes. It describes the game,
        \\it does not grade the pick.</p>
        \\<h2>What meiolol never does</h2>
        \\<ul>
        \\<li>Show other players' names, accounts or statistics.</li>
        \\<li>Pick, ban, lock or dodge for anyone, or name a single "best" champion.</li>
        \\<li>Infer hidden ranks or matchmaking rating.</li>
        \\</ul>
        \\</div>
        \\
    );
}

pub fn download(w: *Writer, info: Info) Writer.Error!void {
    _ = info;
    try w.writeAll(
        \\<div class="prose">
        \\<h1>Desktop app</h1>
        \\<p class="lead">In development: a small Windows app that, once you have picked
        \\your champion in champ select, shows how your lane matchup usually unfolds and
        \\your own record in it.</p>
        \\<ul>
        \\<li>Windows 10 and 11. Free.</li>
        \\<li>Reads champ select from the League client on your PC (the client's local
        \\interface), read-only. Nothing about your games leaves your computer.</li>
        \\<li>The likely lane opponent is labelled as a guess, since enemy roles are hidden
        \\in champ select. Where it shows champions from your pool, it lists several with
        \\their reasons, never one.</li>
        \\<li>Never picks, bans, locks or dodges for you, and never shows other players'
        \\names or statistics.</li>
        \\</ul>
        \\<p class="note">Not released yet. Meanwhile the <a href="matchup/index.html">matchup
        \\curves</a> on this site show the same lane data.</p>
        \\</div>
        \\
    );
}

pub fn privacy(w: *Writer, info: Info) Writer.Error!void {
    try w.print(
        \\<div class="prose">
        \\<h1>Privacy policy</h1>
        \\<p class="muted">Last updated {s}.</p>
        \\<h2>This website</h2>
        \\<p>No accounts, no cookies, no analytics or advertising trackers. The hosting
        \\provider keeps standard request logs (IP address, time, page) for security and
        \\abuse prevention, for a limited time. The Daily Draft keeps your guesses, streak
        \\and archive in your own browser (local storage); they are never sent to us, and
        \\clearing site data removes them.</p>
        \\<p>Daily Draft puzzles are real ranked games with every player identity removed:
        \\no names, Riot IDs, match ids or game dates, only champions, bans, patch, an
        \\approximate rank tier and team totals.</p>
        \\<h2>Your games</h2>
        \\<p>When you enter a Riot ID on <a href="your.html">Your games</a>, we ask the Riot
        \\Games API for that player's recent ranked games and show their own lane against
        \\the typical curve for each matchup. Anyone can look up any Riot ID, as on other
        \\League statistics sites (legal basis: legitimate interests). The page shows only
        \\that player's games: their champion, their lane opponent's champion and the
        \\numbers, never other players' names.</p>
        \\<p>For each player looked up we store the Riot ID, Riot's encrypted player
        \\identifier, server, visible rank, and the games we fetched: champions, positions,
        \\results and per-minute statistics, with no names; the other players in those games
        \\are kept only as one-way hashes of their identifiers. A player nobody has looked up
        \\for 30 days is deleted. We don't record who looked up whom, and lookups are not in
        \\our server logs.</p>
        \\<p>To remove your games and stop us collecting them again, use "Remove a Riot ID"
        \\on the Your games page. You prove the account is yours by setting a given free
        \\profile icon in the League client for a minute; we then delete everything about
        \\you, and keep only your encrypted identifier on a "do not collect" list so we
        \\never fetch your games again.</p>
        \\<h2>The desktop app</h2>
        \\<p>The app reads champ select from the League client running on your own PC and
        \\shows lane information on screen. It does not send your games, account or any other
        \\personal data anywhere. It downloads updated champion statistics from this
        \\site.</p>
        \\<h2>Game data from Riot Games</h2>
        \\<p>The statistics are computed from ranked match data provided by the Riot Games
        \\API. Raw match records, which include Riot's per-application encrypted player
        \\identifiers, are stored privately and used only to compute and improve
        \\champion level and aggregate statistics. Nothing identifying a player is
        \\published. Deletion requests passed on by Riot Games are honoured, and you can ask
        \\us directly to delete any data about your account.</p>
        \\<h2>Contact</h2>
        \\<p>Questions or requests: <a href="mailto:{f}">{f}</a>.</p>
        \\</div>
        \\
    , .{ info.updated, esc(info.contact), esc(info.contact) });
}

pub fn terms(w: *Writer, info: Info) Writer.Error!void {
    try w.print(
        \\<div class="prose">
        \\<h1>Terms of use</h1>
        \\<p class="muted">Last updated {s}.</p>
        \\<ul>
        \\<li>meiolol (this site and the desktop app) is free to use. Its statistics are
        \\estimates from past games and come with no guarantee.</li>
        \\<li>You remain bound by Riot Games' Terms of Service when you play. meiolol only
        \\shows information; it never acts in the game client for you.</li>
        \\<li>Do not scrape the site at a rate that disrupts it or resell its data.</li>
        \\<li>The software is provided as is, without warranty of any kind.</li>
        \\<li>These terms may change; the date above shows the latest version.</li>
        \\</ul>
        \\<p>{s}</p>
        \\<p>Contact: <a href="mailto:{f}">{f}</a>.</p>
        \\</div>
        \\
    , .{ info.updated, html.boilerplate, esc(info.contact), esc(info.contact) });
}
