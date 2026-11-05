//! The champion page (/champions/<slug>, /champions/<slug>/<role>): one champion in one
//! role (docs/plan/ui/champion.md), as five islands. Top: the head with the role picker,
//! the opponent search and the headline figures. Build: the build panel. More: the
//! matchups as a dot plot with the chosen opponent's brief. Trends: by patch, by game
//! length, the players' spread, by rank, first item done. Charts: lane, comeback odds,
//! pick-up, also play, lane kills, objectives.
//!
//! The server renders the path's role (bare: the main role) from the same data the
//! page's data files carry (data/champion/<slug>.bin, -build, -more, -trends, -charts:
//! `split`). ui-champion.wasm adopts Top and fetches the other islands' wasm as they near
//! the screen (one file would be over the 40 KB gz budget: stack.md). Role tabs are
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
const stat = @import("stat.zig");
const winrate = @import("rate.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const card = @import("card.zig");
const badge = @import("badge.zig");
const chip = @import("chip.zig");
const bar = @import("bar.zig");
const strip = @import("strip.zig");
const toggletip = @import("toggletip.zig");
const hint = @import("tip.zig");
const segmented = @import("segmented.zig");
const rolepicker = @import("rolepicker.zig");
const champsearch = @import("champsearch.zig");
const champhead = @import("champhead.zig");
const buildpanel = @import("buildpanel.zig");
const lockbar = @import("lockbar.zig");
const art = @import("art.zig");
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
const objicon = @import("objicon.zig");
const ranking = @import("ranking.zig");
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
    /// P Q W E R; empty without Data Dragon's file
    abilities: []const art.Art = &.{},
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
    /// Riot's champion id: an opponent lock's value
    id: u16 = 0,
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
    objectives: ?Objectives = null,
    ranks: ?Ranks = null,
    ends: ?Ends = null,
    timing: []const Timed = &.{},
    places: Places = .{},
    build: ?buildpanel.Data = null,
    /// BuildRole's
    build_patch: ?[]const u8 = null,
    build_older: bool = false,
    /// Against or with each role: lane opponents first
    rels: []const Rel,
    by_patch: []const Patch,
    /// The newest patch by day, oldest first
    by_day: []const Day = &.{},
    /// Data.lengths' buckets
    by_length: []const Counts,
};

pub const Counts = struct { games: u32, wins: u32 };

/// Its place in a ranking (ui.ranking) of the role's champions, the view's; n 0: under
/// its games floor. href: the ranking, the champion in its fragment
pub const Place = struct { n: u16, of: u16, href: []const u8 };

/// By urls.Stat: Platinum+ only, so a rank group's files have none
pub const Places = struct { ahead: ?Place = null, behind: ?Place = null, long_games: ?Place = null, lane_gold: ?Place = null };

pub const Day = struct {
    /// The day of the month ("24"); tip: "24 Oct"
    label: []const u8,
    tip: []const u8,
    games: u32,
    wins: u32,
};

/// Games and wins in a bucket of minutes ("<10", "10-12", "16+")
pub const Timed = struct { label: []const u8, games: u32, wins: u32 };

/// The champion minus its lane opponent by minute, against the average one (all ranks)
/// A lane opponent and the gold lead at 14 on one side (the list says whose)
pub const LaneOpp = struct { champ: u16, gold: u16 };

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
/// site root from the page. Trends has no rank file of its own: More's holds by patch
pub fn viewPath(a: std.mem.Allocator, src: []const u8, root: []const u8, v: u8, rank: bool) ![]const u8 {
    if (src.len < root.len + ".bin".len) return error.BadPath;
    const rest = src[root.len..];
    if (rank) {
        var stem = rest[0 .. rest.len - ".bin".len];
        const more = std.mem.endsWith(u8, stem, "-trends");
        if (more) stem = stem[0 .. stem.len - "-trends".len];
        return std.mem.concat(a, u8, &.{ root, stem, if (more) "-more" else "", "-rank", rank_suffixes[v], ".bin" });
    }
    return std.mem.concat(a, u8, &.{ root, view_dirs[v], rest });
}

/// Lock answers' directory under a view's (site/locks.zig)
pub const lock_prefix = "data/lock/";

