//! The champion page (/champions/<slug>, /champions/<slug>/<role>): one champion in one
//! role (docs/plan/ui/champion.md), as three islands. Top: the head with the role picker,
//! the opponent search and the headline figures. Build: the build panel. More: the
//! matchups as a dot plot with the chosen opponent's brief; by patch, by game length and
//! the players' spread; pick-up and what its mains also play.
//!
//! The server renders the path's role (bare: the main role) from the same data the
//! page's data files carry (data/champion/<slug>.bin, -build.bin, -more.bin: `split`).
//! ui-champion.wasm adopts Top and fetches ui-champbuild.wasm and ui-champmore.wasm for
//! the others (one file would be over the 40 KB gz budget: stack.md). Role tabs are
//! links to the role's page; the islands see one fragment (role=, region=, ...), which
//! dom.zig's url_map spreads over the path, query and fragment.
//!
//! Top's toolbar picks the region, period and rank, kept beside the role:
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
const matchgrid = @import("matchgrid.zig");
const trend = @import("trend.zig");
const histogram = @import("histogram.zig");
const champlist = @import("champlist.zig");
const tiers = @import("tiers.zig");
const tabs = @import("tabs.zig");
const filterbar = @import("filterbar.zig");
const url = @import("url.zig");
const champrank = @import("champrank.zig");
const lane = @import("lane.zig");
const versus = @import("versus.zig");
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
    /// Riot's champion id: the pool link's
    id: u16 = 0,
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
    return .{ .name = c.name, .src = h.fmt(champ.icon_fmt, .{ ddragon, c.key }) };
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
    lane: ?LaneCurves = null,
    comeback: ?Comeback = null,
    kills: ?Kills = null,
    ranks: ?Ranks = null,
    timing: []const Timed = &.{},
    build: ?buildpanel.Data = null,
    /// Against or with each role: lane opponents first
    rels: []const Rel,
    by_patch: []const Patch,
    /// Data.lengths' buckets
    by_length: []const Counts,
};

pub const Counts = struct { games: u32, wins: u32 };

/// Games and wins in a bucket of minutes ("<10", "10-12", "16+")
pub const Timed = struct { label: []const u8, games: u32, wins: u32 };

/// The champion minus its lane opponent by minute, against the average one (all ranks)
pub const LaneCurves = struct {
    /// Lanes still going at each minute
    games: []const u32,
    /// Gold, XP, CS
    metrics: [3]LaneCurve,
};

/// Index i is minute i
pub const LaneCurve = struct {
    line: []const f32,
    /// The middle half of lanes
    band: []const [2]f32,
};

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
/// site/champrank.zig's suffixes, by view
const view_dirs = @import("urls.zig").view_dirs;
const view_queries = @import("urls.zig").view_queries;
const rank_suffixes = [n_views][]const u8{ "", "-patch", "-all", "-all-patch" };

/// Figures of a rank group's role under this many games are faded; under min_games, games
/// only (builds.md)
pub const solid_games = 400;
/// The lane chart's scale fits its first minutes, as the matchup page's: the band widens
/// far past the line later
const lane_fit = 20;
pub const min_games = 100;

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

