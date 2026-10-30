//! The matchup page (/matchups/<role>/<x>-vs-<y>): one lane pair from x's side
//! (docs/plan/ui/matchup.md), the champion page with its opponent slot filled, as three
//! islands. Head: ChampHeader's pair with the headline figures, x's other lane opponents
//! and the view links. Build: the champion page's Build island on the pair's build (its
//! usual one when the pair is thin). More: head to head beside the lane by minute, won by
//! gold at 10, by game length, by rank and mastery, and bot lane partners.
//!
//! Pages are rendered on request, so each island's data rides in its root's data-bin
//! (base64 of ui.data) rather than a file: ui-matchup.wasm adopts Head and loads
//! ui-champbuild.wasm and ui-matchmore.wasm for the others
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const urls = @import("urls.zig");
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
    return .{ .name = c.name, .src = try a.print(champ.icon_fmt, .{ ddragon, c.key }) };
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
    pub const all_lanes = plain("dashed: all lanes");
    pub const by_length = plain("By game length");
    pub const length_tip = Phrase("{l:text} min: {r:rate} in {n:count} games, against everyone {a:rate}");
    pub const lengths = [3]tree.Text{ plain("<25"), plain("25-35"), plain("35+") };
    pub const everyone = Phrase("dashed: {x:text} against everyone");
    pub const by_rank = plain("By rank and mastery");
    pub const with = Phrase("{x:text} with");
    pub const partners = plain("Lane partners");
    pub const partners_key = plain("vs usual · games");
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
                .fig = .{ .s = try a.print("{d:.1}", .{r}) },
                .colour = .{ .pts = r - 50 },
                .href = try a.print("/matchups/{t}/{s}-vs-{s}{s}", .{ d.role, d.x.slug, o.o.slug, urls.view_queries[d.view] }),
                .current = std.mem.eql(u8, o.o.slug, d.y.slug),
                .thin = o.games < fmt.thin_games,
            };
        }
        const label = try a.print("{s}'s {s} opponents", .{ d.x.name, d.role.label().s });
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
                .champ = .{ .name = d.x.name, .src = h.fmt(champ.icon_fmt, .{ d.ddragon, d.x.key }) },
                .sub = W.sub.with(h, .{ .r = d.role.label().s, .p = d.patch }),
                .pair = .{
                    .champ = .{ .name = d.y.name, .src = h.fmt(champ.icon_fmt, .{ d.ddragon, d.y.key }) },
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
    /// By game length (W.lengths); all_* x's games against everyone in the role
    by_length: [3]Bucket = @splat(.{}),
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
    by_length: trend.Trend = .{ .label = W.by_length, .points = &.{} },
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
            h.div(.{ .class = "lanerow" }, .{ p.h2hCard(h), p.laneCard(h) }),
            h.div(.{ .class = "row3" }, .{ p.gold10Card(h), p.lengthCard(h), p.rankCard(h) }),
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
            lines(h, laneLines(h, d)),
        });
    }

    fn lines(h: *H, ts: []const tree.Text) N {
        if (ts.len == 0) return .none;
        var l = h.list();
        for (ts) |t| l.add(h.li(.{}, .{t}));
        return h.ul(.{ .class = "lines" }, .{l.done()});
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
            card.head(h, W.h2h, null, &.{versus.key(h, .{ p.data.x, p.data.y })}),
            h.div(.{ .data_thin = p.data.thin }, .{versus.rows(h, .{ p.data.x, p.data.y }, rows[0..n])}),
        });
    }

    fn gold10Card(p: *P, h: *H) N {
        const n = buckets(h, &p.gold10, &p.data.gold10, &W.buckets, W.gold10_tip);
        const note: N = if (p.gold10.base.len > 0) h.span(.{ .class = "lg" }, .{W.all_lanes}) else .none;
        return card.view(h, .{}, &.{ card.head(h, W.gold10, null, &.{note}), if (n > 0) p.gold10.view(h) else h.p(.{ .class = "none" }, .{W.none}) });
    }

    fn lengthCard(p: *P, h: *H) N {
        const n = buckets(h, &p.by_length, &p.data.by_length, &W.lengths, W.length_tip);
        const note: N = if (p.by_length.base.len > 0) h.span(.{ .class = "lg" }, .{W.everyone.with(h, .{ .x = p.data.x })}) else .none;
        return card.view(h, .{}, &.{ card.head(h, W.by_length, null, &.{note}), if (n > 1) p.by_length.view(h) else h.p(.{ .class = "none" }, .{W.none}) });
    }

    fn rankCard(p: *P, h: *H) N {
        return card.view(h, .{}, &.{ card.head(h, W.by_rank, null, &.{}), p.ranks.view(h) });
    }

    /// DuoPair: both sides' lane partners in one card, x's left and y's right (stacked
    /// when narrow)
    fn duos(p: *P, h: *H) N {
        const d = p.data;
        if (d.duos.len == 0) return .none;
        var sides = h.list();
        for (d.duos, 0..) |side, k| {
            const rows = h.mem.alloc(champlist.Row, side.partners.len) catch {
                h.oom = true;
                return .none;
            };
            for (rows, side.partners) |*r, x| r.* = .{
                .champ = .{ .name = x.champ.name, .src = h.fmt(champ.icon_fmt, .{ d.ddragon, x.champ.key }) },
                .value = h.span(.{ .style = h.vars(.{ .c = fmt.WrColour{ .pts = x.usual } }) }, .{phrase.num(h, .points, x.usual)}),
                .note = phrase.num(h, .count, x.games),
            };
            const title = W.with.with(h, .{ .x = side.name });
            sides.add(h.div(.{ .key = k, .class = "side" }, .{ h.h3(.{}, .{title}), champlist.view(h, .{ .label = title }, rows) }));
        }
        return card.view(h, .{}, &.{ card.head(h, W.partners, null, &.{h.span(.{ .class = "lg" }, .{W.partners_key})}), h.div(.{ .class = "partners" }, .{sides.done()}) });
    }
};

