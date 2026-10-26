//! Practice on the app's page (private edition only): the page's changes to the poller's
//! practice setup (src/practice.zig), as the dvui window's desktop/private/practice.zig
//! makes them, and the Data behind ui-practice.wasm (practice.bin). Messages come from
//! a page that shows the client's text, so each is checked, never trusted

const std = @import("std");
const ui = @import("ui");
const desktop = @import("desktop");
const screens = @import("screens.zig");
const core = desktop.core;
const poller = desktop.poller;
const practice = desktop.practice;
const state = desktop.state;
const Msg = ui.toshell.Practice;
const Role = core.Role;
const Allocator = std.mem.Allocator;

/// The header's button shows: stats to practise with, and no champ select or game of
/// the client's own on screen unless practice is already on
pub fn offered(edition: state.Edition, stats: ?*const core.Stats, setup: ?practice.Setup, status: state.Status) bool {
    if (edition != .private or stats == null) return false;
    return setup != null or switch (status) {
        .select, .loading, .in_game, .post_game => false,
        else => true,
    };
}

/// `entropy` seeds a random draft. False when nothing changed
pub fn edit(m: Msg, entropy: u64) bool {
    const s = poller.lock();
    defer poller.unlock();
    if (m == .on and m.on and !offered(s.edition, s.stats, s.practice.*, s.status)) return false;
    if (!apply(s.practice, s.stats, m, entropy)) return false;
    s.practice_changed();
    return true;
}

/// False when `m` changed nothing or doesn't fit
fn apply(setup: *?practice.Setup, stats: ?*const core.Stats, m: Msg, entropy: u64) bool {
    const st = stats orelse return false;
    if (m == .on) {
        if (m.on == (setup.* != null)) return false;
        setup.* = if (m.on) .{} else null;
        return true;
    }
    const x = if (setup.*) |*x| x else return false;
    switch (m) {
        .on => unreachable,
        .set => |v| switch (v) {
            .screen => |i| x.screen = nth(practice.Screen, i) orelse return false,
            .stage => |i| x.stage = nth(practice.Stage, i) orelse return false,
            .role => |i| {
                // My champion stays mine in the new role; that role's ally takes my old one
                const r = nth(Role, i) orelse return false;
                std.mem.swap(practice.Seat, &x.mine[@backingInt(x.role)], &x.mine[@backingInt(r)]);
                x.role = r;
            },
            .pick => |i| x.pick = if (i < 5) @intCast(i) else return false,
            .minute => |i| x.minute = if (i < ui.practice.minutes.len) ui.practice.minutes[i] else return false,
            .lead => |i| x.lead = nth(practice.Lead, i) orelse return false,
            .win => |w| x.win = w,
        },
        .random => {
            var prng: std.Random.DefaultPrng = .init(entropy);
            x.randomise(st, prng.random());
        },
        .clear => x.clear(),
        .place => |p| {
            if (p.champion != 0 and st.index(p.champion) == null) return false;
            x.place(target(p.at) orelse return false, p.champion, p.locked);
        },
        .take => |c| {
            if (st.index(c) == null) return false;
            const seat = x.mine[@backingInt(x.role)];
            x.place(.{ .ally = x.role }, c, seat.champion == c and !seat.locked);
        },
        .ban => |c| {
            if (st.index(c) == null) return false;
            x.place(.{ .my_ban = x.pick }, c, true);
        },
    }
    return true;
}

fn nth(comptime E: type, i: u8) ?E {
    const all = std.enums.values(E);
    return if (i < all.len) all[i] else null;
}

fn target(t: ui.toshell.Target) ?practice.Target {
    return switch (t) {
        .ally => |i| .{ .ally = nth(Role, i) orelse return null },
        inline else => |i, tag| if (i < 5) @unionInit(practice.Target, @tagName(tag), @intCast(i)) else null,
    };
}

/// What ui-practice.wasm shows for `setup`; `shown` false while the client's own champ
/// select or game is on screen
pub fn data(a: Allocator, c: screens.Ctx, setup: practice.Setup, shown: bool) !ui.practice.Data {
    var d: ui.practice.Data = .{
        .seq = 0,
        .shown = shown,
        .screen = @fromBackingInt(@backingInt(setup.screen)),
        .stage = @fromBackingInt(@backingInt(setup.stage)),
        .role = ui.role.Role.all[@backingInt(setup.role)],
        .pick = setup.pick,
        .minute = setup.minute,
        .lead = @fromBackingInt(@backingInt(setup.lead)),
        .win = setup.win,
    };
    for (&d.my_bans, setup.my_bans) |*x, id| x.* = try c.champ(a, id);
    for (&d.their_bans, setup.their_bans) |*x, id| x.* = try c.champ(a, id);
    const st = c.stats orelse return d;
    const n = st.ids.len;
    const order = try a.alloc(u16, n);
    for (order, 0..) |*o, i| o.* = @intCast(i);
    std.mem.sort(u16, order, st, moreGames);
    const champs = try a.alloc(ui.practice.Pick, n);
    for (champs, order) |*x, i| x.* = .{ .id = st.ids[i], .champ = (try c.champ(a, st.ids[i])).? };
    d.champs = champs;
    for (&d.by_role, Role.all) |*out, r| {
        const by = try a.alloc(u16, n);
        for (by, 0..) |*o, i| o.* = @intCast(i);
        std.mem.sort(u16, by, ByRole{ .st = st, .role = r, .order = order }, ByRole.more);
        out.* = by;
    }
    return d;
}

