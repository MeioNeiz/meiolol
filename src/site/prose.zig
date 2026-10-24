//! Fixed text pages. Wording follows docs/production-key.md and docs/concept.md
//! ("Application wording"): champion and aggregate data, facts not advice, never a
//! single "best pick"; no other players' names in champ select; no auto actions.

const std = @import("std");
const Writer = std.Io.Writer;
const html = @import("html.zig");
const tpl = html.tpl;
const core = @import("core");
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const Role = core.Role;
const roleName = @import("root.zig").roleName;
const lean = @import("../lean.zig");

pub const Info = struct {
    contact: []const u8,
    /// "11 October 2026"
    updated: []const u8,
    /// For the method page's "games to stabilise" table
    curves: ?*const Curves = null,
    /// The shared view's, for Daily Draft: "16.21"
    patch: []const u8 = "",
};

/// k by role and minute, every bracket: how many games a matchup needs before its own
/// average counts as much as the champions' baseline
fn gamesToStabilise(w: *Writer, c: *const Curves) Writer.Error!void {
    const shown = [_]usize{ 5, 10, 14, 20 };
    try tpl.renderPart(w,
        \\<h3>Games to stabilise</h3>
        \\<p>k by role and minute, every rank bracket together, from the {games} games with
        \\a timeline in the biggest view (every region, last 30 days). Under k
        \\games a matchup's line is mostly its champions' baseline. "Gold at 14" is the
        \\gold difference at 14 minutes.</p>
        \\<div class="table-scroll"><table>
        \\<thead><tr><th>Role</th>
    , .{ .games = c.games });
    for (shown) |m| try tpl.render(w, "<th class=\"num\">Gold at {m}</th>", .{ .m = m });
    try w.writeAll("<th class=\"num\">XP at 14</th><th class=\"num\">CS at 14</th></tr></thead>\n<tbody>\n");
    for (Role.all) |r| {
        try tpl.renderPart(w, "<tr><td>{role}</td>", .{ .role = roleName(r) });
        for (shown) |m| try kCell(w, c.param(r, .all, false, .gold, m - 1));
        try kCell(w, c.param(r, .all, false, .xp, 13));
        try kCell(w, c.param(r, .all, false, .cs, 13));
        try w.writeAll("</tr>\n");
    }
    try tpl.renderPart(w,
        \\</tbody></table></div>
        \\<p class="muted">k is capped at {max}: true matchup differences are never assumed to be zero.</p>
        \\
    , .{ .max = curvesfile.curvefit.max_k });
}

fn kCell(w: *Writer, p: curvesfile.curvefit.Param) Writer.Error!void {
    if (p.tau2 == 0) return w.writeAll("<td class=\"num\">-</td>");
    try tpl.render(w, "<td class=\"num\">{k:.0}</td>", .{ .k = p.k() });
}

