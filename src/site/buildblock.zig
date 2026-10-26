//! The champion page's build block: a builds file's champion and role as BuildPanel's
//! data (ui/buildpanel.zig, ui/runetree.zig). Names and icons from the file's Data
//! Dragon lists, stat shards from ddragon.shards. Trees as the build page's rune view
//! (builds.zig runeStats): those with a rune on min_tree_share, by keystone players
const std = @import("std");
const ui = @import("ui");
const builds = @import("../builds.zig");
const ddragon = @import("../ddragon.zig");

const File = builds.File;
const Kind = builds.Kind;
const bp = ui.buildpanel;
const rt = ui.runetree;
const Art = ui.art.Art;

/// A tree shows when one of its runes has this share of the players
const min_tree_share = 0.02;
const pages_shown = 4;

/// `b` (a File.Build of `f`) as the panel's data, in `a`. `champion`: its name
pub fn data(a: std.mem.Allocator, f: *const File, b: File.Build, champion: []const u8) !bp.Data {
    return dataVs(a, f, b, champion, null);
}

/// A matchup's `b`, with the champion's `usual` build for the runes the matchup moves
pub fn dataVs(a: std.mem.Allocator, f: *const File, b: File.Build, champion: []const u8, usual: ?File.Build) !bp.Data {
    var slots: std.ArrayList(bp.Slot) = .empty;
    const kinds = [_]struct { Kind, bp.Kind }{ .{ .spells, .spells }, .{ .start, .start }, .{ .boots, .boots }, .{ .core3, .core }, .{ .item4, .item4 }, .{ .item5, .item5 }, .{ .item6, .item6 }, .{ .skills, .skills }, .{ .skill_path, .skill_path } };
    for (kinds) |k| {
        const rows = b.get(k[0]) orelse continue;
        if (rows.options.len == 0) continue;
        const options = try a.alloc(bp.Option, rows.options.len);
        for (options, rows.options) |*o, x| o.* = try option(a, f, b, k[0], x);
        try slots.append(a, .{ .kind = k[1], .games = rows.games, .wins = rows.wins, .options = options });
    }
    return .{
        .runes = try runes(a, f, b, if (usual) |u| u.get(.rune) else null),
        .slots = slots.items,
        .champion = champion,
        .own = bp.rate(b.games, b.wins),
    };
}

fn option(a: std.mem.Allocator, f: *const File, b: File.Build, kind: Kind, x: File.Option) !bp.Option {
    var o: bp.Option = .{ .games = x.games, .wins = x.wins };
    switch (kind) {
        .skills => {
            const keys = try a.alloc(u8, x.v.len);
            for (keys, x.v) |*c, s| c.* = key(s);
            o.keys = keys;
        },
        .skill_path => {
            const keys = try a.alloc(u8, builds.max_level);
            for (keys, builds.unpackPath(x.v)) |*c, s| c.* = key(s);
            o.keys = keys;
        },
        else => {
            const list = if (kind == .spells) f.spells else f.items;
            const icons = try a.alloc(Art, x.v.len);
            const minutes = try a.alloc(f32, x.v.len);
            var known = false;
            for (icons, minutes, x.v, 0..) |*icon, *m, id, i| {
                icon.* = if (kind == .boots and id == 0) .{ .name = "No boots", .src = "" } else try art(a, list, id);
                const at = if (builds.itemSlot(kind, i)) |slot| b.minute(slot, id) else null;
                m.* = if (at) |t| @floatCast(t.minute) else 0;
                known = known or m.* > 0;
            }
            o.art = icons;
            if (known) o.minutes = minutes;
            // Pairs and starts name themselves in the open cell; one item by its art
            if (kind == .spells or kind == .start) {
                var name: std.Io.Writer.Allocating = .init(a);
                for (icons, 0..) |icon, i| {
                    if (i > 0) try name.writer.writeAll(if (kind == .spells) " " else ", ");
                    try name.writer.writeAll(icon.name);
                }
                o.name = name.written();
            }
        },
    }
    return o;
}

/// Ability slot 1 Q to 4 R
fn key(s: anytype) u8 {
    return switch (s) {
        1 => 'Q',
        2 => 'W',
        3 => 'E',
        4 => 'R',
        else => '?',
    };
}

/// An id unknown to the file draws an empty square named by its id
fn art(a: std.mem.Allocator, list: []const ddragon.Named, id: u32) !Art {
    const n = ddragon.find(list, id) orelse return .{ .name = try std.fmt.allocPrint(a, "#{d}", .{id}), .src = "" };
    return .{ .name = n.name, .src = n.icon };
}

