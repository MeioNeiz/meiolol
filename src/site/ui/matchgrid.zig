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
const pd = @import("pvdata.zig");
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
    /// `x`: in_games, worth_games for Meio's rate, empty for Meio's gold (no count)
    pub const tile_win = Phrase("{o:text}: {c:text} wins {v:text}{x:text}");
    pub const tile_usual = Phrase("{o:text}: {c:text} {v:text} vs usual{x:text}");
    /// The gold tile is the face's, as its dot: a direction word reads as the name above it
    pub const tile_gold_ahead = Phrase("{o:text}: {g:count} gold ahead of {c:text} at 14{x:text}");
    pub const tile_gold_behind = Phrase("{o:text}: {g:count} gold behind {c:text} at 14{x:text}");
    pub const tile_gold_level = Phrase("{o:text}: level with {c:text} at 14{x:text}");
    pub const in_games = Phrase(" in {n:count} games");
    pub const worth_games = Phrase(", worth {n:count} games");
    pub const ahead = phrase.plain("ahead");
    pub const all = Phrase("All {n:count} matchups ›");
    pub const behind = phrase.plain("behind");
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
    /// A link under the tile rows to the finder with the champion picked: on a phone the
    /// plot hides, so the middle and rare opponents are picked there
    finder: bool = false,
    /// The champion page's Meio period: the lane's win rates and gold at 14
    meio: ?Meio = null,
};

/// Meio's answer under the page's locks (pd.Meio): the stack's rate and each lane
/// opponent's. The lane's dots, tiles and brief show them; an opponent without one, and
/// vs usual, stay the games'. pvdata.Meio's head (data.decodeHead)
pub const Meio = struct { stack: ?pd.Est, opponents: []const pd.Choice };

fn meioOf(in: *const Input, o: Opp) ?*const pd.Choice {
    const m = in.meio orelse return null;
    const id = in.champs[o.champ].id;
    for (m.opponents) |*c| if (c.id == id) return c;
    return null;
}

/// The rate the champion wins against `o` at: Meio's (`meio`, its games are its worth) or
/// the games'
const Win = struct { rate: winrate.Rate, meio: bool = false };

fn winOf(in: *const Input, o: Opp) Win {
    if (meioOf(in, o)) |c| if (c.meio) |e| return .{ .rate = .{ .pct = 100 * e.p, .games = e.worth(), .half = 100 * (e.hi - e.lo) / 2 }, .meio = true };
    return .{ .rate = .counted(o.games, o.wins) };
}