pub fn method(w: *Writer, info: Info) Writer.Error!void {
    try w.writeAll(
        \\<div class="prose">
        \\<h1>Method</h1>
        \\<p class="lead">meiolol helps players understand how lane matchups unfold and compare
        \\their own lane with the typical curve. The statistics are champion and aggregate
        \\data from ranked games, and it never names a "best pick".</p>
        \\<div class="note"><b>In short</b>
        \\<ul>
        \\<li>Ranked solo/duo games from Riot's official API, of players picked at random
        \\from Platinum IV and above in every region.</li>
        \\<li>Each page says its region, period (last 30 days or this patch) and number of
        \\games.</li>
        \\<li>Win rates are plain shares of games won, fainter when games are few.</li>
        \\<li>A matchup with few games leans on how its two champions usually do, and moves
        \\toward its own games as they come in.</li>
        \\</ul></div>
        \\<h2>The data</h2>
        \\<ul>
        \\<li>Ranked Solo/Duo games collected through the official Riot Games API, from
        \\players chosen at random from Platinum IV and above on the ladder, in every
        \\region. Their teammates and opponents are matched to them, so nearly every player
        \\is Platinum or higher: these are the "Platinum+ games" the pages count.</li>
        \\<li>Only complete games: no remakes, a winner, all ten positions known.</li>
        \\<li>Each game's match timeline: every player's gold, experience and CS once a
        \\minute, plus kills, level ups and item purchases. Timelines are stored once per
        \\match, compactly, and never fetched twice.</li>
        \\<li>Grouped per patch and updated daily. Nothing identifying a player is
        \\published.</li>
        \\<li><b>Game counts</b> differ between pages for three reasons. The view: EUW or
        \\every region, the last 30 days or this patch (pages without a switch, like this
        \\one, count EUW's current patch). Lane curves need the game's full match timeline,
        \\so a matchup's curves count slightly fewer games than its win rate. And pages are
        \\refreshed at different times, so one can be a few hours behind another.</li>
        \\</ul>
        \\<h2>Lane curves</h2>
        \\<ul>
        \\<li><b>Matchup</b>: the two players in the same position on opposite teams (top
        \\against top, and so on).</li>
        \\<li><b>Curves</b>: for each minute from 1 to 25, the difference between the two in
        \\gold, experience and CS (lane minions plus jungle monsters). The line is the
        \\estimated average difference (below); the band is the middle half of games (25th
        \\to 75th percentile), so you see how much games vary, not only the typical one.
        \\Under 200 games the band is the middle half of every lane in that role, drawn
        \\around the line, and says so.</li>
        \\<li><b>The estimate</b>: a matchup with few games is mostly noise, so its line
        \\starts from the champions' baseline: how each of the two does against everyone in
        \\that role, fitted together so that A against B starts at A's usual lead minus B's.
        \\The matchup's own games then pull it away from the baseline: with n games, its own
        \\average gets the weight n / (n + k). k, the "games to stabilise", is the
        \\game-to-game variance divided by how much true matchups differ from their
        \\baselines, both measured from the games at every update (table below). A rank
        \\bracket, or games by experienced players, start from the line of every game
        \\in the same way. Finally each line is smoothed across minutes, with a strength
        \\chosen by fitting on half of the games and checking against the other half.</li>
        \\<li><b>Spread</b>: after an average, "8 games in 10" is where single games end up,
        \\the 10th to 90th percentile of this matchup's games (the role's spread around
        \\the line while it has few of its own); the band is the middle half. In tables,
        \\colour says who is ahead on average and fades with fewer games, full from 200.</li>
        \\<li><b>Verdict</b>: the line above a gold chart says ahead or behind only while the
        \\estimate is clear of noise (more than two standard errors from 0) and at least 200
        \\gold at 14 minutes, else about even; "whoever is ahead wins" counts both sides'
        \\games led at 14 minutes. Greyed-out curves get none.</li>
        \\<li><b>Games still going</b>: surrender opens at 15 minutes, so before it nearly
        \\every game is still running. Right of the dotted line at 15 minutes a curve counts
        \\only games still going, which tilts it toward closer games; each chart says what
        \\share had ended by 20 and 25 minutes. Charts stop when fewer than 10 games
        \\remain.</li>
        \\<li><b>Leads at 14 minutes</b>: who is ahead in gold at 14 minutes, and how often
        \\each side then wins the game. Winning lane and winning the game often
        \\disagree.</li>
        \\<li><b>Kills</b>: the share of games where each laner took part in killing the
        \\other, before 6 minutes, from 6 to 14 and after 14.</li>
        \\<li><b>Timings</b>: median time to level 6 and to the first finished item (2,200
        \\gold or more, building into nothing, boots excluded).</li>
        \\<li><b>Experienced players</b>: games where a laner has 100,000 or more mastery
        \\points on their champion, from the mastery we last fetched for them (so it can be
        \\later than the game). Offered on a matchup page once there are 10 such
        \\games.</li>
        \\<li><b>Rank</b>: visible rank tiers when the game was collected, never hidden
        \\matchmaking rating. A matchup page splits its games by the median tier of the
        \\game's ten players, in three brackets (Iron to Silver, Gold to Emerald, Diamond
        \\and above); with Platinum+ games Iron to Silver is nearly empty and Gold to
        \\Emerald is mostly Platinum and Emerald. A champion page's Rank filter uses the
        \\player's own tier and counts that tier and above (Gold+ includes Platinum and
        \\higher); below Platinum it only adds the few lower-ranked players in these
        \\games.</li>
        \\<li><b>Sample size</b>: every chart states patch, rank and the number of games.
        \\Every matchup gets a page; under 200 games, or while less than half of the line
        \\comes from the matchup's own games, it is greyed out: thin curves still move as
        \\games come in.</li>
        \\</ul>
        \\
    );
    if (info.curves) |c| try gamesToStabilise(w, c);
    try w.writeAll(
        \\<h2>Champion statistics</h2>
        \\<ul>
        \\<li><b>Win, pick and ban rate</b>: games won with the champion in that role, share
        \\of games with it in that role, share of games where it was banned.</li>
        \\<li><b>How sure a win rate is</b>: every win rate is the raw share of games won,
        \\never pulled toward 50%; a dot marks it on a track from 25% to 75%. Colour runs
        \\from hot pink through orange (low) to blue through aqua (high), grey at 50%, by
        \\the rate alone, not red and green, which colour-blind readers can't tell apart;
        \\a key under each table gives the rates. Fewer games make it fainter, full from
        \\200: with few games a rate can sit far from the truth. Sorting by win rate uses
        \\the rate pulled toward the average, the more so the fewer its games, so a few
        \\lucky games can't top a table.</li>
        \\<li><b>Lane opponents</b>: the champion's win rate against each lane opponent and
        \\the lane curve's gold difference at 14 minutes. Every opponent is listed, hardest
        \\first; those with under 10 games are faded and listed last.</li>
        \\</ul>
        \\
    );
    try tpl.render(w,
        \\<h2 id="lean">Early or late</h2>
        \\<p>Each role on a champion page has a line on whether the champion leans early or
        \\late, from ranked solo games in every region over the last 30 days that lasted 15
        \\minutes or more and have a match timeline. Two numbers, each against an average
        \\pick in the same role:</p>
        \\<ul>
        \\<li><b>Gold at {gm} minutes</b>: how far ahead or behind its team is on average,
        \\as a team gold lead.</li>
        \\<li><b>From an even game at {wm} minutes</b>: how much more or less often its team
        \\wins than the game state then says. The state is each team's gold, experience,
        \\towers, inhibitors, dragons, soul, elder, grubs, herald and baron, so "even" means
        \\even on all of those. A percentage point is the change in a game that would
        \\otherwise be 50:50.</li>
        \\</ul>
        \\<p>All ten champions of a game are fitted together, one row per game, so a
        \\champion is not credited with what its usual teammates do. Each number is pulled
        \\toward the role's average by how much champions in that role really differ,
        \\estimated from the data, so one with few games stays near average. A number is
        \\shown only when it is at least twice its uncertainty and the champion has {min} or
        \\more games in the role still going at {wm} minutes; the ± is a 95% range.
        \\"Early" means both: ahead at {gm} and winning less often from an even game at
        \\{wm}. "Late" is the reverse.</p>
        \\<p>Why both: champions that put their team ahead early win less from the same gold
        \\and objectives, and champions that fall behind win more from them. The two mostly
        \\cancel, which is why a champion's overall win rate says little about either.
        \\Before this went on the site it was checked on newer games than the ones it was
        \\fitted on: the numbers shown predicted those games' gold and results better than
        \\leaving them out, at the sizes shown, and about nine in ten kept their sign.</p>
        \\<p>What it is not: a reason to pick or avoid a champion. It describes games in
        \\general. Who plays a champion and the rest of the draft are not held fixed, and
        \\"even" is even by the measures above only.</p>
        \\
    , .{ .gm = lean.gold_minute, .wm = lean.win_minute, .min = lean.min_games });
    try w.writeAll(
        \\<h2 id="builds">Builds</h2>
        \\<ul>
        \\<li><b>What is counted</b>: per champion and role on the current patch, the choices
        \\of players ranked Platinum IV and above when the game was collected. Most played
        \\first: a build page shows what players take, it does not rank choices.</li>
        \\<li><b>Runes and summoner spells</b>: from the end-of-game summary. The rune page
        \\is both trees without stat shards, which have their own table; Flash on either key
        \\counts as the same pair.</li>
        \\<li><b>Items</b>, from the match timeline: starting items are everything bought in
        \\the first 90 seconds (net of undos and sales, trinkets left out); boots are the
        \\first pair bought, an upgraded pair counting as the boots it came from, and "no
        \\boots" once a player finished two items without any; finished items are those
        \\used for first-item timing above, in the order they were bought; the fourth to sixth
        \\are counted on their own, whatever came before. Beside each item the median minute
        \\it was bought in that place: half the players who bought it there had it by then.
        \\Boots and finished items get no highest win rate mark: their win rates mostly say
        \\how the game was going when they were bought (nobody finishes Mejai's in a game
        \\they're losing).</li>
        \\<li><b>Skill priority</b>: Q, W and E ordered by points spent after 13 skill
        \\points (or the game's end, from 11), ties going to the ability that got there
        \\first. <b>Levels 1 to 18</b>: the ability taken at each level, from players who
        \\reached level 11; a game that ended sooner continues as the player was going (R
        \\at 6, 11 and 16, otherwise the ability with the most points), except for kits that
        \\break those rules (R before 6, an ability past 5 points), which count only when
        \\the game reached 18.</li>
        \\<li><b>Sample size</b>: every row shows games and its share. A win rate needs 100
        \\games and always comes with its 95% range; rows under 400 games are greyed out.
        \\Games that reach three finished items run long, so their win rates are for
        \\comparing with each other.</li>
        \\</ul>
        \\<h2>Daily Draft</h2>
        \\<p>One complete ranked game a day from recent games, the same for everyone, shown
        \\without names, Riot IDs, match ids or dates. One champion is hidden among four that
        \\were plausible in that draft; the reveal shows what was played, who won, the
        \\scoreboard and what this patch's games say about the draft and its lanes. It
        \\describes the game, it does not grade the pick.</p>
        \\<h2>What meiolol never does</h2>
        \\<ul>
        \\<li>Show other players' names or statistics in champ select, or anyone the game
        \\hides (streamer mode).</li>
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
        \\<h1>Champ select helper <span class="muted">(desktop app)</span></h1>
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
        \\<div id="admin-download"></div>
        \\<p class="note">Not released yet. Meanwhile the <a href="matchup/index.html">matchup
        \\curves</a> on this site show the same lane data.</p>
        \\</div>
        \\
    ++ admin_download);
}

/// Jacob's download before the release: the admin page stores the zip's path and patch in
/// this origin's localStorage (admin.js pollDesktop), as html.zig admin_link; the zip
/// itself stays behind the admin login
const admin_download =
    \\<script>try{const d=JSON.parse(localStorage.getItem("admin-desktop"));
    \\if(d&&typeof d.href=="string"&&d.href.startsWith("/admin/")){
    \\const p=document.createElement("p"),a=document.createElement("a");p.className="note";
    \\a.href=d.href;a.download="";a.textContent="Download for Windows";
    \\a.style.cssText="display:inline-block;margin-bottom:6px;padding:7px 16px;border-radius:8px;"
    \\+"background:var(--accent);color:var(--bg);font-weight:600";
    \\p.append(a,document.createElement("br"),`Admin only until the public release. Unzip
    \\ it and run meiolol-desktop.exe in the meiolol folder; Windows asks first (More info,
    \\ then Run anyway). It downloads patch ${d.patch} statistics on first start and keeps
    \\ them and itself up to date.`);
    \\document.getElementById("admin-download").append(p)}}catch(e){}</script>
    \\
;

pub fn privacy(w: *Writer, info: Info) Writer.Error!void {
    try tpl.render(w,
        \\<div class="prose">
        \\<h1>Privacy policy</h1>
        \\<p class="muted">Last updated {updated}.</p>
        \\<h2>This website</h2>
        \\<p>No analytics or advertising trackers, and no cookies unless you log in (see
        \\<a href="#accounts">Accounts</a>). The hosting
        \\provider keeps standard request logs (IP address, time, page) for security and
        \\abuse prevention, for a limited time. The Daily Draft keeps your guesses, streak
        \\and archive in your own browser (local storage), and clearing site data removes
        \\them. When you finish a puzzle, its two answers (which champion, which side) are
        \\sent once with nothing that identifies you; we keep only each puzzle's totals, to
        \\show what share of players picked each answer, and these requests are not in our
        \\server logs. Pages also keep your view settings in your browser, such as filters,
        \\sort orders and tabs.</p>
        \\<p>Daily Draft puzzles are real ranked games shown without names, Riot IDs, player
        \\identifiers, match ids or game dates: at most champions, bans, patch, game length,
        \\and each player's rank and game statistics (kills, gold and the like); the date
        \\shown is the puzzle's, not the game's.</p>
        \\<h2>Your games</h2>
        \\<p>When you enter a Riot ID on <a href="your.html">Your games</a>, we ask the Riot
        \\Games API for that player's recent Summoner's Rift games and show their own lane
        \\against the typical curve for each matchup. Anyone can look up any Riot ID, as on other
        \\League statistics sites (legal basis: legitimate interests). The page shows that
        \\player's finished games, and lists the ten players in each with their champion,
        \\kills, deaths and assists and their Riot ID as at that game, as the League
        \\client's match history and other statistics sites do. Riot's streamer mode hides
        \\names only during a game, and we show no live games.</p>
        \\<p>For each player looked up we store the Riot ID, Riot's encrypted player
        \\identifier, server, visible rank, and the games we fetched: champions, positions,
        \\results, per-minute statistics and each player's Riot ID as at that game; the
        \\other players' identifiers are kept only as one-way hashes. A player nobody has
        \\looked up for 30 days is deleted, with games no remaining player is in. We don't
        \\record who looked up whom, and lookups are not in our server logs.</p>
        \\<p>Your games remembers the last five Riot IDs you looked up, and the newest game
        \\it saw for each, in your own browser (local storage) to offer them again and count
        \\new games, and the last player's games as last shown, to open them straight away
        \\when you come back; they are never sent to us. "Not you?" by the player's name
        \\stops that; "Forget on this device" under the lookup, or clearing site data,
        \\removes them all.</p>
        \\<p>To remove your games and stop us collecting them again, use "Remove a Riot ID"
        \\on the Your games page. You prove the account is yours by setting a given free
        \\profile icon in the League client for a minute; we then delete everything about
        \\you, your Riot ID in other players' games included, and keep only your encrypted
        \\identifier on a "do not collect" list so we never fetch your games or store your
        \\name again.</p>
        \\<h2 id="accounts">Accounts</h2>
        \\<p>Logins are only for people we invite to help run or test the site; there are no
        \\public accounts. For each account we keep the email address or username used to log
        \\in, a one-way hash of the password, its role, and when it was made and last used.
        \\Logging in sets one cookie, which keeps you logged in for 30 days and does nothing
        \\else; we store only a one-way hash of it. Nothing is ever sent to your email
        \\address. To delete your account, write to the address below and we remove it and
        \\its sessions. Copies in our backups are gone within 14 days.</p>
        \\<h2>The desktop app</h2>
        \\<p>The desktop app is not released yet. When it is, it will read champ select from
        \\the League client running on your own PC and show lane information on screen. It
        \\will not send your games, account or any other personal data anywhere. Apart from
        \\the League client it will connect only to this site, every few hours, to download
        \\newer champion statistics and updates to itself; those requests carry nothing
        \\about you, and our server logs them like any page visit (below).</p>
        \\<h2>Game data from Riot Games</h2>
        \\<p>The statistics are computed from ranked match data provided by the Riot Games
        \\API. Raw match records, which include Riot's per-application encrypted player
        \\identifiers, are stored privately and used to compute the statistics and the
        \\Daily Draft. We publish no Riot IDs or player identifiers from them; Daily Draft
        \\shows players only as seats, and Your games shows a player's games, with the Riot
        \\IDs of the players in them, when their Riot ID is looked up. Riot IDs in raw
        \\records are removed within days, when the records are archived, and player
        \\identifiers are removed from stored games 24 months after the game. Deletion
        \\requests passed on by Riot Games are honoured, and you can ask us directly to
        \\delete any data about your account.</p>
        \\<h2>Contact</h2>
        \\<p>Questions or requests: <a href="mailto:{contact}">{contact}</a>.</p>
        \\</div>
        \\
    , .{ .updated = info.updated, .contact = info.contact });
}

pub fn terms(w: *Writer, info: Info) Writer.Error!void {
    try tpl.render(w,
        \\<div class="prose">
        \\<h1>Terms of use</h1>
        \\<p class="muted">Last updated {updated}.</p>
        \\<ul>
        \\<li>meiolol (this site and the desktop app) is free to use. Its statistics are
        \\estimates from past games and come with no guarantee.</li>
        \\<li>You remain bound by Riot Games' Terms of Service when you play. meiolol only
        \\shows information; it never acts in the game client for you.</li>
        \\<li>Do not scrape the site at a rate that disrupts it or resell its data.</li>
        \\<li>The software is provided as is, without warranty of any kind.</li>
        \\<li>These terms may change; the date above shows the latest version.</li>
        \\</ul>
        \\<p>{legal}</p>
        \\<p>Contact: <a href="mailto:{contact}">{contact}</a>.</p>
        \\</div>
        \\
    , .{ .updated = info.updated, .legal = tpl.trusted(html.boilerplate), .contact = info.contact });
}
