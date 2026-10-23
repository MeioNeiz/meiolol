//! Practice in the window (practice.zig): a bar to set up a champ select by hand (role,
//! pick place, stage, screen, a random draft) and a champion picker for any seat or ban.
//! The poller builds what shows from the setup; a real champ select or game takes over
//! until it ends. In practice seats open the picker, a lane option hovers it as my pick
//! (a second click locks it), an ally's idea fills their seat, a ban option is my ban.

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const practice = @import("../practice.zig");
const w = @import("widgets.zig");
const Role = core.Role;
const Target = practice.Target;
const palette = w.palette;

/// The poller's side, for the frame
pub const Hook = struct {
    /// Null while practice is off; held under the poller's mutex during the frame
    setup: *?practice.Setup,
    /// The status shown is practice's, not the client's
    shown: bool,
    changed: *const fn () void,
};

var hook: ?Hook = null;
/// The seat or ban the picker is open for
var target: ?Target = null;
var lock_in = true;
var seed: u64 = 0;

/// Each frame, before anything draws
pub fn begin(h: ?Hook) void {
    hook = h;
    if (!editing()) target = null;
}

/// Practice shows: seats and options take clicks
pub fn editing() bool {
    const h = hook orelse return false;
    return h.shown and h.setup.* != null;
}

fn setup() *practice.Setup {
    return &hook.?.setup.*.?;
}

fn changed() void {
    hook.?.changed();
}

pub fn open(t: Target) void {
    target = t;
}

pub fn close() void {
    target = null;
}

/// A lane option clicked: hovered as my pick, locked when it already was
pub fn take(champion: u32) void {
    const s = setup();
    const seat = s.mine[@backingInt(s.role)];
    s.place(.{ .ally = s.role }, champion, seat.champion == champion and !seat.locked);
    changed();
}

pub fn fill(t: Target, champion: u32) void {
    setup().place(t, champion, true);
    changed();
}

/// My ban, in my cell's place
pub fn ban(champion: u32) void {
    fill(.{ .my_ban = setup().pick }, champion);
}

/// The header's button: on, or off again
pub fn toggle(src: std.builtin.SourceLocation) void {
    const h = hook orelse return;
    const on = h.setup.* != null;
    if (dvui.button(src, if (on) "End practice" else "Practice", .{}, .{
        .gravity_y = 0.5,
        .style = if (on) .highlight else .control,
        .margin = .{ .x = 8 },
    })) {
        h.setup.* = if (on) null else .{};
        h.changed();
    }
}

