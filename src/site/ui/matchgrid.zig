//! MatchupGrid: a champion's matchups in one role as a dot plot, against or with each
//! role (RelationPicker), placed by win rate, vs usual or gold at 14, and the chosen
//! opponent's brief under it. The champion page's matchups card; the matchup finder
//! shows it for the first champion picked. The owner's Msg carries `rel`, `ally`,
//! `rel_role` and `measure` and hands them to `update`
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const card = @import("card.zig");
const strip = @import("strip.zig");
const segmented = @import("segmented.zig");
const rolepicker = @import("rolepicker.zig");
const dotplot = @import("dotplot.zig");
const matchbrief = @import("matchbrief.zig");
const cp = @import("champpage.zig");
const H = tree.H;
const N = tree.N;

const W = cp.W;
const Rel = cp.Rel;
const Opp = cp.Opp;
const Counts = cp.Counts;
const Measure = cp.Measure;
const thin_games = fmt.thin_games;

pub const Msg = union(enum) { rel: u8, ally: bool, rel_role: role.Role, measure: Measure };

/// What the grid shows: the champion in one role
pub const Input = struct {
    name: []const u8,
    slug: []const u8,
    ddragon: []const u8,
    champs: []const cp.Other,
    /// "../" from the page to the site root
    root: []const u8,
    role: role.Role,
    counts: Counts,
    rels: []const Rel,
    /// A rank pick's lane opponents in place of rels' (null: Platinum+)
    ranked: ?Ranked = null,
    /// Beside the controls when it's not the lane: the cards that stay Platinum+
    plat: N = .none,
    few: N = .none,
    /// The plot faded: a rank pick with few games
    faded: bool = false,
};

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
        return !x.ally and x.role == in.role;
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
        }
        if (g.measure == .gold and !g.goldShown(in)) g.measure = .win;
        g.dots.sel = null;
    }

    /// `owner`'s Msg wraps Msg's tags with the same payloads
    pub fn view(g: *G, h: *H, owner: anytype, in: *const Input) N {
        if (in.rels.len == 0) return card.view(h, .{ .id = "matchups" }, &.{ card.head(h, W.matchups, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        const rel = in.rels[g.rel];
        const lane = !rel.ally and rel.role == in.role;
        var counts = in.counts;
        var opps = rel.opps;
        var rare = rel.rare;
        var few_games = false;
        if (lane) if (in.ranked) |x| switch (x) {
            .few => few_games = true,
            .lane => |y| {
                counts = y.counts;
                opps = y.opps;
                rare = y.rare;
                few_games = y.counts.games < cp.min_games;
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
                .thin = o.games < thin_games,
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
                .pressed = g.dots.chosen() == @as(u16, @intCast(i)),
                .on = h.on(&g.dots, .{ .pick = @intCast(i) }),
            };
            nc += 1;
        }

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
        return card.view(h, .{ .id = "matchups" }, &.{
            card.head(h, W.matchups, if (rare > 0) W.rare.with(h, .{ .n = count, .r = rare }) else phrase.num(h, .count, count), &.{ if (lane) .none else in.plat, controls[0], controls[1], controls[2] }),
            h.div(.{ .class = "c-mgrid" }, .{
                if (few_games) in.few else h.div(.{ .class = "plot", .data_thin = in.faded and counts.games < cp.solid_games }, .{g.dots.view(h)}),
                if (chosen) |o| (if (few_games) .none else h.div(.{ .class = "brief" }, .{matchbrief.view(h, brief(h, in, rel, counts, o), chips[0..nc])})) else .none,
            }),
        });
    }

    /// The figure a dot reads out with its name, in the measure's units
    fn figure(g: *const G, h: *H, o: Opp) tree.Text {
        return switch (g.measure) {
            .win => phrase.num(h, .rate, rate(.{ .games = o.games, .wins = o.wins })),
            .usual => phrase.num(h, .points, o.usual),
            .gold => phrase.num(h, .signed, @as(i32, o.gold orelse 0)),
        };
    }
};

fn brief(h: *H, in: *const Input, rel: Rel, rl: Counts, o: Opp) matchbrief.Brief {
    const own = rate(rl);
    const won = rate(.{ .games = o.games, .wins = o.wins });
    const usual_tip = h.fmt("cp-usual-{d}", .{o.champ});
    var items: [4]strip.Item = undefined;
    var n: usize = 0;
    items[n] = .{ .label = W.wins.with(h, .{ .c = in.name }), .value = phrase.num(h, .rate, won), .ctx = phrase.num(h, .points, won - own), .step = .of(won - own, fmt.win_cuts), .answer = true };
    n += 1;
    items[n] = .{ .label = W.m_usual, .value = phrase.num(h, .points, o.usual), .step = .of(o.usual, fmt.win_cuts), .tip = .{ .id = usual_tip, .note = W.usual_note.with(h, .{ .c = in.name }) } };
    n += 1;
    if (o.gold) |gd| {
        items[n] = .{ .label = W.m_gold, .value = phrase.num(h, .signed, @as(i32, gd)) };
        n += 1;
    }
    items[n] = .{ .label = W.games, .value = phrase.num(h, .count, o.games), .ctx = phrase.num(h, .pct, @as(u32, @intFromFloat(@round(100 * @as(f32, @floatFromInt(o.games)) / @as(f32, @floatFromInt(@max(rl.games, 1))))))) };
    n += 1;
    return .{
        .champ = icon(h, in, o.champ),
        .rel = if (rel.ally) W.ally.with(h, .{ .r = rel.role.label().s }) else W.opponent.with(h, .{ .r = rel.role.label().s }),
        .thin = o.games < thin_games,
        .figures = strip.view(h, items[0..n]),
        .href = matchHref(h, in, o),
    };
}

fn matchHref(h: *H, in: *const Input, o: Opp) ?[]const u8 {
    if (!o.page) return null;
    return h.fmt("{s}matchup/{s}/{s}-vs-{s}.html", .{ in.root, @tagName(in.role), in.slug, in.champs[o.champ].slug });
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
    \\  .c-mgrid { display: contents; }
    \\  .c-mgrid .plot { padding: var(--sp-3) 0; }
    \\  .c-mgrid .brief { container-type: inline-size; }
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
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const in: Input = .{
        .name = "Darius",
        .slug = "darius",
        .ddragon = champ.demo_version,
        .champs = &demo_champs,
        .root = "",
        .role = .top,
        .counts = .{ .games = 20412, .wins = 10063 },
        .rels = &demo_rels,
    };
    const states = [_]struct { []const u8, u8, Measure, ?u16 }{
        .{ "lane opponents by win rate", 0, .win, null },
        .{ "one chosen: its brief under the plot", 0, .win, 3 },
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