fn moreGames(st: *const core.Stats, x: u16, y: u16) bool {
    return st.champGames(x) > st.champGames(y);
}

/// Indexes into the picker's list (`order`, stats indexes) by games in `role`
const ByRole = struct {
    st: *const core.Stats,
    role: Role,
    order: []const u16,

    fn more(b: ByRole, x: u16, y: u16) bool {
        return b.st.champRole(b.role, b.order[x]).games > b.st.champRole(b.role, b.order[y]).games;
    }
};

const testing = std.testing;

test "apply: what the page sends is checked, then changes the setup as the window's bar" {
    var f = try screens.fixture();
    defer f.deinit();
    const st = &f.stats;
    var setup: ?practice.Setup = null;
    try testing.expect(!apply(&setup, st, .{ .take = 103 }, 0));
    try testing.expect(apply(&setup, st, .{ .on = true }, 0));
    try testing.expect(!apply(&setup, st, .{ .on = true }, 0));
    // A lane option: a hover, locked on the second click
    try testing.expect(apply(&setup, st, .{ .take = 103 }, 0));
    try testing.expect(!setup.?.mine[2].locked);
    try testing.expect(apply(&setup, st, .{ .take = 103 }, 0));
    try testing.expect(setup.?.mine[2].locked);
    // My champion goes with me to the new role
    try testing.expect(apply(&setup, st, .{ .set = .{ .role = 0 } }, 0));
    try testing.expectEqual(.top, setup.?.role);
    try testing.expectEqual(103, setup.?.mine[0].champion);
    try testing.expect(apply(&setup, st, .{ .set = .{ .minute = 3 } }, 0));
    try testing.expectEqual(20, setup.?.minute);
    try testing.expect(apply(&setup, st, .{ .ban = 134 }, 0));
    try testing.expectEqual(134, setup.?.my_bans[setup.?.pick]);
    try testing.expect(apply(&setup, st, .{ .place = .{ .at = .{ .their_ban = 4 }, .champion = 3, .locked = true } }, 0));
    try testing.expectEqual(3, setup.?.their_bans[4]);
    for ([_]Msg{
        .{ .place = .{ .at = .{ .enemy = 0 }, .champion = 999, .locked = true } },
        .{ .place = .{ .at = .{ .enemy = 5 }, .champion = 103, .locked = true } },
        .{ .set = .{ .pick = 5 } },
        .{ .set = .{ .minute = 7 } },
        .{ .set = .{ .screen = 4 } },
        .{ .take = 0 },
    }) |bad| try testing.expect(!apply(&setup, st, bad, 0));
    try testing.expect(apply(&setup, st, .{ .on = false }, 0));
    try testing.expect(setup == null);
}

test "data: the setup as ui-practice.wasm reads it, champions most played first" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var f = try screens.fixture();
    defer f.deinit();
    var setup: practice.Setup = .{ .role = .bottom, .screen = .post, .lead = .ahead };
    setup.their_bans[1] = 134;
    const d = try data(a, .{ .stats = &f.stats, .icons = null, .private = true }, setup, false);
    try testing.expect(!d.shown);
    try testing.expectEqual(.bot, d.role);
    try testing.expectEqual(.post, d.screen);
    try testing.expectEqual(.ahead, d.lead);
    try testing.expectEqualStrings("Syndra", d.their_bans[1].?.name);
    try testing.expectEqual(null, d.my_bans[0]);
    try testing.expectEqual(3, d.champs.len);
    // Galio has no games: last overall and in mid
    try testing.expectEqualStrings("Galio", d.champs[2].champ.name);
    try testing.expectEqualStrings("Galio", d.champs[d.by_role[2][2]].champ.name);
    var bin: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, ui.practice.Data, d, &bin);
    try testing.expectEqualStrings("Syndra", (try ui.data.decode(a, ui.practice.Data, bin.items)).their_bans[1].?.name);
}
