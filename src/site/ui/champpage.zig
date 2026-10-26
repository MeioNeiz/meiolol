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
//! so the other roles switch in place (`#role=jungle`).
//!
//! Top's toolbar picks the region, period and rank, kept in the fragment beside the role:
//! each island then fetches its own file for the pick (`Files`: another view's base
//! file, or the view's rank file, ui.champrank) and shows the old figures faded until
//! it's in
const std = @import("std");
const tree = @import("tree.zig");
const html = @import("html.zig");
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
const filterbar = @import("filterbar.zig");
const url = @import("url.zig");
const champrank = @import("champrank.zig");
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
    /// Every champion, for opponents, allies and the search (Opp.champ indexes it)
    champs: []const Other,
    /// Most played first; every role with any of its games
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
    /// A role it rarely plays (under the champions table's share): figures faded
    thin: bool = false,
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

pub const Region = enum { euw, all };
pub const Period = enum { days30, patch };
/// Platinum+ (the base files), then ui.champrank's groups
pub const Rank = enum { plat, emerald, diamond, master };

/// The toolbar's: html.View.all's index (region, period) and the rank
pub const Pick = struct {
    view: u8 = 0,
    rank: Rank = .plat,

    fn of(u: anytype) Pick {
        return .{ .view = 2 * @as(u8, @backingInt(u.region)) + @backingInt(u.period), .rank = u.rank };
    }

    fn eql(a: Pick, b: Pick) bool {
        return a.view == b.view and a.rank == b.rank;
    }

    fn region(p: Pick) Region {
        return @fromBackingInt(@intCast(p.view / 2));
    }

    fn period(p: Pick) Period {
        return @fromBackingInt(@intCast(p.view % 2));
    }
};

const n_views = 4;
/// html.View's dir() and site/champrank.zig's suffixes
const view_dirs = [n_views][]const u8{ "", "patch/", "all/", "all/patch/" };
const rank_suffixes = [n_views][]const u8{ "", "-patch", "-all", "-all-patch" };

/// Figures of a rank group's role under this many games are faded; under min_games, games
/// only (builds.md)
const solid_games = 400;
const min_games = 100;

/// An island's data in each view: the base file (0: the page's) and its rank file,
/// fetched on a pick (ui/wasm/dom.zig Loader). `shown` stays until what `want` needs is in
pub fn Files(comptime D: type, comptime R: type) type {
    return struct {
        base: [n_views]?*const D = @splat(null),
        rank: [n_views]?*const R = @splat(null),
        /// No rank file: no games at Emerald+ in the view
        none: [n_views]bool = @splat(false),
        want: Pick = .{},
        shown: Pick = .{},

        const F = @This();
        const Elem = @typeInfo(@typeInfo(@FieldType(R, "groups")).array.child).pointer.child;

        pub const Need = struct { view: u8, rank: bool };

        pub fn need(f: *const F) ?Need {
            const v = f.want.view;
            if (f.base[v] == null) return .{ .view = v, .rank = false };
            if (f.want.rank != .plat and f.rank[v] == null and !f.none[v]) return .{ .view = v, .rank = true };
            return null;
        }

        pub fn busy(f: *const F) bool {
            return !f.shown.eql(f.want);
        }

        /// The shown rank's roles (none without its file); null at Platinum+
        fn group(f: *const F) ?[]const Elem {
            if (f.shown.rank == .plat) return null;
            const r = f.rank[f.shown.view] orelse return &.{};
            return r.groups[@backingInt(f.shown.rank) - 1];
        }
    };
}

/// View `v`'s base or rank file of the island whose page file is `src`, `root` the
/// site root from the page
pub fn viewPath(a: std.mem.Allocator, src: []const u8, root: []const u8, v: u8, rank: bool) ![]const u8 {
    if (src.len < root.len + ".bin".len) return error.BadPath;
    const rest = src[root.len..];
    if (rank) return std.mem.concat(a, u8, &.{ root, rest[0 .. rest.len - ".bin".len], "-rank", rank_suffixes[v], ".bin" });
    return std.mem.concat(a, u8, &.{ root, view_dirs[v], rest });
}

