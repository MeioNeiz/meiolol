//! Fixed text pages on ui.textpage, their bodies markdown parsed at build time (ui.prose).
//! Wording follows docs/production-key.md and docs/concept.md ("Application wording")
const std = @import("std");
const ui = @import("ui");
const html = @import("html.zig");
const root = @import("root.zig");
const assets = @import("assets.zig");
const urls = ui.urls;
const Site = root.Site;
const core = @import("core");
const curvesfile = core.curvesfile;
const Curves = curvesfile.Curves;
const Role = core.Role;
const evalchart = @import("evalchart.zig");
const extras = @import("extras.zig");
const lean = @import("../lean.zig");

const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;

/// Changed by hand with the text: the build date would claim a new policy every day
const method_lead = "meiolol helps players understand how lane matchups unfold and compare their own lane with the typical curve. The statistics are champion and aggregate data from ranked games, and it never names a \"best pick\".";

const method_md =
    \\**In short**
    \\
    \\- Ranked solo/duo games from Riot's official API, of players picked at random
    \\  from Platinum IV and above in every region.
    \\- Each page says its region, period (last 30 days or this patch) and number of
    \\  games.
    \\- Win rates are plain shares of games won, fainter when games are few.
    \\- A matchup with few games leans on how its two champions usually do, and moves
    \\  toward its own games as they come in.
    \\
    \\## The data
    \\
    \\- Ranked Solo/Duo games collected through the official Riot Games API, from
    \\  players chosen at random from Platinum IV and above on the ladder, in every
    \\  region. Their teammates and opponents are matched to them, so nearly every player
    \\  is Platinum or higher: these are the "Platinum+ games" the pages count.
    \\- Only complete games: no remakes, a winner, all ten positions known.
    \\- Each game's match timeline: every player's gold, experience and CS once a
    \\  minute, plus kills, level ups and item purchases. Timelines are stored once per
    \\  match, compactly, and never fetched twice.
    \\- Grouped per patch and updated daily. Nothing identifying a player is
    \\  published.
    \\- **Game counts** differ between pages for three reasons. The view: EUW or
    \\  every region, the last 30 days or this patch (pages without a switch, like this
    \\  one, count EUW's current patch). Lane curves need the game's full match timeline,
    \\  so a matchup's curves count slightly fewer games than its win rate. And pages are
    \\  refreshed at different times, so one can be a few hours behind another.
    \\
    \\## Lane curves
    \\
    \\- **Matchup**: the two players in the same position on opposite teams (top
    \\  against top, and so on).
    \\- **Curves**: for each minute from 1 to 25, the difference between the two in
    \\  gold, experience and CS (lane minions plus jungle monsters). The line is the
    \\  estimated average difference (below); the band is the middle half of games (25th
    \\  to 75th percentile), so you see how much games vary, not only the typical one.
    \\  Under 200 games the band is the middle half of every lane in that role, drawn
    \\  around the line, and says so.
    \\- **The estimate**: a matchup with few games is mostly noise, so its line
    \\  starts from the champions' baseline: how each of the two does against everyone in
    \\  that role, fitted together so that A against B starts at A's usual lead minus B's.
    \\  The matchup's own games then pull it away from the baseline: with n games, its own
    \\  average gets the weight n / (n + k). k, the "games to stabilise", is the
    \\  game-to-game variance divided by how much true matchups differ from their
    \\  baselines, both measured from the games at every update (table below). A rank
    \\  bracket, or games by experienced players, start from the line of every game
    \\  in the same way. Finally each line is smoothed across minutes, with a strength
    \\  chosen by fitting on half of the games and checking against the other half.
    \\- **Spread**: after an average, "8 games in 10" is where single games end up,
    \\  the 10th to 90th percentile of this matchup's games (the role's spread around
    \\  the line while it has few of its own); the band is the middle half. In tables,
    \\  colour says who is ahead on average and fades with fewer games, full from 200.
    \\- **Verdict**: the line above a gold chart says ahead or behind only while the
    \\  estimate is clear of noise (more than two standard errors from 0) and at least 200
    \\  gold at 14 minutes, else about even; "whoever is ahead wins" counts both sides'
    \\  games led at 14 minutes. Greyed-out curves get none.
    \\- **Games still going**: surrender opens at 15 minutes, so before it nearly
    \\  every game is still running. Right of the dotted line at 15 minutes a curve counts
    \\  only games still going, which tilts it toward closer games; each chart says what
    \\  share had ended by 20 and 25 minutes. Charts stop when fewer than 10 games
    \\  remain.
    \\- **Leads at 14 minutes**: who is ahead in gold at 14 minutes, and how often
    \\  each side then wins the game. Winning lane and winning the game often
    \\  disagree.
    \\- **Kills**: the share of games where each laner took part in killing the
    \\  other, before 6 minutes, from 6 to 14 and after 14.
    \\- **Timings**: median time to level 6 and to the first finished item (2,200
    \\  gold or more, building into nothing, boots excluded).
    \\- **Experienced players**: games where a laner has 100,000 or more mastery
    \\  points on their champion, from the mastery we last fetched for them (so it can be
    \\  later than the game). Offered on a matchup page once there are 10 such
    \\  games.
    \\- **Rank**: visible rank tiers when the game was collected, never hidden
    \\  matchmaking rating. A matchup page splits its games by the median tier of the
    \\  game's ten players, in three brackets (Iron to Silver, Gold to Emerald, Diamond
    \\  and above); with Platinum+ games Iron to Silver is nearly empty and Gold to
    \\  Emerald is mostly Platinum and Emerald. A champion page's Rank filter uses the
    \\  player's own tier and counts that tier and above (Gold+ includes Platinum and
    \\  higher); below Platinum it only adds the few lower-ranked players in these
    \\  games.
    \\- **Sample size**: every chart states patch, rank and the number of games.
    \\  Every matchup gets a page; under 200 games, or while less than half of the line
    \\  comes from the matchup's own games, it is greyed out: thin curves still move as
    \\  games come in.
    \\
    \\{k_table}
    \\
    \\## Champion statistics
    \\
    \\- **Win, pick and ban rate**: games won with the champion in that role, share
    \\  of games with it in that role, share of games where it was banned.
    \\- **How sure a win rate is**: every win rate is the raw share of games won,
    \\  never pulled toward 50%; a dot marks it on a track from 25% to 75%. Colour runs
    \\  from hot pink through orange (low) to blue through aqua (high), grey at 50%, by
    \\  the rate alone, not red and green, which colour-blind readers can't tell apart;
    \\  a key under each table gives the rates. Fewer games make it fainter, full from
    \\  200: with few games a rate can sit far from the truth. Sorting by win rate uses
    \\  the rate pulled toward the average, the more so the fewer its games, so a few
    \\  lucky games can't top a table.
    \\- **Lane opponents**: the champion's win rate against each lane opponent and
    \\  the lane curve's gold difference at 14 minutes. Every opponent is listed, hardest
    \\  first; those with under 10 games are faded and listed last.
    \\
    \\## Early or late {#lean}
    \\
    \\Each role on a champion page has a line on whether the champion leans early or
    \\late, from ranked solo games in every region over the last 30 days that lasted 15
    \\minutes or more and have a match timeline. Two numbers, each against an average
    \\pick in the same role:
    \\
    \\- **Gold at {gm} minutes**: how far ahead or behind its team is on average,
    \\  as a team gold lead.
    \\- **From an even game at {wm} minutes**: how much more or less often its team
    \\  wins than the game state then says. The state is each team's gold, experience,
    \\  towers, inhibitors, dragons, soul, elder, grubs, herald and baron, so "even" means
    \\  even on all of those. A percentage point is the change in a game that would
    \\  otherwise be 50:50.
    \\
    \\All ten champions of a game are fitted together, one row per game, so a
    \\champion is not credited with what its usual teammates do. Each number is pulled
    \\toward the role's average by how much champions in that role really differ,
    \\estimated from the data, so one with few games stays near average. A number is
    \\shown only when it is at least twice its uncertainty and the champion has {min} or
    \\more games in the role still going at {wm} minutes; the ± is a 95% range.
    \\"Early" means both: ahead at {gm} and winning less often from an even game at
    \\{wm}. "Late" is the reverse.
    \\
    \\Why both: champions that put their team ahead early win less from the same gold
    \\and objectives, and champions that fall behind win more from them. The two mostly
    \\cancel, which is why a champion's overall win rate says little about either.
    \\Before this went on the site it was checked on newer games than the ones it was
    \\fitted on: the numbers shown predicted those games' gold and results better than
    \\leaving them out, at the sizes shown, and about nine in ten kept their sign.
    \\
    \\What it is not: a reason to pick or avoid a champion. It describes games in
    \\general. Who plays a champion and the rest of the draft are not held fixed, and
    \\"even" is even by the measures above only.
    \\
    \\## Builds
    \\
    \\- **What is counted**: per champion and role on the current patch, the choices
    \\  of players ranked Platinum IV and above when the game was collected. Most played
    \\  first: a build page shows what players take, it does not rank choices.
    \\- **Runes and summoner spells**: from the end-of-game summary. The rune page
    \\  is both trees without stat shards, which have their own table; Flash on either key
    \\  counts as the same pair.
    \\- **Items**, from the match timeline: starting items are everything bought in
    \\  the first 90 seconds (net of undos and sales, trinkets left out); boots are the
    \\  first pair bought, an upgraded pair counting as the boots it came from, and "no
    \\  boots" once a player finished two items without any; finished items are those
    \\  used for first-item timing above, in the order they were bought; the fourth to sixth
    \\  are counted on their own, whatever came before. Beside each item the median minute
    \\  it was bought in that place: half the players who bought it there had it by then.
    \\  Boots and finished items get no highest win rate mark: their win rates mostly say
    \\  how the game was going when they were bought (nobody finishes Mejai's in a game
    \\  they're losing).
    \\- **Skill priority**: Q, W and E ordered by points spent after 13 skill
    \\  points (or the game's end, from 11), ties going to the ability that got there
    \\  first. **Levels 1 to 18**: the ability taken at each level, from players who
    \\  reached level 11; a game that ended sooner continues as the player was going (R
    \\  at 6, 11 and 16, otherwise the ability with the most points), except for kits that
    \\  break those rules (R before 6, an ability past 5 points), which count only when
    \\  the game reached 18.
    \\- **Highest win rate**: marked among options with 100 or more games, once each
    \\  is pulled toward the average of its kind by k games and taken at the low end of its
    \\  range, so a few lucky games can't top it. k comes from how much options of a kind
    \\  really differ across every champion (about 6,000 games for a rune, 600 to 1,000 for
    \\  items); against one lane opponent, from every matchup.
    \\- **Sample size**: every row shows games and its share. A win rate needs 100
    \\  games and always comes with its 95% range; rows under 400 games are greyed out.
    \\  Games that reach three finished items run long, so their win rates are for
    \\  comparing with each other.
    \\
    \\## Daily Draft
    \\
    \\One complete ranked game a day from recent games, the same for everyone, shown
    \\without names, Riot IDs, match ids or dates. One champion is hidden among four that
    \\were plausible in that draft; the reveal shows what was played, who won, the
    \\scoreboard and what this patch's games say about the draft and its lanes. It
    \\describes the game, it does not grade the pick.
    \\
    \\## What meiolol never does
    \\
    \\- Show other players' names or statistics in champ select, or anyone the game
    \\  hides (streamer mode).
    \\- Pick, ban, lock or dodge for anyone, or name a single "best" champion.
    \\- Infer hidden ranks or matchmaking rating.
;

const terms_updated = "12 October 2026";

const terms_md =
    \\- meiolol (this site and the desktop app) is free to use. Its statistics are
    \\  estimates from past games and come with no guarantee.
    \\- You remain bound by Riot Games' Terms of Service when you play. meiolol only
    \\  shows information; it never acts in the game client for you.
    \\- Do not scrape the site at a rate that disrupts it or resell its data.
    \\- The software is provided as is, without warranty of any kind.
    \\- These terms may change; the date above shows the latest version.
    \\
    \\{legal}
    \\
    \\Contact: [{contact}](mailto:{contact}).
;

const privacy_updated = "24 October 2026";

const privacy_md =
    \\What meiolol collects, why, how long it keeps it and what you can ask us to do.
    \\meiolol is run from the United Kingdom; write to [{contact}](mailto:{contact})
    \\about anything here.
    \\
    \\## This website
    \\
    \\No analytics or advertising trackers, and no cookies unless you log in (see
    \\[Accounts](#accounts)). Our web server logs each request to meio.lol
    \\without your IP address: time, page, status, the page that linked to it and browser
    \\type, for security, fixing problems and counting visits. Requests that fail are
    \\logged with the IP address. Logs are deleted after 14 days; hourly totals of visits
    \\by page and browser type, which identify no one, are kept 90 days. The Daily Draft
    \\keeps your guesses, streak and archive in your own browser (local storage), and
    \\clearing site data removes them. When you finish a puzzle, its two answers (which
    \\champion, which side) are sent once with nothing that identifies you;
    \\we keep only each puzzle's totals, to show what share of players picked each
    \\answer, and these requests are not in our server logs. Pages also keep your view
    \\settings in your browser, such as filters, sort orders and tabs.
    \\
    \\Daily Draft puzzles are real ranked games shown without names, Riot IDs, player
    \\identifiers, match ids or game dates: at most champions, bans, patch, game length,
    \\and each player's rank and game statistics (kills, gold and the like); the date
    \\shown is the puzzle's, not the game's.
    \\
    \\## Your games
    \\
    \\When you enter a Riot ID on [Your games](/your), we ask the Riot
    \\Games API for that player's recent Summoner's Rift games and show their own lane
    \\against the typical curve for each matchup. Anyone can look up any Riot ID, as on other
    \\League statistics sites (legal basis: legitimate interests). The page shows that
    \\player's finished games, and lists the ten players in each with their champion,
    \\kills, deaths and assists and their Riot ID as at that game, as the League
    \\client's match history and other statistics sites do. Friends lists the players on
    \\the same team in three or more of those games, with the player's record with and
    \\without each. Riot's streamer mode hides names only during a game, and we show no
    \\live games.
    \\
    \\For each player looked up we store the Riot ID, Riot's encrypted player
    \\identifier, server, visible rank, and the games we fetched: champions, positions,
    \\results, per-minute statistics and each player's Riot ID as at that game; the
    \\other players' identifiers are kept only as one-way hashes. A player nobody has
    \\looked up for 30 days is deleted, with games no remaining player is in. We don't
    \\record who looked up whom, and lookups are not in our server logs.
    \\
    \\Your games remembers the last five Riot IDs you looked up, and the newest game
    \\it saw for each, in your own browser (local storage) to offer them again and count
    \\new games, and the last player's games as last shown, to open them straight away
    \\when you come back; they are never sent to us. "Not you?" by the player's name
    \\stops that; "Forget on this device" under the lookup, or clearing site data,
    \\removes them all.
    \\
    \\To remove your games and stop us collecting them again, use "Remove a Riot ID"
    \\on the Your games page. You prove the account is yours by setting a given free
    \\profile icon in the League client for a minute; we then delete everything about
    \\you, your Riot ID in other players' games included, and keep only your encrypted
    \\identifier on a "do not collect" list so we never fetch your games or store your
    \\name again.
    \\
    \\## Accounts
    \\
    \\Logins are only for people we invite to help run or test the site; there are no
    \\public accounts. For each account we keep the email address or username used to log
    \\in, a one-way hash of the password, its role, and when it was made and last used.
    \\Logging in sets one cookie, which keeps you logged in for 30 days and does nothing
    \\else; we store only a one-way hash of it. Nothing is ever sent to your email
    \\address. The desktop app, once signed in, keeps a sign-in of its own: we store a
    \\one-way hash of it and when it was made and last used; it ends when you remove it on
    \\your account page, log out everywhere or change your password, or after 90 days
    \\unused. To delete your account, write to the address below and we remove it, its
    \\sessions and its app sign-ins. Copies in our backups are gone within 14 days.
    \\
    \\## The desktop app
    \\
    \\The desktop app is not released yet. When it is, it will read champ select from
    \\the League client running on your own PC, and during and after a game the game's
    \\own live data and end of game totals (champions, scores, items), and show lane
    \\information on screen. It will not send your games or any other personal data
    \\anywhere. Apart from the League client and the game it will connect only to this
    \\site, every few hours, to download newer champion statistics and updates to itself;
    \\those requests carry nothing about you except, while the app is for invited
    \\testers, its sign-in ([Accounts](#accounts)), and our server logs them
    \\like any page visit (above).
    \\
    \\## Game data from Riot Games
    \\
    \\The statistics are computed from ranked games collected through the official
    \\Riot Games API: the match (champions, items, runes, bans, game length, result),
    \\each player's per-minute gold, experience, level, CS and map position, each
    \\player's visible rank when the game was collected, and champion mastery. Players
    \\are identified by Riot's encrypted player identifier, which is different for each
    \\application. Most of these players have never visited this site, so we don't ask
    \\for consent; the legal basis is legitimate interests (UK GDPR and EU GDPR Article
    \\6(1)(f)), weighed in a written assessment we send on request. We publish no Riot
    \\IDs or player identifiers from these games: Daily Draft shows players only as
    \\seats, and Your games shows a player's games, with the Riot IDs of the players in
    \\them, only when their Riot ID is looked up. How long we keep it:
    \\
    \\- Raw match records from Riot, which include Riot IDs: until they are copied to
    \\  our archive, usually two or three days.
    \\- The archive: Riot IDs removed and player identifiers replaced by one-way codes;
    \\  the codes are removed 24 months after we collected the game.
    \\- Matches used for the statistics: the player identifier is removed 24 months
    \\  after the game; the match stays, linked to no one.
    \\- Rank and champion mastery: refreshed at least every 30 days, and deleted for a
    \\  player no ranked ladder or collected game has shown for 30 days, or whom Riot
    \\  reports as gone. A player's rank history goes 24 months after its newest entry.
    \\
    \\Deletion requests passed on by Riot Games are honoured, and you can ask us
    \\directly to delete any data about your account (below).
    \\
    \\## Where it is kept, and who else handles it
    \\
    \\The website, its database and its backups run on a server in Essex, England,
    \\lent to us and run by us alone, with its storage on a file server beside it.
    \\Further copies of the backups and the archive are on our own computers in the
    \\United Kingdom, and every deletion reaches them too. You reach the site through
    \\Cloudflare, which carries the traffic and caches public pages, so it sees your IP
    \\address; Your games answers are marked never to be stored. We never sell or share
    \\data, and there is no advertising. Mail to {contact} passes through Cloudflare's
    \\email routing, which also keeps a copy, and reaches a Gmail inbox.
    \\
    \\## Your rights
    \\
    \\You can object to our use of your data and have it erased ("Remove a Riot ID"
    \\above does both for your games), and ask for a copy of what we hold about you, to
    \\correct it, to restrict its use while a request is considered, or to have it in a
    \\machine-readable form. Write to [{contact}](mailto:{contact}); for a Riot
    \\ID we first ask you to prove it is yours with the same profile icon check, and we
    \\answer within one month. You can complain to us at the same address, and to the
    \\UK Information Commission ([ico.org.uk](https://ico.org.uk)) or, in the
    \\EU, your data protection authority.
;

const download_md =
    \\- Windows 10 and 11. Free.
    \\- Reads champ select from the League client on your PC (the client's local
    \\  interface), read-only. Nothing about your games leaves your computer.
    \\- The likely lane opponent is labelled as a guess, since enemy roles are hidden
    \\  in champ select. Where it shows champions from your pool, it lists several with
    \\  their reasons, never one.
    \\- Never picks, bans, locks or dodges for you, and never shows other players'
    \\  names or statistics.
    \\
    \\Not released yet. Meanwhile the [matchup curves](/matchups) on this site show the
    \\same lane data.
;

const not_found_md = "[Home](/) · [Champions](/champions) · [Matchups](/matchups)";

/// `{name}` holes in `md`: `md_fills` (markdown, as a table) before parsing, `fills` after,
/// into each run's text and href, so a value's `]`, `*` or "" can't change the markup. A
/// heading's slug is the hole's
fn doc(a: Allocator, md: []const u8, md_fills: []const Fill, fills: []const Fill) !ui.prose.Doc {
    var s = md;
    for (md_fills) |f| s = try fillIn(a, s, f);
    const d = try ui.prose.parse(a, s);
    const blocks = try a.dupe(ui.prose.Block, d.blocks);
    for (blocks) |*b| switch (b.*) {
        .heading => |*x| x.line = try fillLine(a, x.line, fills),
        .para => |*l| l.* = try fillLine(a, l.*, fills),
        .list => |*items| {
            const out = try a.dupe(ui.prose.Item, items.*);
            for (out) |*it| it.* = .{ .line = try fillLine(a, it.line, fills), .sub = try fillLines(a, it.sub, fills) };
            items.* = out;
        },
        .table => |*t| {
            const rows = try a.dupe([]const ui.prose.Line, t.rows);
            for (rows) |*r| r.* = try fillLines(a, r.*, fills);
            t.* = .{ .head = try fillLines(a, t.head, fills), .rows = rows, .cut = t.cut };
        },
        .code => {},
    };
    return .{ .blocks = blocks };
}

const Fill = [2][]const u8;

fn fillIn(a: Allocator, s: []const u8, f: Fill) ![]const u8 {
    if (std.mem.findScalar(u8, s, '{') == null) return s;
    return std.mem.replaceOwned(u8, a, s, try std.fmt.allocPrint(a, "{{{s}}}", .{f[0]}), f[1]);
}

fn fillLine(a: Allocator, l: ui.prose.Line, fills: []const Fill) !ui.prose.Line {
    const out = try a.dupe(ui.prose.Run, l);
    for (out) |*r| for (fills) |f| {
        r.s = try fillIn(a, r.s, f);
        r.href = try fillIn(a, r.href, f);
    };
    return out;
}

fn fillLines(a: Allocator, ls: []const ui.prose.Line, fills: []const Fill) ![]const ui.prose.Line {
    const out = try a.dupe(ui.prose.Line, ls);
    for (out) |*l| l.* = try fillLine(a, l.*, fills);
    return out;
}

fn writeBody(h: *ui.H, w: *Writer, p: ui.textpage.TextPage) !void {
    const n = p.view(h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(h.t, n, w);
}

/// k by role and minute, every bracket: how many games a matchup needs before its own
/// average counts as much as the champions' baseline. Markdown, "" without curves
fn gamesToStabilise(a: std.mem.Allocator, curves: ?*const Curves) ![]const u8 {
    const c = curves orelse return "";
    const shown = [_]usize{ 5, 10, 14, 20 };
    var w: Writer.Allocating = .init(a);
    try w.writer.print(
        \\### Games to stabilise
        \\
        \\k by role and minute, every rank bracket together, from the {f} games with
        \\a timeline in the biggest view (every region, last 30 days). Under k
        \\games a matchup's line is mostly its champions' baseline. "Gold at 14" is the
        \\gold difference at 14 minutes.
        \\
        \\| Role |
    , .{root.Thousands{ .n = c.games }});
    for (shown) |m| try w.writer.print(" Gold at {d} |", .{m});
    try w.writer.writeAll(" XP at 14 | CS at 14 |\n|---|---|---|---|---|---|---|\n");
    for (Role.all) |r| {
        try w.writer.print("| {s} |", .{root.roleName(r)});
        for (shown) |m| try kCell(&w.writer, c.param(r, .all, false, .gold, m - 1));
        try kCell(&w.writer, c.param(r, .all, false, .xp, 13));
        try kCell(&w.writer, c.param(r, .all, false, .cs, 13));
        try w.writer.writeByte('\n');
    }
    try w.writer.print("\nk is capped at {d}: true matchup differences are never assumed to be zero.\n", .{curvesfile.curvefit.max_k});
    return w.written();
}

fn kCell(w: *Writer, p: curvesfile.curvefit.Param) Writer.Error!void {
    if (p.tau2 == 0) return w.writeAll(" - |");
    try w.print(" {d:.0} |", .{p.k()});
}

/// The body of text page `at`, between html.head and foot; false for one not here
pub fn body(site: *const Site, w: *Writer, at: std.meta.Tag(urls.Page)) !bool {
    const a = site.arena;
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    try writeBody(&h, w, switch (at) {
        .method => .{
            .title = "Method",
            .lead = method_lead,
            .body = try doc(a, try std.mem.concat(a, u8, &.{ method_md, "\n", try evalchart.intro(a, site.eval) }), &.{
                .{ "k_table", try gamesToStabilise(a, extras.biggestCurves(site.view_curves)) },
            }, &.{
                .{ "gm", try std.fmt.allocPrint(a, "{d}", .{lean.gold_minute}) },
                .{ "wm", try std.fmt.allocPrint(a, "{d}", .{lean.win_minute}) },
                .{ "min", try std.fmt.allocPrint(a, "{d}", .{lean.min_games}) },
            }),
            .extra = evalchart.chart(&h, site.eval),
        },
        .terms => .{
            .title = "Terms of use",
            .sub = "Last updated " ++ terms_updated ++ ".",
            .body = try doc(a, terms_md, &.{}, &.{ .{ "legal", html.boilerplate }, .{ "contact", site.opts.contact } }),
        },
        .privacy => .{
            .title = "Privacy policy",
            .sub = "Last updated " ++ privacy_updated ++ ".",
            .body = try doc(a, privacy_md, &.{}, &.{.{ "contact", site.opts.contact }}),
        },
        .download => .{
            .title = "Champ select helper (desktop app)",
            .lead = "In development: a small Windows app that, once you have picked your champion in champ select, shows how your lane matchup usually unfolds and your own record in it.",
            .body = try ui.prose.parse(a, download_md),
        },
        else => return false,
    });
    return true;
}

/// An account page's body (ui.account), its island's script after it
pub fn account(site: *const Site, w: *Writer, kind: ui.account.Kind) !void {
    var t: ui.Tree = .{};
    var h: ui.H = .init(site.arena, &t);
    var p: ui.account.Account = .{ .kind = kind };
    const n = p.view(&h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&t, n, w);
    try html.tpl.render(w,
        \\<script src="{js}" data-wasm="{wasm}" defer></script>
        \\
    , .{ .js = html.Link{ .path = assets.account_js.path }, .wasm = assets.account_wasm.path });
}

/// The site's 404 page, never indexed
pub fn notFound(site: *const Site, w: *Writer) !void {
    var p = try site.sharedPage("Page not found | meiolol", "No page at this address.", .none);
    p.index = false;
    try html.head(w, p);
    var t: ui.Tree = .{};
    var h: ui.H = .init(site.arena, &t);
    try writeBody(&h, w, .{
        .title = "Page not found",
        .lead = "There's no page at this address: it may have moved, or the link has a typo.",
        .body = try ui.prose.parse(site.arena, not_found_md),
    });
    try html.foot(w, p);
}

test "doc: text fills go in after parsing, so their markdown characters stay text" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const md = "Write to [{contact}](mailto:{contact}).\n\n- **{n}** {contact}\n\n{t}";
    const md_fills: []const Fill = &.{.{ "t", "| a |\n| --- |\n| {n} |" }};
    for ([_][]const u8{ "a*b]c`d@x.y", "" }) |c| {
        const d = try doc(a, md, md_fills, &.{ .{ "contact", c }, .{ "n", "5" } });
        const p = d.blocks[0].para;
        try std.testing.expectEqual(.link, p[1].kind);
        try std.testing.expectEqualStrings(c, p[1].s);
        try std.testing.expectEqualStrings(try std.mem.concat(a, u8, &.{ "mailto:", c }), p[1].href);
        try std.testing.expectEqualStrings(".", p[2].s);
        const li = d.blocks[1].list[0].line;
        try std.testing.expectEqualStrings("5", li[0].s);
        try std.testing.expectEqualStrings(try std.mem.concat(a, u8, &.{ " ", c }), li[1].s);
        try std.testing.expectEqualStrings("5", d.blocks[2].table.rows[0][0][0].s);
    }
}
