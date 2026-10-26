//! ChampRolePicker: a champion and the role it plays. ChampSearch in pick mode, then the
//! five roles as a compact RolePicker once a champion is taken, its main role (the
//! entry's first) preselected and roles it has no games in disabled. The host reads
//! `pick` when `on_pick` fires (a champion taken, a role changed or the champion
//! cleared). `Pair`: two of them with a swap between (the matchup finder)
const std = @import("std");
const tree = @import("tree.zig");
const role = @import("role.zig");
const rolepicker = @import("rolepicker.zig");
const champsearch = @import("champsearch.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;
const Role = role.Role;
const ChampSearch = champsearch.ChampSearch;

pub const name = "ChampRolePicker";
pub const scope = .{ ".c-crp", ".c-crp-pair" };

const W = struct {
    pub const roles = phrase.Phrase("{c:text} roles");
    pub const swap = plain("Swap");
    pub const vs = plain("vs");
};

pub const Pick = struct { e: u16, role: Role };

pub const ChampRolePicker = struct {
    /// Its mode is set to pick
    search: ChampSearch,
    role: ?Role = null,
    on_pick: ?tree.Handler = null,

    const S = @This();

    pub const Msg = union(enum) { picked, role: Role };

    pub fn update(s: *S, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .picked => s.role = if (s.search.chosen) |e| mainRole(s.search.index.entries[e].roles, s.role) else null,
            .role => |r| {
                if (s.search.chosen == null) return;
                s.role = r;
                ev.push = true;
            },
        }
        if (s.on_pick) |hd| hd.call(hd.target, &hd.msg, ev);
    }

    /// The champion and its role; null until both are chosen
    pub fn pick(s: *const S) ?Pick {
        return .{ .e = s.search.chosen orelse return null, .role = s.role orelse return null };
    }

    /// Back to an empty search (a host that took the pick)
    pub fn reset(s: *S) void {
        s.search.chosen = null;
        s.role = null;
    }

    pub fn view(s: *S, h: *H) N {
        s.search.mode = .pick;
        s.search.on_pick = h.on(s, .picked);
        const e = s.search.chosen orelse return h.div(.{ .class = "c-crp" }, .{s.search.view(h)});
        const entry = &s.search.index.entries[e];
        var items: [Role.all.len]rolepicker.Item = undefined;
        for (Role.all, &items) |r, *it| it.* = .{
            .role = r,
            .current = s.role == r,
            .disabled = entry.roles.len > 0 and std.mem.findScalar(Role, entry.roles, r) == null,
            .on = h.on(s, .{ .role = r }),
        };
        return h.div(.{ .class = "c-crp" }, .{
            s.search.view(h),
            rolepicker.view(h, .{ .v = .compact, .label = W.roles.with(h, .{ .c = entry.name }) }, &items),
        });
    }
};

/// `roles`' first (the main role); `keep` when the champion plays it too
fn mainRole(roles: []const Role, keep: ?Role) ?Role {
    if (keep) |k| if (std.mem.findScalar(Role, roles, k) != null) return k;
    return if (roles.len > 0) roles[0] else keep orelse .top;
}