fn at(comptime T: type, roles: []const T, r: role.Role) ?*const T {
    for (roles) |*x| if (x.role == r) return x;
    return null;
}

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
    pub const build_against = Phrase("Build against {y:text}");
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
    pub const few = Phrase("Too few games at {r:text}.");
    pub const rare_role = Phrase("A rare role for {c:text}: {n:count} games.");
    pub const from = Phrase("Build from {g:text} games: too few at {r:text}.");
    pub const plat = plain("Plat+");
    pub const picked = Phrase("{r:text} · {p:text} · {k:text}");
    pub const region = plain("Region");
    pub const period = plain("Period");
    pub const rank_pick = plain("Rank");
    pub const regions = [2]tree.Text{ plain("EUW"), plain("All regions") };
    pub const days = plain("30 days");
    pub const ranks = [4]tree.Text{ plain("Plat+"), plain("Emerald+"), plain("Diamond+"), plain("Master+") };
    pub const bands = [5]tree.Text{ plain("<10k"), plain("10k"), plain("30k"), plain("100k"), plain("300k+") };
};

/// Vs usual's Toggletip, the matchup page's too
pub const usual_note = W.usual_note;

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
    champs: []const Other,
    roles: []const TopRole,
};

pub const TopRole = struct {
    role: role.Role,
    games: u32,
    wins: u32,
    share: f32,
    thin: bool = false,
    rank: u16 = 0,
    of: u16 = 0,
    pick: f32,
    ban: f32,
    patch_move: ?[2]f32 = null,
    /// Lane opponents, for the search
    lane: []const Opp,
    /// A rank file's lane opponent count, its lane being empty: the Matchups tab's
    opps: u16 = 0,
};

/// ui-champbuild.wasm's: each role's build
pub const BuildData = struct {
    roles: []const BuildRole,
    /// The matchup page's opponent: the card heads "Build against {name}"
    against: ?[]const u8 = null,
};