/// View `v`'s lock answer for `island` (site/locks.zig Island) of `slug` in role `r` at
/// rank `k` under `lk`, a lock set as lockanswer.Locks.format writes it
pub fn lockPath(a: std.mem.Allocator, root: []const u8, v: u8, island: []const u8, slug: []const u8, r: role.Role, k: Rank, lk: []const u8) ![]const u8 {
    return std.mem.concat(a, u8, &.{ root, view_dirs[v], lock_prefix, island, "/", slug, "/", @tagName(r), "/", @tagName(k), "/", lk, ".bin" });
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
    /// The build panel has no opponent pick: the head's search is it (walk-rivals 6)
    pub const vs_hint = plain("Against one champion? Pick them in “vs opponent” at the top for their build.");
    pub const won = plain("Win rate");
    pub const rank = Phrase("{n:int}{th:text} of {of:int} in {r:text}");
    pub const place = Phrase("{l:text}: {n:int}{th:text} of {of:int} ›");
    pub const place_thin = Phrase("{l:text}: unsure, few games ›");
    pub const pick = plain("Pick");
    pub const ban = plain("Ban");
    pub const games = plain("Games");
    pub const move = Phrase("{p:text} change");
    pub const nth = Phrase("{n:int}{th:text}");
    pub const move_note = plain("Its win rate on this patch minus the previous one.");
    pub const matchups = plain("Matchups");
    pub const sections = plain("Sections");
    pub const build = plain("Build");
    pub const build_against = Phrase("Build against {y:text}");
    pub const build_usual = Phrase("{x:text}'s build");
    pub const no_lock_games = plain("No games with these locks.");
    pub const vs_lock = Phrase("vs {y:text}");
    /// Until Trends and the lane charts follow the locks (champion-locks.md L4, L5)
    pub const lock_scope = plain("Not Trends yet");
    /// The StatStrip under locks: their games out of the champion-role's
    pub const lock_share = plain("Of its games");
    pub const no_answer = plain("These locks can't be counted here yet.");
    pub const few_vs = Phrase("few games vs {y:text}");
    pub const trends = plain("Trends");
    pub const rare = Phrase("{n:count} · +{r:count} rare");
    pub const against = plain("Against");
    pub const with = plain("With");
    pub const rel_label = plain("Matchups against or with");
    pub const measure_label = plain("Placed by");
    pub const m_win = plain("Win rate");
    pub const m_usual = plain("Vs usual");
    pub const below_usual = plain("below its usual");
    pub const above_usual = plain("above its usual");
    pub const m_gold = plain("Gold at 14");
    pub const usual_note = Phrase("How much more or less often than usual {c:text} won, allowing for the other champion's own win rate in its role; pulled toward 0 the fewer the games.");
    pub const opponent = Phrase("{r:text} opponent");
    pub const ally = Phrase("{r:text} ally");
    pub const wins = Phrase("{c:text} wins");
    pub const none = plain("Not enough games yet.");
    pub const by_patch = plain("By patch");
    pub const by_day = Phrase("{p:text} by day");
    pub const span = plain("Patches or days");
    pub const patches = plain("Patches");
    pub const by_days = plain("Days");
    pub const by_length = plain("By game length");
    pub const lean = Phrase("Early lean {g:signed} gold");
    pub const lean_note = plain("Gold at 14 minutes against an average lane opponent, from games of every length: whether it wins lanes, apart from how long its games last.");
    pub const lane_head = plain("Lane");
    pub const lane_them = "Opponent";
    pub const lane_ends = [2]tree.Text{ plain("Wins lane against"), plain("Loses lane to") };
    pub const lane_ends_unit = plain("gold at 14");
    pub const lane_win = Phrase("{c:text} {g:count} gold ahead of {o:text} at 14");
    pub const lane_loss = Phrase("{o:text} {g:count} gold ahead at 14");
    pub const lane_term = plain("vs the average opponent");
    pub const lane_note = Phrase("{c:text} minus its lane opponent by minute, over all its opponents; the band holds the middle half of lanes. All ranks.");
    pub const lane_metrics = [3]tree.Text{ plain("Gold"), plain("XP"), plain("CS") };
    pub const comeback = plain("Won by lane gold");
    pub const comeback_at = plain("Minute");
    pub const comeback_mins = [2]tree.Text{ plain("10 min"), plain("15 min") };
    pub const comeback_buckets = [5]tree.Text{ plain("-1.5k"), plain("-1k"), plain("0"), plain("+1k"), plain("+1.5k") };
    pub const comeback_tip = Phrase("at {m:text}: {r:rate} in {n:count} games, all lanes {a:rate}");
    pub const all_lanes = plain("dashed: all lanes");
    pub const kills_head = plain("Lane kills");
    pub const kills_them = plain("Opponent");
    pub const kills_y = plain("lanes with a kill");
    pub const lanes_n = Phrase("{n:count} lanes");
    pub const first_blood = plain("First blood");
    pub const kills = [3]tree.Text{ plain("by 6 min"), plain("6-14 min"), plain("14+ min") };
    pub const objectives_head = plain("Objectives");
    pub const firsts = [4]tree.Text{ plain("First tower"), plain("First dragon"), plain("First Voidgrubs"), plain("First Rift Herald") };
    pub const obj_kinds = [4]objicon.Kind{ .tower, .dragon, .grubs, .herald };
    pub const obj_rows = [2]tree.Text{ plain("Took it first"), plain("Win rate if first") };
    pub const games_n = Phrase("{n:count} games");
    pub const took_tip = Phrase("{l:text}: {c:text}'s team took it in {r:rate} of {n:count} games; role average {a:rate}");
    pub const obj_key = plain("│ role average");
    pub const won_tip = Phrase("{l:text}: {c:text}'s team won {r:rate} of {n:count} games after taking it; role average {a:rate}");
    pub const by_rank = plain("By rank");
    pub const brackets = [3]tree.Text{ plain("Iron-Silver"), plain("Gold-Emerald"), plain("Diamond+") };
    pub const rank_tip = Phrase("{r:rate} in {n:count} games · gold at 14 {g:signed}, estimated from common matchups");
    pub const rank_key = plain("dashed: all games");
    pub const rank_note = plain("Games by the middle rank of the players, when 5 or more are known. We crawl from Platinum up, so the lowest bracket is thin and the middle one mostly Platinum and Emerald.");
    pub const ends_head = plain("End of game");
    pub const ends_rows = [9]tree.Text{ plain("Kills"), plain("Deaths"), plain("Assists"), plain("Level"), plain("Gold / min"), plain("Damage / min"), plain("Taken / min"), plain("CS / min"), plain("Vision / min") };
    pub const ends_of = Phrase("of {of:int} champions");
    pub const ends_note = Phrase("Averages over {n:count} games. Each place is among the role's {of:int} champions in the table, highest first, deaths too.");
    pub const ends_lo = plain("lowest");
    pub const ends_hi = plain("highest");
    pub const ends_place = Phrase("{n:int}{th:text} highest of {of:int}");
    pub const first_item = plain("First item done");
    pub const first_item_key = plain("dashed: games with an item");
    pub const win_rate_y = plain("win rate");
    pub const first_item_note = Phrase("Win rate by the minute {c:text} finished its first item. Games that ended before one are left out; a quick item partly follows a game already going well. Finished means a legendary that builds into nothing, so tear items such as Manamune never count.");
    pub const players = plain("Players");
    pub const spread_head = Phrase("{n:count} · middle half {lo:pct}-{hi:pct}");
    pub const spread_note = Phrase("Players with 10+ games on it. Luck alone would spread the middle half over {lo:pct}-{hi:pct}.");
    pub const middle = plain("middle half");
    pub const pickup = plain("Pick-up");
    pub const pickup_head = Phrase("{a:rate} new → {b:rate} practised · gap {g:dec}, usual {u:dec}");
    pub const pickup_note = plain("New: under 30k mastery points; practised: 100k+. Every champion rises with practice: the usual gap is the average.");
    pub const harder = plain("harder to pick up");
    pub const hard = plain("hard");
    pub const easier = plain("easier to pick up");
    pub const also = Phrase("{c:text} mains also play");
    pub const lift = Phrase("{x:dec}× as often");
    pub const share = Phrase("{s:pct}");
    pub const also_tip = Phrase("{d:text}: {s:pct} of {c:text} mains play it, {x:dec}× as often as other players");
    pub const also_tip_hard = Phrase("{d:text}: {s:pct} of {c:text} mains play it, {x:dec}× as often as other players. Harder to pick up");
    pub const pool = plain("Pool");
    /// A chart point's tip, after its name
    pub const rate_tip = Phrase("{r:rate} in {n:count} games");
    pub const min_tip = Phrase("min: {r:rate} in {n:count} games");
    pub const few = Phrase("Too few games at {r:text}.");
    pub const rare_role = Phrase("A rare role for {c:text}: {n:count} games.");
    pub const from = Phrase("Build from {g:text} games: too few at {r:text}.");
    pub const build_patch = Phrase("Patch {p:text}");
    pub const from_older = plain("Too few games on this patch yet");
    pub const from_patch = plain("From this patch, not the 30 days picked");
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

/// Vs usual's sign in words; none when it shows as 0.0
pub fn usualSide(v: f32, below: tree.Text, above: tree.Text) ?tree.Text {
    if (@abs(v) < 0.05) return null;
    return if (v < 0) below else above;
}

fn round(pct: f32) u32 {
    return @intFromFloat(@round(pct));
}

fn rate(c: Counts) f32 {
    return trend.rate(c.games, c.wins);
}

/// A Versus row of a's and b's rates, as the matchup page's head to head
fn rates(h: *H, label: tree.Text, a: Counts, b: Counts) versus.Row {
    return versus.shares(h, label, rate(a) / 100, rate(b) / 100);
}

/// A chart point of c's win rate, its games under the label
fn point(h: *H, label: tree.Text, c: Counts) trend.Point {
    return trend.point(h, label, c.games, c.wins, W.rate_tip.with(h, .{ .r = rate(c), .n = c.games }));
}

/// A card with nothing to show under its head
fn noneCard(h: *H, title: tree.Text, foot: N) N {
    return card.view(h, .{}, &.{ card.head(h, title, null, &.{}), h.p(.{ .class = "none" }, .{W.none}), foot });
}

/// A head's note with its Toggletip
fn tipNote(h: *H, id: []const u8, shown: tree.Text, title: tree.Text, body: tree.Text) N {
    const tip = toggletip.view(h, id, .{shown}, title, body);
    return h.span(.{ .class = "note" }, .{&tip});
}

/// A stat's switch label, at comptime: a runtime spec() would pull every stat's strings
/// into the island
fn short(comptime s: ranking.Stat) []const u8 {
    return comptime ranking.spec(s).short;
}

/// A card's foot: its places in the rankings of what it shows, each a link there
fn places(h: *H, ps: []const struct { []const u8, ?Place }) N {
    var kids = h.list();
    for (ps, 0..) |x, i| {
        const pl = x[1] orelse continue;
        const l = x[0];
        kids.add(h.a(.{ .key = i, .href = pl.href }, .{if (pl.n == 0) W.place_thin.with(h, .{ .l = l }) else W.place.with(h, .{ .l = l, .n = pl.n, .th = ordinal(pl.n), .of = pl.of })}));
    }
    if (kids.items.items.len == 0) return .none;
    return h.p(.{ .class = "places" }, .{kids.done()});
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
    abilities: []const art.Art = &.{},
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
    /// A lock answer's opponent (`vs`), for the LockBar's chip
    vs: ?Vs = null,
};

pub const Vs = struct { id: u16, name: []const u8, icon: []const u8 };

pub const BuildRole = struct {
    role: role.Role,
    thin: bool = false,
    build: ?buildpanel.Data = null,
    /// A rank file's: the group the build is from (Rank's index), when this one has too
    /// few games
    from: u8 = 0,
    /// The patch its games are from when not the view's: the previous one's (`older`,
    /// this patch's too thin) or, on a matchup page in a 30-day view, the patch's
    patch: ?[]const u8 = null,
    older: bool = false,
};

/// ui-champmore.wasm's: the matchups
pub const MoreData = struct {
    name: []const u8,
    slug: []const u8,
    ddragon: []const u8,
    champs: []const Other,
    roles: []const MoreRole,
};

/// Also the rank files' (ui.champrank.More), which carry by patch and by day for the
/// Trends island
pub const MoreRole = struct {
    role: role.Role,
    thin: bool = false,
    games: u32,
    wins: u32,
    rels: []const Rel,
    by_patch: []const Patch = &.{},
    by_day: []const Day = &.{},
};

/// ui-champtrends.wasm's: by patch, by game length, players, pick-up, also play, by rank,
/// first item done. A rank pick changes by patch alone (the More island's rank file)
pub const TrendsData = struct {
    name: []const u8,
    /// Riot's champion id: the pool link's
    id: u16 = 0,
    ddragon: []const u8,
    champs: []const Other,
    roles: []const TrendsRole,
    lengths: []const []const u8,
    spread: ?Spread = null,
    pickup: ?Pickup = null,
    also: []const Also = &.{},
};

pub const TrendsRole = struct {
    role: role.Role,
    thin: bool = false,
    games: u32,
    wins: u32,
    lean: ?i16 = null,
    by_patch: []const Patch,
    by_day: []const Day = &.{},
    by_length: []const Counts,
    long_games: ?Place = null,
    ranks: ?Ranks = null,
    ends: ?Ends = null,
    /// Platinum+, from the view's builds file
    timing: []const Timed = &.{},
};

/// ui-champcharts.wasm's: the lane and early game. Lane, comeback odds and lane kills
/// from every rank, objectives from Platinum+ (whatever the rank pick)
pub const ChartsData = struct {
    name: []const u8,
    /// The portrait's URL
    icon: []const u8 = "",
    /// The matchup links'
    slug: []const u8 = "",
    ddragon: []const u8,
    champs: []const Other,
    roles: []const ChartsRole,
};

pub const ChartsRole = struct {
    role: role.Role,
    lane: ?LaneCurves = null,
    /// Lane opponents it wins lane against most, then those it loses lane to most, by gold
    /// at 14 (u.gg's Best Lane Counters; walk-rivals 5)
    lanes: [2][]const LaneOpp = .{ &.{}, &.{} },
    comeback: ?Comeback = null,
    kills: ?Kills = null,
    /// Platinum+, from the view's builds file
    objectives: ?Objectives = null,
    ahead: ?Place = null,
    behind: ?Place = null,
    lane_gold: ?Place = null,
};

/// Games with a timeline, then those whose team took each objective first (W.firsts'
/// order) and their wins; `role`: every champion in the role
pub const Objectives = struct {
    mine: [5]Counts,
    role: [5]Counts,
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

/// End-of-game averages in the role (the view's games, Platinum+), each with its place
/// among the role's champions table (rare picks left out) that have such games; the
/// card shows none under min_games
pub const Ends = struct {
    games: u32,
    of: u16,
    /// W.ends_rows' order: per game to Level, per minute after
    rows: [9]EndRow,
};

pub const EndRow = struct {
    v: f32,
    /// Highest first; 0: a rare pick in the role, so not placed
    rank: u16,
};

/// Ends.rows shown as whole numbers (gold, damage and taken a minute)
pub const ends_whole = [9]bool{ false, false, false, false, true, true, true, false, false };

pub const Bracket = struct {
    games: u32,
    wins: u32,
    /// Lead in gold at 14 minutes against the average opponent; null on too few lanes
    gold: ?i16 = null,
};

/// Files' rank type for the charts, which have no rank files
pub const NoRank = struct { groups: [1][]const ChartsRole };

pub const Split = struct { top: TopData, build: BuildData, more: MoreData, trends: TrendsData, charts: ChartsData };

/// Lanes the champion wins and loses by most at 14 minutes: thin pairs and small leads out
/// (the curves shrink a thin pair toward the champions' baseline already)
fn laneEnds(a: std.mem.Allocator, r: role.Role, rels: []const Rel) ![2][]const LaneOpp {
    const rel = for (rels) |x| {
        if (!x.ally and x.role == r) break x;
    } else return .{ &.{}, &.{} };
    var all: std.ArrayList(Opp) = .empty;
    for (rel.opps) |o| if (o.gold) |g| if (o.games >= thin_games and @abs(g) >= lane_end_gold) try all.append(a, o);
    std.mem.sort(Opp, all.items, {}, struct {
        fn f(_: void, x: Opp, y: Opp) bool {
            return x.gold.? > y.gold.?;
        }
    }.f);
    var out: [2][]LaneOpp = .{ try a.alloc(LaneOpp, lane_ends), try a.alloc(LaneOpp, lane_ends) };
    var n: [2]usize = .{ 0, 0 };
    for (0..all.items.len) |i| {
        // Wins from the top, losses from the bottom
        for ([2]Opp{ all.items[i], all.items[all.items.len - 1 - i] }, 0..) |o, k| {
            if (n[k] == lane_ends or (o.gold.? > 0) != (k == 0)) continue;
            out[k][n[k]] = .{ .champ = o.champ, .gold = @abs(o.gold.?) };
            n[k] += 1;
        }
    }
    return .{ out[0][0..n[0]], out[1][0..n[1]] };
}

const lane_ends = 5;
/// Under this a lane reads as even
const lane_end_gold = 100;

/// Each island's data, pointing into `d`
pub fn split(a: std.mem.Allocator, d: *const Data) !Split {
    const top = try a.alloc(TopRole, d.roles.len);
    const build = try a.alloc(BuildRole, d.roles.len);
    const more = try a.alloc(MoreRole, d.roles.len);
    const trends = try a.alloc(TrendsRole, d.roles.len);
    const charts = try a.alloc(ChartsRole, d.roles.len);
    for (d.roles, top, build, more, trends, charts) |x, *t, *b, *m, *tr, *c| {
        t.* = .{ .role = x.role, .games = x.games, .wins = x.wins, .share = x.share, .thin = x.thin, .rank = x.rank, .of = x.of, .pick = x.pick, .ban = x.ban, .patch_move = x.patch_move, .lane = if (x.rels.len > 0) x.rels[0].opps else &.{} };
        b.* = .{ .role = x.role, .thin = x.thin, .build = x.build, .patch = x.build_patch, .older = x.build_older };
        m.* = .{ .role = x.role, .thin = x.thin, .games = x.games, .wins = x.wins, .rels = x.rels };
        tr.* = .{ .role = x.role, .thin = x.thin, .games = x.games, .wins = x.wins, .lean = x.lean, .by_patch = x.by_patch, .by_day = x.by_day, .by_length = x.by_length, .long_games = x.places.long_games, .ranks = x.ranks, .ends = x.ends, .timing = x.timing };
        c.* = .{ .role = x.role, .lane = x.lane, .lanes = try laneEnds(a, x.role, x.rels), .comeback = x.comeback, .kills = x.kills, .objectives = x.objectives, .ahead = x.places.ahead, .behind = x.places.behind, .lane_gold = x.places.lane_gold };
    }
    return .{
        .top = .{ .name = d.name, .slug = d.slug, .icon = d.icon, .patch = d.patch, .ddragon = d.ddragon, .champs = d.champs, .abilities = d.abilities, .roles = top },
        .build = .{ .roles = build },
        .more = .{ .name = d.name, .slug = d.slug, .ddragon = d.ddragon, .champs = d.champs, .roles = more },
        .trends = .{ .name = d.name, .id = d.id, .ddragon = d.ddragon, .champs = d.champs, .roles = trends, .lengths = d.lengths, .spread = d.spread, .pickup = d.pickup, .also = d.also },
        .charts = .{ .name = d.name, .icon = d.icon, .slug = d.slug, .ddragon = d.ddragon, .champs = d.champs, .roles = charts },
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
    /// The champion page's locks (`lk`): the StatStrip shows the renderer's answer for
    /// them (lockPath), fetched by ui-champion.wasm
    locks: lockbar.Set = .{},
    /// The answer shown and its path; roles empty: none for the path
    answer: ?*const TopData = null,
    answer_path: []const u8 = "",
    /// The server's answer under `locks`, base64 (Build.ans)
    ans: ?[]const u8 = null,

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
        lk: url.Str(200) = .{},
    };

    fn r(p: *const P) *const TopRole {
        return &p.data.roles[p.cur];
    }

    fn shownAnswer(p: *const P) ?*const TopData {
        return if (p.locks.any()) p.answer else null;
    }

    /// The answer the locks want, null without locks
    pub fn lockWant(p: *const P, a: std.mem.Allocator) ?[]const u8 {
        if (!p.locks.any() or p.cur >= p.data.roles.len) return null;
        const w = p.files.want;
        return lockPath(a, p.root, w.view, "top", p.data.slug, p.data.roles[p.cur].role, w.rank, p.locks.s.slice()) catch null;
    }

    pub fn setAnswer(p: *P, path: []const u8, d: *const TopData) void {
        p.answer = d;
        p.answer_path = path;
    }

    fn waiting(p: *const P, a: std.mem.Allocator) bool {
        const w = p.lockWant(a) orelse return false;
        return !std.mem.eql(u8, w, p.answer_path);
    }

    pub fn toUrl(p: *const P) Url {
        const w = p.files.want;
        return .{ .role = p.want_role, .region = w.region(), .period = w.period(), .rank = w.rank, .lk = p.locks.s };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.want_role = u.role;
        p.files.want = .of(u);
        p.locks.s = u.lk;
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
            .data_busy = p.files.busy() or p.waiting(h.mem),
            .data_lk = if (p.ans != null) p.locks.s.slice() else null,
            .data_ans = p.ans,
        }, .{
            card.view(h, .{}, &.{
                champhead.view(h, .{
                    .champ = .{ .name = d.name, .src = d.icon },
                    .sub = W.sub.with(h, .{ .r = rl.role.label().s, .p = d.patch }),
                    .abilities = d.abilities,
                    .roles = p.roles(h),
                    .vs = if (p.has_search) p.search.view(h) else null,
                    .strip = if (p.shownAnswer()) |y| p.locked(h, y, x) else if (x) |y| p.headline(h, y) else h.p(.{ .class = "none" }, .{W.few.with(h, .{ .r = W.ranks[@backingInt(p.files.shown.rank)].s })}),
                }),
                if (rl.thin) h.p(.{ .class = "rare" }, .{W.rare_role.with(h, .{ .c = d.name, .n = rl.games })}) else .none,
                tabs.view(h, W.sections, &.{
                    .{ .label = W.build, .href = "#build", .on = h.on(p, .{ .jump = .build }) },
                    .{ .label = W.matchups, .href = "#matchups", .on = h.on(p, .{ .jump = .matchups }), .n = if (p.shownAnswer() != null) null else if (p.files.shown.rank == .plat) @intCast(rl.lane.len) else if (x) |y| y.opps else null },
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

    /// Under locks: the answer's games and win rate, and their share of the rank's games
    /// in the role (`all`, null with too few there). Pick, ban, rank and the patch's
    /// move are the champion's, not the locks'
    fn locked(_: *P, h: *H, d: *const TopData, all: ?*const TopRole) N {
        if (d.roles.len == 0 or d.roles[0].games == 0) return h.p(.{ .class = "none" }, .{if (d.roles.len == 0) W.no_answer else W.no_lock_games});
        const x = d.roles[0];
        var items: [2]strip.Item = undefined;
        var n: usize = 0;
        items[n] = .{ .label = W.won, .rate = winrate.view(h, .counted(x.games, x.wins), .{ .said = "" }), .answer = true };
        n += 1;
        // The two count different tables (lock rows, views): never past all of them
        if (all) |y| if (y.games > 0) {
            const share = @min(100, 100 * @as(f32, @floatFromInt(x.games)) / @as(f32, @floatFromInt(y.games)));
            items[n] = .{ .label = W.lock_share, .value = phrase.num(h, .rate, share) };
            n += 1;
        };
        return strip.view(h, items[0..n]);
    }

    fn headline(p: *P, h: *H, rl: *const TopRole) N {
        var items: [4]strip.Item = undefined;
        var n: usize = 0;
        items[n] = .{
            .label = W.won,
            .rate = winrate.view(h, .counted(rl.games, rl.wins), .{ .said = "" }),
            .ctx = if (rl.rank > 0) W.rank.with(h, .{ .n = rl.rank, .th = ordinal(rl.rank), .of = rl.of, .r = rl.role.label().s }) else null,
            .answer = true,
        };
        n += 1;
        if (rl.patch_move) |m| {
            items[n] = .{
                .label = W.move.with(h, .{ .p = p.data.patch }),
                .rate = winrate.delta(h, m[0], m[1]),
                .tip = .{ .id = "cp-move", .note = W.move_note },
            };
            n += 1;
        }
        items[n] = .{ .label = W.pick, .value = phrase.num(h, .rate, rl.pick) };
        items[n + 1] = .{ .label = W.ban, .value = phrase.num(h, .rate, rl.ban) };
        return strip.view(h, items[0 .. n + 2]);
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
    /// The champion page's locks (`lk`): the build shown is the renderer's answer for
    /// them (lockPath), fetched by ui-champbuild.wasm
    locks: lockbar.Set = .{},
    /// Its `set` points at `locks` from each view
    bar: lockbar.LockBar = .{ .set = undefined },
    /// The answer shown and its path; roles empty: none for the path
    answer: ?*const BuildData = null,
    answer_path: []const u8 = "",
    apanel: ?buildpanel.BuildPanel = null,
    /// The server's: the answer it rendered under `locks`, base64, for ui-champbuild.wasm
    /// to hydrate from without asking again
    ans: ?[]const u8 = null,

    const P = @This();

    pub const Url = struct {
        role: ?role.Role = null,
        region: Region = .euw,
        period: Period = .days30,
        rank: Rank = .plat,
        slot: ?buildpanel.Kind = null,
        order: buildpanel.Order = .pick,
        /// The locked keystone (BuildPanel's): the matchup page's; on the champion
        /// page an old link's, read as lk's keystone
        k: ?u32 = null,
        lk: url.Str(200) = .{},
    };

    /// The champion page under locks (the matchup page has none)
    fn locked(p: *const P) bool {
        return p.bin == null and p.locks.any();
    }

    /// The answer shown under locks, once one is in
    fn shownAnswer(p: *const P) ?*const BuildData {
        return if (p.locked()) p.answer else null;
    }

    /// The answer the locks want, null without locks
    pub fn lockWant(p: *const P, a: std.mem.Allocator) ?[]const u8 {
        if (!p.locked() or p.cur >= p.data.roles.len) return null;
        const w = p.files.want;
        return lockPath(a, p.root, w.view, "build", p.slug(), p.data.roles[p.cur].role, w.rank, p.locks.s.slice()) catch null;
    }

    /// From the page's data file: data/champion/<slug>-build.bin
    fn slug(p: *const P) []const u8 {
        const base = p.src[if (std.mem.findScalarLast(u8, p.src, '/')) |i| i + 1 else 0..];
        return if (std.mem.endsWith(u8, base, "-build.bin")) base[0 .. base.len - "-build.bin".len] else base;
    }

    /// Shows `d`, the answer at `path`: the open slot and order stay
    pub fn setAnswer(p: *P, a: std.mem.Allocator, path: []const u8, d: *const BuildData) void {
        const u = p.toUrl();
        p.answer = d;
        p.answer_path = path;
        p.apanel = null;
        if (d.roles.len > 0) if (panels(a, d.roles[0..1])) |ps| {
            p.apanel = ps[0];
        } else |_| {};
        p.fromUrl(u);
    }

    /// The shown rank's build of the role, else the base one; under locks the answer's
    fn panel(p: *P) ?*buildpanel.BuildPanel {
        if (p.shownAnswer() != null) return if (p.apanel) |*b| b else null;
        const own = p.data.roles[p.cur].role;
        if (p.files.group()) |g| for (g, 0..) |x, i| if (x.role == own) {
            return if (p.rpanels[i]) |*b| b else null;
        };
        if (p.cur >= p.panels.len) return null;
        return if (p.panels[p.cur]) |*b| b else null;
    }

    /// The shown rank's BuildRole, else the base one
    fn shownRole(p: *const P) ?*const BuildRole {
        if (p.shownAnswer()) |x| return if (x.roles.len > 0) &x.roles[0] else null;
        const own = p.data.roles[p.cur].role;
        if (p.files.group()) |g| return at(BuildRole, g, own);
        return if (p.cur < p.data.roles.len) &p.data.roles[p.cur] else null;
    }

    /// Under a rank pick, the group the build is from when another
    fn from(p: *const P) ?u8 {
        if (p.files.group() == null or p.shownAnswer() != null) return null;
        const x = p.shownRole() orelse return 0;
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
            .k = if (p.bin == null) null else if (b) |x| x.runes.locked() else null,
            .lk = p.locks.s,
        };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.want_role = u.role;
        p.files.want = .of(u);
        p.cur = roleIndex(p.data.roles, u.role);
        p.order = u.order;
        p.locks.s = if (p.bin == null) u.lk else .{};
        if (p.bin == null) if (u.k) |k| if (p.locks.get(.keystone) == null) {
            var buf: [lockbar.value_max]u8 = undefined;
            p.locks.toggle(.keystone, lockbar.text(&buf, &.{k}));
        };
        if (p.panel()) |b| {
            b.setLocks(if (p.bin == null) &p.locks else null);
            b.fromUrl(.{ .slot = u.slot, .order = u.order, .k = if (p.bin == null) null else u.k });
        }
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
        const b = p.panel();
        if (b) |x| x.setLocks(if (p.bin == null) &p.locks else null);
        const want = p.lockWant(h.mem);
        const waiting = if (want) |w| !std.mem.eql(u8, w, p.answer_path) else false;
        const answer = p.shownAnswer();
        p.bar.set = &p.locks;
        p.bar.scope = W.lock_scope;
        p.bar.games = null;
        if (!waiting) if (answer) |x| {
            p.bar.games = 0;
            if (x.roles.len > 0) if (x.roles[0].build) |d| {
                p.bar.games = d.games;
                p.bar.wins = d.wins;
            };
        };
        const lock_bar: N = if (p.locked()) p.bar.view(h, p.labels(h)) else .none;
        var empty: N = .none;
        if (b == null) if (answer) |x| {
            empty = h.p(.{ .class = "none" }, .{if (x.roles.len == 0) W.no_answer else W.no_lock_games});
        };
        const note: N = if (p.from()) |g| h.p(.{ .class = "from" }, .{W.from.with(h, .{ .g = W.ranks[g].s, .r = W.ranks[@backingInt(p.files.shown.rank)].s })}) else .none;
        // Opens below: the card clips above its top edge
        const patch: N = if (p.shownRole()) |x| if (x.patch) |v| hint.view(
            h,
            if (x.older) W.from_older else W.from_patch,
            .{chip.view(h, .{ .v = .scope }, .{W.build_patch.with(h, .{ .p = v })})},
            .{ .below = true, .end = p.data.against != null },
        ) else .none else .none;
        return h.div(.{
            .class = "part",
            .id = "build",
            .tabindex = @as(i8, -1),
            .role = "region",
            .aria_label = W.build,
            .data_island = "champbuild",
            .data_src = if (p.src.len > 0) p.src else null,
            .data_stamp = if (p.bin == null) p.stamp else null,
            .data_root = if (p.bin == null) p.root else null,
            .data_bin = p.bin,
            .data_js = p.js,
            .data_wasm = p.wasm,
            .data_busy = p.files.busy() or waiting,
            .data_lk = if (p.ans != null) p.locks.s.slice() else null,
            .data_ans = p.ans,
        }, .{ lock_bar, if (b != null or answer != null) card.view(h, .{ .flush = true }, &.{
            p.head(h, patch),
            empty,
            note,
            if (p.data.against == null and patch != .none) h.div(.{ .class = "from" }, .{patch}) else .none,
            if (b) |x| x.view(h) else .none,
            if (p.data.against == null) h.p(.{ .class = "vs-hint" }, .{W.vs_hint}) else .none,
        }) else .none });
    }

    /// The LockBar's chips: each lock as its option draws it in the shown build or
    /// the page's
    fn labels(p: *P, h: *H) []const lockbar.Label {
        var out: std.ArrayList(lockbar.Label) = .empty;
        const shown = if (p.shownAnswer()) |x| buildOf(x.roles, 0) else null;
        const base = buildOf(p.data.roles, p.cur);
        for (std.enums.values(lockbar.Kind)) |k| {
            const v = p.locks.get(k) orelse continue;
            const l = (if (k == .opponent) p.vsLabel(h, v) else if (shown) |d| lockLabel(h, d, k, v) else null) orelse (if (base) |d| lockLabel(h, d, k, v) else null) orelse lockbar.Label{ .kind = k, .text = v };
            out.append(h.mem, l) catch {
                h.oom = true;
                break;
            };
        }
        return out.items;
    }

    /// The opponent as the last answer names it (kept while the next one is out)
    fn vsLabel(p: *const P, h: *H, v: []const u8) ?lockbar.Label {
        const x = (p.answer orelse return null).vs orelse return null;
        var buf: [lockbar.value_max]u8 = undefined;
        if (!std.mem.eql(u8, lockbar.text(&buf, &.{x.id}), v)) return null;
        const a = h.mem.alloc(art.Art, 1) catch return null;
        a[0] = .{ .name = x.name, .src = x.icon };
        return .{ .kind = .opponent, .art = a, .text = W.vs_lock.with(h, .{ .y = x.name }).s };
    }

    fn head(p: *P, h: *H, patch: N) N {
        const y = p.data.against orelse return .none;
        if (p.data.usual_of) |x| return card.head(h, W.build_usual.with(h, .{ .x = x }), null, &.{ badge.view(h, .few, .{W.few_vs.with(h, .{ .y = y })}), patch });
        return card.head(h, W.build_against.with(h, .{ .y = y }), null, &.{patch});
    }
};

fn buildOf(roles: []const BuildRole, i: usize) ?*const buildpanel.Data {
    if (i >= roles.len) return null;
    return if (roles[i].build) |*d| d else null;
}

/// Lock `k` on `v` as `d` draws it: a rune's art, an option's icons or keys
fn lockLabel(h: *H, d: *const buildpanel.Data, k: lockbar.Kind, v: []const u8) ?lockbar.Label {
    switch (k) {
        .keystone, .rune => {
            const id = std.fmt.parseInt(u32, v, 10) catch return null;
            for (d.runes.trees) |t| for (t.rows) |row| for (row) |*r| if (r.id == id) {
                return .{ .kind = k, .art = (&r.art)[0..1], .text = r.art.name };
            };
            return null;
        },
        .shard => {
            var it = std.mem.splitScalar(u8, v, '.');
            const row = std.fmt.parseInt(usize, it.next() orelse return null, 10) catch return null;
            const id = std.fmt.parseInt(u32, it.next() orelse return null, 10) catch return null;
            if (row >= d.runes.shards.len) return null;
            for (d.runes.shards[row]) |*r| if (r.id == id) return .{ .kind = k, .art = (&r.art)[0..1], .text = r.art.name };
            return null;
        },
        .spells, .start, .boots, .core3, .item4, .item5, .item6, .skills, .skill_path => {
            const want: buildpanel.Kind = switch (k) {
                .core3 => .core,
                inline .spells, .start, .boots, .item4, .item5, .item6, .skills, .skill_path => |x| @field(buildpanel.Kind, @tagName(x)),
                else => unreachable,
            };
            for (d.slots) |s| if (s.kind == want) for (s.options) |o| if (std.mem.eql(u8, lockbar.value(h.mem, o.v), v)) {
                const text: []const u8 = switch (k) {
                    .skills => h.fmt("Max {s}", .{o.keys}),
                    .skill_path => "Level path",
                    .item4 => "Item 4",
                    .item5 => "Item 5",
                    .item6 => "Item 6",
                    else => "",
                };
                return .{ .kind = k, .art = o.art, .text = text };
            };
            return null;
        },
        else => return null,
    }
}

/// The matchups (ui-champmore.wasm, loaded by ui-champion.wasm)
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
    /// The champion page's locks (`lk`): the matchups shown are the renderer's answer
    /// for them (lockPath), fetched by ui-champmore.wasm
    locks: lockbar.Set = .{},
    /// The answer shown and its path; roles empty: none for the path
    answer: ?*const MoreData = null,
    answer_path: []const u8 = "",
    /// The server's answer under `locks`, base64 (Build.ans)
    ans: ?[]const u8 = null,

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
        lk: url.Str(200) = .{},
    };

    /// The data's role, or under locks the answer's once one is in
    fn r(p: *const P) *const MoreRole {
        if (p.shownAnswer()) |x| if (x.roles.len > 0) return &x.roles[0];
        return &p.data.roles[p.cur];
    }

    fn shownAnswer(p: *const P) ?*const MoreData {
        return if (p.locks.any()) p.answer else null;
    }

    /// The answer the locks want, null without locks
    pub fn lockWant(p: *const P, a: std.mem.Allocator) ?[]const u8 {
        if (!p.locks.any() or p.cur >= p.data.roles.len) return null;
        const w = p.files.want;
        return lockPath(a, p.root, w.view, "more", p.data.slug, p.data.roles[p.cur].role, w.rank, p.locks.s.slice()) catch null;
    }

    /// Shows `d`, the answer at `path`: the grid's rel and measure stay
    pub fn setAnswer(p: *P, _: std.mem.Allocator, path: []const u8, d: *const MoreData) void {
        const u = p.toUrl();
        p.answer = d;
        p.answer_path = path;
        p.fromUrl(u);
    }

    fn waiting(p: *const P, a: std.mem.Allocator) bool {
        const w = p.lockWant(a) orelse return false;
        return !std.mem.eql(u8, w, p.answer_path);
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
            .lk = p.locks.s,
        };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.want_role = u.role;
        p.files.want = .of(u);
        p.cur = roleIndex(p.data.roles, u.role);
        p.locks.s = u.lk;
        p.grid.set(&p.input(), u.with, u.vs, u.by);
    }

    /// The loader's, once what files.want needs is in
    pub fn show(p: *P, _: std.mem.Allocator) void {
        const u = p.toUrl();
        p.files.shown = p.files.want;
        p.data = p.files.base[p.files.shown.view].?;
        p.fromUrl(u);
    }

    /// The shown rank's figures of the role, for lane opponents; null at Platinum+
    /// (Data's) and under locks (the answer is the rank's), .few without any
    fn ranked(p: *const P) ?Ranked {
        if (p.shownAnswer() != null) return null;
        const g = p.files.group() orelse return null;
        return if (at(MoreRole, g, p.r().role)) |x| .{ .role = x } else .few;
    }

    const Ranked = union(enum) { role: *const MoreRole, few };

    /// On the cards that stay Platinum+ under a rank pick (an answer is the rank's)
    fn plat(p: *const P, h: *H) N {
        return if (p.files.shown.rank != .plat and p.shownAnswer() == null) badge.view(h, .neutral, .{W.plat}) else .none;
    }

    fn few(p: *const P, h: *H) N {
        return h.p(.{ .class = "none" }, .{W.few.with(h, .{ .r = W.ranks[@backingInt(p.files.shown.rank)].s })});
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        ev.push = true;
        if (m == .lock) {
            var buf: [lockbar.value_max]u8 = undefined;
            return p.locks.toggle(.opponent, lockbar.text(&buf, &.{p.data.champs[m.lock].id}));
        }
        p.grid.update(&p.input(), m);
    }

    /// Data.champs' index of the locked opponent
    fn lockedOpp(p: *const P) ?u16 {
        const v = p.locks.get(.opponent) orelse return null;
        const id = std.fmt.parseInt(u16, v, 10) catch return null;
        for (p.data.champs, 0..) |c, i| if (c.id == id) return @intCast(i);
        return null;
    }

    /// The grid's champion and role
    fn input(p: *const P) matchgrid.Input {
        const rl = p.r();
        return .{ .name = p.data.name, .slug = p.data.slug, .ddragon = p.data.ddragon, .champs = p.data.champs, .role = rl.role, .counts = .{ .games = rl.games, .wins = rl.wins }, .rels = rl.rels, .lock = .{ .on = p.lockedOpp() }, .finder = true };
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
            .data_busy = p.files.busy() or p.waiting(h.mem),
            .data_lk = if (p.ans != null) p.locks.s.slice() else null,
            .data_ans = p.ans,
        }, .{
            p.matchups(h),
        });
    }

    fn matchups(p: *P, h: *H) N {
        if (p.shownAnswer()) |x| if (x.roles.len == 0 or x.roles[0].games == 0) {
            return card.view(h, .{ .id = "matchups", .target = true, .label = W.matchups }, &.{ card.head(h, W.matchups, null, &.{}), h.p(.{ .class = "none" }, .{if (x.roles.len == 0) W.no_answer else W.no_lock_games}) });
        };
        var in = p.input();
        if (p.ranked()) |x| in.ranked = switch (x) {
            .few => .few,
            .role => |y| .{ .lane = .{ .counts = .{ .games = y.games, .wins = y.wins }, .opps = if (y.rels.len > 0) y.rels[0].opps else &.{}, .rare = if (y.rels.len > 0) y.rels[0].rare else 0 } },
        };
        in.plat = p.plat(h);
        in.few = p.few(h);
        return p.grid.view(h, p, &in);
    }
};

/// By patch, by game length, players, pick-up, also play, by rank and first item done
/// (ui-champtrends.wasm, loaded by ui-champion.wasm). A rank pick changes by patch, from
/// the More island's rank file; the rest say Platinum+ or are from every rank
pub const Trends = struct {
    data: *const TrendsData,
    /// "../" from the page to the site root
    root: []const u8,
    /// The data file and its stamp, for ui.wasm
    src: []const u8 = "",
    stamp: u32 = 0,
    /// ui-champtrends.js and .wasm, for ui-champion.wasm to load
    js: ?[]const u8 = null,
    wasm: ?[]const u8 = null,
    files: Files(TrendsData, champrank.More) = .{},
    want_role: ?role.Role = null,
    /// Data.roles' index
    cur: u8 = 0,
    by_patch: trend.Trend = .{ .label = W.by_patch, .points = &.{} },
    span: Span = .{},
    by_length: trend.Trend = .{ .label = W.by_length, .points = &.{} },
    ranks: trend.Trend = .{ .label = W.by_rank, .points = &.{} },
    timing: trend.Trend = .{ .label = W.first_item, .points = &.{}, .y_name = W.win_rate_y },
    pickup: trend.Trend = .{ .label = W.pickup, .points = &.{}, .height = 110 },

    const P = @This();

    /// The By patch card's: the last patches, or the newest one by day
    const Span = struct {
        days: bool = false,

        pub const Msg = enum { patches, days };

        pub fn update(s: *Span, m: Span.Msg, _: *tree.Event) void {
            s.days = m == .days;
        }
    };

    pub const Msg = union(enum) {};

    pub const Url = struct {
        role: ?role.Role = null,
        region: Region = .euw,
        period: Period = .days30,
        rank: Rank = .plat,
    };

    fn r(p: *const P) *const TrendsRole {
        return &p.data.roles[p.cur];
    }

    pub fn toUrl(p: *const P) Url {
        const w = p.files.want;
        return .{ .role = p.want_role, .region = w.region(), .period = w.period(), .rank = w.rank };
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.want_role = u.role;
        p.files.want = .of(u);
        p.cur = roleIndex(p.data.roles, u.role);
    }

    /// The loader's, once what files.want needs is in
    pub fn show(p: *P, _: std.mem.Allocator) void {
        const u = p.toUrl();
        p.files.shown = p.files.want;
        p.data = p.files.base[p.files.shown.view].?;
        p.fromUrl(u);
    }

    pub fn update(_: *P, m: Msg, _: *tree.Event) void {
        switch (m) {}
    }

    /// The shown rank's role, for by patch; null at Platinum+, .few without one
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

    pub fn view(p: *P, h: *H) N {
        return h.div(.{
            .class = "part",
            .data_island = "champtrends",
            .data_src = if (p.src.len > 0) p.src else null,
            .data_stamp = p.stamp,
            .data_root = p.root,
            .data_js = p.js,
            .data_wasm = p.wasm,
            .data_busy = p.files.busy(),
        }, .{
            h.div(.{ .class = "row3", .id = "trends", .tabindex = @as(i8, -1), .role = "region", .aria_label = W.trends }, .{ p.patchCard(h), p.lengthCard(h), p.playersCard(h) }),
            h.div(.{ .class = "row2" }, .{ p.pickupCard(h), p.alsoCard(h) }),
            h.div(.{ .class = "row3" }, .{ p.rankCard(h), p.timingCard(h), p.endsCard(h) }),
        });
    }

    fn patchCard(p: *P, h: *H) N {
        const by_patch, const by_day = if (p.ranked()) |x| switch (x) {
            .few => return card.view(h, .{}, &.{ card.head(h, W.by_patch, null, &.{}), p.few(h) }),
            .role => |y| .{ y.by_patch, y.by_day },
        } else .{ p.r().by_patch, p.r().by_day };
        if (by_day.len < 2) p.span.days = false;
        if (p.span.days) return p.dayCard(h, by_patch, by_day);
        const pts = trend.alloc(h, by_patch.len) orelse return .none;
        var n: usize = 0;
        for (by_patch) |x| {
            if (x.games == 0) continue;
            pts[n] = point(h, .{ .s = x.patch }, .{ .games = x.games, .wins = x.wins });
            pts[n].sub = if (x.rank > 0) W.nth.with(h, .{ .n = x.rank, .th = ordinal(x.rank) }) else null;
            n += 1;
        }
        p.by_patch.set(pts[0..n]);
        p.by_patch.label = W.by_patch;
        return card.view(h, .{}, &.{ card.head(h, W.by_patch, null, &.{p.spanPick(h, by_day.len)}), p.by_patch.view(h) });
    }

    /// The newest patch by day (by_patch's last), the first with its month; every other
    /// day named past 10
    fn dayCard(p: *P, h: *H, by_patch: []const Patch, by_day: []const Day) N {
        const pts = trend.alloc(h, by_day.len) orelse return .none;
        var n: usize = 0;
        for (by_day, 0..) |x, i| {
            if (x.games == 0) continue;
            const named = by_day.len <= 10 or (by_day.len - 1 - i) % 2 == 0;
            pts[n] = point(h, .{ .s = if (n == 0) x.tip else if (named) x.label else "" }, .{ .games = x.games, .wins = x.wins });
            if (!named) pts[n].sub = null;
            pts[n].name = .{ .s = x.tip };
            n += 1;
        }
        p.by_patch.set(pts[0..n]);
        const title = W.by_day.with(h, .{ .p = if (by_patch.len > 0) by_patch[by_patch.len - 1].patch else "" });
        p.by_patch.label = title;
        return card.view(h, .{}, &.{ card.head(h, title, null, &.{p.spanPick(h, by_day.len)}), p.by_patch.view(h) });
    }

    fn spanPick(p: *P, h: *H, days: usize) N {
        if (days < 2) return .none;
        return segmented.view(h, .{ .s = .s, .label = W.span }, &.{
            .{ .label = W.patches, .selected = !p.span.days, .on = h.on(&p.span, .patches) },
            .{ .label = W.by_days, .selected = p.span.days, .on = h.on(&p.span, .days) },
        });
    }

    fn lengthCard(p: *P, h: *H) N {
        const rl = p.r();
        const pts = trend.alloc(h, rl.by_length.len) orelse return .none;
        var n: usize = 0;
        for (rl.by_length, 0..) |c, i| {
            if (c.games == 0) continue;
            const l = if (i < p.data.lengths.len) p.data.lengths[i] else "";
            pts[n] = trend.point(h, .{ .s = l }, c.games, c.wins, W.min_tip.with(h, .{ .r = rate(c), .n = c.games }));
            n += 1;
        }
        p.by_length.set(pts[0..n]);
        p.by_length.ref = rate(.{ .games = rl.games, .wins = rl.wins });
        const lean = if (rl.lean) |g| W.lean.with(h, .{ .g = @as(i32, g) }) else null;
        return card.view(h, .{}, &.{ card.head(h, W.by_length, null, &.{ p.plat(h), if (lean) |x| tipNote(h, "cp-lean", x, x, W.lean_note) else .none }), p.by_length.view(h), places(h, &.{.{ short(.long_games), rl.long_games }}) });
    }

    fn playersCard(p: *P, h: *H) N {
        const s = p.data.spread orelse return noneCard(h, W.players, .none);
        const head = W.spread_head.with(h, .{ .n = s.players, .lo = s.p25, .hi = s.p75 });
        return card.view(h, .{}, &.{
            card.head(h, W.players, null, &.{ p.plat(h), tipNote(h, "cp-spread", head, W.middle, W.spread_note.with(h, .{ .lo = s.luck_p25, .hi = s.luck_p75 })) }),
            histogram.view(h, .{
                .label = head,
                .counts = &s.bins,
                .lo = -5,
                .step = 10,
                .mid = .{ @floatFromInt(s.p25), @floatFromInt(s.p75) },
            }),
        });
    }
    /// Win rate by rank bracket, dashed at its rate over every game (the head's); a thin
    /// bracket shows with its wide range
    fn rankCard(p: *P, h: *H) N {
        const k = p.r().ranks orelse return noneCard(h, W.by_rank, .none);
        const pts = trend.alloc(h, k.by.len) orelse return .none;
        var n: usize = 0;
        for (k.by, W.brackets) |b, l| {
            if (b.games == 0) continue;
            const c: Counts = .{ .games = b.games, .wins = b.wins };
            pts[n] = point(h, l, c);
            if (b.gold) |g| pts[n].tip = W.rank_tip.with(h, .{ .r = rate(c), .n = b.games, .g = @as(i32, g) });
            n += 1;
        }
        if (n < 2) return noneCard(h, W.by_rank, .none);
        p.ranks.set(pts[0..n]);
        p.ranks.ref = rate(k.all);
        return card.view(h, .{}, &.{ card.head(h, W.by_rank, null, &.{tipNote(h, "cp-rank", W.rank_key, W.by_rank, W.rank_note)}), p.ranks.view(h) });
    }

    /// End-of-game averages, each with its place in the role as a dot on a track, lowest
    /// left; the place in words on hover
    fn endsCard(p: *P, h: *H) N {
        const e = p.r().ends orelse return noneCard(h, W.ends_head, .none);
        if (e.games < min_games) return noneCard(h, W.ends_head, .none);
        var rs: [9]strip.Row = undefined;
        for (e.rows, W.ends_rows, ends_whole, &rs) |x, l, whole, *row| {
            const v = if (whole) phrase.num(h, .count, @as(u32, @intFromFloat(x.v + 0.5))) else phrase.num(h, .dec, x.v);
            row.* = .{ .label = l, .value = v };
            if (x.rank == 0) continue;
            const pos: f64 = if (e.of > 1) @as(f64, @floatFromInt(e.of - x.rank)) / @as(f64, @floatFromInt(e.of - 1)) else 1;
            const place = W.ends_place.with(h, .{ .n = x.rank, .th = ordinal(x.rank), .of = e.of });
            row.bar = bar.track(h, .{ .at = pos, .label = place });
        }
        const of = W.ends_of.with(h, .{ .of = e.of });
        return card.view(h, .{}, &.{
            card.head(h, W.ends_head, null, &.{ p.plat(h), tipNote(h, "cp-ends", of, W.ends_head, W.ends_note.with(h, .{ .n = e.games, .of = e.of })) }),
            strip.rows(h, &rs, bar.scale(h, W.ends_lo, W.ends_hi)),
        });
    }

    /// Win rate by the minute the first item was finished, dashed at the rate over every
    /// bucket; a thin bucket shows with its wide range
    fn timingCard(p: *P, h: *H) N {
        const k = p.r().timing;
        const pts = trend.alloc(h, k.len) orelse return .none;
        var all: Counts = .{ .games = 0, .wins = 0 };
        var n: usize = 0;
        for (k) |b| {
            all.games += b.games;
            all.wins += b.wins;
            if (b.games == 0) continue;
            pts[n] = trend.point(h, .{ .s = b.label }, b.games, b.wins, W.min_tip.with(h, .{ .r = trend.rate(b.games, b.wins), .n = b.games }));
            n += 1;
        }
        if (n < 2) return noneCard(h, W.first_item, .none);
        p.timing.set(pts[0..n]);
        p.timing.ref = rate(all);
        return card.view(h, .{}, &.{ card.head(h, W.first_item, null, &.{ p.plat(h), tipNote(h, "cp-item", W.first_item_key, W.first_item, W.first_item_note.with(h, .{ .c = p.data.name })) }), p.timing.view(h) });
    }
    fn pickupCard(p: *P, h: *H) N {
        const k = p.data.pickup orelse return noneCard(h, W.pickup, .none);
        var all: Counts = .{ .games = 0, .wins = 0 };
        for (k.bins) |b| {
            all.games += b.games;
            all.wins += b.wins;
        }
        const pts = trend.alloc(h, k.bins.len) orelse return .none;
        var n: usize = 0;
        for (k.bins, W.bands) |b, l| {
            if (b.games == 0) continue;
            pts[n] = point(h, l, b);
            n += 1;
        }
        if (n < 2) return noneCard(h, W.pickup, .none);
        p.pickup.set(pts[0..n]);
        p.pickup.ref = rate(all);
        const head = if (k.gap) |g| tipNote(h, "cp-pickup", W.pickup_head.with(h, .{ .a = k.new.?, .b = k.practised.?, .g = g, .u = k.usual_gap }), W.pickup, W.pickup_note) else .none;
        return card.view(h, .{}, &.{
            card.head(h, W.pickup, null, &.{
                p.plat(h),
                switch (k.kind) {
                    .harder => badge.view(h, .neutral, .{W.harder}),
                    .easier => badge.view(h, .neutral, .{W.easier}),
                    .usual => .none,
                },
                head,
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
            const s: u32 = @intFromFloat(@round(a.share));
            const tip = .{ .c = d.name, .d = c.name, .x = a.lift, .s = s };
            x.* = .{
                .champ = icon(h, d.ddragon, c),
                .href = h.fmt("{s}champions/{s}", .{ p.root, c.slug }),
                .tag = if (a.harder) badge.view(h, .neutral, .{W.hard}) else null,
                .label = if (a.harder) W.also_tip_hard.with(h, tip) else W.also_tip.with(h, tip),
                .value = h.span(.{}, .{W.share.with(h, .{ .s = s })}),
                .note = W.lift.with(h, .{ .x = a.lift }),
            };
        }
        const title = W.also.with(h, .{ .c = d.name });
        return card.view(h, .{}, &.{
            card.head(h, title, null, &.{ p.plat(h), h.a(.{ .class = "more", .href = h.fmt("{s}pool?champs={d}", .{ p.root, d.id }) }, .{W.pool}) }),
            if (rows.len > 0) champlist.view(h, .{ .tiles = true, .label = title }, rows) else h.p(.{ .class = "none" }, .{W.none}),
        });
    }
};

/// The lane and early game (ui-champcharts.wasm, loaded by ui-champion.wasm). From
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
            h.div(.{ .class = "row2" }, .{ p.killsCard(h), p.objectivesCard(h) }),
        });
    }

    /// On the Platinum+ cards under a rank pick
    fn plat(p: *const P, h: *H) N {
        return if (p.rank != .plat) badge.view(h, .neutral, .{W.plat}) else .none;
    }

    fn laneCard(p: *P, h: *H) N {
        const foot = places(h, &.{.{ short(.lane_gold), p.r().lane_gold }});
        const c = p.r().lane orelse return noneCard(h, W.lane_head, foot);
        for (&p.lane_metrics, c.metrics, W.lane_metrics) |*m, x, l| m.* = .{ .label = l, .fit = lane_fit, .s = .{ .line = x.line, .band = x.band } };
        p.lane.a = p.data.name;
        p.lane.metrics = &p.lane_metrics;
        p.lane.games = c.games;
        return card.view(h, .{}, &.{ card.head(h, W.lane_head, null, &.{ tipNote(h, "cp-lane", W.lane_term, W.lane_head, W.lane_note.with(h, .{ .c = p.data.name })), p.lane.switcher(h) }), p.lane.view(h), p.laneEnds(h), foot });
    }

    /// The lane opponents it wins and loses lane against most, each a link to the matchup
    fn laneEnds(p: *P, h: *H) N {
        const rl = p.r();
        const d = p.data;
        if (rl.lanes[0].len + rl.lanes[1].len == 0) return .none;
        var rows: [2]N = undefined;
        for (&rows, rl.lanes, W.lane_ends, 0..) |*row, os, label, k| {
            const links = h.mem.alloc(N, os.len) catch {
                h.oom = true;
                return .none;
            };
            for (links, os) |*l, o| {
                const c = d.champs[o.champ];
                l.* = h.a(.{
                    .href = h.fmt("{s}matchups/{s}/{s}-vs-{s}", .{ p.root, @tagName(rl.role), d.slug, c.slug }),
                    .aria_label = if (k == 0) W.lane_win.with(h, .{ .c = d.name, .o = c.name, .g = o.gold }) else W.lane_loss.with(h, .{ .o = c.name, .g = o.gold }),
                }, .{ champ.view(h, icon(h, d.ddragon, c), .{ .named = false }), " ", phrase.num(h, .count, o.gold) });
            }
            row.* = if (os.len == 0) .none else h.p(.{}, .{ h.span(.{ .class = "k" }, .{ label, " ", h.small(.{}, .{W.lane_ends_unit}) }), links });
        }
        return h.div(.{ .class = "ends" }, .{ rows[0], rows[1] });
    }

    fn comebackCard(p: *P, h: *H) N {
        const foot = places(h, &.{ .{ short(.ahead), p.r().ahead }, .{ short(.behind), p.r().behind } });
        const c = p.r().comeback orelse return noneCard(h, W.comeback, foot);
        const pts = trend.alloc(h, 5) orelse return .none;
        var base: [5]f32 = undefined;
        var n: usize = 0;
        var all = true;
        for (c.at[p.at], c.all[p.at], W.comeback_buckets) |b, a, l| {
            if (b.games == 0) continue;
            pts[n] = trend.point(h, l, b.games, b.wins, W.comeback_tip.with(h, .{ .m = W.comeback_mins[p.at].s, .r = rate(b), .n = b.games, .a = rate(a) }));
            base[n] = rate(a);
            all = all and a.games > 0;
            n += 1;
        }
        if (n < 2) return noneCard(h, W.comeback, foot);
        p.comeback.set(pts[0..n]);
        p.comeback.base = &.{};
        if (all) p.comeback.base = h.mem.dupe(f32, base[0..n]) catch blk: {
            h.oom = true;
            break :blk &.{};
        };
        var items: [2]segmented.Item = undefined;
        for (&items, W.comeback_mins, 0..) |*x, l, i| x.* = .{ .label = l, .selected = i == p.at, .on = h.on(p, .{ .at = @as(u8, @intCast(i)) }) };
        const key: N = if (p.comeback.base.len > 0) h.span(.{ .class = "lg" }, .{W.all_lanes}) else .none;
        return card.view(h, .{}, &.{
            card.head(h, W.comeback, null, &.{ key, segmented.view(h, .{ .s = .s, .label = W.comeback_at }, &items) }),
            p.comeback.view(h),
            foot,
        });
    }

    /// Share of lanes with a kill in each phase, the champion's above the line and its lane
    /// opponent's under it
    fn killsCard(p: *P, h: *H) N {
        const k = p.r().kills orelse return noneCard(h, W.kills_head, .none);
        var rows: [4]versus.Row = undefined;
        var n: usize = 0;
        // Curves files from before v6 have none: no row rather than 0%
        if (k.first_blood[0] + k.first_blood[1] > 0) {
            rows[n] = killRow(h, k.games, W.first_blood, k.first_blood[0], k.first_blood[1]);
            n += 1;
        }
        for (W.kills, k.kills, k.deaths) |l, x, y| {
            rows[n] = killRow(h, k.games, l, x, y);
            n += 1;
        }
        return card.view(h, .{}, &.{
            card.head(h, W.kills_head, W.lanes_n.with(h, .{ .n = k.games }), &.{}),
            versus.timeline(h, .{ p.data.name, W.kills_them.s }, .{
                champ.view(h, .{ .name = p.data.name, .src = p.data.icon }, .{ .px = .@"32", .named = false }),
                role.view(h, p.r().role, .{ .s = .l, .named = false }),
            }, W.kills_y, rows[0..n]),
        });
    }

    fn killRow(h: *H, games: u32, l: tree.Text, us: u32, them: u32) versus.Row {
        const a = rate(.{ .games = games, .wins = us });
        const b = rate(.{ .games = games, .wins = them });
        return versus.shares(h, l, a / 100, b / 100);
    }

    /// How often the champion's team took each objective first, and won after it, each
    /// on a 0-100 track with the role's rate its tick
    fn objectivesCard(p: *P, h: *H) N {
        const k = p.r().objectives orelse return noneCard(h, W.objectives_head, .none);
        var l = h.list();
        l.add(h.span(.{}, .{}));
        for (W.obj_kinds) |o| l.add(h.span(.{ .class = "oh" }, .{ objicon.view(h, o, .{ .s = .xl, .named = false }), objicon.label(o) }));
        for (W.obj_rows, 0..) |rl, row| {
            l.add(h.span(.{ .class = "rl" }, .{rl}));
            for (W.firsts, k.mine[1..], k.role[1..]) |fl, x, y| {
                const took = row == 0;
                const mine: Counts = if (took) .{ .games = k.mine[0].games, .wins = x.games } else x;
                const all: Counts = if (took) .{ .games = k.role[0].games, .wins = y.games } else y;
                l.add(p.objCell(h, fl, took, mine, all));
            }
        }
        return card.view(h, .{}, &.{
            card.head(h, W.objectives_head, W.games_n.with(h, .{ .n = k.mine[0].games }), &.{ p.plat(h), h.span(.{ .class = "lg" }, .{W.obj_key}) }),
            h.div(.{ .class = "obj", .data_grow = {} }, .{l.done()}),
        });
    }

    /// A won-after cell is coloured by its win rate; a taken-first one, not a win rate,
    /// keeps its ink
    fn objCell(p: *const P, h: *H, l: tree.Text, took: bool, mine: Counts, all: Counts) N {
        if (mine.games < fmt.floor_games) return h.span(.{ .class = "fl" }, .{W.games_n.with(h, .{ .n = mine.games })});
        const v = rate(mine);
        const a = rate(all);
        const tip = .{ .l = l.s, .c = p.data.name, .r = v, .n = mine.games, .a = a };
        const on = struct {
            fn f(x: f32) i32 {
                return @intFromFloat(@round(x * 10 - 500));
            }
        }.f;
        const b: versus.Band = .{
            .label = if (took) W.took_tip.with(h, tip) else W.won_tip.with(h, tip),
            .you = on(v),
            .typ = if (all.games > 0) .{ on(a), on(a), on(a) } else null,
            .dom = 500,
            .tint = false,
        };
        // A share of games whole, a win rate to a tenth as everywhere
        if (took) return versus.cell(h, b, phrase.num(h, .pct, round(v)));
        return versus.cell(h, b, winrate.view(h, .counted(mine.games, mine.wins), .{ .count = false }));
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
    \\  .c-cpage > [data-busy]:not([data-island=champion]) > :not(.c-lockbar), .c-cpage > [data-busy] .c-champhead { opacity: 0.55; transition: opacity 0.2s; }
    \\  .c-cpage .plot[data-thin] { opacity: 0.6; }
    \\  .c-cpage .rare { margin: var(--sp-3) 0 0; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .c-champhead > .none { margin: 0 0 0 auto; }
    \\  .c-cpage #build { gap: var(--sp-3); }
    \\  .c-cpage #build .none { margin: 0; padding: var(--sp-4) var(--card-px); color: var(--muted); }
    \\  .c-cpage .vs-hint { margin: 0; padding: var(--sp-3) var(--card-px); border-top: 1px solid var(--line); font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .from { margin: 0; padding: var(--sp-3) var(--card-px) 0; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .none { margin: var(--sp-3) 0; color: var(--muted); }
    \\  .c-cpage .note { margin-left: auto; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .places { display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-4); margin: var(--sp-2) 0 0;
    \\    font-size: var(--fs-s); }
    \\  .c-cpage .c-head .lg { margin-left: auto; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-cpage .more { margin-left: auto; font-size: var(--fs-s); }
    \\  .c-cpage .ends { display: grid; gap: var(--sp-2); margin-top: var(--sp-3); font-size: var(--fs-s); }
    \\  .c-cpage .ends p { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-1) var(--sp-3); margin: 0; }
    \\  .c-cpage .ends .k { display: flex; flex-direction: column; min-width: 9.5em; color: var(--muted); line-height: 1.25; }
    \\  .c-cpage .ends .k small { font-size: var(--fs-xs); }
    \\  @media (max-width: 600px) { .c-cpage .ends .k { flex-direction: row; gap: var(--sp-2); flex-basis: 100%; } }
    \\  .c-cpage .ends a { display: inline-flex; align-items: center; gap: var(--sp-1); color: var(--ink); font-variant-numeric: tabular-nums; }
    \\  .c-cpage .obj { display: grid; grid-template-columns: auto repeat(4, minmax(0, 1fr)); align-items: center;
    \\    align-content: space-evenly; gap: var(--sp-4) var(--sp-4); padding: var(--sp-2) 0; }
    \\  .c-cpage .obj > .oh { display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: var(--fs-xs);
    \\    color: var(--muted); text-align: center; }
    \\  .c-cpage .obj > .rl { font-size: var(--fs-s); color: var(--t2); white-space: nowrap; }
    \\  .c-cpage .obj .c-vs[data-v="cell"] { width: 100%; }
    \\  .c-cpage .obj .c-vs[data-v="cell"] > .fig { order: -1; font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-cpage .obj > .fl { font-size: var(--fs-xs); color: var(--faint); text-align: center; }
    \\  @media (max-width: 600px) { .c-cpage .obj { gap: var(--sp-3) var(--sp-2); } .c-cpage .obj .c-vs[data-v="cell"] > .fig { font-size: var(--fs-m); } }
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
    try std.testing.expectEqualStrings("/data/champion/darius-more-rank-patch.bin", try viewPath(a, "/data/champion/darius-trends.bin", "/", 1, true));
    const p: Pick = .of(Top.Url{ .region = .all, .period = .patch, .rank = .diamond });
    try std.testing.expectEqual(3, p.view);
    try std.testing.expectEqual(.all, p.region());
    try std.testing.expectEqual(.patch, p.period());
}

test "a rare role is listed and opens with its games, faded only by its range" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const d: TopData = .{ .name = "Karthus", .slug = "karthus", .icon = "", .patch = "16.21", .ddragon = "16.21.1", .champs = &.{}, .roles = &.{
        .{ .role = .jungle, .games = 9000, .wins = 4700, .share = 95, .pick = 4, .ban = 2, .lane = &.{} },
        .{ .role = .top, .games = 60, .wins = 27, .share = 0.7, .thin = true, .pick = 0.1, .ban = 2, .lane = &.{} },
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
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "data-thin") == null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "data-wide") != null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "<p class=\"rare\">A rare role for Karthus: 60 games.</p>") != null);
}

test "by rank: a thin bracket shows, an empty one doesn't, no chart under two" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var roles = [_]TrendsRole{.{ .role = .top, .games = 0, .wins = 0, .by_patch = &.{}, .by_length = &.{}, .ranks = .{ .by = .{
        .{ .games = 40, .wins = 20 },
        .{ .games = 900, .wins = 470, .gold = 120 },
        .{ .games = 300, .wins = 140 },
    }, .all = .{ .games = 1600, .wins = 800 } } }};
    const d: TrendsData = .{ .name = "Darius", .ddragon = "", .champs = &.{}, .roles = &roles, .lengths = &.{} };
    var p: Trends = .{ .data = &d, .root = "/" };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "Iron-Silver") != null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "Gold-Emerald") != null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "Diamond+") != null);
    // Dashed at every game's rate, not the brackets' sum's (50.8%)
    try std.testing.expectEqual(@as(f32, 50), p.ranks.ref);

    roles[0].ranks.?.by[1].games = 0;
    roles[0].ranks.?.by[2].games = 0;
    w.clearRetainingCapacity();
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "Gold-Emerald") == null);
}

