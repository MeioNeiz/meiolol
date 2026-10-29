//! Fixed text pages on ui.textpage, their bodies markdown parsed at build time (ui.prose).
//! Wording follows docs/production-key.md and docs/concept.md ("Application wording")
const std = @import("std");
const ui = @import("ui");
const html = @import("html.zig");
const prose = @import("prose.zig");
const root = @import("root.zig");
const urls = ui.urls;
const Site = root.Site;

const Writer = std.Io.Writer;

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

/// `{name}` holes in `md` filled from `fills`, then parsed
fn doc(a: std.mem.Allocator, md: []const u8, fills: []const [2][]const u8) !ui.prose.Doc {
    var s = md;
    for (fills) |f| s = try std.mem.replaceOwned(u8, a, s, try std.fmt.allocPrint(a, "{{{s}}}", .{f[0]}), f[1]);
    return ui.prose.parse(a, s);
}

fn writeBody(h: *ui.H, w: *Writer, p: ui.textpage.TextPage) !void {
    const n = p.view(h);
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(h.t, n, w);
}

/// The body of text page `at`, between html.head and foot; false for one not here
pub fn body(site: *const Site, w: *Writer, at: std.meta.Tag(urls.Page)) !bool {
    const a = site.arena;
    var t: ui.Tree = .{};
    var h: ui.H = .init(a, &t);
    try writeBody(&h, w, switch (at) {
        .terms => .{
            .title = "Terms of use",
            .sub = "Last updated " ++ terms_updated ++ ".",
            .body = try doc(a, terms_md, &.{ .{ "legal", html.boilerplate }, .{ "contact", site.opts.contact } }),
        },
        .privacy => .{
            .title = "Privacy policy",
            .sub = "Last updated " ++ privacy_updated ++ ".",
            .body = try doc(a, privacy_md, &.{.{ "contact", site.opts.contact }}),
        },
        .download => .{
            .title = "Champ select helper (desktop app)",
            .lead = "In development: a small Windows app that, once you have picked your champion in champ select, shows how your lane matchup usually unfolds and your own record in it.",
            .body = try ui.prose.parse(a, download_md),
            .extra = h.div(.{ .id = "admin-download" }, .{}),
        },
        else => return false,
    });
    if (at == .download) try w.writeAll(prose.admin_download);
    return true;
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
