//! Fixed text pages. Wording follows docs/production-key.md: several options with
//! reasons, never a single forced pick; no other players' names; no auto actions.

const std = @import("std");
const Writer = std.Io.Writer;
const html = @import("html.zig");
const esc = html.esc;

pub const Info = struct {
    contact: []const u8,
    /// "11 October 2026"
    updated: []const u8,
};

pub fn about(w: *Writer, info: Info) Writer.Error!void {
    _ = info;
    try w.writeAll(
        \\<div class="prose">
        \\<h1>How it works</h1>
        \\<p class="lead">meiolol helps ranked players learn draft. It highlights the pick
        \\decisions that matter and offers several options, each with the reasons behind it.
        \\It never picks for you.</p>
        \\<h2>The data</h2>
        \\<ul>
        \\<li>Ranked Solo/Duo games on EUW, collected through the official Riot Games API,
        \\from every rank tier, players chosen at random rather than only the top of the
        \\ladder.</li>
        \\<li>Only complete games: no remakes, all ten positions known.</li>
        \\<li>Counted per patch, updated daily. Only champion level statistics are ever
        \\published: no player names, accounts or match histories.</li>
        \\</ul>
        \\<h2>The numbers</h2>
        \\<ul>
        \\<li><b>Win rate</b>: games won with the champion in that role.</li>
        \\<li><b>Pick rate</b>: share of games with the champion in that role.</li>
        \\<li><b>Ban rate</b>: share of games where the champion was banned.</li>
        \\<li><b>Tier</b>: from the win rate pulled toward 50% for champions with few games,
        \\so a lucky handful of games cannot make a champion S tier.</li>
        \\<li><b>Matchup and duo edges</b>: how much better (or worse) a pairing does than
        \\the two champions' own win rates predict, in percentage points. Pairs with few
        \\games stay close to zero until the data supports them.</li>
        \\</ul>
        \\<h2>The draft helper and desktop app</h2>
        \\<p>Both add up the same edges for the champions already picked and banned and list
        \\three to five options for your role, with the reasons for each: counters, synergy
        \\with your team and how the champion is doing this patch. You choose.</p>
        \\<ul>
        \\<li>No automatic picking, banning, locking or dodging.</li>
        \\<li>The desktop app reads champ select from the League client on your own PC, and
        \\only champions, roles and timers. It never shows other players' names or
        \\statistics.</li>
        \\<li>Options favour variety: several viable picks rather than one "best" champion.</li>
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
        \\<p class="lead">The meiolol app sits next to the League client during champ select
        \\and updates its options as picks and bans come in.</p>
        \\<ul>
        \\<li>Windows 10 and 11. Free.</li>
        \\<li>Reads champ select from the League client on your PC (the client's local
        \\interface). Nothing about your games leaves your computer.</li>
        \\<li>Shows three to five options for your role with the reasons behind each, using
        \\the same statistics as this site.</li>
        \\<li>Never picks, bans, locks or dodges for you, and never shows other players'
        \\names or statistics.</li>
        \\</ul>
        \\<p class="note">The first public release is in preparation. Until then, try the
        \\<a href="draft.html">draft helper</a> in your browser: it uses the same
        \\suggestions.</p>
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
        \\abuse prevention, for a limited time.</p>
        \\<h2>The desktop app</h2>
        \\<p>The app reads champ select from the League client running on your own PC and
        \\shows suggestions on screen. It does not send your games, account or any other
        \\personal data anywhere. It downloads updated champion statistics from this
        \\site.</p>
        \\<h2>Game data from Riot Games</h2>
        \\<p>The statistics are computed from ranked match data provided by the Riot Games
        \\API. Raw match records, which include Riot's per-application encrypted player
        \\identifiers, are stored privately and used only to compute and improve
        \\champion level statistics and suggestion models. Nothing identifying a player is
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
        \\<li>meiolol (this site and the desktop app) is free to use. Statistics and
        \\suggestions are estimates from past games and come with no guarantee.</li>
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