test "end of game: each figure with its place, none under min_games or for a rare pick" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var rows: [9]EndRow = @splat(.{ .v = 6.25, .rank = 3 });
    rows[4] = .{ .v = 411.6, .rank = 1 };
    var roles = [_]TrendsRole{.{ .role = .top, .games = 0, .wins = 0, .by_patch = &.{}, .by_length = &.{}, .ends = .{ .games = 100, .of = 48, .rows = rows } }};
    const d: TrendsData = .{ .name = "Darius", .ddragon = "", .champs = &.{}, .roles = &roles, .lengths = &.{} };
    var p: Trends = .{ .data = &d, .root = "/" };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, p.view(&h), &w.writer);
    const got = w.written();
    try std.testing.expect(std.mem.indexOf(u8, got, "<h2>End of game</h2>") != null);
    try std.testing.expect(std.mem.indexOf(u8, got, "of 48 champions") != null);
    try std.testing.expect(std.mem.indexOf(u8, got, ">6.3<") != null);
    try std.testing.expect(std.mem.indexOf(u8, got, ">412<") != null);
    try std.testing.expect(std.mem.indexOf(u8, got, "1st highest of 48") != null);
    try std.testing.expect(std.mem.indexOf(u8, got, "3rd highest of 48") != null);
    try std.testing.expectEqual(9 + 1, std.mem.count(u8, got, "c-track"));

    roles[0].ends.?.rows[4].rank = 0;
    w.clearRetainingCapacity();
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), ">412<") != null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "1st highest") == null);
    try std.testing.expectEqual(8 + 1, std.mem.count(u8, w.written(), "c-track"));

    roles[0].ends.?.games = 99;
    w.clearRetainingCapacity();
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), ">412<") == null);
}