/// Lane minion gold per CS before 14 minutes: 3 melee (21), 3 casters (14) a wave and a
/// cannon (60 to 70) every third, 381 gold over 19 minions. Jungle camps and support
/// CS differ, so those roles get no split
pub const gold_per_cs = 20;

/// Under these a gap gets no line. The curves are already shrunk toward the champions'
/// baseline, so a small estimate is noise or the baseline, not this pair
const close_gold = 150;
const level6_gap = 10;
const item_gap = 20;
/// Points of games
const kill_gap = 5;

const L = struct {
    pub const level = Phrase("Gold is level at 14 min: {g:signed} for {x:text}.");
    pub const ahead = Phrase("{a:text} is {g:count} gold ahead at 14 min");
    pub const cs_all = Phrase("{l:text}, all of it from CS ({n:int} more, about {c:count} gold).");
    pub const cs_most = Phrase("{l:text}, most of it from CS ({n:int} more, about {c:count} gold).");
    pub const cs_some = Phrase("{l:text}, about {c:count} of it from CS ({n:int} more).");
    pub const cs_little = Phrase("{l:text}, little of it from CS.");
    pub const cs_against = Phrase("{l:text}, though {b:text} has {n:int} more CS.");
    pub const end = Phrase("{l:text}.");
    pub const kills = Phrase("{l:text} {p:text} {a:text} takes part in a kill on {b:text} in {k:pct} of games, {b:text} on {a:text} in {d:pct}.");
    pub const phases = [2]tree.Text{ plain("Before 6 min"), plain("From 6 to 14 min") };
    pub const flip = Phrase("{b:text} leads until {m:int} min ({e:count} gold at 6), {a:text} from {n:int} min on ({g:count} at 14).");
    pub const late = Phrase("{a:text}'s lead builds after 6 min: {e:count} gold at 6, {g:count} at 14.");
    pub const early = Phrase("{a:text}'s lead is there early: {e:count} gold by 6 min, {g:count} at 14.");
    pub const steady = Phrase("{a:text}'s lead grows through the lane: {e:count} gold at 6 min, {g:count} at 14.");
    pub const fades = Phrase("{a:text} is {e:count} gold ahead at 6 min, level by 14 ({g:signed} for {a:text}).");
    pub const level6 = Phrase("{a:text} reaches level 6 at {t:time}, {g:text} before {b:text}");
    pub const item = Phrase("{a:text} finishes a first item at {t:time}, {g:text} before {b:text}");
    pub const both = Phrase("{l:text}; {i:text}.");
    pub const same = Phrase("{l:text}, and finishes a first item at {t:time}, {g:text} earlier.");
    pub const secs = Phrase("{s:int} s");
    pub const mins = Phrase("{t:time}");
};

