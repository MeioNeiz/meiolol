//! The Your games page's Over time view (your-games.md "Over time"): each game on a
//! GameTrend of the chosen measure, Patterns (win rate by game length against your own),
//! and a sortable table of the games by champion, matchup or week. From the List alone,
//! on the filtered games. Island YourTime (ui-yourtime.wasm), between YourViews and
//! YourList on the page, shown by YourViews' Over time tab; its file loads when it shows.
//! The filter is read from the URL, written by the other two
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const fmt = @import("fmt.zig");
const yl = @import("yourlist.zig");
const yp = @import("yourpage.zig");
const card = @import("card.zig");
const chart = @import("chart.zig");
const gametrend = @import("gametrend.zig");
const segmented = @import("segmented.zig");
const table = @import("table.zig");
const delta = @import("delta.zig");
const spark = @import("spark.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const url = @import("url.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Role = role.Role;

pub const name = "YourTime";
pub const scope = .{ ".c-ytime", ".c-tcard" };
pub const sel = "[data-island=yourtime]";

pub const Measure = enum { wc, vt, g14, kda, cs };
pub const By = enum { champ, matchup, week };

/// Under this a game is an early surrender: on the record, never a figure
const short_s = 300;
const n_measures = @typeInfo(Measure).@"enum".field_names.len;

const W = struct {
    pub const each = plain("Each game");
    pub const measure = plain("Measure");
    pub const wc = plain("Win at 15");
    pub const vt = plain("Vs typical");
    pub const g14 = plain("Gold 14");
    pub const kda = plain("KDA");
    pub const cs = plain("CS/min");
    pub const chance = plain("Win chance");
    pub const time = plain("Over time");
    pub const recent = plain("Win at 15, last 5");
    pub const patterns = plain("Patterns");
    pub const length = plain("Length");
    pub const under = plain("Under 25");
    pub const mid = plain("25–35");
    pub const over = plain("Over 35");
    pub const vs_rate = Phrase("vs {p:pct}");
    pub const by = plain("By");
    pub const group = plain("Group");
    pub const champion = plain("Champion");
    pub const matchup = plain("Matchup");
    pub const week = plain("Week");
    pub const games = plain("Games");
    pub const wl = plain("W–L");
    pub const per = plain("Per game");
    pub const last = plain("Last");
    pub const none = plain("No games match");
    pub const no_measure = plain("No games with this figure");
    pub const score = Phrase("{w:int}–{l:int}");
    pub const vs = Phrase("{a:text} vs {b:text}");
    pub const dot = Phrase("{c:text} · {v:text} · {d:text}");
    pub const one = plain("one-game matchups");
    pub const wc_tip = plain("Your team's win chance at 15 minutes, on average.");
    pub const vt_tip = plain("Your gold lead at 14 over the matchup's typical one.");
    pub const dash = plain("–");
};

fn kdaOf(g: yl.Game) f32 {
    return @as(f32, @floatFromInt(@as(u32, g.k) + g.a)) / @as(f32, @floatFromInt(@max(g.d, 1)));
}

/// The game's figure; null without it (no timeline, no lane, an early surrender)
pub fn valueOf(m: Measure, g: yl.Game) ?f32 {
    if (g.remake or g.dur < short_s) return null;
    return switch (m) {
        .wc => if (g.wc.len > 15) @floatFromInt(g.wc[15]) else null,
        .g14 => if (g.lane14) |x| @floatFromInt(x.you) else null,
        .vt => if (g.lane14) |x| if (x.typ) |t| @floatFromInt(x.you - t[1]) else null else null,
        .kda => kdaOf(g),
        .cs => if (g.cs) |c| @as(f32, @floatFromInt(c)) * 60 / @as(f32, @floatFromInt(g.dur)) else null,
    };
}

fn int(v: f32) i32 {
    return @intFromFloat(@round(v));
}

fn text(h: *H, m: Measure, v: f32) tree.Text {
    return switch (m) {
        .wc => phrase.num(h, .pct, int(v)),
        .vt, .g14 => phrase.num(h, .signed, int(v)),
        .kda, .cs => phrase.num(h, .dec, v),
    };
}

fn labelOf(m: Measure) tree.Text {
    return switch (m) {
        .wc => W.wc,
        .vt => W.vt,
        .g14 => W.g14,
        .kda => W.kda,
        .cs => W.cs,
    };
}

/// Monday-based weeks: 1 January 1970 was a Thursday
fn weekOf(day: i32) i32 {
    return @divFloor(day + 3, 7);
}

const Avg = struct {
    sum: f32 = 0,
    n: u16 = 0,

    fn add(a: *Avg, v: ?f32) void {
        const x = v orelse return;
        a.sum += x;
        a.n += 1;
    }

    fn of(a: Avg) ?f32 {
        return if (a.n == 0) null else a.sum / @as(f32, @floatFromInt(a.n));
    }
};

/// A table row: a champion in a role, a matchup or a week
pub const Row = struct {
    l: *const yl.List,
    champ: u16 = 0,
    role: ?Role = null,
    opp: ?u16 = null,
    /// The week's Monday (yl.dayOf)
    day: i32 = 0,
    /// The first column's A to Z
    key: []const u8 = "",
    t: yl.Totals = .{},
    wc: Avg = .{},
    g14: Avg = .{},
    vt: Avg = .{},
    /// The chosen measure per game, oldest first
    per: std.ArrayList(f32) = .empty,
    last_ms: i64 = 0,
    last_day: i32 = 0,

    fn same(r: *const Row, by: By, g: yl.Game, week: i32) bool {
        return switch (by) {
            .champ => r.champ == g.champ and r.role == g.role,
            .matchup => r.champ == g.champ and r.opp == g.opp,
            .week => r.day == week * 7 - 3,
        };
    }
};

/// `games` the filtered list, newest first
pub fn rowsOf(h: *H, l: *const yl.List, games: []const yl.Game, by: By, m: Measure, tz_min: i32) ![]Row {
    const a = h.mem;
    var out: std.ArrayList(Row) = .empty;
    var i = games.len;
    while (i > 0) {
        i -= 1;
        const g = games[i];
        if (g.remake or (by == .matchup and g.opp == null)) continue;
        const day = yl.dayOf(g.start_ms, tz_min);
        const week = weekOf(day);
        const r = for (out.items) |*r| {
            if (r.same(by, g, week)) break r;
        } else blk: {
            var r: Row = .{ .l = l, .champ = g.champ, .role = g.role, .opp = if (by == .matchup) g.opp else null, .day = week * 7 - 3 };
            r.key = switch (by) {
                .champ => l.champs[g.champ].name,
                .matchup => try std.fmt.allocPrint(a, "{s} {s}", .{ l.champs[g.champ].name, l.champs[g.opp.?].name }),
                .week => "",
            };
            try out.append(a, r);
            break :blk &out.items[out.items.len - 1];
        };
        r.t.add(g);
        r.wc.add(valueOf(.wc, g));
        r.g14.add(valueOf(.g14, g));
        r.vt.add(valueOf(.vt, g));
        if (valueOf(m, g)) |v| try r.per.append(a, v);
        r.last_ms = g.start_ms;
        r.last_day = day;
    }
    return out.items;
}

fn nameCell(h: *H, r: *const Row) N {
    const me = r.l.champs[r.champ];
    if (r.opp) |o| return h.span(.{ .class = "who" }, .{
        champ.view(h, me, .{ .px = .@"20", .named = false }),
        champ.view(h, r.l.champs[o], .{ .px = .@"20", .named = false }),
        h.span(.{}, .{W.vs.with(h, .{ .a = me.name, .b = r.l.champs[o].name })}),
    });
    return h.span(.{ .class = "who" }, .{
        champ.view(h, me, .{ .px = .@"20", .named = false }),
        h.span(.{}, .{me.name}),
        if (r.role) |x| role.view(h, x, .{ .s = .s }) else null,
    });
}

fn weekCell(h: *H, r: *const Row) N {
    return h.span(.{}, .{yp.dayText(h, r.day)});
}

fn keyOf(r: *const Row) []const u8 {
    return r.key;
}

fn dayOf(r: *const Row) f64 {
    return @floatFromInt(r.day);
}

fn gamesOf(r: *const Row) f64 {
    return @floatFromInt(r.t.games);
}

fn gamesCell(h: *H, r: *const Row) N {
    return h.span(.{}, .{r.t.games});
}

fn rateOf(r: *const Row) f64 {
    return @as(f64, @floatFromInt(r.t.wins)) / @as(f64, @floatFromInt(@max(r.t.games, 1)));
}

fn wlCell(h: *H, r: *const Row) N {
    return h.span(.{ .class = "wl" }, .{
        W.score.with(h, .{ .w = r.t.wins, .l = r.t.losses() }),
        h.span(.{ .class = "bar", .style = h.vars(.{ .p = @round(rateOf(r) * 100) }) }, .{}),
    });
}

fn kdaSort(r: *const Row) f64 {
    return r.t.kda();
}

fn kdaCell(h: *H, r: *const Row) N {
    return h.span(.{}, .{phrase.num(h, .dec, r.t.kda())});
}

fn sortOf(a: Avg) f64 {
    return a.of() orelse -std.math.inf(f64);
}

fn wcSort(r: *const Row) f64 {
    return sortOf(r.wc);
}

fn g14Sort(r: *const Row) f64 {
    return sortOf(r.g14);
}

fn vtSort(r: *const Row) f64 {
    return sortOf(r.vt);
}

fn wcCell(h: *H, r: *const Row) N {
    const v = r.wc.of() orelse return h.span(.{ .class = "na" }, .{W.dash});
    return h.span(.{ .style = h.vars(.{ .c = fmt.Step.of(v - 50, fmt.game_cuts) }), .class = "v" }, .{text(h, .wc, v)});
}

fn goldCell(h: *H, a: Avg) N {
    const v = a.of() orelse return h.span(.{ .class = "na" }, .{W.dash});
    return h.span(.{ .style = h.vars(.{ .c = fmt.Step.of(v, gold_cuts) }), .class = "v" }, .{text(h, .g14, v)});
}

fn g14Cell(h: *H, r: *const Row) N {
    return goldCell(h, r.g14);
}

fn vtCell(h: *H, r: *const Row) N {
    return goldCell(h, r.vt);
}

/// Lane gold's colour steps, Highlights' too
const gold_cuts: [4]f32 = .{ 250, 750, 1500, 2500 };

fn perCell(h: *H, r: *const Row) N {
    return spark.view(h, .{ .vs = r.per.items, .w = 64, .h = 20 });
}

fn lastOf(r: *const Row) f64 {
    return @floatFromInt(r.last_ms);
}

fn lastCell(h: *H, r: *const Row) N {
    return h.span(.{}, .{yp.dayText(h, r.last_day)});
}

fn oneGame(r: *const Row) bool {
    return r.t.games < 2;
}

/// The three tables share all but the first column (its name, how it sorts) and the
/// matchups' one-game rows behind a chip
fn specOf(comptime by: By) table.Spec(Row) {
    const first: table.Column(Row) = switch (by) {
        .champ => .{ .label = W.champion, .cell = nameCell, .name = keyOf, .num = false },
        .matchup => .{ .label = W.matchup, .cell = nameCell, .name = keyOf, .num = false },
        .week => .{ .label = W.week, .cell = weekCell, .sort = dayOf, .num = false },
    };
    return .{
        .title = W.by,
        .columns = &.{
            first,
            // W–L says it on a phone
            .{ .label = W.games, .cell = gamesCell, .sort = gamesOf, .priority = 2 },
            .{ .label = W.wl, .cell = wlCell, .sort = rateOf, .answer = true },
            .{ .label = W.kda, .cell = kdaCell, .sort = kdaSort, .priority = 2 },
            .{ .label = W.chance, .cell = wcCell, .sort = wcSort, .tip = W.wc_tip },
            .{ .label = W.g14, .cell = g14Cell, .sort = g14Sort, .priority = 3 },
            .{ .label = W.vt, .cell = vtCell, .sort = vtSort, .priority = 2, .tip = W.vt_tip },
            .{ .label = W.per, .cell = perCell, .num = false, .priority = 3 },
            .{ .label = W.last, .cell = lastCell, .sort = lastOf, .priority = 3 },
        },
        .default_sort = if (by == .week) 0 else 1,
        .bare = true,
        .key = @tagName(by),
        .rare = if (by == .matchup) oneGame else null,
        .rare_name = W.one,
    };
}

pub const ChampTable = table.DataTable(Row, specOf(.champ));
pub const MatchupTable = table.DataTable(Row, specOf(.matchup));
pub const WeekTable = table.DataTable(Row, specOf(.week));

pub const YourTime = struct {
    l: *const yl.List,
    filter: yl.Filter = .{},
    m: Measure = .wc,
    by: By = .champ,
    champs: ChampTable = .{ .rows = &.{} },
    matchups: MatchupTable = .{ .rows = &.{} },
    weeks: WeekTable = .{ .rows = &.{} },
    /// game.html, relative to the page
    game: []const u8 = "game.html",
    /// A looked-up player's Riot ID, percent-encoded; "" the example
    id: []const u8 = "",
    /// Minutes east of UTC; the server's: UTC
    tz_min: i32 = 0,
    /// Its own file, loaded when the view shows (dom.lazyLoad)
    js: []const u8 = "",
    wasm: []const u8 = "",

    const P = @This();

    pub const Url = struct {
        q: ?yl.Queue = null,
        role: ?Role = null,
        champ: url.Str(24) = .{},
        measure: Measure = .wc,
        by: By = .champ,
        sort: ?u8 = null,
        desc: bool = true,
    };

    pub const Msg = union(enum) { measure: Measure, by: By };

    pub fn toUrl(p: *const P) Url {
        const f = yp.urlOf(p.l, p.filter);
        var u: Url = .{ .q = f.q, .role = f.role, .champ = f.champ, .measure = p.m, .by = p.by };
        switch (p.by) {
            inline else => |b| {
                const t = p.tableOf(b);
                const d: @TypeOf(t.*) = .{ .rows = &.{} };
                if (t.sort != d.sort or t.desc != d.desc) {
                    u.sort = t.sort;
                    u.desc = t.desc;
                }
            },
        }
        return u;
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.filter = yp.filterOf(p.l, .{ .q = u.q, .role = u.role, .champ = u.champ });
        p.m = u.measure;
        p.by = u.by;
        p.champs = .{ .rows = &.{} };
        p.matchups = .{ .rows = &.{} };
        p.weeks = .{ .rows = &.{} };
        if (u.sort) |s| switch (p.by) {
            inline else => |b| p.tableOf(b).fromUrl(.{ .sort = s, .desc = u.desc }),
        };
    }

    fn tableOf(p: anytype, comptime b: By) switch (b) {
        .champ => @TypeOf(&p.champs),
        .matchup => @TypeOf(&p.matchups),
        .week => @TypeOf(&p.weeks),
    } {
        return switch (b) {
            .champ => &p.champs,
            .matchup => &p.matchups,
            .week => &p.weeks,
        };
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .measure => |x| p.m = x,
            .by => |x| p.by = x,
        }
        ev.push = true;
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{
            .class = "c-ytime",
            .data_island = "yourtime",
            .role = "tabpanel",
            .data_js = if (p.js.len > 0) p.js else null,
            .data_wasm = if (p.wasm.len > 0) p.wasm else null,
        }, .{p.body(h)});
    }

    fn body(p: *P, h: *H) N {
        var kept: std.ArrayList(yl.Game) = .empty;
        for (p.l.games) |g| if (p.filter.keeps(g)) kept.append(h.mem, g) catch {
            h.oom = true;
            return .none;
        };
        if (kept.items.len == 0) return h.p(.{ .class = "note" }, .{W.none});
        // A measure no game has falls to the first one some game has
        var has: [n_measures]bool = @splat(false);
        for (kept.items) |g| for (&has, 0..) |*x, i| {
            if (valueOf(@fromBackingInt(@intCast(i)), g) != null) x.* = true;
        };
        var m = p.m;
        if (!has[@backingInt(m)]) m = for (has, 0..) |x, i| {
            if (x) break @as(Measure, @fromBackingInt(@intCast(i)));
        } else m;
        const rows = rowsOf(h, p.l, kept.items, p.by, m, p.tz_min) catch {
            h.oom = true;
            return .none;
        };
        return h.div(.{ .class = "grid" }, .{
            card.view(h, .{ .flush = true }, &.{
                card.head(h, W.each, null, &.{p.measures(h, m, &has)}),
                h.div(.{ .class = "body" }, .{p.trend(h, kept.items, m, has[@backingInt(m)])}),
            }),
            patterns(h, kept.items),
            card.view(h, .{ .flush = true, .label = W.by }, &.{
                card.head(h, W.by, null, &.{p.groups(h)}),
                switch (p.by) {
                    inline else => |b| blk: {
                        const t = p.tableOf(b);
                        t.rows = rows;
                        break :blk t.view(h);
                    },
                },
            }),
        });
    }

    fn measures(p: *P, h: *H, m: Measure, has: *const [n_measures]bool) N {
        var items: [n_measures]segmented.Item = undefined;
        for (&items, has.*, 0..) |*it, x, i| {
            const v: Measure = @fromBackingInt(@intCast(i));
            it.* = .{ .label = labelOf(v), .selected = v == m, .disabled = !x, .on = h.on(p, .{ .measure = v }) };
        }
        return segmented.view(h, .{ .s = .s, .label = W.measure }, &items);
    }

    fn groups(p: *P, h: *H) N {
        var items: [3]segmented.Item = undefined;
        for (&items, [_]tree.Text{ W.champion, W.matchup, W.week }, 0..) |*it, label, i| {
            const b: By = @fromBackingInt(@intCast(i));
            it.* = .{ .label = label, .selected = p.by == b, .on = h.on(p, .{ .by = b }) };
        }
        return segmented.view(h, .{ .s = .s, .label = W.group }, &items);
    }

    /// `games` newest first
    fn trend(p: *P, h: *H, games: []const yl.Game, m: Measure, any: bool) N {
        if (!any) return h.p(.{ .class = "note" }, .{W.no_measure});
        var pts: std.ArrayList(gametrend.Point) = .empty;
        var lo: f32 = std.math.inf(f32);
        var hi: f32 = -std.math.inf(f32);
        var sum: f32 = 0;
        var last_week: ?i32 = null;
        var i = games.len;
        while (i > 0) {
            i -= 1;
            const g = games[i];
            const v = valueOf(m, g) orelse continue;
            lo = @min(lo, v);
            hi = @max(hi, v);
            sum += v;
            const day = yl.dayOf(g.start_ms, p.tz_min);
            const date = yp.dayText(h, day);
            const me = p.l.champs[g.champ].name;
            const who = if (g.opp) |o| W.vs.with(h, .{ .a = me, .b = p.l.champs[o].name }) else tree.Text{ .s = me };
            pts.append(h.mem, .{
                .v = v,
                .win = g.win,
                .patch = g.patch,
                .week = if (last_week != weekOf(day)) date else null,
                .href = yp.gameHref(h, p.game, p.id, g, 0),
                .label = W.dot.with(h, .{ .c = who.s, .v = text(h, m, v).s, .d = date.s }),
            }) catch {
                h.oom = true;
                return .none;
            };
            last_week = weekOf(day);
        }
        const mean = sum / @as(f32, @floatFromInt(pts.items.len));
        const s = scaleOf(m, lo, hi);
        const plane: chart.Plane = .{ .x = .{ .lo = 0, .hi = 1 }, .y = s };
        var ticks: [5]chart.Tick = undefined;
        var n: usize = 0;
        for ([_]f32{ 0, 0.25, 0.5, 0.75, 1 }) |f| {
            // A symmetric axis at quarters; the others at halves
            if (m == .kda or m == .cs) if (f == 0.25 or f == 0.75) continue;
            const v = s.lo + (s.hi - s.lo) * f;
            ticks[n] = .{ .at = plane.py(v), .label = text(h, m, v), .zero = (v == 0 and s.lo < 0) or (m == .wc and v == 50) };
            n += 1;
        }
        return gametrend.view(h, .{
            .label = labelOf(m),
            .points = pts.items,
            .y = s,
            .ticks = h.mem.dupe(chart.Tick, ticks[0..n]) catch &.{},
            .base = switch (m) {
                .wc => 50,
                .vt, .g14 => 0,
                .kda, .cs => mean,
            },
        });
    }
};

