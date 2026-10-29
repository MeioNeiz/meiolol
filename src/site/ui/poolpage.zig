//! The pool page's own island (pool.html, docs/plan/ui/pool.md): the pool, up to ten
//! champion-role pairs grouped by role, and the picker. Empty by default: the picker is
//! the page. The sections per role are ui.poolgrid's island beside it, which ui-pool.wasm
//! tells the pool; the pool rides in the URL (#pool=86t-122j) and localStorage
const std = @import("std");
const tree = @import("tree.zig");
const card = @import("card.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const rolepicker = @import("rolepicker.zig");
const champsearch = @import("champsearch.zig");
const poolslots = @import("poolslots.zig");
const phrase = @import("phrase.zig");
const url = @import("url.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Role = role.Role;

pub const name = "PoolPage";
pub const scope = .{ ".c-poolpage", ".c-poolwrap" };
pub const sel = "[data-island=pool]";

/// Champion-role pairs in a pool
pub const max = 10;
/// By role icons before "All"
const role_shown = 24;

const W = struct {
    pub const title = plain("Champion pool");
    pub const lead = plain("Your champions in each role, the lanes they leave open, what to add");
    pub const choose = plain("Choose your pool");
    pub const choose_sub = plain("up to 10, any roles");
    pub const add_champs = plain("Add champions");
    pub const of_max = Phrase("{n:int} of 10");
    pub const any = plain("Any champion");
    pub const by_role = plain("By role");
    pub const all = Phrase("All {n:int}");
    pub const fewer = plain("Fewer");
    pub const add = Phrase("Add {c:text}");
};

/// How hard a champion is to pick up (src/learning.zig): new against practised players
pub const Pickup = enum(u8) { usual, harder, easier };

pub const Champ = struct {
    id: u16,
    name: []const u8,
    /// Data Dragon's
    key: []const u8,
    slug: []const u8,
    pickup: Pickup = .usual,
    /// A bit per role it has lanes in (Role order): By role lists it there
    roles: u8 = 0,
};

/// A champion with a pool file
pub const Main = struct {
    /// Champ's index
    c: u16,
    role: Role,
    players: u32,
};

pub const Data = struct {
    ddragon: []const u8,
    /// By name
    champs: []const Champ,
    /// Most players first
    mains: []const Main,
    /// The page's html.View index: its files' tree and its links' query (ui.urls)
    view: u8 = 0,
};

pub const Pick = struct { id: u16, role: Role };

/// The pool as the URL and localStorage hold it: "86t-122j", a role letter each
pub fn write(pool: []const Pick, w: *std.Io.Writer) std.Io.Writer.Error!void {
    for (pool, 0..) |x, i| try w.print("{s}{d}{c}", .{ if (i > 0) "-" else "", x.id, letters[@backingInt(x.role)] });
}

const letters = "tjmbs";

/// Known champions' pairs from `s` into `out`, role order, repeats and the rest past
/// `max` dropped; an id without a letter (older links) in its main role
pub fn read(d: *const Data, s: []const u8, out: *[max]Pick) u8 {
    var n: u8 = 0;
    var it = std.mem.tokenizeScalar(u8, s, '-');
    while (it.next()) |x| {
        const end = std.mem.findNone(u8, x, "0123456789") orelse x.len;
        const id = std.fmt.parseInt(u16, x[0..end], 10) catch continue;
        const c = indexOf(d, id) orelse continue;
        const r: Role = if (end == x.len) defaultRole(d, c) else if (std.mem.findScalar(u8, letters, x[end])) |k| @fromBackingInt(@intCast(k)) else continue;
        n = insert(out, n, .{ .id = id, .role = r });
    }
    return n;
}

/// `x` into `pool[0..n]` after its role's others; the new length
fn insert(pool: *[max]Pick, n: u8, x: Pick) u8 {
    if (n == max) return n;
    for (pool[0..n]) |y| if (y.id == x.id and y.role == x.role) return n;
    var at: usize = n;
    while (at > 0 and @backingInt(pool[at - 1].role) > @backingInt(x.role)) at -= 1;
    std.mem.copyBackwards(Pick, pool[at + 1 .. n + 1], pool[at..n]);
    pool[at] = x;
    return n + 1;
}

/// Its main role, else its first role with lanes, else top
pub fn defaultRole(d: *const Data, c: usize) Role {
    if (mainOf(d, c)) |m| return m.role;
    const bits = d.champs[c].roles;
    return if (bits == 0) .top else @fromBackingInt(@intCast(@ctz(bits)));
}

pub const Page = struct {
    d: *const Data,
    search: champsearch.ChampSearch,
    pool: [max]Pick = undefined,
    n: u8 = 0,
    /// By role's tab: its icons add in this role
    role: Role = .top,
    /// By role shows every champion
    all: bool = false,
    /// The pool changed by a message (not the URL), for the wasm to store
    dirty: bool = false,
    /// The server's render: Data as ui.data, base64, for the island
    bin: []const u8 = "",

    const P = @This();

    pub const Url = struct { pool: url.Str(64) = .{} };

    pub const Msg = union(enum) { picked, add: u16, remove: u8, role: Role, all, focus };

    /// Builds the search's index over `d.champs`, in `a`
    pub fn init(a: std.mem.Allocator, d: *const Data) !P {
        const entries = try a.alloc(champsearch.Entry, d.champs.len);
        for (entries, d.champs, 0..) |*e, c, i| e.* = .{
            .name = c.name,
            .src = try a.print(champ.icon_fmt, .{ d.ddragon, c.key }),
            .roles = if (mainOf(d, i)) |m| try a.dupe(Role, &.{m.role}) else &.{},
        };
        const ix = try a.create(champsearch.Index);
        ix.* = try .init(a, entries);
        return .{ .d = d, .search = .{ .index = ix, .id = "pool-pick", .mode = .pick, .label = W.any } };
    }

    pub fn picks(p: *const P) []const Pick {
        return p.pool[0..p.n];
    }

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .picked => {
                const e = p.search.chosen orelse return;
                p.search.chosen = null;
                if (e < p.d.champs.len) p.add(.{ .id = p.d.champs[e].id, .role = defaultRole(p.d, e) });
                ev.after = .{ .op = .focus, .ref = "input" };
            },
            .add => |id| p.add(.{ .id = id, .role = p.role }),
            .remove => |i| {
                if (i >= p.n) return;
                std.mem.copyForwards(Pick, p.pool[i .. p.n - 1], p.pool[i + 1 .. p.n]);
                p.n -= 1;
            },
            .role => |r| p.role = r,
            .all => p.all = !p.all,
            .focus => {
                ev.after = .{ .op = .focus, .ref = "input" };
                return;
            },
        }
        // Only what Url holds makes a history entry
        ev.push = m == .picked or m == .add or m == .remove;
        if (ev.push) p.dirty = true;
    }

    pub fn add(p: *P, x: Pick) void {
        p.n = insert(&p.pool, p.n, x);
    }

    pub fn toUrl(p: *const P) Url {
        var u: Url = .{};
        var buf: [64]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        write(p.picks(), &w) catch {};
        u.pool.set(w.buffered());
        return u;
    }

    pub fn fromUrl(p: *P, u: Url) void {
        p.n = read(p.d, u.pool.slice(), &p.pool);
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{ .class = "c-poolpage", .data_island = "pool", .data_bin = if (p.bin.len > 0) p.bin else null }, .{
            h.div(.{ .class = "top" }, .{
                h.el(.h1, .{}, .{W.title}),
                h.p(.{ .class = "lead" }, .{W.lead}),
            }),
            if (p.n > 0) p.slots(h) else null,
            if (p.n < max) h.div(.{ .class = "side" }, .{if (p.n == 0) p.picker(h, W.choose, W.choose_sub) else p.picker(h, W.add_champs, W.of_max.with(h, .{ .n = p.n }))}) else null,
        });
    }

    fn slots(p: *P, h: *H) N {
        const ss = h.mem.alloc(poolslots.Slot, p.n) catch {
            h.oom = true;
            return .none;
        };
        for (ss, p.picks(), 0..) |*s, x, i| s.* = .{
            .champ = iconOf(p.d, h, x.id),
            .role = x.role,
            .on_remove = h.on(p, .{ .remove = @intCast(i) }),
        };
        return poolslots.view(h, .{ .slots = ss, .max = max, .main = false, .on_add = h.on(p, .focus) });
    }

    fn picker(p: *P, h: *H, title: tree.Text, sub: tree.Text) N {
        var items: [Role.all.len]rolepicker.Item = undefined;
        for (Role.all, &items) |r, *it| it.* = .{ .role = r, .current = r == p.role, .on = h.on(p, .{ .role = r }) };
        p.search.on_pick = h.on(p, .picked);
        var icons = h.list();
        var n: u32 = 0;
        // The role's mains by players, then the rest playing it by name
        for (p.d.mains) |m| {
            if (m.role != p.role or m.c >= p.d.champs.len) continue;
            p.pickIcon(h, &icons, &n, m.c);
        }
        const bit = @as(u8, 1) << @backingInt(p.role);
        for (p.d.champs, 0..) |c, i| {
            if (c.roles & bit == 0) continue;
            if (mainOf(p.d, i)) |m| if (m.role == p.role) continue;
            p.pickIcon(h, &icons, &n, i);
        }
        return card.view(h, .{ .label = title }, &.{
            card.head(h, title, sub, &.{}),
            h.div(.{ .class = "pick" }, .{
                p.search.view(h),
                h.div(.{ .class = "roles" }, .{
                    h.div(.{ .class = "rh" }, .{
                        h.span(.{ .class = "lab" }, .{W.by_role}),
                        rolepicker.view(h, .{ .v = .compact, .label = W.by_role }, &items),
                    }),
                    h.div(.{ .class = "icons" }, .{icons.done()}),
                    if (n > role_shown) h.button(.{ .type = "button", .aria_expanded = p.all, .on_click = h.on(p, .all) }, .{if (p.all) W.fewer else W.all.with(h, .{ .n = n })}) else null,
                }),
            }),
        });
    }

    fn pickIcon(p: *P, h: *H, icons: *tree.List, n: *u32, c: usize) void {
        const id = p.d.champs[c].id;
        for (p.picks()) |x| if (x.id == id and x.role == p.role) return;
        n.* += 1;
        if (!p.all and n.* > role_shown) return;
        const ic = iconOf(p.d, h, id);
        icons.add(h.button(.{ .key = id, .type = "button", .class = "pk", .aria_label = W.add.with(h, .{ .c = ic.name }), .on_click = h.on(p, .{ .add = id }) }, .{
            champ.view(h, ic, .{ .px = .@"40", .named = false }),
        }));
    }
};

