//! The matchup page (matchup/<role>/<x>-vs-<y>.html): one lane pair from x's side
//! (docs/plan/ui/matchup.md), the champion page with its opponent slot filled, as three
//! islands. Head: ChampHeader's pair with the headline figures, x's other lane opponents
//! and the view links. Build: the champion page's Build island on the pair's build. More:
//! the lane by minute beside head to head, won by gold at 10, by rank and mastery, and
//! bot lane partners.
//!
//! Pages are rendered on request, so each island's data rides in its root's data-bin
//! (base64 of ui.data) rather than a file: ui-matchup.wasm adopts Head and loads
//! ui-champbuild.wasm and ui-matchmore.wasm for the others
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const card = @import("card.zig");
const badge = @import("badge.zig");
const strip = @import("strip.zig");
const segmented = @import("segmented.zig");
const champhead = @import("champhead.zig");
const matchstrip = @import("matchstrip.zig");
const filterbar = @import("filterbar.zig");
const champlist = @import("champlist.zig");
const lane = @import("lane.zig");
const versus = @import("versus.zig");
const trend = @import("trend.zig");
const table = @import("table.zig");
const champpage = @import("champpage.zig");
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "MatchPage";
pub const scope = .{".c-mpage"};

pub const Other = champpage.Other;

fn icon(a: std.mem.Allocator, ddragon: []const u8, c: Other) !champ.Champ {
    return .{ .name = c.name, .src = try std.fmt.allocPrint(a, "https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ ddragon, c.key }) };
}

fn rate(games: u32, wins: u32) f32 {
    return 100 * @as(f32, @floatFromInt(wins)) / @as(f32, @floatFromInt(@max(games, 1)));
}

/// ±95%, points
fn ci(games: u32, wins: u32) f32 {
    if (games == 0) return 0;
    const p = rate(games, wins) / 100;
    return 196 * @sqrt(p * (1 - p) / @as(f32, @floatFromInt(games)));
}

const n_views = 4;

/// ui-matchup.wasm's
pub const HeadData = struct {
    x: Other,
    y: Other,
    role: role.Role,
    patch: []const u8,
    ddragon: []const u8,
    /// The other side's page; x's champion page in the role
    swap: []const u8,
    clear: []const u8,
    games: u32,
    wins: u32,
    /// What x usually wins against an opponent this strong, %
    usual: f32,
    /// x's win rate here minus usual, pulled toward 0 the fewer the games, points
    vs_usual: f32,
    /// Lane gold at 14, x minus y, estimated; about this much of it from CS
    gold: ?i16 = null,
    cs_gold: ?i16 = null,
    lane_games: u32 = 0,
    ahead: u32 = 0,
    /// Few games, or mostly the champions' baseline: gold and ahead faded
    thin: bool = false,
    /// x's lane opponents with a page, most games first
    opps: []const Opp,
    /// This page in each view (html.View.all's order); "" none
    views: [n_views][]const u8,
    /// html.View.all's index of this one
    view: u8,
};

pub const Opp = struct { o: Other, games: u32, wins: u32 };

const W = struct {
    pub const sub = Phrase("{r:text} · {p:text}");
    pub const wins = Phrase("{c:text} wins");
    pub const usual = plain("Vs usual");
    pub const usually = Phrase("{r:rate} usually");
    pub const gold = plain("Gold at 14");
    pub const cs_part = Phrase("{x:text} minus {y:text} at 14 minutes, estimated from games of every length; about {g:signed} of it from CS.");
    pub const gold_note = Phrase("{x:text} minus {y:text} at 14 minutes, estimated from games of every length.");
    pub const ahead = plain("Ahead at 14");
    pub const games = plain("Games");
    pub const opps = Phrase("{x:text}'s {r:text} opponents");
    pub const picked = Phrase("{r:text} · {p:text} · {k:text}");
    pub const region = plain("Region");
    pub const period = plain("Period");
    pub const rank = plain("Rank");
    pub const regions = [2]tree.Text{ plain("EUW"), plain("All regions") };
    pub const days = plain("30 days");
    pub const ranks = [4]tree.Text{ plain("Plat+"), plain("Emerald+"), plain("Diamond+"), plain("Master+") };
    pub const lane_head = plain("Lane");
    pub const h2h = plain("Head to head");
    pub const few = plain("few games");
    pub const few_note = plain("Few games of this pair: the lines lean on how both champions do against everyone.");
    pub const none = plain("Not enough games yet.");
    pub const metrics = [3]tree.Text{ plain("Gold"), plain("XP"), plain("CS") };
    pub const won = plain("Wins");
    pub const won_ahead = plain("Wins from ahead");
    pub const first_blood = plain("First blood");
    pub const kills = [3]tree.Text{ plain("Kills to 6 min"), plain("Kills 6-14 min"), plain("Kills after 14") };
    pub const level2 = plain("Level 2");
    pub const level6 = plain("Level 6");
    pub const first_item = plain("First item");
    pub const apart = Phrase("{s:int} s apart");
    pub const apart_long = Phrase("{t:time} apart");
    pub const never = plain("-");
    pub const gold10 = plain("Won by gold at 10");
    pub const gold10_tip = Phrase("{l:text} at 10 min: {r:rate} in {n:count} games, all lanes {a:rate}");
    pub const buckets = [5]tree.Text{ plain("-1.5k"), plain("-1k"), plain("0"), plain("+1k"), plain("+1.5k") };
    pub const by_rank = plain("By rank and mastery");
    pub const with = Phrase("{x:text} with");
};

/// The head (ui-matchup.wasm), with the opponents and the view links
pub const Head = struct {
    data: *const HeadData,
    strip: matchstrip.MatchupStrip,
    /// The data-bin it came from, for the root
    bin: []const u8 = "",
    /// The narrow toolbar's choices shown
    open: bool = false,

    const P = @This();

    pub const Msg = union(enum) { filters };

    pub fn init(a: std.mem.Allocator, d: *const HeadData) !P {
        const items = try a.alloc(matchstrip.Item, d.opps.len);
        for (items, d.opps) |*it, o| {
            const r = rate(o.games, o.wins);
            it.* = .{
                .champ = try icon(a, d.ddragon, o.o),
                .fig = .{ .s = try std.fmt.allocPrint(a, "{d:.1}", .{r}) },
                .colour = .{ .pts = r - 50 },
                .href = try std.fmt.allocPrint(a, "{s}-vs-{s}.html", .{ d.x.slug, o.o.slug }),
                .current = std.mem.eql(u8, o.o.slug, d.y.slug),
                .thin = o.games < fmt.thin_games,
            };
        }
        const label = try std.fmt.allocPrint(a, "{s}'s {s} opponents", .{ d.x.name, d.role.label().s });
        return .{ .data = d, .strip = try .init(a, items, "mu-opp", .{ .s = label }) };
    }

    pub fn update(p: *P, m: Msg, _: *tree.Event) void {
        switch (m) {
            .filters => p.open = !p.open,
        }
    }

    pub fn view(p: *P, h: *H) N {
        const d = p.data;
        return h.div(.{ .class = "part", .data_island = "matchup", .data_bin = if (p.bin.len > 0) p.bin else null, .data_thin = d.thin }, .{card.view(h, .{}, &.{
            champhead.view(h, .{
                .champ = .{ .name = d.x.name, .src = h.fmt("https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ d.ddragon, d.x.key }) },
                .sub = W.sub.with(h, .{ .r = d.role.label().s, .p = d.patch }),
                .pair = .{
                    .champ = .{ .name = d.y.name, .src = h.fmt("https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ d.ddragon, d.y.key }) },
                    .swap = d.swap,
                    .clear = d.clear,
                },
                .strip = p.headline(h),
            }),
            p.strip.view(h),
            p.toolbar(h),
        })});
    }

    fn headline(p: *P, h: *H) N {
        const d = p.data;
        const won = rate(d.games, d.wins);
        var items: [5]strip.Item = undefined;
        var n: usize = 0;
        items[n] = .{ .label = W.wins.with(h, .{ .c = d.x.name }), .value = phrase.num(h, .rate, won), .step = .of(won - 50, fmt.win_cuts), .answer = true };
        n += 1;
        items[n] = .{
            .label = W.usual,
            .value = phrase.num(h, .points, d.vs_usual),
            .ctx = W.usually.with(h, .{ .r = d.usual }),
            .step = .of(d.vs_usual, fmt.win_cuts),
            .tip = .{ .id = "mu-usual", .note = champpage.usual_note.with(h, .{ .c = d.x.name }) },
        };
        n += 1;
        if (d.gold) |g| {
            items[n] = .{
                .label = W.gold,
                .value = phrase.num(h, .signed, @as(i32, g)),
                .tip = .{ .id = "mu-gold", .note = if (d.cs_gold) |c| W.cs_part.with(h, .{ .x = d.x.name, .y = d.y.name, .g = @as(i32, c) }) else W.gold_note.with(h, .{ .x = d.x.name, .y = d.y.name }) },
            };
            n += 1;
        }
        if (d.lane_games > 0) {
            items[n] = .{ .label = W.ahead, .value = phrase.num(h, .pct, @as(u32, @intFromFloat(@round(rate(d.lane_games, d.ahead))))) };
            n += 1;
        }
        items[n] = .{ .label = W.games, .value = phrase.num(h, .count, d.games) };
        n += 1;
        return strip.view(h, items[0..n]);
    }

    /// The views as links to this page in each (lolalytics' filters), ranks greyed: the
    /// champion page's toolbar look
    fn toolbar(p: *P, h: *H) N {
        const d = p.data;
        const at = struct {
            fn f(dd: *const HeadData, v: u8, label: tree.Text) segmented.Item {
                return .{ .label = label, .href = dd.views[v], .selected = v == dd.view, .disabled = dd.views[v].len == 0 and v != dd.view };
            }
        }.f;
        const region = d.view / 2;
        const period = d.view % 2;
        var ranks: [W.ranks.len]segmented.Item = undefined;
        for (&ranks, W.ranks, 0..) |*it, l, i| it.* = .{ .label = l, .href = "", .selected = i == 0, .disabled = i > 0 };
        return card.toolbar(h, &.{filterbar.view(h, .{
            .summary = W.picked.with(h, .{ .r = W.regions[region].s, .p = if (period == 1) d.patch else W.days.s, .k = W.ranks[0].s }),
            .open = p.open,
            .on_toggle = h.on(p, .filters),
        }, &.{
            segmented.view(h, .{ .label = W.region }, &.{ at(d, period, W.regions[0]), at(d, 2 + period, W.regions[1]) }),
            segmented.view(h, .{ .label = W.period }, &.{ at(d, 2 * region, W.days), at(d, 2 * region + 1, .{ .s = d.patch }) }),
            segmented.view(h, .{ .label = W.rank }, &ranks),
        })});
    }
};

/// ui-matchmore.wasm's
pub const MoreData = struct {
    x: []const u8,
    y: []const u8,
    ddragon: []const u8,
    role: role.Role,
    thin: bool = false,
    /// Games still going at each minute drawn
    games: []const u32,
    /// Gold, XP, CS: x minus y by minute
    curves: [3]Curve,
    h2h: H2h,
    /// x's lead at 10 minutes from 1,500+ behind to 1,500+ ahead
    gold10: [5]Bucket,
    ranks: []const RankRow,
    /// Bot and support: each side's lane partners, from all their games in the role
    duos: []const DuoSide = &.{},
};

pub const Curve = struct {
    /// The estimated average
    line: []const i16,
    /// The middle half of games
    band: []const [2]i16,
    /// The previous patch's average (patch views)
    prev: []const i16 = &.{},
};

/// From the lane curves' games: x's then y's
pub const H2h = struct {
    games: u32,
    wins: u32,
    lane_games: u32,
    ahead: u32,
    behind: u32,
    wins_ahead: u32,
    wins_behind: u32,
    first_blood: [2]u32,
    /// Games x took part in killing y, by phase (0-6, 6-14, 14+); deaths the other way
    kills: [3]u32,
    deaths: [3]u32,
    /// Medians, seconds; 0 unknown
    level2: [2]u16,
    level6: [2]u16,
    first_item: [2]u16,
};

pub const Bucket = struct { games: u32 = 0, wins: u32 = 0, all_games: u32 = 0, all_wins: u32 = 0 };

pub const RankRow = struct {
    label: []const u8,
    games: u32,
    wins: u32,
    gold: ?i16 = null,
    /// Its place in the list, which the table keeps
    order: u8,
};

pub const DuoSide = struct { name: []const u8, partners: []const Duo };

pub const Duo = struct {
    champ: Other,
    games: u32,
    /// Vs usual, points
    usual: f32,
};

const Ranks = table.DataTable(RankRow, rank_spec);

const rank_spec: table.Spec(RankRow) = .{
    .title = W.by_rank,
    .columns = &.{
        .{ .label = plain("Rank"), .cell = rankName, .sort = rankOrder, .num = false },
        .{ .label = plain("Win rate"), .cell = rankRate, .sort = rankRateOf, .answer = true },
        .{ .label = plain("Lane gold"), .cell = rankGold, .sort = rankGoldOf, .tip = plain("Gold at 14 minutes, the first champion minus the second, estimated.") },
        .{ .label = plain("Games"), .cell = rankGames, .sort = rankGamesOf },
    },
    .games = rankGamesOfN,
    .thin = thin_games,
    .compact = true,
};

fn rankName(h: *H, r: *const RankRow) N {
    return h.span(.{}, .{r.label});
}

fn rankOrder(r: *const RankRow) f64 {
    return -@as(f64, @floatFromInt(r.order));
}

fn rankRate(h: *H, r: *const RankRow) N {
    const v = rate(r.games, r.wins);
    return h.b(.{ .style = h.vars(.{ .c = fmt.WrColour{ .pts = v - 50 } }) }, .{phrase.num(h, .rate, v)});
}

fn rankRateOf(r: *const RankRow) f64 {
    return rate(r.games, r.wins);
}

fn rankGold(h: *H, r: *const RankRow) N {
    return h.span(.{}, .{if (r.gold) |g| phrase.num(h, .signed, @as(i32, g)) else W.never});
}

fn rankGoldOf(r: *const RankRow) f64 {
    return @floatFromInt(r.gold orelse -32768);
}

fn rankGames(h: *H, r: *const RankRow) N {
    return h.span(.{}, .{phrase.num(h, .count, r.games)});
}

fn rankGamesOf(r: *const RankRow) f64 {
    return @floatFromInt(r.games);
}

fn rankGamesOfN(r: *const RankRow) u32 {
    return r.games;
}

/// The lane curves': under it a figure leans on the champions' baseline
/// (site/matchup.zig thin_games)
pub const thin_games = 200;

/// The lane row, outcome row and partners (ui-matchmore.wasm, loaded after Head)
pub const More = struct {
    data: *const MoreData,
    chart: lane.Lane,
    gold10: trend.Trend = .{ .label = W.gold10, .points = &.{} },
    ranks: Ranks,
    bin: []const u8 = "",
    /// ui-matchmore.js and .wasm, for ui-matchup.wasm to load
    js: ?[]const u8 = null,
    wasm: ?[]const u8 = null,

    const P = @This();

    /// The chart's measures as floats, allocated: the server's and the island's copies
    /// share them
    pub fn init(a: std.mem.Allocator, d: *const MoreData) !P {
        const metrics = try a.alloc(lane.Metric, 3);
        for (metrics, d.curves, W.metrics) |*m, c, l| m.* = .{ .label = l, .fit = fit_minutes, .s = .{
            .line = try floats(a, c.line),
            .band = try pairs(a, c.band),
            .prev = try floats(a, c.prev),
        } };
        return .{
            .data = d,
            .chart = .{ .a = d.x, .b = d.y, .metrics = metrics, .games = d.games, .select = false },
            .ranks = .{ .rows = d.ranks, .id = "mu-rank" },
        };
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{ .class = "part", .data_island = "matchmore", .data_bin = if (p.bin.len > 0) p.bin else null, .data_js = p.js, .data_wasm = p.wasm }, .{
            h.div(.{ .class = "lanerow" }, .{ p.laneCard(h), p.h2hCard(h) }),
            h.div(.{ .class = "row2" }, .{ p.gold10Card(h), p.rankCard(h) }),
            p.duos(h),
        });
    }

    fn laneCard(p: *P, h: *H) N {
        const d = p.data;
        const few: N = if (d.thin) badge.view(h, .few, .{W.few}) else .none;
        if (d.games.len < 2) return card.view(h, .{}, &.{ card.head(h, W.lane_head, null, &.{few}), h.p(.{ .class = "none" }, .{W.none}) });
        return card.view(h, .{}, &.{
            card.head(h, W.lane_head, null, &.{ few, p.chart.switcher(h) }),
            h.div(.{ .class = "plot", .data_thin = d.thin }, .{p.chart.view(h)}),
        });
    }

    fn h2hCard(p: *P, h: *H) N {
        const v = p.data.h2h;
        var rows: [12]versus.Row = undefined;
        var n: usize = 0;
        rows[n] = share(h, W.won, .{ v.wins, v.games }, .{ v.games -| v.wins, v.games });
        n += 1;
        if (v.lane_games > 0) {
            rows[n] = share(h, W.ahead, .{ v.ahead, v.lane_games }, .{ v.behind, v.lane_games });
            rows[n + 1] = share(h, W.won_ahead, .{ v.wins_ahead, v.ahead }, .{ v.behind -| v.wins_behind, v.behind });
            n += 2;
        }
        // Curves files from before v6 have none: no row rather than 0%
        if (v.first_blood[0] + v.first_blood[1] > 0) {
            rows[n] = share(h, W.first_blood, .{ v.first_blood[0], v.games }, .{ v.first_blood[1], v.games });
            n += 1;
        }
        for (W.kills, v.kills, v.deaths) |l, k, dd| {
            rows[n] = share(h, l, .{ k, v.games }, .{ dd, v.games });
            n += 1;
        }
        if (v.level2[0] != 0 or v.level2[1] != 0) {
            rows[n] = timing(h, W.level2, v.level2);
            n += 1;
        }
        rows[n] = timing(h, W.level6, v.level6);
        rows[n + 1] = timing(h, W.first_item, v.first_item);
        n += 2;
        return card.view(h, .{}, &.{
            card.head(h, W.h2h, null, &.{}),
            h.div(.{ .data_thin = p.data.thin }, .{versus.rows(h, .{ p.data.x, p.data.y }, rows[0..n])}),
        });
    }

    fn gold10Card(p: *P, h: *H) N {
        const pts = h.mem.alloc(trend.Point, p.data.gold10.len) catch {
            h.oom = true;
            return .none;
        };
        var n: usize = 0;
        for (p.data.gold10, W.buckets) |b, l| {
            if (b.games == 0) continue;
            pts[n] = .{
                .label = l,
                .sub = phrase.num(h, .kilo, b.games),
                .v = rate(b.games, b.wins),
                .ci = ci(b.games, b.wins),
                .tip = W.gold10_tip.with(h, .{ .l = l.s, .r = rate(b.games, b.wins), .n = b.games, .a = rate(b.all_games, b.all_wins) }),
            };
            n += 1;
        }
        p.gold10.points = pts[0..n];
        if (p.gold10.tip) |t| if (t >= n) {
            p.gold10.tip = null;
        };
        return card.view(h, .{}, &.{ card.head(h, W.gold10, null, &.{}), if (n > 0) p.gold10.view(h) else h.p(.{ .class = "none" }, .{W.none}) });
    }

    fn rankCard(p: *P, h: *H) N {
        return card.view(h, .{}, &.{ card.head(h, W.by_rank, null, &.{}), p.ranks.view(h) });
    }

    fn duos(p: *P, h: *H) N {
        const d = p.data;
        if (d.duos.len == 0) return .none;
        var cards = h.list();
        for (d.duos, 0..) |side, k| {
            const rows = h.mem.alloc(champlist.Row, side.partners.len) catch {
                h.oom = true;
                return .none;
            };
            for (rows, side.partners) |*r, x| r.* = .{
                .champ = .{ .name = x.champ.name, .src = h.fmt("https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ d.ddragon, x.champ.key }) },
                .value = h.span(.{ .style = h.vars(.{ .c = fmt.WrColour{ .pts = x.usual } }) }, .{phrase.num(h, .points, x.usual)}),
                .note = phrase.num(h, .count, x.games),
            };
            const title = W.with.with(h, .{ .x = side.name });
            cards.add(h.div(.{ .key = k }, .{card.view(h, .{}, &.{ card.head(h, title, null, &.{}), champlist.view(h, .{ .label = title }, rows) })}));
        }
        return h.div(.{ .class = "row2" }, .{cards.done()});
    }
};

/// A share row of head to head: each side's part of its games
fn share(h: *H, label: tree.Text, a: [2]u32, b: [2]u32) versus.Row {
    const pa = rate(a[1], a[0]);
    const pb = rate(b[1], b[0]);
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

/// A timing row: both medians, the earlier bold and the gap under the label
fn timing(h: *H, label: tree.Text, t: [2]u16) versus.Row {
    const known = t[0] != 0 and t[1] != 0;
    const gap: u32 = if (known) @abs(@as(i32, t[0]) - t[1]) else 0;
    return .{
        .label = label,
        .a = if (t[0] != 0) phrase.num(h, .time, @as(u32, t[0])) else W.never,
        .b = if (t[1] != 0) phrase.num(h, .time, @as(u32, t[1])) else W.never,
        .lead = if (!known or gap == 0) null else if (t[0] < t[1]) .a else .b,
        .sub = if (gap == 0) null else if (gap < 60) W.apart.with(h, .{ .s = gap }) else W.apart_long.with(h, .{ .t = gap }),
    };
}

/// The axis fits the band to here: the lane and the first fights, before the spread of
/// long games (±3,000 gold) flattens every line to 0
const fit_minutes = 20;

fn floats(a: std.mem.Allocator, xs: []const i16) ![]const f32 {
    const out = try a.alloc(f32, xs.len);
    for (out, xs) |*o, x| o.* = @floatFromInt(x);
    return out;
}

fn pairs(a: std.mem.Allocator, xs: []const [2]i16) ![]const [2]f32 {
    const out = try a.alloc([2]f32, xs.len);
    for (out, xs) |*o, x| o.* = .{ @floatFromInt(x[0]), @floatFromInt(x[1]) };
    return out;
}

pub const css =
    \\@layer components {
    \\  .c-mpage .c-mstrip { margin-top: var(--sp-4); }
    \\  .c-mpage [data-thin] > .c-vs { opacity: 0.6; }
    \\  .c-mpage .lanerow { display: grid; gap: var(--sp-4); grid-template-columns: minmax(0, 1fr); }
    \\  @media (min-width: 1000px) {
    \\    .c-mpage .lanerow { grid-template-columns: minmax(0, 3fr) minmax(0, 2fr); }
    \\  }
    \\}
    \\
;