/// Two pickers, one against the other, with a swap between
pub const Pair = struct {
    a: ChampRolePicker,
    b: ChampRolePicker,
    /// Fired after a swap, as each picker's on_pick is
    on_swap: ?tree.Handler = null,

    const P = @This();

    pub const Msg = enum { swap };

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .swap => {
                std.mem.swap(?u16, &p.a.search.chosen, &p.b.search.chosen);
                std.mem.swap(?Role, &p.a.role, &p.b.role);
                ev.push = true;
            },
        }
        if (p.on_swap) |hd| hd.call(hd.target, &hd.msg, ev);
    }

    pub fn view(p: *P, h: *H) N {
        const empty = p.a.search.chosen == null and p.b.search.chosen == null;
        return h.div(.{ .class = "c-crp-pair" }, .{
            p.a.view(h),
            h.button(.{
                .type = "button",
                .class = "sw",
                .aria_label = W.swap,
                .title = W.swap,
                .disabled = empty,
                .on_click = h.on(p, .swap),
            }, .{"⇄"}),
            p.b.view(h),
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-crp { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-crp > .c-search { flex: 1 1 200px; width: auto; }
    \\  .c-crp > .c-search:has(> .c-chosen) { flex: 0 1 auto; }
    \\  .c-crp-pair { container-type: inline-size; display: grid; grid-template-columns: 1fr auto 1fr;
    \\    align-items: center; gap: var(--sp-2); }
    \\  .c-crp-pair > .sw { all: unset; display: grid; place-items: center; width: var(--ctl); height: var(--ctl);
    \\    border-radius: var(--r-ctl); color: var(--t2); font-size: var(--fs-l); cursor: pointer;
    \\    box-shadow: inset 0 0 0 1px var(--ctl-line); }
    \\  .c-crp-pair > .sw:hover { background: var(--ctl-bg-2); color: var(--text); }
    \\  .c-crp-pair > .sw:focus-visible { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-crp-pair > .sw:disabled { opacity: 0.35; cursor: default; background: none; }
    \\  @container (max-width: 520px) {
    \\    .c-crp-pair { grid-template-columns: 1fr; justify-items: start; }
    \\    .c-crp-pair > .sw { transform: rotate(90deg); }
    \\  }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const ix = h.mem.create(champsearch.Index) catch {
        h.oom = true;
        return;
    };
    ix.* = champsearch.Index.init(h.mem, &champsearch.Demo.entries) catch {
        h.oom = true;
        return;
    };
    const one = [_]struct { []const u8, ?u16, ?Role }{
        .{ "empty", null, null },
        .{ "taken: its main role chosen, roles without games off", 3, .top },
        .{ "another of its roles", 3, .jungle },
    };
    for (one, 0..) |st, i| {
        const s = h.mem.create(ChampRolePicker) catch {
            h.oom = true;
            return;
        };
        s.* = .{ .search = .{ .index = ix, .id = h.fmt("{s}-{d}", .{ g.id("crp"), i }) }, .role = st[2] };
        s.search.chosen = st[1];
        g.add(st[0], s.view(h));
    }
    const pairs = [_]struct { []const u8, ?u16, ?u16 }{
        .{ "pair, empty", null, null },
        .{ "pair: a matchup", 12, 18 },
    };
    for (pairs, 0..) |st, i| {
        const p = h.mem.create(Pair) catch {
            h.oom = true;
            return;
        };
        p.* = .{
            .a = .{ .search = .{ .index = ix, .id = h.fmt("{s}-{d}a", .{ g.id("crpp"), i }) }, .role = if (st[1] != null) .top else null },
            .b = .{ .search = .{ .index = ix, .id = h.fmt("{s}-{d}b", .{ g.id("crpp"), i }) }, .role = if (st[2] != null) .top else null },
        };
        p.a.search.chosen = st[1];
        p.b.search.chosen = st[2];
        g.add(st[0], p.view(h));
    }
}

const testing = std.testing;

const Host = struct {
    picks: u32 = 0,
    pub const Msg = enum { got };
    pub fn update(x: *Host, _: Msg, _: *tree.Event) void {
        x.picks += 1;
    }
};

test "taking a champion picks its main role; roles change it; clear and swap" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const ix = try champsearch.Index.init(a, &champsearch.Demo.entries);
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var host: Host = .{};
    var p: Pair = .{
        .a = .{ .search = .{ .index = &ix, .id = "a" }, .on_pick = h.on(&host, .got) },
        .b = .{ .search = .{ .index = &ix, .id = "b" }, .on_pick = h.on(&host, .got) },
    };
    _ = p.view(&h);
    try testing.expect(p.a.pick() == null);

    var ev: tree.Event = .{ .kind = .click };
    // Dr. Mundo: top, jungle
    p.a.search.update(.{ .pick = 3 }, &ev);
    try testing.expectEqual(Pick{ .e = 3, .role = .top }, p.a.pick().?);
    try testing.expectEqual(1, host.picks);

    _ = p.view(&h);
    p.a.update(.{ .role = .jungle }, &ev);
    try testing.expectEqual(Role.jungle, p.a.pick().?.role);
    try testing.expectEqual(2, host.picks);

    // A new champion: its own main role
    _ = p.view(&h);
    p.a.search.update(.clear, &ev);
    try testing.expect(p.a.pick() == null);
    p.a.search.update(.{ .pick = 13 }, &ev);
    try testing.expectEqual(Pick{ .e = 13, .role = .jungle }, p.a.pick().?);
    p.b.search.update(.{ .pick = 0 }, &ev);
    try testing.expectEqual(Pick{ .e = 0, .role = .mid }, p.b.pick().?);

    p.update(.swap, &ev);
    try testing.expectEqual(Pick{ .e = 0, .role = .mid }, p.a.pick().?);
    try testing.expectEqual(Pick{ .e = 13, .role = .jungle }, p.b.pick().?);

    p.a.reset();
    try testing.expect(p.a.pick() == null);
}