/// Up to three facts on how the lane goes, each with its numbers (site.md "Matchup page"):
/// where the gold at 14 comes from, when it appears, who reaches level 6 and a first item
/// first. None on a thin pair: the page greys its figures as the champions' baseline
pub fn laneLines(h: *H, d: *const MoreData) []const tree.Text {
    const out = h.mem.alloc(tree.Text, 3) catch {
        h.oom = true;
        return &.{};
    };
    if (d.thin) return out[0..0];
    var n: usize = 0;
    const k14 = 13;
    const gold = d.curves[0].line;
    if (gold.len > k14) {
        const g: i32 = gold[k14];
        const e: i32 = gold[5];
        const names = [2][]const u8{ d.x, d.y };
        const up: usize = if (g < 0) 1 else 0;
        const s: i32 = if (g < 0) -1 else 1;
        const a = names[up];
        const b = names[1 - up];
        if (@abs(g) < close_gold) {
            const early: usize = @intFromBool(e < 0);
            out[n] = if (@abs(e) >= close_gold) L.fades.with(h, .{ .a = names[early], .e = @abs(e), .g = if (e < 0) -g else g }) else L.level.with(h, .{ .g = g, .x = d.x });
            n += 1;
        } else {
            out[n] = source(h, d, a, b, s * g, up);
            n += 1;
            out[n] = if (s * e <= -close_gold / 2) flip: {
                var m: usize = 5;
                while (m < k14 and s * @as(i32, gold[m + 1]) < 0) m += 1;
                break :flip L.flip.with(h, .{ .a = a, .b = b, .m = m + 1, .e = @abs(e), .n = m + 2, .g = @abs(g) });
            } else if (3 * s * e < s * g) L.late.with(h, .{ .a = a, .e = @max(0, s * e), .g = @abs(g) }) else if (3 * s * e > 2 * s * g) L.early.with(h, .{ .a = a, .e = s * e, .g = @abs(g) }) else L.steady.with(h, .{ .a = a, .e = s * e, .g = @abs(g) });
            n += 1;
        }
    }
    if (spikes(h, d)) |t| {
        out[n] = t;
        n += 1;
    }
    return out[0..n];
}

/// The lead at 14 split into CS and the rest; the clearer kill gap by 14 when the rest
/// carries it
fn source(h: *H, d: *const MoreData, a: []const u8, b: []const u8, g: i32, up: usize) tree.Text {
    const lead = L.ahead.with(h, .{ .a = a, .g = g });
    var rest = g;
    const clause = if (d.role == .jungle or d.role == .support or d.curves[2].line.len <= 13) L.end.with(h, .{ .l = lead.s }) else cs: {
        const cs: i32 = if (up == 0) d.curves[2].line[13] else -@as(i32, d.curves[2].line[13]);
        const c = round10(cs * gold_per_cs);
        rest = g - c;
        break :cs if (cs < 0) L.cs_against.with(h, .{ .l = lead.s, .b = b, .n = -cs }) else if (c >= g) L.cs_all.with(h, .{ .l = lead.s, .n = cs, .c = c }) else if (3 * c >= 2 * g) L.cs_most.with(h, .{ .l = lead.s, .n = cs, .c = c }) else if (3 * c <= g) L.cs_little.with(h, .{ .l = lead.s }) else L.cs_some.with(h, .{ .l = lead.s, .c = c, .n = cs });
    };
    if (rest < close_gold or d.h2h.games == 0) return clause;
    const v = d.h2h;
    var best: ?usize = null;
    var best_gap: f32 = kill_gap;
    for (0..2) |p| {
        const k = if (up == 0) v.kills[p] else v.deaths[p];
        const o = if (up == 0) v.deaths[p] else v.kills[p];
        const gap = rate(v.games, k) - rate(v.games, o);
        if (gap >= best_gap) {
            best = p;
            best_gap = gap;
        }
    }
    const p = best orelse return clause;
    const k = if (up == 0) v.kills[p] else v.deaths[p];
    const o = if (up == 0) v.deaths[p] else v.kills[p];
    return L.kills.with(h, .{ .l = clause.s, .p = L.phases[p].s, .a = a, .b = b, .k = pct(v.games, k), .d = pct(v.games, o) });
}