test "lane kills: a timeline of each side's share of lanes, first blood only when counted" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var roles = [_]ChartsRole{.{ .role = .top, .kills = .{ .games = 1000, .first_blood = .{ 100, 120 }, .kills = .{ 490, 710, 30 }, .deaths = .{ 460, 740, 40 } } }};
    const d: ChartsData = .{ .name = "Ornn", .ddragon = "", .champs = &.{}, .roles = &roles };
    var p: Charts = .{ .data = &d, .root = "/" };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, p.view(&h), &w.writer);
    const got = w.written();
    try std.testing.expect(std.mem.indexOf(u8, got, "data-v=\"time\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, got, "by 6 min") != null);
    try std.testing.expect(std.mem.indexOf(u8, got, "<span class=\"y\">lanes with a kill</span>") != null);
    try std.testing.expect(std.mem.indexOf(u8, got, "<span class=\"sr\">Opponent </span>46%") != null);
    try std.testing.expect(std.mem.indexOf(u8, got, "--x:12") != null);
    try std.testing.expectEqual(4, std.mem.count(u8, got, "class=\"tc\""));

    roles[0].kills.?.first_blood = .{ 0, 0 };
    w.clearRetainingCapacity();
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "First blood") == null);
    try std.testing.expectEqual(3, std.mem.count(u8, w.written(), "class=\"tc\""));
}