fn scaleOf(m: Measure, lo: f32, hi: f32) chart.Scale {
    return switch (m) {
        .wc => .{ .lo = 0, .hi = 100 },
        .vt, .g14 => blk: {
            const a = chart.niceCeil(@max(@max(@abs(lo), @abs(hi)), 500));
            break :blk .{ .lo = -a, .hi = a };
        },
        .kda, .cs => .{ .lo = 0, .hi = chart.niceCeil(@max(hi, 1)) },
    };
}

/// The Games view's card: the rolling mean of win at 15 as a spark and its last figure;
/// `on` opens Over time. `games` newest first
pub fn summary(h: *H, games: []const yl.Game, on: tree.Handler) N {
    var vs: std.ArrayList(f32) = .empty;
    var i = games.len;
    while (i > 0) {
        i -= 1;
        const v = valueOf(.wc, games[i]) orelse continue;
        vs.append(h.mem, v) catch {
            h.oom = true;
            return .none;
        };
    }
    if (vs.items.len < 2) return .none;
    const mean = gametrend.rolling(h, vs.items) orelse return .none;
    const last = mean[mean.len - 1];
    return h.div(.{ .class = "c-tcard" }, .{
        // Over the whole card (::after)
        h.button(.{ .type = "button", .class = "lab", .on_click = on }, .{W.time}),
        h.span(.{ .class = "val", .style = h.vars(.{ .c = fmt.Step.of(last - 50, fmt.game_cuts) }) }, .{text(h, .wc, last)}),
        h.span(.{ .class = "sub" }, .{W.recent}),
        spark.view(h, .{ .vs = mean, .mid = 50, .y = .{ .lo = 0, .hi = 100 }, .w = 160, .h = 36 }),
    });
}