pub const W = struct {
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
    pub const build_usual = Phrase("{x:text}'s build");
    pub const few_vs = Phrase("few games vs {y:text}");
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
    pub const lane_head = plain("Lane");
    pub const lane_them = "Opponent";
    pub const lane_term = plain("vs the average opponent");
    pub const lane_note = Phrase("{c:text} minus its lane opponent by minute, averaged over its opponents by games; the band holds the middle half of lanes. All ranks.");
    pub const lane_metrics = [3]tree.Text{ plain("Gold"), plain("XP"), plain("CS") };
    pub const comeback = plain("Won by lane gold");
    pub const comeback_at = plain("Minute");
    pub const comeback_mins = [2]tree.Text{ plain("10 min"), plain("15 min") };
    pub const comeback_buckets = [5]tree.Text{ plain("-1.5k"), plain("-1k"), plain("0"), plain("+1k"), plain("+1.5k") };
    pub const comeback_tip = Phrase("{l:text} at {m:text}: {r:rate} in {n:count} games, all lanes {a:rate}");
    pub const all_lanes = plain("dashed: all lanes");
    pub const kills_head = plain("Lane kills");
    pub const kills_them = "Opponent";
    pub const first_blood = plain("First blood");
    pub const kills = [3]tree.Text{ plain("Kills to 6 min"), plain("Kills 6-14 min"), plain("Kills after 14") };
    pub const by_rank = plain("By rank");
    pub const brackets = [3]tree.Text{ plain("Iron-Silver"), plain("Gold-Emerald"), plain("Diamond+") };
    pub const rank_tip = Phrase("{r:rate} in {n:count} games · gold at 14 {g:signed}");
    pub const rank_tip_thin = Phrase("{r:rate} in {n:count} games");
    pub const rank_key = plain("dashed: every rank");
    pub const rank_note = plain("Games by the middle rank of the players, when 5 or more are known. We crawl from Platinum up, so the lowest bracket is thin and the middle one mostly Platinum and Emerald.");
    pub const first_item = plain("First item done");
    pub const first_item_key = plain("dashed: games with an item");
    pub const first_item_note = Phrase("Win rate by the minute {c:text} finished its first item. Games that ended before one are left out; a quick item partly follows a game already going well.");
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

/// A Versus row of a and b in `games`, as the matchup page's head to head
fn share(h: *H, label: tree.Text, games: u32, a: u32, b: u32) versus.Row {
    const pa = rate(.{ .games = games, .wins = a });
    const pb = rate(.{ .games = games, .wins = b });
    const ra = @round(pa);
    const rb = @round(pb);
    return .{
        .label = label,
        .a = phrase.num(h, .pct, @as(u32, @intFromFloat(ra))),
        .b = phrase.num(h, .pct, @as(u32, @intFromFloat(rb))),
        .bars = .{ pa / 100, pb / 100 },
        .lead = if (ra > rb) .a else if (rb > ra) .b else null,
    };
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
    /// The matchup page's champion when the pair has too few games for its own build: its
    /// usual build instead, headed so
    usual_of: ?[]const u8 = null,
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
    id: u16 = 0,
    ddragon: []const u8,
    champs: []const Other,
    roles: []const MoreRole,
    lengths: []const []const u8,
    spread: ?Spread = null,
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

/// ui-champcharts.wasm's: the cards under the trends. Lane and comeback odds from every
/// rank, Pick-up and Also play from Platinum+ (whatever the rank pick)
pub const ChartsData = struct {
    name: []const u8,
    /// Riot's champion id: the pool link's
    id: u16 = 0,
    ddragon: []const u8,
    champs: []const Other,
    roles: []const ChartsRole,
    pickup: ?Pickup = null,
    also: []const Also = &.{},
};

pub const ChartsRole = struct {
    role: role.Role,
    lane: ?LaneCurves = null,
    comeback: ?Comeback = null,
    kills: ?Kills = null,
    ranks: ?Ranks = null,
    /// Platinum+, from the view's builds file
    timing: []const Timed = &.{},
};

/// Games and wins by the champion's lane gold lead at 10 and 15 minutes, in the curves'
/// buckets from 1,500+ behind to 1,500+ ahead; `all`: every lane in the role
pub const Comeback = struct {
    at: [2][5]Counts,
    all: [2][5]Counts,
};

/// Lanes where the champion took part in killing its lane opponent, and the other way,
/// in each phase (0-6, 6-14, 14+ min); first blood from games of curves files v6+
pub const Kills = struct {
    games: u32,
    first_blood: [2]u32,
    kills: [3]u32,
    deaths: [3]u32,
};

/// Games by the game's rank bracket (W.brackets: the curves' Iron-Silver, Gold-Emerald,
/// Diamond+ by the players' median tier)
pub const Ranks = struct {
    by: [3]Bracket,
    /// Every game in the role, those of no bracket too: the head's
    all: Counts,
};

pub const Bracket = struct {
    games: u32,
    wins: u32,
    /// Lead in gold at 14 minutes against the average opponent; null on too few lanes
    gold: ?i16 = null,
};

/// Files' rank type for the charts, which have no rank files
pub const NoRank = struct { groups: [1][]const ChartsRole };

pub const Split = struct { top: TopData, build: BuildData, more: MoreData, charts: ChartsData };

/// Each island's data, pointing into `d`
pub fn split(a: std.mem.Allocator, d: *const Data) !Split {
    const top = try a.alloc(TopRole, d.roles.len);
    const build = try a.alloc(BuildRole, d.roles.len);
    const more = try a.alloc(MoreRole, d.roles.len);
    const charts = try a.alloc(ChartsRole, d.roles.len);
    for (d.roles, top, build, more, charts) |x, *t, *b, *m, *c| {
        t.* = .{ .role = x.role, .games = x.games, .wins = x.wins, .share = x.share, .thin = x.thin, .rank = x.rank, .of = x.of, .pick = x.pick, .ban = x.ban, .patch_move = x.patch_move, .lane = if (x.rels.len > 0) x.rels[0].opps else &.{} };
        b.* = .{ .role = x.role, .thin = x.thin, .build = x.build };
        m.* = .{ .role = x.role, .thin = x.thin, .games = x.games, .wins = x.wins, .lean = x.lean, .rels = x.rels, .by_patch = x.by_patch, .by_length = x.by_length };
        c.* = .{ .role = x.role, .lane = x.lane, .comeback = x.comeback, .kills = x.kills, .ranks = x.ranks, .timing = x.timing };
    }
    return .{
        .top = .{ .name = d.name, .slug = d.slug, .icon = d.icon, .patch = d.patch, .ddragon = d.ddragon, .champs = d.champs, .roles = top },
        .build = .{ .roles = build },
        .more = .{ .name = d.name, .slug = d.slug, .id = d.id, .ddragon = d.ddragon, .champs = d.champs, .roles = more, .lengths = d.lengths, .spread = d.spread },
        .charts = .{ .name = d.name, .id = d.id, .ddragon = d.ddragon, .champs = d.champs, .roles = charts, .pickup = d.pickup, .also = d.also },
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
                .src = try std.fmt.allocPrint(a, champ.icon_fmt, .{ d.ddragon, c.key }),
                .href = if (o.page) try std.fmt.allocPrint(a, "{s}matchups/{s}/{s}-vs-{s}", .{ root, @tagName(r.role), d.slug, c.slug }) else null,
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

    /// A role tab's URL, keeping the pick: the role's page (bare for the main role), the
    /// view in the query, the rank in the fragment
    const RoleHref = struct {
        root: []const u8,
        slug: []const u8,
        role: ?role.Role,
        u: Url,
        pub fn format(l: RoleHref, w: *std.Io.Writer) std.Io.Writer.Error!void {
            try w.print("{s}champions/{s}", .{ l.root, l.slug });
            if (l.role) |x| try w.print("/{t}", .{x});
            try w.writeAll(view_queries[Pick.of(l.u).view]);
            if (l.u.rank == .plat) return;
            try w.writeByte('#');
            try url.write(Url, .{ .rank = l.u.rank }, w);
        }
    };

    fn roles(p: *P, h: *H) N {
        var items: [role.Role.all.len]rolepicker.Item = undefined;
        const u = p.toUrl();
        for (role.Role.all, &items) |x, *it| {
            it.* = .{ .role = x, .disabled = true, .href = "#" };
            for (p.data.roles, 0..) |dr, i| if (dr.role == x) {
                it.* = .{
                    .role = x,
                    .share = dr.share,
                    .current = i == p.cur,
                    .href = h.fmt("{f}", .{RoleHref{ .root = p.root, .slug = p.data.slug, .role = if (i == 0) null else x, .u = u }}),
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
            p.head(h),
            note,
            b.view(h),
        }) else .none});
    }

    fn head(p: *P, h: *H) N {
        const y = p.data.against orelse return .none;
        if (p.data.usual_of) |x| return card.head(h, W.build_usual.with(h, .{ .x = x }), null, &.{badge.view(h, .few, .{W.few_vs.with(h, .{ .y = y })})});
        return card.head(h, W.build_against.with(h, .{ .y = y }), null, &.{});
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
    grid: matchgrid.MatchupGrid = .{},
    by_patch: trend.Trend = .{ .label = W.by_patch, .points = &.{} },
    by_length: trend.Trend = .{ .label = W.by_length, .points = &.{} },

    const P = @This();

    pub const Msg = matchgrid.Msg;

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
        const rel = if (rl.rels.len > 0) rl.rels[p.grid.rel] else null;
        const w = p.files.want;
        return .{
            .role = p.want_role,
            .region = w.region(),
            .period = w.period(),
            .rank = w.rank,
            .with = if (rel) |x| x.ally else false,
            .vs = if (rel) |x| (if (x.role == rl.role) null else x.role) else null,
            .by = p.grid.measure,
        };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.want_role = u.role;
        p.files.want = .of(u);
        p.cur = roleIndex(p.data.roles, u.role);
        p.grid.set(&p.input(), u.with, u.vs, u.by);
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

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        p.grid.update(&p.input(), m);
        ev.push = true;
    }

    /// The grid's champion and role
    fn input(p: *const P) matchgrid.Input {
        const rl = p.r();
        return .{ .name = p.data.name, .slug = p.data.slug, .ddragon = p.data.ddragon, .champs = p.data.champs, .role = rl.role, .counts = .{ .games = rl.games, .wins = rl.wins }, .rels = rl.rels };
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
        });
    }

    fn matchups(p: *P, h: *H) N {
        var in = p.input();
        if (p.ranked()) |x| in.ranked = switch (x) {
            .few => .few,
            .role => |y| .{ .lane = .{ .counts = .{ .games = y.games, .wins = y.wins }, .opps = if (y.rels.len > 0) y.rels[0].opps else &.{}, .rare = if (y.rels.len > 0) y.rels[0].rare else 0 } },
        };
        in.plat = p.plat(h);
        in.few = p.few(h);
        in.faded = p.files.shown.rank != .plat;
        return p.grid.view(h, p, &in);
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
};

/// The charts under the trends (ui-champcharts.wasm, loaded by ui-champion.wasm). From
/// every rank: a rank pick changes nothing here
pub const Charts = struct {
    data: *const ChartsData,
    /// "../" from the page to the site root
    root: []const u8,
    /// The data file and its stamp, for ui.wasm
    src: []const u8 = "",
    stamp: u32 = 0,
    /// ui-champcharts.js and .wasm, for ui-champion.wasm to load
    js: ?[]const u8 = null,
    wasm: ?[]const u8 = null,
    files: Files(ChartsData, NoRank) = .{},
    want_role: ?role.Role = null,
    /// The URL's, given back to it: files.want stays at Platinum+
    rank: Rank = .plat,
    /// Data.roles' index
    cur: u8 = 0,
    lane: lane.Lane = .{ .a = "", .b = W.lane_them, .metrics = &.{}, .select = false },
    /// lane's, pointed at the shown role's curves on each view
    lane_metrics: [3]lane.Metric = undefined,
    comeback: trend.Trend = .{ .label = W.comeback, .points = &.{} },
    pickup: trend.Trend = .{ .label = W.pickup, .points = &.{}, .height = 110 },
    ranks: trend.Trend = .{ .label = W.by_rank, .points = &.{} },
    timing: trend.Trend = .{ .label = W.first_item, .points = &.{} },
    /// Comeback.at's index: 10 or 15 minutes
    at: u8 = 0,

    const P = @This();

    pub const Msg = union(enum) { at: u8 };

    pub const Url = struct {
        role: ?role.Role = null,
        region: Region = .euw,
        period: Period = .days30,
        rank: Rank = .plat,
    };

    fn r(p: *const P) *const ChartsRole {
        return &p.data.roles[p.cur];
    }

    pub fn toUrl(p: *const P) Url {
        const w = p.files.want;
        return .{ .role = p.want_role, .region = w.region(), .period = w.period(), .rank = p.rank };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.want_role = u.role;
        p.rank = u.rank;
        p.files.want = .{ .view = Pick.of(u).view };
        p.cur = roleIndex(p.data.roles, u.role);
    }

    /// The loader's, once what files.want needs is in
    pub fn show(p: *P, _: std.mem.Allocator) void {
        const u = p.toUrl();
        p.files.shown = p.files.want;
        p.data = p.files.base[p.files.shown.view].?;
        p.fromUrl(u);
    }

    pub fn update(p: *P, m: Msg, _: *tree.Event) void {
        switch (m) {
            .at => |i| if (i < W.comeback_mins.len) {
                p.at = i;
            },
        }
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{
            .class = "part",
            .data_island = "champcharts",
            .data_src = if (p.src.len > 0) p.src else null,
            .data_stamp = p.stamp,
            .data_root = p.root,
            .data_js = p.js,
            .data_wasm = p.wasm,
            .data_busy = p.files.busy(),
        }, .{
            h.div(.{ .class = "row2" }, .{ p.laneCard(h), p.comebackCard(h) }),
            h.div(.{ .class = "row2" }, .{ p.pickupCard(h), p.alsoCard(h) }),
            h.div(.{ .class = "row3" }, .{ p.killsCard(h), p.rankCard(h), p.timingCard(h) }),
        });
    }

    /// On Pick-up and Also play under a rank pick: they stay Platinum+
    fn plat(p: *const P, h: *H) N {
        return if (p.rank != .plat) badge.view(h, .neutral, .{W.plat}) else .none;
    }

    fn laneCard(p: *P, h: *H) N {
        const c = p.r().lane orelse return card.view(h, .{}, &.{ card.head(h, W.lane_head, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        for (&p.lane_metrics, c.metrics, W.lane_metrics) |*m, x, l| m.* = .{ .label = l, .fit = lane_fit, .s = .{ .line = x.line, .band = x.band } };
        p.lane.a = p.data.name;
        p.lane.metrics = &p.lane_metrics;
        p.lane.games = c.games;
        const tip = toggletip.view(h, "cp-lane", .{W.lane_term}, W.lane_head, W.lane_note.with(h, .{ .c = p.data.name }));
        return card.view(h, .{}, &.{ card.head(h, W.lane_head, null, &.{ h.span(.{ .class = "note" }, .{&tip}), p.lane.switcher(h) }), p.lane.view(h) });
    }

    fn comebackCard(p: *P, h: *H) N {
        const none = card.view(h, .{}, &.{ card.head(h, W.comeback, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        const c = p.r().comeback orelse return none;
        const pts = h.mem.alloc(trend.Point, 5) catch {
            h.oom = true;
            return .none;
        };
        const base = h.mem.alloc(f32, 5) catch {
            h.oom = true;
            return .none;
        };
        var n: usize = 0;
        var all = true;
        for (c.at[p.at], c.all[p.at], W.comeback_buckets) |b, a, l| {
            if (b.games == 0) continue;
            pts[n] = .{
                .label = l,
                .sub = phrase.num(h, .kilo, b.games),
                .v = rate(b),
                .ci = ci(b),
                .tip = W.comeback_tip.with(h, .{ .l = l.s, .m = W.comeback_mins[p.at].s, .r = rate(b), .n = b.games, .a = rate(a) }),
            };
            base[n] = rate(a);
            all = all and a.games > 0;
            n += 1;
        }
        if (n < 2) return none;
        p.comeback.points = pts[0..n];
        p.comeback.base = if (all) base[0..n] else &.{};
        if (p.comeback.tip) |t| if (t >= n) {
            p.comeback.tip = null;
        };
        var items: [2]segmented.Item = undefined;
        for (&items, W.comeback_mins, 0..) |*x, l, i| x.* = .{ .label = l, .selected = i == p.at, .on = h.on(p, .{ .at = @as(u8, @intCast(i)) }) };
        const key: N = if (p.comeback.base.len > 0) h.span(.{ .class = "lg" }, .{W.all_lanes}) else .none;
        return card.view(h, .{}, &.{
            card.head(h, W.comeback, null, &.{ key, segmented.view(h, .{ .s = .s, .label = W.comeback_at }, &items) }),
            p.comeback.view(h),
        });
    }

    /// Share of lanes with each, the champion against the average opponent
    fn killsCard(p: *P, h: *H) N {
        const k = p.r().kills orelse return card.view(h, .{}, &.{ card.head(h, W.kills_head, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        var rows: [4]versus.Row = undefined;
        var n: usize = 0;
        // Curves files from before v6 have none: no row rather than 0%
        if (k.first_blood[0] + k.first_blood[1] > 0) {
            rows[n] = share(h, W.first_blood, k.games, k.first_blood[0], k.first_blood[1]);
            n += 1;
        }
        for (W.kills, k.kills, k.deaths) |l, x, y| {
            rows[n] = share(h, l, k.games, x, y);
            n += 1;
        }
        const names: [2][]const u8 = .{ p.data.name, W.kills_them };
        return card.view(h, .{}, &.{ card.head(h, W.kills_head, null, &.{versus.key(h, names)}), versus.rows(h, names, rows[0..n]) });
    }

    /// Win rate by rank bracket, dashed at its rate over every game (the head's); brackets under
    /// min_games left out
    fn rankCard(p: *P, h: *H) N {
        const none = card.view(h, .{}, &.{ card.head(h, W.by_rank, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        const k = p.r().ranks orelse return none;
        const pts = h.mem.alloc(trend.Point, k.by.len) catch {
            h.oom = true;
            return .none;
        };
        var n: usize = 0;
        for (k.by, W.brackets) |b, l| {
            if (b.games < min_games) continue;
            const c: Counts = .{ .games = b.games, .wins = b.wins };
            pts[n] = .{
                .label = l,
                .sub = phrase.num(h, .kilo, b.games),
                .v = rate(c),
                .ci = ci(c),
                .tip = if (b.gold) |g| W.rank_tip.with(h, .{ .r = rate(c), .n = b.games, .g = @as(i32, g) }) else W.rank_tip_thin.with(h, .{ .r = rate(c), .n = b.games }),
            };
            n += 1;
        }
        if (n < 2) return none;
        p.ranks.points = pts[0..n];
        p.ranks.ref = rate(k.all);
        if (p.ranks.tip) |t| if (t >= n) {
            p.ranks.tip = null;
        };
        const tip = toggletip.view(h, "cp-rank", .{W.rank_key}, W.by_rank, W.rank_note);
        return card.view(h, .{}, &.{ card.head(h, W.by_rank, null, &.{h.span(.{ .class = "note" }, .{&tip})}), p.ranks.view(h) });
    }

    /// Win rate by the minute the first item was finished, dashed at the rate over every
    /// bucket; buckets under min_games left out
    fn timingCard(p: *P, h: *H) N {
        const none = card.view(h, .{}, &.{ card.head(h, W.first_item, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        const k = p.r().timing;
        const pts = h.mem.alloc(trend.Point, k.len) catch {
            h.oom = true;
            return .none;
        };
        var all: Counts = .{ .games = 0, .wins = 0 };
        var n: usize = 0;
        for (k) |b| {
            const c: Counts = .{ .games = b.games, .wins = b.wins };
            all.games += b.games;
            all.wins += b.wins;
            if (b.games < min_games) continue;
            pts[n] = .{
                .label = .{ .s = b.label },
                .sub = phrase.num(h, .kilo, b.games),
                .v = rate(c),
                .ci = ci(c),
                .tip = W.length_tip.with(h, .{ .l = b.label, .r = rate(c), .n = b.games }),
            };
            n += 1;
        }
        if (n < 2) return none;
        p.timing.points = pts[0..n];
        p.timing.ref = rate(all);
        if (p.timing.tip) |t| if (t >= n) {
            p.timing.tip = null;
        };
        const tip = toggletip.view(h, "cp-item", .{W.first_item_key}, W.first_item, W.first_item_note.with(h, .{ .c = p.data.name }));
        return card.view(h, .{}, &.{ card.head(h, W.first_item, null, &.{ p.plat(h), h.span(.{ .class = "note" }, .{&tip}) }), p.timing.view(h) });
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
                .href = h.fmt("{s}champions/{s}", .{ p.root, c.slug }),
                .tag = if (a.harder) badge.view(h, .neutral, .{W.harder}) else null,
                .value = h.span(.{}, .{W.lift.with(h, .{ .x = a.lift })}),
                .note = W.share.with(h, .{ .s = @as(u32, @intFromFloat(@round(a.share))) }),
            };
        }
        const title = W.also.with(h, .{ .c = d.name });
        return card.view(h, .{}, &.{
            card.head(h, title, null, &.{ p.plat(h), h.a(.{ .class = "more", .href = h.fmt("{s}pool?champs={d}", .{ p.root, d.id }) }, .{W.pool}) }),
            if (rows.len > 0) champlist.view(h, .{ .label = title }, rows) else h.p(.{ .class = "none" }, .{W.none}),
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-cpage, .c-cpage > .part { display: flex; flex-direction: column; gap: var(--sp-4); }
    \\  .c-cpage > .part:empty { display: none; }
    \\  .c-cpage .c-card > .c-tabs { margin-top: var(--sp-4); }
    \\  .c-cpage [id] { scroll-margin-top: calc(var(--header) + var(--sp-3)); }
    \\  .c-cpage .c-toolbar { container-type: inline-size; margin-top: var(--sp-3); }
    \\  @media (min-width: 1100px) {
    \\    .c-cpage [data-island=champion] > .c-card { display: grid; grid-template-columns: auto minmax(0, 1fr); }
    \\    .c-cpage [data-island=champion] > .c-card > :not(.c-tabs, .c-toolbar) { grid-column: 1 / -1; }
    \\    .c-cpage [data-island=champion] > .c-card > :is(.c-tabs, .c-toolbar) { margin-bottom: calc(-1 * var(--card-py)); }
    \\    .c-cpage [data-island=champion] > .c-card > .c-tabs { margin-right: 0; box-shadow: none; }
    \\    .c-cpage [data-island=champion] > .c-card > .c-toolbar { margin: var(--sp-4) calc(-1 * var(--card-px)) calc(-1 * var(--card-py)) 0;
    \\      padding-block: 0; background: none; border: 0; justify-content: flex-end; }
    \\    .c-cpage [data-island=champion] .c-toolbar > .c-filters { flex: none; }
    \\  }
    \\  .c-cpage > [data-busy]:not([data-island=champion]), .c-cpage > [data-busy] .c-champhead { opacity: 0.55; transition: opacity 0.2s; }
    \\  .c-cpage [data-thin] .c-champhead > .c-strip, .c-cpage .plot[data-thin] { opacity: 0.6; }
    \\  .c-cpage > [data-thin] :is(.c-build > .in, .plot, .c-mpick, #trends .c-trend) { opacity: 0.6; }
    \\  .c-cpage .rare { margin: var(--sp-3) 0 0; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .c-champhead > .none { margin: 0 0 0 auto; }
    \\  .c-cpage .from { margin: 0; padding: var(--sp-3) var(--card-px) 0; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .none { margin: var(--sp-3) 0; color: var(--muted); }
    \\  .c-cpage .note { margin-left: auto; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .c-head .lg { margin-left: auto; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .more { margin-left: auto; font-size: var(--fs-s); }
    \\  .c-cpage .plot { padding: var(--sp-1) 0 var(--sp-3); }
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
    const src = "/data/champion/darius-more.bin";
    try std.testing.expectEqualStrings("/_v/all-patch/data/champion/darius-more.bin", try viewPath(a, src, "/", 3, false));
    try std.testing.expectEqualStrings("/data/champion/darius-more-rank-all.bin", try viewPath(a, src, "/", 2, true));
    try std.testing.expectEqualStrings("/data/champion/darius-more-rank.bin", try viewPath(a, src, "/", 0, true));
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
    var p: Top = .init(&d, try prepare(a, &d, "/"), "/");
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

test "by rank: brackets under min_games left out, no chart under two" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var roles = [_]ChartsRole{.{ .role = .top, .ranks = .{ .by = .{
        .{ .games = 40, .wins = 20 },
        .{ .games = 900, .wins = 470, .gold = 120 },
        .{ .games = 300, .wins = 140 },
    }, .all = .{ .games = 1600, .wins = 800 } } }};
    const d: ChartsData = .{ .name = "Darius", .ddragon = "", .champs = &.{}, .roles = &roles };
    var p: Charts = .{ .data = &d, .root = "/" };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "Iron-Silver") == null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "Gold-Emerald") != null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "Diamond+") != null);
    // Dashed at every game's rate, not the brackets' sum's (50.8%)
    try std.testing.expectEqual(@as(f32, 50), p.ranks.ref);

    roles[0].ranks.?.by[2].games = 99;
    w.clearRetainingCapacity();
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "Gold-Emerald") == null);
}

test "first item done: buckets under min_games left out, no chart under two" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var timing = [_]Timed{
        .{ .label = "<9", .games = 99, .wins = 60 },
        .{ .label = "9-11", .games = 900, .wins = 470 },
        .{ .label = "11+", .games = 300, .wins = 140 },
    };
    var roles = [_]ChartsRole{.{ .role = .top, .timing = &timing }};
    const d: ChartsData = .{ .name = "Darius", .ddragon = "", .champs = &.{}, .roles = &roles };
    var p: Charts = .{ .data = &d, .root = "/" };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "&lt;9") == null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "9-11") != null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "11+") != null);

    timing[2].games = 99;
    w.clearRetainingCapacity();
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "9-11") == null);
}
