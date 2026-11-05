//! MatchupGrid: a champion's matchups in one role as a dot plot, against or with each
//! role (RelationPicker), placed by win rate, vs usual or gold at 14; under it the ends as
//! two rows of tiles, the hardest and the easiest among the sure ones, so the card reads
//! without a click (the plot hides in a narrow card); the picked opponent's brief last.
//! Every figure is the champion's ("Ornn wins"). The champion page's matchups card; the
//! matchup finder shows it for the first champion picked. The owner's Msg carries `rel`,
//! `ally`, `rel_role` and `measure` and hands them to `update`
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const winrate = @import("rate.zig");
const phrase = @import("phrase.zig");
const Phrase = phrase.Phrase;
const champ = @import("champ.zig");
const role = @import("role.zig");
const card = @import("card.zig");
const strip = @import("strip.zig");
const segmented = @import("segmented.zig");
const rolepicker = @import("rolepicker.zig");
const dotplot = @import("dotplot.zig");
const matchbrief = @import("matchbrief.zig");
const champlist = @import("champlist.zig");
const cp = @import("champpage.zig");
const H = tree.H;
const N = tree.N;

const W = cp.W;
const Rel = cp.Rel;
const Opp = cp.Opp;
const Counts = cp.Counts;
const Measure = cp.Measure;

/// `lock`: the owner's, Input.champs' index as the lane opponent lock
pub const Msg = union(enum) { rel: u8, ally: bool, rel_role: role.Role, measure: Measure, lock: u16 };

const L = struct {
    /// Under the With plot: the page's lane cards don't follow the partner (walk 1 Nov S2)
    pub const alone = Phrase("The cards below are {c:text}'s alone, not with {p:text}.");
    pub const alone_any = Phrase("The cards below are {c:text}'s alone, not with a partner.");
    /// Gold at 14 names the side ahead: a signed lead read the wrong way round (walk S1)
    pub const gold_ahead = Phrase("{c:text} ahead");
    pub const level = phrase.plain("level");
    /// A dot's readout, its champion the subject: "Caitlyn 380 ahead"
    pub const dot_ahead = Phrase("{g:count} ahead");
    pub const dot_behind = Phrase("{g:count} behind");
    pub const harder = Phrase("Harder for {c:text}");
    pub const easier = Phrase("Easier for {c:text}");
    pub const tile_win = Phrase("{o:text}: {c:text} wins {v:text} in {n:count} games");
    pub const tile_usual = Phrase("{o:text}: {c:text} {v:text} vs usual in {n:count} games");
    pub const tile_gold = Phrase("{o:text}: {c:text} {v:text} at 14 in {n:count} games");
};

/// Tiles per row
const tiles_max = 6;

/// What the grid shows: the champion in one role
pub const Input = struct {
    name: []const u8,
    slug: []const u8,
    ddragon: []const u8,
    champs: []const cp.Other,
    /// The view's query its matchup links keep ("" for the default)
    query: []const u8 = "",
    role: role.Role,
    counts: Counts,
    rels: []const Rel,
    /// A rank pick's lane opponents in place of rels' (null: Platinum+)
    ranked: ?Ranked = null,
    /// Beside the controls when it's not the lane: the cards that stay Platinum+
    plat: N = .none,
    /// A rank pick without the role (Ranked.few)
    few: N = .none,
    /// The champion page's: a lane opponent's brief locks it (Msg.lock)
    lock: ?Lock = null,
};

/// Input.champs' index of the opponent locked
pub const Lock = struct { on: ?u16 = null };

pub const Ranked = union(enum) { few, lane: struct { counts: Counts, opps: []const Opp, rare: u16 } };

