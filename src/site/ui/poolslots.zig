//! PoolSlots: a player's champion pool as a band of slots, main first (marked), each
//! removable, then an empty Add slot while there's room that opens the host's picker.
//! The pool page's head; the desktop's pool editor next
const std = @import("std");
const tree = @import("tree.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "PoolSlots";
pub const scope = .{".c-slots"};

const W = struct {
    pub const pool = plain("Your pool");
    pub const main = plain("main");
    pub const add = plain("Add");
    pub const remove = phrase.Phrase("Remove {c:text}");
};

pub const Slot = struct {
    champ: champ.Champ,
    /// The role it's played in, a corner badge
    role: ?role.Role = null,
    on_remove: ?tree.Handler = null,
};

pub const Pool = struct {
    /// The main first
    slots: []const Slot,
    max: u8 = 5,
    /// The Add slot, shown while there's room; null: none
    on_add: ?tree.Handler = null,
};

pub fn view(h: *H, p: Pool) N {
    var ms = h.list();
    for (p.slots, 0..) |s, i| ms.add(h.span(.{ .key = i, .class = "m" }, .{
        champ.view(h, s.champ, .{ .px = .@"32", .named = false, .role = s.role }),
        h.b(.{}, .{s.champ.name}),
        if (i == 0) h.small(.{}, .{W.main}) else null,
        if (s.on_remove) |on| h.button(.{
            .type = "button",
            .aria_label = W.remove.with(h, .{ .c = s.champ.name }),
            .on_click = on,
        }, .{"×"}) else null,
    }));
    const add: ?N = if (p.on_add != null and p.slots.len < p.max) h.button(.{
        .key = 100,
        .type = "button",
        .class = "add",
        .on_click = p.on_add,
    }, .{ champ.view(h, null, .{ .px = .@"32" }), W.add }) else null;
    return h.div(.{ .class = "c-slots" }, .{ h.span(.{ .class = "lab" }, .{W.pool}), ms.done(), add });
}

pub const css =
    \\@layer components {
    \\  .c-slots { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); min-width: 0; }
    \\  .c-slots > .lab { margin-right: var(--sp-1); font-size: var(--fs-xs); font-weight: var(--w-m);
    \\    text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); }
    \\  .c-slots .m { display: inline-flex; align-items: center; gap: var(--sp-2); min-width: 0; max-width: 100%;
    \\    height: 44px; box-sizing: border-box; padding: 0 var(--sp-1) 0 5px; border: 1px solid var(--sel-line);
    \\    border-radius: var(--r-ctl); background: var(--sel-bg); color: var(--sel-ink); }
    \\  .c-slots .m > b { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-slots .m > small { font-size: var(--fs-xs); color: var(--muted); }
    \\  .c-slots .m > button { all: unset; display: grid; place-items: center; width: 24px; height: 24px;
    \\    border-radius: var(--r-ctl); color: var(--t2); font-size: var(--fs-l); cursor: pointer; }
    \\  .c-slots .m > button:hover { background: var(--ctl-bg-2); color: var(--text); }
    \\  .c-slots :is(.m > button, .add):focus-visible { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\  .c-slots .add { all: unset; display: inline-flex; align-items: center; gap: var(--sp-2); height: 44px;
    \\    box-sizing: border-box; padding: 0 12px 0 5px; border: 1.5px dashed var(--line-2);
    \\    border-radius: var(--r-ctl); color: var(--muted); font-size: var(--fs-s); cursor: pointer; }
    \\  .c-slots .add:hover { color: var(--text); background: var(--ctl-bg-2); }
    \\  .c-slots .add > .c-champ { border: 0; background: var(--panel-3); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const Inert = struct {
        pub const Msg = u8;
        pub fn update(_: *@This(), _: u8, _: *tree.Event) void {}
        var it: @This() = .{};
    };
    const on = h.on(&Inert.it, 0);
    const ornn: Slot = .{ .champ = champ.demo("Ornn", "Ornn"), .role = .top, .on_remove = on };
    const three = [_]Slot{
        ornn,
        .{ .champ = champ.demo("Sion", "Sion"), .role = .top, .on_remove = on },
        .{ .champ = champ.demo("DrMundo", "Dr. Mundo"), .role = .top, .on_remove = on },
    };
    g.add("a main", view(h, .{ .slots = &.{ornn}, .on_add = on }));
    g.add("three, room for more", view(h, .{ .slots = &three, .on_add = on }));
    const five = three ++ [_]Slot{
        .{ .champ = champ.demo("Jax", "Jax"), .role = .jungle, .on_remove = on },
        .{ .champ = champ.demo("Garen", "Garen"), .role = .top, .on_remove = on },
    };
    g.add("full: no Add slot", view(h, .{ .slots = &five, .on_add = on }));
}

const testing = std.testing;

test "pool slots: main marked, a remove each, Add only while there's room" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const Host = struct {
        pub const Msg = u8;
        pub fn update(_: *@This(), _: u8, _: *tree.Event) void {}
    };
    var host: Host = .{};
    const on = h.on(&host, 0);
    const two = [_]Slot{
        .{ .champ = .{ .name = "Ornn", .src = "" }, .on_remove = on },
        .{ .champ = .{ .name = "Sion", .src = "" }, .on_remove = on },
    };
    var w: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, view(&h, .{ .slots = &two, .on_add = on }), &w.writer);
    const out = w.written();
    try testing.expectEqual(1, std.mem.count(u8, out, "<small>main</small>"));
    try testing.expect(std.mem.find(u8, out, "aria-label=\"Remove Sion\"") != null);
    try testing.expectEqual(1, std.mem.count(u8, out, "class=\"add\""));

    w.clearRetainingCapacity();
    try @import("html.zig").write(&t, view(&h, .{ .slots = &two, .max = 2, .on_add = on }), &w.writer);
    try testing.expectEqual(0, std.mem.count(u8, w.written(), "class=\"add\""));

    // Empty: the Add slot alone
    w.clearRetainingCapacity();
    try @import("html.zig").write(&t, view(&h, .{ .slots = &.{}, .on_add = on }), &w.writer);
    try testing.expectEqual(1, std.mem.count(u8, w.written(), "class=\"add\""));
    try testing.expectEqual(0, std.mem.count(u8, w.written(), "<small>"));
}