pub fn iconOf(d: *const Data, h: *H, id: u16) champ.Champ {
    const c = indexOf(d, id) orelse return .{ .name = "?", .src = "" };
    const x = d.champs[c];
    return .{ .name = x.name, .src = h.fmt(champ.icon_fmt, .{ d.ddragon, x.key }) };
}

pub fn indexOf(d: *const Data, id: u16) ?usize {
    for (d.champs, 0..) |c, i| if (c.id == id) return i;
    return null;
}

pub fn mainOf(d: *const Data, c: usize) ?Main {
    for (d.mains) |m| if (m.c == c) return m;
    return null;
}

pub const css =
    \\@layer components {
    \\  .c-poolwrap { container-type: inline-size; display: grid; gap: var(--sp-4); }
    \\  .c-poolwrap > .c-poolpage { display: contents; }
    \\  .c-poolpage { display: grid; gap: var(--sp-4); }
    \\  .c-poolpage > .top { display: flex; flex-wrap: wrap; align-items: baseline; gap: var(--sp-1) var(--sp-3); }
    \\  .c-poolpage > .top > h1 { margin: 0; }
    \\  .c-poolpage > .top > .lead { margin: 0; color: var(--muted); }
    \\  @container (min-width: 960px) {
    \\    .c-poolwrap:has(.c-slots) { grid-template-columns: minmax(0, 1fr) 340px; align-items: start; }
    \\    .c-poolwrap > .c-poolpage > :is(.top, .c-slots) { grid-column: 1 / -1; }
    \\    .c-poolwrap:has(.c-slots) > .c-poolpage > .side { grid-column: 2; grid-row: 3; position: sticky; top: var(--sp-4); }
    \\    .c-poolwrap:has(.c-slots) > .c-poolgrid { grid-column: 1; grid-row: 3; }
    \\  }
    \\  .c-poolwrap > .c-poolgrid:empty { display: none; }
    \\  .c-poolpage .lab { font-size: var(--fs-xs); font-weight: var(--w-m); text-transform: uppercase;
    \\    letter-spacing: 0.06em; color: var(--muted); }
    \\  .c-poolpage .pick { display: grid; gap: var(--sp-3); }
    \\  .c-poolpage .roles { display: flex; flex-direction: column; align-items: flex-start; gap: var(--sp-2); }
    \\  .c-poolpage .roles > .rh, .c-poolpage .icons { align-self: stretch; }
    \\  .c-poolpage .roles > .rh { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-2); }
    \\  .c-poolpage .icons { display: flex; flex-wrap: wrap; gap: var(--sp-1); }
    \\  .c-poolpage .icons > .pk { all: unset; cursor: pointer; border-radius: var(--r-ctl); }
    \\  .c-poolpage .icons > .pk:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }
    \\  .c-poolpage .icons > .pk:hover { filter: brightness(1.15); }
    \\}
    \\
