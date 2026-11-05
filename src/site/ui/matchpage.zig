//! The matchup page (/matchups/<role>/<x>-vs-<y>): one lane pair from x's side
//! (docs/plan/ui/matchup.md), the champion page with its opponent slot filled, as three
//! islands, lane first. Head: ChampHeader's pair with the headline figures, x's other lane
//! opponents and the view links. More's lane part: head to head beside the lane by
//! minute. Build: the champion page's Build island on the pair's build (its usual one when
//! the pair is thin). More's outcome part: won by gold at 10, by game length, by rank and
//! mastery, and bot lane partners.
//!
//! Pages are rendered on request, so each island's data rides in its root's data-bin
//! (base64 of ui.data) rather than a file: ui-matchup.wasm adopts Head and loads
//! ui-champbuild.wasm and ui-matchmore.wasm for the others. More's two parts share the
//! lane part's data-bin and file
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
const stat = @import("stat.zig");
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

const rate = trend.rate;

const n_views = 4;

/// ui-matchup.wasm's
/// A role in a sentence ("84% top"), role.Role's order
const role_word = [_][]const u8{ "top", "jungle", "mid", "bot", "support" };

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
    /// y's games in this role, % of all its games, when an off-role pick
    y_share: ?f32 = null,
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
    pub const y_share = Phrase("{s:pct} {r:text}");
    pub const wins = Phrase("{c:text} wins");
    pub const usual = plain("Vs usual");
    pub const usually = Phrase("{r:rate} usually");
    pub const gold = plain("Gold at 14");
    pub const gold_ahead = Phrase("{c:text} ahead");
    pub const gold_level = plain("level");
    pub const cs_part = Phrase("At 14 minutes, estimated from games of every length; about {g:count} of it from CS.");
    pub const cs_other = Phrase("At 14 minutes, estimated from games of every length; {c:text} about {g:count} gold ahead on CS.");
    pub const gold_note = plain("At 14 minutes, estimated from games of every length.");
    pub const ahead = plain("Ahead at 14");
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
    pub const kills = [3]tree.Text{ plain("Kill by 6:00"), plain("Kill 6-14"), plain("Kill after 14") };
    pub const level2 = plain("Level 2");
    pub const level6 = plain("Level 6");
    pub const first_item = plain("First item");
    pub const apart = Phrase("{s:int} s apart");
    pub const apart_long = Phrase("{t:time} apart");
    pub const never = plain("-");
    pub const gold10 = plain("Won by gold at 10");
    pub const gold10_tip = Phrase("at 10 min: {r:rate} in {n:count} games, all lanes {a:rate}");
    pub const buckets = [5]tree.Text{ plain("-1.5k"), plain("-1k"), plain("0"), plain("+1k"), plain("+1.5k") };
    pub const all_lanes = plain("dashed: all lanes");
    pub const by_length = plain("By game length");
    pub const length_tip = Phrase("min: {r:rate} in {n:count} games, against everyone {a:rate}");
    pub const lengths = [3]tree.Text{ plain("<25"), plain("25-35"), plain("35+") };
    pub const everyone = Phrase("dashed: {x:text} against everyone");
    pub const by_rank = plain("By rank and mastery");
    pub const with = Phrase("{x:text} with");
    pub const partners = plain("Lane partners");
    pub const partners_key = plain("vs usual · games");
    pub const cs_from = Phrase("{c:count} from CS");
    pub const cs_all = Phrase("CS worth {c:count}");
    pub const swing = Phrase("{g:signed} in 3 min");
    pub const lead6 = Phrase("{n:text} level 6");
    pub const lead_item = Phrase("{n:text} first item");
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
                .thin = fmt.wide(fmt.range(o.games, o.wins)),
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
                    .note = if (d.y_share) |s| W.y_share.with(h, .{ .s = @as(u32, @intFromFloat(@round(s))), .r = role_word[@backingInt(d.role)] }) else null,
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
        var items: [4]strip.Item = undefined;
        var n: usize = 0;
        items[n] = .{ .label = W.wins.with(h, .{ .c = d.x.name }), .value = phrase.num(h, .rate, won), .range = fmt.range(d.games, d.wins), .ends = stat.endsGames(h, .rate, won, fmt.range(d.games, d.wins), d.games), .games = phrase.num(h, .kilo, d.games), .step = .of(won - 50, fmt.win_cuts), .answer = true };
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
                .value = phrase.num(h, .count, @abs(@as(i32, g))),
                .ctx = if (g == 0) W.gold_level else W.gold_ahead.with(h, .{ .c = if (g > 0) d.x.name else d.y.name }),
                .tip = .{ .id = "mu-gold", .note = goldNote(h, d, g) },
            };
            n += 1;
        }
        if (d.lane_games > 0) {
            items[n] = .{ .label = W.ahead, .value = phrase.num(h, .pct, @as(u32, @intFromFloat(@round(rate(d.lane_games, d.ahead))))) };
            n += 1;
        }
        return strip.view(h, items[0..n]);
    }

    /// Where Gold at 14 comes from, without a sign to read the wrong way round
    fn goldNote(h: *H, d: *const HeadData, g: i16) tree.Text {
        const c: i32 = d.cs_gold orelse return W.gold_note;
        if (@abs(c) < 10) return W.gold_note;
        if ((c < 0) == (g < 0)) return W.cs_part.with(h, .{ .g = @abs(c) });
        return W.cs_other.with(h, .{ .c = if (c > 0) d.x.name else d.y.name, .g = @abs(c) });
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
    marks: LaneMarks = .{},
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
    .compact = true,
};