test "first item done: a thin bucket shows, an empty one doesn't, no chart under two" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var timing = [_]Timed{
        .{ .label = "<9", .games = 99, .wins = 60 },
        .{ .label = "9-11", .games = 900, .wins = 470 },
        .{ .label = "11+", .games = 300, .wins = 140 },
    };
    var roles = [_]TrendsRole{.{ .role = .top, .games = 0, .wins = 0, .by_patch = &.{}, .by_length = &.{}, .timing = &timing }};
    const d: TrendsData = .{ .name = "Darius", .ddragon = "", .champs = &.{}, .roles = &roles, .lengths = &.{} };
    var p: Trends = .{ .data = &d, .root = "/" };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var w: std.Io.Writer.Allocating = .init(a);
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "&lt;9") != null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "9-11") != null);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "11+") != null);

    timing[0].games = 0;
    timing[2].games = 0;
    w.clearRetainingCapacity();
    try html.write(&t, p.view(&h), &w.writer);
    try std.testing.expect(std.mem.indexOf(u8, w.written(), "9-11") == null);
}

test "lane ends: biggest gold leads each way, thin and even lanes out" {
    const testing = std.testing;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const opps = [_]Opp{
        .{ .champ = 1, .games = 400, .wins = 200, .usual = 0, .gold = 300 },
        .{ .champ = 2, .games = 400, .wins = 200, .usual = 0, .gold = -250 },
        .{ .champ = 3, .games = 50, .wins = 20, .usual = 0, .gold = 900 },
        .{ .champ = 4, .games = 400, .wins = 200, .usual = 0, .gold = 60 },
        .{ .champ = 5, .games = 400, .wins = 200, .usual = 0, .gold = 500 },
        .{ .champ = 6, .games = 400, .wins = 200, .usual = 0, .gold = -700 },
        .{ .champ = 7, .games = 400, .wins = 200, .usual = 0 },
    };
    const rels = [_]Rel{
        .{ .ally = true, .role = .jungle, .opps = &opps, .rare = 0 },
        .{ .ally = false, .role = .top, .opps = &opps, .rare = 0 },
    };
    const e = try laneEnds(arena.allocator(), .top, &rels);
    try testing.expectEqualSlices(LaneOpp, &.{ .{ .champ = 5, .gold = 500 }, .{ .champ = 1, .gold = 300 } }, e[0]);
    try testing.expectEqualSlices(LaneOpp, &.{ .{ .champ = 6, .gold = 700 }, .{ .champ = 2, .gold = 250 } }, e[1]);
    try testing.expectEqual(0, (try laneEnds(arena.allocator(), .mid, &rels))[0].len);
}

