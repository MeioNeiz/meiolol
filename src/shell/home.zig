//! The lobby's tiles (ui/apphome.zig) from the app's stats and the poller's mastery top:
//! each role's best now and the best role of each mastery champion, smoothed win rates
//! as the site's stats pages give them

const std = @import("std");
const ui = @import("ui");
const desktop = @import("desktop");
const core = desktop.core;
const me = desktop.lcu.me;
const screens = @import("screens.zig");
const Allocator = std.mem.Allocator;

/// A champion in a role counts with at least 1 in this many of the stats' games
const min_share = 200;

pub fn view(a: Allocator, c: screens.Ctx, f: ?*const me.Form) !ui.apphome.Home {
    const stats = c.stats orelse return .{ .private = c.private };
    const floor = stats.games / min_share;
    var best: std.ArrayList(ui.apphome.Pick) = .empty;
    for (core.Role.all) |r| {
        var top: ?Best = null;
        for (0..stats.n) |i| top = better(top, rate(stats, floor, i, r));
        if (top) |x| if (try pick(a, c, stats, x)) |p| try best.append(a, p);
    }
    var pool: std.ArrayList(ui.apphome.Pick) = .empty;
    if (f) |form| for (form.mastery()) |m| {
        const i = stats.index(m.champion) orelse continue;
        var top: ?Best = null;
        for (core.Role.all) |r| top = better(top, rate(stats, floor, i, r));
        if (top) |x| if (try pick(a, c, stats, x)) |p| try pool.append(a, p);
    };
    const scope = if (stats.patch.len > 0) try a.print("{s}, {s}", .{ c.region, stats.patch }) else c.region;
    return .{ .scope = scope, .pool = pool.items, .best = best.items, .private = c.private };
}

const Best = struct { i: usize, role: core.Role, win: f64 };

fn rate(stats: *const core.Stats, floor: u64, i: usize, r: core.Role) ?Best {
    if (stats.champRole(r, i).games < @max(floor, 1)) return null;
    return .{ .i = i, .role = r, .win = core.score.roleWin(stats, .{}, i, r) };
}

fn better(a: ?Best, b: ?Best) ?Best {
    const x = a orelse return b;
    const y = b orelse return a;
    return if (y.win > x.win) y else x;
}

fn pick(a: Allocator, c: screens.Ctx, stats: *const core.Stats, b: Best) !?ui.apphome.Pick {
    const ch = (try c.champ(a, stats.ids[b.i])) orelse return null;
    return .{ .champ = ch, .role = @fromBackingInt(@as(u3, @backingInt(b.role))), .win = 100 * b.win };
}