/// The practice controls, under the header while practice is on
pub fn bar(ctx: w.Ctx) void {
    const h = hook orelse return;
    if (h.setup.* == null) return;
    var box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = palette.private.opacity(0.18) },
        .padding = .{ .x = 14, .y = 6, .w = 14, .h = 6 },
    });
    defer box.deinit();
    if (!h.shown) {
        w.para(@src(), "Practice waits while the client is in champ select or a game.", .{}, .{ .small = true });
        return;
    }
    const s = setup();
    {
        var fb = dvui.flexbox(@src(), .{ .justify_content = .start }, .{ .expand = .horizontal });
        defer fb.deinit();
        if (choice(@src(), "Screen", &.{ "Champ select", "Loading", "In game", "Post game" }, @backingInt(s.screen))) |i| {
            s.screen = @fromBackingInt(@intCast(i));
            changed();
        }
        if (s.screen == .select) {
            if (choice(@src(), "Stage", &.{ "Planning", "Bans", "Picks", "Finalising" }, @backingInt(s.stage))) |i| {
                s.stage = @fromBackingInt(@intCast(i));
                changed();
            }
        }
        if (choice(@src(), "Role", &.{ "Top", "Jungle", "Mid", "Bot", "Support" }, @backingInt(s.role))) |i| {
            // My champion stays mine in the new role; that role's ally takes my old one
            std.mem.swap(practice.Seat, &s.mine[@backingInt(s.role)], &s.mine[i]);
            s.role = @fromBackingInt(@intCast(i));
            changed();
        }
        if (choice(@src(), "Pick", &.{ "1", "2", "3", "4", "5" }, s.pick)) |i| {
            s.pick = @intCast(i);
            changed();
        }
        if (dvui.button(@src(), "Random draft", .{}, .{ .gravity_y = 0.5, .margin = .{ .x = 4, .y = 2, .w = 4, .h = 2 } })) {
            seed +%= 1;
            var prng: std.Random.DefaultPrng = .init(seed ^ @as(u64, @truncate(@as(u128, @bitCast(dvui.frameTimeNS())))));
            s.randomise(ctx.stats, prng.random());
            changed();
        }
        if (dvui.button(@src(), "Clear", .{}, .{ .gravity_y = 0.5, .margin = .{ .x = 4, .y = 2, .w = 4, .h = 2 } })) {
            s.clear();
            changed();
        }
    }
    switch (s.screen) {
        .select => {
            banRow(ctx, s);
            w.para(@src(), "Click a seat or ban to fill it; a lane option hovers it as your pick, a second click locks it.", .{}, .{ .muted = true, .small = true });
        },
        .loading => {},
        .game, .post => {
            var fb = dvui.flexbox(@src(), .{ .justify_content = .start }, .{ .expand = .horizontal });
            defer fb.deinit();
            const minutes = [_]u8{ 5, 10, 15, 20, 25, 30, 35 };
            const at = std.mem.indexOfScalar(u8, &minutes, s.minute) orelse 2;
            if (choice(@src(), "Minute", &.{ "5", "10", "15", "20", "25", "30", "35" }, at)) |i| {
                s.minute = minutes[i];
                changed();
            }
            if (choice(@src(), "Your team", &.{ "Behind", "Even", "Ahead" }, @backingInt(s.lead))) |i| {
                s.lead = @fromBackingInt(@intCast(i));
                changed();
            }
            if (s.screen == .post) if (choice(@src(), "Result", &.{ "Win", "Loss" }, @intFromBool(!s.win))) |i| {
                s.win = i == 0;
                changed();
            };
        },
    }
}

/// Ten ban places, mine first; each opens the picker
fn banRow(ctx: w.Ctx, s: *const practice.Setup) void {
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .margin = .{ .y = 2 } });
    defer row.deinit();
    dvui.labelNoFmt(@src(), "Bans", .{}, .{ .font = w.small(), .gravity_y = 0.5, .padding = .{ .w = 8 } });
    for (0..10) |i| {
        if (i == 5) _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 14 } });
        const t: Target = if (i < 5) .{ .my_ban = @intCast(i) } else .{ .their_ban = @intCast(i - 5) };
        const c = if (i < 5) s.my_bans[i] else s.their_bans[i - 5];
        var tile = dvui.box(@src(), .{}, .{ .id_extra = i, .margin = .{ .w = 3 } });
        w.champIcon(@src(), ctx, c, .{ .size = 28, .crossed = c != 0, .border = (if (i < 5) palette.ally else palette.enemy).opacity(0.6) });
        if (dvui.clicked(tile.data(), .{})) open(t);
        tile.deinit();
    }
}

/// "Label [a][b][c]": the one clicked, if it changed
fn choice(src: std.builtin.SourceLocation, label: []const u8, names: []const []const u8, current: usize) ?usize {
    var row = dvui.box(src, .{ .dir = .horizontal }, .{ .margin = .{ .w = 14, .y = 2, .h = 2 } });
    defer row.deinit();
    dvui.labelNoFmt(@src(), label, .{}, .{ .font = w.small(), .gravity_y = 0.5, .color_text = .{ .color = w.text().opacity(0.7) }, .padding = .{ .w = 6 } });
    var out: ?usize = null;
    for (names, 0..) |name, i| {
        if (dvui.button(@src(), name, .{}, .{
            .id_extra = i,
            .style = if (i == current) .highlight else .control,
            .corners = .all(0),
            .margin = .{},
            .padding = .{ .x = 8, .y = 3, .w = 8, .h = 3 },
            .font = w.small(),
        }) and i != current) out = i;
    }
    return out;
}

