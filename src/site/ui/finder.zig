//! The matchup finder (matchup/index.html, docs/plan/ui/matchups.md): a way to a matchup
//! page, not a list of them. Two islands. Finder: two ChampRolePickers, one lane for both;
//! nothing picked, a role and three short lists of its lane pairs (this patch's movers,
//! the hardest lanes, the lane bullies), each a link to its page. Grid (its own, lazily
//! loaded file): the first pick's MatchupGrid, Against its lane, from the champion page's
//! data/champion/<slug>-more.bin; the second pick is that opponent's dot, and its page when
//! there is one. Finder writes the picks to the URL, Grid reads them (same keys).
//!
//! Pages are rendered on request, so Finder's data rides in its data-bin, as the matchup
//! page's do: ui-finder.wasm adopts it
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const card = @import("card.zig");
const delta = @import("delta.zig");
const rolepicker = @import("rolepicker.zig");
const champlist = @import("champlist.zig");
const champpage = @import("champpage.zig");
const champsearch = @import("champsearch.zig");
const champrolepicker = @import("champrolepicker.zig");
const matchgrid = @import("matchgrid.zig");
const button = @import("button.zig");
const url = @import("url.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "Finder";
pub const scope = .{ ".c-finder", ".c-fgrid" };

pub const Other = champpage.Other;

pub const Data = struct {
    ddragon: []const u8,
    /// Pair.x and .y index it
    champs: []const Other,
    /// Each champion's roles with games, most played first (its main role first)
    roles: []const []const role.Role = &.{},
    /// Role.all's order, each list's: the lowest win rates, from the side that wins less
    hard: []const []const Pair = &.{},
    /// The biggest gold leads at 14 minutes, from the side ahead
    bully: []const []const Lead = &.{},
    /// This patch's win rate moves, from the side that gained: clear ones, then the surest
    /// of the rest
    moved: []const []const Move = &.{},
    /// "16.21"; "" without an earlier patch to compare with
    patch: []const u8 = "",
    /// The query of the view whose matchup pages have whole patches
    patch_query: []const u8 = "?period=patch",
};

pub const Pair = struct { x: u16, y: u16, games: u32, wins: u32 };

/// x's median gold lead over y at 14 minutes
pub const Lead = struct { x: u16, y: u16, games: u32, gold: i16 };

pub const Move = struct {
    role: role.Role,
    x: u16,
    y: u16,
    /// x's win rate this patch minus the previous one, points, with its 95% half width
    d: f32,
    ci: f32,
    /// This patch's
    games: u32,
    /// Too big to be luck (the patch page's test); else faint with its range
    clear: bool = true,
};

const W = struct {
    pub const title = plain("Matchups");
    pub const moved = plain("Moved this patch");
    pub const hard = plain("Hardest lanes");
    pub const bully = plain("Lane bullies");
    pub const gold = Phrase("{g:signed} gold");
    pub const patch = Phrase("Patch {p:text}");
    pub const role_label = plain("Role");
    pub const none = plain("Not enough games yet.");
    pub const pm = Phrase("±{ci:dec}");
    pub const yours = plain("Your champion");
    pub const opponent = plain("Opponent");
    pub const go = plain("Matchup ›");
    pub const no_page = Phrase("Too few {a:text} vs {b:text} games in {r:text} for a matchup page.");
};

pub const Finder = struct {
    data: *const Data,
    /// The view's query its links keep ("" for the default)
    query: []const u8,
    bin: []const u8 = "",
    /// Most played's; the pair's lane once a champion is picked
    role: role.Role = .top,
    /// Search entries are data.champs, by index
    pair: champrolepicker.Pair,
    /// The second champion as last seen: a new one is a pick, the same a role change
    b_seen: ?u16 = null,

    const F = @This();

    pub const Msg = union(enum) { role: role.Role, a, b, swap };

    pub const Url = struct { role: ?role.Role = null, c: url.Str(24) = .{}, vs: url.Str(24) = .{} };

    pub fn init(a: std.mem.Allocator, data: *const Data, query: []const u8) !F {
        const entries = try a.alloc(champsearch.Entry, data.champs.len);
        for (entries, data.champs, 0..) |*e, c, i| e.* = .{
            .name = c.name,
            .src = try std.fmt.allocPrint(a, champ.icon_fmt, .{ data.ddragon, c.key }),
            .roles = if (i < data.roles.len) data.roles[i] else &.{},
        };
        const ix = try a.create(champsearch.Index);
        ix.* = try .init(a, entries);
        return .{ .data = data, .query = query, .pair = .{
            .a = .{ .search = .{ .index = ix, .id = "fd-a", .label = W.yours } },
            .b = .{ .search = .{ .index = ix, .id = "fd-b", .label = W.opponent } },
        } };
    }

    /// With a champion the role is written even when Top: none means its main role
    pub fn toUrl(f: *const F) Url {
        const p = &f.pair;
        var u: Url = .{};
        if (p.a.search.chosen) |e| {
            u.c.set(f.data.champs[e].slug);
            u.role = p.a.role orelse f.role;
        } else if (f.role != .top) u.role = f.role;
        if (p.b.search.chosen) |o| u.vs.set(f.data.champs[o].slug);
        return u;
    }

    pub fn fromUrl(f: *F, u: Url) void {
        const p = &f.pair;
        p.a.search.chosen = f.find(u.c.slice());
        p.b.search.chosen = f.find(u.vs.slice());
        if (p.b.search.chosen == p.a.search.chosen) p.b.search.chosen = null;
        const lead = p.a.search.chosen orelse p.b.search.chosen;
        f.role = if (lead) |e| f.roleOf(e, u.role) else u.role orelse .top;
        p.a.role = if (p.a.search.chosen != null) f.role else null;
        p.b.role = if (p.b.search.chosen != null) f.role else null;
        f.b_seen = p.b.search.chosen;
    }

    /// `want` when champion `e` has games in it, else its main role
    fn roleOf(f: *const F, e: u16, want: ?role.Role) role.Role {
        const rs = if (e < f.data.roles.len) f.data.roles[e] else &.{};
        if (want) |r| if (std.mem.findScalar(role.Role, rs, r) != null) return r;
        return if (rs.len > 0) rs[0] else want orelse .top;
    }

    fn find(f: *const F, slug: []const u8) ?u16 {
        if (slug.len == 0) return null;
        for (f.data.champs, 0..) |c, i| if (std.mem.eql(u8, c.slug, slug)) return @intCast(i);
        return null;
    }

    pub fn update(f: *F, m: Msg, ev: *tree.Event) void {
        const p = &f.pair;
        switch (m) {
            .role => |r| {
                f.role = r;
                ev.push = true;
            },
            .a, .swap => {
                if (p.a.search.chosen != null and p.a.search.chosen == p.b.search.chosen) p.b.reset();
                if (p.a.role) |r| {
                    f.role = r;
                    if (p.b.search.chosen != null) p.b.role = r;
                }
                f.b_seen = p.b.search.chosen;
            },
            .b => {
                if (p.b.search.chosen != null and p.b.search.chosen == p.a.search.chosen) p.b.reset();
                const new = p.b.search.chosen != f.b_seen;
                f.b_seen = p.b.search.chosen;
                if (p.b.search.chosen == null) return;
                if (new) {
                    p.b.role = p.a.role orelse p.b.role;
                } else if (p.a.search.chosen != null) {
                    p.a.role = p.b.role;
                    if (p.b.role) |r| f.role = r;
                }
            },
        }
    }

    pub fn view(f: *F, h: *H) N {
        const p = &f.pair;
        p.a.on_pick = h.on(f, .a);
        p.b.on_pick = h.on(f, .b);
        p.on_swap = h.on(f, .swap);
        const picked = p.a.search.chosen != null;
        return h.div(.{ .class = "c-finder", .data_island = "finder", .data_query = f.query, .data_bin = if (f.bin.len > 0) f.bin else null }, .{
            h.el(.h1, .{}, .{W.title}),
            p.view(h),
            if (picked) N.none else f.lists(h),
        });
    }

    fn icon(f: *const F, h: *H, i: u16) champ.Champ {
        const c = f.data.champs[i];
        return .{ .name = c.name, .src = h.fmt(champ.icon_fmt, .{ f.data.ddragon, c.key }) };
    }

    fn href(f: *const F, h: *H, query: []const u8, r: role.Role, x: u16, y: u16) []const u8 {
        return h.fmt("/matchups/{s}/{s}-vs-{s}{s}", .{ @tagName(r), f.data.champs[x].slug, f.data.champs[y].slug, query });
    }

    /// Nothing picked: a role, then its three lists side by side
    fn lists(f: *F, h: *H) N {
        var items: [role.Role.all.len]rolepicker.Item = undefined;
        for (role.Role.all, &items) |r, *it| it.* = .{ .role = r, .current = r == f.role, .on = h.on(f, .{ .role = r }) };
        return h.div(.{ .class = "lists" }, .{
            rolepicker.view(h, .{ .v = .compact, .label = W.role_label }, &items),
            h.div(.{ .class = "cols" }, .{ f.movedCard(h), f.hardCard(h), f.bullyCard(h) }),
        });
    }

    fn of(comptime T: type, by_role: []const []const T, r: role.Role) []const T {
        return if (by_role.len > @backingInt(r)) by_role[@backingInt(r)] else &.{};
    }

    fn listCard(h: *H, title: tree.Text, controls: []const N, rows: []const champlist.Row) N {
        return card.view(h, .{}, &.{
            card.head(h, title, null, controls),
            if (rows.len == 0) h.p(.{ .class = "none" }, .{W.none}) else champlist.view(h, .{ .label = title }, rows),
        });
    }

    fn rowsOf(h: *H, n: usize) []champlist.Row {
        return h.mem.alloc(champlist.Row, n) catch {
            h.oom = true;
            return &.{};
        };
    }

    fn movedCard(f: *F, h: *H) N {
        const d = f.data;
        if (d.patch.len == 0) return .none;
        const moves = of(Move, d.moved, f.role);
        const rows = rowsOf(h, moves.len);
        for (moves[0..rows.len], rows) |m, *row| row.* = .{
            .champ = f.icon(h, m.x),
            .vs = f.icon(h, m.y),
            .href = f.href(h, d.patch_query, m.role, m.x, m.y),
            .value = if (m.clear) delta.view(h, .{ .d = m.d }) else h.span(.{}, .{
                delta.view(h, .{ .d = m.d, .faint = true }),
                h.span(.{ .class = "pm" }, .{W.pm.with(h, .{ .ci = m.ci })}),
            }),
            .note = phrase.num(h, .count, m.games),
        };
        const link = h.a(.{ .class = "more", .href = h.fmt("/patch{s}", .{f.query}) }, .{W.patch.with(h, .{ .p = d.patch })});
        return listCard(h, W.moved, &.{link}, rows);
    }

    fn hardCard(f: *F, h: *H) N {
        const pairs = of(Pair, f.data.hard, f.role);
        const rows = rowsOf(h, pairs.len);
        for (pairs[0..rows.len], rows) |p, *row| {
            const won = rate(p.games, p.wins);
            row.* = .{
                .champ = f.icon(h, p.x),
                .vs = f.icon(h, p.y),
                .href = f.href(h, "", f.role, p.x, p.y),
                .value = h.span(.{}, .{phrase.num(h, .rate, won)}),
                .note = phrase.num(h, .count, p.games),
            };
        }
        return listCard(h, W.hard, &.{}, rows);
    }

    fn bullyCard(f: *F, h: *H) N {
        const leads = of(Lead, f.data.bully, f.role);
        const rows = rowsOf(h, leads.len);
        for (leads[0..rows.len], rows) |l, *row| row.* = .{
            .champ = f.icon(h, l.x),
            .vs = f.icon(h, l.y),
            .href = f.href(h, "", f.role, l.x, l.y),
            .value = h.span(.{}, .{W.gold.with(h, .{ .g = l.gold })}),
            .note = phrase.num(h, .count, l.games),
        };
        return listCard(h, W.bully, &.{}, rows);
    }
};

/// The first pick's matchups. Its URL is Finder's: it reads the picks and writes them back
/// unchanged (each runtime rewrites the keys it owns)
pub const Grid = struct {
    /// The view's tree from the site root ("/", "/_v/all/"): its champion files
    root: []const u8,
    /// The view's query its links keep
    query: []const u8 = "",
    /// ui-findergrid.js and .wasm, for ui-finder.wasm to load
    js: ?[]const u8 = null,
    wasm: ?[]const u8 = null,
    u: Url = .{},
    /// The first champion's matchups, once fetched (null: its file failed)
    more: ?*const champpage.MoreData = null,
    /// The slug `more` is for
    more_of: url.Str(24) = .{},
    grid: matchgrid.MatchupGrid = .{},
    /// Set after the page's first read of the URL: a second pick after it goes to its page
    live: bool = false,
    /// ui-findergrid.wasm's, from a popstate until the URL is read: Back or Forward to a
    /// pair stays on the finder
    back: bool = false,
    /// A second pick not yet taken to its page (`goTo`)
    fresh: bool = false,

    const G = @This();

    pub const Msg = matchgrid.Msg;
    pub const Url = Finder.Url;

    pub fn toUrl(g: *const G) Url {
        return g.u;
    }

    pub fn fromUrl(g: *G, u: Url) void {
        var v = u;
        if (v.vs.eql(&v.c)) v.vs = .{};
        // A role change keeps a pending jump
        if (!v.vs.eql(&g.u.vs)) g.fresh = g.live and !g.back and v.vs.len > 0;
        g.u = v;
        g.aim();
    }

    /// The champion whose file the page needs: its slug (letters, digits and '-': it goes
    /// into a path)
    pub fn want(g: *const G) ?[]const u8 {
        const s = g.u.c.slice();
        if (s.len == 0) return null;
        for (s) |ch| if (!std.ascii.isAlphanumeric(ch) and ch != '-') return null;
        return s;
    }

    /// `slug`'s matchups are in (null: its file failed)
    pub fn got(g: *G, slug: []const u8, d: ?*const champpage.MoreData) void {
        g.more = d;
        g.more_of.set(slug);
        g.aim();
    }

    /// A fresh second pick's page, once its first champion's matchups are in
    pub fn goTo(g: *G, a: std.mem.Allocator) ?[]const u8 {
        if (!g.fresh) return null;
        const in = g.input() orelse return null;
        g.fresh = false;
        const k = g.opp(&in) orelse return null;
        return pageOf(a, &in, in.rels[g.grid.rel].opps[k]) catch null;
    }

    pub fn update(g: *G, m: Msg, _: *tree.Event) void {
        const in = g.input() orelse return;
        g.grid.update(&in, m);
    }

    /// The first champion in the URL's role, else its main one, once its matchups are in
    fn input(g: *const G) ?matchgrid.Input {
        if (g.u.c.len == 0 or !g.more_of.eql(&g.u.c)) return null;
        const d = g.more orelse return null;
        const x = for (d.roles) |*x| {
            if (g.u.role) |r| if (x.role == r) break x;
        } else if (d.roles.len > 0) &d.roles[0] else return null;
        return .{
            .name = d.name,
            .slug = d.slug,
            .ddragon = d.ddragon,
            .champs = d.champs,
            .query = g.query,
            .role = x.role,
            .counts = .{ .games = x.games, .wins = x.wins },
            .rels = x.rels,
        };
    }

    /// The grid back on the lane, the second champion's dot chosen
    fn aim(g: *G) void {
        const in = g.input() orelse return;
        g.grid.set(&in, false, null, .win);
        if (g.opp(&in)) |k| g.grid.dots.sel = k;
    }

    /// The second champion among the lane opponents (the dots' index by win rate)
    fn opp(g: *const G, in: *const matchgrid.Input) ?u16 {
        if (g.u.vs.len == 0 or in.rels.len == 0) return null;
        const rel = in.rels[g.grid.rel];
        if (rel.ally or rel.role != in.role) return null;
        for (rel.opps, 0..) |o, k| {
            if (o.champ < in.champs.len and std.mem.eql(u8, in.champs[o.champ].slug, g.u.vs.slice())) return @intCast(k);
        }
        return null;
    }

    pub fn view(g: *G, h: *H) N {
        return h.div(.{ .class = "c-fgrid", .data_island = "findergrid", .data_root = g.root, .data_query = g.query, .data_js = g.js, .data_wasm = g.wasm }, .{
            if (g.u.c.len == 0) N.none else g.goLine(h),
            if (g.u.c.len == 0) N.none else g.gridCard(h),
        });
    }

    /// Both picked: the way to their page, or why there is none
    fn goLine(g: *G, h: *H) N {
        if (g.u.vs.len == 0) return .none;
        const in = g.input() orelse return .none;
        const b = g.u.vs.slice();
        if (g.opp(&in)) |k| {
            const o = in.rels[g.grid.rel].opps[k];
            const href = pageOf(h.mem, &in, o) catch {
                h.oom = true;
                return .none;
            };
            if (href) |x| return h.p(.{ .class = "go", .role = "status" }, .{button.view(h, .{ .v = .primary, .href = x, .ref = "go" }, .{W.go})});
        }
        const b_name = for (in.champs) |c| {
            if (std.mem.eql(u8, c.slug, b)) break c.name;
        } else return .none;
        return h.p(.{ .class = "none", .role = "status" }, .{W.no_page.with(h, .{ .a = in.name, .b = b_name, .r = in.role.label().s })});
    }

    fn gridCard(g: *G, h: *H) N {
        if (!g.more_of.eql(&g.u.c)) return cardWith(h, h.div(.{ .class = "wait", .data_busy = true, .aria_busy = true }, .{}));
        var in = g.input() orelse return cardWith(h, h.p(.{ .class = "none", .role = "status" }, .{W.none}));
        return g.grid.view(h, g, &in);
    }
};

fn cardWith(h: *H, body: N) N {
    return card.view(h, .{ .id = "matchups" }, &.{ card.head(h, champpage.W.matchups, null, &.{}), body });
}

fn pageOf(a: std.mem.Allocator, in: *const matchgrid.Input, o: champpage.Opp) !?[]const u8 {
    if (!o.page or o.champ >= in.champs.len) return null;
    return try std.mem.concat(a, u8, &.{ "/matchups/", @tagName(in.role), "/", in.slug, "-vs-", in.champs[o.champ].slug, in.query });
}

fn rate(games: u32, wins: u32) f32 {
    return 100 * @as(f32, @floatFromInt(wins)) / @as(f32, @floatFromInt(@max(games, 1)));
}

pub const css =
    \\@layer components {
    \\  .c-finder { display: grid; gap: var(--sp-4); }
    \\  .c-finder > h1 { margin: 0; }
    \\  .c-finder .c-head > .more { margin-left: auto; font-size: var(--fs-s); }
    \\  .c-finder .lists { display: grid; gap: var(--sp-3); justify-items: start; }
    \\  .c-finder .cols { justify-self: stretch; display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: var(--sp-4); align-items: start; }
    \\  .c-finder .none { margin: 0; color: var(--faint); }
    \\  .c-finder .pm { margin-left: 4px; color: var(--faint); font-size: var(--fs-xs); font-variant-numeric: tabular-nums; }
    \\  .c-fgrid:not(:empty) { display: grid; gap: var(--sp-4); margin-top: var(--sp-4); }
    \\  .c-fgrid > .go, .c-fgrid > .none { margin: 0; }
    \\  .c-fgrid > .none { color: var(--faint); }
    \\  .c-fgrid .wait { min-height: 220px; }
    \\}
    \\
;

pub const Demo = struct {
    pub const champs = [_]Other{
        .{ .name = "Darius", .key = "Darius", .slug = "darius" },
        .{ .name = "Garen", .key = "Garen", .slug = "garen" },
        .{ .name = "Malphite", .key = "Malphite", .slug = "malphite" },
        .{ .name = "Tryndamere", .key = "Tryndamere", .slug = "tryndamere" },
        .{ .name = "Ahri", .key = "Ahri", .slug = "ahri" },
        .{ .name = "Zed", .key = "Zed", .slug = "zed" },
        .{ .name = "Lee Sin", .key = "LeeSin", .slug = "leesin" },
    };
    const top = [_]Pair{
        .{ .x = 3, .y = 2, .games = 1204, .wins = 549 },
        .{ .x = 1, .y = 0, .games = 1788, .wins = 873 },
    };
    const mid = [_]Pair{.{ .x = 4, .y = 5, .games = 2410, .wins = 1180 }};
    const top_leads = [_]Lead{
        .{ .x = 0, .y = 1, .games = 1788, .gold = 412 },
        .{ .x = 3, .y = 2, .games = 1204, .gold = 168 },
    };
    const top_only = [_]role.Role{.top};
    const mid_only = [_]role.Role{.mid};
    pub const data: Data = .{
        .ddragon = "16.21.1",
        .champs = &champs,
        .roles = &.{ &top_only, &.{ .top, .mid }, &.{ .top, .support }, &top_only, &mid_only, &mid_only, &.{.jungle} },
        .hard = &.{ &top, &.{}, &mid, &.{}, &.{} },
        .bully = &.{ &top_leads, &.{}, &.{}, &.{}, &.{} },
        .moved = &.{ &.{ .{ .role = .top, .x = 2, .y = 0, .d = 3.4, .ci = 2.1, .games = 1630 }, .{ .role = .top, .x = 1, .y = 3, .d = 12.4, .ci = 11.6, .games = 140, .clear = false } }, &.{}, &.{.{ .role = .mid, .x = 5, .y = 4, .d = 2.8, .ci = 1.9, .games = 1310 }}, &.{}, &.{} },
        .patch = "16.21",
    };

    /// Darius's file: Opp.champ indexes matchgrid's demo champions (Garen first)
    pub const more: champpage.MoreData = .{
        .name = "Darius",
        .slug = "darius",
        .ddragon = "16.21.1",
        .champs = &matchgrid.demo_champs,
        .roles = &.{.{ .role = .top, .games = 20412, .wins = 10063, .rels = &matchgrid.demo_rels, .by_patch = &.{}, .by_length = &.{} }},
        .lengths = &.{},
    };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    // Picked: Darius, then Garen; Lee Sin: in his file, not in his lane
    const states = [_]struct { []const u8, role.Role, ?u16, ?u16, bool }{
        .{ "nothing picked: Top's movers, hardest lanes and bullies", .top, null, null, false },
        .{ "a role with no pairs yet", .jungle, null, null, false },
        .{ "one picked, its matchups on the way", .top, 0, null, false },
        .{ "one picked: its lane opponents", .top, 0, null, true },
        .{ "both picked: the opponent's brief and the way to their page", .top, 0, 1, true },
        .{ "both picked, too few games for a page", .top, 0, 6, true },
    };
    for (states) |st| {
        const f = h.mem.create(Finder) catch {
            h.oom = true;
            return;
        };
        f.* = Finder.init(h.mem, &Demo.data, "") catch {
            h.oom = true;
            return;
        };
        f.pair.a.search.id = h.fmt("{s}-a", .{g.id("fd")});
        f.pair.b.search.id = h.fmt("{s}-b", .{g.id("fd")});
        var u: Finder.Url = .{ .role = st[1] };
        if (st[2]) |e| u.c.set(Demo.champs[e].slug);
        if (st[3]) |e| u.vs.set(Demo.champs[e].slug);
        f.fromUrl(u);
        const gr = h.mem.create(Grid) catch {
            h.oom = true;
            return;
        };
        gr.* = .{ .root = "/" };
        gr.fromUrl(u);
        if (st[4]) gr.got("darius", &Demo.more);
        g.addFill(st[0], h.div(.{}, .{ f.view(h), gr.view(h) }));
    }
}

const testing = std.testing;

test "Finder: one lane for both picks; the URL keeps them" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var f = try Finder.init(a, &Demo.data, "");
    _ = f.view(&h);

    var ev: tree.Event = .{ .kind = .click };
    // Ahri: mid only
    f.pair.a.search.update(.{ .pick = 4 }, &ev);
    try testing.expectEqual(role.Role.mid, f.role);
    _ = f.view(&h);
    f.pair.a.search.update(.clear, &ev);
    f.pair.a.search.update(.{ .pick = 0 }, &ev);
    try testing.expectEqual(role.Role.top, f.role);

    // The same champion twice: the second goes
    _ = f.view(&h);
    f.pair.b.search.update(.{ .pick = 0 }, &ev);
    try testing.expect(f.pair.b.search.chosen == null);

    // Garen (main top, also mid) takes Darius's lane; his role chip moves both
    _ = f.view(&h);
    f.pair.b.search.update(.{ .pick = 1 }, &ev);
    try testing.expectEqual(role.Role.top, f.pair.b.role.?);
    var w: std.Io.Writer.Allocating = .init(a);
    try url.write(Finder.Url, f.toUrl(), &w.writer);
    try testing.expectEqualStrings("role=top&c=darius&vs=garen", w.written());
    _ = f.view(&h);
    f.pair.b.update(.{ .role = .mid }, &ev);
    try testing.expectEqual(role.Role.mid, f.pair.a.role.?);
    try testing.expectEqual(role.Role.mid, f.role);

    var g = try Finder.init(a, &Demo.data, "");
    g.fromUrl(url.read(Finder.Url, w.written()));
    try testing.expectEqual(0, g.pair.a.search.chosen.?);
    try testing.expectEqual(1, g.pair.b.search.chosen.?);
    try testing.expectEqual(role.Role.top, g.pair.b.role.?);

    // No role, or one the champion lacks: its main one. An opponent alone stays
    g.fromUrl(url.read(Finder.Url, "c=ahri"));
    try testing.expectEqual(role.Role.mid, g.pair.a.role.?);
    g.fromUrl(url.read(Finder.Url, "role=support&c=garen"));
    try testing.expectEqual(role.Role.top, g.pair.a.role.?);
    g.fromUrl(url.read(Finder.Url, "c=darius&vs=darius"));
    try testing.expect(g.pair.b.search.chosen == null);
    g.fromUrl(url.read(Finder.Url, "vs=zed"));
    try testing.expectEqual(5, g.pair.b.search.chosen.?);
    w.clearRetainingCapacity();
    try url.write(Finder.Url, g.toUrl(), &w.writer);
    try testing.expectEqualStrings("role=mid&vs=zed", w.written());
}