fn rankName(h: *H, r: *const RankRow) N {
    return h.span(.{}, .{r.label});
}

fn rankOrder(r: *const RankRow) f64 {
    return -@as(f64, @floatFromInt(r.order));
}

fn rankRate(h: *H, r: *const RankRow) N {
    return stat.view(h, .{ .value = rate(r.games, r.wins), .scale = .aggregate, .ref = 50, .range = fmt.range(r.games, r.wins) });
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

/// The lane row, or the outcome row and partners (ui-matchmore.wasm, loaded after Head)
pub const More = struct {
    data: *const MoreData,
    part: Part = .lane,
    chart: lane.Lane,
    gold10: trend.Trend = .{ .label = W.gold10, .points = &.{} },
    by_length: trend.Trend = .{ .label = W.by_length, .points = &.{} },
    ranks: Ranks,
    bin: []const u8 = "",
    /// ui-matchmore.js and .wasm, for ui-matchup.wasm to load
    js: ?[]const u8 = null,
    wasm: ?[]const u8 = null,

    const P = @This();

    /// Each its own island root, so the build can sit between them in the page's order
    pub const Part = enum { lane, outcome };

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
        return switch (p.part) {
            .lane => h.div(.{ .class = "part", .data_island = "matchmore", .data_bin = if (p.bin.len > 0) p.bin else null, .data_js = p.js, .data_wasm = p.wasm }, .{
                h.div(.{ .class = "lanerow" }, .{ p.h2hCard(h), p.laneCard(h) }),
            }),
            .outcome => h.div(.{ .class = "part", .data_island = "matchout" }, .{
                h.div(.{ .class = "row3" }, .{ p.gold10Card(h), p.lengthCard(h), p.rankCard(h) }),
                p.duos(h),
            }),
        };
    }

    fn laneCard(p: *P, h: *H) N {
        const d = p.data;
        const few: N = if (d.thin) badge.view(h, .few, .{W.few}) else .none;
        if (d.games.len < 2) return card.view(h, .{}, &.{ card.head(h, W.lane_head, null, &.{few}), h.p(.{ .class = "none" }, .{W.none}) });
        return card.view(h, .{}, &.{
            card.head(h, W.lane_head, null, &.{ few, p.chart.switcher(h) }),
            h.div(.{ .class = "plot", .data_thin = d.thin }, .{p.chart.viewMarked(h, .none, marks(h, d))}),
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
            card.head(h, W.h2h, null, &.{versus.key(h, .{ p.data.x, p.data.y })}),
            versus.rows(h, .{ p.data.x, p.data.y }, rows[0..n]),
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

/// Under these a gap gets no mark. The curves are already shrunk toward the champions'
/// baseline, so a small estimate is noise or the baseline, not this pair
const close_gold = 150;
const level_gold = 50;
const swing_gold = 100;
/// A swing is an event only this far over the line's mean 3 min move; under it, it's
/// the ordinary slope
const swing_over_mean = 1.5;
const level6_gap = 10;
const item_gap = 20;

/// What the lane chart marks on its Gold line, the facts its line alone doesn't say:
/// the gap at 6 and 14 min with its CS part, the three minutes where gold moves most and
/// a level 6 or first item lead inside them (site.md "Matchup page")
pub const LaneMarks = struct {
    /// gold 0: none
    at: [2]Gap = @splat(.{}),
    /// From minute m to m + 3
    swing: Gap = .{},
    lead: ?Lead = null,
};

/// The gap's size at minute m, y's side when `y`, and the gold its CS gap is worth when
/// on the same side
pub const Gap = struct { m: u8 = 0, gold: u16 = 0, y: bool = false, cs: u16 = 0 };

/// The side gaining the swing (y's when `y`) got there at t s, clearly before the other
pub const Lead = struct { what: enum(u8) { level6, item }, y: bool, t: u16 };

/// None on a thin pair: the page greys its figures as the champions' baseline. Curves
/// index i is minute i
pub fn laneMarks(d: *const MoreData) LaneMarks {
    var out: LaneMarks = .{};
    const gold = d.curves[0].line;
    const end = 14;
    if (d.thin or gold.len <= end) return out;
    const cs = d.curves[2].line;
    const has_cs = !(d.role == .jungle or d.role == .support or cs.len <= end);
    if (@abs(gold[6]) >= close_gold or @abs(gold[end]) >= close_gold) {
        var n: usize = 0;
        for ([2]u8{ 6, end }) |m| {
            const g: i32 = gold[m];
            if (@abs(g) < level_gold) continue;
            out.at[n] = .{ .m = m, .gold = size(g), .y = g < 0, .cs = if (has_cs) csWorth(g, cs[m]) else 0 };
            n += 1;
        }
    }
    var best: u8 = 0;
    var gain: i32 = 0;
    var sum: u32 = 0;
    for (0..end - 2) |i| {
        const v = @as(i32, gold[i + 3]) - gold[i];
        sum += @abs(v);
        if (@abs(v) > @abs(gain)) {
            best = @intCast(i);
            gain = v;
        }
    }
    const mean = @as(f32, @floatFromInt(sum)) / (end - 2);
    if (@abs(gain) < swing_gold or @as(f32, @floatFromInt(@abs(gain))) < swing_over_mean * mean) return out;
    out.swing = .{ .m = best, .gold = size(gain), .y = gain < 0 };
    const side: usize = @intFromBool(gain < 0);
    const lo = @as(u32, best) * 60;
    const hi = lo + 180;
    if (lead(d.h2h.level6, side, level6_gap, lo, hi)) |t| {
        out.lead = .{ .what = .level6, .y = side == 1, .t = t };
    } else if (lead(d.h2h.first_item, side, item_gap, lo, hi)) |t| {
        out.lead = .{ .what = .item, .y = side == 1, .t = t };
    }
    return out;
}

fn size(v: i32) u16 {
    return @intCast(@min(@abs(v), std.math.maxInt(u16)));
}

/// What `cs` (x minus y) is worth in gold, for the side `gold` leans to; 0 when CS went
/// the other way or is too small to say
fn csWorth(gold: i32, cs: i32) u16 {
    const c = round10(std.math.sign(gold) * cs * gold_per_cs);
    return if (c < 10) 0 else size(c);
}

/// `side`'s median when at least `min_gap` s before the other's, inside [lo, hi]
fn lead(t: [2]u16, side: usize, min_gap: u32, lo: u32, hi: u32) ?u16 {
    const mine: u32 = t[side];
    const theirs: u32 = t[1 - side];
    if (mine == 0 or theirs < mine + min_gap or mine < lo or mine > hi) return null;
    return t[side];
}

fn round10(v: i32) i32 {
    return @divTrunc(v + if (v < 0) @as(i32, -5) else 5, 10) * 10;
}

/// The chart's sign: y's side is below 0
fn signed(g: Gap) i32 {
    return if (g.y) -@as(i32, g.gold) else g.gold;
}

/// `d.marks` for the chart, in words
fn marks(h: *H, d: *const MoreData) lane.Marks {
    const m = d.marks;
    const notes = h.mem.alloc(lane.Note, 2) catch {
        h.oom = true;
        return .{};
    };
    var n: usize = 0;
    for (m.at) |g| {
        if (g.gold == 0) continue;
        notes[n] = .{
            .m = g.m,
            .label = phrase.num(h, .signed, signed(g)),
            .sub = if (g.cs == 0) null else if (g.cs > g.gold) W.cs_all.with(h, .{ .c = g.cs }) else W.cs_from.with(h, .{ .c = g.cs }),
        };
        n += 1;
    }
    var out: lane.Marks = .{ .notes = notes[0..n] };
    if (m.swing.gold > 0) out.span = .{ .a = m.swing.m, .b = m.swing.m + 3, .label = W.swing.with(h, .{ .g = signed(m.swing) }) };
    if (m.lead) |l| {
        const who = if (l.y) d.y else d.x;
        const one = h.mem.alloc(lane.AxisNote, 1) catch {
            h.oom = true;
            return out;
        };
        one[0] = .{ .t = l.t, .label = switch (l.what) {
            .level6 => W.lead6.with(h, .{ .n = who }),
            .item => W.lead_item.with(h, .{ .n = who }),
        } };
        out.axis = one;
    }
    return out;
}

/// `t`'s points from the buckets over the games floor (a thinner one's band drags the line),
/// its base their wider group's rates when each has games; how many points
fn buckets(h: *H, t: *trend.Trend, bs: []const Bucket, labels: []const tree.Text, tip: anytype) usize {
    const pts = trend.alloc(h, bs.len) orelse return 0;
    var base: [8]f32 = undefined;
    std.debug.assert(bs.len <= base.len);
    var n: usize = 0;
    var all = true;
    for (bs, labels) |b, l| {
        if (b.games < fmt.floor_games) continue;
        const a = rate(b.all_games, b.all_wins);
        pts[n] = trend.point(h, l, b.games, b.wins, tip.with(h, .{ .r = rate(b.games, b.wins), .n = b.games, .a = a }));
        base[n] = a;
        all = all and b.all_games > 0;
        n += 1;
    }
    t.set(pts[0..n]);
    t.base = &.{};
    if (all) t.base = h.mem.dupe(f32, base[0..n]) catch blk: {
        h.oom = true;
        break :blk &.{};
    };
    return n;
}

/// A share row of head to head: each side's part of its games ([part, of])
fn share(h: *H, label: tree.Text, a: [2]u32, b: [2]u32) versus.Row {
    var r = versus.shares(h, label, rate(a[1], a[0]) / 100, rate(b[1], b[0]) / 100);
    r.wide = fmt.wide(@max(fmt.range(a[1], a[0]), fmt.range(b[1], b[0])));
    return r;
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
    \\  .c-mpage .partners { display: grid; gap: var(--sp-3) var(--sp-5); grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); }
    \\  .c-mpage .partners h3 { margin: 0 0 var(--sp-1); font-size: var(--fs-s); font-weight: var(--w-m); color: var(--t2); }
    \\  .c-mpage .c-head .lg { font-size: var(--fs-s); color: var(--muted); }
    \\  .c-mpage .lanerow { display: grid; gap: var(--sp-4); grid-template-columns: minmax(0, 1fr); }
    \\  @media (min-width: 1000px) {
    \\    .c-mpage .lanerow { grid-template-columns: minmax(0, 2fr) minmax(0, 3fr); }
    \\  }
    \\}
    \\
;

const testing = std.testing;

/// Gold by minute 0 to 14; CS 0 to 6 min then a straight line to `cs14`
fn testMore(a: std.mem.Allocator, gold: [15]i16, cs6: i16, cs14: i16) !MoreData {
    const cs = try a.alloc(i16, 15);
    for (cs, 0..) |*c, i| {
        const t: i16 = @intCast(i);
        c.* = if (i <= 6) @divTrunc(cs6 * t, 6) else cs6 + @divTrunc((cs14 - cs6) * (t - 6), 8);
    }
    return .{
        .x = "Darius",
        .y = "Garen",
        .ddragon = "",
        .role = .top,
        .games = &.{},
        .curves = .{ .{ .line = try a.dupe(i16, &gold), .band = &.{} }, .{ .line = &.{}, .band = &.{} }, .{ .line = cs, .band = &.{} } },
        .h2h = .{ .games = 1000, .wins = 520, .lane_games = 900, .ahead = 500, .behind = 400, .wins_ahead = 300, .wins_behind = 150, .first_blood = .{ 0, 0 }, .kills = .{ 200, 400, 300 }, .deaths = .{ 190, 250, 300 }, .level2 = .{ 0, 0 }, .level6 = .{ 365, 390 }, .first_item = .{ 640, 700 } },
        .gold10 = @splat(.{}),
        .ranks = &.{},
    };
}

test "lane marks: the gap at 6 and 14 with CS, a swing over the slope with a lead in it, none when thin" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const eq = testing.expectEqualDeep;

    var d = try testMore(a, .{ 0, 0, 10, 20, 40, 60, 100, 180, 280, 360, 420, 480, 530, 570, 600 }, 2, 12);
    var m = laneMarks(&d);
    try eq([2]Gap{ .{ .m = 6, .gold = 100, .cs = 40 }, .{ .m = 14, .gold = 600, .cs = 240 } }, m.at);
    // 260 against a mean 3 min move of 141
    try eq(Gap{ .m = 6, .gold = 260 }, m.swing);
    try eq(Lead{ .what = .level6, .y = false, .t = 365 }, m.lead.?);

    d.role = .jungle;
    try testing.expectEqual(0, laneMarks(&d).at[0].cs);

    // A small early lead the other way: its size, CS only on the side it leans to
    d = try testMore(a, .{ 0, 0, -5, -10, -15, -20, -60, 0, 60, 120, 180, 240, 300, 360, 420 }, 1, 6);
    try eq([2]Gap{ .{ .m = 6, .gold = 60, .y = true }, .{ .m = 14, .gold = 420, .cs = 120 } }, laneMarks(&d).at);
    // Level at 6: no dot there
    d = try testMore(a, .{ 0, 0, -5, -10, -15, -20, -23, 0, 60, 120, 180, 240, 300, 360, 420 }, 0, 6);
    try eq([2]Gap{ .{ .m = 14, .gold = 420, .cs = 120 }, .{} }, laneMarks(&d).at);

    // An early Darius lead turned; Garen's first item inside the swing
    d = try testMore(a, .{ 0, 0, 50, 100, 150, 200, 200, 100, -50, -150, -200, -240, -280, -320, -360 }, 0, -20);
    d.h2h.first_item = .{ 700, 520 };
    m = laneMarks(&d);
    try eq([2]Gap{ .{ .m = 6, .gold = 200 }, .{ .m = 14, .gold = 360, .y = true, .cs = 400 } }, m.at);
    try eq(Gap{ .m = 6, .gold = 350, .y = true }, m.swing);
    try eq(Lead{ .what = .item, .y = true, .t = 520 }, m.lead.?);

    // Faded by 14: the 6 min dot alone. Its biggest move, 160, is the ordinary slope
    // (mean 127): no swing, so no lead either
    d = try testMore(a, .{ 0, 0, -50, -100, -150, -200, -260, -280, -250, -200, -150, -100, -50, 0, 40 }, 0, 0);
    m = laneMarks(&d);
    try eq([2]Gap{ .{ .m = 6, .gold = 260, .y = true }, .{} }, m.at);
    try eq(Gap{}, m.swing);
    try testing.expect(m.lead == null);

    d = try testMore(a, @splat(20), 0, 0);
    try eq(LaneMarks{}, laneMarks(&d));

    d = try testMore(a, .{ 0, 0, 10, 20, 40, 60, 100, 180, 280, 360, 420, 480, 530, 570, 600 }, 2, 12);
    d.thin = true;
    try eq(LaneMarks{}, laneMarks(&d));
}

test "buckets: one under the games floor isn't drawn" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var tr: trend.Trend = .{ .label = W.by_length, .points = &.{} };
    const bs = [3]Bucket{ .{ .games = 120, .wins = 60 }, .{ .games = fmt.floor_games - 1, .wins = 9 }, .{ .games = fmt.floor_games, .wins = 16 } };
    try testing.expectEqual(2, buckets(&h, &tr, &bs, &W.lengths, W.length_tip));
}