/// The champion picker, over everything while open
pub fn picker(ctx: w.Ctx) void {
    const t = target orelse return;
    var open_flag = true;
    var fw = dvui.floatingWindow(@src(), .{ .modal = true, .open_flag = &open_flag }, .{
        .min_size_content = .{ .w = 560, .h = 480 },
        .max_size_content = .size(.{ .w = 560, .h = 480 }),
    });
    defer fw.deinit();
    var title_buf: [48]u8 = undefined;
    fw.dragAreaSet(dvui.windowHeader(title(&title_buf, t), "", &open_flag));

    const ally = t == .ally;
    var query: []const u8 = "";
    var enter = false;
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .padding = .all(6) });
        defer row.deinit();
        var te = dvui.textEntry(@src(), .{ .placeholder = "Search champions" }, .{ .expand = .horizontal });
        if (dvui.firstFrame(te.data().id)) dvui.focusWidget(te.data().id, null, null);
        query = te.getText();
        enter = te.enter_pressed;
        te.deinit();
        if (ally) _ = dvui.checkbox(@src(), &lock_in, "Lock in", .{ .gravity_y = 0.5, .margin = .{ .x = 8 } });
        if (dvui.button(@src(), "Empty", .{}, .{ .gravity_y = 0.5, .margin = .{ .x = 8 } })) {
            setup().place(t, 0, false);
            changed();
            target = null;
            return;
        }
    }

    var list: [512]u32 = undefined;
    const found = candidates(ctx, t, query, &list);
    if (enter and found.len > 0) return choose(t, found[0], ally);
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();
    var fb = dvui.flexbox(@src(), .{ .justify_content = .start }, .{ .expand = .horizontal, .padding = .all(4) });
    defer fb.deinit();
    for (found, 0..) |c, i| {
        var tile = dvui.box(@src(), .{ .dir = .vertical }, .{
            .id_extra = i,
            .min_size_content = .{ .w = 76 },
            .max_size_content = .width(76),
            .padding = .all(4),
            .corners = .all(6),
        });
        {
            // The icon centres itself vertically: its own box keeps the name under it
            var icon = dvui.box(@src(), .{}, .{ .gravity_x = 0.5 });
            defer icon.deinit();
            w.champIcon(@src(), ctx, c, .{ .size = 44 });
        }
        dvui.labelNoFmt(@src(), ctx.stats.nameOf(c), .{}, .{ .font = w.tiny(), .gravity_x = 0.5, .padding = .{ .y = 2 } });
        const hit = dvui.clicked(tile.data(), .{});
        tile.deinit();
        if (hit) return choose(t, c, ally);
    }
    if (!open_flag) target = null;
}

fn choose(t: Target, champion: u32, ally: bool) void {
    setup().place(t, champion, !ally or lock_in);
    changed();
    target = null;
}

fn title(buf: []u8, t: Target) []const u8 {
    return switch (t) {
        .ally => |r| std.fmt.bufPrint(buf, "Your team: {s}", .{w.roleName(r)}),
        .enemy => |i| std.fmt.bufPrint(buf, "Enemy seat {d}", .{@as(u8, i) + 1}),
        .my_ban => "Your team's ban",
        .their_ban => "Enemy team's ban",
    } catch "Pick a champion";
}

/// Champions matching `query` (any case, anywhere in the name), most played first: in
/// the seat's role for allies, overall otherwise
fn candidates(ctx: w.Ctx, t: Target, query: []const u8, out: []u32) []const u32 {
    const stats = ctx.stats;
    var n: usize = 0;
    for (stats.names, stats.ids) |name, id| {
        if (n == out.len) break;
        if (query.len > 0 and std.ascii.findIgnoreCase(name, query) == null) continue;
        out[n] = id;
        n += 1;
    }
    const By = struct {
        stats: *const core.Stats,
        role: ?Role,
        fn games(b: @This(), id: u32) u64 {
            const c = b.stats.index(id) orelse return 0;
            return if (b.role) |r| b.stats.champRole(r, c).games else b.stats.champGames(c);
        }
        fn more(b: @This(), x: u32, y: u32) bool {
            return b.games(x) > b.games(y);
        }
    };
    const by: By = .{ .stats = stats, .role = if (t == .ally) t.ally else null };
    std.mem.sort(u32, out[0..n], by, By.more);
    return out[0..n];
}