pub const MatchupGrid = struct {
    /// Input.rels' index
    rel: u8 = 0,
    measure: Measure = .win,
    dots: dotplot.DotPlot = .{ .dots = &.{}, .m = .{ .label = W.matchups } },

    const G = @This();

    pub fn relOf(_: *const G, in: *const Input, ally: bool, r2: role.Role) ?u8 {
        for (in.rels, 0..) |x, i| if (x.ally == ally and x.role == r2) return @intCast(i);
        return null;
    }

    /// Gold at 14 is the lane curves': lane opponents only
    pub fn goldShown(g: *const G, in: *const Input) bool {
        if (in.rels.len == 0) return false;
        const x = in.rels[g.rel];
        if (x.ally or x.role != in.role) return false;
        // None under locks: the curves aren't locked
        for (x.opps) |o| if (o.gold != null) return true;
        return false;
    }

    /// The URL's choice: with or against, the other role, the measure
    pub fn set(g: *G, in: *const Input, with: bool, vs: ?role.Role, by: Measure) void {
        g.rel = g.relOf(in, with, vs orelse if (with) partner(in.role) else in.role) orelse 0;
        g.measure = if (by == .gold and !g.goldShown(in)) .win else by;
        g.dots.sel = null;
    }

    pub fn update(g: *G, in: *const Input, m: Msg) void {
        switch (m) {
            .rel => |i| g.rel = i,
            .ally => |a| {
                if (in.rels.len == 0) return;
                const cur = in.rels[g.rel].role;
                // Nobody is with the champion in its own role: the usual partner then
                const r2 = if (a and cur == in.role) partner(in.role) else cur;
                g.rel = g.relOf(in, a, r2) orelse for (in.rels, 0..) |x, i| {
                    if (x.ally == a) break @intCast(i);
                } else g.rel;
            },
            .rel_role => |r2| {
                const ally = if (in.rels.len > 0) in.rels[g.rel].ally else false;
                g.rel = g.relOf(in, ally, r2) orelse g.rel;
            },
            .measure => |x| g.measure = x,
            .lock => return,
        }
        if (g.measure == .gold and !g.goldShown(in)) g.measure = .win;
        g.dots.sel = null;
    }

    /// `owner`'s Msg wraps Msg's tags with the same payloads
    pub fn view(g: *G, h: *H, owner: anytype, in: *const Input) N {
        if (in.rels.len == 0) return card.view(h, .{ .id = "matchups", .target = true, .label = W.matchups }, &.{ card.head(h, W.matchups, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        const rel = in.rels[g.rel];
        const lane = !rel.ally and rel.role == in.role;
        var counts = in.counts;
        var opps = rel.opps;
        var rare = rel.rare;
        var none = false;
        if (lane) if (in.ranked) |x| switch (x) {
            .few => none = true,
            .lane => |y| {
                counts = y.counts;
                opps = y.opps;
                rare = y.rare;
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
            const x: f32 = switch (g.measure) {
                .win => rate(.{ .games = o.games, .wins = o.wins }) - own,
                .usual => o.usual,
                .gold => @floatFromInt(o.gold orelse continue),
            };
            dots[n] = .{
                .champ = icon(h, in, o.champ),
                .x = x,
                .games = o.games,
                .fig = g.figure(h, o),
                .thin = wide(o),
                .href = matchHref(h, in, o),
            };
            of[n] = @intCast(k);
            n += 1;
        }
        g.dots.dots = dots[0..n];
        g.dots.m = switch (g.measure) {
            .win => .{ .label = W.matchups },
            .usual => .{ .label = W.matchups, .bin = 0.5, .reach = 1 },
            .gold => .{ .label = W.matchups, .bin = 100, .reach = 200 },
        };
        const chosen: ?Opp = if (g.dots.chosen()) |i| opps[of[i]] else null;
        const buf = h.mem.alloc(u16, n) catch {
            h.oom = true;
            return .none;
        };
        const e = ends(buf, dots[0..n]);

        var rels: [role.Role.all.len]rolepicker.Item = undefined;
        for (role.Role.all, &rels) |x, *it| {
            const i = g.relOf(in, rel.ally, x);
            it.* = .{ .role = x, .current = x == rel.role, .disabled = i == null, .on = if (i) |k| h.on(owner, .{ .rel = k }) else null };
        }
        const controls = [_]N{
            segmented.view(h, .{ .label = W.rel_label }, &.{
                .{ .label = W.against, .selected = !rel.ally, .on = h.on(owner, .{ .ally = false }) },
                .{ .label = W.with, .selected = rel.ally, .on = h.on(owner, .{ .ally = true }) },
            }),
            rolepicker.view(h, .{ .v = .compact, .label = W.rel_label }, &rels),
            segmented.view(h, .{ .label = W.measure_label }, &.{
                .{ .label = W.m_win, .selected = g.measure == .win, .on = h.on(owner, .{ .measure = .win }) },
                .{ .label = W.m_usual, .selected = g.measure == .usual, .on = h.on(owner, .{ .measure = .usual }) },
                .{ .label = W.m_gold, .selected = g.measure == .gold, .disabled = !g.goldShown(in), .on = h.on(owner, .{ .measure = .gold }) },
            }),
        };
        const count: u32 = @intCast(opps.len);
        return card.view(h, .{ .id = "matchups", .target = true, .label = W.matchups }, &.{
            card.head(h, W.matchups, if (rare > 0) W.rare.with(h, .{ .n = count, .r = rare }) else phrase.num(h, .count, count), &.{ if (lane) .none else in.plat, controls[0], controls[1], controls[2] }),
            h.div(.{ .class = "c-mgrid" }, .{
                if (none) in.few else h.div(.{ .class = "plot" }, .{g.dots.view(h)}),
                if (none or e.lo.len == 0) .none else h.div(.{ .class = "ends" }, .{
                    g.tiles(h, in, L.harder.with(h, .{ .c = in.name }), e.lo, opps, of),
                    g.tiles(h, in, L.easier.with(h, .{ .c = in.name }), e.hi, opps, of),
                }),
                if (rel.ally) h.p(.{ .class = "alone" }, .{if (chosen) |o| L.alone.with(h, .{ .c = in.name, .p = in.champs[o.champ].name }) else L.alone_any.with(h, .{ .c = in.name })}) else .none,
                if (chosen) |o| (if (none) .none else h.div(.{ .class = "brief" }, .{matchbrief.view(h, b: {
                    var x = brief(h, in, rel, counts, o);
                    if (in.lock) |l| if (lane) {
                        x.lock = .{ .on = h.on(owner, .{ .lock = o.champ }), .locked = l.on == o.champ };
                    };
                    if (rel.ally and rel.role == partner(in.role) and (in.role == .bot or in.role == .support))
                        if (g.relOf(in, false, in.role)) |k| {
                            x.lanes = h.on(owner, .{ .rel = k });
                        };
                    break :b x;
                })})) else .none,
            }),
        });
    }

    /// A row of ends: `ks` the dots' indexes, `of` theirs into `opps`. A tap picks, as a
    /// dot does
    fn tiles(g: *G, h: *H, in: *const Input, head: tree.Text, ks: []const u16, opps: []const Opp, of: []const u16) N {
        if (ks.len == 0) return .none;
        const rows = h.mem.alloc(champlist.Row, ks.len) catch {
            h.oom = true;
            return .none;
        };
        for (ks, rows) |k, *row| {
            const o = opps[of[k]];
            const d = g.dots.dots[k];
            const r: winrate.Rate = .counted(o.games, o.wins);
            const v = g.tileFigure(h, o);
            row.* = .{
                .champ = d.champ,
                .value = switch (g.measure) {
                    .win => winrate.view(h, r, .{ .count = false, .said = "" }),
                    .usual => winrate.delta(h, o.usual, r.half),
                    .gold => h.span(.{}, .{v}),
                },
                // The count alone: a button's shown text stays 2 words (check), its label says games
                .note = phrase.num(h, .count, o.games),
                .label = switch (g.measure) {
                    .win => L.tile_win.with(h, .{ .o = d.champ.name, .c = in.name, .v = v.s, .n = o.games }),
                    .usual => L.tile_usual.with(h, .{ .o = d.champ.name, .c = in.name, .v = v.s, .n = o.games }),
                    .gold => L.tile_gold.with(h, .{ .o = d.champ.name, .c = in.name, .v = v.s, .n = o.games }),
                },
                .pressed = g.dots.chosen() == k,
                .on = h.on(&g.dots, .{ .pick = k }),
            };
        }
        return h.div(.{ .class = "end" }, .{ h.h3(.{}, .{head}), champlist.view(h, .{ .tiles = true }, rows) });
    }

    /// A tile's figure, the champion its subject as everywhere on the page: gold "380
    /// behind" is the champion's (a dot's readout is its own champion's)
    fn tileFigure(g: *const G, h: *H, o: Opp) tree.Text {
        return switch (g.measure) {
            .win => winrate.shown(h, .counted(o.games, o.wins)),
            .usual => phrase.num(h, .points, o.usual),
            .gold => {
                const gd: i32 = o.gold orelse 0;
                if (gd == 0) return L.level;
                if (gd > 0) return L.dot_ahead.with(h, .{ .g = @abs(gd) });
                return L.dot_behind.with(h, .{ .g = @abs(gd) });
            },
        };
    }

    /// The figure a dot reads out with its name, in the measure's units
    fn figure(g: *const G, h: *H, o: Opp) tree.Text {
        return switch (g.measure) {
            .win => phrase.num(h, .rate, rate(.{ .games = o.games, .wins = o.wins })),
            .usual => phrase.num(h, .points, o.usual),
            .gold => {
                // x minus the dot's champion: the dot's champion is ahead when negative
                const gd: i32 = o.gold orelse 0;
                if (gd == 0) return L.level;
                if (gd < 0) return L.dot_ahead.with(h, .{ .g = @abs(gd) });
                return L.dot_behind.with(h, .{ .g = @abs(gd) });
            },
        };
    }
};

const Ends = struct { lo: []const u16, hi: []const u16 };

/// The tile rows' dots, `buf` one slot per dot: the lowest and the highest by the measure
/// among the sure ones, hardest and easiest first; fewer than two rows' worth split, the
/// harder half the larger. None sure: no rows, the plot stays in a narrow card too
fn ends(buf: []u16, dots: []const dotplot.Dot) Ends {
    var n: usize = 0;
    for (dots, 0..) |d, i| if (!d.thin) {
        buf[n] = @intCast(i);
        n += 1;
    };
    const s = buf[0..n];
    const Ctx = struct {
        fn less(ds: []const dotplot.Dot, a: u16, b: u16) bool {
            if (ds[a].x != ds[b].x) return ds[a].x < ds[b].x;
            return ds[a].games > ds[b].games;
        }
    };
    // Insertion, as DotPlot's order: std.mem.sort's block sort costs ~9 KB of wasm
    std.sort.insertion(u16, s, dots, Ctx.less);
    const lo = @min(tiles_max, (n + 1) / 2);
    const hi = @min(tiles_max, n - lo);
    std.mem.reverse(u16, s[n - hi ..]);
    return .{ .lo = s[0..lo], .hi = s[n - hi ..] };
}

/// A matchup's win rate range past fmt.wide_range: its dot, tile and brief fade (J35)
fn wide(o: Opp) bool {
    return fmt.wide(fmt.range(o.games, o.wins));
}

fn brief(h: *H, in: *const Input, rel: Rel, rl: Counts, o: Opp) matchbrief.Brief {
    const usual_tip = h.fmt("cp-usual-{d}", .{o.champ});
    var items: [4]strip.Item = undefined;
    var n: usize = 0;
    items[n] = .{ .label = W.wins.with(h, .{ .c = in.name }), .rate = winrate.view(h, .counted(o.games, o.wins), .{ .said = "" }), .answer = true };
    n += 1;
    items[n] = .{ .label = W.m_usual, .rate = winrate.delta(h, o.usual, fmt.range(o.games, o.wins)), .ctx = cp.usualSide(o.usual, W.below_usual, W.above_usual), .tip = .{ .id = usual_tip, .note = W.usual_note.with(h, .{ .c = in.name }) } };
    n += 1;
    if (o.gold) |gd| {
        items[n] = goldItem(h, in, o.champ, gd);
        n += 1;
    }
    items[n] = .{ .label = W.lock_share, .value = phrase.num(h, .pct, @as(u32, @intFromFloat(@round(100 * @as(f32, @floatFromInt(o.games)) / @as(f32, @floatFromInt(@max(rl.games, 1))))))) };
    n += 1;
    return .{
        .champ = icon(h, in, o.champ),
        .rel = if (rel.ally) W.ally.with(h, .{ .r = rel.role.label().s }) else W.opponent.with(h, .{ .r = rel.role.label().s }),
        .thin = wide(o),
        .figures = strip.view(h, items[0..n]),
        .href = matchHref(h, in, o),
    };
}

fn goldItem(h: *H, in: *const Input, other: u16, gd: i16) strip.Item {
    return .{
        .label = W.m_gold,
        .value = phrase.num(h, .count, @abs(@as(i32, gd))),
        .ctx = if (gd == 0) L.level else L.gold_ahead.with(h, .{ .c = if (gd > 0) in.name else in.champs[other].name }),
    };
}

fn matchHref(h: *H, in: *const Input, o: Opp) ?[]const u8 {
    if (!o.page) return null;
    return h.fmt("/matchups/{s}/{s}-vs-{s}{s}", .{ @tagName(in.role), in.slug, in.champs[o.champ].slug, in.query });
}

fn icon(h: *H, in: *const Input, i: u16) champ.Champ {
    const c = in.champs[i];
    return .{ .name = c.name, .src = h.fmt(champ.icon_fmt, .{ in.ddragon, c.key }) };
}

fn rate(c: Counts) f32 {
    return 100 * @as(f32, @floatFromInt(c.wins)) / @as(f32, @floatFromInt(@max(c.games, 1)));
}

pub fn partner(r: role.Role) role.Role {
    return switch (r) {
        .top, .mid => .jungle,
        .jungle => .mid,
        .bot => .support,
        .support => .bot,
    };
}

pub const name = "MatchupGrid";
pub const scope = .{".c-mgrid"};

pub const css =
    \\@layer components {
    \\  .c-mgrid { container-type: inline-size; }
    \\  .c-mgrid .plot { padding: var(--sp-3) 0; }
    \\  .c-mgrid .ends { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 480px), 1fr));
    \\    gap: var(--sp-3) var(--sp-5); margin-bottom: var(--sp-4); }
    \\  .c-mgrid .end > h3 { margin: 0 0 var(--sp-2); font-size: var(--fs-s); font-weight: var(--w-b); color: var(--t2); }
    \\  @container (max-width: 559px) { .c-mgrid:has(.ends) .plot { display: none; } }
    \\  .c-mgrid .brief { container-type: inline-size; }
    \\  .c-mgrid .alone { margin: 0 0 var(--sp-3); font-size: var(--fs-s); color: var(--muted); }
    \\}
    \\
;

const Gallery = @import("gallery.zig").Gallery;

pub const demo_champs = [_]cp.Other{
    .{ .name = "Garen", .key = "Garen", .slug = "garen" },                   .{ .name = "Sett", .key = "Sett", .slug = "sett" },
    .{ .name = "Mordekaiser", .key = "Mordekaiser", .slug = "mordekaiser" }, .{ .name = "Yone", .key = "Yone", .slug = "yone" },
    .{ .name = "Dr. Mundo", .key = "DrMundo", .slug = "drmundo" },           .{ .name = "Volibear", .key = "Volibear", .slug = "volibear" },
    .{ .name = "Teemo", .key = "Teemo", .slug = "teemo" },                   .{ .name = "Malphite", .key = "Malphite", .slug = "malphite" },
    .{ .name = "Jax", .key = "Jax", .slug = "jax" },                         .{ .name = "Aatrox", .key = "Aatrox", .slug = "aatrox" },
    .{ .name = "Fiora", .key = "Fiora", .slug = "fiora" },                   .{ .name = "K'Sante", .key = "KSante", .slug = "ksante" },
    .{ .name = "Lee Sin", .key = "LeeSin", .slug = "leesin" },               .{ .name = "Viego", .key = "Viego", .slug = "viego" },
    .{ .name = "Graves", .key = "Graves", .slug = "graves" },
};

fn demoOpp(comptime i: u16, comptime games: u32, comptime won: f32, comptime usual: f32, comptime gold: ?i16) Opp {
    return .{ .champ = i, .games = games, .wins = @intFromFloat(@round(won * games / 100)), .usual = usual, .gold = gold, .page = true };
}

const demo_lane = [_]Opp{
    demoOpp(0, 1788, 49.9, 0.4, 35),   demoOpp(1, 1621, 47.4, -1.2, -60), demoOpp(2, 1077, 50.2, 0.6, 20),
    demoOpp(3, 1259, 51.8, 1.4, 110),  demoOpp(4, 859, 43.2, -4.8, -150), demoOpp(5, 939, 45.9, -2.9, -40),
    demoOpp(6, 930, 47.1, -1.6, -210), demoOpp(7, 932, 48.0, -0.9, -15),  demoOpp(8, 922, 48.0, -1.1, 5),
    demoOpp(9, 747, 49.9, 0.3, 70),    demoOpp(10, 798, 53.3, 3.2, 180),  demoOpp(11, 353, 60.3, 9.1, 240),
};
const demo_with = [_]Opp{ demoOpp(12, 2104, 50.8, 0.6, null), demoOpp(13, 1530, 48.9, -0.7, null), demoOpp(14, 1122, 51.6, 1.1, null) };
pub const demo_rels = [_]Rel{ .{ .ally = false, .role = .top, .opps = &demo_lane, .rare = 31 }, .{ .ally = true, .role = .jungle, .opps = &demo_with } };

const GridMsg = Msg;

/// A gallery owner: the champion page's Msg plumbing, cut to the grid
const Demo = struct {
    grid: MatchupGrid = .{},
    in: Input,

    pub const Msg = GridMsg;

    pub fn update(d: *Demo, m: GridMsg, _: *tree.Event) void {
        d.grid.update(&d.in, m);
    }

    pub fn view(d: *Demo, h: *H) N {
        return d.grid.view(h, d, &d.in);
    }
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const in: Input = .{
        .name = "Darius",
        .slug = "darius",
        .ddragon = champ.demo_version,
        .champs = &demo_champs,
        .role = .top,
        .counts = .{ .games = 20412, .wins = 10063 },
        .rels = &demo_rels,
    };
    const states = [_]struct { []const u8, u8, Measure, ?u16 }{
        .{ "lane opponents by win rate", 0, .win, null },
        .{ "one chosen: its brief under the tiles", 0, .win, 3 },
        .{ "by gold at 14", 0, .gold, null },
        .{ "with the jungler", 1, .win, null },
    };
    for (states) |s| {
        const d = h.mem.create(Demo) catch {
            h.oom = true;
            return;
        };
        d.* = .{ .in = in, .grid = .{ .rel = s[1], .measure = s[2] } };
        d.grid.dots.sel = s[3];
        g.addFill(s[0], d.grid.view(h, d, &d.in));
    }
}

test "gold at 14 names the side ahead, never a signed lead" {
    const testing = std.testing;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const in: Input = .{ .name = "Darius", .slug = "darius", .ddragon = champ.demo_version, .champs = &demo_champs, .role = .top, .counts = .{ .games = 1000, .wins = 500 }, .rels = &demo_rels };
    const g: MatchupGrid = .{ .measure = .gold };
    // Darius minus Fiora -384: Fiora ahead
    const o = demoOpp(10, 400, 48, -1, -384);
    try testing.expectEqualStrings("384 ahead", g.figure(&h, o).s);
    try testing.expectEqualStrings("level", g.figure(&h, demoOpp(10, 400, 48, -1, 0)).s);
    try testing.expectEqualStrings("120 behind", g.figure(&h, demoOpp(10, 400, 48, -1, 120)).s);
    const it = goldItem(&h, &in, o.champ, -384);
    try testing.expectEqualStrings("384", it.value.s);
    try testing.expectEqualStrings("Fiora ahead", it.ctx.?.s);
    try testing.expectEqualStrings("Darius ahead", goldItem(&h, &in, o.champ, 90).ctx.?.s);
}

fn testDot(x: f32, thin: bool) dotplot.Dot {
    return .{ .champ = .{ .name = "", .src = "" }, .x = x, .games = 100, .fig = phrase.plain(""), .thin = thin };
}

test "the tile rows: the sure ends, hardest and easiest first; few split, the harder half larger; none sure, none" {
    const testing = std.testing;
    var buf: [16]u16 = undefined;
    var ds: [14]dotplot.Dot = undefined;
    for (&ds, 0..) |*d, i| d.* = testDot(@as(f32, @floatFromInt(i)) - 7, false);
    // The hardest and the easiest are wide: the next ones stand in
    ds[0].thin = true;
    ds[13].thin = true;
    const e = ends(&buf, &ds);
    try testing.expectEqualSlices(u16, &.{ 1, 2, 3, 4, 5, 6 }, e.lo);
    try testing.expectEqualSlices(u16, &.{ 12, 11, 10, 9, 8, 7 }, e.hi);
    // 5 sure: 3 harder, 2 easier, by x whatever the order given
    const few = [_]dotplot.Dot{ testDot(2, false), testDot(-1, false), testDot(9, true), testDot(0.5, false), testDot(-3, false), testDot(1, false) };
    const f = ends(&buf, &few);
    try testing.expectEqualSlices(u16, &.{ 4, 1, 3 }, f.lo);
    try testing.expectEqualSlices(u16, &.{ 0, 5 }, f.hi);
    // None sure: no rows
    const thin = [_]dotplot.Dot{ testDot(1, true), testDot(-1, true) };
    try testing.expectEqual(@as(usize, 0), ends(&buf, &thin).lo.len);
    try testing.expectEqual(@as(usize, 0), ends(&buf, &.{}).lo.len);
}

test "on the fake DOM: tiles name the champion's figure, a tap picks one and opens its brief" {
    const testing = std.testing;
    const island = @import("island.zig");
    const Fake = @import("fakedom.zig").Fake;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var fake: Fake = .{ .a = a };
    var rt: island.Runtime(Fake) = .init(a, &fake);
    var server: Demo = .{ .in = .{ .name = "Darius", .slug = "darius", .ddragon = champ.demo_version, .champs = &demo_champs, .role = .top, .counts = .{ .games = 20412, .wins = 10063 }, .rels = &demo_rels } };
    var state = server;
    const t = try a.create(tree.Tree);
    t.* = .{};
    var h: H = .init(a, t);
    t.root = server.view(&h);
    fake.server = t;
    const i = try rt.add(Demo, &state, &server, "#matchups");
    const cur = i.current();
    // No brief until a pick
    try testing.expect(cur.find(cur.root, "class", "c-mpick") == null);
    // Dr. Mundo is the hardest: the first tile of the first row
    const mundo = cur.find(cur.root, "aria-label", "Dr. Mundo: Darius wins 43.2% in 859 games").?;
    try testing.expect(cur.find(cur.root, "aria-label", "K'Sante: Darius wins 60.3% in 353 games") != null);
    _ = rt.event(0, .{ .kind = .click, .target = cur.node(mundo).dom });
    try testing.expectEqual(@as(?u16, 4), state.grid.dots.sel);
    const now = i.current();
    try testing.expect(now.find(now.root, "class", "c-mpick") != null);
    try testing.expectEqualStrings("true", now.attr(now.find(now.root, "aria-label", "Dr. Mundo: Darius wins 43.2% in 859 games").?, "aria-pressed").?);
    try testing.expectEqual(@as(u32, 0), fake.warnings);
}