test "a build from another patch than the view's has its patch chip" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const b: buildpanel.Data = .{ .runes = .{ .trees = &.{}, .games = 0, .wins = 0 }, .slots = &.{}, .champion = "Darius", .own = 50 };
    const cases = [_]struct { BuildRole, ?[]const u8 }{
        .{ .{ .role = .top, .build = b }, null },
        .{ .{ .role = .top, .build = b, .patch = "16.20", .older = true }, "<div class=\"from\"><span class=\"c-hint\" tabindex=\"0\" data-at=\"below\"><span class=\"c-chip\" data-v=\"scope\">Patch 16.20</span><span class=\"c-hintb\">Too few games on this patch yet</span></span></div>" },
        .{ .{ .role = .top, .build = b, .patch = "16.21" }, "Patch 16.21</span><span class=\"c-hintb\">From this patch, not the 30 days picked</span>" },
    };
    for (cases) |c| {
        const d: BuildData = .{ .roles = &.{c[0]} };
        var p: Build = .{ .data = &d, .panels = try panels(a, d.roles) };
        p.files.base[0] = &d;
        var t: tree.Tree = .{};
        var h: H = .init(a, &t);
        var w: std.Io.Writer.Allocating = .init(a);
        try html.write(&t, p.view(&h), &w.writer);
        if (c[1]) |want| {
            std.testing.expect(std.mem.indexOf(u8, w.written(), want) != null) catch |e| {
                std.debug.print("{s}\n", .{w.written()});
                return e;
            };
        } else try std.testing.expect(std.mem.indexOf(u8, w.written(), "data-v=\"scope\"") == null);
    }
}