/// Lane gold at 14, the champion minus `o`: Meio's or the curves'
fn goldOf(in: *const Input, o: Opp) ?i16 {
    if (meioOf(in, o)) |c| if (c.gold) |e| return @intFromFloat(@round(std.math.clamp(e.p, -9999, 9999)));
    return o.gold;
}

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
        for (x.opps) |o| if (goldOf(in, o) != null) return true;
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
    pub fn view(g: *G, h: *H, owner: anytype, page: *const Input) N {
        if (page.rels.len == 0) return card.view(h, .{ .id = "matchups", .target = true, .label = W.matchups }, &.{ card.head(h, W.matchups, null, &.{}), h.p(.{ .class = "none" }, .{W.none}) });
        const rel = page.rels[g.rel];
        const lane = !rel.ally and rel.role == page.role;
        // Meio's opponents are the lane's
        var lin = page.*;
        if (!lane) lin.meio = null;
        const in = &lin;
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
        const own = if (in.meio) |m| (if (m.stack) |e| 100 * e.p else rate(counts)) else rate(counts);
        const raw_own = rate(counts);
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
            const wo = winOf(in, o);
            const est = wo.meio;
            const w = wo.rate;
            // Each dot against the own rate of its kind: an estimate against Meio's stack
            // rate, an opponent left to the games against the games' own rate
            const x: f32 = switch (g.measure) {
                .win => @floatCast(w.pct - (if (est) own else raw_own)),
                .usual => o.usual,
                .gold => @floatFromInt(goldOf(in, o) orelse continue),
            };
            dots[n] = .{
                .champ = icon(h, in, o.champ),
                .x = x,
                .games = if (est and g.measure == .win) w.games.? else o.games,
                .worth = est and g.measure == .win,
                .fig = g.figure(h, in, o),
                .thin = faded(in, o),
                .href = matchHref(h, in, o),
            };
            of[n] = @intCast(k);
            n += 1;
        }
        g.dots.dots = dots[0..n];
        // The locked lane opponent is chosen until another is: its brief holds Unlock
        if (lane and g.dots.sel == null) if (in.lock) |l| if (l.on) |c| {
            for (of[0..n], 0..) |k, i| if (opps[k].champ == c) {
                g.dots.sel = @intCast(i);
                break;
            };
        };
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
                if (in.finder and lane and !none and e.lo.len > 0) h.a(.{
                    .class = "all",
                    .href = h.fmt(finder_href, .{ @tagName(in.role), in.slug }),
                }, .{L.all.with(h, .{ .n = count + rare })}) else .none,
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
            const wo = winOf(in, o);
            const r = wo.rate;
            const est = wo.meio;
            const v = g.tileFigure(h, in, o);
            // The dot's champion minus the page's: the face's own lead
            const gd = -(goldOf(in, o) orelse 0);
            const meio_gold = g.measure == .gold and est;
            // Meio's gold has no count to give: its worth is the win rate's
            const x = if (meio_gold) "" else if (est and g.measure == .win) L.worth_games.with(h, .{ .n = r.games.? }).s else L.in_games.with(h, .{ .n = o.games }).s;
            row.* = .{
                .champ = d.champ,
                .value = switch (g.measure) {
                    .win => winrate.view(h, r, .{ .count = false, .said = "", .worth = est }),
                    .usual => winrate.delta(h, o.usual, r.half),
                    // The number at the tile's size, its word small under it: "210 behind"
                    // whole overruns a 3x2 tile at 320
                    .gold => if (gd == 0) h.span(.{}, .{L.level}) else h.span(.{}, .{
                        phrase.num(h, .count, @abs(gd)),
                        h.span(.{ .class = "w" }, .{if (gd > 0) L.ahead else L.behind}),
                    }),
                },
                // The count alone: its label says games. An estimate's worth as "~13k"
                .note = if (meio_gold) null else if (est and g.measure == .win) winrate.about(h, r.games.?) else phrase.num(h, .count, o.games),
                .label = switch (g.measure) {
                    .win => L.tile_win.with(h, .{ .o = d.champ.name, .c = in.name, .v = v.s, .x = x }),
                    .usual => L.tile_usual.with(h, .{ .o = d.champ.name, .c = in.name, .v = v.s, .x = x }),
                    .gold => if (gd > 0)
                        L.tile_gold_ahead.with(h, .{ .o = d.champ.name, .g = @abs(gd), .c = in.name, .x = x })
                    else if (gd < 0)
                        L.tile_gold_behind.with(h, .{ .o = d.champ.name, .g = @abs(gd), .c = in.name, .x = x })
                    else
                        L.tile_gold_level.with(h, .{ .o = d.champ.name, .c = in.name, .x = x }),
                },
                .pressed = g.dots.chosen() == k,
                .on = h.on(&g.dots, .{ .pick = k }),
            };
        }
        return h.div(.{ .class = "end" }, .{ h.h3(.{}, .{head}), champlist.view(h, .{ .tiles = true }, rows) });
    }

    /// A tile's figure for its label: win rate and vs usual are the page champion's (no
    /// direction word); gold is the face's, as its dot
    fn tileFigure(g: *const G, h: *H, in: *const Input, o: Opp) tree.Text {
        return switch (g.measure) {
            .win => winrate.shown(h, winOf(in, o).rate),
            .usual, .gold => g.figure(h, in, o),
        };
    }

    /// The figure a dot reads out with its name, in the measure's units
    fn figure(g: *const G, h: *H, in: *const Input, o: Opp) tree.Text {
        return switch (g.measure) {
            .win => phrase.num(h, .rate, @as(f32, @floatCast(winOf(in, o).rate.pct))),
            .usual => phrase.num(h, .points, o.usual),
            .gold => {
                // x minus the dot's champion: the dot's champion is ahead when negative
                const gd: i32 = goldOf(in, o) orelse 0;
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
fn faded(in: *const Input, o: Opp) bool {
    return fmt.wide(winOf(in, o).rate.half.?);
}

fn brief(h: *H, in: *const Input, rel: Rel, rl: Counts, o: Opp) matchbrief.Brief {
    const usual_tip = h.fmt("cp-usual-{d}", .{o.champ});
    const w = winOf(in, o);
    var items: [4]strip.Item = undefined;
    var n: usize = 0;
    items[n] = .{ .label = W.wins.with(h, .{ .c = in.name }), .rate = winrate.view(h, w.rate, .{ .said = "", .worth = w.meio }), .answer = true };
    n += 1;
    items[n] = .{ .label = W.m_usual, .rate = winrate.delta(h, o.usual, fmt.range(o.games, o.wins)), .ctx = cp.usualSide(o.usual, W.below_usual, W.above_usual), .tip = .{ .id = usual_tip, .note = W.usual_note.with(h, .{ .c = in.name }) } };
    n += 1;
    if (goldOf(in, o)) |gd| {
        items[n] = goldItem(h, in, o.champ, gd);
        n += 1;
    }
    items[n] = .{ .label = W.lock_share, .value = phrase.num(h, .pct, @as(u32, @intFromFloat(@round(100 * @as(f32, @floatFromInt(o.games)) / @as(f32, @floatFromInt(@max(rl.games, 1))))))) };
    n += 1;
    return .{
        .champ = icon(h, in, o.champ),
        .rel = if (rel.ally) W.ally.with(h, .{ .r = rel.role.label().s }) else W.opponent.with(h, .{ .r = rel.role.label().s }),
        .thin = fmt.wide(w.rate.half.?),
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
    \\  .c-mgrid > .all { display: block; margin: calc(-1 * var(--sp-2)) 0 var(--sp-4); font-size: var(--fs-s); }
    \\  .c-mgrid .end .v .w { display: block; font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-mgrid .end > h3 { margin: 0 0 var(--sp-2); font-size: var(--fs-s); font-weight: var(--w-b); color: var(--t2); }
    \\  @container (max-width: 559px) { .c-mgrid:has(.ends) .plot { display: none; } }
    \\  .c-mgrid .brief { container-type: inline-size; }
    \\  .c-mgrid .alone { margin: 0 0 var(--sp-3); font-size: var(--fs-s); color: var(--muted); }
    \\}
    \\
;

const Gallery = @import("gallery.zig").Gallery;

/// The finder on a champion and its role, by hand: url.write(Finder.Url) would cost the
/// island. finder.zig's tests read it back
pub const finder_href = "/matchups#role={s}&c={s}";

pub const demo_champs = [_]cp.Other{
    .{ .name = "Garen", .id = 86, .key = "Garen", .slug = "garen" },                   .{ .name = "Sett", .id = 875, .key = "Sett", .slug = "sett" },
    .{ .name = "Mordekaiser", .id = 82, .key = "Mordekaiser", .slug = "mordekaiser" }, .{ .name = "Yone", .id = 777, .key = "Yone", .slug = "yone" },
    .{ .name = "Dr. Mundo", .id = 36, .key = "DrMundo", .slug = "drmundo" },           .{ .name = "Volibear", .id = 106, .key = "Volibear", .slug = "volibear" },
    .{ .name = "Teemo", .id = 17, .key = "Teemo", .slug = "teemo" },                   .{ .name = "Malphite", .id = 54, .key = "Malphite", .slug = "malphite" },
    .{ .name = "Jax", .id = 24, .key = "Jax", .slug = "jax" },                         .{ .name = "Aatrox", .id = 266, .key = "Aatrox", .slug = "aatrox" },
    .{ .name = "Fiora", .id = 114, .key = "Fiora", .slug = "fiora" },                  .{ .name = "K'Sante", .id = 897, .key = "KSante", .slug = "ksante" },
    .{ .name = "Lee Sin", .id = 64, .key = "LeeSin", .slug = "leesin" },               .{ .name = "Viego", .id = 234, .key = "Viego", .slug = "viego" },
    .{ .name = "Graves", .id = 104, .key = "Graves", .slug = "graves" },
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
/// Meio's lane under no locks: Teemo has no estimate, so stays the games'
const demo_meio: Meio = .{ .stack = demoEst(0.496, 0.004), .opponents = &.{
    demoChoice(86, 0.502, 0.012, 30),   demoChoice(875, 0.478, 0.012, -45), demoChoice(82, 0.505, 0.015, null),
    demoChoice(777, 0.512, 0.014, 95),  demoChoice(36, 0.441, 0.02, -130),  demoChoice(106, 0.462, 0.016, -35),
    demoChoice(54, 0.483, 0.016, -10),  demoChoice(24, 0.484, 0.016, 0),    demoChoice(266, 0.497, 0.018, 60),
    demoChoice(114, 0.527, 0.017, 160), demoChoice(897, 0.571, 0.025, 210),
} };

fn demoEst(p: f32, half: f32) pd.Est {
    return .{ .p = p, .lo = p - half, .hi = p + half, .own = 0 };
}

fn demoChoice(id: u32, p: f32, half: f32, gold: ?f32) pd.Choice {
    return .{ .id = id, .name = "", .games = 0, .wins = 0, .meio = demoEst(p, half), .gold = if (gold) |g| demoEst(g, 40) else null };
}

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
        .finder = true,
    };
    const states = [_]struct { []const u8, u8, Measure, ?u16, ?Meio }{
        .{ "lane opponents by win rate", 0, .win, null, null },
        .{ "one chosen: its brief under the tiles", 0, .win, 3, null },
        .{ "by gold at 14", 0, .gold, null, null },
        .{ "with the jungler", 1, .win, null, null },
        .{ "Meio's lane: estimates worth games, Teemo the games'", 0, .win, 4, demo_meio },
        .{ "Meio's gold at 14", 0, .gold, null, demo_meio },
    };
    for (states) |s| {
        const d = h.mem.create(Demo) catch {
            h.oom = true;
            return;
        };
        d.* = .{ .in = in, .grid = .{ .rel = s[1], .measure = s[2] } };
        d.in.meio = s[4];
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
    try testing.expectEqualStrings("384 ahead", g.figure(&h, &in, o).s);
    try testing.expectEqualStrings("level", g.figure(&h, &in, demoOpp(10, 400, 48, -1, 0)).s);
    try testing.expectEqualStrings("120 behind", g.figure(&h, &in, demoOpp(10, 400, 48, -1, 120)).s);
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

/// The brief's lock button's word
fn lockWord(a: std.mem.Allocator, t: *const tree.Tree) ![]const u8 {
    const b = t.find(t.root, "class", "brief") orelse return "";
    var w: std.Io.Writer.Allocating = .init(a);
    try t.textOf(b, &w.writer);
    const s = w.written();
    return if (std.mem.find(u8, s, "Unlock") != null) "Unlock" else if (std.mem.find(u8, s, "Lock") != null) "Lock" else "";
}

test "on the fake DOM: the locked opponent is chosen, Unlock in its brief; another tile offers Lock" {
    const testing = std.testing;
    const island = @import("island.zig");
    const Fake = @import("fakedom.zig").Fake;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var fake: Fake = .{ .a = a };
    var rt: island.Runtime(Fake) = .init(a, &fake);
    var server: Demo = .{ .in = .{ .name = "Darius", .slug = "darius", .ddragon = champ.demo_version, .champs = &demo_champs, .role = .top, .counts = .{ .games = 20412, .wins = 10063 }, .rels = &demo_rels, .lock = .{ .on = 4 } } };
    var state = server;
    const t = try a.create(tree.Tree);
    t.* = .{};
    var h: H = .init(a, t);
    t.root = server.view(&h);
    fake.server = t;
    const i = try rt.add(Demo, &state, &server, "#matchups");
    const cur = i.current();
    const mundo = cur.find(cur.root, "aria-label", "Dr. Mundo: Darius wins 43.2% in 859 games").?;
    try testing.expectEqualStrings("true", cur.attr(mundo, "aria-pressed").?);
    try testing.expectEqualStrings("Unlock", try lockWord(a, cur));
    _ = rt.event(0, .{ .kind = .click, .target = cur.node(cur.find(cur.root, "aria-label", "K'Sante: Darius wins 60.3% in 353 games").?).dom });
    const now = i.current();
    try testing.expectEqualStrings("false", now.attr(now.find(now.root, "aria-label", "Dr. Mundo: Darius wins 43.2% in 859 games").?, "aria-pressed").?);
    try testing.expectEqualStrings("Lock", try lockWord(a, now));
    try testing.expectEqual(@as(u32, 0), fake.warnings);
}

test "gold tiles are the face's: its lead in its label, the number shown with its word under" {
    const testing = std.testing;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var d: Demo = .{ .grid = .{ .measure = .gold }, .in = .{ .name = "Darius", .slug = "darius", .ddragon = champ.demo_version, .champs = &demo_champs, .role = .top, .counts = .{ .games = 20412, .wins = 10063 }, .rels = &demo_rels, .finder = true } };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    t.root = d.view(&h);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, t.root, &out.writer);
    const html = out.written();
    // Darius minus Dr. Mundo -150: Mundo ahead
    try testing.expect(std.mem.find(u8, html, "aria-label=\"Dr. Mundo: 150 gold ahead of Darius at 14 in 859 games\"") != null);
    try testing.expect(std.mem.find(u8, html, "<span>150<span class=\"w\">ahead</span></span>") != null);
    // The rest are in the finder, the champion and its role picked
    try testing.expect(std.mem.find(u8, html, "href=\"/matchups#role=top&amp;c=darius\"") != null);
}

fn demoHtml(a: std.mem.Allocator, d: *Demo) ![]const u8 {
    const t = try a.create(tree.Tree);
    t.* = .{};
    var h: H = .init(a, t);
    t.root = d.view(&h);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(t, t.root, &out.writer);
    return out.written();
}

test "Meio's lane: tiles and brief show its rates worth games, its gold no count; one without stays the games'" {
    const testing = std.testing;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const in: Input = .{ .name = "Darius", .slug = "darius", .ddragon = champ.demo_version, .champs = &demo_champs, .role = .top, .counts = .{ .games = 20412, .wins = 10063 }, .rels = &demo_rels, .meio = demo_meio };
    var d: Demo = .{ .in = in };
    d.grid.dots.sel = 4;
    const html = try demoHtml(a, &d);
    // 44.1% +-2: worth 1,012 games
    try testing.expect(std.mem.find(u8, html, "aria-label=\"Dr. Mundo: Darius wins 44.1%, worth 1,012 games\"") != null);
    try testing.expect(std.mem.find(u8, html, "aria-label=\"Teemo: Darius wins 47.1% in 930 games\"") != null);
    try testing.expect(std.mem.find(u8, html, "in 859 games") == null);
    // The dot's tip says what its count is
    try testing.expect(std.mem.find(u8, html, "worth 1,012 games</span>") != null);

    var gd: Demo = .{ .in = in, .grid = .{ .measure = .gold } };
    const gold = try demoHtml(a, &gd);
    // Meio's -130: Mundo ahead, no count; Teemo has no Meio, so the curves' -210 in games
    try testing.expect(std.mem.find(u8, gold, "aria-label=\"Dr. Mundo: 130 gold ahead of Darius at 14\"") != null);
    try testing.expect(std.mem.find(u8, gold, "aria-label=\"Teemo: 210 gold ahead of Darius at 14 in 930 games\"") != null);
    // Mordekaiser has Meio's rate but no gold: the curves' 20
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    try testing.expectEqualStrings("20 behind", gd.grid.figure(&h, &in, demo_lane[2]).s);
}

test "Meio stays out of the other relations: the jungler's tiles are the games'" {
    const testing = std.testing;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var d: Demo = .{ .grid = .{ .rel = 1 }, .in = .{ .name = "Darius", .slug = "darius", .ddragon = champ.demo_version, .champs = &demo_champs, .role = .top, .counts = .{ .games = 20412, .wins = 10063 }, .rels = &demo_rels, .meio = demo_meio } };
    const html = try demoHtml(a, &d);
    try testing.expect(std.mem.find(u8, html, "aria-label=\"Lee Sin: Darius wins 50.8% in 2,104 games\"") != null);
    try testing.expect(std.mem.find(u8, html, "worth") == null);
}
