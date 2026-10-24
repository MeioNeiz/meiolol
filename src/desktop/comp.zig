//! The comp view (comp.zig) once every seat is locked: both teams' damage mix and early
//! or late champions side by side, then the five lanes as mirrored rows. The public
//! edition says it in words; testers also see the numbers behind each word

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const comp = @import("../comp.zig");
const loading = @import("../loading.zig");
const rows = @import("rows.zig");
const w = @import("widgets.zig");
const Ctx = w.Ctx;
const palette = w.palette;
const champfacts = core.champfacts;

const magic_colour: dvui.Color = .fromHex("#8a7cf0");
const physical_colour: dvui.Color = .fromHex("#c8794a");

pub fn view(ctx: Ctx, c: *const comp.Comp) void {
    w.heading(@src(), "Team comps", null);
    {
        var row = dvui.box(@src(), .{ .dir = if (ctx.wide) .horizontal else .vertical, .equal_space = ctx.wide }, .{ .expand = .horizontal });
        defer row.deinit();
        for (c.teams, 0..) |t, side| team(ctx, side, t);
    }
    w.heading(@src(), "Lanes", null);
    for (c.lanes, 0..) |l, i| lane(ctx, i, l);
    w.para(@src(), "A champion leans early when its team is usually ahead at {d} min but wins less often from an even game at {d}; late, the other way round.", .{
        champfacts.gold_minute, champfacts.win_minute,
    }, .{ .muted = true, .small = true });
    w.para(@src(), "Champion facts only, averages over many games: damage split and team mixes from patch {s} in EUW, early or late from every region over 30 days, lanes from the matchup's curve at {d} min.", .{
        if (c.patch.len > 0) c.patch else "?", core.curvesfile.lane_minute,
    }, .{ .muted = true, .small = true });
}

fn team(ctx: Ctx, side: usize, t: comp.Team) void {
    const ours = side == 0;
    const colour = if (ours) palette.ally else palette.enemy;
    var box = w.card(@src(), side, null, .vertical);
    defer box.deinit();
    dvui.labelNoFmt(@src(), if (ours) "Your team" else "Enemy team", .{}, .{ .font = dvui.themeGet().font_heading, .color_text = .{ .color = colour }, .padding = .{} });
    if (t.damage) |d| damage(ctx, d) else {
        w.para(@src(), "Damage split not known for every champion yet.", .{}, .{ .muted = true, .small = true });
    }
    if (t.timing.len == 0) {
        w.para(@src(), "No champion with a clear early or late lean.", .{}, .{ .muted = true, .small = true });
        return;
    }
    for (t.timing, 0..) |tm, i| timing(ctx, i, tm);
}

/// The split as a bar, magic left, then the mix in words
fn damage(ctx: Ctx, d: comp.Damage) void {
    var bar = dvui.box(@src(), .{}, .{ .expand = .horizontal, .min_size_content = .{ .h = 8 }, .margin = .{ .y = 6, .h = 4 } });
    const r = bar.data().contentRectScale().r;
    bar.deinit();
    var left = r;
    left.w = r.w * @as(f32, @floatCast(d.magic));
    var right = r;
    right.x += left.w;
    right.w -= left.w;
    left.fill(.{}, .{ .color = .{ .color = magic_colour } });
    right.fill(.{}, .{ .color = .{ .color = physical_colour } });
    {
        var legend = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer legend.deinit();
        const o: dvui.Options = .{ .font = w.tiny(), .padding = .{} };
        dvui.labelNoFmt(@src(), "magic", .{}, o.override(.{ .color_text = .{ .color = magic_colour.lighten(10) } }));
        dvui.labelNoFmt(@src(), "physical", .{}, o.override(.{ .gravity_x = 1, .color_text = .{ .color = physical_colour.lighten(10) } }));
    }
    const words = switch (d.mix) {
        .physical => "Mostly physical damage",
        .mixed => "Mixed damage",
        .magic => "Mostly magic damage",
    };
    if (ctx.private()) {
        w.para(@src(), "{s}: {d:.0}% magic", .{ words, 100 * d.magic }, .{});
        if (d.teams.games > 0) {
            var nbuf: [16]u8 = undefined;
            const rate = @as(f64, @floatFromInt(d.teams.wins)) / @as(f64, @floatFromInt(d.teams.games));
            w.para(@src(), "Teams like it won {d:.1}% ({s} teams)", .{ 100 * rate, w.compact(&nbuf, d.teams.games) }, .{ .small = true, .color = w.rateColour(rate) });
        }
    } else {
        w.para(@src(), "{s}", .{words}, .{});
    }
    if (d.wins_less) w.para(@src(), "Teams this one-sided win less often: one kind of defence blocks most of their damage.", .{}, .{ .small = true, .color = palette.caution });
}

fn timing(ctx: Ctx, i: usize, t: comp.Timing) void {
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = i, .expand = .horizontal, .margin = .{ .y = 2 } });
    defer row.deinit();
    w.champIcon(@src(), ctx, t.champion, .{ .size = 24 });
    var col = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .gravity_y = 0.5, .margin = .{ .x = 6 } });
    defer col.deinit();
    const late = t.lean == .late;
    dvui.label(@src(), "{s} leans {s}", .{ ctx.stats.nameOf(t.champion), if (late) "late" else "early" }, .{ .font = w.small(), .padding = .{} });
    if (!ctx.private()) return;
    dvui.label(@src(), "{s}{d:.0} gold at {d} min, {s}{d:.0} pts at {d}", .{
        if (t.gold > 0) "+" else "", @round(t.gold / 10) * 10, champfacts.gold_minute, if (t.win > 0) "+" else "", t.win, champfacts.win_minute,
    }, .{ .font = w.tiny(), .color_text = .{ .color = w.text().opacity(0.6) }, .padding = .{} });
}

fn lane(ctx: Ctx, i: usize, l: comp.Lane) void {
    var obuf: [64]u8 = undefined;
    var tbuf: [64]u8 = undefined;
    const ours, const theirs = lines(&obuf, &tbuf, l);
    const gold: ?i64 = if (ctx.private()) if (l.facts) |f| if (f.gold) |g| g.mean else null else null else null;
    rows.mirrored(
        ctx,
        i,
        l.role,
        if (l.ours != 0) .{ .champion = l.ours, .me = l.me, .line = ours } else null,
        if (l.theirs != 0) .{ .champion = l.theirs, .me = false, .line = theirs } else null,
        gold,
    );
}

/// Each side's lane in words, its own way round: "ahead in lane, level 6 sooner"
fn lines(obuf: []u8, tbuf: []u8, l: comp.Lane) [2][]const u8 {
    const f = l.facts orelse return .{ if (l.ours != 0 and l.theirs != 0) "few games of this lane" else "", "" };
    const where = if (l.role == .jungle) "early" else "in lane";
    var out: [2][]const u8 = undefined;
    for ([_][]u8{ obuf, tbuf }, [_]bool{ true, false }, &out) |buf, mine, *o| {
        var bw: std.Io.Writer = .fixed(buf);
        if (f.edge()) |e| {
            const flipped: loading.LaneFacts.Edge = if (mine) e else switch (e) {
                .ahead => .behind,
                .behind => .ahead,
                .even => .even,
            };
            bw.print("{t} {s}", .{ flipped, where }) catch {};
        }
        if (loading.timingWord(f.level6)) |word| {
            const sooner = (word == .sooner) == mine;
            bw.print("{s}level 6 {s}", .{ if (bw.end > 0) ", " else "", if (sooner) "sooner" else "later" }) catch {};
        }
        o.* = bw.buffered();
    }
    return out;
}
