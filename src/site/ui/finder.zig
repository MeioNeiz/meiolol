//! The matchup finder (matchup/index.html, docs/plan/ui/matchups.md): a way to a matchup
//! page, not a list of them. Nothing picked: each role's most played lane pairs (the
//! role picked in place) and this patch's clearest movers, each a link to its page.
//!
//! Pages are rendered on request, so the data rides in the island's data-bin, as the
//! matchup page's do: ui-finder.wasm adopts it
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
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;

pub const name = "Finder";
pub const scope = .{".c-finder"};

pub const Other = champpage.Other;

pub const Data = struct {
    ddragon: []const u8,
    /// Pair.x and .y index it
    champs: []const Other,
    /// Role.all's order: most games first, each from the side that won more
    most: []const []const Pair,
    /// The clearest win rate moves this patch, from the side that gained, biggest first
    moved: []const Move = &.{},
    /// "16.21"; "" without an earlier patch to compare with
    patch: []const u8 = "",
    /// From the view's root to the view whose matchup pages have whole patches: "patch/"
    /// or ""
    patch_dir: []const u8 = "",
};

pub const Pair = struct { x: u16, y: u16, games: u32, wins: u32 };

pub const Move = struct {
    role: role.Role,
    x: u16,
    y: u16,
    /// x's win rate this patch minus the previous one, points, with its 95% half width
    d: f32,
    ci: f32,
    /// This patch's
    games: u32,
};

const W = struct {
    pub const title = plain("Matchups");
    pub const most = plain("Most played");
    pub const moved = plain("Moved this patch");
    pub const patch = Phrase("Patch {p:text}");
    pub const role_label = plain("Role");
    pub const none = plain("Not enough games yet.");
};

pub const Finder = struct {
    data: *const Data,
    /// "../" from the page to the view's root
    root: []const u8,
    bin: []const u8 = "",
    role: role.Role = .top,

    const F = @This();

    pub const Msg = union(enum) { role: role.Role };

    pub const Url = struct { role: ?role.Role = null };

    pub fn toUrl(f: *const F) Url {
        return .{ .role = if (f.role == .top) null else f.role };
    }

    pub fn fromUrl(f: *F, u: Url) void {
        f.role = u.role orelse .top;
    }

    pub fn update(f: *F, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .role => |r| f.role = r,
        }
        ev.push = true;
    }

    pub fn view(f: *F, h: *H) N {
        return h.div(.{ .class = "c-finder", .data_island = "finder", .data_root = f.root, .data_bin = if (f.bin.len > 0) f.bin else null }, .{
            h.el(.h1, .{}, .{W.title}),
            f.mostCard(h),
            f.movedCard(h),
        });
    }

    fn icon(f: *const F, h: *H, i: u16) champ.Champ {
        const c = f.data.champs[i];
        return .{ .name = c.name, .src = h.fmt("https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ f.data.ddragon, c.key }) };
    }

    fn href(f: *const F, h: *H, dir: []const u8, r: role.Role, x: u16, y: u16) []const u8 {
        return h.fmt("{s}{s}matchup/{s}/{s}-vs-{s}.html", .{ f.root, dir, @tagName(r), f.data.champs[x].slug, f.data.champs[y].slug });
    }

    fn mostCard(f: *F, h: *H) N {
        var items: [role.Role.all.len]rolepicker.Item = undefined;
        for (role.Role.all, &items) |r, *it| it.* = .{ .role = r, .current = r == f.role, .on = h.on(f, .{ .role = r }) };
        const pairs = if (f.data.most.len > @backingInt(f.role)) f.data.most[@backingInt(f.role)] else &.{};
        const rows = h.mem.alloc(champlist.Row, pairs.len) catch {
            h.oom = true;
            return .none;
        };
        for (pairs, rows) |p, *row| {
            const won = rate(p.games, p.wins);
            row.* = .{
                .champ = f.icon(h, p.x),
                .vs = f.icon(h, p.y),
                .href = f.href(h, "", f.role, p.x, p.y),
                .value = h.span(.{ .style = h.vars(.{ .c = fmt.Step.of(won - 50, fmt.win_cuts) }) }, .{phrase.num(h, .rate, won)}),
                .note = phrase.num(h, .count, p.games),
            };
        }
        return card.view(h, .{}, &.{
            card.head(h, W.most, null, &.{rolepicker.view(h, .{ .v = .compact, .label = W.role_label }, &items)}),
            if (rows.len == 0) h.p(.{ .class = "none" }, .{W.none}) else champlist.view(h, .{ .cols = true, .label = W.most }, rows),
        });
    }

    fn movedCard(f: *F, h: *H) N {
        const d = f.data;
        if (d.moved.len == 0) return .none;
        const rows = h.mem.alloc(champlist.Row, d.moved.len) catch {
            h.oom = true;
            return .none;
        };
        for (d.moved, rows) |m, *row| row.* = .{
            .champ = f.icon(h, m.x),
            .vs = f.icon(h, m.y),
            .role = m.role,
            .href = f.href(h, d.patch_dir, m.role, m.x, m.y),
            .value = delta.view(h, .{ .d = m.d, .ci = m.ci }),
            .note = phrase.num(h, .count, m.games),
        };
        const link = h.a(.{ .class = "more", .href = h.fmt("{s}patch.html", .{f.root}) }, .{W.patch.with(h, .{ .p = d.patch })});
        return card.view(h, .{}, &.{
            card.head(h, W.moved, null, &.{link}),
            champlist.view(h, .{ .cols = true, .label = W.moved }, rows),
        });
    }
};

fn rate(games: u32, wins: u32) f32 {
    return 100 * @as(f32, @floatFromInt(wins)) / @as(f32, @floatFromInt(@max(games, 1)));
}

pub const css =
    \\@layer components {
    \\  .c-finder { display: grid; gap: var(--sp-4); }
    \\  .c-finder > h1 { margin: 0; }
    \\  .c-finder .c-head > .more { margin-left: auto; font-size: var(--fs-s); }
    \\  .c-finder .none { margin: 0; color: var(--faint); }
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
    };
    const top = [_]Pair{
        .{ .x = 0, .y = 1, .games = 1788, .wins = 915 },
        .{ .x = 2, .y = 3, .games = 1204, .wins = 655 },
    };
    const mid = [_]Pair{.{ .x = 4, .y = 5, .games = 2410, .wins = 1230 }};
    pub const data: Data = .{
        .ddragon = "16.21.1",
        .champs = &champs,
        .most = &.{ &top, &.{}, &mid, &.{}, &.{} },
        .moved = &.{.{ .role = .mid, .x = 5, .y = 4, .d = 3.4, .ci = 2.1, .games = 1630 }},
        .patch = "16.21",
        .patch_dir = "patch/",
    };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, role.Role }{
        .{ "nothing picked: Top's most played, this patch's movers", .top },
        .{ "a role with no pairs yet", .jungle },
    };
    for (states) |st| {
        const f = h.mem.create(Finder) catch {
            h.oom = true;
            return;
        };
        f.* = .{ .data = &Demo.data, .root = "", .role = st[1] };
        g.addFill(st[0], f.view(h));
    }
}