pub const BuildRole = struct {
    role: role.Role,
    thin: bool = false,
    build: ?buildpanel.Data = null,
    /// A rank file's: the group the build is from (Rank's index), when this one has too
    /// few games
    from: u8 = 0,
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
    thin: bool = false,
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
        t.* = .{ .role = x.role, .games = x.games, .wins = x.wins, .share = x.share, .thin = x.thin, .rank = x.rank, .of = x.of, .pick = x.pick, .ban = x.ban, .patch_move = x.patch_move, .lane = if (x.rels.len > 0) x.rels[0].opps else &.{} };
        b.* = .{ .role = x.role, .thin = x.thin, .build = x.build };
        m.* = .{ .role = x.role, .thin = x.thin, .games = x.games, .wins = x.wins, .lean = x.lean, .rels = x.rels, .by_patch = x.by_patch, .by_length = x.by_length };
    }
    return .{
        .top = .{ .name = d.name, .slug = d.slug, .icon = d.icon, .patch = d.patch, .ddragon = d.ddragon, .champs = d.champs, .roles = top },
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

/// The head (ui-champion.wasm), with the toolbar
pub const Top = struct {
    /// The shown view's
    data: *const TopData,
    /// The search's, by the page's roles (files.base[0])
    prep: []champsearch.Index,
    /// "../" from the page to the site root
    root: []const u8,
    /// The data file and its stamp, for ui.wasm
    src: []const u8 = "",
    stamp: u32 = 0,
    files: Files(TopData, champrank.Top) = .{},
    /// The fragment's (null: the main one)
    want_role: ?role.Role = null,
    /// Data.roles' index
    cur: u8 = 0,
    /// The narrow toolbar's choices shown
    open: bool = false,
    search: champsearch.ChampSearch = .{ .index = undefined, .id = "vs", .label = W.vs },
    has_search: bool = false,

    const P = @This();

    /// The section links: a plain `#build` would clear the fragment's role
    pub const Msg = union(enum) { jump: Section, region: Region, period: Period, rank: Rank, filters };
    pub const Section = enum { build, matchups, trends };

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        const w = &p.files.want;
        switch (m) {
            .jump => |x| {
                ev.handled = true;
                ev.after = .{ .op = .jump, .ref = @tagName(x) };
                return;
            },
            .region => |x| w.view = 2 * @as(u8, @backingInt(x)) + w.view % 2,
            .period => |x| w.view = w.view / 2 * 2 + @backingInt(x),
            .rank => |x| w.rank = x,
            .filters => {
                p.open = !p.open;
                return;
            },
        }
        ev.push = true;
    }

    /// The main role as written; fromUrl moves to the URL's
    pub fn init(data: *const TopData, prep: []champsearch.Index, root: []const u8) P {
        var p: P = .{ .data = data, .prep = prep, .root = root };
        p.files.base[0] = data;
        p.sync();
        return p;
    }

    /// `role` and the pick are every island's: each writes the same value
    pub const Url = struct {
        role: ?role.Role = null,
        region: Region = .euw,
        period: Period = .days30,
        rank: Rank = .plat,
    };

    fn r(p: *const P) *const TopRole {
        return &p.data.roles[p.cur];
    }

    pub fn toUrl(p: *const P) Url {
        const w = p.files.want;
        return .{ .role = p.want_role, .region = w.region(), .period = w.period(), .rank = w.rank };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.want_role = u.role;
        p.files.want = .of(u);
        p.sync();
    }

    fn sync(p: *P) void {
        p.cur = roleIndex(p.data.roles, p.want_role);
        const page = p.files.base[0].?.roles;
        p.has_search = false;
        for (page, 0..) |x, i| if (x.role == p.r().role and i < p.prep.len) {
            p.search.index = &p.prep[i];
            p.has_search = true;
        };
    }

    /// The loader's, once what files.want needs is in
    pub fn show(p: *P, _: std.mem.Allocator) void {
        p.files.shown = p.files.want;
        p.data = p.files.base[p.files.shown.view].?;
        p.sync();
    }

    /// The rank's figures of the role; null with too few games there
    fn ranked(p: *const P) ?*const TopRole {
        const g = p.files.group() orelse return p.r();
        return at(TopRole, g, p.r().role);
    }

    pub fn view(p: *P, h: *H) N {
        const d = p.data;
        const rl = p.r();
        const x = p.ranked();
        return h.div(.{
            .class = "part",
            .data_island = "champion",
            .data_src = if (p.src.len > 0) p.src else null,
            .data_stamp = p.stamp,
            .data_root = p.root,
            .data_busy = p.files.busy(),
            .data_thin = rl.thin or if (x) |y| p.files.shown.rank != .plat and y.games < solid_games else false,
        }, .{
            card.view(h, .{}, &.{
                champhead.view(h, .{
                    .champ = .{ .name = d.name, .src = d.icon },
                    .sub = W.sub.with(h, .{ .r = rl.role.label().s, .p = d.patch }),
                    .roles = p.roles(h),
                    .vs = if (p.has_search) p.search.view(h) else null,
                    .strip = if (x) |y| p.headline(h, y) else h.p(.{ .class = "none" }, .{W.few.with(h, .{ .r = W.ranks[@backingInt(p.files.shown.rank)].s })}),
                }),
                if (rl.thin) h.p(.{ .class = "rare" }, .{W.rare_role.with(h, .{ .c = d.name, .n = rl.games })}) else .none,
                tabs.view(h, W.sections, &.{
                    .{ .label = W.build, .href = "#build", .on = h.on(p, .{ .jump = .build }) },
                    .{ .label = W.matchups, .href = "#matchups", .on = h.on(p, .{ .jump = .matchups }), .n = if (p.files.shown.rank == .plat) @intCast(rl.lane.len) else if (x) |y| y.opps else null },
                    .{ .label = W.trends, .href = "#trends", .on = h.on(p, .{ .jump = .trends }) },
                }, &.{}),
                p.toolbar(h),
            }),
        });
    }

    fn toolbar(p: *P, h: *H) N {
        const w = p.files.want;
        const period = if (w.period() == .patch) tree.Text{ .s = p.data.patch } else W.days;
        var ranks: [W.ranks.len]segmented.Item = undefined;
        for (&ranks, W.ranks, 0..) |*it, l, i| it.* = .{ .label = l, .selected = @backingInt(w.rank) == i, .on = h.on(p, .{ .rank = @fromBackingInt(@intCast(i)) }) };
        return card.toolbar(h, &.{filterbar.view(h, .{
            .summary = W.picked.with(h, .{ .r = W.regions[@backingInt(w.region())].s, .p = period.s, .k = W.ranks[@backingInt(w.rank)].s }),
            .open = p.open,
            .on_toggle = h.on(p, .filters),
        }, &.{
            segmented.view(h, .{ .label = W.region }, &.{
                .{ .label = W.regions[0], .selected = w.region() == .euw, .on = h.on(p, .{ .region = .euw }) },
                .{ .label = W.regions[1], .selected = w.region() == .all, .on = h.on(p, .{ .region = .all }) },
            }),
            segmented.view(h, .{ .label = W.period }, &.{
                .{ .label = W.days, .selected = w.period() == .days30, .on = h.on(p, .{ .period = .days30 }) },
                .{ .label = .{ .s = p.data.patch }, .selected = w.period() == .patch, .on = h.on(p, .{ .period = .patch }) },
            }),
            segmented.view(h, .{ .label = W.rank_pick }, &ranks),
        })});
    }

    /// A role link keeps the pick
    const Frag = struct {
        u: Url,
        pub fn format(f: Frag, w: *std.Io.Writer) std.Io.Writer.Error!void {
            try url.write(Url, f.u, w);
        }
    };

    fn roles(p: *P, h: *H) N {
        var items: [role.Role.all.len]rolepicker.Item = undefined;
        const u = p.toUrl();
        for (role.Role.all, &items) |x, *it| {
            it.* = .{ .role = x, .disabled = true, .href = "#" };
            for (p.data.roles, 0..) |dr, i| if (dr.role == x) {
                var to = u;
                to.role = if (i == 0) null else x;
                it.* = .{
                    .role = x,
                    .share = dr.share,
                    .current = i == p.cur,
                    .href = h.fmt("#{f}", .{Frag{ .u = to }}),
                };
            };
        }
        return rolepicker.view(h, .{ .label = W.roles.with(h, .{ .c = p.data.name }) }, &items);
    }

    fn headline(p: *P, h: *H, rl: *const TopRole) N {
        const won = rate(.{ .games = rl.games, .wins = rl.wins });
        const games: strip.Item = .{ .label = W.games, .value = phrase.num(h, .count, rl.games) };
        if (p.files.shown.rank != .plat and rl.games < min_games) return strip.view(h, &.{games});
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
        items[n + 2] = games;
        return strip.view(h, items[0 .. n + 3]);
    }
};