test "Finder: a thin move is faint with its range however big, a clear one bright" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var f = try Finder.init(a, &Demo.data, "");
    f.fromUrl(.{ .role = .top });
    var w: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, f.view(&h), &w.writer);
    const s = w.written();
    try testing.expect(std.mem.find(u8, s, "<span class=\"c-delta\" style=\"--c:var(--hi2)\">+3.4</span></span>") != null);
    try testing.expect(std.mem.find(u8, s, "<span class=\"c-delta\" data-state=\"unclear\" style=\"--c:var(--hi4)\">+12.4</span><span class=\"pm\">±11.6</span>") != null);
}

test "Grid: the first pick's file, the second its dot and once its page" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var g: Grid = .{ .root = "/" };
    try testing.expect(g.want() == null);
    g.fromUrl(url.read(Finder.Url, "c=..%2Fx"));
    try testing.expect(g.want() == null);
    g.fromUrl(url.read(Finder.Url, "c=nunu-willump"));
    try testing.expectEqualStrings("nunu-willump", g.want().?);

    // The page opens on a pair: no jump, its dot chosen once the file is in
    g.fromUrl(url.read(Finder.Url, "c=darius&vs=garen"));
    g.live = true;
    try testing.expectEqualStrings("darius", g.want().?);
    try testing.expect(g.input() == null);
    g.got("darius", &Demo.more);
    try testing.expectEqual(0, g.grid.dots.sel.?);
    try testing.expect(g.goTo(a) == null);
    t.root = g.view(&h);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, t.root, &out.writer);
    try testing.expect(std.mem.find(u8, out.written(), "<p class=\"go\" role=\"status\"><a class=\"c-btn\" href=\"/matchups/top/darius-vs-garen\"") != null);

    // A new second pick: its page, once; a role change meanwhile keeps it
    g.got("ahri", null);
    g.fromUrl(url.read(Finder.Url, "c=darius&vs=sett"));
    g.fromUrl(url.read(Finder.Url, "role=top&c=darius&vs=sett"));
    try testing.expect(g.goTo(a) == null);
    g.got("darius", &Demo.more);
    try testing.expectEqualStrings("/matchups/top/darius-vs-sett", g.goTo(a).?);
    try testing.expect(g.goTo(a) == null);

    // Back or Forward to a pair: no jump
    g.back = true;
    g.fromUrl(url.read(Finder.Url, "c=darius&vs=garen"));
    g.back = false;
    try testing.expect(g.goTo(a) == null);

    // In his file, not in his lane: no page, one line why; himself: no opponent
    g.fromUrl(url.read(Finder.Url, "c=darius&vs=leesin"));
    try testing.expect(g.goTo(a) == null);
    try testing.expect(g.grid.dots.sel == null);
    t.root = g.view(&h);
    out.clearRetainingCapacity();
    try @import("html.zig").write(&t, t.root, &out.writer);
    try testing.expect(std.mem.find(u8, out.written(), "Too few Darius vs Lee Sin games in Top") != null);
    g.fromUrl(url.read(Finder.Url, "c=darius&vs=darius"));
    try testing.expectEqual(0, g.u.vs.len);

    // A role he has no games in: his main one
    g.fromUrl(url.read(Finder.Url, "role=mid&c=darius"));
    try testing.expectEqual(role.Role.top, g.input().?.role);
}