/// Win rate by game length against the overall rate, each bucket with games
fn patterns(h: *H, games: []const yl.Game) N {
    var all: yl.Totals = .{};
    var by: [3]yl.Totals = @splat(.{});
    for (games) |g| {
        if (g.remake or g.dur < short_s) continue;
        all.add(g);
        by[if (g.dur < 25 * 60) 0 else if (g.dur <= 35 * 60) 1 else 2].add(g);
    }
    var buckets: usize = 0;
    for (by) |t| buckets += @intFromBool(t.games > 0);
    // One length is the whole record again
    if (all.games < 4 or buckets < 2) return .none;
    const rate = @as(f32, @floatFromInt(all.wins)) * 100 / @as(f32, @floatFromInt(all.games));
    var rows = h.list();
    for (by, [_]tree.Text{ W.under, W.mid, W.over }) |t, label| {
        if (t.games == 0) continue;
        const d = @as(f32, @floatFromInt(t.wins)) * 100 / @as(f32, @floatFromInt(t.games)) - rate;
        rows.add(h.span(.{ .class = "lab" }, .{ label, h.small(.{}, .{W.score.with(h, .{ .w = t.wins, .l = t.losses() })}) }));
        rows.add(delta.bar(h, .{ .d = d, .span = 50, .scale = .game }));
        rows.add(h.span(.{ .class = "d", .style = h.vars(.{ .c = fmt.Step.of(d, fmt.game_cuts) }) }, .{phrase.num(h, .signed, int(d))}));
    }
    return card.view(h, .{ .label = W.patterns }, &.{
        card.head(h, W.patterns, W.vs_rate.with(h, .{ .p = int(rate) }), &.{}),
        h.div(.{ .class = "pat" }, .{
            h.el(.h3, .{}, .{W.length}),
            h.div(.{ .class = "rows" }, .{rows.done()}),
        }),
    });
}