fn runes(a: std.mem.Allocator, f: *const File, b: File.Build, usual: ?File.Rows) !rt.Data {
    const rune = b.get(.rune) orelse File.Rows{ .kind = .rune, .games = 0, .wins = 0, .options = &.{} };
    const Shown = struct { t: rt.Tree, keystones: u32, most: u32 };
    var shown: std.ArrayList(Shown) = .empty;
    for (f.trees) |t| {
        var s: Shown = .{ .t = .{ .id = t.id, .art = try art(a, f.runes, t.id), .rows = &.{} }, .keystones = 0, .most = 0 };
        const rows = try a.alloc([]const rt.Rune, t.slots.len);
        for (rows, t.slots, 0..) |*row, slot, i| {
            const cells = try a.alloc(rt.Rune, slot.len);
            for (cells, slot) |*c, id| {
                const n = find(rune.options, &.{id});
                c.* = .{ .id = id, .art = try art(a, f.runes, id), .games = n.games, .wins = n.wins, .usual = moved(rune, n, usual, id) };
                if (i == 0) s.keystones += n.games;
                s.most = @max(s.most, n.games);
            }
            row.* = cells;
        }
        s.t.rows = rows;
        if (@as(f64, @floatFromInt(s.most)) < min_tree_share * @as(f64, @floatFromInt(rune.games))) continue;
        try shown.append(a, s);
    }
    std.mem.sort(Shown, shown.items, {}, struct {
        fn lt(_: void, x: Shown, y: Shown) bool {
            return if (x.keystones != y.keystones) x.keystones > y.keystones else x.most > y.most;
        }
    }.lt);
    const trees = try a.alloc(rt.Tree, shown.items.len);
    for (trees, shown.items) |*t, s| t.* = s.t;

    var shards: []const []const rt.Rune = &.{};
    if (b.get(.shard)) |sr| if (sr.options.len > 0) {
        const rows = try a.alloc([]const rt.Rune, ddragon.shard_rows.len);
        for (rows, ddragon.shard_rows, 0..) |*row, ids, i| {
            const cells = try a.alloc(rt.Rune, ids.len);
            for (cells, ids) |*c, id| {
                const n = find(sr.options, &.{ @intCast(i), id });
                c.* = .{ .id = id, .art = try art(a, &ddragon.shards, id), .games = n.games, .wins = n.wins };
            }
            row.* = cells;
        }
        shards = rows;
    };
    var top_shards: [3]u32 = @splat(0);
    if (b.get(.shards)) |s| if (s.options.len > 0 and s.options[0].v.len == 3) {
        top_shards = s.options[0].v[0..3].*;
    };

    var pages: []rt.Page = &.{};
    if (b.get(.runes)) |r| {
        pages = try a.alloc(rt.Page, @min(r.options.len, pages_shown));
        var n: usize = 0;
        for (r.options[0..pages.len]) |o| {
            if (o.v.len != 8) continue;
            pages[n] = .{
                .v = o.v[0..8].*,
                .keystone = try art(a, f.runes, o.v[1]),
                .second = try art(a, f.runes, o.v[5]),
                .games = o.games,
                .wins = o.wins,
            };
            n += 1;
        }
        pages = pages[0..n];
    }
    return .{ .trees = trees, .shards = shards, .games = rune.games, .wins = rune.wins, .pages = pages, .top_shards = top_shards };
}

/// A rune counts as taken differently in a matchup when its pick share is this many
/// points away from the champion's in the role. Win rates don't enter: pulled toward the
/// row's by File.shrinkK (about 6,000 games for runes in matchups), no rune's moves 2
/// points from its usual in any EUW matchup with a file (16.20, 2,002 pairs)
const shift_points = 10;
/// Under this many players a rune's share is left out either way
const shift_games = bp.rate_games;

/// The usual share of rune `id`, %, when the matchup's (`n` of `rune`) is shift_points
/// or more away
fn moved(rune: File.Rows, n: builds.Count, usual: ?File.Rows, id: u32) ?u8 {
    const ur = usual orelse return null;
    const u = find(ur.options, &.{id});
    if (n.games < shift_games and u.games < shift_games) return null;
    const here = share(n.games, rune.games);
    const was = share(u.games, ur.games);
    if (@abs(here - was) < shift_points) return null;
    return @intFromFloat(@round(was));
}

fn share(n: u32, all: u32) f64 {
    return 100 * @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(@max(all, 1)));
}

fn find(options: []const File.Option, v: []const u32) builds.Count {
    for (options) |o| if (std.mem.eql(u32, o.v, v)) return .{ .games = o.games, .wins = o.wins };
    return .{};
}

test "moved runes: 10+ points from usual either way, under 100 players on both sides left out" {
    const rows = struct {
        fn of(options: []const File.Option) File.Rows {
            return .{ .kind = .rune, .games = 1000, .wins = 500, .options = options };
        }
    };
    const usual = rows.of(&.{
        .{ .v = &.{8010}, .games = 600, .wins = 300 },
        .{ .v = &.{8008}, .games = 400, .wins = 200 },
        .{ .v = &.{8444}, .games = 300, .wins = 150 },
        .{ .v = &.{8299}, .games = 50, .wins = 25 },
    });
    const vs = rows.of(&.{
        .{ .v = &.{8010}, .games = 800, .wins = 400 },
        .{ .v = &.{8008}, .games = 150, .wins = 75 },
        .{ .v = &.{8021}, .games = 95, .wins = 45 },
        .{ .v = &.{8299}, .games = 120, .wins = 60 },
    });
    const want = [_]struct { u32, ?u8 }{
        .{ 8010, 60 }, // 80% here
        .{ 8008, 40 }, // 15%
        .{ 8444, 30 }, // left out of the matchup
        .{ 8021, null }, // 9.5% from 0, and under 100 players on both sides
        .{ 8299, null }, // 12% from 5%
    };
    for (want) |w| try std.testing.expectEqual(w[1], moved(vs, find(vs.options, &.{w[0]}), usual, w[0]));
    try std.testing.expectEqual(null, moved(vs, find(vs.options, &.{8010}), null, 8010));
}