fn spikes(h: *H, d: *const MoreData) ?tree.Text {
    const names = [2][]const u8{ d.x, d.y };
    const six = spike(h, d.h2h.level6, level6_gap);
    const item = spike(h, d.h2h.first_item, item_gap);
    const l = if (six) |x| L.level6.with(h, .{ .a = names[x.first], .t = x.t, .g = x.gap.s, .b = names[1 - x.first] }) else null;
    const i = item orelse return if (l) |t| L.end.with(h, .{ .l = t.s }) else null;
    if (six) |x| if (x.first == i.first) return L.same.with(h, .{ .l = l.?.s, .t = i.t, .g = i.gap.s });
    const it = L.item.with(h, .{ .a = names[i.first], .t = i.t, .g = i.gap.s, .b = names[1 - i.first] });
    return if (l) |t| L.both.with(h, .{ .l = t.s, .i = it.s }) else L.end.with(h, .{ .l = it.s });
}

const Spike = struct { first: usize, t: u32, gap: tree.Text };

fn spike(h: *H, t: [2]u16, min_gap: u32) ?Spike {
    if (t[0] == 0 or t[1] == 0) return null;
    const gap: u32 = @abs(@as(i32, t[0]) - t[1]);
    if (gap < min_gap) return null;
    const first: usize = @intFromBool(t[1] < t[0]);
    return .{ .first = first, .t = t[first], .gap = if (gap < 60) L.secs.with(h, .{ .s = gap }) else L.mins.with(h, .{ .t = gap }) };
}

fn pct(games: u32, k: u32) u32 {
    return @intFromFloat(@round(rate(games, k)));
}

fn round10(v: i32) i32 {
    return @divTrunc(v + if (v < 0) @as(i32, -5) else 5, 10) * 10;
}

/// `t`'s points from the buckets with games, its base their wider group's rates when
/// each has games; how many points
fn buckets(h: *H, t: *trend.Trend, bs: []const Bucket, labels: []const tree.Text, tip: anytype) usize {
    const pts = h.mem.alloc(trend.Point, bs.len) catch {
        h.oom = true;
        return 0;
    };
    const base = h.mem.alloc(f32, bs.len) catch {
        h.oom = true;
        return 0;
    };
    var n: usize = 0;
    var all = true;
    for (bs, labels) |b, l| {
        if (b.games == 0) continue;
        const a = rate(b.all_games, b.all_wins);
        pts[n] = .{
            .label = l,
            .sub = phrase.num(h, .kilo, b.games),
            .v = rate(b.games, b.wins),
            .ci = ci(b.games, b.wins),
            .tip = tip.with(h, .{ .l = l.s, .r = rate(b.games, b.wins), .n = b.games, .a = a }),
        };
        base[n] = a;
        all = all and b.all_games > 0;
        n += 1;
    }
    t.points = pts[0..n];
    t.base = if (all) base[0..n] else &.{};
    if (t.tip) |i| if (i >= n) {
        t.tip = null;
    };
    return n;
}

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
    \\  .c-mpage .partners { display: grid; gap: var(--sp-3) var(--sp-5); grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); }
    \\  .c-mpage .partners h3 { margin: 0 0 var(--sp-1); font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-mpage .c-head .lg { font-size: var(--fs-s); color: var(--muted); }
    \\  .c-mpage .lines { margin: var(--sp-3) 0 0; padding-left: var(--sp-4); font-size: var(--fs-s); color: var(--t2); }
    \\  .c-mpage .lanerow { display: grid; gap: var(--sp-4); grid-template-columns: minmax(0, 1fr); }
    \\  @media (min-width: 1000px) {
    \\    .c-mpage .lanerow { grid-template-columns: minmax(0, 2fr) minmax(0, 3fr); }
    \\  }
    \\}
    \\
