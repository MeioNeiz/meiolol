//! The home page (index.html, docs/plan/ui/home.md): a game on the first screen with the
//! lookup and today's things beside it, each role's most played under them. Islands
//! (ui-home.wasm): HomeReview (the example's game, its role switch, the stat cells
//! select on the graph; a returning visitor's newest game in its place), IdLookup (recent Riot IDs on this device), HomeChamps (one role
//! at a time in a narrow card), HomeDaily (this device's Daily Draft marks). The patch
//! card is static
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const card = @import("card.zig");
const badge = @import("badge.zig");
const button = @import("button.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const rolepicker = @import("rolepicker.zig");
const stat = @import("stat.zig");
const segmented = @import("segmented.zig");
const bar = @import("bar.zig");
const gamehead = @import("gamehead.zig");
const gamepage = @import("gamepage.zig");
const gamedata = @import("gamedata.zig");
const idlookup = @import("idlookup.zig");
const yourlist = @import("yourlist.zig");
const url = @import("url.zig");
const today = @import("today.zig");
const dailypage = @import("dailypage.zig");
const data = @import("data.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;
const Role = role.Role;

pub const name = "HomePage";
pub const scope = .{ ".c-home", ".c-hrev", ".c-hch" };

/// The example's files (site/yourgame.zig)
pub const your_dir = "data/your/";
pub const game_page = "game";

const W = struct {
    pub const title = plain("Review your games");
    pub const example = plain("Example");
    pub const example_role = plain("Example's role");
    pub const open = plain("Open");
    pub const champions = plain("Champions");
    pub const games = phrase.Phrase("{n:count} games");
    pub const role = plain("Role");
    pub const daily = plain("Daily Draft");
    pub const number = phrase.Phrase("#{n:int}");
    pub const guess = plain("Guess");
    pub const play = plain("Today's Daily Draft");
    pub const yours = plain("Your last game");
    pub const record = phrase.Phrase("{w:int}W {l:int}L");
    pub const form = plain("Newest results, newest first");
    pub const win = plain("W");
    pub const loss = plain("L");
    pub const list = plain("List");
    pub const played = plain("Most played");
    pub const best = plain("Win rate");
    pub const rising = plain("Rising");
    pub const none = plain("None clear yet");
};

/// The example's game: the data file's first (newest) game. Switching role fetches that
/// role's file (wasm/home.zig); `want` differs from `shown` until it is in
pub const HomeReview = struct {
    s: gamepage.GamePage,
    /// Roles with a file in `dir`
    roles: [5]bool,
    shown: Role,
    want: Role,
    /// The site root, relative to the page
    up: []const u8 = "",
    default: Role,
    /// This device's newest looked-up player's newest game in place of the example
    /// (Mine); the role picker goes
    you: ?You = null,
    /// ui-homegame's loader and wasm (dom.lazyLoad), from the page
    js: []const u8 = "",
    wasm: []const u8 = "",
    /// Set by the island once the game's data is in: the role picker works
    live: bool = false,

    const P = @This();

    pub const Msg = union(enum) { role: Role };

    pub fn update(p: *P, m: Msg, _: *tree.Event) void {
        switch (m) {
            .role => |r| if (p.roles[@backingInt(r)]) {
                p.want = r;
            },
        }
    }

    /// The file a role's games are in
    pub fn path(p: *const P, a: std.mem.Allocator, r: Role) ![]const u8 {
        return a.print("{s}" ++ your_dir ++ "{t}.bin", .{ p.up, r });
    }

    pub fn view(p: *P, h: *H) N {
        const s = &p.s;
        // Each game opened makes a new Timeline
        s.tl.compact = true;
        var roles: [5]rolepicker.Item = undefined;
        for (&roles, Role.all) |*it, r| it.* = .{
            .role = r,
            .current = r == p.want,
            .disabled = !p.live or !p.roles[@backingInt(r)],
            .on = h.on(p, .{ .role = r }),
        };
        // /game opens the default role's games only
        const open = if (p.you) |y| y.open else if (p.shown == p.default) h.fmt("{s}" ++ game_page, .{p.up}) else null;
        return h.div(.{
            .class = "c-hrev",
            .data_island = "home",
            .data_src = if (s.src.len > 0) s.src else null,
            .data_stamp = s.stamp,
            .data_up = p.up,
            .data_roles = rolesMask(p.roles),
            .data_role = p.default,
            .data_js = if (p.js.len > 0) p.js else null,
            .data_wasm = if (p.wasm.len > 0) p.wasm else null,
        }, .{card.view(h, .{ .flush = true }, &.{
            h.div(.{ .class = "c-head" }, .{
                if (p.you) |*y| y.view(h) else badge.view(h, .accent, .{W.example}),
                if (p.you == null) rolepicker.view(h, .{ .v = .compact, .label = W.example_role }, &roles) else null,
                if (open) |o| button.view(h, .{ .s = .s, .href = o }, .{W.open}) else null,
            }),
            h.div(.{ .class = "hd" }, .{gamehead.view(h, s.game(), s.data.champs, s.data.arts)}),
            h.div(.{ .class = "gr" }, .{ s.tl.modes(h), s.tl.view(h), s.cells(h) }),
        })});
    }
};

/// The player bar, compact: Riot ID, record and form of their newest games
pub const You = struct {
    id: []const u8,
    /// /game with the game in the fragment (gamedata.Lookup)
    open: []const u8,
    wins: u16,
    losses: u16,
    /// Newest first, remakes skipped
    form: []const bool,

    const form_n = 5;

    /// `id` as typed (Name#TAG); null without games
    pub fn of(a: std.mem.Allocator, id: []const u8, l: *const yourlist.List, up: []const u8) !?You {
        if (l.games.len == 0) return null;
        const t = yourlist.totals(l.games, .{});
        var form: std.ArrayList(bool) = .empty;
        for (l.games) |g| {
            if (form.items.len == form_n) break;
            if (!g.remake) try form.append(a, g.win);
        }
        return .{
            .id = id,
            .open = try a.print("{s}" ++ game_page ++ "#{s}&game={d}", .{ up, try idQuery(a, id), l.games[0].start_ms }),
            .wins = t.wins,
            .losses = t.losses(),
            .form = form.items,
        };
    }

    /// Mine's attribute: "<wins> <losses> f<form as 1/0> <open> <id>" (the ID may have
    /// spaces, so last; open is URL-encoded). Plain text, so ui-homegame has no decoder
    pub fn text(y: You, a: std.mem.Allocator) ![]const u8 {
        const form = y.form[0..@min(y.form.len, form_n)];
        var f: [form_n]u8 = undefined;
        for (form, 0..) |w, i| f[i] = if (w) '1' else '0';
        return a.print("{d} {d} f{s} {s} {s}", .{ y.wins, y.losses, f[0..form.len], y.open, y.id });
    }

    /// `text`'s; slices point into `s`
    pub fn parse(a: std.mem.Allocator, s: []const u8) !You {
        var it = std.mem.splitScalar(u8, s, ' ');
        const wins = try std.fmt.parseInt(u16, it.next() orelse return error.BadValue, 10);
        const losses = try std.fmt.parseInt(u16, it.next() orelse return error.BadValue, 10);
        const f = it.next() orelse return error.BadValue;
        if (f.len == 0 or f[0] != 'f' or f.len - 1 > form_n) return error.BadValue;
        const form = try a.alloc(bool, f.len - 1);
        for (form, f[1..]) |*w, c| w.* = switch (c) {
            '1' => true,
            '0' => false,
            else => return error.BadValue,
        };
        const open = it.next() orelse return error.BadValue;
        const id = it.rest();
        if (open.len == 0 or id.len == 0) return error.BadValue;
        return .{ .id = id, .open = open, .wins = wins, .losses = losses, .form = form };
    }

    fn view(y: *const You, h: *H) N {
        var f = h.list();
        for (y.form, 0..) |w, i| f.add(h.el(.i, .{ .key = i, .data_ok = w }, .{if (w) W.win else W.loss}));
        return h.span(.{ .class = "you" }, .{
            h.b(.{}, .{y.id}),
            badge.view(h, .accent, .{W.yours}),
            h.span(.{ .class = "rec" }, .{W.record.with(h, .{ .w = y.wins, .l = y.losses })}),
            h.span(.{ .class = "form", .role = "img", .aria_label = W.form }, .{f.done()}),
        });
    }
};

/// `id=Name%23TAG`: the API's query and /game's fragment
pub fn idQuery(a: std.mem.Allocator, id: []const u8) ![]const u8 {
    var f: struct { id: idlookup.Id = .{} } = .{};
    f.id.set(id);
    var out: std.Io.Writer.Allocating = .init(a);
    try url.write(@TypeOf(f), f, &out.writer);
    return out.written();
}

/// The API calls for a returning visitor, cache only (api/root.zig): their newest games
/// with record and form, then the newest game
pub fn listApi(a: std.mem.Allocator, id: []const u8) ![]const u8 {
    return a.print("/api/list?cached=1&n=20&{s}", .{try idQuery(a, id)});
}

pub fn gameApi(a: std.mem.Allocator, id: []const u8, start_ms: i64) ![]const u8 {
    return a.print("/api/game?{s}&start={d}", .{ try idQuery(a, id), start_ms });
}

/// A returning visitor's game, from ui-home (which has the list) to ui-homegame (which
/// has the review): `you` and `game` attributes on the review's root, then `event` on
/// the window, as homegame may be in before or after
pub const Mine = struct {
    /// You.text
    you: []const u8,
    /// gameApi of their newest game
    game: []const u8,

    pub const you_attr = "data-you";
    pub const game_attr = "data-game";
    pub const event = "ui-you";

    /// From /api/list's body; null when the cache has no games for `id` (never looked
    /// up, opted out) or the body isn't a Lookup (an older API: no list call)
    pub fn of(a: std.mem.Allocator, id: []const u8, body: []const u8, up: []const u8) !?Mine {
        const look = data.decode(a, yourlist.Lookup, body) catch |e| switch (e) {
            error.OutOfMemory => return e,
            else => return null,
        };
        if (look.state != .ready) return null;
        const l = look.list orelse return null;
        const y = try You.of(a, id, &l, up) orelse return null;
        return .{ .you = try y.text(a), .game = try gameApi(a, id, l.games[0].start_ms) };
    }
};

/// HomeReview.roles as bits, top first: the island's data-roles
pub fn rolesMask(roles: [5]bool) u8 {
    var m: u8 = 0;
    for (roles, 0..) |on, i| if (on) {
        m |= @as(u8, 1) << @intCast(i);
    };
    return m;
}

pub fn rolesOf(mask: u8) [5]bool {
    var r: [5]bool = undefined;
    for (&r, 0..) |*x, i| x.* = mask >> @intCast(i) & 1 == 1;
    return r;
}

/// Each role's top picks three ways
pub const Champs = struct {
    champs: []const champ.Champ,
    games: u32,
    /// The champions table's, then each role's (the heads' links)
    index: []const u8 = "",
    role_hrefs: [5][]const u8 = @splat(""),
    /// Most played by role, most games first
    roles: [5][]const Pick,
    /// Best win rate over the champions table's games floor, by role
    best: [5][]const Pick = @splat(&.{}),
    /// Clear win rate rises since the last patch, biggest first, by role
    rising: [5][]const Pick = @splat(&.{}),
    pub const Pick = struct {
        champ: u16,
        href: []const u8,
        games: u32,
        wins: u32,
        /// Of all games, percent
        share: f32,
        /// This patch against the last, points; null: new or too few games
        d: ?f32 = null,
    };
};

pub const HomeChamps = struct {
    data: *const Champs,
    /// Shown alone when the card is narrow
    on: Role = .mid,
    list: List = .played,
    /// Base64 of `data` for the island (ui.data)
    bin: []const u8 = "",

    const P = @This();

    pub const List = enum { played, best, rising };

    pub const Msg = union(enum) { role: Role, list: List };

    pub fn update(p: *P, m: Msg, _: *tree.Event) void {
        switch (m) {
            .role => |r| p.on = r,
            .list => |l| p.list = l,
        }
    }

    /// The champions table sorted as the list is (its Games, Win rate and Patch columns)
    fn sorted(p: *const P, h: *H, href: []const u8) []const u8 {
        const frag = switch (p.list) {
            .played => "#sort=6",
            .best => return href,
            .rising => "#sort=2",
        };
        return std.mem.concat(h.mem, u8, &.{ href, frag }) catch {
            h.oom = true;
            return href;
        };
    }

    pub fn view(p: *P, h: *H) N {
        const d = p.data;
        var roles: [5]rolepicker.Item = undefined;
        for (&roles, Role.all) |*it, r| it.* = .{ .role = r, .current = r == p.on, .on = h.on(p, .{ .role = r }) };
        const lists = switch (p.list) {
            .played => d.roles,
            .best => d.best,
            .rising => d.rising,
        };
        var any_rising = false;
        for (d.rising) |ps| any_rising = any_rising or ps.len > 0;
        var items: [3]segmented.Item = undefined;
        for (&items, std.enums.values(List), [_]tree.Text{ W.played, W.best, W.rising }) |*it, l, label| it.* = .{ .label = label, .selected = p.list == l, .on = h.on(p, .{ .list = l }) };
        var top: f32 = 1;
        for (lists) |ps| for (ps) |x| {
            top = @max(top, x.share);
        };
        var cols = h.list();
        for (Role.all, lists) |r, ps| {
            var rows = h.list();
            if (ps.len == 0) rows.add(h.li(.{ .class = "none" }, .{W.none}));
            for (ps, 0..) |x, i| {
                // The island's from data-bin
                if (x.champ >= d.champs.len) continue;
                const c = d.champs[x.champ];
                const wr: f64 = if (x.games == 0) 50 else 100 * @as(f64, @floatFromInt(x.wins)) / @as(f64, @floatFromInt(x.games));
                rows.add(h.li(.{ .key = i }, .{h.a(.{ .href = x.href }, .{
                    champ.view(h, c, .{ .px = .@"32", .named = false }),
                    h.span(.{ .class = "nm" }, .{ h.b(.{}, .{c.name}), bar.view(h, x.share, top, phrase.num(h, .rate, x.share)) }),
                    stat.view(h, .{
                        .value = wr,
                        .scale = .aggregate,
                        .ref = 50,
                        .games = x.games,
                        .ctx = if (x.d) |dd| phrase.num(h, .points, dd) else null,
                    }),
                })}));
            }
            cols.add(h.div(.{ .key = @backingInt(r), .class = "col", .data_on = r == p.on }, .{
                h.h3(.{}, .{h.a(.{ .href = p.sorted(h, d.role_hrefs[@backingInt(r)]) }, .{ role.view(h, r, .{ .s = .s, .named = false }), r.label() })}),
                h.ul(.{}, .{rows.done()}),
            }));
        }
        return h.div(.{ .class = "c-hch", .data_island = "homechamps", .data_bin = if (p.bin.len > 0) p.bin else null }, .{card.view(h, .{ .flush = true }, &.{
            h.div(.{ .class = "c-head" }, .{
                h.h2(.{}, .{h.a(.{ .href = p.sorted(h, d.index) }, .{W.champions})}),
                h.span(.{ .class = "count" }, .{W.games.with(h, .{ .n = d.games })}),
                segmented.view(h, .{ .s = .s, .label = W.list }, items[0..if (any_rising) 3 else 2]),
                rolepicker.view(h, .{ .v = .compact, .label = W.role }, &roles),
            }),
            h.div(.{ .class = "cols" }, .{cols.done()}),
        })});
    }
};

/// Today's Daily Draft: its teams, the hidden seat null
pub const Daily = struct {
    n: u32,
    href: []const u8,
    teams: today.Teams = @splat(@splat(null)),
};

/// The Daily Draft card; `marks` once this device played the puzzle (wasm/home.zig reads
/// them from daily.js's storage)
pub const HomeDaily = struct {
    data: *const Daily,
    marks: ?today.Marks = null,
    bin: []const u8 = "",

    const P = @This();

    pub fn view(p: *P, h: *H) N {
        const d = p.data;
        return h.div(.{ .data_island = "homedaily", .data_bin = if (p.bin.len > 0) p.bin else null }, .{today.view(h, .{
            .title = W.daily,
            .count = W.number.with(h, .{ .n = d.n }),
            .action = if (p.marks == null) W.guess else W.open,
            .href = d.href,
        }, if (p.marks) |m| today.marks(h, m) else null, today.draft(h, &d.teams, d.href, W.play))});
    }
};

/// ui-yourlookup's `your-recent` (`[{"id":"Name#TAG","newest":ms},...]`, newest first) into
/// `out`; IDs with JSON escapes are skipped (a Riot ID has no quote or backslash)
pub fn recentIds(json: []const u8, out: []idlookup.Id) []idlookup.Id {
    const key = "\"id\":\"";
    var n: usize = 0;
    var rest = json;
    while (n < out.len) {
        const at = std.mem.find(u8, rest, key) orelse break;
        rest = rest[at + key.len ..];
        const end = std.mem.findAny(u8, rest, "\"\\") orelse break;
        if (rest[end] == '"' and end > 0) {
            out[n] = .{};
            out[n].set(rest[0..end]);
            n += 1;
        }
        rest = rest[end..];
    }
    return out[0..n];
}

/// Puzzle n's marks (pick right, winner right) in `meiolol.daily.v1`, as the Daily page
/// reads them; null until both are in
pub fn dailyMarks(json: []const u8, n: u32) ?today.Marks {
    const m = (dailypage.read(json, n) orelse return null).marks orelse return null;
    return .{ .pick = m[0], .side = m[1] };
}

/// The page's grid: the title, lookup and Today cards on the left, the game on the right,
/// the champions under them
pub fn page(h: *H, lookup: N, review: N, cards: []const N, champs: N) N {
    return h.div(.{ .class = "c-home" }, .{
        h.div(.{ .class = "hero" }, .{
            h.el(.h1, .{}, .{W.title}),
            h.div(.{ .class = "side" }, .{
                h.div(.{ .class = "look" }, .{lookup}),
                h.div(.{ .class = "td" }, .{cards}),
            }),
            h.div(.{ .class = "rv" }, .{review}),
        }),
        champs,
    });
}

pub const css =
    \\@layer components {
    \\  .c-home { display: grid; gap: var(--sp-4); min-width: 0; }
    \\  .c-home > .hero { display: grid; grid-template-columns: minmax(0, 4fr) minmax(0, 8fr); gap: var(--sp-3) var(--sp-5);
    \\    grid-template-areas: "h1 h1" "side rv"; align-items: stretch; }
    \\  .c-home > .hero > h1 { grid-area: h1; margin: 0; }
    \\  .c-home > .hero > .side { grid-area: side; display: flex; flex-direction: column; gap: var(--sp-3); min-width: 0; }
    \\  .c-home > .hero > .rv { grid-area: rv; min-width: 0; display: flex; flex-direction: column; }
    \\  .c-home :is(.rv, .td > :last-child) > * { flex: 1; }
    \\  .c-home :is(.rv, .td > :last-child) .c-card { height: 100%; }
    \\  .c-home > .hero .td { flex: 1; display: flex; flex-direction: column; gap: var(--sp-3); }
    \\  .c-home > .hero .td > :last-child { flex: 1; display: flex; flex-direction: column; }
    \\  @media (max-width: 1000px) {
    \\    .c-home > .hero { grid-template-columns: minmax(0, 1fr); grid-template-areas: "h1" "look" "rv" "td"; }
    \\    .c-home > .hero > .side { display: contents; }
    \\    .c-home > .hero .look { grid-area: look; }
    \\    .c-home > .hero .td { grid-area: td; }
    \\  }
    \\  .c-hrev { container-type: inline-size; }
    \\  /* The side column can run taller (a patch with six changes): the graph takes the rest, no empty band */
    \\  .c-hrev > .c-card { display: flex; flex-direction: column; }
    \\  .c-hrev .gr { flex: 1; display: flex; flex-direction: column; }
    \\  .c-hrev .gr > .c-tl { flex: 1; }
    \\  .c-hrev .c-tl > .plot { flex: 1 0 auto; height: auto; min-height: calc(var(--h) * 1px); }
    \\  .c-hrev .c-head { padding-inline: var(--card-px); }
    \\  .c-hrev .c-head > .c-btn { margin-left: auto; }
    \\  .c-hrev .you { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-hrev .you > b { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-hrev .rec { color: var(--muted); font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\  .c-hrev .form { display: inline-flex; gap: 2px; }
    \\  .c-hrev .form > i { width: 16px; height: 16px; border-radius: 3px; display: grid; place-items: center;
    \\    font-size: var(--fs-xs); font-style: normal; font-weight: var(--w-b); color: var(--bg); background: var(--them); }
    \\  .c-hrev .form > i[data-ok] { background: var(--us); }
    \\  .c-hrev .hd { padding: var(--sp-3) var(--card-px); border-bottom: 1px solid var(--line); }
    \\  .c-hrev .gr { padding: var(--sp-2) var(--card-px) var(--sp-3); }
    \\  .c-hrev .gr > .c-seg { align-self: start; margin-bottom: var(--sp-2); }
    \\  /* Boxed under a rule: spread loose under the x axis they read as points on the timeline */
    \\  .c-hrev .cells { margin-top: var(--sp-3); padding-top: var(--sp-3); border-top: 1px solid var(--line); }
    \\  .c-hrev .cells > .c-strip { display: grid; grid-template-columns: repeat(auto-fit, minmax(96px, 1fr)); gap: var(--sp-2); }
    \\  .c-hrev .cells > * > :where(*) { padding: var(--sp-2) var(--sp-3); background: var(--panel-2); border-radius: var(--r-s); }
    \\  .c-hrev .cells > .c-strip > [data-press] { margin: 0; }
    \\  .c-hch { container-type: inline-size; }
    \\  .c-hch .c-head { padding-inline: var(--card-px); }
    \\  .c-hch .c-head > .c-seg { margin-left: auto; }
    \\  .c-hch .c-head > .c-roles { display: none; }
    \\  .c-hch .cols { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); }
    \\  .c-hch .col { min-width: 0; border-right: 1px solid var(--line); }
    \\  .c-hch .col:last-child { border-right: 0; }
    \\  .c-hch h3 { display: flex; align-items: center; gap: 6px; height: 32px; margin: 0; padding: 0 var(--card-px);
    \\    background: var(--panel-2); border-bottom: 1px solid var(--line); font-size: var(--fs-xs); font-weight: var(--w-b);
    \\    color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; }
    \\  .c-hch :is(h2, h3) > a { display: inline-flex; align-items: center; gap: 6px; color: inherit; }
    \\  .c-hch :is(h2, h3) > a:hover { color: var(--accent); text-decoration: none; }
    \\  .c-hch ul { list-style: none; margin: 0; padding: 0; }
    \\  .c-hch li > a { display: grid; grid-template-columns: 32px minmax(0, 1fr) auto; gap: var(--sp-2); align-items: center;
    \\    padding: 6px var(--card-px); color: var(--text); border-bottom: 1px solid var(--line); }
    \\  .c-hch li:last-child > a { border-bottom: 0; }
    \\  .c-hch li.none { padding: var(--sp-3) var(--card-px); color: var(--faint); font-size: var(--fs-s); }
    \\  .c-hch li > a:hover { background: var(--panel-2); text-decoration: none; }
    \\  .c-hch .nm { display: flex; flex-direction: column; min-width: 0; line-height: 1.25; }
    \\  .c-hch .nm > b { font-weight: var(--w-m); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-hch .c-stat { text-align: right; }
    \\  .c-hch .nm > .c-bar { font-size: var(--fs-xs); color: var(--muted); }
    \\  @container (max-width: 700px) {
    \\    .c-hch .c-head > .c-roles { display: inline-flex; }
    \\    .c-hch .cols { grid-template-columns: minmax(0, 1fr); }
    \\    .c-hch .col { display: none; border: 0; }
    \\    .c-hch .col[data-on] { display: block; }
    \\    .c-hch h3 { display: none; }
    \\  }
    \\}
    \\
;

/// The gallery's: the demo game and a few champions
pub fn demo(h: *H) ?struct { HomeReview, HomeChamps } {
    const s = gamepage.GamePage.init(h.mem, &@import("game_demo.zig").data) catch return null;
    const d = h.mem.create(Champs) catch return null;
    const c = champ.demo;
    const picks = [_][]const Champs.Pick{
        &.{ .{ .champ = 0, .href = "#", .games = 3540, .wins = 1810, .share = 8.8, .d = 0.3 }, .{ .champ = 1, .href = "#", .games = 3340, .wins = 1670, .share = 8.3, .d = -0.7 } },
        &.{.{ .champ = 2, .href = "#", .games = 3100, .wins = 1610, .share = 7.7, .d = 0.2 }},
        &.{ .{ .champ = 3, .href = "#", .games = 4470, .wins = 2290, .share = 11.1 }, .{ .champ = 1, .href = "#", .games = 3900, .wins = 1980, .share = 9.7, .d = 0.1 } },
        &.{.{ .champ = 4, .href = "#", .games = 6640, .wins = 3430, .share = 16.5, .d = -0.5 }},
        &.{.{ .champ = 5, .href = "#", .games = 5800, .wins = 3010, .share = 14.4, .d = 0.3 }},
    };
    d.* = .{
        .champs = h.mem.dupe(champ.Champ, &.{ c("Garen", "Garen"), c("Yone", "Yone"), c("MonkeyKing", "Wukong"), c("Ahri", "Ahri"), c("Jinx", "Jinx"), c("Thresh", "Thresh") }) catch return null,
        .games = 403364,
        .roles = picks,
        .best = .{ picks[2], picks[0], picks[1], &.{}, picks[4] },
    };
    return .{ .{ .s = s, .roles = .{ true, true, true, false, true }, .shown = .mid, .want = .mid, .default = .mid }, .{ .data = d } };
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    var x = demo(h) orelse {
        h.oom = true;
        return;
    };
    var look: idlookup.IdLookup = .{ .to = "#" };
    const teams: today.Teams = .{
        .{ champ.demo("Darius", "Darius"), champ.demo("LeeSin", "Lee Sin"), champ.demo("Ahri", "Ahri"), champ.demo("Jinx", "Jinx"), champ.demo("Thresh", "Thresh") },
        .{ champ.demo("Garen", "Garen"), champ.demo("Vi", "Vi"), null, champ.demo("Jhin", "Jhin"), champ.demo("Nami", "Nami") },
    };
    const dd = h.mem.create(Daily) catch return;
    dd.* = .{ .n = 14, .href = "#", .teams = teams };
    var daily: HomeDaily = .{ .data = dd };
    g.addFill("first visit", page(h, look.view(h), x[0].view(h), &.{daily.view(h)}, x[1].view(h)));
    daily.marks = .{ .pick = true, .side = true };
    g.addFill("Daily Draft played", daily.view(h));
    x[0].you = .{ .id = "Agurin#EUW", .open = "#", .wins = 12, .losses = 8, .form = &.{ true, true, false, true, false } };
    g.addFill("returning visitor", x[0].view(h));
    x[1].list = .best;
    g.addFill("champions by win rate, a role with none", x[1].view(h));
}

test "a role switch waits for its file; Open only on the default role" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var x = demo(&h).?;
    var ev: tree.Event = .{ .kind = .click };
    x[0].update(.{ .role = .bot }, &ev);
    try std.testing.expectEqual(Role.mid, x[0].want);
    x[0].update(.{ .role = .top }, &ev);
    try std.testing.expectEqual(Role.top, x[0].want);
    try std.testing.expectEqual(Role.mid, x[0].shown);
    x[0].up = "/";
    try std.testing.expectEqualStrings("/data/your/top.bin", try x[0].path(arena.allocator(), .top));
}

test "recent IDs and Daily marks from the browser's storage" {
    var out: [5]idlookup.Id = undefined;
    const ids = recentIds("[{\"id\":\"Faker#KR1\",\"newest\":1},{\"id\":\"a\\\"b#X\",\"newest\":2},{\"id\":\"Agurin#EUW\"}]", &out);
    try std.testing.expectEqual(2, ids.len);
    try std.testing.expectEqualStrings("Faker#KR1", ids[0].slice());
    try std.testing.expectEqualStrings("Agurin#EUW", ids[1].slice());
    try std.testing.expectEqual(0, recentIds("null", &out).len);
    const d = "{\"13\":{\"pick\":\"x\",\"side\":0,\"marks\":\"11\"},\"14\":{\"pick\":\"y\",\"side\":1,\"on\":\"2026-10-26\",\"marks\":\"10\"},\"15\":{\"pick\":\"z\"}}";
    try std.testing.expectEqual(today.Marks{ .pick = true, .side = false }, dailyMarks(d, 14).?);
    try std.testing.expectEqual(null, dailyMarks(d, 15));
    try std.testing.expectEqual(null, dailyMarks(d, 16));
    // The Daily island's entries: the option, not the champion
    const v = "{\"16\":{\"opt\":2,\"side\":1,\"marks\":\"01\",\"on\":\"2026-10-27\"},\"17\":{\"opt\":0}}";
    try std.testing.expectEqual(today.Marks{ .pick = false, .side = true }, dailyMarks(v, 16).?);
    try std.testing.expectEqual(null, dailyMarks(v, 17));
}

test "a returning visitor: record, form and the calls by their Riot ID" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const g: yourlist.Game = .{ .start_ms = 9, .dur = 1800, .patch = "16.21", .queue = .solo, .champ = 0, .win = true, .k = 1, .d = 2, .a = 3 };
    var games: [7]yourlist.Game = @splat(g);
    games[1].win = false;
    games[2].remake = true;
    games[4].win = false;
    games[0].start_ms = 1791720000000;
    const l: yourlist.List = .{ .player = .{ .name = "Hide on bush" }, .champs = &.{}, .games = &games };
    const y = (try You.of(a, "Hide on bush#KR1", &l, "/")).?;
    try std.testing.expectEqual(4, y.wins);
    try std.testing.expectEqual(2, y.losses);
    try std.testing.expectEqualSlices(bool, &.{ true, false, true, false, true }, y.form);
    try std.testing.expectEqualStrings("/game#id=Hide%20on%20bush%23KR1&game=1791720000000", y.open);
    try std.testing.expectEqualStrings("/api/list?cached=1&n=20&id=Hide%20on%20bush%23KR1", try listApi(a, "Hide on bush#KR1"));
    try std.testing.expectEqualStrings("/api/game?id=Hide%20on%20bush%23KR1&start=5", try gameApi(a, "Hide on bush#KR1", 5));
    const none: yourlist.List = .{ .player = .{ .name = "x" }, .champs = &.{}, .games = &.{} };
    try std.testing.expectEqual(null, try You.of(a, "x#1", &none, ""));

    var body: std.ArrayList(u8) = .empty;
    try data.encode(a, yourlist.Lookup, .{ .state = .ready, .list = l }, &body);
    const m = (try Mine.of(a, "Hide on bush#KR1", body.items, "/")).?;
    try std.testing.expectEqualStrings("/api/game?id=Hide%20on%20bush%23KR1&start=1791720000000", m.game);
    try std.testing.expectEqualStrings("4 2 f10101 /game#id=Hide%20on%20bush%23KR1&game=1791720000000 Hide on bush#KR1", m.you);
    const back = try You.parse(a, m.you);
    try std.testing.expectEqualStrings(y.open, back.open);
    try std.testing.expectEqualStrings("Hide on bush#KR1", back.id);
    try std.testing.expectEqual(4, back.wins);
    try std.testing.expectEqualSlices(bool, y.form, back.form);
    // Cache misses and an older API keep the example
    for ([_]yourlist.Lookup{ .{ .state = .none }, .{ .state = .opted_out }, .{ .state = .ready, .list = none } }) |v| {
        body.clearRetainingCapacity();
        try data.encode(a, yourlist.Lookup, v, &body);
        try std.testing.expectEqual(null, try Mine.of(a, "x#1", body.items, ""));
    }
    try std.testing.expectEqual(null, try Mine.of(a, "x#1", "{\"state\":\"none\"}", ""));
    try std.testing.expectEqual(null, try Mine.of(a, "x#1", "", ""));
    const no_form = try You.parse(a, "0 0 f # x#1");
    try std.testing.expectEqual(0, no_form.form.len);
    for ([_][]const u8{ "", "1 2", "1 2 101 # x#1", "1 2 f1x # x#1", "1 2 f111111 # x#1", "1 2 f1 #", "-1 2 f1 # x#1" }) |bad|
        try std.testing.expect(std.meta.isError(You.parse(a, bad)));
}