pub const css =
    \\@layer components {
    \\  .c-ytime > .grid { display: grid; grid-template-columns: minmax(0, 1fr) 300px; gap: var(--sp-3); align-items: start; }
    \\  /* The table, and the chart without Patterns */
    \\  .c-ytime > .grid > :last-child, .c-ytime > .grid > :first-child:nth-last-child(2) { grid-column: 1 / -1; }
    \\  .c-ytime .body { padding: var(--sp-3) var(--sp-4) var(--sp-2); }
    \\  .c-ytime .note { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  .c-ytime .pat { display: grid; gap: var(--sp-2); }
    \\  .c-ytime .pat h3 { margin: 0; font-size: var(--fs-xs); font-weight: var(--w-b); color: var(--muted); text-transform: uppercase; }
    \\  .c-ytime .pat .rows { display: grid; grid-template-columns: auto minmax(60px, 1fr) 3.5em; gap: var(--sp-2) var(--sp-3); align-items: center; }
    \\  .c-ytime .pat .lab { display: grid; font-size: var(--fs-s); }
    \\  .c-ytime .pat .lab small { color: var(--faint); font-size: var(--fs-xs); }
    \\  .c-ytime .pat .d { justify-self: end; color: var(--c); font-size: var(--fs-s); font-weight: var(--w-m); font-variant-numeric: tabular-nums; }
    \\  .c-ytime .who { display: inline-flex; align-items: center; gap: var(--sp-1); }
    \\  .c-ytime .who > span:not([class]) { margin-left: var(--sp-1); }
    \\  .c-ytime .wl { display: inline-flex; align-items: center; gap: var(--sp-2); }
    \\  .c-ytime .wl .bar { width: 48px; height: 4px; border-radius: 2px;
    \\    background: linear-gradient(90deg, var(--us) calc(var(--p) * 1%), var(--them) 0); }
    \\  .c-ytime .v { color: var(--c); }
    \\  /* A looked-up list before ui-yourtime runs: the example's content, kept for its size */
    \\  .c-ytime[aria-busy="true"] { border-radius: var(--r-l); background: var(--panel); }
    \\  .c-ytime[aria-busy="true"] > * { visibility: hidden; }
    \\  .c-ytime .na { color: var(--faint); }
    \\  .c-tcard { position: relative; display: grid; align-content: start; gap: 2px; min-width: 0;
    \\    padding: var(--sp-3) var(--sp-4); background: var(--panel); border: 1px solid var(--line); border-radius: var(--r-l); }
    \\  .c-tcard:hover { border-color: var(--line-2); }
    \\  .c-tcard:has(> .lab:focus-visible) { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  .c-tcard > .lab { all: unset; justify-self: start; cursor: pointer; font-size: var(--fs-s); color: var(--accent); }
    \\  .c-tcard > .lab::after { content: ""; position: absolute; inset: 0; border-radius: inherit; }
    \\  .c-tcard > .val { font-size: var(--fs-xl); font-weight: var(--w-b); line-height: 1.15; color: var(--c);
    \\    font-variant-numeric: tabular-nums; }
    \\  .c-tcard > .sub { font-size: var(--fs-xs); color: var(--faint); }
    \\  .c-tcard > .c-spark { margin-top: var(--sp-1); }
    \\  @media (max-width: 1000px) {
    \\    .c-ytime > .grid { grid-template-columns: minmax(0, 1fr); }
    \\  }
    \\}
    \\
;

const demo = struct {
    const champs = [_]champ.Champ{ .{ .name = "Aurelion Sol", .src = "" }, .{ .name = "Karthus", .src = "" }, .{ .name = "Ahri", .src = "" } };
    const wc = [_]u8{ 50, 52, 48, 46, 50, 55, 58, 54, 60, 64, 62, 66, 70, 68, 72, 75, 78 };
    const games = blk: {
        var gs = yp.demo.games;
        for (&gs, 0..) |*g, i| {
            g.opp = 2;
            g.dur = 1200 + 300 * (i % 5);
            g.patch = if (i < 6) "16.21" else "16.20";
            g.wc = &wc;
            g.lane14 = .{ .you = 400 - 150 * @as(i32, @intCast(i % 7)), .typ = .{ -500, 100, 600 } };
            g.cs = 180 + 10 * i;
        }
        break :blk gs;
    };
    const list: yl.List = .{ .player = yp.demo.list.player, .champs = &champs, .games = &games };
    var time: YourTime = .{ .l = &list };
    var gold: YourTime = .{ .l = &list, .m = .vt, .by = .matchup };
    var weeks: YourTime = .{ .l = &list, .m = .kda, .by = .week };
    var bare: YourTime = .{ .l = &yp.demo.list };
    var empty: YourTime = .{ .l = &list, .filter = .{ .queue = .draft } };
};

/// The gallery card's press, which goes nowhere
const Tap = struct {
    pub const Msg = union(enum) { open };
    pub fn update(_: *Tap, _: Msg, _: *tree.Event) void {}
};
var gallery_tap: Tap = .{};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.add("the Games view's card", summary(h, &demo.games, h.on(&gallery_tap, .open)));
    g.addFill("win at 15, by champion", demo.time.view(h));
    g.addFill("vs typical, by matchup", demo.gold.view(h));
    g.addFill("KDA, by week", demo.weeks.view(h));
    g.addFill("no timelines: KDA, one length so no Patterns", demo.bare.view(h));
    g.addFill("a filter without games", demo.empty.view(h));
}

const testing = std.testing;

test "measures, groups and the URL" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    var p: YourTime = .{ .l = &demo.list };
    var ev: tree.Event = .{ .kind = .click };

    var n = p.view(&h);
    // A dot per game (and the figure's label), two patches
    const chart_n = t.find(n, "class", "c-chart c-gtrend").?;
    try testing.expectEqual(11, t.count(chart_n, "aria-label"));
    try testing.expectEqual(6, t.count(chart_n, "data-win"));
    try testing.expect(t.find(n, "class", "pl") != null);
    try testing.expect(t.find(n, "class", "c-table") != null);
    try testing.expect(t.find(n, "class", "pat") != null);

    p.update(.{ .by = .week }, &ev);
    p.update(.{ .measure = .kda }, &ev);
    try testing.expect(ev.push);
    n = p.view(&h);
    var u = p.toUrl();
    try testing.expectEqual(.week, u.by);
    try testing.expectEqual(.kda, u.measure);
    try testing.expectEqual(null, u.sort);

    // Back to a URL: a sort, a filter
    u = .{ .by = .matchup, .sort = 4, .desc = false, .q = .flex };
    p.fromUrl(u);
    try testing.expectEqual(4, p.matchups.sort);
    try testing.expectEqual(.flex, p.filter.queue);
    try testing.expectEqual(@as(?u8, 4), p.toUrl().sort);
    n = p.view(&h);

    // No timelines: win at 15 can't be chosen, KDA shows
    var bare: YourTime = .{ .l = &yp.demo.list };
    n = bare.view(&h);
    try testing.expectEqualStrings("KDA", t.attr(t.find(n, "class", "c-chart c-gtrend").?, "aria-label").?);
    try testing.expect(!h.oom);
}

test "rows: a champion per role, matchups need an opponent, weeks from Monday" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const champs = try rowsOf(&h, &demo.list, &demo.games, .champ, .wc, 0);
    try testing.expectEqual(2, champs.len);
    var games: u32 = 0;
    for (champs) |r| games += r.t.games;
    try testing.expectEqual(10, games);
    try testing.expectEqual(5, champs[0].per.items.len);
    try testing.expectEqual(null, champs[0].opp);
    try testing.expectEqual(0, (try rowsOf(&h, &yp.demo.list, &yp.demo.games, .matchup, .wc, 0)).len);
    const weeks = try rowsOf(&h, &demo.list, &demo.games, .week, .wc, 0);
    for (weeks) |r| try testing.expectEqual(0, fmt.civil(r.day).weekday);
}