;

pub const Demo = struct {
    pub const champs = [_]Champ{
        .{ .id = 30, .name = "Ahri", .key = "Ahri", .slug = "ahri", .roles = 0b00100 },
        .{ .id = 1, .name = "Darius", .key = "Darius", .slug = "darius", .roles = 0b00001 },
        .{ .id = 4, .name = "Dr. Mundo", .key = "DrMundo", .slug = "drmundo", .roles = 0b00011 },
        .{ .id = 10, .name = "Fiora", .key = "Fiora", .slug = "fiora", .roles = 0b00001 },
        .{ .id = 2, .name = "Garen", .key = "Garen", .slug = "garen", .pickup = .easier, .roles = 0b00001 },
        .{ .id = 3, .name = "Jax", .key = "Jax", .slug = "jax", .pickup = .harder, .roles = 0b00011 },
        .{ .id = 20, .name = "Teemo", .key = "Teemo", .slug = "teemo", .roles = 0b00001 },
        .{ .id = 40, .name = "Vi", .key = "Vi", .slug = "vi", .roles = 0b00010 },
        .{ .id = 11, .name = "Yone", .key = "Yone", .slug = "yone", .roles = 0b00101 },
    };
    pub const data: Data = .{
        .ddragon = "16.21.1",
        .champs = &champs,
        .mains = &.{
            .{ .c = 1, .role = .top, .players = 400 },
            .{ .c = 4, .role = .top, .players = 310 },
            .{ .c = 5, .role = .top, .players = 120 },
            .{ .c = 0, .role = .mid, .players = 520 },
            .{ .c = 7, .role = .jungle, .players = 450 },
        },
    };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, []const u8 }{
        .{ "empty: the picker is the page", "" },
        .{ "Darius, Garen top and Vi jungle: the slots by role, the grid, the picker beside", "1t-2t-40j" },
    };
    for (states, 0..) |st, k| {
        const p = h.mem.create(Page) catch {
            h.oom = true;
            return;
        };
        p.* = Page.init(h.mem, &Demo.data) catch {
            h.oom = true;
            return;
        };
        p.search.id = h.fmt("{s}-{d}", .{ g.id("pool-pick"), k });
        p.n = read(&Demo.data, st[1], &p.pool);
        // As the page has it: the grid island beside, in the wrapper
        const grid: N = if (p.n > 0) if (@import("poolgrid.zig").demoPage(h, st[1])) |x| x.view(h) else .none else .none;
        g.addFill(st[0], h.div(.{ .class = "c-poolwrap" }, .{ p.view(h), grid }));
    }
}