;

const testing = std.testing;

/// Gold and CS lines through 14 min, linear from `at6` at 6 min to `at14`
fn testMore(a: std.mem.Allocator, at6: i16, at14: i16, cs14: i16) !MoreData {
    var curves: [3]Curve = undefined;
    for (&curves, [_][2]i16{ .{ at6, at14 }, .{ 0, 0 }, .{ @divTrunc(cs14, 2), cs14 } }) |*c, v| {
        const line = try a.alloc(i16, 15);
        for (line, 0..) |*l, i| {
            const t: i32 = @as(i32, @intCast(i)) - 5;
            l.* = @intCast(v[0] + @divTrunc((v[1] - v[0]) * t, 8));
        }
        c.* = .{ .line = line, .band = &.{} };
    }
    return .{
        .x = "Darius",
        .y = "Garen",
        .ddragon = "",
        .role = .top,
        .games = &.{},
        .curves = curves,
        .h2h = .{ .games = 1000, .wins = 520, .lane_games = 900, .ahead = 500, .behind = 400, .wins_ahead = 300, .wins_behind = 150, .first_blood = .{ 0, 0 }, .kills = .{ 200, 400, 300 }, .deaths = .{ 190, 250, 300 }, .level2 = .{ 0, 0 }, .level6 = .{ 365, 390 }, .first_item = .{ 640, 700 } },
        .gold10 = @splat(.{}),
        .ranks = &.{},
    };
}

test "lane lines: the lead's source and timing, the spikes, none when thin" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const eq = testing.expectEqualStrings;

    var d = try testMore(a, 100, 600, 12);
    var ls = laneLines(&h, &d);
    try testing.expectEqual(3, ls.len);
    try eq("Darius is 600 gold ahead at 14 min, about 240 of it from CS (12 more). From 6 to 14 min Darius takes part in a kill on Garen in 40% of games, Garen on Darius in 25%.", ls[0].s);
    try eq("Darius's lead builds after 6 min: 100 gold at 6, 600 at 14.", ls[1].s);
    try eq("Darius reaches level 6 at 6:05, 25 s before Garen, and finishes a first item at 10:40, 1:00 earlier.", ls[2].s);

    // Garen's side: an early Darius lead turned, and most of it CS
    d = try testMore(a, 200, -400, -20);
    d.h2h.level6 = .{ 380, 385 };
    ls = laneLines(&h, &d);
    try testing.expectEqual(3, ls.len);
    try eq("Garen is 400 gold ahead at 14 min, all of it from CS (20 more, about 400 gold).", ls[0].s);
    try eq("Darius leads until 8 min (200 gold at 6), Garen from 9 min on (400 at 14).", ls[1].s);
    try eq("Darius finishes a first item at 10:40, 1:00 before Garen.", ls[2].s);

    d = try testMore(a, -300, 60, 0);
    d.h2h.first_item = .{ 0, 700 };
    ls = laneLines(&h, &d);
    try testing.expectEqual(2, ls.len);
    try eq("Garen is 300 gold ahead at 6 min, level by 14 (\u{2212}60 for Garen).", ls[0].s);

    try eq("Darius reaches level 6 at 6:05, 25 s before Garen.", ls[1].s);
    d.h2h.first_item = .{ 700, 640 };
    try eq("Darius reaches level 6 at 6:05, 25 s before Garen; Garen finishes a first item at 10:40, 1:00 before Darius.", laneLines(&h, &d)[1].s);

    d.thin = true;
    try testing.expectEqual(0, laneLines(&h, &d).len);
}
