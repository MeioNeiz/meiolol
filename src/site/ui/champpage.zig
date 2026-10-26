//! The champion page (champion/<slug>.html): one champion in one role
//! (docs/plan/ui/champion.md), as three islands. Top: the head with the role picker,
//! the opponent search and the headline figures. Build: the build panel. More: the
//! matchups as a dot plot with the chosen opponent's brief; by patch, by game length and
//! the players' spread; pick-up and what its mains also play.
//!
//! The server renders the main role from the same data the page's data files carry
//! (data/champion/<slug>.bin, -build.bin, -more.bin: `split`). ui-champion.wasm adopts
//! Top and fetches ui-champbuild.wasm and ui-champmore.wasm for the others (one file
//! would be over the 40 KB gz budget: stack.md); each reads the role from the fragment,
//! so the other roles switch in place (`#role=jungle`)
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const card = @import("card.zig");
const badge = @import("badge.zig");
const strip = @import("strip.zig");
const toggletip = @import("toggletip.zig");
const segmented = @import("segmented.zig");
const rolepicker = @import("rolepicker.zig");
const champsearch = @import("champsearch.zig");
const champhead = @import("champhead.zig");
const buildpanel = @import("buildpanel.zig");
const dotplot = @import("dotplot.zig");
const matchbrief = @import("matchbrief.zig");
const trend = @import("trend.zig");
const histogram = @import("histogram.zig");
const champlist = @import("champlist.zig");
const tiers = @import("tiers.zig");
const tabs = @import("tabs.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "ChampPage";
pub const scope = .{".c-cpage"};

pub const stamp = tiers.stamp;

pub const Data = struct {
    name: []const u8,
    slug: []const u8,
    /// The portrait's URL
    icon: []const u8,
    /// The newest patch: "16.21"
    patch: []const u8,
    /// Data Dragon's version, for portraits
    ddragon: []const u8,
    /// "EUW · last 30 days · Platinum+ · 403,364 games"
    scope: []const u8,
    /// Every champion, for opponents, allies and the search (Opp.champ indexes it)
    champs: []const Other,
    /// Most played first; only roles with enough of its games
    roles: []const Role,
    /// Game length buckets' names: "<20", "20-25" ...
    lengths: []const []const u8,
    spread: ?Spread = null,
    pickup: ?Pickup = null,
    also: []const Also = &.{},
};

pub const Other = struct {
    name: []const u8,
    /// Data Dragon's
    key: []const u8,
    slug: []const u8,
};

fn icon(h: *H, ddragon: []const u8, c: Other) champ.Champ {
    return .{ .name = c.name, .src = h.fmt("https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ ddragon, c.key }) };
}

pub const Role = struct {
    role: role.Role,
    games: u32,
    wins: u32,
    /// Of the champion's games, %
    share: f32,
    /// Its place in the role's champions table; 0: a rare pick there
    rank: u16 = 0,
    of: u16 = 0,
    /// Pick and ban rates, %
    pick: f32,
    ban: f32,
    /// Win rate change since the previous patch, points, with its 95% half width
    patch_move: ?[2]f32 = null,
    /// Early lean: gold at 14 against an average opponent
    lean: ?i16 = null,
    build: ?buildpanel.Data = null,
    /// Against or with each role: lane opponents first
    rels: []const Rel,
    by_patch: []const Patch,
    /// Data.lengths' buckets
    by_length: []const Counts,
};

pub const Counts = struct { games: u32, wins: u32 };

pub const Patch = struct {
    patch: []const u8,
    games: u32,
    wins: u32,
    /// Its place in the role on that patch; 0: rare
    rank: u16 = 0,
};

pub const Rel = struct {
    ally: bool,
    role: role.Role,
    /// Those in 1%+ of the champion's games, most played first
    opps: []const Opp,
    /// How many met it less often, left out
    rare: u16 = 0,
};

pub const Opp = struct {
    champ: u16,
    games: u32,
    wins: u32,
    /// Win rate against usual (its strength allowed for), points
    usual: f32,
    /// Lane gold at 14, the champion minus the opponent (lane opponents with curves)
    gold: ?i16 = null,
    /// A matchup page exists
    page: bool = false,
};

pub const Spread = struct {
    players: u32,
    /// Players per 10% bin, centred on 0% ... 100%
    bins: [11]u32,
    p25: u8,
    p75: u8,
    luck_p25: u8,
    luck_p75: u8,
};

pub const Pickup = struct {
    /// Mastery bands: under 10k, 10k, 30k, 100k, 300k+
    bins: [5]Counts,
    /// Bands under this many games are greyed
    thin: u32,
    /// Practised (100k+) minus new (under 30k) win rate, points; and the usual gap
    gap: ?f32 = null,
    usual_gap: f32,
    kind: enum { harder, usual, easier } = .usual,
    new: ?f32 = null,
    practised: ?f32 = null,
};

pub const Also = struct {
    champ: u16,
    /// How many times as often as other players its mains play it
    lift: f32,
    /// Of its mains, %
    share: f32,
    harder: bool = false,
};

/// What the dot plot places opponents by
pub const Measure = enum { win, usual, gold };

const thin_games = fmt.thin_games;

const W = struct {
    pub const roles = Phrase("{c:text}'s roles");
    pub const sub = Phrase("{r:text} · {p:text}");
    pub const vs = plain("vs opponent");
    pub const won = plain("Win rate");
    pub const rank = Phrase("{n:int}{th:text} of {of:int}");
    pub const pick = plain("Pick");
    pub const ban = plain("Ban");
    pub const games = plain("Games");
    pub const pm = Phrase("±{v:dec}");
    pub const nth = Phrase("{n:int}{th:text}");
    pub const move_note = plain("Its win rate on this patch minus the previous one, and how far it may be off either way (95%).");
    pub const matchups = plain("Matchups");
    pub const sections = plain("Sections");
    pub const build = plain("Build");
    pub const trends = plain("Trends");
    pub const rare = Phrase("{n:count} · +{r:count} rare");
    pub const against = plain("Against");
    pub const with = plain("With");
    pub const rel_label = plain("Matchups against or with");
    pub const measure_label = plain("Placed by");
    pub const m_win = plain("Win rate");
    pub const m_usual = plain("Vs usual");
    pub const m_gold = plain("Gold at 14");
    pub const usual_note = Phrase("How much more or less often than usual {c:text} won, allowing for the other champion's own win rate in its role; pulled toward 0 the fewer the games.");
    pub const opponent = Phrase("{r:text} opponent");
    pub const ally = Phrase("{r:text} ally");
    pub const wins = Phrase("{c:text} wins");
    pub const none = plain("Not enough games yet.");
    pub const by_patch = plain("By patch");
    pub const by_length = plain("By game length");
    pub const lean = Phrase("Early lean {g:signed} gold");
    pub const lean_note = plain("Gold at 14 minutes against an average lane opponent, from games of every length: whether it wins lanes, apart from how long its games last.");
    pub const players = plain("Players");
    pub const spread_head = Phrase("{n:count} · middle half {lo:pct}-{hi:pct}");
    pub const spread_note = Phrase("Players with 10+ games on it. Luck alone would spread the middle half over {lo:pct}-{hi:pct}.");
    pub const middle = plain("middle half");
    pub const pickup = plain("Pick-up");
    pub const pickup_head = Phrase("{a:rate} new → {b:rate} practised · gap {g:dec}, usual {u:dec}");
    pub const pickup_note = plain("New: under 30k mastery points on it; practised: 100k+. Practised players are better players too, so every champion rises: the usual gap is the average over champions.");
    pub const harder = plain("harder to pick up");
    pub const easier = plain("easier to pick up");
    pub const also = Phrase("{c:text} mains also play");
    pub const lift = Phrase("×{x:dec}");
    pub const share = Phrase("{s:pct}");
    pub const pool = plain("Pool");
    pub const patch_tip = Phrase("{p:text}: {r:rate} in {n:count} games");
    pub const length_tip = Phrase("{l:text} min: {r:rate} in {n:count} games");
    pub const band_tip = Phrase("{l:text}: {r:rate} in {n:count} games");
    pub const bands = [5]tree.Text{ plain("<10k"), plain("10k"), plain("30k"), plain("100k"), plain("300k+") };
};

fn rate(c: Counts) f32 {
    return @floatCast(buildpanel.rate(c.games, c.wins));
}

/// ±95%, points
fn ci(c: Counts) f32 {
    if (c.games == 0) return 0;
    const p: f32 = @floatCast(buildpanel.rate(c.games, c.wins) / 100);
    return 196 * @sqrt(p * (1 - p) / @as(f32, @floatFromInt(c.games)));
}

fn ordinal(n: u16) []const u8 {
    if (n % 100 >= 11 and n % 100 <= 13) return "th";
    return switch (n % 10) {
        1 => "st",
        2 => "nd",
        3 => "rd",
        else => "th",
    };
}

/// ui-champion.wasm's part of Data: the head
pub const TopData = struct {
    name: []const u8,
    slug: []const u8,
    icon: []const u8,
    patch: []const u8,
    ddragon: []const u8,
    scope: []const u8,
    champs: []const Other,
    roles: []const TopRole,
};

pub const TopRole = struct {
    role: role.Role,
    games: u32,
    wins: u32,
    share: f32,
    rank: u16 = 0,
    of: u16 = 0,
    pick: f32,
    ban: f32,
    patch_move: ?[2]f32 = null,
    /// Lane opponents, for the search
    lane: []const Opp,
};

/// ui-champbuild.wasm's: each role's build
pub const BuildData = struct {
    roles: []const BuildRole,
};

pub const BuildRole = struct {
    role: role.Role,
    build: ?buildpanel.Data = null,
};

/// ui-champmore.wasm's: the matchups and the cards under them
pub const MoreData = struct {
    name: []const u8,
    slug: []const u8,
    ddragon: []const u8,
    champs: []const Other,
    roles: []const MoreRole,
    lengths: []const []const u8,
    spread: ?Spread = null,
    pickup: ?Pickup = null,
    also: []const Also = &.{},
};

pub const MoreRole = struct {
    role: role.Role,
    games: u32,
    wins: u32,
    lean: ?i16 = null,
    rels: []const Rel,
    by_patch: []const Patch,
    by_length: []const Counts,
};

pub const Split = struct { top: TopData, build: BuildData, more: MoreData };

/// Each island's data, pointing into `d`
pub fn split(a: std.mem.Allocator, d: *const Data) !Split {
    const top = try a.alloc(TopRole, d.roles.len);
    const build = try a.alloc(BuildRole, d.roles.len);
    const more = try a.alloc(MoreRole, d.roles.len);
    for (d.roles, top, build, more) |x, *t, *b, *m| {
        t.* = .{ .role = x.role, .games = x.games, .wins = x.wins, .share = x.share, .rank = x.rank, .of = x.of, .pick = x.pick, .ban = x.ban, .patch_move = x.patch_move, .lane = if (x.rels.len > 0) x.rels[0].opps else &.{} };
        b.* = .{ .role = x.role, .build = x.build };
        m.* = .{ .role = x.role, .games = x.games, .wins = x.wins, .lean = x.lean, .rels = x.rels, .by_patch = x.by_patch, .by_length = x.by_length };
    }
    return .{
        .top = .{ .name = d.name, .slug = d.slug, .icon = d.icon, .patch = d.patch, .ddragon = d.ddragon, .scope = d.scope, .champs = d.champs, .roles = top },
        .build = .{ .roles = build },
        .more = .{ .name = d.name, .slug = d.slug, .ddragon = d.ddragon, .champs = d.champs, .roles = more, .lengths = d.lengths, .spread = d.spread, .pickup = d.pickup, .also = d.also },
    };
}

/// The role in the fragment's `role=`, as Data.roles' index (0, the main role, when none)
fn roleIndex(roles: anytype, want: ?role.Role) u8 {
    if (want) |w| for (roles, 0..) |x, i| {
        if (x.role == w) return @intCast(i);
    };
    return 0;
}

/// The search's entries for each of the champion's roles: the matchup pages from it
pub fn prepare(a: std.mem.Allocator, d: *const TopData, root: []const u8) ![]champsearch.Index {
    const out = try a.alloc(champsearch.Index, d.roles.len);
    for (out, d.roles) |*p, *r| {
        var entries: std.ArrayList(champsearch.Entry) = .empty;
        for (r.lane) |o| {
            const c = d.champs[o.champ];
            try entries.append(a, .{
                .name = c.name,
                .src = try std.fmt.allocPrint(a, "https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ d.ddragon, c.key }),
                .href = if (o.page) try std.fmt.allocPrint(a, "{s}matchup/{s}/{s}-vs-{s}.html", .{ root, @tagName(r.role), d.slug, c.slug }) else null,
            });
        }
        p.* = try .init(a, entries.items);
    }
    return out;
}

/// The head (ui-champion.wasm)
pub const Top = struct {
    data: *const TopData,
    /// The search's, by role
    prep: []champsearch.Index,
    /// "../" from the page to the site root
    root: []const u8,
    /// The data file and its stamp, for ui.wasm
    src: []const u8 = "",
    stamp: u32 = 0,
    /// Data.roles' index
    cur: u8 = 0,
    search: champsearch.ChampSearch = .{ .index = undefined, .id = "vs", .label = W.vs },

    const P = @This();

    /// The section links: a plain `#build` would clear the fragment's role
    pub const Msg = union(enum) { jump: Section };
    pub const Section = enum { build, matchups, trends };

    pub fn update(_: *P, m: Msg, ev: *tree.Event) void {
        ev.handled = true;
        ev.after = .{ .op = .jump, .ref = @tagName(m.jump) };
    }

    /// The main role as written; fromUrl moves to the URL's
    pub fn init(data: *const TopData, prep: []champsearch.Index, root: []const u8) P {
        var p: P = .{ .data = data, .prep = prep, .root = root };
        if (prep.len > 0) p.search.index = &prep[0];
        return p;
    }

    pub const Url = struct {
        role: ?role.Role = null,
    };

    fn r(p: *const P) *const TopRole {
        return &p.data.roles[p.cur];
    }

    pub fn toUrl(p: *const P) Url {
        return .{ .role = if (p.cur == 0) null else p.r().role };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.cur = roleIndex(p.data.roles, u.role);
        if (p.cur < p.prep.len) p.search.index = &p.prep[p.cur];
    }

    pub fn view(p: *P, h: *H) N {
        const d = p.data;
        const rl = p.r();
        return h.div(.{
            .class = "part",
            .data_island = "champion",
            .data_src = if (p.src.len > 0) p.src else null,
            .data_stamp = p.stamp,
            .data_root = p.root,
        }, .{
            card.view(h, .{}, &.{
                champhead.view(h, .{
                    .champ = .{ .name = d.name, .src = d.icon },
                    .sub = W.sub.with(h, .{ .r = rl.role.label().s, .p = d.patch }),
                    .roles = p.roles(h),
                    .vs = if (p.prep.len > 0) p.search.view(h) else null,
                    .strip = p.headline(h),
                }),
                tabs.view(h, W.sections, &.{
                    .{ .label = W.build, .href = "#build", .on = h.on(p, .{ .jump = .build }) },
                    .{ .label = W.matchups, .href = "#matchups", .on = h.on(p, .{ .jump = .matchups }), .n = @intCast(rl.lane.len) },
                    .{ .label = W.trends, .href = "#trends", .on = h.on(p, .{ .jump = .trends }) },
                }, &.{}),
                h.p(.{ .class = "where" }, .{tree.Text{ .s = d.scope }}),
            }),
        });
    }

    fn roles(p: *P, h: *H) N {
        var items: [role.Role.all.len]rolepicker.Item = undefined;
        for (role.Role.all, &items) |x, *it| {
            it.* = .{ .role = x, .disabled = true, .href = "#" };
            for (p.data.roles, 0..) |dr, i| if (dr.role == x) {
                it.* = .{
                    .role = x,
                    .share = dr.share,
                    .current = i == p.cur,
                    .href = if (i == 0) "#" else h.fmt("#role={s}", .{@tagName(x)}),
                };
            };
        }
        return rolepicker.view(h, .{ .label = W.roles.with(h, .{ .c = p.data.name }) }, &items);
    }

    fn headline(p: *P, h: *H) N {
        const rl = p.r();
        const won = rate(.{ .games = rl.games, .wins = rl.wins });
        var items: [5]strip.Item = undefined;
        var n: usize = 0;
        items[n] = .{
            .label = W.won,
            .value = phrase.num(h, .rate, won),
            .ctx = if (rl.rank > 0) W.rank.with(h, .{ .n = rl.rank, .th = ordinal(rl.rank), .of = rl.of }) else null,
            .step = .of(won - 50, fmt.win_cuts),
            .answer = true,
        };
        n += 1;
        if (rl.patch_move) |m| {
            items[n] = .{
                .label = .{ .s = p.data.patch },
                .value = phrase.num(h, .points, m[0]),
                .ctx = W.pm.with(h, .{ .v = m[1] }),
                .step = .of(m[0], fmt.win_cuts),
                .tip = .{ .id = "cp-move", .note = W.move_note },
            };
            n += 1;
        }
        items[n] = .{ .label = W.pick, .value = phrase.num(h, .rate, rl.pick) };
        items[n + 1] = .{ .label = W.ban, .value = phrase.num(h, .rate, rl.ban) };
        items[n + 2] = .{ .label = W.games, .value = phrase.num(h, .count, rl.games) };
        return strip.view(h, items[0 .. n + 3]);
    }
};

/// Each role's build panel (null without a build), set up in place: its rows point into
/// it
pub fn panels(a: std.mem.Allocator, d: *const BuildData) ![]?buildpanel.BuildPanel {
    const out = try a.alloc(?buildpanel.BuildPanel, d.roles.len);
    for (out, d.roles) |*p, *r| {
        p.* = null;
        if (r.build) |*b| {
            p.* = @as(buildpanel.BuildPanel, undefined);
            try p.*.?.init(a, b);
        }
    }
    return out;
}

/// The build (ui-champbuild.wasm, loaded after Top)
pub const Build = struct {
    data: *const BuildData,
    panels: []?buildpanel.BuildPanel,
    /// The data file and its stamp, for ui.wasm
    src: []const u8 = "",
    stamp: u32 = 0,
    /// ui-champbuild.js and .wasm, for ui-champion.wasm to load
    js: ?[]const u8 = null,
    wasm: ?[]const u8 = null,
    /// Data.roles' index
    cur: u8 = 0,

    const P = @This();

    /// `role` is Top's too: both write the same value
    pub const Url = struct {
        role: ?role.Role = null,
        slot: ?buildpanel.Kind = null,
    };

    fn panel(p: *P) ?*buildpanel.BuildPanel {
        if (p.cur >= p.panels.len) return null;
        return if (p.panels[p.cur]) |*b| b else null;
    }

    pub fn toUrl(p: *const P) Url {
        const bp = if (p.cur < p.panels.len) p.panels[p.cur] else null;
        return .{ .role = if (p.cur == 0) null else p.data.roles[p.cur].role, .slot = if (bp) |b| b.open else null };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.cur = roleIndex(p.data.roles, u.role);
        if (p.panel()) |b| b.fromUrl(.{ .slot = u.slot });
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{
            .class = "part",
            .id = "build",
            .data_island = "champbuild",
            .data_src = if (p.src.len > 0) p.src else null,
            .data_stamp = p.stamp,
            .data_js = p.js,
            .data_wasm = p.wasm,
        }, .{if (p.panel()) |b| card.view(h, .{ .flush = true }, &.{b.view(h)}) else .none});
    }
};

/// The matchups and the cards under them (ui-champmore.wasm, loaded after Top)
pub const More = struct {
    data: *const MoreData,
    /// "../" from the page to the site root
    root: []const u8,
    /// The data file and its stamp, for ui.wasm
    src: []const u8 = "",
    stamp: u32 = 0,
    /// ui-champmore.js and .wasm, for ui-champion.wasm to load
    js: ?[]const u8 = null,
    wasm: ?[]const u8 = null,
    /// Data.roles' index
    cur: u8 = 0,
    /// Data.roles[cur].rels' index
    rel: u8 = 0,
    measure: Measure = .win,
    dots: dotplot.DotPlot = .{ .dots = &.{}, .m = .{ .label = W.matchups } },
    by_patch: trend.Trend = .{ .label = W.by_patch, .points = &.{} },
    by_length: trend.Trend = .{ .label = W.by_length, .points = &.{} },
    pickup: trend.Trend = .{ .label = W.pickup, .points = &.{}, .height = 110 },

    const P = @This();

    pub const Msg = union(enum) { rel: u8, ally: bool, rel_role: role.Role, measure: Measure };

    /// `role` is Top's too: both write the same value
    pub const Url = struct {
        role: ?role.Role = null,
        with: bool = false,
        vs: ?role.Role = null,
        by: Measure = .win,
    };

    fn r(p: *const P) *const MoreRole {
        return &p.data.roles[p.cur];
    }

    pub fn toUrl(p: *const P) Url {
        const rl = p.r();
        const rel = if (rl.rels.len > 0) rl.rels[p.rel] else null;
        return .{
            .role = if (p.cur == 0) null else rl.role,
            .with = if (rel) |x| x.ally else false,
            .vs = if (rel) |x| (if (x.role == rl.role) null else x.role) else null,
            .by = p.measure,
        };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.cur = roleIndex(p.data.roles, u.role);
        const own = p.r().role;
        p.rel = p.relOf(u.with, u.vs orelse if (u.with) partner(own) else own) orelse 0;
        p.measure = if (u.by == .gold and !p.goldShown()) .win else u.by;
        p.dots.sel = null;
    }

    fn relOf(p: *const P, ally: bool, r2: role.Role) ?u8 {
        for (p.r().rels, 0..) |x, i| if (x.ally == ally and x.role == r2) return @intCast(i);
        return null;
    }

    /// Gold at 14 is the lane curves': lane opponents only
    fn goldShown(p: *const P) bool {
        const rl = p.r();
        if (rl.rels.len == 0) return false;
        const x = rl.rels[p.rel];
        return !x.ally and x.role == rl.role;
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .rel => |i| p.rel = i,
            .ally => |a| {
                const rl = p.r();
                if (rl.rels.len == 0) return;
                const cur = rl.rels[p.rel].role;
                // Nobody is with the champion in its own role: the usual partner then
                const r2 = if (a and cur == rl.role) partner(rl.role) else cur;
                p.rel = p.relOf(a, r2) orelse for (rl.rels, 0..) |x, i| {
                    if (x.ally == a) break @intCast(i);
                } else p.rel;
            },
            .rel_role => |r2| {
                const ally = if (p.r().rels.len > 0) p.r().rels[p.rel].ally else false;
                p.rel = p.relOf(ally, r2) orelse p.rel;
            },
            .measure => |x| p.measure = x,
        }
        if (p.measure == .gold and !p.goldShown()) p.measure = .win;
        p.dots.sel = null;
        ev.push = true;
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{
            .class = "part",
            .data_island = "champmore",
            .data_src = if (p.src.len > 0) p.src else null,
            .data_stamp = p.stamp,
            .data_root = p.root,
            .data_js = p.js,
            .data_wasm = p.wasm,
        }, .{
            p.matchups(h),
            h.div(.{ .class = "row3", .id = "trends" }, .{ p.patchCard(h), p.lengthCard(h), p.playersCard(h) }),
            h.div(.{ .class = "row2" }, .{ p.pickupCard(h), p.alsoCard(h) }),
        });
    }

    fn matchups(p: *P, h: *H) N {
        const d = p.data;
        const rl = p.r();
        if (rl.rels.len == 0) return card.view(h, .{ .id = "matchups" }, &.{ card.head(h, W.matchups, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        const rel = rl.rels[p.rel];
        const own = rate(.{ .games = rl.games, .wins = rl.wins });
        const opps = rel.opps;
        const dots = h.mem.alloc(dotplot.Dot, opps.len) catch {
            h.oom = true;
            return .none;
        };
        // Dots skip opponents without the measure (gold): back to opps
        const of = h.mem.alloc(u16, opps.len) catch {
            h.oom = true;
            return .none;
        };
        var n: usize = 0;
        for (opps, 0..) |o, k| {
            const x: f32 = switch (p.measure) {
                .win => rate(.{ .games = o.games, .wins = o.wins }) - own,
                .usual => o.usual,
                .gold => @floatFromInt(o.gold orelse continue),
            };
            dots[n] = .{
                .champ = icon(h, d.ddragon, d.champs[o.champ]),
                .x = x,
                .games = o.games,
                .fig = p.figure(h, o),
                .thin = o.games < thin_games,
                .href = p.matchHref(h, o),
            };
            of[n] = @intCast(k);
            n += 1;
        }
        p.dots.dots = dots[0..n];
        p.dots.m = switch (p.measure) {
            .win => .{ .label = W.matchups },
            .usual => .{ .label = W.matchups, .bin = 0.5, .reach = 1 },
            .gold => .{ .label = W.matchups, .bin = 100, .reach = 200 },
        };
        const chosen: ?Opp = if (p.dots.chosen()) |i| opps[of[i]] else null;
        var chips: [6]matchbrief.Common = undefined;
        var nc: usize = 0;
        for (dots[0..n], 0..) |x, i| {
            if (nc == chips.len) break;
            const o = opps[of[i]];
            chips[nc] = .{
                .champ = x.champ,
                .fig = phrase.num(h, .rate, rate(.{ .games = o.games, .wins = o.wins })),
                .colour = .{ .pts = rate(.{ .games = o.games, .wins = o.wins }) - own },
                .thin = x.thin,
                .pressed = p.dots.chosen() == @as(u16, @intCast(i)),
                .on = h.on(&p.dots, .{ .pick = @intCast(i) }),
            };
            nc += 1;
        }

        var rels: [role.Role.all.len]rolepicker.Item = undefined;
        for (role.Role.all, &rels) |x, *it| {
            const i = p.relOf(rel.ally, x);
            it.* = .{ .role = x, .current = x == rel.role, .disabled = i == null, .on = if (i) |k| h.on(p, .{ .rel = k }) else null };
        }
        const controls = [_]N{
            segmented.view(h, .{ .label = W.rel_label }, &.{
                .{ .label = W.against, .selected = !rel.ally, .on = h.on(p, .{ .ally = false }) },
                .{ .label = W.with, .selected = rel.ally, .on = h.on(p, .{ .ally = true }) },
            }),
            rolepicker.view(h, .{ .v = .compact, .label = W.rel_label }, &rels),
            segmented.view(h, .{ .label = W.measure_label }, &.{
                .{ .label = W.m_win, .selected = p.measure == .win, .on = h.on(p, .{ .measure = .win }) },
                .{ .label = W.m_usual, .selected = p.measure == .usual, .on = h.on(p, .{ .measure = .usual }) },
                .{ .label = W.m_gold, .selected = p.measure == .gold, .disabled = !p.goldShown(), .on = h.on(p, .{ .measure = .gold }) },
            }),
        };
        const count: u32 = @intCast(opps.len);
        return card.view(h, .{ .id = "matchups" }, &.{
            card.head(h, W.matchups, if (rel.rare > 0) W.rare.with(h, .{ .n = count, .r = rel.rare }) else phrase.num(h, .count, count), &controls),
            h.div(.{ .class = "plot" }, .{p.dots.view(h)}),
            if (chosen) |o| h.div(.{ .class = "brief" }, .{matchbrief.view(h, p.brief(h, rel, o), chips[0..nc])}) else .none,
        });
    }

    /// The figure a dot reads out with its name, in the measure's units
    fn figure(p: *const P, h: *H, o: Opp) tree.Text {
        return switch (p.measure) {
            .win => phrase.num(h, .rate, rate(.{ .games = o.games, .wins = o.wins })),
            .usual => phrase.num(h, .points, o.usual),
            .gold => phrase.num(h, .signed, @as(i32, o.gold orelse 0)),
        };
    }

    fn brief(p: *const P, h: *H, rel: Rel, o: Opp) matchbrief.Brief {
        const d = p.data;
        const rl = p.r();
        const own = rate(.{ .games = rl.games, .wins = rl.wins });
        const won = rate(.{ .games = o.games, .wins = o.wins });
        const c = d.champs[o.champ];
        const usual_tip = h.fmt("cp-usual-{d}", .{o.champ});
        var items: [4]strip.Item = undefined;
        var n: usize = 0;
        items[n] = .{ .label = W.wins.with(h, .{ .c = d.name }), .value = phrase.num(h, .rate, won), .ctx = phrase.num(h, .points, won - own), .step = .of(won - own, fmt.win_cuts), .answer = true };
        n += 1;
        items[n] = .{ .label = W.m_usual, .value = phrase.num(h, .points, o.usual), .step = .of(o.usual, fmt.win_cuts), .tip = .{ .id = usual_tip, .note = W.usual_note.with(h, .{ .c = d.name }) } };
        n += 1;
        if (o.gold) |g| {
            items[n] = .{ .label = W.m_gold, .value = phrase.num(h, .signed, @as(i32, g)) };
            n += 1;
        }
        items[n] = .{ .label = W.games, .value = phrase.num(h, .count, o.games), .ctx = phrase.num(h, .pct, @as(u32, @intFromFloat(@round(100 * @as(f32, @floatFromInt(o.games)) / @as(f32, @floatFromInt(@max(rl.games, 1))))))) };
        n += 1;
        return .{
            .champ = icon(h, d.ddragon, c),
            .rel = if (rel.ally) W.ally.with(h, .{ .r = rel.role.label().s }) else W.opponent.with(h, .{ .r = rel.role.label().s }),
            .thin = o.games < thin_games,
            .figures = strip.view(h, items[0..n]),
            .href = p.matchHref(h, o),
        };
    }

    fn matchHref(p: *const P, h: *H, o: Opp) ?[]const u8 {
        if (!o.page) return null;
        return h.fmt("{s}matchup/{s}/{s}-vs-{s}.html", .{ p.root, @tagName(p.r().role), p.data.slug, p.data.champs[o.champ].slug });
    }

    fn patchCard(p: *P, h: *H) N {
        const rl = p.r();
        const pts = h.mem.alloc(trend.Point, rl.by_patch.len) catch {
            h.oom = true;
            return .none;
        };
        var n: usize = 0;
        for (rl.by_patch) |x| {
            if (x.games == 0) continue;
            const c: Counts = .{ .games = x.games, .wins = x.wins };
            pts[n] = .{
                .label = .{ .s = x.patch },
                .sub = if (x.rank > 0) W.nth.with(h, .{ .n = x.rank, .th = ordinal(x.rank) }) else null,
                .v = rate(c),
                .ci = ci(c),
                .tip = W.patch_tip.with(h, .{ .p = x.patch, .r = rate(c), .n = x.games }),
            };
            n += 1;
        }
        p.by_patch.points = pts[0..n];
        if (p.by_patch.tip) |t| if (t >= n) {
            p.by_patch.tip = null;
        };
        return card.view(h, .{}, &.{ card.head(h, W.by_patch, null, &.{}), p.by_patch.view(h) });
    }

    fn lengthCard(p: *P, h: *H) N {
        const rl = p.r();
        const pts = h.mem.alloc(trend.Point, rl.by_length.len) catch {
            h.oom = true;
            return .none;
        };
        var n: usize = 0;
        for (rl.by_length, 0..) |c, i| {
            if (c.games == 0) continue;
            const l = if (i < p.data.lengths.len) p.data.lengths[i] else "";
            pts[n] = .{
                .label = .{ .s = l },
                .sub = phrase.num(h, .kilo, c.games),
                .v = rate(c),
                .ci = ci(c),
                .tip = W.length_tip.with(h, .{ .l = l, .r = rate(c), .n = c.games }),
            };
            n += 1;
        }
        p.by_length.points = pts[0..n];
        p.by_length.ref = rate(.{ .games = rl.games, .wins = rl.wins });
        const lean: ?[2]N = if (rl.lean) |g| toggletip.view(h, "cp-lean", .{W.lean.with(h, .{ .g = @as(i32, g) })}, W.lean.with(h, .{ .g = @as(i32, g) }), W.lean_note) else null;
        return card.view(h, .{}, &.{ card.head(h, W.by_length, null, &.{if (lean) |*x| h.span(.{ .class = "note" }, .{x}) else .none}), p.by_length.view(h) });
    }

    fn playersCard(p: *P, h: *H) N {
        const s = p.data.spread orelse return card.view(h, .{}, &.{ card.head(h, W.players, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        const tip = toggletip.view(h, "cp-spread", .{W.spread_head.with(h, .{ .n = s.players, .lo = s.p25, .hi = s.p75 })}, W.middle, W.spread_note.with(h, .{ .lo = s.luck_p25, .hi = s.luck_p75 }));
        return card.view(h, .{}, &.{
            card.head(h, W.players, null, &.{h.span(.{ .class = "note" }, .{&tip})}),
            histogram.view(h, .{
                .label = W.spread_head.with(h, .{ .n = s.players, .lo = s.p25, .hi = s.p75 }),
                .counts = &s.bins,
                .lo = -5,
                .step = 10,
                .mid = .{ @floatFromInt(s.p25), @floatFromInt(s.p75) },
            }),
        });
    }

    fn pickupCard(p: *P, h: *H) N {
        const k = p.data.pickup orelse return card.view(h, .{}, &.{ card.head(h, W.pickup, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        var all: Counts = .{ .games = 0, .wins = 0 };
        for (k.bins) |b| {
            all.games += b.games;
            all.wins += b.wins;
        }
        const pts = h.mem.alloc(trend.Point, k.bins.len) catch {
            h.oom = true;
            return .none;
        };
        var n: usize = 0;
        for (k.bins, W.bands) |b, l| {
            if (b.games < k.thin) continue;
            pts[n] = .{ .label = l, .sub = phrase.num(h, .kilo, b.games), .v = rate(b), .ci = ci(b), .tip = W.band_tip.with(h, .{ .l = l.s, .r = rate(b), .n = b.games }) };
            n += 1;
        }
        if (n < 2) return card.view(h, .{}, &.{ card.head(h, W.pickup, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        p.pickup.points = pts[0..n];
        p.pickup.ref = rate(all);
        const head: ?[2]N = if (k.gap) |g| toggletip.view(h, "cp-pickup", .{W.pickup_head.with(h, .{ .a = k.new.?, .b = k.practised.?, .g = g, .u = k.usual_gap })}, W.pickup, W.pickup_note) else null;
        return card.view(h, .{}, &.{
            card.head(h, W.pickup, null, &.{
                switch (k.kind) {
                    .harder => badge.view(h, .neutral, .{W.harder}),
                    .easier => badge.view(h, .neutral, .{W.easier}),
                    .usual => .none,
                },
                if (head) |*x| h.span(.{ .class = "note" }, .{x}) else .none,
            }),
            p.pickup.view(h),
        });
    }

    fn alsoCard(p: *P, h: *H) N {
        const d = p.data;
        const rows = h.mem.alloc(champlist.Row, d.also.len) catch {
            h.oom = true;
            return .none;
        };
        for (rows, d.also) |*x, a| {
            const c = d.champs[a.champ];
            x.* = .{
                .champ = icon(h, d.ddragon, c),
                .href = h.fmt("{s}.html", .{c.slug}),
                .tag = if (a.harder) badge.view(h, .neutral, .{W.harder}) else null,
                .value = h.span(.{}, .{W.lift.with(h, .{ .x = a.lift })}),
                .note = W.share.with(h, .{ .s = @as(u32, @intFromFloat(@round(a.share))) }),
            };
        }
        const title = W.also.with(h, .{ .c = d.name });
        return card.view(h, .{}, &.{
            card.head(h, title, null, &.{h.a(.{ .class = "more", .href = h.fmt("{s}pool.html#{s}", .{ p.root, d.slug }) }, .{W.pool})}),
            if (rows.len > 0) champlist.view(h, .{ .label = title }, rows) else h.p(.{ .class = "none" }, .{W.none}),
        });
    }
};

/// The ally the With view opens on: the lane partner for bot and support, jungle for
/// the solo lanes, mid for the jungle
fn partner(r: role.Role) role.Role {
    return switch (r) {
        .top, .mid => .jungle,
        .jungle => .mid,
        .bot => .support,
        .support => .bot,
    };
}

pub const css =
    \\@layer components {
    \\  .c-cpage, .c-cpage > .part { display: flex; flex-direction: column; gap: var(--sp-4); }
    \\  .c-cpage > .part:empty { display: none; }
    \\  .c-cpage .c-card > .c-tabs { margin-top: var(--sp-4); }
    \\  .c-cpage [id] { scroll-margin-top: calc(var(--header) + var(--sp-3)); }
    \\  .c-cpage .where { margin: var(--sp-3) 0 0; font-size: var(--fs-s); color: var(--faint); }
    \\  .c-cpage .none { margin: var(--sp-3) 0; color: var(--muted); }
    \\  .c-cpage .note { margin-left: auto; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .more { margin-left: auto; font-size: var(--fs-s); }
    \\  .c-cpage .plot { padding: var(--sp-3) 0; }
    \\  .c-cpage .brief { container-type: inline-size; }
    \\  .c-cpage .row3, .c-cpage .row2 { display: grid; gap: var(--sp-4); grid-template-columns: minmax(0, 1fr); }
    \\  @media (min-width: 1000px) {
    \\    .c-cpage .row3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    \\    .c-cpage .row2 { grid-template-columns: minmax(0, 3fr) minmax(0, 2fr); }
    \\  }
    \\}
    \\
;