const testing = std.testing;

fn render(a: std.mem.Allocator, p: *Page) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    t.root = p.view(&h);
    if (h.oom) return error.OutOfMemory;
    var w: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, t.root, &w.writer);
    return w.written();
}

fn urlOf(a: std.mem.Allocator, p: *const Page) ![]const u8 {
    const u = p.toUrl();
    return a.dupe(u8, u.pool.slice());
}

fn link(s: []const u8) Page.Url {
    var u: Page.Url = .{};
    u.pool.set(s);
    return u;
}

test "pool page: empty is the picker; the URL's pool keeps known pairs by role, ten at most" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p: Page = try .init(a, &Demo.data);
    const empty = try render(a, &p);
    try testing.expect(std.mem.find(u8, empty, "Choose your pool") != null);
    try testing.expect(std.mem.find(u8, empty, "c-slots") == null);
    // By role, top: the mains Darius, Mundo, Jax, then Fiora, Garen, Teemo, Yone by name
    try testing.expectEqual(7, std.mem.count(u8, empty, "class=\"pk\""));
    try testing.expect(std.mem.find(u8, empty, "Add Darius").? < std.mem.find(u8, empty, "Add Fiora").?);

    // Older links: ids alone, each in its main role; a letter picks the role
    p.fromUrl(link("40-2-999-2-3j-1m-4"));
    try testing.expectEqualStrings("2t-4t-40j-3j-1m", try urlOf(a, &p));
    // Ahri has no lanes in top: still kept, in top (the link asked for it)
    p.fromUrl(link("30t-1t-2t-3t-4t-10t-20t-11t-11m-40j-1j-2j"));
    try testing.expectEqual(max, p.n);
    try testing.expect(std.mem.find(u8, try render(a, &p), "Add champions") == null);
    p.fromUrl(.{});
    try testing.expectEqual(0, p.n);
}

test "pool page: the tab's role for its icons, the main role for a search, history and storage" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p: Page = try .init(a, &Demo.data);
    var ev: tree.Event = .{ .kind = .click };
    p.update(.{ .role = .jungle }, &ev);
    try testing.expect(!ev.push and !p.dirty);
    // Jungle: Vi (main), then Mundo and Jax by name
    const jungle = try render(a, &p);
    try testing.expectEqual(3, std.mem.count(u8, jungle, "class=\"pk\""));
    p.update(.{ .add = 3 }, &ev);
    try testing.expect(ev.push and p.dirty);
    p.search.chosen = 3; // Fiora
    p.update(.picked, &ev);
    try testing.expectEqualStrings("10t-3j", try urlOf(a, &p));
    // Jax in jungle is in the pool: off jungle's icons, still on top's
    try testing.expect(std.mem.find(u8, try render(a, &p), "Add Jax") == null);
    p.update(.{ .role = .top }, &ev);
    try testing.expect(std.mem.find(u8, try render(a, &p), "Add Jax") != null);
    p.update(.{ .remove = 0 }, &ev);
    try testing.expectEqualStrings("3j", try urlOf(a, &p));
}