/// Each role's build panel (null without a build), set up in place: its rows point into
/// it
pub fn panels(a: std.mem.Allocator, roles: []const BuildRole) ![]?buildpanel.BuildPanel {
    const out = try a.alloc(?buildpanel.BuildPanel, roles.len);
    for (out, roles) |*p, *r| {
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
    /// The shown view's
    data: *const BuildData,
    panels: []?buildpanel.BuildPanel,
    /// The shown rank group's, by its roles
    rpanels: []?buildpanel.BuildPanel = &.{},
    /// "../" from the page to the site root
    root: []const u8 = "",
    /// The data file and its stamp, for ui.wasm
    src: []const u8 = "",
    stamp: u32 = 0,
    /// The data inline instead (the matchup page's, base64): no file, no other views
    bin: ?[]const u8 = null,
    /// ui-champbuild.js and .wasm, for ui-champion.wasm to load
    js: ?[]const u8 = null,
    wasm: ?[]const u8 = null,
    files: Files(BuildData, champrank.Build) = .{},
    want_role: ?role.Role = null,
    /// Kept for a role without a build
    order: buildpanel.Order = .pick,
    /// Data.roles' index
    cur: u8 = 0,

    const P = @This();

    pub const Url = struct {
        role: ?role.Role = null,
        region: Region = .euw,
        period: Period = .days30,
        rank: Rank = .plat,
        slot: ?buildpanel.Kind = null,
        order: buildpanel.Order = .pick,
    };

    /// The shown rank's build of the role, else the base one
    fn panel(p: *P) ?*buildpanel.BuildPanel {
        const own = p.data.roles[p.cur].role;
        if (p.files.group()) |g| for (g, 0..) |x, i| if (x.role == own) {
            return if (p.rpanels[i]) |*b| b else null;
        };
        if (p.cur >= p.panels.len) return null;
        return if (p.panels[p.cur]) |*b| b else null;
    }

    /// Under a rank pick, the group the build is from when another
    fn from(p: *const P) ?u8 {
        const g = p.files.group() orelse return null;
        const x = at(BuildRole, g, p.data.roles[p.cur].role) orelse return 0;
        return if (x.from == @backingInt(p.files.shown.rank)) null else x.from;
    }

    pub fn toUrl(p: *P) Url {
        const w = p.files.want;
        const b = p.panel();
        return .{
            .role = p.want_role,
            .region = w.region(),
            .period = w.period(),
            .rank = w.rank,
            .slot = if (b) |x| x.open else null,
            .order = if (b) |x| x.order else p.order,
        };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.want_role = u.role;
        p.files.want = .of(u);
        p.cur = roleIndex(p.data.roles, u.role);
        p.order = u.order;
        if (p.panel()) |b| b.fromUrl(.{ .slot = u.slot, .order = u.order });
    }

    /// The loader's, once what files.want needs is in: the open slot stays open
    pub fn show(p: *P, a: std.mem.Allocator) void {
        const u = p.toUrl();
        p.files.shown = p.files.want;
        p.data = p.files.base[p.files.shown.view].?;
        p.panels = panels(a, p.data.roles) catch &.{};
        p.rpanels = if (p.files.group()) |g| panels(a, g) catch &.{} else &.{};
        p.fromUrl(u);
    }

    pub fn view(p: *P, h: *H) N {
        const note: N = if (p.from()) |g| h.p(.{ .class = "from" }, .{W.from.with(h, .{ .g = W.ranks[g].s, .r = W.ranks[@backingInt(p.files.shown.rank)].s })}) else .none;
        return h.div(.{
            .class = "part",
            .id = "build",
            .data_island = "champbuild",
            .data_src = if (p.src.len > 0) p.src else null,
            .data_stamp = if (p.bin == null) p.stamp else null,
            .data_root = if (p.bin == null) p.root else null,
            .data_bin = p.bin,
            .data_js = p.js,
            .data_wasm = p.wasm,
            .data_busy = p.files.busy(),
            .data_thin = p.data.roles[p.cur].thin,
        }, .{if (p.panel()) |b| card.view(h, .{ .flush = true }, &.{
            if (p.data.against) |y| card.head(h, W.build_against.with(h, .{ .y = y }), null, &.{}) else .none,
            note,
            b.view(h),
        }) else .none});
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
    files: Files(MoreData, champrank.More) = .{},
    want_role: ?role.Role = null,
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

    pub const Url = struct {
        role: ?role.Role = null,
        region: Region = .euw,
        period: Period = .days30,
        rank: Rank = .plat,
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
        const w = p.files.want;
        return .{
            .role = p.want_role,
            .region = w.region(),
            .period = w.period(),
            .rank = w.rank,
            .with = if (rel) |x| x.ally else false,
            .vs = if (rel) |x| (if (x.role == rl.role) null else x.role) else null,
            .by = p.measure,
        };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.want_role = u.role;
        p.files.want = .of(u);
        p.cur = roleIndex(p.data.roles, u.role);
        const own = p.r().role;
        p.rel = p.relOf(u.with, u.vs orelse if (u.with) partner(own) else own) orelse 0;
        p.measure = if (u.by == .gold and !p.goldShown()) .win else u.by;
        p.dots.sel = null;
    }

    /// The loader's, once what files.want needs is in
    pub fn show(p: *P, _: std.mem.Allocator) void {
        const u = p.toUrl();
        p.files.shown = p.files.want;
        p.data = p.files.base[p.files.shown.view].?;
        p.fromUrl(u);
    }

    /// The shown rank's figures of the role, for lane opponents and by patch; null at
    /// Platinum+ (Data's), .few without any
    fn ranked(p: *const P) ?Ranked {
        const g = p.files.group() orelse return null;
        return if (at(MoreRole, g, p.r().role)) |x| .{ .role = x } else .few;
    }

    const Ranked = union(enum) { role: *const MoreRole, few };

    /// On the cards that stay Platinum+ under a rank pick
    fn plat(p: *const P, h: *H) N {
        return if (p.files.shown.rank != .plat) badge.view(h, .neutral, .{W.plat}) else .none;
    }

    fn few(p: *const P, h: *H) N {
        return h.p(.{ .class = "none" }, .{W.few.with(h, .{ .r = W.ranks[@backingInt(p.files.shown.rank)].s })});
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
            .data_busy = p.files.busy(),
            .data_thin = p.r().thin,
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
        const lane = !rel.ally and rel.role == rl.role;
        var counts: Counts = .{ .games = rl.games, .wins = rl.wins };
        var opps = rel.opps;
        var rare = rel.rare;
        var few_games = false;
        if (lane) if (p.ranked()) |x| switch (x) {
            .few => few_games = true,
            .role => |y| {
                counts = .{ .games = y.games, .wins = y.wins };
                opps = if (y.rels.len > 0) y.rels[0].opps else &.{};
                rare = if (y.rels.len > 0) y.rels[0].rare else 0;
                few_games = y.games < min_games;
            },
        };
        const own = rate(counts);
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
            card.head(h, W.matchups, if (rare > 0) W.rare.with(h, .{ .n = count, .r = rare }) else phrase.num(h, .count, count), &.{ if (lane) .none else p.plat(h), controls[0], controls[1], controls[2] }),
            if (few_games) p.few(h) else h.div(.{ .class = "plot", .data_thin = p.files.shown.rank != .plat and counts.games < solid_games }, .{p.dots.view(h)}),
            if (chosen) |o| (if (few_games) .none else h.div(.{ .class = "brief" }, .{matchbrief.view(h, p.brief(h, rel, counts, o), chips[0..nc])})) else .none,
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

    fn brief(p: *const P, h: *H, rel: Rel, rl: Counts, o: Opp) matchbrief.Brief {
        const d = p.data;
        const own = rate(rl);
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
        const by_patch = if (p.ranked()) |x| switch (x) {
            .few => return card.view(h, .{}, &.{ card.head(h, W.by_patch, null, &.{}), p.few(h) }),
            .role => |y| y.by_patch,
        } else p.r().by_patch;
        const pts = h.mem.alloc(trend.Point, by_patch.len) catch {
            h.oom = true;
            return .none;
        };
        var n: usize = 0;
        for (by_patch) |x| {
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
        return card.view(h, .{}, &.{ card.head(h, W.by_length, null, &.{ p.plat(h), if (lean) |*x| h.span(.{ .class = "note" }, .{x}) else .none }), p.by_length.view(h) });
    }

    fn playersCard(p: *P, h: *H) N {
        const s = p.data.spread orelse return card.view(h, .{}, &.{ card.head(h, W.players, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        const tip = toggletip.view(h, "cp-spread", .{W.spread_head.with(h, .{ .n = s.players, .lo = s.p25, .hi = s.p75 })}, W.middle, W.spread_note.with(h, .{ .lo = s.luck_p25, .hi = s.luck_p75 }));
        return card.view(h, .{}, &.{
            card.head(h, W.players, null, &.{ p.plat(h), h.span(.{ .class = "note" }, .{&tip}) }),
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
                p.plat(h),
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
            card.head(h, title, null, &.{ p.plat(h), h.a(.{ .class = "more", .href = h.fmt("{s}pool.html#{s}", .{ p.root, d.slug }) }, .{W.pool}) }),
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
    \\  .c-cpage .c-toolbar { container-type: inline-size; margin-top: var(--sp-3); }
    \\  .c-cpage > [data-busy]:not([data-island=champion]), .c-cpage > [data-busy] .c-champhead { opacity: 0.55; transition: opacity 0.2s; }
    \\  .c-cpage [data-thin] .c-champhead > .c-strip, .c-cpage .plot[data-thin] { opacity: 0.6; }
    \\  .c-cpage > [data-thin] :is(.c-build > .in, .plot, .c-mpick, #trends .c-trend) { opacity: 0.6; }
    \\  .c-cpage .rare { margin: var(--sp-3) 0 0; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .c-champhead > .none { margin: 0 0 0 auto; }
    \\  .c-cpage .from { margin: 0; padding: var(--sp-3) var(--card-px) 0; font-size: var(--fs-s); color: var(--muted); }
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

test "a view's files sit beside the page's; rank files at the root" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const src = "../data/champion/darius-more.bin";
    try std.testing.expectEqualStrings("../all/patch/data/champion/darius-more.bin", try viewPath(a, src, "../", 3, false));
    try std.testing.expectEqualStrings("../data/champion/darius-more-rank-all.bin", try viewPath(a, src, "../", 2, true));
    try std.testing.expectEqualStrings("../data/champion/darius-more-rank.bin", try viewPath(a, src, "../", 0, true));
    const p: Pick = .of(Top.Url{ .region = .all, .period = .patch, .rank = .diamond });
    try std.testing.expectEqual(3, p.view);
    try std.testing.expectEqual(.all, p.region());
    try std.testing.expectEqual(.patch, p.period());
}

test "a rare role is listed and opens faded, with its games" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const d: TopData = .{ .name = "Karthus", .slug = "karthus", .icon = "", .patch = "16.21", .ddragon = "16.21.1", .champs = &.{}, .roles = &.{
        .{ .role = .jungle, .games = 9000, .wins = 4700, .share = 95, .pick = 4, .ban = 2, .lane = &.{} },
        .{ .role = .top, .games = 120, .wins = 55, .share = 1.3, .thin = true, .pick = 0.1, .ban = 2, .lane = &.{} },
    } };
    var p: Top = .init(&d, try prepare(a, &d, "../"), "../");
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "data-thin") == null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "Top") != null);

    p.fromUrl(.{ .role = .top });
    w.clearRetainingCapacity();
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "data-thin") != null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "<p class=\"rare\">A rare role for Karthus: 120 games.</p>") != null);
}
